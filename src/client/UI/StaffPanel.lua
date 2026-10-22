--[[
	StaffPanel
	The owner's panel and the admins' panel (one panel; it shows what your role allows).
	The server (AdminService) checks every action again: this only draws it.

	  Players   everyone on this server; Manage opens their sheet
	  Reports   chat reports from players (on every server), with the person's last lines
	  Find      anyone by username, online or not (gifts wait for them to join)
	  Server    announcements; the owner's gem rain, chest rain, weekly event, shutdown
	  Admins    (owner) who's an admin
	  Bans      who's banned and until when
	  Log       what staff did lately

	A player's sheet: mute, kick, ban (admins up to 72 hours, the owner for good), end
	their match; the owner also gives gamepasses (or takes them back), Gems, free
	chests, any item or the whole collection, and makes or removes admins.

		StaffPanel.open(layer)
		StaffPanel.announce(data)   -- the "staff.announce" banner everyone sees
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Passes = require(Shared.Meta.Passes)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)
local Layout = require(UI.Layout)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local StaffPanel = {}

local function act(payload): (boolean, any)
	local ok, result = Net.request("staff.do", payload)
	if ok then
		local queued = type(result) == "table" and result.queued
		Widgets.toast(if queued then "Done! They'll get it next time they join." else "Done!", "reward")
	else
		Widgets.toast(tostring(result), "error")
	end
	return ok, result
end

local function heading(parent: Instance, text: string, order: number)
	Widgets.label(parent, {
		text = text,
		font = "chunky",
		size = 20,
		color = C.text,
		sizeUDim = UDim2.new(1, -8, 0, 26),
		layoutOrder = order,
	})
end

local function note(parent: Instance, text: string, order: number)
	local l = Widgets.label(parent, {
		text = text,
		font = "body",
		size = 15,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, -8, 0, 0),
		layoutOrder = order,
	})
	l.AutomaticSize = Enum.AutomaticSize.Y
	return l
end

