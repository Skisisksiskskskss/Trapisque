--[[
	Collection
	Your badges and your fish log, side by side on two tabs. Badges you haven't earned
	show as dark medals with what they're for; fish you haven't caught show as dark
	shapes. Opened from the Quests page.

		Collection.open(popups, tab?)   -- tab: "badges" (default) | "fish"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Badges = require(Shared.Meta.Badges)
local Fishing = require(Shared.Meta.Fishing)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local BadgeArt = require(UI.BadgeArt)
local FishArt = require(UI.FishArt)

local Client = UI.Parent
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local Collection = {}

local RARITY_COLOR = {
	common = C.steel,
	uncommon = C.lime,
	rare = C.sky,
	legendary = C.sun,
	junk = C.textFaint,
}

-- Every op drawn in one dark ink (a fish you haven't caught yet).
local function shadowOf(ops)
	local out = {}
	for _, op in ops do
		local copy = table.clone(op)
		copy.c = "#3A3846"
		table.insert(out, copy)
	end
	return out
end

function Collection.open(popups: Instance, tab: string?)
	local roomW, roomH, narrow = Widgets.room()
	local content, close = Widgets.modal(popups, {
		title = "Collection",
		titleWidth = 280,
		width = math.min(900, roomW),
		height = math.min(620, roomH),
	})
	local tabs = Util.frame(content, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 44) })
	Util.list(tabs, "x", 10, "Center", "Center")
	local body = Util.frame(content, { Name = "Body", Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) })
	local current = tab or "badges"
	local buttons = {}
	local cols = if narrow then 2 else 4

	local function badgesTab()
		local profile = State.get("profile")
		local earned = profile and profile.badges or {}
		local have = 0
		for _ in earned do
			have += 1
		end
		Widgets.label(body, {
			text = string.format("%d of %d badges", have, #Badges.list),
			font = "heavy",
			size = 15,
			color = C.textSoft,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 20),
		})
		local grid = Widgets.scroll(body, {
			position = UDim2.fromOffset(0, 26),
			size = UDim2.new(1, 0, 1, -26),
			grid = UDim2.new(1 / cols, -10, 0, 176),
			gap = 10,
			padding = 4,
		})
		for i, b in Badges.list do
			local got = earned[b.key] ~= nil
			local cell = Util.new("Frame", {
				Name = b.key,
				BackgroundColor3 = if got then C.mine else C.panelRaised,
				BorderSizePixel = 0,
				LayoutOrder = (if got then 0 else 100) + i,
				Parent = grid,
			})
			Util.corner(cell, 12)
			Util.stroke(cell, if got then C.sun else C.line, 2.5)
			BadgeArt.medal(cell, b.key, got, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(78, 78),
			})
			Widgets.label(cell, {
				text = b.name,
				font = "chunky",
				size = 17,
				color = if got then C.text else C.textSoft,
				align = "center",
				scaled = true,
				sizeUDim = UDim2.new(1, -12, 0, 22),
				position = UDim2.fromOffset(6, 94),
			})
			Widgets.label(cell, {
				text = b.text,
				font = "body",
				size = 13,
				minSize = 9,
				color = C.textSoft,
				align = "center",
				wrap = true,
				scaled = true,
				valign = "top",
				sizeUDim = UDim2.new(1, -14, 0, 52),
				position = UDim2.fromOffset(7, 118),
			})
		end
	end

	local function fishTab()
		local profile = State.get("profile")
		local log = profile and profile.fish or {}
		local have = 0
		for _, c in Fishing.logged do
			if (log[c.id] or 0) > 0 then
				have += 1
			end
		end
		Widgets.label(body, {
			text = string.format("%d of %d caught  ·  fish between turns with the rod in the board's corner", have, #Fishing.logged),
			font = "heavy",
			size = if narrow then 13 else 15,
			color = C.textSoft,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, if narrow then 34 else 20),
		})
		local top = if narrow then 40 else 26
		local grid = Widgets.scroll(body, {
			position = UDim2.fromOffset(0, top),
			size = UDim2.new(1, 0, 1, -top),
			grid = UDim2.new(1 / cols, -10, 0, 150),
			gap = 10,
			padding = 4,
		})
		for i, c in Fishing.logged do
			local n = log[c.id] or 0
			local cell = Util.new("Frame", {
				Name = c.id,
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = grid,
			})
			Util.corner(cell, 12)
			Util.stroke(cell, if n > 0 then (RARITY_COLOR[c.rarity] or C.line) else C.line, 2.5)
			local ops = FishArt.ops(c.id)
			Icons.sticker(cell, if n > 0 then ops else shadowOf(ops), {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(84, 84),
			}, 0.06)
			Widgets.label(cell, {
				text = if n > 0 then c.name else "???",
				font = "chunky",
				size = 17,
				color = C.text,
				align = "center",
				scaled = true,
				sizeUDim = UDim2.new(1, -12, 0, 22),
				position = UDim2.fromOffset(6, 96),
			})
			Widgets.label(cell, {
				text = string.upper(string.sub(c.rarity, 1, 1)) .. string.sub(c.rarity, 2) .. (if n > 0 then ("  ·  x" .. n) else ""),
				font = "heavy",
				size = 12,
				color = RARITY_COLOR[c.rarity] or C.textSoft,
				align = "center",
				sizeUDim = UDim2.new(1, -12, 0, 16),
				position = UDim2.fromOffset(6, 122),
			})
		end
	end

	local function show(which: string)
		current = which
		Util.clear(body)
		for id, b in buttons do
			b:setStyle(if id == which then "brass" else "panel")
		end
		if which == "fish" then
			fishTab()
		else
			badgesTab()
		end
	end
	for i, t in { { "badges", "Badges", "star" }, { "fish", "Fish log", "rod" } } do
		buttons[t[1]] = Widgets.button(tabs, {
			text = t[2],
			icon = t[3],
			style = "panel",
			textSize = 17,
			size = UDim2.fromOffset(if narrow then 150 else 180, 42),
			layoutOrder = i,
			onClick = function()
				Sound.play("click")
				show(t[1])
			end,
		})
	end
	show(current)
	return close
end

return Collection
