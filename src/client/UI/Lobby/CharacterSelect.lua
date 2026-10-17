--[[
	CharacterSelect
	Pick the character you take into matches. Each one shows its card (tap or hover it to
	read its passive and ability), your mastery level with them, and what you're working
	towards: titles, and the character's own base to stand on in matches (at mastery 5,
	gold at 10; the little stand by MASTERY shows it). Playing a character levels up
	their mastery (Meta/Progress). Four are free; the rest unlock as your level goes up
	(Config.CharacterUnlocks).

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
local BaseArt = require(UI.BaseArt)

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

-- What mastery brings next for this character: a title, their base, the gold base.
local function nextReward(name: string, level: number): string
	local at, titleName = nextTitle(level)
	local baseAt, gold = nil, false
	for i, l in Progress.baseLevels do
		if level < l then
			baseAt, gold = l, i == #Progress.baseLevels
			break
		end
	end
	if baseAt and at and baseAt == at then
		return string.format("%s title + gold base at %d", tostring(titleName), at)
	elseif baseAt and (not at or baseAt < at) then
		return string.format("%s %s at level %d", name, if gold then "gold base" else "base", baseAt)
	elseif at then
		return string.format("%s %s title at level %d", name, tostring(titleName), at)
	end
	return "Max mastery!"
end

function CharacterSelect.open(popups: Instance)
	local roomW, roomH, narrow = Widgets.room()
	local cols = if narrow then 2 else 4
	local cellW = if narrow then 158 else 196
	local cardW = if narrow then 104 else 128
	local cellH = math.floor(cardW / CardStyle.aspect) + 112 -- card, mastery, bar, next title, PICK
	local rows = math.ceil(#Characters.list / cols)
	local content, close = Widgets.modal(popups, {
		title = "Characters",
		titleWidth = 280,
		width = math.min(roomW, cols * (cellW + 12) + 60),
		-- taller than the screen: the grid scrolls
		height = math.min(120 + rows * (cellH + 12), math.max(420, roomH)),
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
	-- (the scroll's own grid: a second layout next to its list would be ignored)
	local grid = Widgets.scroll(content, {
		name = "Grid",
		position = UDim2.fromOffset(0, if narrow then 40 else 30),
		size = UDim2.new(1, 0, 1, if narrow then -40 else -30),
		grid = UDim2.fromOffset(cellW, cellH),
		gap = 12,
	})
	local buttons = {}
	local function refresh()
		local profile = State.get("profile")
		local current = profile and profile.character
		local level = profile and profile.level or 1
		for id, b in buttons do
			local picked = id == current
			local open = (profile and profile.unlockAll) or Characters.unlocked(id, level)
			local def = Characters.get(id)
			b.button:setText(if not open then ("LEVEL " .. tostring(def and def.unlockLevel or 0)) elseif picked then "PICKED" else "PICK")
			b.button:setStyle(if not open then "dark" elseif picked then "green" else "brass")
			b.rim.Color = if picked then C.sun else C.line
			b.rim.Thickness = if picked then 4 else 2.5
			b.lock.Visible = not open
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
		-- locked: a padlock over the card until your level reaches it
		local lock = Util.frame(cell, {
			Name = "Lock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 8 + cardW / CardStyle.aspect * 0.5),
			Size = UDim2.fromOffset(cardW * 0.46, cardW * 0.46),
			ZIndex = 20,
			Visible = false,
		})
		local disc = Util.new("Frame", {
			Name = "Disc",
			BackgroundColor3 = C.panelDeep,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Parent = lock,
		})
		Util.corner(disc, 0.5)
		Util.stroke(disc, C.line, 3)
		Icons.make(disc, "lock", Icons.flatColors(C.sun, C.panelDeep), { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21 })
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
		-- their base: faint until mastery 5 earns it
		BaseArt.preview(cell, def.id, if profile and profile.unlockAll then 2 else Progress.baseTier(level), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -3, 0, y + 9),
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 4,
		})
		local bar = Widgets.progress(cell, {
			size = UDim2.new(1, -24, 0, 10),
			position = UDim2.fromOffset(12, y + 22),
			value = if need then into / math.max(1, need) else 1,
			color = color,
		})
		local _ = bar
		Widgets.label(cell, {
			text = nextReward(def.name, level),
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
				local profile = State.get("profile")
				if not (profile and profile.unlockAll) and not Characters.unlocked(def.id, profile and profile.level or 1) then
					Widgets.toast(string.format("Reach level %d to unlock the %s. Every match you play earns XP!", def.unlockLevel or 0, def.name), "info")
					return
				end
				local ok, err = Net.request("character.select", { character = def.id })
				if not ok then
					Widgets.toast(tostring(err), "error")
					return
				end
				Sound.play("reveal")
				Util.bump(cell, 0.06)
			end,
		})
		buttons[def.id] = { button = button, rim = rim, lock = lock }
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
