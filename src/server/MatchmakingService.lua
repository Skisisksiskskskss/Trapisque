--[[
	MatchmakingService
	Quick Play queues for every mode, solo or as a party.

	Two backends share the pure Matchmaker logic:
		global  MemoryStore queues shared by every lobby server. One lobby server at a time
		        (elected with a lock) forms matches, reserves a server and writes an
		        assignment for each ticket; the ticket's own server teleports its players.
		local   an in-server queue. Used in Studio (teleports don't work there) and as a
		        fallback if MemoryStore is down. Matches run right on this server.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)
local Matchmaker = require(Shared.Meta.Matchmaker)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local MemoryUtil = require(script.Parent.MemoryUtil)
local PartyService = require(script.Parent.PartyService)
local DataService = require(script.Parent.DataService)
local TeleportUtil = require(script.Parent.TeleportUtil)

local MatchmakingService = {}

local MM = Config.Matchmaking
local QUEUE_PREFIX = "TrapisqueQ_"
local ASSIGN_MAP = "TrapisqueAssign"
local MATCH_MAP = "TrapisqueMatch"
local LOCK_MAP = "TrapisqueLock"

local tickets = {} -- [ticketId] = ticket (tickets owned by this server)
local ticketOfUser = {} -- [userId] = ticketId
local queueSizes = {} -- [modeId] = players searching (best guess)

-- set by Main: function(spec) that starts a match on this server
MatchmakingService.startLocalMatch = nil

local function useGlobal(): boolean
	return ServerInfo.canTeleport and ServerInfo.role == "lobby" and not MemoryUtil.unhealthy()
end

local function ticketPlayers(ticket): { Player }
	local out = {}
	for _, userId in ticket.users do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

local function pushStatus(ticket, state: string, extra: any?)
	local data = {
		state = state,
		mode = ticket.mode,
		since = ticket.createdClock,
		elapsed = os.clock() - ticket.createdClock,
		searching = queueSizes[ticket.mode] or ticket.size,
	}
	if extra then
		for k, v in extra do
			data[k] = v
		end
	end
	for _, p in ticketPlayers(ticket) do
		Net.push(p, "queue", data)
	end
end

local function clearTicket(ticket, state: string?, message: string?)
	tickets[ticket.id] = nil
	for _, userId in ticket.users do
		if ticketOfUser[userId] == ticket.id then
			ticketOfUser[userId] = nil
		end
	end
	if ticket.party then
		local anyone = Players:GetPlayerByUserId(ticket.party.leader) or ticketPlayers(ticket)[1]
		local party = anyone and PartyService.get(anyone)
		if party and party.state == "queued" then
			PartyService.setState(party, if state == "matched" then "playing" else "idle")
		end
	end
	for _, p in ticketPlayers(ticket) do
		Net.push(p, "queue", { state = state or "idle", message = message })
	end
	if ticket.global and state ~= "matched" then
		task.spawn(MemoryUtil.remove, QUEUE_PREFIX .. ticket.mode, ticket.key)
	end
end

---------------------------------------------------------------------------
-- queueing
---------------------------------------------------------------------------

function MatchmakingService.queue(player: Player, modeId: any)
	local mode = type(modeId) == "string" and Modes.get(modeId)
	if not mode then
		return false, "Pick a mode."
	end
	if ServerInfo.role ~= "lobby" then
		return false, "Finish this match first."
	end
	if ticketOfUser[player.UserId] then
		return false, "You're already searching."
	end
	local party = PartyService.get(player)
	local users = { player.UserId }
	if party then
		if party.leader ~= player.UserId then
			return false, "Only the party leader can start searching."
		end
		if party.state ~= "idle" then
			return false, "Your party is busy."
		end
		users = table.clone(party.members)
		if not Modes.partyFits(mode, #users) then
			if mode.isTeam then
				return false, "Parties in " .. mode.name .. " can have at most " .. mode.teamSize .. " players (one team). Try a Private Match!"
			end
			return false, "Your party is too big for this mode."
		end
	end
	for _, userId in users do
		if ticketOfUser[userId] then
			return false, "Someone in your party is already searching."
		end
		local p = Players:GetPlayerByUserId(userId)
		if not p then
			return false, "Everyone in the party must be on this server."
		end
	end

	local now = os.time()
	local id = HttpService:GenerateGUID(false)
	local ticket = {
		id = id,
		mode = mode.id,
		users = users,
		size = #users,
		created = now,
		createdClock = os.clock(),
		party = if party then { leader = party.leader, members = table.clone(party.members), settings = table.clone(party.settings) } else nil,
		global = useGlobal(),
	}
	ticket.key = string.format("%010d_%s", now, id)
	tickets[id] = ticket
	for _, userId in users do
		ticketOfUser[userId] = id
	end
	if party then
		PartyService.setState(party, "queued")
	end

	if ticket.global then
		local ok = MemoryUtil.set(QUEUE_PREFIX .. mode.id, ticket.key, {
			id = id,
			users = users,
			size = ticket.size,
			created = now,
			job = game.JobId,
			party = ticket.party,
		}, MM.TicketTTL)
		if not ok then
			-- MemoryStore hiccup: fall back to the in-server queue
			ticket.global = false
		end
	end
	pushStatus(ticket, "searching")
	return true
end

function MatchmakingService.cancel(player: Player)
	local id = ticketOfUser[player.UserId]
	local ticket = id and tickets[id]
	if not ticket then
		return false, "You're not searching."
	end
	if ticket.party and ticket.party.leader ~= player.UserId then
		-- anyone can cancel, but tell the others who did
		for _, p in ticketPlayers(ticket) do
			if p ~= player then
				Net.push(p, "toast", { text = player.DisplayName .. " cancelled the search.", kind = "info" })
			end
		end
	end
	clearTicket(ticket, "idle")
	return true
end

function MatchmakingService.isQueued(player: Player): boolean
	return ticketOfUser[player.UserId] ~= nil
end

---------------------------------------------------------------------------
-- local backend
---------------------------------------------------------------------------

local function startLocal(match, mode)
	local humans = {}
	for _, seat in match.seats do
		local p = Players:GetPlayerByUserId(seat.userId)
		if p then
			table.insert(humans, { player = p, team = seat.team })
		end
	end
	local bots = {}
	for _, b in match.bots do
		table.insert(bots, { team = b.team })
	end
	for _, t in match.tickets do
		clearTicket(tickets[t.id] or t, "matched")
	end
	if #humans == 0 then
		return
	end
	local ok, err = pcall(MatchmakingService.startLocalMatch, {
		mode = mode.id,
		map = "random",
		length = "quick",
		kind = "public",
		humans = humans,
		bots = bots,
		teamsPreset = mode.isTeam,
	})
	if not ok then
		warn("[Trapisque] failed to start local match: " .. tostring(err))
	end
end

local function localTick()
	local now = os.time()
	for _, mode in Modes.list do
		local list = {}
		for _, t in tickets do
			if not t.global and t.mode == mode.id then
				table.insert(list, t)
			end
		end
		local count = 0
		for _, t in list do
			count += t.size
		end
		queueSizes[mode.id] = math.max(queueSizes[mode.id] or 0, count)
		if #list > 0 then
			local matches = Matchmaker.form(mode, list, now, MM)
			for _, match in matches do
				startLocal(match, mode)
			end
		end
	end
end

---------------------------------------------------------------------------
-- global backend
---------------------------------------------------------------------------

local function acquireLock(modeId: string): boolean
	local won = false
	local now = os.time()
	MemoryUtil.update(LOCK_MAP, modeId, function(old)
		if old and old.job ~= game.JobId and (old.exp or 0) > now then
			won = false
			return nil
		end
		won = true
		return { job = game.JobId, exp = now + MM.LockTTL }
	end, MM.LockTTL)
	return won
end

local function formGlobal(mode)
	local ok, entries = MemoryUtil.range(QUEUE_PREFIX .. mode.id, 100)
	if not ok or type(entries) ~= "table" then
		return
	end
	local list = {}
	local total = 0
	for _, entry in entries do
		local v = entry.value
		if type(v) == "table" and type(v.users) == "table" then
			table.insert(list, {
				id = v.id,
				key = entry.key,
				size = v.size,
				users = v.users,
				created = v.created,
				party = v.party,
			})
			total += v.size
		end
	end
	queueSizes[mode.id] = total
	if #list == 0 then
		return
	end
	local matches = Matchmaker.form(mode, list, os.time(), MM)
	for _, match in matches do
		local reserved, accessCode, privateServerId = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if not reserved then
			warn("[Trapisque] ReserveServer failed: " .. tostring(accessCode))
			return
		end
		local mapDef = Maps.list[math.random(1, #Maps.list)]
		local parties = {}
		for _, t in match.tickets do
			if t.party then
				table.insert(parties, { leader = t.party.leader, members = t.party.members, settings = t.party.settings })
			end
		end
		local info = {
			mode = mode.id,
			map = mapDef.id,
			length = "quick",
			kind = "public",
			seats = match.seats,
			bots = match.bots,
			parties = parties,
			created = os.time(),
		}
		local wrote = MemoryUtil.set(MATCH_MAP, privateServerId, info, MM.MatchInfoTTL)
		if wrote then
			for _, t in match.tickets do
				MemoryUtil.set(ASSIGN_MAP, t.id, { code = accessCode, psid = privateServerId, info = info }, MM.AssignmentTTL)
				MemoryUtil.remove(QUEUE_PREFIX .. mode.id, t.key)
			end
		end
	end
end

local function pollAssignments()
	for id, ticket in tickets do
		if ticket.global then
			local ok, assignment = MemoryUtil.get(ASSIGN_MAP, id)
			if ok and type(assignment) == "table" and tickets[id] then
				MemoryUtil.remove(ASSIGN_MAP, id)
				local players = ticketPlayers(ticket)
				clearTicket(ticket, "matched")
				if #players > 0 then
					for _, p in players do
						Net.push(p, "teleporting", { reason = "Match found! Heading to the board..." })
						DataService.save(p, true)
					end
					local options = Instance.new("TeleportOptions")
					options.ReservedServerAccessCode = assignment.code
					options:SetTeleportData({ match = assignment.psid, info = assignment.info })
					task.spawn(function()
						local tpOk, err = TeleportUtil.teleport(players, game.PlaceId, options)
						if not tpOk then
							for _, p in players do
								Net.push(p, "teleporting", nil)
								Net.push(p, "toast", { text = "Couldn't join the match (" .. tostring(err) .. "). Try again!", kind = "error" })
							end
							local party = PartyService.get(players[1])
							if party then
								PartyService.setState(party, "idle")
							end
						end
					end)
				end
			end
		end
	end
end

local function refreshTickets()
	for _, ticket in tickets do
		if ticket.global then
			-- only refresh if the matchmaker hasn't already taken it
			MemoryUtil.update(QUEUE_PREFIX .. ticket.mode, ticket.key, function(old)
				if old == nil then
					return nil
				end
				return old
			end, MM.TicketTTL)
		end
	end
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

function MatchmakingService.init()
	PartyService.hooks.changed = function(party)
		-- membership changed while searching: cancel so the ticket isn't wrong
		for _, ticket in tickets do
			if ticket.party and ticket.party.leader and table.find(ticket.users, party.leader) then
				if #party.members ~= ticket.size then
					clearTicket(ticket, "idle", "The party changed, so the search was cancelled.")
				end
			end
		end
	end
	PartyService.hooks.disbanded = function(party)
		for _, ticket in tickets do
			if ticket.party and table.find(ticket.users, party.leader) then
				clearTicket(ticket, "idle")
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local id = ticketOfUser[player.UserId]
		if id and tickets[id] then
			clearTicket(tickets[id], "idle", player.DisplayName .. " left, so the search was cancelled.")
		end
	end)

	Net.handle("mm.queue", function(player, payload)
		return MatchmakingService.queue(player, payload.mode)
	end)
	Net.handle("mm.cancel", function(player)
		return MatchmakingService.cancel(player)
	end)

	if ServerInfo.role ~= "lobby" then
		return
	end

	-- local queue
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, err = pcall(localTick)
			if not ok then
				warn("[Trapisque] local matchmaking error: " .. tostring(err))
			end
		end
	end)

	-- status pushes
	task.spawn(function()
		while true do
			task.wait(1)
			for _, ticket in tickets do
				pushStatus(ticket, "searching")
			end
		end
	end)

	if not ServerInfo.canTeleport then
		return
	end

	-- global queue: assignments, refreshes and (if elected) match forming
	task.spawn(function()
		local lastRefresh, lastForm = 0, 0
		while true do
			task.wait(MM.PollInterval)
			local now = os.clock()
			pcall(pollAssignments)
			if now - lastRefresh >= MM.TicketRefresh then
				lastRefresh = now
				pcall(refreshTickets)
			end
			if now - lastForm >= MM.MatchmakerInterval then
				lastForm = now
				for _, mode in Modes.list do
					local ok, err = pcall(function()
						if acquireLock(mode.id) then
							formGlobal(mode)
						end
					end)
					if not ok then
						warn("[Trapisque] matchmaker error: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return MatchmakingService
