--[[
	ActionDock
	Your two action areas.

	The dice tray. Every turn starts with your dice already rolled: two of them (three in
	the Triple Dice event or as the underdog, one while you're Frozen). You pick the one
	to move with and the best of the others charges your Power. On doubles the second
	die of the pair is marked BACK: it moves you backwards; or move the TOTAL of the pair
	(no Power). Hovering a die (or tapping it once on a touch screen) shows on the board
	where it takes you; clicking it (or tapping it again) moves. On other players' turns
	the tray shows their dice, so you can see what they chose. RECALL joins the tray when
	you've dropped a time anchor.

	The Power panel: your mascot, a Power bar as long as your ability costs, and the
	ability button, which lights up when the bar is full.

		local dock = ActionDock.new(parent, { character = "mage", touch = bool })
		dock:layout(L.ability, L.roll, form)
		dock:setDice({ dice, mine, owner, frozen, chosen, enabled, power = { [key] = n }, back = { [key] = true }, hint })
		dock:rollDice(dice, frozen, speed)               -- tumbles them in (yields)
		dock:choose(key)                                 -- the chosen die pops
		dock:setPower(power, cap, { usable, used, mine })
		dock:setRecall(show, enabled)
		dock:setClock(secondsLeft?)
		dock:clearSelection()
		dock.onDie(key), dock.onDieHover(key?), dock.onAbility(), dock.onRecall(), dock.onPortrait()

	A die's key is its number in the roll (1, 2, 3) or "sum" for doubles' TOTAL.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Sound = require(UI.Parent.Sound)

local C = Theme.C

local ActionDock = {}
ActionDock.__index = ActionDock

-- Ability button colour per character: its own colour (Widgets button styles)
local ABILITY_STYLE = {
	mage = "blue",
	trapper = "orange",
	fire_starter = "red",
	naturalist = "green",
	warper = "pink",
	overseer = "brass",
}

-- PC keys for the dice (shown under them)
local DIE_KEYS = { "Q", "W", "E" }

function ActionDock.new(parent: Instance, opts)
	local self = setmetatable({}, ActionDock)
	self.character = opts.character
	self.touch = opts.touch == true
	self.def = Characters.get(self.character or "")
	self.abilityRoot = Util.frame(parent, { Name = "Ability" })
	self.rollRoot = Util.frame(parent, { Name = "DiceTray" })
	self.diceInfo = { dice = {}, mine = false, enabled = false, power = {} }
	self.powerInfo = { power = 0, cap = 1, usable = false, used = false, mine = false }
	self.recall = { show = false, enabled = false }
	self.selected = nil
	self.diceSkin = opts.diceSkin
	return self
end

function ActionDock:destroy()
	self.abilityRoot:Destroy()
	self.rollRoot:Destroy()
end

local function place(f: Frame, r)
	f.Position = UDim2.fromOffset(r.x, r.y)
	f.Size = UDim2.fromOffset(r.w, r.h)
end

-- A sticker panel: candy surface, the dark outline and a hard shadow under it.
local function slab(parent: Instance, color: Color3, corner: number): Frame
	local shadow = Util.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = C.shadow,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	Util.corner(shadow, corner)
	local face = Util.new("Frame", {
		Name = "Slab",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	Util.corner(face, corner)
	Util.stroke(face, C.line, 3)
	return face
end

function ActionDock:layout(abilityRect, rollRect, form: string)
	self.form = form
	place(self.abilityRoot, abilityRect)
	place(self.rollRoot, rollRect)
	Util.clear(self.abilityRoot)
	Util.clear(self.rollRoot)
	self:_buildPower(abilityRect, form)
	self:_buildTray(rollRect, form)
	self:setDice(self.diceInfo)
	local pi = self.powerInfo
	self:setPower(pi.power, pi.cap, pi)
	self:setRecall(self.recall.show, self.recall.enabled)
end

---------------------------------------------------------------------------
-- Power panel
---------------------------------------------------------------------------

function ActionDock:_buildPower(r, form: string)
	local def = self.def
	local ability = def and def.ability
	local color = Theme.Character[self.character] or C.grape
	local box = self.abilityRoot
	self.abilityDef = ability
	self.abilityButton = nil
	self.bar = nil
	self.powerLabel = nil

	local function portrait(size: number, x: number, y: number)
		local p = Util.new("TextButton", {
			Name = "Portrait",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 2,
			Parent = box,
		})
		Icons.medallion(p, self.character or "info", color, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
		p.Activated:Connect(function()
			if self.onPortrait then
				self.onPortrait()
			end
		end)
		p.MouseEnter:Connect(function()
			Util.tween(Util.scaler(p), 0.12, { Scale = 1.08 }, Enum.EasingStyle.Back)
		end)
		p.MouseLeave:Connect(function()
			Util.tween(Util.scaler(p), 0.12, { Scale = 1 })
		end)
		return p
	end

	local function abilityButton(x: number, y: number, w: number, h: number, textSize: number)
		return Widgets.button(box, {
			name = "AbilityButton",
			text = if ability then ability.name else "",
			style = ABILITY_STYLE[self.character] or "wood",
			textSize = textSize,
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromOffset(x, y),
			depth = 4,
			z = 3,
			onClick = function()
				if self.onAbility then
					self.onAbility()
				end
			end,
		})
	end

	if form == "wide" then
		slab(box, C.panel, 16)
		local ps = math.min(70, r.h - 50)
		portrait(ps, 10, 10)
		local tx = ps + 20
		Widgets.label(box, {
			name = "Name",
			text = if def then def.name else "",
			font = "chunky",
			size = 19,
			color = C.text,
			outline = C.line,
			sizeUDim = UDim2.fromOffset(r.w - tx - 10, 22),
			position = UDim2.fromOffset(tx, 10),
			z = 2,
		})
		self.powerLabel = Widgets.label(box, {
			name = "PowerText",
			text = "",
			font = "heavy",
			size = 13,
			color = C.textSoft,
			sizeUDim = UDim2.fromOffset(r.w - tx - 10, 16),
			position = UDim2.fromOffset(tx, 32),
			z = 2,
		})
		self.bar = self:_bar(box, tx, 52, r.w - tx - 12, 18)
		if ability then
			self.abilityButton = abilityButton(10, r.h - 50, r.w - 20, 42, 19)
		end
	elseif form == "short" then
		local ps = math.min(38, r.h - 34)
		portrait(ps, 0, 0)
		self.bar = self:_bar(box, ps + 6, math.floor((ps - 14) / 2), r.w - ps - 6, 14)
		if ability then
			self.abilityButton = abilityButton(0, ps + 4, r.w, math.max(30, r.h - ps - 4), 15)
		end
	else
		-- upright phone: the button with the bar along its bottom edge
		if ability then
			self.abilityButton = abilityButton(0, 0, r.w, r.h - 10, 14)
		end
		self.bar = self:_bar(box, 4, r.h - 9, r.w - 8, 9)
	end
end

--[[
	The Power bar: one segment per point of Power the ability costs (up to 10; more
	than that and it becomes one smooth bar), filled in the character's colour.
]]
function ActionDock:_bar(parent: Instance, x: number, y: number, w: number, h: number)
	local track = Util.new("Frame", {
		Name = "PowerBar",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 4,
		Parent = parent,
	})
	Util.corner(track, 0.5)
	Util.stroke(track, C.line, if h >= 12 then 2.5 else 2)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Character[self.character] or C.sun,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = track,
	})
	Util.corner(fill, 0.5)
	local shine = Util.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 0, 2),
		Size = UDim2.new(1, -6, 0.3, 0),
		ZIndex = 6,
		Parent = fill,
	})
	Util.corner(shine, 0.5)
	local ticks = Util.frame(track, { Name = "Ticks", ZIndex = 7 })
	return { track = track, fill = fill, ticks = ticks, w = w, h = h, cap = 0 }
end

function ActionDock:_drawTicks(cap: number)
	local bar = self.bar
	if not bar or bar.cap == cap then
		return
	end
	bar.cap = cap
	Util.clear(bar.ticks)
	if cap <= 1 or cap > 10 then
		return
	end
	for i = 1, cap - 1 do
		local tick = Util.new("Frame", {
			Name = "Tick" .. i,
			BackgroundColor3 = C.line,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(i / cap, 0, 0, 2),
			Size = UDim2.new(0, 2, 1, -4),
			ZIndex = 7,
			Parent = bar.ticks,
		})
		local _ = tick
	end
end

--[[
	power / cap: the bar. o = { usable (the button works now), used (already used this
	turn), mine (it's my turn) }.
]]
function ActionDock:setPower(power: number, cap: number, o)
	local before = self.powerInfo.power
	self.powerInfo = { power = power, cap = cap, usable = o.usable == true, used = o.used == true, mine = o.mine == true }
	local full = cap > 0 and power >= cap
	local bar = self.bar
	if bar then
		self:_drawTicks(cap)
		local k = if cap > 0 then math.clamp(power / cap, 0, 1) else 0
		Util.tween(bar.fill, 0.35, { Size = UDim2.fromScale(k, 1) }, Enum.EasingStyle.Back)
		local fill = bar.fill :: Frame
		-- a tween (not a plain set) so it also cancels a glow tween still running
		Util.tween(fill, 0.12, { BackgroundColor3 = if full then C.sun else (Theme.Character[self.character] or C.sky) })
		if power > before then
			Util.bump(bar.track, 0.08)
		end
		-- a full bar glows (one pulse loop per bar: a relayout builds a new one)
		if full and self.pulseBar ~= bar then
			self.pulseBar = bar
			task.spawn(function()
				local track = bar.track
				while self.pulseBar == bar and track.Parent do
					Util.tween(bar.fill, 0.45, { BackgroundColor3 = C.sunLight }, Enum.EasingStyle.Sine)
					task.wait(0.45)
					Util.tween(bar.fill, 0.45, { BackgroundColor3 = C.sun }, Enum.EasingStyle.Sine)
					task.wait(0.45)
				end
			end)
		elseif not full then
			self.pulseBar = nil
		end
	end
	if self.powerLabel then
		local ab = self.abilityDef
		self.powerLabel.Text = if not ab then "" elseif full then "Power full!" else string.format("Power %d / %d", power, cap)
		self.powerLabel.TextColor3 = if full then C.sun else C.textSoft
	end
	local btn = self.abilityButton
	if btn then
		local usable = self.powerInfo.usable
		btn:setEnabled(usable)
		btn:pulse(usable)
		if self.form == "tall" and self.abilityDef then
			btn:setText(self.abilityDef.name .. (if full then "!" else string.format(" %d/%d", power, cap)))
		end
	end
end

---------------------------------------------------------------------------
-- dice tray
---------------------------------------------------------------------------

function ActionDock:_buildTray(r, form: string)
	local box = self.rollRoot
	slab(box, C.panel, 16)
	self.trayRect = r
	local captionH = if form == "wide" then 20 else 0
	local footH = if form == "wide" then 30 elseif form == "short" then 26 else 0
	self.caption = nil
	if captionH > 0 then
		self.caption = Widgets.label(box, {
			name = "Caption",
			text = "",
			font = "chunky",
			size = 15,
			color = C.text,
			outline = C.line,
			align = "center",
			sizeUDim = UDim2.new(1, -16, 0, captionH),
			position = UDim2.fromOffset(8, 6),
			z = 3,
		})
		self.caption.TextTruncate = Enum.TextTruncate.AtEnd
	end
	-- where the dice sit
	self.diceArea = Util.frame(box, {
		Name = "Dice",
		Position = UDim2.fromOffset(6, 6 + captionH),
		Size = UDim2.new(1, -12, 1, -(12 + captionH + footH)),
		ZIndex = 3,
	})
	-- the footer: TOTAL for doubles, RECALL, or a line of help
	self.foot = Util.frame(box, {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, -6),
		Size = UDim2.new(1, -12, 0, math.max(footH, 0)),
		ZIndex = 3,
	})
	self.footLabel = nil
	if footH > 0 then
		self.footLabel = Widgets.label(self.foot, {
			name = "Help",
			text = "",
			font = "heavy",
			size = if form == "wide" then 13 else 11,
			color = C.textSoft,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.fromScale(1, 1),
			z = 4,
		})
	end
	self.sumButton = Widgets.button(if footH > 0 then self.foot else box, {
		name = "Total",
		text = "Total",
		style = "brass",
		textSize = if form == "wide" then 16 else 13,
		depth = 3,
		corner = 10,
		size = if footH > 0 then UDim2.fromScale(1, 1) else UDim2.new(0.62, 0, 0, 24),
		anchor = if footH > 0 then Vector2.zero else Vector2.new(0.5, 1),
		position = if footH > 0 then UDim2.new() else UDim2.new(0.5, 0, 1, -2),
		z = 8,
		onClick = function()
			self:_dieClicked("sum")
		end,
	})
	self.sumButton.root.Visible = false
	self.sumButton.root.MouseEnter:Connect(function()
		self:_hover("sum")
	end)
	self.sumButton.root.MouseLeave:Connect(function()
		self:_hover(nil)
	end)
	self.recallButton = Widgets.button(if footH > 0 then self.foot else box, {
		name = "Recall",
		text = "Recall",
		icon = "time_potion",
		style = "purple",
		textSize = if form == "wide" then 15 else 12,
		depth = 3,
		corner = 10,
		size = if footH > 0 then UDim2.fromScale(1, 1) else UDim2.new(0.7, 0, 0, 24),
		anchor = if footH > 0 then Vector2.zero else Vector2.new(0.5, 0),
		position = if footH > 0 then UDim2.new() else UDim2.new(0.5, 0, 0, 2),
		z = 8,
		onClick = function()
			if self.onRecall then
				self.onRecall()
			end
		end,
	})
	self.recallButton.root.Visible = false

	-- your turn's countdown. An upright phone has no room around the tray (the ability
	-- sits right above it), so there it's a line along the tray's top edge.
	self.clockBar = nil
	self.clockBadge = nil
	self.clockShown = nil
	if form ~= "wide" and form ~= "short" then
		local bar = Widgets.progress(box, {
			name = "ClockBar",
			plain = true,
			size = UDim2.new(1, -24, 0, 3),
			position = UDim2.fromOffset(12, 3),
			value = 1,
			color = C.sun,
			z = 30,
		})
		bar.root.Visible = false
		self.clockBar = bar
		self.dieWidgets = {}
		self.dieCount = 0
		return
	end
	-- a clock badge on the tray's top corner
	local badge = Util.new("Frame", {
		Name = "Clock",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(if form == "wide" then 58 else 48, if form == "wide" then 24 else 20),
		ZIndex = 30,
		Visible = false,
		Parent = box,
	})
	Util.corner(badge, 0.5)
	Util.stroke(badge, C.line, 2)
	self.clockLabel = Widgets.label(badge, {
		text = "",
		font = "chunky",
		size = if form == "wide" then 16 else 14,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 31,
	})
	self.clockBadge = badge
	self.clockShown = nil
	self.dieWidgets = {}
	self.dieCount = 0
end

-- Builds the die buttons for `n` dice.
function ActionDock:_buildDice(n: number)
	Util.clear(self.diceArea)
	self.dieWidgets = {}
	self.dieCount = n
	if n == 0 then
		return
	end
	local areaFrame = self.diceArea :: Frame
	local area = areaFrame.AbsoluteSize
	local k = Util.inheritedScale(areaFrame, true)
	local aw = if area.X > 0 then area.X / k else (self.trayRect.w - 12)
	local ah = if area.Y > 0 then area.Y / k else (self.trayRect.h - 40)
	local gap = if self.form == "wide" then 12 else 8
	-- the +POWER tag hangs under each die: leave room for it inside the dice area
	-- (and the hover ring sticks out above it: room for that too, under the caption)
	local size = math.floor(math.min((ah - 8) / 1.24, (aw - (n - 1) * gap) / n, 84))
	local overhang = math.floor(size * 0.16)
	local ringTop = math.ceil(size * 0.08) + 2
	local total = n * size + (n - 1) * gap
	for i = 1, n do
		local x = (aw - total) / 2 + (i - 1) * (size + gap)
		local btn = Util.new("TextButton", {
			Name = "Die" .. i,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, math.max(ringTop, (ah - size - overhang) / 2)),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 4,
			Parent = self.diceArea,
		})
		local lift = Util.frame(btn, { Name = "Lift", ZIndex = 4 })
		-- a glow ring behind the die: hovered or picked
		local ring = Util.new("Frame", {
			Name = "Ring",
			BackgroundColor3 = C.sun,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.16, 1.16),
			ZIndex = 3,
			Parent = lift,
		})
		Util.corner(ring, 0.3)
		local die, setValue = CosmeticArt.die(lift, self.diceSkin, 1, {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
		-- dims a die that wasn't chosen
		local dim = Util.new("Frame", {
			Name = "Dim",
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.96, 0.96),
			Visible = false,
			ZIndex = 8,
			Parent = lift,
		})
		Util.corner(dim, 0.24)
		-- the Power this choice would charge (the other die), on a little tag
		local tag = Widgets.badge(lift, {
			name = "PowerTag",
			text = "",
			color = C.sun,
			height = math.max(16, math.floor(size * 0.28)),
			textSize = math.max(11, math.floor(size * 0.2)),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 1, -2),
			z = 9,
		})
		tag.Visible = false
		local keyHint = nil
		if not self.touch and self.form == "wide" then
			-- its keyboard key, on a little key cap at its lower corner
			keyHint = Util.new("Frame", {
				Name = "Key",
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 2, 1, -2),
				Size = UDim2.fromOffset(18, 18),
				ZIndex = 9,
				Parent = lift,
			})
			Util.corner(keyHint, 4)
			Util.stroke(keyHint, C.line, 2)
			Widgets.label(keyHint, {
				text = DIE_KEYS[i] or "",
				font = "chunky",
				size = 13,
				color = C.text,
				align = "center",
				sizeUDim = UDim2.fromScale(1, 1),
				z = 10,
			})
		end
		-- the second die of doubles goes the other way: a BACK flag on its top edge
		local back = Widgets.badge(lift, {
			name = "BackTag",
			text = "Back",
			color = C.coral,
			height = math.max(16, math.floor(size * 0.26)),
			textSize = math.max(11, math.floor(size * 0.19)),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 0, 2),
			z = 9,
		})
		back.Visible = false
		local gold = Widgets.badge(lift, {
			name = "GoldTag",
			text = "Gold",
			color = C.sun,
			height = math.max(16, math.floor(size * 0.26)),
			textSize = math.max(11, math.floor(size * 0.19)),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 0, 2),
			z = 9,
		})
		gold.Visible = false
		local w = { button = btn, lift = lift, ring = ring, die = die, dim = dim, setValue = setValue, tag = tag, back = back, gold = gold, key = keyHint, index = i, size = size }
		self.dieWidgets[i] = w
		btn.MouseEnter:Connect(function()
			self:_hover(i)
		end)
		btn.MouseLeave:Connect(function()
			self:_hover(nil)
		end)
		btn.Activated:Connect(function()
			self:_dieClicked(i)
		end)
	end
