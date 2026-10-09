--[[
	LeaderboardService
	All-time top players: most wins, most treasures found, highest level.

	Scores live in one OrderedDataStore per board and are sent in when a match ends.
	Each board's top 50 is read at most once a minute per server and shared by everyone
	who asks. Names come from UserService (display name and @username), cached.

	In Studio without API access the boards are built from the players on this server,
	so the panel still has something to show.

		LeaderboardService.init(profileOf)       -- profileOf(player) -> saved profile
		LeaderboardService.submit(player, data)  -- after a match (data = saved profile)

	Client request: "leaderboard.get" { board = "wins" | "treasures" | "level" } ->
		{ board, live, entries = { { rank, userId, name, username, value } },
		  me = { rank?, value } }
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)

local LeaderboardService = {}

type Board = { store: string, value: (any) -> number }

local BOARDS: { [string]: Board } = {
	wins = {
		store = "TrapisqueWins_v1",
		value = function(d)
			return d.stats and d.stats.wins or 0
		end,
	},
	treasures = {
		store = "TrapisqueTreasures_v1",
		value = function(d)
			return d.stats and d.stats.treasures or 0
		end,
	},
	level = {
		store = "TrapisqueLevel_v1",
		value = function(d)
			return d.level or 1
		end,
	},
}

local TOP = 50
local CACHE_TIME = 60

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { at: number, entries: { any } } } = {}
local fetching: { [string]: boolean } = {}
local names: { [number]: { name: string, username: string? } } = {}
local offline: { [string]: { [number]: number } } = {} -- Studio: [board][userId] = value
local profileOf: ((Player) -> any)? = nil

-- Display names for everyone on a board (one UserService call for the unknown ones).
local function resolveNames(entries)
	local missing = {}
	for _, e in entries do
		if not names[e.userId] then
			table.insert(missing, e.userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in infos do
			names[info.Id] = { name = info.DisplayName, username = info.Username }
		end
	end
	for _, id in missing do
		if not names[id] then
			local ok2, username = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			if ok2 and username then
				names[id] = { name = username, username = username }
			end
		end
	end
end

local function valueFor(player: Player, board: string): number
	local data = if profileOf then profileOf(player) else nil
	if not data then
		return 0
	end
	return math.floor(BOARDS[board].value(data))
end

-- The top of a board: cached for a minute; never more than one read at a time.
local function fetch(board: string): { any }
	local c = cache[board]
	if c and os.clock() - c.at < CACHE_TIME then
		return c.entries
	end
	if fetching[board] then
		local t0 = os.clock()
		while fetching[board] and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		return if cache[board] then cache[board].entries else {}
	end
	fetching[board] = true
	local entries = {}
	local store = stores[board]
	if store then
		local ok, page = pcall(function()
			return store:GetSortedAsync(false, TOP):GetCurrentPage()
		end)
		if ok and type(page) == "table" then
			for _, item in page do
				local id = tonumber(item.key)
				if id and item.value > 0 then
					table.insert(entries, { userId = id, value = item.value })
				end
			end
		else
			warn("[Trapisque] leaderboard '" .. board .. "' failed to load: " .. tostring(page))
			fetching[board] = false
			return if c then c.entries else {}
		end
	else
		-- no DataStores: whoever has finished a match here, plus everyone here now
		local values = table.clone(offline[board] or {})
		for _, p in Players:GetPlayers() do
			values[p.UserId] = math.max(values[p.UserId] or 0, valueFor(p, board))
			names[p.UserId] = { name = p.DisplayName, username = p.Name }
		end
		for id, v in values do
			if v > 0 then
				table.insert(entries, { userId = id, value = v })
			end
		end
		table.sort(entries, function(a, b)
			if a.value ~= b.value then
				return a.value > b.value
			end
			return a.userId < b.userId
		end)
		while #entries > TOP do
			table.remove(entries)
		end
	end
	resolveNames(entries)
	cache[board] = { at = os.clock(), entries = entries }
	fetching[board] = false
	return entries
end

function LeaderboardService.submit(player: Player, data)
	if not data then
		return
	end
	names[player.UserId] = { name = player.DisplayName, username = player.Name }
	for board, def in BOARDS do
		local value = math.floor(def.value(data))
		local store = stores[board]
		if store then
			task.spawn(function()
				local ok, err = pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
				if not ok then
					warn("[Trapisque] leaderboard '" .. board .. "' save failed: " .. tostring(err))
				end
			end)
		else
			offline[board] = offline[board] or {}
			offline[board][player.UserId] = value
			cache[board] = nil
		end
	end
end

function LeaderboardService.init(getProfile: (Player) -> any)
	profileOf = getProfile
	for board, def in BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(def.store)
		end)
		if ok and store then
			stores[board] = store
		end
	end
	-- In Studio without API access, every DataStore call fails: use this server's players.
	if ServerInfo.isStudio and stores.wins then
		local probeOk = pcall(function()
			stores.wins:GetSortedAsync(false, 1)
		end)
		if not probeOk then
			table.clear(stores)
		end
	end

	Net.handle("leaderboard.get", function(player, payload)
		local board = if type(payload) == "table" and type(payload.board) == "string" then payload.board else "wins"
		if not BOARDS[board] then
			return false, "There's no such leaderboard."
		end
		local entries = fetch(board)
		local out = {}
		local myRank = nil
		for i, e in entries do
			local n = names[e.userId]
			out[i] = {
				rank = i,
				userId = e.userId,
				name = if n then n.name else ("Player " .. e.userId),
				username = if n then n.username else nil,
				value = e.value,
			}
			if e.userId == player.UserId then
				myRank = i
			end
		end
		return true, {
			board = board,
			live = stores[board] ~= nil,
			entries = out,
			me = { rank = myRank, value = valueFor(player, board) },
		}
	end)
end

return LeaderboardService
