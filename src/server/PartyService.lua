--[[
	PartyService
	Parties of up to 6 friends who queue and play together.

	Ways to join a party:
		- Invite: the leader invites someone on the same server (they get a popup).
		- Code:   every party has a 6-character code. Typing it joins the party, even from
		          another server (we look the code up in MemoryStore and teleport you to
		          the party's server). "Invite only" parties ignore codes.
		- Friends: the client can send a Roblox game invite that carries the code.

	After a public match, the matchmaker sends party members back together and the party
	is restored on arrival.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local MemoryUtil = require(script.Parent.MemoryUtil)
local DataService = require(script.Parent.DataService)
local TeleportUtil = require(script.Parent.TeleportUtil)

local PartyService = {}

local CODE_MAP = "TrapisqueParties"

local parties = {} -- [partyId] = party
local partyOfUser = {} -- [userId] = partyId
local codeIndex = {} -- [code] = partyId
local restoreIndex = {} -- [restoreKey] = partyId
local invites = {} -- [targetUserId] = { [partyId] = { expires, from } }

-- Hooks set by other services (avoids circular requires)
PartyService.hooks = {
	changed = function(_party) end, -- membership or settings changed
	disbanded = function(_party) end,
}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function playerById(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function newCode(): string
	local alphabet = Config.Party.CodeAlphabet
	for _ = 1, 50 do
		local chars = {}
		for i = 1, Config.Party.CodeLength do
			local n = math.random(1, #alphabet)
			chars[i] = string.sub(alphabet, n, n)
		end
		local code = table.concat(chars)
		if not codeIndex[code] then
			return code
		end
	end
	return string.upper(string.sub(HttpService:GenerateGUID(false), 1, Config.Party.CodeLength))
end

local function normalizeCode(code: any): string
	if type(code) ~= "string" then
		return ""
	end
	local cleaned = string.gsub(code, "[^%w]", "")
	return string.upper(cleaned)
end

function PartyService.members(party): { Player }
	local out = {}
	for _, userId in party.members do
		local p = playerById(userId)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

function PartyService.get(player: Player)
	local id = partyOfUser[player.UserId]
	return id and parties[id]
end

function PartyService.isLeader(player: Player): boolean
	local party = PartyService.get(player)
	return party ~= nil and party.leader == player.UserId
end

function PartyService.view(party)
	if not party then
		return nil
	end
	local members = {}
	for _, userId in party.members do
		local p = playerById(userId)
		if p then
			local look = DataService.publicLook(p)
			table.insert(members, {
				userId = userId,
				name = p.DisplayName,
				username = p.Name,
				leader = userId == party.leader,
				look = look,
			})
		end
	end
	return {
		id = party.id,
		code = party.code,
		leader = party.leader,
		privacy = party.privacy,
		settings = table.clone(party.settings),
		state = party.state,
		members = members,
		max = Config.Party.MaxSize,
	}
end

function PartyService.push(party)
	local view = PartyService.view(party)
	for _, p in PartyService.members(party) do
		Net.push(p, "party", view)
	end
end

---------------------------------------------------------------------------
-- cross-server code registry
---------------------------------------------------------------------------

local function registerCode(party)
	if not ServerInfo.canTeleport or ServerInfo.role ~= "lobby" then
		return
	end
	task.spawn(function()
		if party.privacy == "code" and parties[party.id] then
			MemoryUtil.set(CODE_MAP, party.code, {
				job = game.JobId,
				party = party.id,
				privacy = party.privacy,
				size = #party.members,
			}, Config.Party.CodeTTL)
		else
			MemoryUtil.remove(CODE_MAP, party.code)
		end
	end)
end

local function unregisterCode(party)
	if not ServerInfo.canTeleport then
		return
	end
	task.spawn(MemoryUtil.remove, CODE_MAP, party.code)
end

---------------------------------------------------------------------------
-- membership
---------------------------------------------------------------------------

local function disband(party)
	parties[party.id] = nil
	codeIndex[party.code] = nil
	if party.restoreKey then
		restoreIndex[party.restoreKey] = nil
	end
	for _, userId in party.members do
		if partyOfUser[userId] == party.id then
			partyOfUser[userId] = nil
		end
	end
	unregisterCode(party)
	PartyService.hooks.disbanded(party)
end

local function removeMember(party, userId: number)
	local i = table.find(party.members, userId)
	if not i then
		return
	end
	table.remove(party.members, i)
	if partyOfUser[userId] == party.id then
		partyOfUser[userId] = nil
	end
	if #party.members == 0 then
		disband(party)
		return
	end
	if party.leader == userId then
		party.leader = party.members[1]
	end
	PartyService.hooks.changed(party)
	registerCode(party)
	PartyService.push(party)
end

function PartyService.create(player: Player, restore: any?)
	local existing = PartyService.get(player)
	if existing then
		return existing
	end
	local party = {
		id = HttpService:GenerateGUID(false),
		code = newCode(),
		leader = player.UserId,
		members = { player.UserId },
		privacy = "code",
		settings = { mode = "chaos", map = "random", length = "quick", bots = 3 },
		state = "idle",
	}
	if restore then
		party.restoreKey = restore.key
		restoreIndex[restore.key] = party.id
		if type(restore.settings) == "table" then
			for k, v in restore.settings do
				if party.settings[k] ~= nil and type(v) == type(party.settings[k]) then
					party.settings[k] = v
				end
			end
		end
	end
	parties[party.id] = party
	partyOfUser[player.UserId] = party.id
	codeIndex[party.code] = party.id
	registerCode(party)
	PartyService.push(party)
	return party
end

function PartyService.leave(player: Player, quiet: boolean?)
	local party = PartyService.get(player)
	if not party then
		return
	end
	removeMember(party, player.UserId)
	if not quiet and player.Parent == Players then
		Net.push(player, "party", nil)
	end
end

local function addMember(party, player: Player): (boolean, string?)
	if table.find(party.members, player.UserId) then
		return true, nil
	end
	if #party.members >= Config.Party.MaxSize then
		return false, "That party is full."
	end
	if party.state ~= "idle" then
		return false, "That party is busy right now. Try again in a moment."
	end
	local current = PartyService.get(player)
	if current then
		if current.state ~= "idle" then
			return false, "Leave your current queue first."
		end
		PartyService.leave(player, true)
	end
	table.insert(party.members, player.UserId)
	partyOfUser[player.UserId] = party.id
	if invites[player.UserId] then
		invites[player.UserId][party.id] = nil
	end
	PartyService.hooks.changed(party)
	registerCode(party)
	PartyService.push(party)
	for _, p in PartyService.members(party) do
		if p ~= player then
			Net.push(p, "toast", { text = player.DisplayName .. " joined the party!", kind = "party" })
		end
	end
	return true, nil
end

function PartyService.setState(party, state: string)
	if party and parties[party.id] then
		party.state = state
		PartyService.push(party)
	end
end

function PartyService.joinByCode(player: Player, rawCode: any)
	local code = normalizeCode(rawCode)
	if #code ~= Config.Party.CodeLength then
		return false, "Party codes are " .. Config.Party.CodeLength .. " letters/numbers."
	end
	local localId = codeIndex[code]
	if localId then
		local party = parties[localId]
		local invited = invites[player.UserId] and invites[player.UserId][party.id]
		if party.privacy ~= "code" and not invited then
			return false, "That party is invite-only."
		end
		local ok, err = addMember(party, player)
		if not ok then
			return false, err
		end
		return true, { joined = true }
	end
	if not ServerInfo.canTeleport then
		return false, "No party with that code on this server."
	end
	local ok, entry = MemoryUtil.get(CODE_MAP, code)
	if not ok then
		return false, "Couldn't look up that code right now. Try again."
	end
	if type(entry) ~= "table" or entry.job == game.JobId then
		return false, "No party found with that code."
	end
	if entry.privacy ~= "code" then
		return false, "That party is invite-only."
	end
	if (entry.size or 0) >= Config.Party.MaxSize then
		return false, "That party is full."
	end
	local current = PartyService.get(player)
	if current and current.state ~= "idle" then
		return false, "Leave your current queue first."
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = entry.job
	options:SetTeleportData({ joinParty = code })
	DataService.save(player, true)
	Net.push(player, "teleporting", { reason = "Joining your friend's party..." })
	task.spawn(function()
		local tpOk, err = TeleportUtil.teleport({ player }, game.PlaceId, options)
		if not tpOk then
			Net.push(player, "teleporting", nil)
			Net.push(player, "toast", { text = "Couldn't reach that party: " .. tostring(err), kind = "error" })
		end
	end)
	return true, { teleporting = true }
end

function PartyService.invite(player: Player, targetUserId: any)
	if type(targetUserId) ~= "number" then
		return false, "Pick someone to invite."
	end
	local target = playerById(targetUserId)
	if not target or target == player then
		return false, "They're not on this server."
	end
	local party = PartyService.get(player) or PartyService.create(player)
	if #party.members >= Config.Party.MaxSize then
		return false, "Your party is full."
	end
	if table.find(party.members, targetUserId) then
		return false, "They're already in your party."
	end
	invites[targetUserId] = invites[targetUserId] or {}
	invites[targetUserId][party.id] = { expires = os.time() + Config.Party.InviteExpiry, from = player.UserId }
	Net.push(target, "invite", {
		partyId = party.id,
		from = player.DisplayName,
		fromUserId = player.UserId,
		size = #party.members,
		expires = Config.Party.InviteExpiry,
		look = DataService.publicLook(player),
	})
	return true
end

function PartyService.respond(player: Player, partyId: any, accept: any)
	local mine = invites[player.UserId]
	local invite = type(partyId) == "string" and mine and mine[partyId]
	if not invite then
		return false, "That invite is no longer valid."
	end
	mine[partyId] = nil
	local party = parties[partyId]
	if not party or os.time() > invite.expires then
		return false, "That invite expired."
	end
	if not accept then
		local from = playerById(invite.from)
		if from then
			Net.push(from, "toast", { text = player.DisplayName .. " declined your invite.", kind = "info" })
		end
		return true
	end
	local ok, err = addMember(party, player)
	if not ok then
		return false, err
	end
	return true
end

---------------------------------------------------------------------------
-- arrivals (teleports and friend invites)
---------------------------------------------------------------------------

local function handleArrival(player: Player)
	local joinData = player:GetJoinData()
	local tp = joinData and joinData.TeleportData
	if type(tp) == "table" then
		if type(tp.joinParty) == "string" then
			task.wait(1)
			local ok, err = PartyService.joinByCode(player, tp.joinParty)
			if not ok then
				Net.push(player, "toast", { text = "Couldn't join that party: " .. tostring(err), kind = "error" })
			end
			return
		end
		local restore = tp.restoreParty
		if type(restore) == "table" and type(restore.key) == "string" and type(restore.members) == "table" then
			if not table.find(restore.members, player.UserId) then
				return
			end
			local existingId = restoreIndex[restore.key]
			local party = existingId and parties[existingId]
			if party then
				addMember(party, player)
			else
				party = PartyService.create(player, restore)
			end
			if restore.leader == player.UserId and table.find(party.members, player.UserId) then
				party.leader = player.UserId
				PartyService.push(party)
			end
			return
		end
	end
	-- Roblox game invites carry the party code in LaunchData
	local launch = joinData and joinData.LaunchData
	if type(launch) == "string" and #launch > 0 then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(launch)
		end)
		if ok and type(decoded) == "table" and type(decoded.party) == "string" then
			task.wait(1)
			local joined, err = PartyService.joinByCode(player, decoded.party)
			if not joined then
				Net.push(player, "toast", { text = "Couldn't join your friend's party: " .. tostring(err), kind = "error" })
			end
		end
	end
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

function PartyService.init()
	Players.PlayerRemoving:Connect(function(player)
		invites[player.UserId] = nil
		local party = PartyService.get(player)
		if party then
			removeMember(party, player.UserId)
		end
	end)

	if ServerInfo.role == "lobby" then
		Players.PlayerAdded:Connect(function(player)
			DataService.waitFor(player, 20)
			handleArrival(player)
		end)
	end

	-- keep codes alive in MemoryStore, expire stale invites
	task.spawn(function()
		while true do
			task.wait(Config.Party.CodeRefresh)
			for _, party in parties do
				registerCode(party)
			end
			local now = os.time()
			for userId, list in invites do
				for partyId, inv in list do
					if now > inv.expires or not parties[partyId] then
						list[partyId] = nil
					end
				end
				if next(list) == nil then
					invites[userId] = nil
				end
			end
		end
	end)

	Net.handle("party.create", function(player)
		local party = PartyService.create(player)
		return true, PartyService.view(party)
	end)

	Net.handle("party.leave", function(player)
		local party = PartyService.get(player)
		if party and party.state == "playing" then
			return false, "You can't leave in the middle of a match."
		end
		PartyService.leave(player)
		return true
	end)

	Net.handle("party.kick", function(player, payload)
		local party = PartyService.get(player)
		if not party or party.leader ~= player.UserId then
			return false, "Only the party leader can do that."
		end
		if party.state ~= "idle" then
			return false, "Not while queued or playing."
		end
		local target = tonumber(payload.userId)
		if not target or target == player.UserId or not table.find(party.members, target) then
			return false, "They're not in your party."
		end
		removeMember(party, target)
		local kicked = playerById(target)
		if kicked then
			Net.push(kicked, "party", nil)
			Net.push(kicked, "toast", { text = "You were removed from the party.", kind = "info" })
		end
		return true
	end)

	Net.handle("party.promote", function(player, payload)
		local party = PartyService.get(player)
		if not party or party.leader ~= player.UserId then
			return false, "Only the party leader can do that."
		end
		local target = tonumber(payload.userId)
		if not target or not table.find(party.members, target) then
			return false, "They're not in your party."
		end
		party.leader = target
		PartyService.push(party)
		return true
	end)

	Net.handle("party.privacy", function(player, payload)
		local party = PartyService.get(player)
		if not party or party.leader ~= player.UserId then
			return false, "Only the party leader can do that."
		end
		if payload.privacy ~= "code" and payload.privacy ~= "invite" then
			return false, "Unknown privacy setting."
		end
		party.privacy = payload.privacy
		registerCode(party)
		PartyService.push(party)
		return true
	end)

	Net.handle("party.settings", function(player, payload)
		local party = PartyService.get(player)
		if not party or party.leader ~= player.UserId then
			return false, "Only the party leader can change match settings."
		end
		local s = party.settings
		if payload.mode ~= nil then
			if not Modes.get(payload.mode) then
				return false, "Unknown mode."
			end
			s.mode = payload.mode
		end
		if payload.map ~= nil then
			if payload.map ~= "random" and not Maps.get(payload.map) then
				return false, "Unknown map."
			end
			s.map = payload.map
		end
		if payload.length ~= nil then
			if not Modes.lengthById[payload.length] then
				return false, "Unknown length."
			end
			s.length = payload.length
		end
		if payload.bots ~= nil then
			local n = tonumber(payload.bots)
			if not n or n < 0 or n > 5 then
				return false, "Bots must be 0-5."
			end
			s.bots = math.floor(n)
		end
		PartyService.hooks.changed(party)
		PartyService.push(party)
		return true
	end)

	Net.handle("party.invite", function(player, payload)
		return PartyService.invite(player, tonumber(payload.userId))
	end)

	Net.handle("party.respond", function(player, payload)
		return PartyService.respond(player, payload.partyId, payload.accept == true)
	end)

	Net.handle("party.join", function(player, payload)
		return PartyService.joinByCode(player, payload.code)
	end)

	Net.handle("lobby.players", function(player)
		local list = {}
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local party = PartyService.get(p)
				table.insert(list, {
					userId = p.UserId,
					name = p.DisplayName,
					username = p.Name,
					inMyParty = party ~= nil and party == PartyService.get(player),
					inParty = party ~= nil,
					look = DataService.publicLook(p),
				})
			end
		end
		return true, list
	end)
end

return PartyService
