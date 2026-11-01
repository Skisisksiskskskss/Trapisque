--!strict
-- Session-locked DataStore wrapper. Guarantees one server owns a player's save at a time so progress can't be
-- overwritten by a stale server, retries every call with exponential backoff, and falls back to an in-memory
-- backend in Studio when API access is disabled.
--
-- Record layout stored under "Player_<userId>":
--   { Data = <PlayerData>, Lock = { JobId, Session, Time }?, SavedAt = <unix> }

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

export type LoadStatus = "ok" | "locked" | "error"

export type Store = {
	Load: (self: Store, userId: number) -> (any?, LoadStatus),
	Save: (self: Store, userId: number, data: any, release: boolean) -> (boolean, boolean),
	IsMemory: (self: Store) -> boolean,
}

local SaveStore = {}

SaveStore.LockStaleSeconds = 600 -- a lock not refreshed for this long belongs to a dead server
SaveStore.LoadAttempts = 7
SaveStore.LockedRetryDelay = 5
SaveStore.SaveAttempts = 4

type Backend = {
	Update: (key: string, transform: (any) -> any?) -> (boolean, any),
}

local function memoryBackend(): Backend
	local storage: { [string]: any } = {}
	return {
		Update = function(key: string, transform: (any) -> any?): (boolean, any)
			local current = storage[key]
			local copy = if current ~= nil then HttpService:JSONDecode(HttpService:JSONEncode(current)) else nil
			local result = transform(copy)
			if result ~= nil then
				storage[key] = HttpService:JSONDecode(HttpService:JSONEncode(result))
			end
			return true, if result ~= nil then result else current
		end,
	}
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local waited = 0
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and waited < 10 do
		task.wait(0.5)
		waited += 0.5
	end
end

local function dataStoreBackend(store: GlobalDataStore): Backend
	return {
		Update = function(key: string, transform: (any) -> any?): (boolean, any)
			waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
			local ok, result = pcall(function()
				return store:UpdateAsync(key, function(old)
					return transform(old)
				end)
			end)
			return ok, result
		end,
	}
end

local function detectBackend(name: string): (Backend, boolean)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok and store then
		-- Probe: Studio without API access throws on any request.
		local probeOk, probeErr = pcall(function()
			return store:GetAsync("__probe")
		end)
		if probeOk then
			return dataStoreBackend(store), false
		end
		local message = tostring(probeErr)
		local isAccess = string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
			or string.find(message, "403", 1, true) ~= nil
			or string.find(message, "publish", 1, true) ~= nil
		if not isAccess and not RunService:IsStudio() then
			-- Live server with a transient error: still use the real store; calls retry individually.
			return dataStoreBackend(store), false
		end
	end
	warn("[SaveStore] DataStores unavailable (Studio without API access?). Using in-memory saves for this session.")
	return memoryBackend(), true
end

function SaveStore.new(name: string): Store
	local backend, isMemory = detectBackend(name)
	local sessions: { [number]: string } = {}

	local self = {} :: Store

	function self.IsMemory(_: Store): boolean
		return isMemory
	end

	function self.Load(_: Store, userId: number): (any?, LoadStatus)
		local key = "Player_" .. userId
		local session = HttpService:GenerateGUID(false)
		for attempt = 1, SaveStore.LoadAttempts do
			local lockedOut = false
			local loadedData: any = nil
			local ok, _ = backend.Update(key, function(old: any): any?
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.Session ~= session then
					local age = os.time() - (tonumber(lock.Time) or 0)
					local sameServer = lock.JobId == game.JobId and game.JobId ~= ""
					if age < SaveStore.LockStaleSeconds and not sameServer then
						lockedOut = true
						return nil
					end
				end
				record.Lock = { JobId = game.JobId, Session = session, Time = os.time() }
				loadedData = record.Data
				return record
			end)
			if ok and not lockedOut then
				sessions[userId] = session
				return loadedData, "ok"
			end
			if lockedOut then
				task.wait(SaveStore.LockedRetryDelay)
			else
				task.wait(math.min(2 ^ attempt, 16))
			end
		end
		return nil, "locked"
	end

	-- Returns (success, lockLost). lockLost means another server owns this save now; stop saving this player.
	function self.Save(_: Store, userId: number, data: any, release: boolean): (boolean, boolean)
		local key = "Player_" .. userId
		local session = sessions[userId]
		if session == nil then
			return false, true
		end
		for attempt = 1, SaveStore.SaveAttempts do
			local lockLost = false
			local ok, _ = backend.Update(key, function(old: any): any?
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.Session ~= session then
					lockLost = true
					return nil
				end
				record.Data = data
				record.SavedAt = os.time()
				if release then
					record.Lock = nil
				else
					record.Lock = { JobId = game.JobId, Session = session, Time = os.time() }
				end
				return record
			end)
			if lockLost then
				sessions[userId] = nil
				return false, true
			end
			if ok then
				if release then
					sessions[userId] = nil
				end
				return true, false
			end
			task.wait(math.min(2 ^ attempt, 8))
		end
		return false, false
	end

	return self
end

return SaveStore