-- A wrapping row of buttons: { { text, style?, onClick } }
local function buttons(parent: Instance, list, order: number, w: number?)
	local row = Util.frame(parent, {
		Name = "Buttons",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(w or 150, 42),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local made = {}
	for i, b in list do
		made[i] = Widgets.button(row, {
			text = b.text,
			style = b.style or "panel",
			textSize = 16,
			font = "heavy",
			depth = 3,
			layoutOrder = i,
			onClick = b.onClick,
		})
	end
	return row, made
end

local function textRow(parent: Instance, placeholder: string, order: number, maxLength: number?): TextBox
	local box = Widgets.textBox(parent, {
		placeholder = placeholder,
		textSize = 17,
		maxLength = maxLength or 200,
		size = UDim2.new(1, -8, 0, 44),
		layoutOrder = order,
	})
	box.TextXAlignment = Enum.TextXAlignment.Left
	Util.pad(box, 12, 0, 12, 0)
	return box
end

-- A small confirm box; `yes` runs if they press the button.
local function confirm(layer: Instance, text: string, button: string, yes: () -> ())
	local content, close = Widgets.modal(layer, { title = "Sure?", titleWidth = 180, width = 460, height = 240 })
	Widgets.label(content, {
		text = text,
		font = "heavy",
		size = 18,
		color = C.text,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 70),
	})
	Widgets.button(content, {
		text = button,
		style = "red",
		textSize = 20,
		size = UDim2.fromOffset(200, 50),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			close()
			yes()
		end,
	})
end

---------------------------------------------------------------------------
-- a player's sheet
---------------------------------------------------------------------------

local function sheet(layer: Instance, role: string, who, refresh: () -> ())
	local roomW, roomH = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = who.name or "Player",
		titleWidth = 300,
		width = math.min(720, roomW),
		height = math.min(600, roomH),
	})
	local body = Widgets.scroll(content, { gap = 10, padding = 6, hAlign = "Left" })
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local target = who.userId
	local function run(payload)
		payload.target = target
		payload.name = who.username or who.name
		local ok = act(payload)
		if ok then
			refresh()
		end
		return ok
	end

	-- who they are
	local info = {}
	if who.username then
		table.insert(info, "@" .. who.username)
	end
	table.insert(info, "id " .. tostring(target))
	if who.level then
		table.insert(info, "level " .. who.level)
		table.insert(info, Util.commas(who.gems or 0) .. " Gems")
		table.insert(info, (who.wins or 0) .. " wins in " .. (who.games or 0) .. " games")
		table.insert(info, (who.owned or 0) .. " items")
	end
	if who.role then
		table.insert(info, string.upper(who.role))
	end
	if who.muted then
		table.insert(info, "MUTED")
	end
	if who.inMatch then
		table.insert(info, "in a match")
	end
	if who.online == false then
		table.insert(info, "not on this server")
	end
	note(body, table.concat(info, "  ·  "), nextOrder())
	if who.passes and #who.passes > 0 then
		note(body, "Gamepasses: " .. table.concat(who.passes, ", "), nextOrder())
	end

	-- keeping the peace
	heading(body, "Chat", nextOrder())
	buttons(body, {
		{ text = "MUTE 10 MIN", onClick = function()
			run({ action = "mute", minutes = 10 })
		end },
		{ text = "MUTE 1 HOUR", onClick = function()
			run({ action = "mute", minutes = 60 })
		end },
		{ text = "MUTE 1 DAY", onClick = function()
			run({ action = "mute", minutes = 1440 })
		end },
		{ text = "UNMUTE", style = "green", onClick = function()
			run({ action = "unmute" })
		end },
	}, nextOrder())

	heading(body, "Kick or ban", nextOrder())
	local reason = textRow(body, "Reason (they'll see it)", nextOrder(), 120)
	local bans = {
		{ text = "KICK", style = "orange", onClick = function()
			run({ action = "kick", reason = reason.Text })
		end },
		{ text = "BAN 1 HOUR", style = "red", onClick = function()
			run({ action = "ban", hours = 1, reason = reason.Text })
		end },
		{ text = "BAN 1 DAY", style = "red", onClick = function()
			run({ action = "ban", hours = 24, reason = reason.Text })
		end },
		{ text = "BAN 3 DAYS", style = "red", onClick = function()
			run({ action = "ban", hours = 72, reason = reason.Text })
		end },
	}
	if role == "owner" then
		table.insert(bans, { text = "BAN FOR GOOD", style = "red", onClick = function()
			confirm(layer, "Ban " .. (who.name or "them") .. " for good?", "BAN", function()
				run({ action = "ban", hours = 0, reason = reason.Text })
			end)
		end })
	end
	table.insert(bans, { text = "UNBAN", style = "green", onClick = function()
		run({ action = "unban" })
	end })
	if who.inMatch then
		table.insert(bans, { text = "END THEIR MATCH", onClick = function()
			confirm(layer, "End the match " .. (who.name or "they") .. " is in, for everyone in it?", "END IT", function()
				run({ action = "endMatch" })
			end)
		end })
	end
	buttons(body, bans, nextOrder())

	if role ~= "owner" then
		return close
	end

	-- the owner's gifts
	heading(body, "Gamepasses", nextOrder())
	note(body, "Gives the pass's perks without a purchase (or takes a given one back). Passes they bought stay theirs.", nextOrder())
	local granted = {}
	for _, key in who.granted or {} do
		granted[key] = true
	end
	local bought = {}
	for _, key in who.passes or {} do
		if not granted[key] then
			bought[key] = true
		end
	end
	local passButtons = {}
	for _, pass in Passes.list do
		local has = granted[pass.key] or bought[pass.key]
		table.insert(passButtons, {
			text = if has then (string.upper(pass.name) .. ": ON") else ("GIVE " .. string.upper(pass.name)),
			style = if has then "green" else "panel",
			onClick = function()
				if bought[pass.key] then
					Widgets.toast("They bought that one: it stays theirs.", "info")
					return
				end
				local on = not granted[pass.key]
				if run({ action = "givePass", key = pass.key, on = on }) then
					granted[pass.key] = if on then true else nil
				end
			end,
		})
	end
	buttons(body, passButtons, nextOrder(), 170)

	heading(body, "Gems and chests", nextOrder())
	buttons(body, {
		{ text = "+100 GEMS", onClick = function()
			run({ action = "gems", amount = 100 })
		end },
		{ text = "+1,000 GEMS", onClick = function()
			run({ action = "gems", amount = 1000 })
		end },
		{ text = "+10,000 GEMS", onClick = function()
			run({ action = "gems", amount = 10000 })
		end },
		{ text = "-1,000 GEMS", style = "orange", onClick = function()
			run({ action = "gems", amount = -1000 })
		end },
		{ text = "+1 EXPLORER CHEST", onClick = function()
			run({ action = "chests", chest = "explorer", count = 1 })
		end },
		{ text = "+5 EXPLORER CHESTS", onClick = function()
			run({ action = "chests", chest = "explorer", count = 5 })
		end },
		{ text = "+1 ROYAL CHEST", onClick = function()
			run({ action = "chests", chest = "royal", count = 1 })
		end },
	}, nextOrder(), 170)

	heading(body, "Items", nextOrder())
	local search = textRow(body, "Search items by name...", nextOrder(), 40)
	local results = Util.frame(body, {
		Name = "Items",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
	})
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 40),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = results,
	})
	local function showItems()
		Util.clear(results, true)
		local q = string.lower(search.Text)
		local shown = 0
		for _, def in Cosmetics.list do
			if shown >= 24 then
				break
			end
			if q == "" or string.find(string.lower(def.name), q, 1, true) then
				shown += 1
				local rarity = Cosmetics.rarityById[def.rarity or ""]
				Widgets.button(results, {
					text = def.name,
					style = "panel",
					textSize = 15,
					font = "heavy",
					depth = 3,
					layoutOrder = shown,
					onClick = function()
						run({ action = "item", item = def.id })
					end,
				}).root.Name = def.id
				local _ = rarity
			end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(showItems)
	showItems()
	buttons(body, {
		{ text = "GIVE EVERYTHING", style = "brass", onClick = function()
			confirm(layer, "Give " .. (who.name or "them") .. " every item in the game?", "GIVE ALL", function()
				run({ action = "everything" })
			end)
		end },
	}, nextOrder(), 200)

	heading(body, "Admin", nextOrder())
	buttons(body, {
		{ text = if who.role == "admin" then "REMOVE ADMIN" else "MAKE ADMIN", style = if who.role == "admin" then "red" else "blue", onClick = function()
			local on = who.role ~= "admin"
			if run({ action = "setAdmin", on = on }) then
				who.role = if on then "admin" else nil
			end
		end },
	}, nextOrder(), 200)
	return close
