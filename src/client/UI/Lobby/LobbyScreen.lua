--[[
	LobbyScreen
	Home base between matches: your profile (level, Gems, trophies and rank), the Play
	and Party panels, the Top Players board, the menu (Chests, Quests, Locker, Shop,
	How to Play, Settings), the matchmaking banner and party invites.

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
local Quests = require(script.Parent.Quests)
local LobbyChat = require(script.Parent.LobbyChat)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progress = require(ReplicatedStorage.Shared.Meta.Progress)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local LobbyScreen = {}

local player = Players.LocalPlayer
local screen = nil -- { root, popups, invites, maid }
local welcomed = false -- the guided match was offered this session
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
		color = C.text,
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
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	place(chip, r)
	Util.corner(chip, 14)
	Util.stroke(chip, C.line, 3)
	local h = r.h
	local avatar = h - 20
	Avatars.portrait(chip, { userId = player.UserId, name = player.DisplayName }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(avatar, avatar),
	}, { ring = C.sun, ringPx = 3 })
	local x = avatar + 20
	local name = Widgets.label(chip, {
		text = player.DisplayName,
		font = "heavy",
		size = 18,
		color = C.text,
		sizeUDim = UDim2.new(1, -(x + 150), 0, 20),
		position = UDim2.fromOffset(x, h / 2 - 27),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local titleHolder = Util.frame(chip, { Position = UDim2.fromOffset(x, h / 2 - 6), Size = UDim2.new(1, -(x + 150), 0, 18) })
	local level = Widgets.label(chip, {
		text = "LV 1",
		font = "chunky",
		size = 14,
		color = C.skyDark,
		sizeUDim = UDim2.fromOffset(40, 16),
		position = UDim2.fromOffset(x, h / 2 + 13),
	})
	local xp = Widgets.progress(chip, {
		size = UDim2.new(1, -(x + 44 + 150), 0, 8),
		position = UDim2.fromOffset(x + 44, h / 2 + 17),
		color = C.info,
	})
	local gems = gemCounter(chip, 22, maid)
	gems.Position = UDim2.new(1, -16, 0.32, 0)
	-- trophies and rank (from ranked Quick Play)
	local trophyRow = Util.frame(chip, {
		Name = "Trophies",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.74, 0),
		Size = UDim2.fromOffset(140, 22),
	})
	Util.list(trophyRow, "x", 6, "Right", "Center")
	local trophyText = Widgets.label(trophyRow, {
		text = "0",
		font = "chunky",
		size = 16,
		color = C.text,
		align = "right",
		sizeUDim = UDim2.fromOffset(0, 20),
		layoutOrder = 1,
	})
	trophyText.AutomaticSize = Enum.AutomaticSize.X
	local trophyIcon = Util.frame(trophyRow, { Size = UDim2.fromOffset(20, 20), LayoutOrder = 2 })
	local shownRank = nil
	maid:add(State.watch("profile", function(p)
		if not p then
			return
		end
		local rank = Progress.rank(p.trophies or 0)
		trophyText.Text = rank.name .. "  " .. Util.commas(p.trophies or 0)
		if shownRank ~= rank.id then
			shownRank = rank.id
			Util.clear(trophyIcon)
			Icons.medallion(trophyIcon, "crown", Color3.fromHex(string.sub(rank.color, 2)), { Size = UDim2.fromScale(1, 1) })
		end
	end, true))

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
					color = C.textSoft,
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
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	place(chip, r)
	Util.corner(chip, r.h / 2)
	Util.stroke(chip, C.line, 2.5)
	local avatar = r.h - 8
	Avatars.portrait(chip, { userId = player.UserId, name = player.DisplayName }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(avatar, avatar),
	}, { ring = C.sun, ringPx = 2 })
	local x = avatar + 12
	local name = Widgets.label(chip, {
		text = player.DisplayName,
		font = "heavy",
		size = 15,
		color = C.text,
		sizeUDim = UDim2.new(1, -(x + 170), 1, 0),
		position = UDim2.fromOffset(x, 0),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local level = Widgets.label(chip, {
		text = "LV 1",
		font = "chunky",
		size = 14,
		color = C.skyDark,
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
	{ id = "quests", text = "QUESTS", short = "QUESTS", icon = "star", style = "orange" },
	{ id = "locker", text = "LOCKER", short = "LOCKER", icon = "hanger", style = "wood" },
	{ id = "shop", text = "SHOP", short = "SHOP", icon = "bag", style = "wood" },
	{ id = "leaders", text = "TOP PLAYERS", short = "TOP", icon = "crown", style = "wood" },
	{ id = "rules", text = "HOW TO PLAY", short = "RULES", icon = "book", style = "wood" },
	{ id = "settings", text = "SETTINGS", short = "SETTINGS", icon = "gear", style = "wood" },
}

local function openPage(id: string, popups: Instance)
	if id == "chests" then
		Chests.open(popups)
	elseif id == "quests" then
		Quests.open(popups)
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
	with a count while a free chest is waiting. Nothing here loops: a menu that keeps
	moving gets tiring, so a chest that becomes free just hops once.
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
	local quests = nil
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
			-- as big as the bar allows, but never wider than its share of the row
			local cellW = (spec.rect.w - gap * (n - 1)) / n
			local size = math.min(spec.rect.h - 18, math.floor(cellW - 4))
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
				color = C.textLight,
				align = "center",
				sizeUDim = UDim2.new(1, 0, 0, 14),
				anchor = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				outline = C.line,
			})
			if item.id == "chests" then
				chest = { button = b, icon = true }
			elseif item.id == "quests" then
				quests = b
			end
		else
			local b = Widgets.button(nav, {
				name = item.id,
				text = if spec.kind == "full" then item.text else item.short,
				icon = item.icon,
				style = item.style,
				textSize = if spec.kind == "full" then 19 elseif n >= 7 then 13 else 15,
				size = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0),
				layoutOrder = i,
				onClick = onClick,
			})
			if item.id == "chests" then
				chest = { button = b, icon = false }
			elseif item.id == "quests" then
				quests = b
			end
		end
	end
	-- the Quests button shows how many of today's quests are left
	maid:add(State.watch("profile", function(p)
		if quests and p then
			local left = Quests.unfinished(p)
			quests:setBadge(if left > 0 then tostring(left) else nil)
		end
	end, true))
	local wasFree: boolean? = nil
	maid:add(State.watch("profile", function(p)
		if not chest or not p then
			return
		end
		local count = freeChests(p)
		local free = count > 0
		chest.button:setStyle(if free then "green" else "brass")
		if not chest.icon then
			chest.button:setText(if free then "FREE CHEST!" else "CHESTS")
		end
		chest.button:setBadge(if free then tostring(count) else nil)
		if free and wasFree == false then
			Util.bump(chest.button.root, 0.12)
		end
		wasFree = free
	end, true))
	return nav
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------

--[[
	What's still loading once you're in (sounds and music), on a little pill in the top
	bar that fills up and goes away. On a phone held sideways it sits where the title is,
	so the title steps aside until it's done.
]]
local function buildLoader(parent: Instance, maid, r, title: GuiObject?)
	if not r or r.w < 120 then
		return
	end
	local h = math.floor(r.h * 0.72)
	local pill = Util.new("Frame", {
		Name = "StillLoading",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(r.x, r.y + (r.h - h) / 2),
		Size = UDim2.fromOffset(r.w, h),
		Visible = false,
		Parent = parent,
	})
	Util.corner(pill, 0.5)
	Util.stroke(pill, C.line, 2.5)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.sunLight,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = pill,
	})
	Util.corner(fill, 0.5)
	local label = Widgets.label(pill, {
		text = "",
		font = "heavy",
		size = 14,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 2,
	})
	maid:add(State.watch("loadingRest", function(v)
		if v then
			pill.Visible = true
			if title then
				title.Visible = false
			end
			label.Text = string.format("Loading sounds  %d%%", math.floor(v * 100))
			Util.tween(fill, 0.2, { Size = UDim2.fromScale(math.max(0.08, v), 1) })
		elseif pill.Visible then
			label.Text = "All aboard!"
			Util.tween(fill, 0.2, { Size = UDim2.fromScale(1, 1) })
			task.delay(1.2, function()
				if pill.Parent then
					pill.Visible = false
					if title then
						title.Visible = true
					end
				end
			end)
		end
	end, true))
