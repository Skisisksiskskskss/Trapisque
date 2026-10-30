--[[
	MatchService
	Starts and tracks matches.

	Lobby servers run Practice (you vs bots), the guided first match and Private (your
	party + bots) matches right on the server, plus public matches when testing in
	Studio. Reserved match servers read their match setup from MemoryStore (written by
	the matchmaker), wait for everyone to arrive, play, then send everyone back to a
	lobby with their party intact.

	Three MemoryStore maps let other servers find running matches:
		TrapisqueOpen_<mode>  public matches with a bot seat someone could drop into
		TrapisqueWhere        which match each player is in (so friends can watch)
		TrapisqueRejoin       the seat kept for someone whose connection dropped
		                      (Config.Rejoin): the lobby they come back to offers to
		                      take them back to it
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)
local HouseRules = require(Shared.Game.HouseRules)
local Tutorial = require(Shared.Meta.Tutorial)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local MemoryUtil = require(script.Parent.MemoryUtil)
local DataService = require(script.Parent.DataService)
local PartyService = require(script.Parent.PartyService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local TeleportUtil = require(script.Parent.TeleportUtil)
local Match = require(script.Parent.Match)

local MatchService = {}

local OPEN_PREFIX = "TrapisqueOpen_"
local WHERE_MAP = "TrapisqueWhere"
local REJOIN_MAP = "TrapisqueRejoin"

local matches = {} -- [id] = Match
local matchOf = {} -- [Player] = Match (playing or watching)
local reserved = { waiting = true, expected = {}, info = nil }
local offers = {} -- [Player] = the seat kept for them on another server

function MatchService.get(player: Player)
	return matchOf[player]
end

---------------------------------------------------------------------------
-- rejoining after a dropped connection
---------------------------------------------------------------------------

-- Remember where `player` can get back to the seat kept for them.
local function rememberRejoin(player: Player, match)
	if not ServerInfo.canTeleport then
		return
	end
	local rec = {
		matchId = match.id,
		mode = match.mode.id,
		map = match.mapId,
		untilTime = os.time() + Config.Rejoin.Seconds,
	}
	if ServerInfo.isReserved then
		rec.code = reserved.info and reserved.info.code
		rec.psid = game.PrivateServerId
		if not rec.code then
			return
		end
	else
		rec.jobId = game.JobId
	end
	task.spawn(MemoryUtil.set, REJOIN_MAP, tostring(player.UserId), rec, Config.Rejoin.Seconds)
end

local function forgetRejoin(userId: number)
	if ServerInfo.canTeleport then
		task.spawn(MemoryUtil.remove, REJOIN_MAP, tostring(userId))
	end
end

-- Back on the server where your seat is kept: you get it back. Returns whether.
function MatchService.rejoinHere(player: Player): boolean
	if matchOf[player] then
		return false
	end
	for _, m in matches do
		if m:heldSeat(player.UserId) then
			DataService.waitFor(player, 10)
			if player.Parent == Players and m:rejoin(player) then
				matchOf[player] = m
				forgetRejoin(player.UserId)
				return true
			end
		end
	end
	return false
end

-- A seat kept for you on another server: what the lobby offers you (or nil).
function MatchService.rejoinOffer(player: Player)
	if ServerInfo.isReserved or not ServerInfo.canTeleport or matchOf[player] then
		return nil
	end
	local ok, rec = MemoryUtil.get(REJOIN_MAP, tostring(player.UserId))
	if not ok or type(rec) ~= "table" or (tonumber(rec.untilTime) or 0) <= os.time() or rec.jobId == game.JobId then
		return nil
	end
	offers[player] = rec
	return { mode = rec.mode, map = rec.map, seconds = rec.untilTime - os.time() }
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

local function forget(userId: number)
	if ServerInfo.canTeleport then
		task.spawn(MemoryUtil.remove, WHERE_MAP, tostring(userId))
	end
end

local function onClosed(match, reason)
	matches[match.id] = nil
	local people = {}
	-- a rematch: the players stay right here for the next one
	local staying = if reason == "rematch" then (match.staying or {}) else {}
	for player, m in matchOf do
		if m == match then
			matchOf[player] = nil
			if not staying[player] then
				table.insert(people, player)
				forget(player.UserId)
			end
		end
	end
	if ServerInfo.canTeleport and match.kind == "public" then
		task.spawn(MemoryUtil.remove, OPEN_PREFIX .. match.mode.id, game.PrivateServerId)
	end
	if ServerInfo.isReserved then
		if #people > 0 then
			sendHome(people, match)
		end
		return
	end
	for _, player in people do
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

local rematch -- (below: it starts a match too)

function MatchService.start(spec)
	for _, h in spec.humans do
		if matchOf[h.player] then
			error("player already in a match")
		end
	end
	local match = Match.new(spec, {
		closed = onClosed,
		rematch = function(m)
			rematch(m)
		end,
		-- a seat kept for someone who dropped out is a bot's for good now
		released = forgetRejoin,
	})
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

-- Everyone still at the table asked for a rematch: the same table again, right here.
rematch = function(match)
	if match.closed then
		return
	end
	local spec = match:rematchSpec()
	if #spec.humans == 0 then
		return
	end
	match.staying = {}
	for _, h in spec.humans do
		match.staying[h.player] = true
	end
	match:close("rematch")
	MatchService.start(spec)
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

local function canStartHere(player: Player): (boolean, string?)
	if ServerInfo.role ~= "lobby" then
		return false, "Finish this match first."
	end
	if matchOf[player] then
		return false, "You're already in a match."
	end
	if MatchmakingService.isQueued(player) then
		return false, "Cancel your search first."
	end
	return true, nil
end

function MatchService.practice(player: Player, payload)
	local ok, why = canStartHere(player)
	if not ok then
		return false, why
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

-- The guided first match: a short game against two gentle bots with the coach on.
function MatchService.tutorial(player: Player)
	local ok, why = canStartHere(player)
	if not ok then
		return false, why
	end
	local party = PartyService.get(player)
	if party and #party.members > 1 then
		return false, "Leave your party first: the guided match is just you and two bots."
	end
	MatchService.start({
		mode = Tutorial.mode,
		map = Tutorial.map,
		kind = "practice",
		humans = { { player = player, character = Tutorial.character } },
		bots = { {}, {} },
		tutorial = true,
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
	-- the host's house rules, and their map vote (which picks the map instead)
	local rules = HouseRules.clean(s.rules)
	local vote = nil
	if rules.vote ~= "off" then
		vote = { style = rules.vote, mystery = rules.mystery, wildcard = rules.wildcard }
	end
	MatchService.start({
		mode = mode.id,
		map = if vote then "random" else s.map,
		length = s.length,
		kind = "private",
		humans = humans,
		bots = bots,
		teamsPreset = mode.isTeam,
		parties = { { leader = party.leader, members = party.members, settings = party.settings } },
		rules = rules,
		vote = vote,
	})
	return true
end

---------------------------------------------------------------------------
-- drop-in and spectating
---------------------------------------------------------------------------

-- A match running on this server that `players` could drop into right now.
local function localDropIn(modeId: string, count: number)
	for _, match in matches do
		if match.mode.id == modeId and #match:openSeats() >= count then
			return match
		end
	end
	return nil
end

-- Drops `players` (a solo searcher or a small party) into a running match, if one
-- here has room. Returns true when they're in.
local function dropInHere(players: { Player }, modeId: string): boolean
	local match = localDropIn(modeId, #players)
	if not match then
		return false
	end
	for _, p in players do
		if match:dropIn(p) then
			matchOf[p] = match
			local party = PartyService.get(p)
			if party then
				PartyService.setState(party, "playing")
			end
		end
	end
	return true
end

-- Start watching a friend's match on this server.
local function watchHere(player: Player, userId: number): (boolean, string?)
	local friend = Players:GetPlayerByUserId(userId)
	local match = friend and matchOf[friend]
	if not match or match.closed or match.finished then
		return false, "That match has ended."
	end
	if matchOf[player] then
		return false, "You're already in a match."
	end
	if match:addSpectator(player) then
		matchOf[player] = match
		return true, nil
	end
	return false, "Can't watch that match."
end

-- Which of these friends are in a match someone could watch: { [userId] = info }.
function MatchService.findWatchable(player: Player, userIds: any)
	local out = {}
	if type(userIds) ~= "table" then
		return out
	end
	local count = 0
	for _, id in userIds do
		count += 1
		if count > 30 then
			break
		end
		local userId = tonumber(id)
		if userId then
			local here = Players:GetPlayerByUserId(userId)
			local match = here and matchOf[here]
			if match and not match.finished and not match:isSpectator(here) then
				out[tostring(userId)] = { map = match.mapId, mode = match.mode.id, here = true }
			elseif ServerInfo.canTeleport then
				local ok, where = MemoryUtil.get(WHERE_MAP, tostring(userId))
				if ok and type(where) == "table" then
					out[tostring(userId)] = { map = where.map, mode = where.mode }
				end
			end
		end
	end
	local _ = player
	return out
end

function MatchService.watch(player: Player, userId: any): (boolean, string?)
	local id = tonumber(userId)
	if not id then
		return false, "Pick a friend to watch."
	end
	if ServerInfo.role ~= "lobby" then
		return false, "Finish this match first."
	end
	if MatchmakingService.isQueued(player) then
		return false, "Cancel your search first."
	end
	if Players:GetPlayerByUserId(id) then
		return watchHere(player, id)
	end
	if not ServerInfo.canTeleport then
		return false, "That match isn't on this server."
	end
	local ok, where = MemoryUtil.get(WHERE_MAP, tostring(id))
	if not ok or type(where) ~= "table" then
		return false, "That match has ended."
	end
	Net.push(player, "teleporting", { reason = "Rowing over to watch..." })
	DataService.save(player, true)
	task.spawn(function()
		local tpOk, err
		if where.code then
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = where.code
			options:SetTeleportData({ match = where.psid, spectate = id })
			tpOk, err = TeleportUtil.teleport({ player }, game.PlaceId, options)
		elseif where.job then
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = where.job
			options:SetTeleportData({ spectate = id })
			tpOk, err = TeleportUtil.teleport({ player }, game.PlaceId, options)
		end
		if not tpOk then
			Net.push(player, "teleporting", nil)
			Net.push(player, "toast", { text = "Couldn't get to that match (" .. tostring(err) .. ").", kind = "error" })
		end
	end)
	return true, nil
end

-- Keeps the cross-server maps up to date: who plays where, and open drop-in seats.
local function advertise()
	if not ServerInfo.canTeleport then
		return
	end
	for _, match in matches do
		if not match.closed then
			local where = { mode = match.mode.id, map = match.mapId }
			if ServerInfo.isReserved then
				where.psid = game.PrivateServerId
				where.code = reserved.info and reserved.info.code
			else
				where.job = game.JobId
			end
			for _, p in match:humans() do
				MemoryUtil.set(WHERE_MAP, tostring(p.UserId), where, 90)
			end
			if ServerInfo.isReserved and match.kind == "public" and reserved.info and reserved.info.code then
				local open = #match:openSeats()
				local key = OPEN_PREFIX .. match.mode.id
				if open > 0 then
					MemoryUtil.set(key, game.PrivateServerId, { psid = game.PrivateServerId, code = reserved.info.code, seats = open, round = match.engine.round }, 20)
				else
					MemoryUtil.remove(key, game.PrivateServerId)
				end
			end
		end
	end
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
		vote = info.vote == true,
	})
end

-- Someone arrived after the match started: back from a dropped connection, a drop-in,
-- a spectator, or a straggler.
local function lateArrival(player: Player)
	if MatchService.rejoinHere(player) then
		return
	end
	local data = player:GetJoinData().TeleportData
	local match = nil
	for _, m in matches do
		match = m
	end
	if match and type(data) == "table" then
		if data.dropIn then
			DataService.waitFor(player, 10)
			if match:dropIn(player) then
				matchOf[player] = match
				return
			end
		elseif data.spectate then
			if match:addSpectator(player) then
				matchOf[player] = match
				return
			end
		end
	end
	task.wait(3)
	Net.push(player, "toast", { text = "That match already started. Sending you back to the lobby.", kind = "info" })
	sendHome({ player }, { parties = {} })
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

function MatchService.init()
	MatchmakingService.startLocalMatch = function(spec)
		MatchService.start(spec)
	end
	MatchmakingService.tryDropIn = dropInHere

	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		local match = matchOf[player]
		if match then
			matchOf[player] = nil
			-- (a dropped connection: the seat is kept for a while)
			if match:playerLeft(player) then
				rememberRejoin(player, match)
			end
		end
		forget(player.UserId)
	end)

	-- arriving on a lobby server to watch a friend's match here (or back on the one
	-- where your seat is kept)
	Players.PlayerAdded:Connect(function(player)
		if ServerInfo.isReserved then
			return
		end
		task.spawn(MatchService.rejoinHere, player)
		local data = player:GetJoinData().TeleportData
		if type(data) == "table" and tonumber(data.spectate) then
			task.delay(4, function()
				if player.Parent == Players and not matchOf[player] then
					local ok, err = watchHere(player, tonumber(data.spectate) :: number)
					if not ok then
						Net.push(player, "toast", { text = tostring(err), kind = "info" })
					end
				end
			end)
		end
	end)

	Net.handle("match.practice", function(player, payload)
		return MatchService.practice(player, payload)
	end)

	Net.handle("match.tutorial", function(player)
		return MatchService.tutorial(player)
	end)

	Net.handle("match.private", function(player)
		return MatchService.private(player)
	end)

	-- back to the seat kept for you on another server, or not
	Net.handle("rejoin.go", function(player)
		local rec = offers[player]
		if not rec or (tonumber(rec.untilTime) or 0) <= os.time() then
			return false, "That match has moved on without you."
		end
		offers[player] = nil
		local options = Instance.new("TeleportOptions")
		if rec.code then
			options.ReservedServerAccessCode = rec.code
			options:SetTeleportData({ match = rec.psid, rejoin = true })
		elseif rec.jobId then
			options.ServerInstanceId = rec.jobId
			options:SetTeleportData({ rejoin = true })
		else
			return false, "That match has moved on without you."
		end
		Net.push(player, "teleporting", { reason = "Back to your match..." })
		DataService.save(player, true)
		task.spawn(function()
			local ok, err = TeleportUtil.teleport({ player }, game.PlaceId, options)
			if not ok then
				Net.push(player, "teleporting", nil)
				Net.push(player, "toast", { text = "Couldn't get back to your match (" .. tostring(err) .. ").", kind = "error" })
			end
		end)
		return true
	end)
	Net.handle("rejoin.skip", function(player)
		offers[player] = nil
		forgetRejoin(player.UserId)
		return true
	end)

	Net.handle("match.cmd", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:command(player, payload.cmd)
	end)

	Net.handle("match.vote", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:vote(player, payload.option or payload.map)
	end)

	Net.handle("match.rematch", function(player)
		local match = matchOf[player]
		if not match then
			return false, "That match is over."
		end
		return match:voteRematch(player)
	end)

	Net.handle("match.fish", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:fish(player, payload.action, payload)
	end)

	Net.handle("match.emote", function(player, payload)
		local match = matchOf[player]
		if not match then
			return false, "You're not in a match."
		end
		return match:emote(player, payload.emote)
	end)

	-- the screen saw a tap, click or key press: the player is here (takes over from a bot)
	Net.handle("match.active", function(player)
		local match = matchOf[player]
		if not match then
			return true
		end
		return match:active(player)
	end)

	Net.handle("match.sync", function(player)
		local match = matchOf[player]
		if not match then
			return true, nil
		end
		return true, match:resync(player)
	end)

	Net.handle("spectate.find", function(player, payload)
		return true, MatchService.findWatchable(player, payload.userIds)
	end)

	Net.handle("spectate.watch", function(player, payload)
		return MatchService.watch(player, payload.userId)
	end)

	Net.handle("match.leave", function(player)
		local match = matchOf[player]
		if ServerInfo.isReserved then
			if match then
				matchOf[player] = nil
				match:playerLeft(player, true)
			end
			sendHome({ player }, match or { parties = {} })
			return true
		end
		if match then
			matchOf[player] = nil
			forget(player.UserId)
			match:playerLeft(player, true)
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
					lateArrival(player)
				end
			end
		end)
		task.spawn(bootReserved)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			pcall(advertise)
		end
	end)
end

function MatchService.status(player: Player)
	return {
		role = ServerInfo.role,
		inMatch = matchOf[player] ~= nil,
		waiting = ServerInfo.isReserved and reserved.waiting,
	}
end

return MatchService