end

---------------------------------------------------------------------------
-- the panel
---------------------------------------------------------------------------

local TABS = {
	{ id = "players", text = "PLAYERS" },
	{ id = "reports", text = "REPORTS" },
	{ id = "find", text = "FIND" },
	{ id = "server", text = "SERVER" },
	{ id = "admins", text = "ADMINS", owner = true },
	{ id = "bans", text = "BANS" },
	{ id = "log", text = "LOG" },
}

function StaffPanel.open(layer: Instance)
	local role = State.get("staff")
	if not role then
		return
	end
	local roomW, roomH, narrow = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = if role == "owner" then "Owner panel" else "Admin panel",
		titleWidth = 300,
		width = math.min(960, roomW),
		height = math.min(640, roomH),
	})
	local state = nil
	local tab = "players"

	local tabs = Util.frame(content, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 44) })
	Util.list(tabs, "x", 8, "Left", "Center").SortOrder = Enum.SortOrder.LayoutOrder
	local page = Util.frame(content, {
		Name = "Page",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
	})
	local tabButtons = {}

	local render: () -> ()

	local function refresh()
		local ok, data = Net.request("staff.state")
		if ok then
			state = data
			if data.role ~= role then
				role = data.role
				State.set("staff", role)
			end
			render()
		else
			Widgets.toast(tostring(data), "error")
		end
	end

	local function playerRow(list: Instance, i: number, p, onManage: () -> ())
		local row = Util.new("Frame", {
			Name = "Player" .. i,
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -10, 0, 58),
			LayoutOrder = i,
			Parent = list,
		})
		Util.corner(row, 8)
		Util.stroke(row, C.panelEdge, 1.5)
		Avatars.portrait(row, { userId = p.userId, name = p.name }, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(46, 46),
		}, { ring = Theme.playerColor(p.character), ringPx = 2 })
		local tags = {}
		if p.role then
			table.insert(tags, string.upper(p.role))
		end
		if p.muted then
			table.insert(tags, "MUTED")
		end
		if p.inMatch then
			table.insert(tags, "IN A MATCH")
		end
		Widgets.label(row, {
			text = (p.name or "?") .. (if #tags > 0 then ("   " .. table.concat(tags, " · ")) else ""),
			font = "heavy",
			size = 17,
			color = C.text,
			sizeUDim = UDim2.new(1, -200, 0, 22),
			position = UDim2.fromOffset(62, 7),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local detail = if p.loading then "loading..." elseif p.level then string.format("@%s  ·  level %d  ·  %s Gems  ·  %d wins", p.username or "?", p.level, Util.commas(p.gems or 0), p.wins or 0) else ("@" .. tostring(p.username or p.name))
		Widgets.label(row, {
			text = detail,
			font = "body",
			size = 14,
			color = C.textSoft,
			sizeUDim = UDim2.new(1, -200, 0, 18),
			position = UDim2.fromOffset(62, 31),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		Widgets.button(row, {
			text = "MANAGE",
			style = "blue",
			textSize = 16,
			depth = 3,
			size = UDim2.fromOffset(120, 42),
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0),
			onClick = onManage,
		})
	end

	local pages = {}

	function pages.players()
		local list = Widgets.scroll(page, { gap = 8, padding = 4 })
		local players = state and state.players or {}
		table.sort(players, function(a, b)
			return string.lower(a.name or "") < string.lower(b.name or "")
		end)
		for i, p in players do
			playerRow(list, i, p, function()
				sheet(layer, role, p, refresh)
			end)
		end
		if #players == 0 then
			note(list, "No one's here.", 1)
		end
	end

	function pages.reports()
		local list = Widgets.scroll(page, { gap = 10, padding = 6, hAlign = "Left" })
		local reports = state and state.reports or {}
		note(list, "What players reported from the chat, newest first, with that person's last few lines (filtered). Deal with it from MANAGE, then dismiss the report.", 0)
		if #reports == 0 then
			note(list, "No reports. Nice and quiet.", 1)
		end
		for i, r in reports do
			local card = Util.new("Frame", {
				Name = "Report" .. i,
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -10, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = list,
			})
			Util.corner(card, 8)
			Util.stroke(card, C.panelEdge, 1.5)
			Util.pad(card, 10, 8, 10, 10)
			Util.list(card, "y", 6, "Left", "Top").SortOrder = Enum.SortOrder.LayoutOrder
			heading(card, string.format("%s  ·  %s", r.target or "?", r.reason or "?"), 1)
			note(card, string.format("reported by %s  ·  %s  ·  %s", r.by or "?", os.date("%b %d %H:%M", r.t or 0), if r.where == "match" then "in a match" else "in the lobby"), 2)
			local lines = r.lines or {}
			for j, l in lines do
				note(card, os.date("%H:%M", l.t or 0) .. "   " .. tostring(l.text or ""), 2 + j)
			end
			if #lines == 0 then
				note(card, "(nothing they said is on record)", 3)
			end
			buttons(card, {
				{ text = "MANAGE", style = "blue", onClick = function()
					local who = nil
					for _, p in state and state.players or {} do
						if p.userId == r.targetId then
							who = p
						end
					end
					sheet(layer, role, who or { userId = r.targetId, name = r.target, username = r.target, online = false }, refresh)
				end },
				{ text = "DISMISS", onClick = function()
					if act({ action = "dismissReport", id = r.id }) then
						refresh()
					end
				end },
			}, 100)
		end
	end

	function pages.find()
		local body = Util.frame(page, {})
		Util.list(body, "y", 10, "Left", "Top").SortOrder = Enum.SortOrder.LayoutOrder
		note(body, "Look anyone up by their Roblox username, even if they're not playing. Bans and gifts work offline: gifts wait for them to join.", 1)
		local box = textRow(body, "Username", 2, 30)
		local result = Util.frame(body, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 4 })
		local function find()
			local name = string.gsub(box.Text, "^@", "")
			if #name < 2 then
				return
			end
			local ok, who = Net.request("staff.do", { action = "lookup", name = name })
			Util.clear(result)
			if not ok then
				Widgets.toast(tostring(who), "error")
				return
			end
			-- someone on this server: use what the server knows about them
			for _, p in state and state.players or {} do
				if p.userId == who.userId then
					who = p
					who.online = true
				end
			end
			who.username = who.username or who.name
			for _, a in state and state.admins or {} do
				if a.userId == who.userId then
					who.role = "admin"
				end
			end
			playerRow(result, 1, who, function()
				sheet(layer, role, who, refresh)
			end)
		end
		buttons(body, { { text = "FIND", style = "blue", onClick = find } }, 3)
		box.FocusLost:Connect(function(enter)
			if enter then
				find()
			end
		end)
	end

	function pages.server()
		local body = Widgets.scroll(page, { gap = 10, padding = 6, hAlign = "Left" })
		heading(body, "Announcement", 1)
		local text = textRow(body, "What should everyone see?", 2, 200)
		local list = {
			{ text = "THIS SERVER", style = "blue", onClick = function()
				act({ action = "announce", text = text.Text })
			end },
		}
		if role == "owner" then
			table.insert(list, { text = "ALL SERVERS", style = "blue", onClick = function()
				act({ action = "announceAll", text = text.Text })
			end })
		end
		buttons(body, list, 3)
		if role ~= "owner" then
			return
		end
		heading(body, "Treats for everyone here", 4)
		buttons(body, {
			{ text = "GEM RAIN +50", onClick = function()
				act({ action = "gemRain", amount = 50 })
			end },
			{ text = "GEM RAIN +250", onClick = function()
				act({ action = "gemRain", amount = 250 })
			end },
			{ text = "FREE CHEST", onClick = function()
				act({ action = "chestRain" })
			end },
		}, 5)
		heading(body, "Weekly event", 6)
		local current = state and state.event
		note(body, "Switch this week's event on every server (back to the rotation when you like). Now: " .. (if current then (Progress.eventById(current) or {}).name or current else ("rotation (" .. Progress.currentEvent().name .. ")")), 7)
		local events = {}
		for _, e in Progress.events do
			table.insert(events, { text = string.upper(e.name), style = if current == e.id then "green" else "panel", onClick = function()
				if act({ action = "event", id = e.id }) then
					refresh()
				end
			end })
		end
		table.insert(events, { text = "ROTATION", style = if current == nil then "green" else "panel", onClick = function()
			if act({ action = "event" }) then
				refresh()
			end
		end })
		buttons(body, events, 8, 170)
		heading(body, "Shut down", 9)
		note(body, "Everyone gets your message, then every server closes (for an update). Rejoining starts fresh servers.", 10)
		local msg = textRow(body, "Trapisque is updating. Rejoin in a minute!", 11, 200)
		buttons(body, {
			{ text = "SHUT DOWN ALL", style = "red", onClick = function()
				confirm(layer, "Close every Trapisque server now?", "SHUT DOWN", function()
					act({ action = "shutdown", text = msg.Text })
				end)
			end },
		}, 12, 200)
	end

	function pages.admins()
		local list = Widgets.scroll(page, { gap = 8, padding = 4 })
		note(list, "Admins can mute, kick, ban for up to 3 days, end a stuck match and announce on their server. Find someone to make them an admin.", 0)
		for i, a in state and state.admins or {} do
			local row = Util.frame(list, { Size = UDim2.new(1, -10, 0, 48), LayoutOrder = i })
			Widgets.label(row, {
				text = string.format("%s  (id %d, made admin by %s)", a.name or "?", a.userId or 0, a.by or "?"),
				font = "heavy",
				size = 16,
				color = C.text,
				sizeUDim = UDim2.new(1, -150, 1, 0),
			}).TextTruncate = Enum.TextTruncate.AtEnd
			Widgets.button(row, {
				text = "REMOVE",
				style = "red",
				textSize = 16,
				depth = 3,
				size = UDim2.fromOffset(130, 42),
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, 0, 0.5, 0),
				onClick = function()
					if act({ action = "setAdmin", target = a.userId, name = a.name, on = false }) then
						refresh()
					end
				end,
			})
		end
	end

	function pages.bans()
		local list = Widgets.scroll(page, { gap = 8, padding = 4 })
		local bans = state and state.bans or {}
		if #bans == 0 then
			note(list, "Nobody's banned.", 0)
		end
		for i, b in bans do
			local row = Util.frame(list, { Size = UDim2.new(1, -10, 0, 52), LayoutOrder = i })
			local untilText = if b.untilT == 0 then "for good" else ("until " .. os.date("%b %d, %H:%M", b.untilT))
			Widgets.label(row, {
				text = string.format("%s  ·  %s  ·  by %s%s", b.name or tostring(b.userId), untilText, b.by or "?", if b.reason and b.reason ~= "" then ("  ·  " .. b.reason) else ""),
				font = "heavy",
				size = 15,
				color = C.text,
				wrap = true,
				sizeUDim = UDim2.new(1, -150, 1, 0),
			})
			Widgets.button(row, {
				text = "UNBAN",
				style = "green",
				textSize = 16,
				depth = 3,
				size = UDim2.fromOffset(130, 42),
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, 0, 0.5, 0),
				onClick = function()
					if act({ action = "unban", target = b.userId, name = b.name }) then
						refresh()
					end
				end,
			})
		end
	end

	function pages.log()
		local list = Widgets.scroll(page, { gap = 4, padding = 6, hAlign = "Left" })
		local log = state and state.log or {}
		if #log == 0 then
			note(list, "Nothing yet.", 0)
		end
		for i, e in log do
			note(list, string.format("%s  ·  %s  ·  %s%s%s", os.date("%b %d %H:%M", e.t or 0), e.by or "?", e.action or "?", if e.target then (" " .. e.target) else "", if e.detail and e.detail ~= "" then ("  (" .. e.detail .. ")") else ""), i)
		end
	end

	render = function()
		Util.clear(page)
		for id, b in tabButtons do
			b:setStyle(if id == tab then "brass" else "panel")
		end
		if not state then
			note(page, "Loading...", 1)
			return
		end
		local count = #(state.reports or {})
		tabButtons.reports:setText(if count > 0 then ("REPORTS " .. count) else "REPORTS")
		pages[tab]()
	end

	local shown = 0
	for _, t in TABS do
		if not (t.owner and role ~= "owner") then
			shown += 1
		end
	end
	for i, t in TABS do
		if t.owner and role ~= "owner" then
			continue
		end
		tabButtons[t.id] = Widgets.button(tabs, {
			text = t.text,
			style = "panel",
			textSize = if narrow then 13 else 16,
			depth = 3,
			size = UDim2.new(1 / shown, -8 * (shown - 1) / shown, 1, 0),
			layoutOrder = i,
			onClick = function()
				tab = t.id
				render()
			end,
		})
	end
	render()
	task.spawn(refresh)
	return close
end

---------------------------------------------------------------------------
-- announcements
---------------------------------------------------------------------------

-- The banner across the top of everyone's screen for a few seconds.
function StaffPanel.announce(layer: Instance, data)
	if type(data) ~= "table" or type(data.text) ~= "string" then
		return
	end
	local m = Widgets.metrics
	local safe = Layout.safeRect(m, 8)
	local top = math.max(m.topbar.y1, safe.y) + 10
	local w = math.min(640, safe.w)
	local banner = Util.new("Frame", {
		Name = "Announcement",
		BackgroundColor3 = C.sun,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(safe.x + safe.w / 2, top),
		Size = UDim2.fromOffset(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 300,
		Parent = layer,
	})
	Util.corner(banner, 10)
	Util.stroke(banner, C.line, 3.5)
	Util.pad(banner, 16, 10, 16, 12)
	Util.list(banner, "y", 4, "Center", "Top").SortOrder = Enum.SortOrder.LayoutOrder
	Widgets.label(banner, {
		text = "ANNOUNCEMENT" .. (if data.by then (" FROM " .. string.upper(data.by)) else ""),
		font = "chunky",
		size = 18,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 22),
		layoutOrder = 1,
		z = 301,
	})
	local text = Widgets.label(banner, {
		text = data.text,
		font = "heavy",
		size = 21,
		color = C.text,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 0),
		layoutOrder = 2,
		z = 301,
	})
	text.AutomaticSize = Enum.AutomaticSize.Y
	Util.popIn(banner, 0.35, 0.6)
	Sound.play("turn")
	task.delay(math.clamp(5 + #data.text / 15, 6, 14), function()
		if banner.Parent then
			Util.tween(Util.scaler(banner), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.22)
			banner:Destroy()
		end
	end)
end

return StaffPanel
