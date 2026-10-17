--[[
	ChatService
	The game's own chat, for everyone in a match together (or in the lobby together).

	Two kinds of line:
	  quick   one of the ready-made lines (Meta/QuickChat): fixed text, so anyone can
	          say them whatever their Roblox chat settings, and anyone can see them
	  typed   your own words: needs the Chat pass and chat switched on in your Roblox
	          settings. Every line goes through Roblox's text filter for each person
	          who reads it, and only reaches people whose settings let them chat with you.

	Staff can mute a player (AdminService); a muted player can still use quick lines.
	Each person's last few lines stay on this server for a while, so a report
	(AdminService, "chat.report") can show staff what they said: filtered for everyone,
	never the raw text.

	Pushes "chat.line" { from, name, text, quick?, seat?, staff?, voice, character } to
	everyone who hears it. The screen pops it as a bubble over the speaker's character
	(in a match) or their party card (in the lobby) and reads it out in their voice.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local QuickChat = require(ReplicatedStorage.Shared.Meta.QuickChat)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local ChatService = {}

local canChatCache: { [number]: boolean } = {}
local buckets: { [Player]: { tokens: number, t: number } } = {}
local muted: { [number]: number } = {} -- [userId] = os.time() when the mute ends
local said: { [number]: { name: string, lines: { any } } } = {} -- [userId] = their latest lines
local staffTag: (Player) -> string? = function()
	return nil
end

-- Whether Roblox lets this account chat at all (asked once per player).
local function canChat(player: Player): boolean
	local cached = canChatCache[player.UserId]
	if cached ~= nil then
		return cached
	end
	local allowed = false
	if ServerInfo.isStudio then
		allowed = true
	else
		local ok, result = pcall(function()
			return TextChatService:CanUserChatAsync(player.UserId)
		end)
		allowed = ok and result == true
	end
	canChatCache[player.UserId] = allowed
	return allowed
end
ChatService.canChat = canChat

-- Whether these two may chat with each other (blocks, parental controls).
local function canChatTogether(a: Player, b: Player): boolean
	if a == b or ServerInfo.isStudio then
		return true
	end
	local ok, result = pcall(function()
		return TextChatService:CanUsersChatAsync(a.UserId, b.UserId)
	end)
	return ok and result == true
end

local function allow(player: Player): boolean
	local now = os.clock()
	local cfg = Config.Chat
	local b = buckets[player]
	if not b then
		b = { tokens = cfg.Burst, t = now }
		buckets[player] = b
	end
	b.tokens = math.min(cfg.Burst, b.tokens + (now - b.t) / cfg.Cooldown)
	b.t = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Who hears this player: the people in their match (players and spectators), or
-- everyone in the lobby. Also the seat they speak from and the character they're
-- playing (for their voice).
local function audience(player: Player): ({ Player }, number?, string)
	local match = MatchService.get(player)
	if match then
		local seat = match.seatOf[player]
		local p = seat and match.engine and match.engine.players[seat]
		return match:audience(), seat, (p and p.character) or DataService.selectedCharacter(player)
	end
	local list = {}
	for _, p in Players:GetPlayers() do
		if not MatchService.get(p) then
			table.insert(list, p)
		end
	end
	return list, nil, DataService.selectedCharacter(player)
end


local function remember(player: Player, text: string, result: any)
	local entry = said[player.UserId]
	if not entry then
		entry = { name = player.Name, lines = {} }
		said[player.UserId] = entry
	end
	table.insert(entry.lines, { t = os.time(), text = text, result = result })
	while #entry.lines > Config.Staff.ReportLines do
		table.remove(entry.lines, 1)
	end
end

-- Someone's latest lines the way everyone may see them, for a report: their name (if
-- they've said anything here) and { { t, text } }. Yields: typed lines are filtered.
function ChatService.recent(userId: number): (string?, { { t: number, text: string } })
	local entry = said[userId]
	if not entry then
		return nil, {}
	end
	local out = {}
	for _, l in entry.lines do
		local text = l.text
		if l.result == nil then
			text = "[quick line] " .. text
		elseif not ServerInfo.isStudio then
			local ok, shown = pcall(function()
				return l.result:GetNonChatStringForBroadcastAsync()
			end)
			text = if ok and type(shown) == "string" then shown else "(couldn't show this line)"
		end
		table.insert(out, { t = l.t, text = text })
	end
	return entry.name, out
end

function ChatService.isMuted(player: Player): boolean
	local untilT = muted[player.UserId]
	return untilT ~= nil and os.time() < untilT
end

function ChatService.mute(userId: number, minutes: number?)
	if minutes and minutes > 0 then
		muted[userId] = os.time() + math.floor(minutes * 60)
	else
		muted[userId] = nil
	end
end

-- AdminService hands over who wears a staff tag.
function ChatService.setStaffTagger(fn: (Player) -> string?)
	staffTag = fn
end

-- The chat status a client needs to draw its chat box.
function ChatService.status(player: Player)
	return {
		allowed = canChat(player),
		pass = DataService.hasPass(player, "Chat"),
		muted = ChatService.isMuted(player),
	}
end

local function send(player: Player, payload): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "Nothing to say."
	end
	if not allow(player) then
		return false, "Slow down a little!"
	end
	local list, seat, character = audience(player)
	local base = {
		from = player.UserId,
		name = player.DisplayName,
		seat = seat,
		staff = staffTag(player),
		voice = DataService.voiceOf(player),
		character = character,
	}
	if payload.quick ~= nil then
		local q = QuickChat.get(payload.quick)
		if not q then
			return false, "Unknown line."
		end
		local line = table.clone(base)
		line.text = q.text
		line.quick = q.id
		for _, p in list do
			Net.push(p, "chat.line", line)
		end
		remember(player, q.text, nil)
		return true
	end
	-- typed lines
	local text = payload.text
	if type(text) ~= "string" then
		return false, "Nothing to say."
	end
	text = string.gsub(text, "[%c]", " ")
	text = string.match(text, "^%s*(.-)%s*$") or ""
	if #text == 0 then
		return false, "Nothing to say."
	end
	if #text > Config.Chat.MaxLength then
		text = string.sub(text, 1, Config.Chat.MaxLength)
	end
	if not DataService.hasPass(player, "Chat") then
		return false, "Typing your own lines needs the Chat pass. Quick lines are free!"
	end
	if not canChat(player) then
		return false, "Chat is off in your Roblox settings. Quick lines still work!"
	end
	if ChatService.isMuted(player) then
		return false, "You're muted for now. Quick lines still work."
	end
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok or not filtered then
		return false, "Couldn't send that. Try again."
	end
	remember(player, text, filtered)
	for _, p in list do
		if p == player or (canChat(p) and canChatTogether(player, p)) then
			local okFor, shown = pcall(function()
				return (filtered :: any):GetChatForUserAsync(p.UserId)
			end)
			if okFor and type(shown) == "string" and #shown > 0 then
				local line = table.clone(base)
				line.text = shown
				Net.push(p, "chat.line", line)
			end
		end
	end
	return true
end

function ChatService.init()
	Net.handle("chat.send", send)
	Net.handle("chat.status", function(player)
		return true, ChatService.status(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		canChatCache[player.UserId] = nil
		-- their lines stay a while, for anyone reporting them just after they left
		local id = player.UserId
		task.delay(600, function()
			if not Players:GetPlayerByUserId(id) then
				said[id] = nil
			end
		end)
	end)
end

return ChatService