end

function ActionDock:_canPick(): boolean
	local d = self.diceInfo
	return d.mine == true and d.enabled == true and d.chosen == nil
end

function ActionDock:_hover(key: any)
	if not self:_canPick() then
		return
	end
	if self.touch then
		return -- touch screens select with a first tap instead
	end
	self:_showSelected(key)
	if self.onDieHover then
		self.onDieHover(key)
	end
end

function ActionDock:_dieClicked(key: any)
	if not self:_canPick() then
		if self.diceInfo.mine and self.diceInfo.chosen == nil then
			Sound.play("error")
		end
		return
	end
	if self.touch and self.selected ~= key then
		-- first tap: show where it goes; tap again to move
		self.selected = key
		self:_showSelected(key)
		Sound.play("hover")
		if self.onDieHover then
			self.onDieHover(key)
		end
		self:_updateFoot()
		return
	end
	self.selected = nil
	if self.onDie then
		self.onDie(key)
	end
end

function ActionDock:clearSelection()
	self.selected = nil
	self:_showSelected(nil)
	self:_updateFoot()
end

-- Lifts the die (or both, for the TOTAL) under the pointer / picked on touch.
function ActionDock:_showSelected(key: any)
	for i, w in self.dieWidgets do
		local on = key == i or (key == "sum" and self.diceInfo.sum)
		Util.tween(w.lift, 0.12, { Position = UDim2.fromOffset(0, if on then -6 else 0) }, Enum.EasingStyle.Back)
		Util.tween(w.ring, 0.12, { BackgroundTransparency = if on then 0.15 else 1 })
	end
