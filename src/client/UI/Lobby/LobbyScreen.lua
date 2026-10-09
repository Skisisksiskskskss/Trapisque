--[[
	LobbyScreen
	Home base between matches: your profile, the Play and Party panels, the Top Players
	board, the menu (Chests, Locker, Shop, How to Play, Settings), the matchmaking
	banner and party invites.

	The arrangement follows the screen (Layout.lobby) and is rebuilt when it changes
	shape: three columns on a big monitor, two on a laptop, compact panels on a phone
	held sideways (your profile then sits in the middle of Roblox's top bar), and one
	panel at a time under Play / Party / Top tabs on a phone held upright.

		LobbyScreen.show()
		LobbyScreen.invite(data)   -- server "invite" push
]]

local Players = game:GetService("Players")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)
local Avatars = require(UI.Avatars)
local Layout = require(UI.Layout)
local Root = require(UI.Root)
local PlayPanel = require(script.Parent.PlayPanel)
local PartyPanel = require(script.Parent.PartyPanel)
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
local Chests = require(script.Parent.Chests)
local Locker = require(script.Parent.Locker)
local Pages = require(script.Parent.Pages)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local LobbyScreen = {}

local player = Players.LocalPlayer
local screen = nil -- { root, popups, invites, maid }
local tab = "play" -- upright phones: the panel on show

local function place(f: GuiObject, r)
	f.Position = UDim2.fromOffset(r.x, r.y)
	f.Size = UDim2.fromOffset(r.w, r.h)
end

local function freeChests(p): number
	local free = 0
	for _, n in p and p.freeChests or {} do
		free += n
	end
	return free
end

---------------------------------------------------------------------------
-- profile chip
---------------------------------------------------------------------------

-- Gems, with a bump (and a coin sound) when they go up.
local function gemCounter(parent: Instance, size: number, maid): Frame
	local row = Util.frame(parent, {
		Name = "Gems",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(130, size + 4),
	})
	Util.list(row, "x", 6, "Right", "Center")
	local gems = Widgets.label(row, {
		text = "0",
		font = "chunky",
		size = size,
		color = C.ink,
		align = "right",
		sizeUDim = UDim2.fromOffset(0, size + 4),
		layoutOrder = 1,
	})
	gems.AutomaticSize = Enum.AutomaticSize.X
	local gemIcon = Util.frame(row, { Size = UDim2.fromOffset(size, size), LayoutOrder = 2 })
	Icons.medallion(gemIcon, "gem", C.neutral, { Size = UDim2.fromScale(1, 1) })
	local last = nil
	maid:add(State.watch("profile", function(p)
		if not p then
			return
		end
		if last and p.gems ~= last then
			Util.bump(row, 0.12)
			if p.gems > last then
				Sound.play("coin")
			end
		end
		last = p.gems
		gems.Text = Util.commas(p.gems or 0)
	end, true))
	return row
end

