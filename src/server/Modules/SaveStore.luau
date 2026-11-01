--!strict
-- Session-locked DataStore wrapper. Guarantees one server owns a player's save at a time so progress can't be
-- overwritten by a stale server, retries every call with exponential backoff, and falls back to an in-memory
-- backend in Studio when API access is disabled. Core logic is backend-agnostic and unit-tested
-- (tests/savestore.spec.luau) with a fake backend and multiple simulated servers.
--
-- Record layout stored under "Player_<userId>":
--   { Data = <PlayerData>, Lock = { JobId, Session, Time }?, SavedAt = <unix> }

export type LoadStatus = "ok" | "locked" | "error"

export type Store = {
	Load: (self: Store, userId: number) -> (any?, LoadStatus),
	Save: (self: Store, userId: number, data: any, release: boolean) -> (boolean, boolean),
	IsMemory: (self: Store) -> boolean,
}

export type Backend = {
	-- Atomically transforms the value at key. transform returns the new value, or nil to cancel the write.
	-- Returns (success, resulting value).
	Update: (key: string, transform: (any) -> any?) -> (boolean, any),
}

export type Options = {
	JobId: string,
	Guid: () -> string,
	Now: () -> number,
	Wait: (seconds: number) -> (),
	IsMemory: boolean,
}

local SaveStore = {}

SaveStore.LockStaleSeconds = 600 -- a lock not refreshed for this long belongs to a dead server
SaveStore.LoadAttempts = 7
SaveStore.LockedRetryDelay = 5
SaveStore.SaveAttempts = 4

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- In-memory backend (Studio without API access, and tests).
function SaveStore.MemoryBackend(): Backend
	local storage: { [string]: any } = {}
	return {
		Update = function(key: string, transform: (any) -> any?): (boolean, any)
			local result = transform(deepCopy(storage[key]))
			if result ~= nil then
				storage[key] = deepCopy(result)
			end
			return true, if result ~= nil then result else storage[key]
		end,
	}
end

function SaveStore.fromBackend(backend: Backend, options: Options): Store
	local sessions: { [number]: string } = {}
	local self = {} :: Store

	function self.IsMemory(_: Store): boolean
		return options.IsMemory
	end

	function self.Load(_: Store, userId: number): (any?, LoadStatus)
		local key = "Player_" .. userId
		local session = options.Guid()
		for attempt = 1, SaveStore.LoadAttempts do
			local lockedOut = false
			local loadedData: any = nil
			local ok, _ = backend.Update(key, function(old: any): any?
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.Session ~= session then
					local age = options.Now() - (tonumber(lock.Time) or 0)
					local sameServer = lock.JobId == options.JobId and options.JobId ~= ""
					if age < SaveStore.LockStaleSeconds and not sameServer then
						lockedOut = true
						return nil
					end
				end
				record.Lock = { JobId = options.JobId, Session = session, Time = options.Now() }
				loadedData = record.Data
				return record
			end)
			if ok and not lockedOut then
				sessions[userId] = session
				return loadedData, "ok"
			end
			if attempt < SaveStore.LoadAttempts then
				if lockedOut then
					options.Wait(SaveStore.LockedRetryDelay)
				else
					options.Wait(math.min(2 ^ attempt, 16))
				end
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
				record.SavedAt = options.Now()
				if release then
					record.Lock = nil
				else
					record.Lock = { JobId = options.JobId, Session = session, Time = options.Now() }
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
			if attempt < SaveStore.SaveAttempts then
				options.Wait(math.min(2 ^ attempt, 8))
			end
		end
		return false, false
	end

	return self
end

-- Production constructor: real DataStore when available, memory backend in Studio without API access.
function SaveStore.new(name: string): Store
	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")

	local function waitForBudget()
		local waited = 0
		while
			DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1
			and waited < 10
		do
			task.wait(0.5)
			waited += 0.5
		end
	end

	local function dataStoreBackend(store: GlobalDataStore): Backend
		return {
			Update = function(key: string, transform: (any) -> any?): (boolean, any)
				waitForBudget()
				local ok, result = pcall(function()
					return store:UpdateAsync(key, function(old)
						return transform(old)
					end)
				end)
				return ok, result
			end,
		}
	end

	local backend: Backend? = nil
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok and store then
		local probeOk, probeErr = pcall(function()
			return store:GetAsync("__probe")
		end)
		if probeOk then
			backend = dataStoreBackend(store)
		else
			local message = tostring(probeErr)
			local isAccess = string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
				or string.find(message, "403", 1, true) ~= nil
				or string.find(message, "publish", 1, true) ~= nil
			if not isAccess and not RunService:IsStudio() then
				-- Live server with a transient error: still use the real store; every call retries.
				backend = dataStoreBackend(store)
			end
		end
	end
	local isMemory = backend == nil
	if isMemory then
		warn("[SaveStore] DataStores unavailable (Studio without API access?). Using in-memory saves for this session.")
	end
	return SaveStore.fromBackend(backend or SaveStore.MemoryBackend(), {
		JobId = game.JobId,
		Guid = function()
			return HttpService:GenerateGUID(false)
		end,
		Now = os.time,
		Wait = function(seconds: number)
			task.wait(seconds)
		end,
		IsMemory = isMemory,
	})
end

return SaveStore