end

--[[
	info = {
		dice = { numbers },      -- the roll on the table
		mine = boolean,          -- my dice (it's my turn)
		owner = string?,         -- whose dice, when not mine
		frozen = boolean,        -- one halved die
		chosen = key?,           -- picked already (the move is happening)
		enabled = boolean,       -- I may pick now
		power = { [key] = n },   -- Power each choice would charge
		back = { [key] = true }, -- dice that move you backwards (the second of a pair)
		gold = key?,             -- the underdog's extra die (moves you, charges no Power)
		hint = string?,          -- the footer's line when there's nothing else to show
	}
]]
function ActionDock:setDice(info)
	self.diceInfo = info
	if not self.diceArea then
		return
	end
	local dice = info.dice or {}
	if #dice ~= self.dieCount then
		self:_buildDice(#dice)
	end
	local sum = #dice == 2 and dice[1] == dice[2]
	info.sum = sum
	for i, w in self.dieWidgets do
		w.setValue(dice[i] or 1)
		local chosen = info.chosen
		local picked = chosen == i or (chosen == "sum")
		w.back.Visible = info.back ~= nil and info.back[i] == true and (chosen == nil or chosen == i)
		-- the underdog's gold die: moves you, never charges Power
		w.gold.Visible = info.gold == i and not w.back.Visible
		local faded = chosen ~= nil and not picked
		w.die.Rotation = 0
		w.dim.Visible = faded
		local power = info.power and info.power[i]
		local showTag = info.mine and chosen == nil and power ~= nil and power > 0 and info.enabled
		w.tag.Visible = showTag == true
		if showTag then
			local label = w.tag:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				-- small dice (phones) have room for the number only
				label.Text = "+" .. tostring(power) .. (if w.size >= 64 then " Power" else "")
			end
		end
		if w.key then
			w.key.Visible = info.mine == true and info.enabled == true and chosen == nil
		end
		w.button.Active = info.mine == true
	end
	if self.caption then
		if info.over then
			self.caption.Text = "Game over"
		elseif #dice == 0 then
			self.caption.Text = if info.mine then "Your dice" else ""
		elseif info.mine then
			self.caption.Text = if info.chosen ~= nil then "Go!" elseif info.frozen then "Frozen: one die" else "Pick a die"
		else
			self.caption.Text = (info.owner or "") .. "'s dice"
		end
		self.caption.TextColor3 = if info.mine and info.frozen then C.sky elseif info.mine then C.text else C.textSoft
	end
	if info.chosen == nil and not self:_canPick() then
		self.selected = nil
	end
	self:_showSelected(self.selected)
	self:_updateFoot()
end

-- The footer: TOTAL (doubles), RECALL (an anchor down) or a line of help.
function ActionDock:_updateFoot()
	local info = self.diceInfo
	local canPick = self:_canPick()
	local showSum = canPick and info.sum == true
	local showRecall = canPick and self.recall.show and not showSum
	if self.sumButton then
		self.sumButton.root.Visible = showSum
		if showSum then
			local dice = info.dice
			self.sumButton:setText("Total " .. tostring((dice[1] or 0) + (dice[2] or 0)) .. (if self.selected == "sum" then "  Go!" else ""))
			self.sumButton:setEnabled(true)
		end
	end
	if self.recallButton then
		self.recallButton.root.Visible = showRecall
		self.recallButton:setEnabled(self.recall.enabled)
	end
	if self.footLabel then
		self.footLabel.Visible = not showSum and not showRecall
		local text = info.hint or ""
		if canPick then
			if self.touch then
				text = if self.selected ~= nil then "Tap it again to go!" else "Tap a die to see where it goes"
			else
				text = "Hover a die to preview, click to go"
			end
		end
		self.footLabel.Text = text
	end
end

-- The tray's footer line, when nothing else is there ("Waiting for Bot Lily...").
function ActionDock:setHint(text: string?)
	self.diceInfo.hint = text
	self:_updateFoot()
end

function ActionDock:setRecall(show: boolean, enabled: boolean)
	self.recall = { show = show, enabled = enabled }
	self:_updateFoot()
end

-- The dice tumble onto the tray (yields about half the roll's time).
function ActionDock:rollDice(dice: { number }, frozen: boolean, speed: number)
	if not self.diceArea then
		return
	end
	if #dice ~= self.dieCount then
		self:_buildDice(#dice)
	end
	Sound.play("dice")
	local tumble = 0.55 * math.clamp(speed, 0.25, 1)
	local t0 = os.clock()
	for _, w in self.dieWidgets do
		local s = Util.scaler(w.lift)
		s.Scale = 0.3
		Util.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		w.tag.Visible = false
	end
	while os.clock() - t0 < tumble do
		for _, w in self.dieWidgets do
			w.setValue(math.random(1, 6))
			w.die.Rotation = (math.random() - 0.5) * 40
		end
		task.wait(0.06)
	end
	for i, w in self.dieWidgets do
		w.setValue(dice[i] or 1)
		Util.tween(w.die, 0.22, { Rotation = 0 }, Enum.EasingStyle.Back)
		local s = Util.scaler(w.lift)
		s.Scale = 1.25
		Util.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Bounce)
	end
	Sound.play("diceLand")
	if frozen then
		for _, w in self.dieWidgets do
			Util.shake(w.lift, 4, 0.3)
		end
	elseif #dice == 2 and dice[1] == dice[2] then
		-- doubles!
		for _, w in self.dieWidgets do
			Util.bump(w.lift, 0.2)
		end
		Sound.play("reveal")
	end
end

-- One die changed by itself (a Compass): it hops.
function ActionDock:bumpDie(i: number)
	local w = self.dieWidgets and self.dieWidgets[i]
	if w then
		Util.bump(w.lift, 0.25)
		Sound.play("diceLand")
	end
end

-- The chosen die pops; the others fade back.
function ActionDock:choose(key: any)
	for i, w in self.dieWidgets do
		if key == i or key == "sum" then
			Util.bump(w.lift, 0.25)
		end
	end
end

--[[
	Your turn's countdown (nil hides it). Shown when the game has a timer; turns red
	and ticks in the last seconds, before the turn is played for you.
]]
function ActionDock:setClock(left: number?)
	local bar = self.clockBar
	if bar then
		if left == nil then
			bar.root.Visible = false
			self.clockShown = nil
			return
		end
		if not bar.root.Visible then
			-- the countdown starts full: whatever time this turn (or shop) began with
			bar.root.Visible = true
			self.clockTotal = math.max(1, left)
		end
		bar:set(math.clamp(left / (self.clockTotal or 1), 0, 1), true)
		local secs = math.max(0, math.ceil(left))
		bar.fill.BackgroundColor3 = if secs <= 10 then C.bad else C.sun
		if secs ~= self.clockShown then
			self.clockShown = secs
			if secs <= 5 and secs > 0 then
				Sound.play("tick", 1.15)
			end
		end
		return
	end
	local badge = self.clockBadge
	if not badge then
		return
	end
	if left == nil then
		badge.Visible = false
		self.clockShown = nil
		return
	end
	local secs = math.max(0, math.ceil(left))
	badge.Visible = true
	if secs == self.clockShown then
		return
	end
	self.clockShown = secs
	self.clockLabel.Text = string.format("%d:%02d", secs // 60, secs % 60)
	local urgent = secs <= 10
	badge.BackgroundColor3 = if urgent then C.bad else C.panelDeep
	if urgent and secs > 0 then
		Util.bump(badge, 0.12)
		if secs <= 5 then
			Sound.play("tick", 1.15)
		end
	end
end

return ActionDock
