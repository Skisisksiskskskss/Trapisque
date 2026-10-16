--[[
	AdminService
	The staff panel's server side. Two roles:

	  owner   the game's creator (the group's owner for a group game), plus anyone in
	          Config.Staff.OwnerIds. Can do everything below.
	  admin   people the owner picks in the panel (kept in a DataStore, so it lasts).
	          Can keep the peace: kick, mute, ban for up to Config.Staff.AdminMaxBanHours,
	          unban, announce to this server, end a stuck match, look players up.

	The owner can also give anyone (online or not) gamepasses, Gems, free chests, any
	cosmetic or the whole collection; ban for good; make or remove admins; announce to
	every server; give everyone on a server Gems or a chest; switch the weekly event; and
	shut every server down (for an update). Gifts to someone who's offline wait in the
	DataStore and land the next time they join.

	Every action is checked here (the client only shows buttons), logged (the last 100
	are kept), and shared with the other servers over MessagingService.

	Requests: "staff.state" -> what the panel shows; "staff.do" { action, target?, ... }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local GroupService = game:GetService("GroupService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Passes = require(Shared.Meta.Passes)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Progress = require(Shared.Meta.Progress)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local ChatService = require(script.Parent.ChatService)

local AdminService = {}

local S = Config.Staff
local store: DataStore? = nil
local admins: { [string]: { name: string, by: string, at: number } } = {} -- keyed by tostring(userId)
local bans: { [string]: { name: string, reason: string, by: string, at: number, untilT: number } } = {}
local log: { any } = {}
local groupOwner: { [Player]: boolean } = {}
local groupOwnerId: number? = nil

---------------------------------------------------------------------------
-- roles
---------------------------------------------------------------------------

local function isOwner(player: Player): boolean
	if ServerInfo.isStudio and S.StudioIsOwner then
		return true
	end
	if table.find(S.OwnerIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId and player.UserId > 0
	end
	return groupOwner[player] == true
end

function AdminService.role(player: Player): string?
	if isOwner(player) then
		return "owner"
	end
	if admins[tostring(player.UserId)] then
		return "admin"
	end
	return nil
end

---------------------------------------------------------------------------
-- storage and the other servers
---------------------------------------------------------------------------

local function load(key: string, default: any): any
	if not store then
		return default
	end
	local ok, value = pcall(function()
		return (store :: DataStore):GetAsync(key)
	end)
	return if ok and value ~= nil then value else default
end

local function update(key: string, fn: (any) -> any)
	if not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync(key, fn)
	end)
end

-- Tells the other servers (this one acts on its own; its copy is ignored).
local function publish(message)
	message.origin = game.JobId
	pcall(function()
		MessagingService:PublishAsync(S.Topic, message)
	end)
end

local function record(by: Player, action: string, target: string?, detail: string?)
	local entry = { t = os.time(), by = by.Name, action = action, target = target, detail = detail }
	table.insert(log, 1, entry)
	while #log > 100 do
		table.remove(log)
	end
	update("log", function(old)
		local list = old or {}
		table.insert(list, 1, entry)
		while #list > 100 do
			table.remove(list)
		end
		return list
	end)
end

-- Text the owner or an admin writes for everyone (announcements, ban reasons) still
-- goes through the filter.
local function filterBroadcast(player: Player, text: string): string?
	if ServerInfo.isStudio then
		return text
	end
	local ok, result = pcall(function()
		local f = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return f:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

local function banned(userId: number)
	local b = bans[tostring(userId)]
	if b and (b.untilT == 0 or os.time() < b.untilT) then
		return b
	end
	return nil
end

local function banMessage(b): string
	local length = if b.untilT == 0 then "for good" else ("until " .. os.date("!%Y-%m-%d %H:%M UTC", b.untilT))
	return "You're banned from Trapisque " .. length .. (if b.reason ~= "" then (". Reason: " .. b.reason) else ".")
end

local function announceHere(text: string, by: string?)
	for _, p in Players:GetPlayers() do
		Net.push(p, "staff.announce", { text = text, by = by })
	end
end

local function setEvent(id: string?)
	Progress.eventOverride = id
	ReplicatedStorage:SetAttribute("TrapisqueEvent", id or "")
end

-- Gifts for someone who's offline (or on another server) wait here until they join.
local function queueGift(userId: number, gift)
	update("pending_" .. userId, function(old)
		local list = old or {}
		table.insert(list, gift)
		return list
	end)
	publish({ kind = "gift", userId = userId })
end

local function applyGift(player: Player, gift): boolean
	local kind = gift.kind
	if kind == "pass" then
		return DataService.grantPass(player, gift.key, gift.on ~= false)
	elseif kind == "gems" then
		DataService.addGems(player, gift.amount or 0)
		DataService.pushProfile(player)
		return true
	elseif kind == "chests" then
		return DataService.giveChests(player, gift.chest or "explorer", gift.count or 1)
	elseif kind == "item" then
		return DataService.giveItem(player, gift.item)
	elseif kind == "everything" then
		return DataService.giveEverything(player)
	end
	return false
end

local function applyPending(player: Player)
	if not store then
		return
	end
	local gifts = nil
	pcall(function()
		(store :: DataStore):UpdateAsync("pending_" .. player.UserId, function(old)
			gifts = old
			return {} -- taken (returning nil would cancel the write and leave them there)
		end)
	end)
	if type(gifts) == "table" and #gifts > 0 then
		DataService.waitFor(player, 20)
		for _, gift in gifts do
			applyGift(player, gift)
		end
		Net.push(player, "toast", { text = "You got a gift from the Trapisque crew!", kind = "reward" })
	end
end

local function onMessage(message)
	local m = message and message.Data
	if type(m) ~= "table" or m.origin == game.JobId then
		return
	end
	if m.kind == "admins" then
		admins = load("admins", {})
	elseif m.kind == "bans" then
		bans = load("bans", {})
		for _, p in Players:GetPlayers() do
			local b = banned(p.UserId)
			if b then
				p:Kick(banMessage(b))
			end
		end
	elseif m.kind == "announce" and type(m.text) == "string" then
		announceHere(m.text, m.by)
	elseif m.kind == "kick" and type(m.userId) == "number" then
		local p = Players:GetPlayerByUserId(m.userId)
		if p then
			p:Kick(m.reason or "You were removed from the game.")
		end
	elseif m.kind == "mute" and type(m.userId) == "number" then
		ChatService.mute(m.userId, m.minutes)
	elseif m.kind == "event" then
		setEvent(if type(m.id) == "string" and m.id ~= "" then m.id else nil)
	elseif m.kind == "gift" and type(m.userId) == "number" then
		local p = Players:GetPlayerByUserId(m.userId)
		if p then
			task.spawn(applyPending, p)
		end
	elseif m.kind == "shutdown" then
		local text = if type(m.text) == "string" then m.text else "Trapisque is updating. Rejoin in a minute!"
		announceHere(text, nil)
		task.delay(8, function()
			for _, p in Players:GetPlayers() do
				p:Kick(text)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- the panel
---------------------------------------------------------------------------

local function target(payload): (Player?, number?)
	local id = tonumber(payload.target)
	if not id then
		return nil, nil
	end
	return Players:GetPlayerByUserId(id), id
end

local function stateFor(player: Player)
	local role = AdminService.role(player)
	local players = {}
	for _, p in Players:GetPlayers() do
		local info = DataService.summary(p)
		info.role = AdminService.role(p)
		info.muted = ChatService.isMuted(p)
		local match = MatchService.get(p)
		info.inMatch = match ~= nil
		table.insert(players, info)
	end
	local banList = {}
	for id, b in bans do
		if b.untilT == 0 or os.time() < b.untilT then
			table.insert(banList, { userId = tonumber(id), name = b.name, reason = b.reason, by = b.by, untilT = b.untilT })
		end
	end
	local adminList = {}
	if role == "owner" then
		for id, a in admins do
			table.insert(adminList, { userId = tonumber(id), name = a.name, by = a.by, at = a.at })
		end
	end
	return {
		role = role,
		players = players,
		bans = banList,
		admins = adminList,
		log = log,
		event = Progress.eventOverride,
		maxBanHours = if role == "owner" then 0 else S.AdminMaxBanHours,
	}
end

-- [action] = "admin" (admins and the owner) or "owner" (the owner only)
local ACCESS = {
	kick = "admin",
	ban = "admin",
	unban = "admin",
	mute = "admin",
	unmute = "admin",
	announce = "admin",
	endMatch = "admin",
	lookup = "admin",
	givePass = "owner",
	gems = "owner",
	chests = "owner",
	item = "owner",
	everything = "owner",
	setAdmin = "owner",
	announceAll = "owner",
	gemRain = "owner",
	chestRain = "owner",
	event = "owner",
	shutdown = "owner",
}

local function act(player: Player, payload): (boolean, any)
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		return false, "Bad request."
	end
	local role = AdminService.role(player)
	local need = ACCESS[payload.action]
	if not role or not need or (need == "owner" and role ~= "owner") then
		return false, "You can't do that."
	end
	local action = payload.action
	local who, userId = target(payload)
	local whoName = if who then who.Name else (if type(payload.name) == "string" then payload.name else tostring(userId))

	-- nobody can be kicked, banned or muted by an admin if they're staff themselves
	if (action == "kick" or action == "ban" or action == "mute") and userId then
		local staff = if who then AdminService.role(who) else (if admins[tostring(userId)] then "admin" else nil)
		if staff == "owner" or (staff == "admin" and role ~= "owner") or userId == player.UserId then
			return false, "You can't do that to them."
		end
	end

	if action == "lookup" then
		local name = payload.name
		if type(name) ~= "string" or #name < 2 or #name > 30 then
			return false, "Type a username."
		end
		local ok, id = pcall(function()
			return Players:GetUserIdFromNameAsync(name)
		end)
		if not ok or not id then
			return false, "No player called " .. name .. "."
		end
		return true, { userId = id, name = name, online = Players:GetPlayerByUserId(id) ~= nil, banned = banned(id) ~= nil }
	elseif action == "kick" then
		if not userId then
			return false, "Pick a player."
		end
		local reason = filterBroadcast(player, tostring(payload.reason or "")) or ""
		local text = "You were removed from the game" .. (if reason ~= "" then (": " .. reason) else ".")
		if who then
			who:Kick(text)
		else
			publish({ kind = "kick", userId = userId, reason = text })
		end
		record(player, "kick", whoName, reason)
		return true
	elseif action == "ban" then
		if not userId then
			return false, "Pick a player."
		end
		local hours = math.max(0, math.floor(tonumber(payload.hours) or 0))
		if role ~= "owner" then
			if hours == 0 or hours > S.AdminMaxBanHours then
				return false, "Admins can ban for 1 to " .. S.AdminMaxBanHours .. " hours."
			end
		end
		local reason = filterBroadcast(player, tostring(payload.reason or "")) or ""
		local entry = { name = whoName, reason = reason, by = player.Name, at = os.time(), untilT = if hours == 0 then 0 else os.time() + hours * 3600 }
		bans[tostring(userId)] = entry
		update("bans", function(old)
			local all = old or {}
			all[tostring(userId)] = entry
			return all
		end)
		publish({ kind = "bans" })
		if who then
			who:Kick(banMessage(entry))
		end
		record(player, "ban", whoName, (if hours == 0 then "for good" else (hours .. "h")) .. (if reason ~= "" then (": " .. reason) else ""))
		return true
	elseif action == "unban" then
		if not userId then
			return false, "Pick a player."
		end
		bans[tostring(userId)] = nil
		update("bans", function(old)
			local all = old or {}
			all[tostring(userId)] = nil
			return all
		end)
		publish({ kind = "bans" })
		record(player, "unban", whoName)
		return true
	elseif action == "mute" or action == "unmute" then
		if not userId then
			return false, "Pick a player."
		end
		local minutes = if action == "mute" then math.clamp(math.floor(tonumber(payload.minutes) or 10), 1, 7 * 24 * 60) else nil
		ChatService.mute(userId, minutes)
		publish({ kind = "mute", userId = userId, minutes = minutes })
		if who then
			Net.push(who, "toast", { text = if minutes then ("You've been muted for " .. minutes .. " minutes.") else "You can chat again.", kind = "info" })
		end
		record(player, action, whoName, if minutes then (minutes .. " min") else nil)
		return true
	elseif action == "announce" or action == "announceAll" then
		local text = filterBroadcast(player, string.sub(tostring(payload.text or ""), 1, 200))
		if not text or text == "" then
			return false, "Write something to announce."
		end
		if action == "announceAll" then
			publish({ kind = "announce", text = text, by = player.DisplayName })
		end
		announceHere(text, player.DisplayName)
		record(player, action, nil, text)
		return true
	elseif action == "endMatch" then
		if not who then
			return false, "They have to be on this server."
		end
		local match = MatchService.get(who)
		if not match then
			return false, "They're not in a match."
		end
		match:close("staff")
		record(player, "endMatch", whoName)
		return true
	elseif action == "givePass" or action == "gems" or action == "chests" or action == "item" or action == "everything" then
		if not userId then
			return false, "Pick a player."
		end
		local gift
		if action == "givePass" then
			if type(payload.key) ~= "string" or not Passes.byKey[payload.key] then
				return false, "Pick a gamepass."
			end
			gift = { kind = "pass", key = payload.key, on = payload.on ~= false }
		elseif action == "gems" then
			local amount = math.floor(tonumber(payload.amount) or 0)
			if amount == 0 or math.abs(amount) > 1000000 then
				return false, "Pick an amount."
			end
			gift = { kind = "gems", amount = amount }
		elseif action == "chests" then
			gift = { kind = "chests", chest = if payload.chest == "royal" then "royal" else "explorer", count = math.clamp(math.floor(tonumber(payload.count) or 1), 1, 100) }
		elseif action == "item" then
			if type(payload.item) ~= "string" or not Cosmetics.get(payload.item) then
				return false, "Pick an item."
			end
			gift = { kind = "item", item = payload.item }
		else
			gift = { kind = "everything" }
		end
		if who and DataService.isLoaded(who) then
			if not applyGift(who, gift) then
				return false, "That didn't work."
			end
			Net.push(who, "toast", { text = "You got a gift from the Trapisque crew!", kind = "reward" })
		else
			queueGift(userId, gift)
		end
		record(player, action, whoName, gift.key or gift.item or (gift.amount and tostring(gift.amount)) or gift.chest)
		return true, { queued = who == nil }
	elseif action == "setAdmin" then
		if not userId then
			return false, "Pick a player."
		end
		local on = payload.on ~= false
		local entry = if on then { name = whoName, by = player.Name, at = os.time() } else nil
		admins[tostring(userId)] = entry
		update("admins", function(old)
			local all = old or {}
			all[tostring(userId)] = entry
			return all
		end)
		publish({ kind = "admins" })
		if who then
			Net.push(who, "staff.role", { role = AdminService.role(who) })
		end
		record(player, if on then "makeAdmin" else "removeAdmin", whoName)
		return true
	elseif action == "gemRain" or action == "chestRain" then
		local amount = math.clamp(math.floor(tonumber(payload.amount) or 50), 1, 10000)
		for _, p in Players:GetPlayers() do
			if DataService.isLoaded(p) then
				if action == "gemRain" then
					applyGift(p, { kind = "gems", amount = amount })
				else
					applyGift(p, { kind = "chests", chest = "explorer", count = 1 })
				end
				Net.push(p, "toast", { text = if action == "gemRain" then ("Gem rain! +" .. amount .. " Gems for everyone!") else "A free Explorer Chest for everyone!", kind = "reward" })
			end
		end
		record(player, action, nil, if action == "gemRain" then tostring(amount) else nil)
		return true
	elseif action == "event" then
		local id = payload.id
		if id ~= nil and (type(id) ~= "string" or not Progress.eventById(id)) then
			return false, "Pick an event."
		end
		setEvent(id)
		publish({ kind = "event", id = id or "" })
		record(player, "event", nil, id or "back to the weekly rotation")
		return true
	elseif action == "shutdown" then
		local text = filterBroadcast(player, string.sub(tostring(payload.text or ""), 1, 200))
		if not text or text == "" then
			text = "Trapisque is updating. Rejoin in a minute!"
		end
		record(player, "shutdown", nil, text)
		publish({ kind = "shutdown", text = text })
		onMessage({ Data = { kind = "shutdown", text = text, origin = "here" } })
		return true
	end
	return false, "Unknown action."
end

function AdminService.init()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(S.StoreName)
	end)
	if ok then
		store = ds
		if ServerInfo.isStudio then
			local probe = pcall(function()
				ds:GetAsync("__probe")
			end)
			if not probe then
				store = nil
			end
		end
	end
	admins = load("admins", {})
	bans = load("bans", {})
	log = load("log", {})
	pcall(function()
		MessagingService:SubscribeAsync(S.Topic, onMessage)
	end)

	ChatService.setStaffTagger(function(p)
		local r = AdminService.role(p)
		return if r == "owner" then "OWNER" elseif r == "admin" then "ADMIN" else nil
	end)

	local function onJoin(player: Player)
		local b = banned(player.UserId)
		if b then
			player:Kick(banMessage(b))
			return
		end
		if game.CreatorType == Enum.CreatorType.Group then
			-- a group game's owner is the group's owner
			if groupOwnerId == nil then
				local okInfo, info = pcall(function()
					return GroupService:GetGroupInfoAsync(game.CreatorId)
				end)
				groupOwnerId = if okInfo and type(info) == "table" and type(info.Owner) == "table" then info.Owner.Id else nil
			end
			groupOwner[player] = groupOwnerId ~= nil and player.UserId == groupOwnerId
		end
		applyPending(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		groupOwner[player] = nil
	end)

	Net.handle("staff.state", function(player)
		if not AdminService.role(player) then
			return false, "Staff only."
		end
		return true, stateFor(player)
	end)
	Net.handle("staff.do", act)
end

return AdminService