-- Avatar, name, title, level with its XP bar, gems.
local function profileChip(parent: Instance, maid, r): Frame
	local chip = Util.new("Frame", {
		Name = "Profile",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Parent = parent,
	})
	place(chip, r)
	Util.corner(chip, 14)
	Util.stroke(chip, C.burn, 3)
	local h = r.h
	local avatar = h - 20
	Avatars.portrait(chip, { userId = player.UserId, name = player.DisplayName }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(avatar, avatar),
	}, { ring = C.brass, ringPx = 3 })
	local x = avatar + 20
	local name = Widgets.label(chip, {
		text = player.DisplayName,
		font = "heavy",
		size = 18,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -(x + 150), 0, 20),
		position = UDim2.fromOffset(x, h / 2 - 27),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local titleHolder = Util.frame(chip, { Position = UDim2.fromOffset(x, h / 2 - 6), Size = UDim2.new(1, -(x + 150), 0, 18) })
	local level = Widgets.label(chip, {
		text = "LV 1",
		font = "chunky",
		size = 14,
		color = C.inkBlue,
		sizeUDim = UDim2.fromOffset(40, 16),
		position = UDim2.fromOffset(x, h / 2 + 13),
	})
	local xp = Widgets.progress(chip, {
		size = UDim2.new(1, -(x + 44 + 150), 0, 8),
		position = UDim2.fromOffset(x + 44, h / 2 + 17),
		color = C.info,
	})
	local gems = gemCounter(chip, 24, maid)
	gems.Position = UDim2.new(1, -16, 0.5, 0)

	local lastTitle = nil
	maid:add(State.watch("profile", function(p)
		if not p then
			return
		end
		local eq = p.equipped or {}
		if eq.title ~= lastTitle then
			lastTitle = eq.title
			Util.clear(titleHolder)
			local t = CosmeticArt.title(titleHolder, eq.title, nil, 12)
			if not t then
				Widgets.label(titleHolder, {
					text = "@" .. player.Name,
					font = "body",
					size = 13,
					color = C.inkSoft,
					sizeUDim = UDim2.fromScale(1, 1),
				})
			end
		end
		level.Text = "LV " .. tostring(p.level or 1)
		xp:set((p.xp or 0) / math.max(1, p.xpNext or 100))
	end, true))
	return chip
end

-- A slim version that fits in the middle of Roblox's top bar (phones held sideways).
local function compactChip(parent: Instance, maid, r): Frame
	local chip = Util.new("Frame", {
		Name = "Profile",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Parent = parent,
	})
	place(chip, r)
	Util.corner(chip, r.h / 2)
	Util.stroke(chip, C.burn, 2)
	local avatar = r.h - 8
	Avatars.portrait(chip, { userId = player.UserId, name = player.DisplayName }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(avatar, avatar),
	}, { ring = C.brass, ringPx = 2 })
	local x = avatar + 12
	local name = Widgets.label(chip, {
		text = player.DisplayName,
		font = "heavy",
		size = 15,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -(x + 170), 1, 0),
		position = UDim2.fromOffset(x, 0),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local level = Widgets.label(chip, {
		text = "LV 1",
		font = "chunky",
		size = 14,
		color = C.inkBlue,
		align = "right",
		anchor = Vector2.new(1, 0.5),
		sizeUDim = UDim2.fromOffset(52, 20),
		position = UDim2.new(1, -108, 0.5, 0),
	})
	local gems = gemCounter(chip, 18, maid)
	gems.Size = UDim2.fromOffset(96, 22)
	gems.Position = UDim2.new(1, -12, 0.5, 0)
	maid:add(State.watch("profile", function(p)
		if p then
			level.Text = "LV " .. tostring(p.level or 1)
		end
	end, true))
	return chip
end

---------------------------------------------------------------------------
-- menu
---------------------------------------------------------------------------

local NAV = {
	{ id = "chests", text = "CHESTS", short = "CHESTS", icon = "chest", style = "brass" },
	{ id = "locker", text = "LOCKER", short = "LOCKER", icon = "hanger", style = "wood" },
	{ id = "shop", text = "SHOP", short = "SHOP", icon = "bag", style = "wood" },
	{ id = "leaders", text = "TOP PLAYERS", short = "TOP", icon = "crown", style = "wood" },
	{ id = "rules", text = "HOW TO PLAY", short = "RULES", icon = "book", style = "wood" },
	{ id = "settings", text = "SETTINGS", short = "SETTINGS", icon = "gear", style = "wood" },
}

local function openPage(id: string, popups: Instance)
	if id == "chests" then
		Chests.open(popups)
	elseif id == "locker" then
		Locker.open(popups)
	elseif id == "shop" then
		Pages.shop(popups)
	elseif id == "leaders" then
		Pages.leaderboard(popups)
	elseif id == "rules" then
		Pages.rules(popups)
	elseif id == "settings" then
		Pages.settings(popups)
	end
end

--[[
	The menu: wide buttons with words (PC), shorter words (phones sideways), or icons
	with a small caption under each (phones upright). The Chests button turns green
	while a free chest is waiting.
]]
local function buildNav(parent: Instance, maid, spec, popups: Instance, withLeaders: boolean)
	local nav = Util.frame(parent, { Name = "Nav" })
	place(nav, spec.rect)
	local items = {}
	for _, item in NAV do
		if item.id ~= "leaders" or withLeaders then
			table.insert(items, item)
		end
	end
	local n = #items
	local gap = if spec.kind == "full" then 14 else 8
	local layout = Util.list(nav, "x", gap, "Center", "Center")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local chest = nil
	for i, item in items do
		local onClick = function()
			openPage(item.id, popups)
		end
		if spec.kind == "icon" then
			local cell = Util.frame(nav, {
				Name = item.id,
				Size = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0),
				LayoutOrder = i,
			})
			local size = spec.rect.h - 18
			local b = Widgets.iconButton(cell, {
				icon = item.icon,
				style = item.style,
				size = UDim2.fromOffset(size, size),
				anchor = Vector2.new(0.5, 0),
				position = UDim2.fromScale(0.5, 0),
				onClick = onClick,
			})
			Widgets.label(cell, {
				text = item.short,
				font = "heavy",
				size = 11,
				color = C.parchment,
				align = "center",
				sizeUDim = UDim2.new(1, 0, 0, 14),
				anchor = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				outline = C.ink,
			})
			if item.id == "chests" then
				chest = { button = b, icon = true }
			end
		else
			local b = Widgets.button(nav, {
				name = item.id,
				text = if spec.kind == "full" then item.text else item.short,
				icon = item.icon,
				style = item.style,
				textSize = if spec.kind == "full" then 19 else 15,
				size = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0),
				layoutOrder = i,
				onClick = onClick,
			})
			if item.id == "chests" then
				chest = { button = b, icon = false }
			end
		end
	end
	maid:add(State.watch("profile", function(p)
		if not chest or not p then
			return
		end
		local free = freeChests(p) > 0
		chest.button:setStyle(if free then "green" else "brass")
		if not chest.icon then
			chest.button:setText(if free then "FREE CHEST!" else (if spec.kind == "full" then "CHESTS" else "CHESTS"))
		end
		chest.button:pulse(free)
	end, true))
	return nav
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------

