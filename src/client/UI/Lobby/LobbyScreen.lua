--[[
	LobbyScreen
	Home base between matches: your profile, the Play and Party panels, the menu along
	the bottom (Chests, Locker, Shop, How to Play, Settings), the matchmaking banner
	and party invites.

		LobbyScreen.show()
		LobbyScreen.invite(data)   -- server "invite" push
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage.Shared.Game.Modes)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)
local Root = require(UI.Root)
local PlayPanel = require(script.Parent.PlayPanel)
local PartyPanel = require(script.Parent.PartyPanel)
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

---------------------------------------------------------------------------
-- profile chip (top right)
---------------------------------------------------------------------------

local function profileChip(parent: Instance, maid)
	local chip = Util.new("Frame", {
		Name = "Profile",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(400, 70),
		Parent = parent,
	})
	Util.corner(chip, 14)
	Util.stroke(chip, C.burn, 3)
	local pawnHolder = Util.frame(chip, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(50, 50) })
	local name = Widgets.label(chip, {
		text = player.DisplayName,
		font = "heavy",
		size = 18,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -220, 0, 22),
		position = UDim2.fromOffset(70, 8),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local titleHolder = Util.frame(chip, { Position = UDim2.fromOffset(70, 30), Size = UDim2.new(1, -220, 0, 16) })
	local xp = Widgets.progress(chip, {
		size = UDim2.new(1, -220, 0, 10),
		position = UDim2.fromOffset(70, 50),
		color = C.info,
	})
	-- level + gems on the right
	local level = Widgets.badge(chip, {
		text = "LV 1",
		color = C.info,
		height = 26,
		textSize = 16,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 8),
	})
	local gemRow = Util.frame(chip, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -6),
		Size = UDim2.fromOffset(130, 28),
	})
	Util.list(gemRow, "x", 6, "Right", "Center")
	local gems = Widgets.label(gemRow, {
		text = "0",
		font = "chunky",
		size = 22,
		color = C.ink,
		align = "right",
		sizeUDim = UDim2.fromOffset(0, 28),
		layoutOrder = 1,
	})
	gems.AutomaticSize = Enum.AutomaticSize.X
	local gemIcon = Util.frame(gemRow, { Size = UDim2.fromOffset(26, 26), LayoutOrder = 2 })
	Icons.medallion(gemIcon, "gem", C.neutral, { Size = UDim2.fromScale(1, 1) })

	local lastPawn, lastTitle, lastGems = nil, nil, nil
	maid:add(State.watch("profile", function(p)
		if not p then
			return
		end
		local eq = p.equipped or {}
		if eq.pawn ~= lastPawn then
			lastPawn = eq.pawn
			Util.clear(pawnHolder)
			CosmeticArt.pawn(pawnHolder, eq.pawn, Theme.Seat[2], {
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			})
		end
		if eq.title ~= lastTitle then
			lastTitle = eq.title
			Util.clear(titleHolder)
			local t = CosmeticArt.title(titleHolder, eq.title, { TextXAlignment = Enum.TextXAlignment.Left })
			if not t then
				Widgets.label(titleHolder, {
					text = "No title yet",
					font = "body",
					size = 13,
					color = C.inkFaint,
					sizeUDim = UDim2.fromScale(1, 1),
				})
			end
		end
		local lv = level:FindFirstChildWhichIsA("TextLabel", true)
		if lv then
			lv.Text = "LV " .. tostring(p.level or 1)
		end
		xp:set((p.xp or 0) / math.max(1, p.xpNext or 100))
		if lastGems and p.gems ~= lastGems then
			Util.bump(gemRow, 0.12)
			if p.gems > lastGems then
				Sound.play("coin")
			end
		end
		lastGems = p.gems
		gems.Text = Util.commas(p.gems or 0)
	end, true))
	return chip
end

---------------------------------------------------------------------------
-- matchmaking banner
---------------------------------------------------------------------------

