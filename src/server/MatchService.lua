--[[
	MatchService
	Starts and tracks matches.

	Lobby servers run Practice (you vs bots) and Private (your party + bots) matches
	right on the server, plus public matches when testing in Studio.
	Reserved match servers read their match setup from MemoryStore (written by the
	matchmaker), wait for everyone to arrive, play, then send everyone back to a lobby
	with their party intact.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local MemoryUtil = require(script.Parent.MemoryUtil)
local DataService = require(script.Parent.DataService)
local PartyService = require(script.Parent.PartyService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local TeleportUtil = require(script.Parent.TeleportUtil)
local Match = require(script.Parent.Match)

local MatchService = {}

local matches = {} -- [id] = Match
local matchOf = {} -- [Player] = Match
local reserved = { waiting = true, expected = {}, info = nil }

function MatchService.get(player: Player)
	return matchOf[player]
end

---------------------------------------------------------------------------
-- closing
---------------------------------------------------------------------------

local function sendHome(players: { Player }, match)
	-- Back to a public lobby. Party members travel together and get their party back.
	local groups = {}
	local solo = {}
	for _, p in players do
		local group = nil
		for gi, party in match.parties do
			if table.find(party.members, p.UserId) then
				group = gi
				break
			end
		end
		if group then
			groups[group] = groups[group] or {}
			table.insert(groups[group], p)
		else
			table.insert(solo, p)
		end
	end
	for gi, list in groups do
		local party = match.parties[gi]
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({
			restoreParty = {
				key = HttpService:GenerateGUID(false),
				leader = party.leader,
				members = party.members,
				settings = party.settings,
			},
		})
		for _, p in list do
			Net.push(p, "teleporting", { reason = "Heading back to the lobby..." })
			DataService.save(p, true)
		end
		task.spawn(TeleportUtil.teleport, list, game.PlaceId, options)
	end
	if #solo > 0 then
		for _, p in solo do
			Net.push(p, "teleporting", { reason = "Heading back to the lobby..." })
			DataService.save(p, true)
		end
		task.spawn(TeleportUtil.teleport, solo, game.PlaceId, nil)
	end
end

local function onClosed(match, _reason)
	matches[match.id] = nil
	local humans = {}
	for player, m in matchOf do
		if m == match then
			matchOf[player] = nil
			table.insert(humans, player)
		end
	end
	if ServerInfo.isReserved then
		if #humans > 0 then
			sendHome(humans, match)
		end
		return
	end
	for _, player in humans do
		Net.push(player, "match.closed", { id = match.id })
		local party = PartyService.get(player)
		if party and party.state == "playing" then
			PartyService.setState(party, "idle")
		end
	end
end

---------------------------------------------------------------------------
-- starting
---------------------------------------------------------------------------

function MatchService.start(spec)
	for _, h in spec.humans do
		if matchOf[h.player] then
			error("player already in a match")
		end
	end
	local match = Match.new(spec, { closed = onClosed })
	matches[match.id] = match
	for _, h in spec.humans do
		matchOf[h.player] = match
		local party = PartyService.get(h.player)
		if party then
			PartyService.setState(party, "playing")
		end
	end
	match:start()
	return match
end

local function teamFill(mode, humans: { Player }, together: boolean)
	-- humans fill teams in order (party leader's team first); bots take empty seats
	local list = {}
	for i, p in humans do
		list[i] = p
	end
	if not together then
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	local humanSpecs, bots = {}, {}
	local seat = 0
	for team = 1, mode.teams do
		for _ = 1, mode.teamSize do
			seat += 1
			local p = list[seat]
			if p then
				table.insert(humanSpecs, { player = p, team = team })
			else
				table.insert(bots, { team = team })
			end
		end
	end
	return humanSpecs, bots
end

local function checkSettings(modeId, mapId, length)
	local mode = Modes.get(modeId)
	if not mode then
		return nil, "Pick a mode."
	end
	if mapId ~= "random" and not Maps.get(mapId) then
		return nil, "Pick a map."
	end
	if not Modes.lengthById[length] then
		return nil, "Pick a match length."
	end
	return mode, nil
end

function MatchService.practice(player: Player, payload)
	if ServerInfo.role ~= "lobby" then
		return false, "Finish this match first."
	end
	if matchOf[player] then
		return false, "You're already in a match."
	end
	if MatchmakingService.isQueued(player) then
		return false, "Cancel your search first."
	end
	local party = PartyService.get(player)
	if party and #party.members > 1 then
		return false, "You're in a party. Start a Private Match to play together!"
	end
	local mode, err = checkSettings(payload.mode, payload.map or "random", payload.length or "quick")
	if not mode then
		return false, err
	end
	local humans, bots
	if mode.isTeam then
		humans, bots = teamFill(mode, { player }, true)
	else
		local n = math.clamp(tonumber(payload.bots) or 3, 1, mode.maxPlayers - 1)
		humans = { { player = player } }
		bots = {}
		for _ = 1, n do
			table.insert(bots, {})
		end
	end
	MatchService.start({
		mode = mode.id,
		map = payload.map or "random",
		length = payload.length or "quick",
		kind = "practice",
		humans = humans,
		bots = bots,
		teamsPreset = mode.isTeam,
	})
	return true
end

function MatchService.private(player: Player)
	if ServerInfo.role ~= "lobby" then
		return false, "Finish this match first."
	end
	local party = PartyService.get(player)
	if not party then
		return false, "Create a party first."
	end
	if party.leader ~= player.UserId then
		return false, "Only the party leader can start the match."
	end
	if party.state ~= "idle" then
		return false, "Your party is busy."
	end
	local s = party.settings
	local mode, err = checkSettings(s.mode, s.map, s.length)
	if not mode then
		return false, err
	end
	local members = PartyService.members(party)
	for _, p in members do
		if matchOf[p] then
			return false, p.DisplayName .. " is still in a match."
		end
	end
	if #members > mode.maxPlayers then
		return false, mode.name .. " has room for " .. mode.maxPlayers .. " players."
	end
	local humans, bots
	if mode.isTeam then
		humans, bots = teamFill(mode, members, s.teams ~= "random")
	else
		humans, bots = {}, {}
		for _, p in members do
			table.insert(humans, { player = p })
		end
		local botCount = math.clamp(s.bots or 0, 0, mode.maxPlayers - #members)
		if #members + botCount < 2 then
			botCount = 2 - #members
		end
		for _ = 1, botCount do
			table.insert(bots, {})
		end
	end
	MatchService.start({
		mode = mode.id,
		map = s.map,
		length = s.length,
		kind = "private",
		humans = humans,
		bots = bots,
		teamsPreset = mode.isTeam,
	})
	return true
end

---------------------------------------------------------------------------
-- reserved match servers
---------------------------------------------------------------------------

local function waitingPush()
	local arrived = {}
	for _, userId in reserved.expected do
		if Players:GetPlayerByUserId(userId) then
			table.insert(arrived, userId)
		end
	end
	for _, p in Players:GetPlayers() do
		Net.push(p, "match.waiting", { expected = #reserved.expected, arrived = #arrived })
	end
	return #arrived
end

local function bootReserved()
	local psid = game.PrivateServerId
	local info = nil
	for _ = 1, 12 do
		local ok, value = MemoryUtil.get("TrapisqueMatch", psid)
		if ok and type(value) == "table" then
			info = value
			break
		end
		-- fall back to what the first arrival carried in their teleport data
		for _, p in Players:GetPlayers() do
			local data = p:GetJoinData().TeleportData
			if type(data) == "table" and data.match == psid and type(data.info) == "table" then
				info = data.info
				break
			end
		end
		if info then
			break
		end
		task.wait(1)
	end
	if not info then
		warn("[Trapisque] reserved server has no match info; sending everyone home")
		for _, p in Players:GetPlayers() do
			Net.push(p, "toast", { text = "This match expired. Taking you back to the lobby.", kind = "error" })
		end
		sendHome(Players:GetPlayers(), { parties = {} })
		return
	end
	reserved.info = info
	reserved.expected = {}
	for _, seat in info.seats do
		table.insert(reserved.expected, seat.userId)
	end

	-- wait for everyone (or ~25s)
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		if waitingPush() >= #reserved.expected then
			break
		end
		task.wait(1)
	end

	local humans, bots = {}, {}
	for _, seat in info.seats do
		local p = Players:GetPlayerByUserId(seat.userId)
		if p then
			DataService.waitFor(p, 10)
			table.insert(humans, { player = p, team = seat.team })
		else
			table.insert(bots, { team = seat.team })
		end
	end
	for _, b in info.bots or {} do
		table.insert(bots, { team = b.team })
	end
	reserved.waiting = false
	if #humans == 0 then
		return
	end
	local mode = Modes.get(info.mode)
	MatchService.start({
		mode = info.mode,
		map = info.map,
		length = info.length,
		kind = "public",
		humans = humans,
		bots = bots,
		teamsPreset = mode ~= nil and mode.isTeam,
		parties = info.parties,
	})
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

function MatchService.init()
	MatchmakingService.startLocalMatch = function(spec)
		MatchService.start(spec)
	end

	Players.PlayerRemoving:Connect(function(player)
		local match = matchOf[player]
		if match then
			matchOf[player] = nil
			match:playerLeft(player)
		end
	end)

	Net.handle("match.practice", function(player, payload)
		return MatchService.practice(player, payload)
	end)

	Net.handle("match.private", function(player)
		return MatchService.private(player)
	end)

	Net.handle("match.cmd", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:command(player, payload.cmd)
	end)

	Net.handle("match.emote", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:emote(player, payload.emote)
	end)

	Net.handle("match.sync", function(player)
		local match = matchOf[player]
		if not match then
			return true, nil
		end
		return true, match:resync(player)
	end)

	Net.handle("match.leave", function(player)
		local match = matchOf[player]
		if ServerInfo.isReserved then
			if match then
				matchOf[player] = nil
				match:playerLeft(player)
			end
			sendHome({ player }, match or { parties = {} })
			return true
		end
		if match then
			matchOf[player] = nil
			match:playerLeft(player)
			local party = PartyService.get(player)
			if party and party.state == "playing" then
				local stillPlaying = false
				for _, p in PartyService.members(party) do
					if matchOf[p] then
						stillPlaying = true
					end
				end
				if not stillPlaying then
					PartyService.setState(party, "idle")
				end
			end
		end
		Net.push(player, "match.closed", { id = match and match.id or "" })
		return true
	end)

	if ServerInfo.isReserved then
		Players.PlayerAdded:Connect(function(player)
			if reserved.info and not reserved.waiting then
				local expected = table.find(reserved.expected, player.UserId)
				if not expected or not matchOf[player] then
					-- late or unexpected arrival: the match already started
					task.wait(3)
					Net.push(player, "toast", { text = "That match already started. Sending you back to the lobby.", kind = "info" })
					sendHome({ player }, { parties = {} })
				end
			end
		end)
		task.spawn(bootReserved)
	end
end

function MatchService.status(player: Player)
	return {
		role = ServerInfo.role,
		inMatch = matchOf[player] ~= nil,
		waiting = ServerInfo.isReserved and reserved.waiting,
	}
end

return MatchService
