--[[
	CharacterSelect
	Pick the character you take into matches. Each one shows its card (tap or hover it to
	read its passive and ability), your mastery level with them, and the title you're
	working towards. Playing a character levels up their mastery (Meta/Progress).

		CharacterSelect.open(popups)
		CharacterSelect.strip(parent, opts) -> { root, destroy }  -- the lobby's "your character" bar
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local CharacterSelect = {}

-- Mastery for a character from the profile: level, XP into it, XP it needs (nil at max).
local function masteryOf(profile, id: string): (number, number, number?)
	local xp = profile and profile.mastery and profile.mastery[id] or 0
	local into, need = Progress.masteryProgress(xp)
	return Progress.masteryLevel(xp), into, need
end
CharacterSelect.masteryOf = masteryOf

-- The next mastery title for a level ("Fan" at 3, "Pro" at 6, "Legend" at 10), or nil.
local function nextTitle(level: number): (number?, string?)
	local best, bestTier = nil, nil
	for at, tier in Progress.masteryTitles do
		if at > level and (best == nil or at < best) then
			best, bestTier = at, tier
		end
	end
	if not best then
		return nil, nil
	end
	return best, Progress.masteryTitleName[bestTier :: string]
end

function CharacterSelect.open(popups: Instance)
	local roomW, _, narrow = Widgets.room()
	local cols = if narrow then 2 else 3
	local cellW = if narrow then 158 else 196
	local cardW = if narrow then 104 else 128
	local cellH = math.floor(cardW / CardStyle.aspect) + 112 -- card, mastery, bar, next title, PICK
	local rows = math.ceil(#Characters.list / cols)
	local content, close = Widgets.modal(popups, {
		title = "Characters",
		titleWidth = 280,
		width = math.min(roomW, cols * (cellW + 12) + 60),
		height = 120 + rows * (cellH + 12),
	})
	Widgets.label(content, {
		text = "Pick who you play as. The more you play someone, the higher their mastery.",
		font = "heavy",
		size = if narrow then 13 else 15,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, if narrow then 34 else 22),
	})
	local grid = Util.frame(content, {
		Name = "Grid",
		Position = UDim2.fromOffset(0, if narrow then 40 else 30),
		Size = UDim2.new(1, 0, 1, if narrow then -40 else -30),
	})
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local buttons = {}
	local function refresh()
		local profile = State.get("profile")
		local current = profile and profile.character
		for id, b in buttons do
			local picked = id == current
			b.button:setText(if picked then "PICKED" else "PICK")
			b.button:setStyle(if picked then "green" else "brass")
			b.rim.Color = if picked then C.sun else C.line
			b.rim.Thickness = if picked then 4 else 2.5
		end
	end
	for i, def in Characters.list do
		local profile = State.get("profile")
		local color = Theme.Character[def.id] or C.grape
		local cell = Util.new("Frame", {
			Name = def.id,
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		})
		Util.corner(cell, 14)
		local rim = Util.stroke(cell, C.line, 2.5)
		local card = Cards.character(cell, def.id, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(cardW, cardW / CardStyle.aspect),
		})
		-- open it big to read its rules
		Cards.interactive(card, function()
			Cards.zoom(card.root, function(parent, props)
				return Cards.character(parent, def.id, props)
			end)
		end)
		local level, into, need = masteryOf(profile, def.id)
		local y = 8 + math.floor(cardW / CardStyle.aspect) + 6
		Widgets.label(cell, {
			text = "MASTERY " .. level,
			font = "chunky",
			size = 15,
			color = C.text,
			outline = C.line,
			align = "center",
			sizeUDim = UDim2.new(1, -12, 0, 18),
			position = UDim2.fromOffset(6, y),
		})
		local bar = Widgets.progress(cell, {
			size = UDim2.new(1, -24, 0, 10),
			position = UDim2.fromOffset(12, y + 22),
			value = if need then into / math.max(1, need) else 1,
			color = color,
		})
		local _ = bar
		local at, titleName = nextTitle(level)
		Widgets.label(cell, {
			text = if at then (def.name .. " " .. titleName .. " title at level " .. at) else "Max mastery!",
			font = "heavy",
			size = 11,
			color = C.textFaint,
			align = "center",
			sizeUDim = UDim2.new(1, -12, 0, 14),
			position = UDim2.fromOffset(6, y + 36),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local button = Widgets.button(cell, {
			text = "PICK",
			style = "brass",
			textSize = 16,
			size = UDim2.new(1, -20, 0, 36),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			depth = 4,
			onClick = function()
				local ok, err = Net.request("character.select", { character = def.id })
				if not ok then
					Widgets.toast(tostring(err), "error")
					return
				end
				Sound.play("reveal")
				Util.bump(cell, 0.06)
			end,
		})
		buttons[def.id] = { button = button, rim = rim }
	end
	refresh()
	local conn = State.watch("profile", function()
		refresh()
	end)
	local root = grid:FindFirstAncestorWhichIsA("GuiObject")
	task.spawn(function()
		while grid.Parent do
			task.wait(0.5)
		end
		conn()
	end)
	local _ = root
	return close
end

--[[
	The lobby's "your character" bar: mascot, name, mastery level and bar, CHANGE.
	opts = { compact, onChange }
]]
function CharacterSelect.strip(parent: Instance, opts: { [string]: any }?)
	local o = opts or {}
	local compact = o.compact == true
	local root = Util.new("TextButton", {
		Name = "YourCharacter",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	Util.corner(root, 12)
	Util.stroke(root, C.line, 2.5)
	local portrait = Util.frame(root, { Name = "Portrait", Position = UDim2.fromOffset(6, 4) })
	local name = Widgets.label(root, {
		name = "Name",
		text = "",
		font = "chunky",
		size = if compact then 16 else 20,
		color = C.text,
		outline = C.line,
	})
	local sub = Widgets.label(root, {
		name = "Mastery",
		text = "",
		font = "heavy",
		size = if compact then 11 else 13,
		color = C.textSoft,
	})
	-- (the short strip's bar is a plain line: an outline would run into the text above)
	local bar = Widgets.progress(root, { value = 0, size = UDim2.fromOffset(100, 8), plain = compact })
	local change = Widgets.button(root, {
		text = "CHANGE",
		style = "purple",
		textSize = if compact then 13 else 16,
		depth = 3,
		corner = 10,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		onClick = function()
			if o.onChange then
				o.onChange()
			end
		end,
	})
	root.Activated:Connect(function()
		if o.onChange then
			o.onChange()
		end
	end)
	local shown = nil
	local function draw()
		local h = root.AbsoluteSize.Y / math.max(0.01, Util.inheritedScale(root, true))
		if h <= 0 then
			h = if compact then 44 else 60
		end
		local ps = h - 8
		portrait.Size = UDim2.fromOffset(ps, ps)
		local bw = if compact then 84 else 108
		change.root.Size = UDim2.fromOffset(bw, math.min(40, h - 14))
		local tx = ps + 14
		name.Position = UDim2.fromOffset(tx, if compact then 3 else 6)
		name.Size = UDim2.new(1, -(tx + bw + 16), 0, if compact then 18 else 24)
		sub.Position = UDim2.fromOffset(tx, if compact then 20 else 30)
		sub.Size = UDim2.new(1, -(tx + bw + 16), 0, if compact then 13 else 14)
		bar.root.Position = UDim2.fromOffset(tx, h - (if compact then 9 else 14))
		bar.root.Size = UDim2.new(1, -(tx + bw + 20), 0, if compact then 5 else 8)
		local profile = State.get("profile")
		local id = profile and profile.character or Characters.ids[1]
		local def = Characters.get(id)
		if shown ~= id then
			shown = id
			Util.clear(portrait)
			Icons.medallion(portrait, id, Theme.Character[id] or C.grape, { Size = UDim2.fromScale(1, 1) })
		end
		local level, into, need = masteryOf(profile, id)
		name.Text = string.upper(if def then def.name else id)
		sub.Text = "Mastery " .. level .. (if need then string.format("  ·  %d / %d XP", into, need) else "  ·  MAX")
		bar:set(if need then into / math.max(1, need) else 1)
		local fill = bar.fill :: Frame
		fill.BackgroundColor3 = Theme.Character[id] or C.sun
	end
	local maid = Util.maid()
	maid:add(State.watch("profile", function()
		draw()
	end, true))
	maid:add(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw))
	return {
		root = root,
		destroy = function()
			maid:clean()
			root:Destroy()
		end,
	}
end

return CharacterSelect
