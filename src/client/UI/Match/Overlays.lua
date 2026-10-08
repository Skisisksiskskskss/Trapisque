--[[
	Overlays
	The big animated moments of a match, drawn above the board:
	dice rolls, the spinner wheel, turn/ability banners, the Potion Seller, the card
	inspector, the character reveal and the event log.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Game.Items)
local Characters = require(Shared.Game.Characters)
local Config = require(Shared.Config)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CosmeticArt = require(UI.CosmeticArt)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex
local T = Config.Timing

local Overlays = {}

---------------------------------------------------------------------------
-- dice
---------------------------------------------------------------------------

local MOD_TEXT = {
	frozen = { "FROZEN", hex("5DADE2") },
	speed_boost = { "x2 SPEED", hex("5E9A3C") },
	speed_potion = { "+1 POTION", hex("4FA3FF") },
	bounce_pad = { "+2 BOUNCE", hex("5E9A3C") },
	slime = { "SLIMED", hex("7DB843") },
	boots = { "BOOTS ON", hex("8B6B3E") },
}

--[[ Rolls the die in `layer` (yields ~DiceTime). e = roll event. ]]
function Overlays.dice(layer: Frame, e, diceSkin: string?, speed: number)
	local box = Util.frame(layer, {
		Name = "DiceRoll",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(300, 220),
		ZIndex = 60,
	})
	local die, setValue = CosmeticArt.die(box, diceSkin, 1, {
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(96, 96),
		ZIndex = 61,
	})
	local s = Util.scaler(die)
	s.Scale = 0.2
	Util.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play("dice")
	local tumble = T.DiceTime * 0.55 * speed
	local t0 = os.clock()
	local n = 0
	while os.clock() - t0 < tumble do
		n += 1
		setValue(math.random(1, 6))
		die.Rotation = (math.random() - 0.5) * 50
		die.Position = UDim2.new(0.5, (math.random() - 0.5) * 16, 0, 50 + (math.random() - 0.5) * 10)
		task.wait(0.06)
	end
	setValue(e.die)
	Util.tween(die, 0.25, { Rotation = 0, Position = UDim2.new(0.5, 0, 0, 50) }, Enum.EasingStyle.Back)
	s.Scale = 1.3
	Util.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Bounce)
	Sound.play("diceLand")

	-- modifiers and the final move
	local info = Util.frame(box, {
		Name = "Info",
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = 62,
	})
	Util.list(info, "x", 6, "Center", "Center")
	if e.held then
		Widgets.badge(info, { text = if e.die >= Config.Rules.GateEscapeMin then "BROKE FREE!" else "STILL STUCK", color = hex("6D747C"), height = 30, textSize = 18, z = 63 })
	end
	for i, m in e.mods or {} do
		local spec = MOD_TEXT[m]
		if spec then
			task.delay(0.12 * i * speed, function()
				local b = Widgets.badge(info, { text = spec[1], color = spec[2], height = 30, textSize = 18, z = 63, layoutOrder = i })
				Util.popIn(b, 0.25, 0.5)
			end)
		end
	end
	local final = #(e.mods or {}) > 0 or e.move ~= e.die
	if final and not e.held then
		task.delay(0.12 * (#(e.mods or {}) + 1) * speed, function()
			local b = Widgets.badge(info, { text = "MOVE " .. e.move, color = C.brassDark, height = 34, textSize = 22, z = 63, layoutOrder = 99 })
			Util.popIn(b, 0.3, 0.4)
		end)
	end
	task.wait(T.DiceTime * 0.45 * speed)
	Util.tween(s, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, d in info:GetDescendants() do
		if d:IsA("Frame") then
			Util.tween(d, 0.18, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then
			Util.tween(d, 0.18, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Util.tween(d, 0.18, { Transparency = 1 })
		end
	end
	task.delay(0.2, function()
		box:Destroy()
	end)
end

---------------------------------------------------------------------------
-- spinner wheel
---------------------------------------------------------------------------

local WHEEL_COLOR = { trap = Theme.Category.trap, assist = Theme.Category.assist, neutral = Theme.Category.neutral }

-- What each segment of a wheel shows for this player on this map.
function Overlays.wheelSegments(wheel: string, mapDef, character: string?): { string }
	local out = {}
	for i, seg in Items.wheels[wheel] do
		if seg == "bkb" then
			out[i] = if character == "naturalist" then mapDef.naturalCard else mapDef.counterItem
		else
			out[i] = seg
		end
	end
	return out
end

--[[ Spins a wheel and lands on segment `index` (yields ~SpinTime). ]]
function Overlays.spin(layer: Frame, wheel: string, segments: { string }, index: number, speed: number)
	local color = WHEEL_COLOR[wheel] or C.brass
	local n = #segments
	local dim = Util.new("Frame", {
		Name = "SpinDim",
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = layer,
	})
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.5 })
	local holder = Util.frame(dim, {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(330, 330),
		ZIndex = 71,
	})
	Util.popIn(holder, 0.3, 0.5)
	-- shadow, brass rim, wooden disc
	local canvas = Shapes.canvas(holder)
	Shapes.circle(canvas, 0.5, 0.53, 1, C.black, { t = 0.6 })
	Shapes.circle(canvas, 0.5, 0.5, 1, C.brassDark)
	Shapes.circle(canvas, 0.5, 0.5, 0.95, C.brass)
	local spinFrame = Util.frame(holder, {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.88),
		ZIndex = 72,
	})
	local disc = Shapes.canvas(spinFrame)
	Shapes.circle(disc, 0.5, 0.5, 1, C.woodLight)
	Shapes.circle(disc, 0.5, 0.5, 0.94, C.wood)
	for i = 1, n do
		-- spokes between segments
		local a = math.rad((i - 0.5) * 360 / n - 90)
		Shapes.line(disc, 0.5, 0.5, 0.5 + math.cos(a) * 0.47, 0.5 + math.sin(a) * 0.47, 0.012, C.woodDeep)
		-- segment pocket with its prize
		local b = math.rad((i - 1) * 360 / n - 90)
		local px, py = 0.5 + math.cos(b) * 0.33, 0.5 + math.sin(b) * 0.33
		local pocketColor = if i % 2 == 0 then color else Util.shade(color, -0.25)
		local seg = segments[i]
		if seg == "coin" then
			pocketColor = C.brassDark
		end
		local pocket = Util.frame(disc, {
			Name = "Pocket" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(px, py),
			Size = UDim2.fromScale(0.25, 0.25),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Rotation = (i - 1) * 360 / n,
			ZIndex = 3,
		})
		Icons.medallion(pocket, seg, pocketColor, { Size = UDim2.fromScale(1, 1) })
	end
	Shapes.circle(disc, 0.5, 0.5, 0.2, C.brass)
	Shapes.circle(disc, 0.5, 0.5, 0.12, C.brassDark)
	-- pointer at the top
	local pointer = Util.frame(holder, {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 80,
	})
	local pc = Shapes.canvas(pointer)
	Shapes.tri(pc, 0.5, 0.2, 0.9, C.inkRed, { dir = 180 })
	Shapes.circle(pc, 0.5, 0.18, 0.32, C.brassLight)

	-- spin: several turns, landing with segment `index` under the pointer
	local turns = 4
	local finalRot = turns * 360 - (index - 1) * 360 / n + (math.random() - 0.5) * (300 / n)
	local duration = T.SpinTime * 0.72 * speed
	spinFrame.Rotation = 0
	Util.tween(spinFrame, duration, { Rotation = finalRot }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	-- ticks as pockets pass the pointer (approximation of the quartic ease)
	task.spawn(function()
		local last = 0
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local p = (os.clock() - t0) / duration
			local eased = 1 - (1 - p) ^ 4
			local passed = math.floor(eased * finalRot / (360 / n))
			if passed ~= last then
				last = passed
				Sound.play("tick", 1 + eased * 0.3)
				Util.bump(pointer, 0.1)
			end
			task.wait(1 / 60)
		end
	end)
	task.wait(duration)
	Sound.play("reveal")
	local winner = disc:FindFirstChild("Pocket" .. index)
	if winner then
		Util.bump(winner :: GuiObject, 0.35)
	end
	task.wait(T.SpinTime * 0.2 * speed)
	Util.tween(dim, 0.2, { BackgroundTransparency = 1 })
	Util.tween(Util.scaler(holder), 0.2, { Scale = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in holder:GetDescendants() do
		if d:IsA("Frame") then
			Util.tween(d, 0.2, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Util.tween(d, 0.2, { Transparency = 1 })
		end
	end
	task.delay(0.22, function()
		dim:Destroy()
	end)
end

---------------------------------------------------------------------------
-- flying cards and coins
---------------------------------------------------------------------------

-- A card flies from one screen spot to another and shrinks into its target.
function Overlays.flyCard(layer: Frame, itemId: string, from: Vector2, to: Vector2, speed: number)
	if not Items.get(itemId) then
		return
	end
	local card = Cards.item(layer, itemId, {
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(110, 110 / 0.72),
		ZIndex = 90,
	})
	local root = card.root
	local s = Util.scaler(root)
	s.Scale = 0.3
	Sound.play("card")
	Util.tween(s, 0.25 * speed, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.wait(0.35 * speed)
	Util.tween(root, 0.4 * speed, { Position = UDim2.fromOffset(to.X, to.Y), Rotation = (math.random() - 0.5) * 20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Util.tween(s, 0.4 * speed, { Scale = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.42 * speed, function()
		root:Destroy()
	end)
end

function Overlays.flyIcon(layer: Frame, iconId: string, color: Color3, from: Vector2, to: Vector2, speed: number)
	local h = Util.frame(layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 90,
	})
	Icons.medallion(h, iconId, color, { Size = UDim2.fromScale(1, 1) })
	Util.popIn(h, 0.2, 0.3)
	Util.tween(h, 0.5 * speed, { Position = UDim2.fromOffset(to.X, to.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.5 * speed, function()
		h:Destroy()
	end)
end

---------------------------------------------------------------------------
-- banners
---------------------------------------------------------------------------

-- "Pip's turn" ribbon that sweeps across the top of the board.
function Overlays.turnBanner(layer: Frame, text: string, seatColor: Color3, mine: boolean, speed: number)
	local banner = Util.new("Frame", {
		Name = "TurnBanner",
		BackgroundColor3 = if mine then C.brass else C.parchmentMid,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(-0.3, 0, 0.12, 0),
		Size = UDim2.fromOffset(if mine then 380 else 320, if mine then 62 else 50),
		ZIndex = 85,
		Parent = layer,
	})
	Util.corner(banner, 14)
	Util.stroke(banner, C.ink, 3)
	local stripe = Util.new("Frame", {
		BackgroundColor3 = seatColor,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 14, 1, 0),
		ZIndex = 86,
		Parent = banner,
	})
	Util.corner(stripe, 10)
	Widgets.label(banner, {
		text = text,
		font = "chunky",
		size = if mine then 32 else 26,
		color = C.ink,
		align = "center",
		sizeUDim = UDim2.new(1, -24, 1, 0),
		position = UDim2.fromOffset(18, 0),
		scaled = true,
		z = 87,
	})
	if mine then
		Sound.play("turn")
	end
	local hold = (if mine then 0.55 else 0.3) * speed
	Util.tween(banner, 0.28 * speed, { Position = UDim2.fromScale(0.5, 0.12) }, Enum.EasingStyle.Back)
	task.delay((0.28 + hold) * speed, function()
		Util.tween(banner, 0.25 * speed, { Position = UDim2.fromScale(1.3, 0.12) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.26 * speed, function()
			banner:Destroy()
		end)
	end)
end

-- Character card swoops in with the ability name.
function Overlays.abilityBanner(layer: Frame, character: string, abilityName: string, playerName: string, speed: number)
	local color = Theme.Character[character] or C.brass
	local wrap = Util.frame(layer, {
		Name = "AbilityBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.fromOffset(520, 180),
		ZIndex = 88,
	})
	local band = Util.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1.6, 0, 0, 92),
		Rotation = -4,
		ZIndex = 88,
		Parent = wrap,
	})
	Util.stroke(band, C.ink, 3)
	local card = Cards.character(wrap, character, {
		Position = UDim2.new(0.18, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 120 / 0.72),
		ZIndex = 90,
	})
	card.root.Rotation = -8
	Widgets.label(wrap, {
		text = string.upper(abilityName) .. "!",
		font = "chunky",
		size = 54,
		color = C.white,
		align = "left",
		sizeUDim = UDim2.new(0.62, 0, 0, 60),
		position = UDim2.new(0.34, 0, 0.5, -42),
		outline = C.ink,
		outlineThickness = 4,
		scaled = true,
		z = 91,
	})
	Widgets.label(wrap, {
		text = playerName .. " the " .. ((Characters.get(character) or { name = "" }).name),
		font = "heavy",
		size = 22,
		color = C.white,
		align = "left",
		sizeUDim = UDim2.new(0.62, 0, 0, 28),
		position = UDim2.new(0.34, 0, 0.5, 18),
		outline = C.ink,
		outlineThickness = 2,
		z = 91,
	})
	local s = Util.scaler(wrap)
	s.Scale = 0.4
	wrap.Position = UDim2.new(-0.4, 0, 0.42, 0)
	Util.tween(wrap, 0.3 * speed, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	Util.tween(s, 0.3 * speed, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play("magic", 0.9)
	task.delay(1.1 * speed, function()
		Util.tween(wrap, 0.25 * speed, { Position = UDim2.new(1.4, 0, 0.42, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.27 * speed, function()
			wrap:Destroy()
		end)
	end)
end

-- Big centred message ("Pip collected every treasure!", "Your turn!" etc.)
function Overlays.shout(layer: Frame, text: string, color: Color3, speed: number, sub: string?)
	local wrap = Util.frame(layer, {
		Name = "Shout",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(700, 110),
		ZIndex = 89,
	})
	Widgets.label(wrap, {
		text = text,
		font = "chunky",
		size = 56,
		color = color,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 64),
		outline = C.ink,
		outlineThickness = 4,
		scaled = true,
		z = 90,
	})
	if sub then
		Widgets.label(wrap, {
			text = sub,
			font = "heavy",
			size = 24,
			color = C.white,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 66),
			outline = C.ink,
			outlineThickness = 2,
			z = 90,
		})
	end
	Util.popIn(wrap, 0.35, 0.3)
	task.delay(1.3 * speed, function()
		for _, d in wrap:GetDescendants() do
			if d:IsA("TextLabel") then
				Util.tween(d, 0.25, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Util.tween(d, 0.25, { Transparency = 1 })
			end
		end
		task.delay(0.27, function()
			wrap:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------
-- event log
---------------------------------------------------------------------------

function Overlays.log(parent: Frame)
	local box = Util.frame(parent, {
		Name = "Log",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(360, 132),
		ZIndex = 40,
	})
	local list = Util.list(box, "y", 3, "Left", "Bottom")
	local lines = {}
	local log = {}
	function log.add(_self, text: string, color: Color3?)
		local row = Util.new("Frame", {
			BackgroundColor3 = C.dim,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			LayoutOrder = #lines + 1,
			ZIndex = 41,
			Parent = box,
		})
		Util.corner(row, 8)
		Util.pad(row, 8, 3, 8, 3)
		local label = Widgets.label(row, {
			text = text,
			font = "heavy",
			size = 15,
			color = color or C.parchment,
			z = 42,
			rich = true,
		})
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		Util.new("UISizeConstraint", { MaxSize = Vector2.new(344, 60), Parent = label })
		label.TextWrapped = true
		table.insert(lines, row)
		if #lines > 5 then
			local old = table.remove(lines, 1)
			old:Destroy()
		end
		Util.popIn(row, 0.2, 0.7)
		task.delay(9, function()
			if row.Parent then
				Util.tween(row, 0.5, { BackgroundTransparency = 1 })
				Util.tween(label, 0.5, { TextTransparency = 1 })
				task.delay(0.5, function()
					local i = table.find(lines, row)
					if i then
						table.remove(lines, i)
					end
					row:Destroy()
				end)
			end
		end)
	end
	local _ = list
	return log
end

---------------------------------------------------------------------------
-- character reveal (match intro)
---------------------------------------------------------------------------

function Overlays.reveal(layer: Frame, seats, duration: number)
	local n = #seats
	local row = Util.frame(layer, {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(math.min(900, n * 150), 260),
		ZIndex = 95,
	})
	Util.list(row, "x", 14, "Center", "Center")
	local cards = {}
	for i, info in seats do
		local slot = Util.frame(row, { Size = UDim2.fromOffset(130, 250), LayoutOrder = i })
		local card = Cards.character(slot, info.character or "mage", {
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(124, 124 / 0.72),
		})
		card:showBack(true, true)
		local name = Widgets.label(slot, {
			text = info.name,
			font = "heavy",
			size = 17,
			color = C.parchment,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 22),
			position = UDim2.new(0, 0, 1, -24),
			outline = C.ink,
		})
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local seatDot = Util.new("Frame", {
			BackgroundColor3 = Theme.Seat[((info.seat - 1) % 6) + 1],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(40, 6),
			Parent = slot,
		})
		Util.corner(seatDot, 0.5)
		Util.popIn(slot, 0.3, 0.2)
		cards[i] = card
		task.wait(0.08)
	end
	-- flip them over one by one
	local each = math.max(0.2, (duration - 1.2) / math.max(1, n))
	for _, card in cards do
		task.wait(each * 0.5)
		card:showBack(false)
		Sound.play("reveal", 0.9 + math.random() * 0.2)
	end
	task.wait(0.9)
	Util.tween(row, 0.3, { Position = UDim2.fromScale(0.5, 1.4) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.32, function()
		row:Destroy()
	end)
end

return Overlays