-- Builds everything that moves with the screen's shape into `frame`.
local function build(frame: Frame, maid, L, popups: Instance)
	-- title
	if L.title then
		local r = L.title
		local title = Widgets.label(frame, {
			name = "Title",
			text = "Trapisque",
			font = "display",
			size = math.floor(math.min(60, r.h * 0.86)),
			color = C.parchment,
			align = if L.form == "tall" then "center" else "left",
			outline = C.ink,
			outlineThickness = if r.h >= 60 then 3 else 2,
		})
		place(title, r)
	end
	-- profile
	if L.profile.kind == "compact" then
		compactChip(frame, maid, L.profile.rect)
	else
		profileChip(frame, maid, L.profile.rect)
	end

	-- panels
	local panels = {}
	local function host(name: string, r): Frame
		local f = Util.frame(frame, { Name = name })
		place(f, r)
		return f
	end
	local tabbed = L.tabs ~= nil
	local play = PlayPanel.new(host("Play", L.play), popups, { compact = L.compact, untitled = tabbed })
	local party = PartyPanel.new(host("Party", L.party), popups, { compact = L.compact, untitled = tabbed })
	panels.play = play
	panels.party = party
	maid:add(function()
		play:destroy()
		party:destroy()
		if panels.leaders then
			panels.leaders:destroy()
		end
	end)

	if L.tabs then
		-- upright phone: one panel at a time
		local frames = { play = play.root.Parent, party = party.root.Parent }
		local function show(id: string)
			tab = id
			if id == "leaders" and not panels.leaders then
				panels.leaders = LeaderboardPanel.new(host("Leaders", L.leaders), { untitled = true })
				frames.leaders = panels.leaders.root.Parent
			end
			for key, f in frames do
				(f :: GuiObject).Visible = key == id
			end
		end
		local choice = Widgets.choice(frame, {
			name = "Tabs",
			options = {
				{ text = "Play", value = "play" },
				{ text = "Party", value = "party" },
				{ text = "Top", value = "leaders" },
			},
			value = tab,
			textSize = 18,
			onChange = show,
		})
		place(choice.root, L.tabs)
		show(tab)
	elseif L.leaders then
		panels.leaders = LeaderboardPanel.new(host("Leaders", L.leaders), {})
	end

	-- menu (the leaderboard joins it when there's no column or tab for it)
	buildNav(frame, maid, L.nav, popups, L.leaders == nil)
end

function LobbyScreen.show()
	Sound.music("lobby")
	Root.show("lobby", function(container)
		local maid = Util.maid()
		local root = Util.frame(container, { Name = "Lobby" })
		local popups = Util.frame(root, { Name = "Popups", ZIndex = 80 })
		local invites = Util.frame(root, { Name = "Invites", ZIndex = 90 })
		Util.list(invites, "y", 10, "Right", "Bottom")
		screen = { root = root, popups = popups, invites = invites, maid = maid }

		-- matchmaking messages ("X left, so the search was cancelled")
		maid:add(State.watch("queue", function(q)
			if q and q.message then
				Widgets.toast(q.message, "info")
			end
		end))

		-- the arrangement, rebuilt when the screen changes shape (settled for a moment
		-- first, so dragging a window doesn't rebuild it every frame)
		local current = nil -- { key, maid, frame }
		local pendingAt = 0
		local function rebuild(m)
			local L = Layout.lobby(m)
			local key = string.format("%s:%d:%d", L.form, math.floor(m.vw), math.floor(m.vh))
			if current and current.key == key then
				return
			end
			if current then
				current.maid:clean()
				current.frame:Destroy()
			end
			local frame = Util.frame(root, { Name = "Layout" })
			local bmaid = Util.maid()
			current = { key = key, maid = bmaid, frame = frame }
			local ok, err = pcall(build, frame, bmaid, L, popups)
			if not ok then
				warn("[Trapisque] lobby layout failed: " .. tostring(err))
			end
			local inv = L.invites
			local w = math.min(380, inv.w)
			invites.Position = UDim2.fromOffset(inv.x + inv.w - w, inv.y)
			invites.Size = UDim2.fromOffset(w, inv.h)
		end
		maid:add(Root.onResize(function(_vw, _vh, m)
			if not current then
				rebuild(m)
				return
			end
			local stamp = os.clock()
			pendingAt = stamp
			task.delay(0.25, function()
				if pendingAt == stamp and screen and screen.root == root then
					rebuild(Root.metrics)
				end
			end)
		end))
		maid:add(function()
			if current then
				current.maid:clean()
			end
		end)

		-- invites that arrived before the screen existed
		for _, inv in State.get("pendingInvites") or {} do
			LobbyScreen.invite(inv)
		end
		State.set("pendingInvites", {})

		return function()
			maid:clean()
			if screen and screen.root == root then
				screen = nil
			end
		end
	end)
end

-- A party invite card that waits for Accept / Decline (or runs out).
function LobbyScreen.invite(data)
	if not screen then
		local pending = State.get("pendingInvites") or {}
		table.insert(pending, data)
		State.set("pendingInvites", pending)
		return
	end
	local card = Util.new("Frame", {
		Name = "Invite",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 118),
		ZIndex = 91,
		Parent = screen.invites,
	})
	Util.corner(card, 14)
	Util.stroke(card, C.good, 3)
	Avatars.portrait(card, { userId = data.fromUserId, name = data.from }, {
		Position = UDim2.fromOffset(34, 34),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 92,
	}, { ring = C.good, ringPx = 2 })
	Widgets.label(card, {
		text = (data.from or "Someone") .. " invited you to their party",
		font = "heavy",
		size = 17,
		color = C.textDark,
		wrap = true,
		sizeUDim = UDim2.new(1, -76, 0, 44),
		position = UDim2.fromOffset(66, 10),
		z = 92,
	})
	local timer = Widgets.progress(card, {
		size = UDim2.new(1, -24, 0, 6),
		position = UDim2.fromOffset(12, 60),
		value = 1,
		color = C.good,
		z = 92,
	})
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		Util.tween(Util.scaler(card), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.2, function()
			card:Destroy()
		end)
	end
	local function respond(accept: boolean)
		finish()
		local ok, err = Net.request("party.respond", { partyId = data.partyId, accept = accept })
		if not ok then
			Widgets.toast(tostring(err), "error")
		end
	end
	Widgets.button(card, {
		text = "JOIN",
		style = "green",
		textSize = 17,
		size = UDim2.new(0.5, -18, 0, 38),
		position = UDim2.new(0, 12, 1, -46),
		z = 93,
		onClick = function()
			respond(true)
		end,
	})
	Widgets.button(card, {
		text = "NO THANKS",
		style = "parchment",
		textSize = 17,
		size = UDim2.new(0.5, -18, 0, 38),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 1, -46),
		z = 93,
		onClick = function()
			respond(false)
		end,
	})
	Util.popIn(card, 0.35, 0.5)
	Sound.play("turn")
	local life = data.expires or 60
	local t0 = os.clock()
	task.spawn(function()
		while not done and card.Parent do
			local left = 1 - (os.clock() - t0) / life
			if left <= 0 then
				finish()
				break
			end
			timer:set(left, true)
			task.wait(0.2)
		end
	end)
end

return LobbyScreen