end

-- Builds everything that moves with the screen's shape into `frame`.
local function build(frame: Frame, maid, L, popups: Instance)
	-- title
	local titleLabel: GuiObject? = nil
	if L.title then
		local r = L.title
		local title = Widgets.label(frame, {
			name = "Title",
			text = "Trapisque",
			font = "display",
			size = math.floor(math.min(60, r.h * 0.86)),
			color = C.sun,
			align = if L.form == "tall" then "center" else "left",
			outline = C.line,
			outlineThickness = if r.h >= 60 then 3 else 2,
		})
		place(title, r)
		titleLabel = title
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
	LobbyChat.build(frame, maid, L.chat, popups)
	buildLoader(frame, maid, L.loader, if L.form == "short" then titleLabel else nil)
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

		-- new here: offer the guided first match
		if not welcomed then
			local profile = State.get("profile")
			if profile and profile.tutorialDone == false then
				welcomed = true
				task.delay(0.9, function()
					if screen and screen.root == root then
						LobbyScreen.welcome(popups)
					end
				end)
			end
		end

		return function()
			maid:clean()
			if screen and screen.root == root then
				screen = nil
			end
		end
	end)
end

-- Welcome aboard: the guided first match (or not now; it's in How to Play).
function LobbyScreen.welcome(popups: Instance)
	local _, _, narrow = Widgets.room()
	local content, close = Widgets.modal(popups, {
		title = "Welcome Aboard!",
		titleWidth = 320,
		width = 560,
		height = if narrow then 400 else 360,
		closeOnBackdrop = false,
	})
	local face = Util.frame(content, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(96, 96),
	})
	Icons.medallion(face, "overseer", Theme.Character.overseer, { Size = UDim2.fromScale(1, 1) })
	Widgets.label(content, {
		text = "New to Trapisque? Race me to the treasure in a quick guided match: I'll show you the dice, the traps and your Power as we go. It takes about 3 minutes.",
		font = "heavy",
		size = 17,
		color = C.text,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, if narrow then 110 else 80),
		position = UDim2.fromOffset(0, 104),
	})
	local row = Util.frame(content, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 54),
	})
	Util.list(row, "x", 12, "Center", "Center")
	Widgets.button(row, {
		text = "NOT NOW",
		style = "panel",
		textSize = 18,
		size = UDim2.fromOffset(160, 50),
		layoutOrder = 1,
		onClick = function()
			close()
			Net.request("tutorial.skip")
		end,
	})
	Widgets.button(row, {
		text = "LET'S GO!",
		icon = "play",
		style = "green",
		textSize = 20,
		size = UDim2.fromOffset(220, 50),
		layoutOrder = 2,
		onClick = function()
			local ok, err = Net.request("match.tutorial")
			if ok then
				close()
			else
				Widgets.toast(tostring(err), "error")
			end
		end,
	})
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
		BackgroundColor3 = C.panel,
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
		color = C.text,
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