local function queueBanner(parent: Instance, maid)
	local banner = Util.new("Frame", {
		Name = "Queue",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(560, 56),
		Visible = false,
		ZIndex = 40,
		Parent = parent,
	})
	Util.corner(banner, 14)
	Util.stroke(banner, C.brassDark, 3)
	local compass = Util.frame(banner, { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(40, 40), ZIndex = 41 })
	Icons.make(compass, "compass", Icons.flatColors(C.ink, C.parchment))
	local text = Widgets.label(banner, {
		text = "",
		font = "heavy",
		size = 18,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -200, 1, 0),
		position = UDim2.fromOffset(62, 0),
		z = 41,
	})
	text.TextTruncate = Enum.TextTruncate.AtEnd
	Widgets.button(banner, {
		text = "CANCEL",
		style = "red",
		textSize = 17,
		size = UDim2.fromOffset(120, 40),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, -2),
		z = 42,
		onClick = function()
			local ok, err = Net.request("mm.cancel")
			if not ok then
				Widgets.toast(tostring(err), "error")
			end
		end,
	})
	local startedAt = os.clock()
	local modeName = ""
	maid:add(State.watch("queue", function(q)
		local searching = q ~= nil and q.state == "searching"
		if searching and not banner.Visible then
			startedAt = os.clock() - (q.elapsed or 0)
			Util.popIn(banner, 0.3, 0.7)
		end
		banner.Visible = searching
		if q and q.mode then
			local m = Modes.get(q.mode)
			modeName = if m then m.name else q.mode
		end
		if q and q.message then
			Widgets.toast(q.message, "info")
		end
	end, true))
	task.spawn(function()
		while banner.Parent do
			if banner.Visible then
				local q = State.get("queue")
				local secs = math.floor(os.clock() - startedAt)
				local others = q and q.searching and q.searching > 1 and ("  ·  " .. q.searching .. " searching") or ""
				text.Text = "Finding a " .. modeName .. " match  " .. string.format("%d:%02d", secs // 60, secs % 60) .. others
				compass.Rotation = (compass.Rotation + 6) % 360
			end
			task.wait(0.1)
		end
	end)
	return banner
end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------

local NAV = {
	{ id = "chests", text = "CHESTS", icon = "chest", style = "brass" },
	{ id = "locker", text = "LOCKER", icon = "hanger", style = "wood" },
	{ id = "shop", text = "SHOP", icon = "bag", style = "wood" },
	{ id = "rules", text = "HOW TO PLAY", icon = "book", style = "wood" },
	{ id = "settings", text = "SETTINGS", icon = "gear", style = "wood" },
}

function LobbyScreen.show()
	Root.show("lobby", function(container)
		local maid = Util.maid()
		local root = Util.frame(container, { Name = "Lobby" })
		local popups = Util.frame(root, { Name = "Popups", ZIndex = 80 })
		local invites = Util.frame(root, {
			Name = "Invites",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -110),
			Size = UDim2.fromOffset(380, 400),
			ZIndex = 90,
		})
		Util.list(invites, "y", 10, "Right", "Bottom")
		screen = { root = root, popups = popups, invites = invites, maid = maid }

		local top = Root.topInset()
		-- title
		local title = Widgets.label(root, {
			text = "Trapisque",
			font = "display",
			size = 60,
			color = C.parchment,
			sizeUDim = UDim2.fromOffset(420, 70),
			position = UDim2.fromOffset(28, top - 6),
			outline = C.ink,
			outlineThickness = 3,
		})
		title.Name = "Title"
		local chip = profileChip(root, maid)
		chip.Position = UDim2.new(1, -24, 0, top)
		local banner = queueBanner(root, maid)
		banner.Position = UDim2.new(0.5, 0, 0, top + 6)

		-- the two main panels
		local body = Util.frame(root, {
			Name = "Body",
			Position = UDim2.fromOffset(24, top + 96),
			Size = UDim2.new(1, -48, 1, -(top + 96 + 112)),
		})
		local left = Util.frame(body, { Name = "Left", Size = UDim2.new(0.55, -12, 1, 0) })
		local right = Util.frame(body, {
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.45, -12, 1, 0),
		})
		local play = PlayPanel.new(left, popups)
		local party = PartyPanel.new(right, popups)
		maid:add(function()
			play:destroy()
			party:destroy()
		end)

		-- bottom menu
		local nav = Util.frame(root, {
			Name = "Nav",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -22),
			Size = UDim2.new(1, -48, 0, 66),
		})
		local layout = Util.list(nav, "x", 14, "Center", "Center")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		local chestButton = nil
		for i, item in NAV do
			local b = Widgets.button(nav, {
				name = item.id,
				text = item.text,
				icon = item.icon,
				style = item.style,
				textSize = 19,
				size = UDim2.new(0.2, -12, 1, 0),
				layoutOrder = i,
				onClick = function()
					if item.id == "chests" then
						Chests.open(popups)
					elseif item.id == "locker" then
						Locker.open(popups)
					elseif item.id == "shop" then
						Pages.shop(popups)
					elseif item.id == "rules" then
						Pages.rules(popups)
					elseif item.id == "settings" then
						Pages.settings(popups)
					end
				end,
			})
			if item.id == "chests" then
				chestButton = b
			end
		end
		-- a free chest turns the Chests button green so it's hard to miss
		maid:add(State.watch("profile", function(p)
			if chestButton and p then
				local free = 0
				for _, n in p.freeChests or {} do
					free += n
				end
				chestButton:setText(if free > 0 then "FREE CHEST!" else "CHESTS")
				chestButton:setStyle(if free > 0 then "green" else "brass")
			end
		end, true))

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
		Size = UDim2.fromOffset(380, 118),
		ZIndex = 91,
		Parent = screen.invites,
	})
	Util.corner(card, 14)
	Util.stroke(card, C.good, 3)
	local pawn = Util.frame(card, { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(44, 44), ZIndex = 92 })
	CosmeticArt.pawn(pawn, data.look and data.look.pawn, Theme.Seat[3], {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
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
