--[[
	LeaderboardService: global top-50 boards on OrderedDataStores.

	  SoloBest    best Solo score
	  DuoBest     best co-op score (online Duos or Couch Co-op)
	  VersusWins  total Versus wins

	Reads are cached for 60 s; writes only ever raise a value.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

local BOARDS = { "SoloBest", "DuoBest", "VersusWins" }
local CACHE_SECONDS = 60
local TOP = 50

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { time: number, rows: { any } } } = {}
local nameCache: { [number]: string } = {}
local available = true

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	name = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = name
	return name
end

function LeaderboardService.init()
	for _, board in BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board .. "_v1")
		end)
		if ok then
			stores[board] = store
		else
			available = false
		end
	end
end

function LeaderboardService.submit(board: string, player: Player, value: number)
	local store = stores[board]
	if not store or not available or value <= 0 then
		return
	end
	local userId = player.UserId
	nameCache[userId] = player.Name
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(userId), function(old)
				old = tonumber(old) or 0
				if value <= old then
					return nil
				end
				return math.floor(value)
			end)
		end)
		if not ok then
			local msg = tostring(err)
			if string.find(msg, "Studio") or string.find(msg, "publish") then
				available = false
			end
		end
		cache[board] = nil
	end)
end

-- Returns { { rank, userId, name, value } ... }
function LeaderboardService.get(board: string): { any }
	local cached = cache[board]
	if cached and os.clock() - cached.time < CACHE_SECONDS then
		return cached.rows
	end
	local store = stores[board]
	local rows = {}
	if store and available then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, TOP)
		end)
		if ok and pages then
			local entries = pages:GetCurrentPage()
			for rank, entry in entries do
				local userId = tonumber(entry.key) or 0
				table.insert(rows, {
					rank = rank,
					userId = userId,
					name = nameOf(userId),
					value = entry.value,
				})
			end
		end
	end
	cache[board] = { time = os.clock(), rows = rows }
	return rows
end

function LeaderboardService.isAvailable(): boolean
	return available
end

return LeaderboardService
