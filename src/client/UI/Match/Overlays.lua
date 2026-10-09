--[[
	Overlays
	The big animated moments of a match, drawn above the board: dice rolls, the spinner
	wheel, turn and ability banners, shouts, flying cards and the character reveal.

	Each one is designed at a fixed size and shrinks (never grows) to fit the layer it
	plays in, so a portrait phone gets the same moments as a monitor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local CardStyle = require(UI.CardStyle)
local CosmeticArt = require(UI.CosmeticArt)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex
local T = Config.Timing

local Overlays = {}

-- The layer's size in stage pixels (its on-screen size with the stage scale undone).
local function stageSize(layer: GuiObject): Vector2
	local k = Util.inheritedScale(layer, false)
	return layer.AbsoluteSize / math.max(k, 0.01)
end

-- How much a w x h overlay must shrink to fit in `layer` with a margin.
local function fitScale(layer: GuiObject, w: number, h: number, margin: number?): number
	local size = stageSize(layer)
	local m = margin or 12
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	return math.clamp(math.min((size.X - 2 * m) / w, (size.Y - 2 * m) / h), 0.4, 1)
end

--[[
	A w x h frame centred at (sx, sy) of `layer` (or of `parent`, which covers it),
	shrunk to fit. The overlay builds inside it; its own pop and slide animations stay
	on the inner frames.
]]
local function fitted(layer: GuiObject, name: string, w: number, h: number, sx: number, sy: number, z: number, parent: Instance?): Frame
	local f = Util.frame(parent or layer, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(sx, sy),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z,
	})
	local k = fitScale(layer, w, h)
	if k < 1 then
		Util.new("UIScale", { Name = "Fit", Scale = k, Parent = f })
	end
	return f
end
Overlays.fitScale = fitScale

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
	local box = fitted(layer, "DiceRoll", 300, 220, 0.5, 0.4, 60)
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
	local fit = fitted(layer, "WheelFit", 330, 330, 0.5, 0.5, 71, dim)
	local holder = Util.frame(fit, {
		Name = "Wheel",
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

--[[
	A card flies from one stage spot to another and shrinks into its target, calling
	onLand() as it arrives (that's when the hand or the board shows it). Doesn't yield.
	opts.slam: it arcs over and is slapped down onto the target (a card being placed).
]]
function Overlays.flyCard(layer: Frame, itemId: string, from: Vector2, to: Vector2, speed: number, onLand: (() -> ())?, opts: { [string]: any }?)
	if not Items.get(itemId) then
		if onLand then
			onLand()
		end
		return
	end
	local slam = opts ~= nil and opts.slam == true
	local w = math.clamp(stageSize(layer).X * 0.14, 76, 110)
	local card = Cards.item(layer, itemId, {
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(w, w / 0.72),
		ZIndex = 90,
	})
	local root = card.root
	local s = Util.scaler(root)
	s.Scale = 0.3
	Sound.play("card")
	Util.tween(s, 0.25 * speed, { Scale = 1.15 }, Enum.EasingStyle.Back)
	local function landed()
		root:Destroy()
		if onLand then
			onLand()
		end
	end
	task.delay(0.35 * speed, function()
		if not root.Parent then
			-- the layer went away mid-flight: still land, so nothing waits forever
			if onLand then
				onLand()
			end
			return
		end
		if not slam then
			Util.tween(root, 0.4 * speed, { Position = UDim2.fromOffset(to.X, to.Y), Rotation = (math.random() - 0.5) * 20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Util.tween(s, 0.4 * speed, { Scale = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4 * speed, landed)
			return
		end
		-- over the top in an arc, turning upright, then slapped down onto the tile
		local dur = 0.42 * speed
		local mid = (from + to) / 2
		local lift = math.clamp((to - from).Magnitude * 0.35, 40, 160)
		local ctrl = mid - Vector2.new(0, lift)
		local spin = if to.X >= from.X then 1 else -1
		local alpha = Instance.new("NumberValue")
		alpha.Changed:Connect(function(t)
			if not root.Parent then
				return
			end
			local a = from:Lerp(ctrl, t)
			local b = ctrl:Lerp(to, t)
			local p = a:Lerp(b, t)
			root.Position = UDim2.fromOffset(p.X, p.Y)
			root.Rotation = spin * 18 * (1 - t)
		end)
		Util.tween(alpha, dur, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		Util.tween(s, dur * 0.7, { Scale = 1.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(dur * 0.7, function()
			Util.tween(s, dur * 0.3, { Scale = 0.42 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(dur, function()
			alpha:Destroy()
			landed()
		end)
	end)
end

--[[
	A card you've picked up to play. It follows the pointer (smoothly, leaning into the
	way it's moving) and shrinks to tile size over a spot where it can go.

		local held = Overlays.heldCard(layer, itemId, from, width)
		held:moveTo(stagePos) ; held:over(onATile) ; held:glow(on) ; held:hoverAt(stagePos)
		held:drop(at, onDone?)   -- stamped onto the board
		held:use(at, onDone?)    -- played (it flares and fades)
		held:back(to, onDone?)   -- returned to the hand
]]
function Overlays.heldCard(layer: Frame, itemId: string, from: Vector2, width: number)
	local w = math.clamp(width, 70, 120)
	local card = Cards.item(layer, itemId, {
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(w, w / CardStyle.aspect),
		ZIndex = 92,
	})
	local root = card.root
	local s = Util.scaler(root)
	Util.tween(s, 0.16, { Scale = 1.18 }, Enum.EasingStyle.Back)
	-- a brass outline that lights up when letting go would play it
	local rim = Util.new("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = root,
	})
	Util.corner(rim, CardStyle.corner)
	local rimStroke = Util.stroke(rim, C.brassLight, 4, 1)

	local pos = from
	local target = from
	local offset = Vector2.zero
	local following = true
	local overTile = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then
			conn:Disconnect()
			return
		end
		if not following then
			return
		end
		local k = 1 - math.exp(-dt * 20)
		local nextPos = pos + (target + offset - pos) * k
		local vx = (nextPos.X - pos.X) / math.max(dt, 1 / 240)
		pos = nextPos
		root.Position = UDim2.fromOffset(pos.X, pos.Y)
		local lean = math.clamp(vx * 0.018, -16, 16)
		root.Rotation += (lean - root.Rotation) * math.min(1, dt * 14)
	end)
	local held = {}
	local function stop()
		following = false
		conn:Disconnect()
	end
	function held.moveTo(_self, p: Vector2)
		target = p
	end
	function held.over(_self, on: boolean)
		if on == overTile then
			return
		end
		overTile = on
		-- over a tile it can go on, the card shrinks and lifts off beside the pointer, so
		-- the tile underneath can show what it's about to become
		offset = if on then Vector2.new(w * 0.42, -w * 0.62) else Vector2.zero
		Util.tween(s, 0.14, { Scale = if on then 0.66 else 1.18 }, Enum.EasingStyle.Back)
	end
	function held.glow(_self, on: boolean)
		Util.tween(rimStroke, 0.12, { Transparency = if on then 0 else 1 })
	end
	function held.hoverAt(_self, p: Vector2)
		target = p
		held:over(true)
	end
	function held.drop(_self, at: Vector2, onDone: (() -> ())?)
		stop()
		Util.tween(root, 0.09, { Position = UDim2.fromOffset(at.X, at.Y - 14), Rotation = 0 }, Enum.EasingStyle.Quad)
		Util.tween(s, 0.09, { Scale = 0.9 }, Enum.EasingStyle.Quad)
		task.delay(0.09, function()
			Util.tween(root, 0.07, { Position = UDim2.fromOffset(at.X, at.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Util.tween(s, 0.07, { Scale = 0.45 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.07, function()
				root:Destroy()
				if onDone then
					onDone()
				end
			end)
		end)
	end
	function held.use(_self, at: Vector2, onDone: (() -> ())?)
		stop()
		Util.tween(root, 0.12, { Position = UDim2.fromOffset(at.X, at.Y - 20), Rotation = 0 }, Enum.EasingStyle.Quad)
		Util.tween(s, 0.12, { Scale = 1.35 }, Enum.EasingStyle.Back)
		task.delay(0.14, function()
			Util.tween(s, 0.16, { Scale = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.16, function()
				root:Destroy()
				if onDone then
					onDone()
				end
			end)
		end)
	end
	function held.back(_self, to: Vector2, onDone: (() -> ())?)
		stop()
		Util.tween(root, 0.2, { Position = UDim2.fromOffset(to.X, to.Y), Rotation = 0 }, Enum.EasingStyle.Quad)
		Util.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad)
		task.delay(0.2, function()
			root:Destroy()
			if onDone then
				onDone()
			end
		end)
	end
	return held
end

-- A coin (or any medallion) flies across the screen; onLand() as it arrives. Doesn't yield.
function Overlays.flyIcon(layer: Frame, iconId: string, color: Color3, from: Vector2, to: Vector2, speed: number, onLand: (() -> ())?)
	local size = math.clamp(stageSize(layer).X * 0.05, 34, 44)
	local h = Util.frame(layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 90,
	})
	Icons.medallion(h, iconId, color, { Size = UDim2.fromScale(1, 1) })
	Util.popIn(h, 0.2, 0.3)
	Util.tween(h, 0.5 * speed, { Position = UDim2.fromOffset(to.X, to.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.5 * speed, function()
		h:Destroy()
		if onLand then
			onLand()
		end
	end)
end

---------------------------------------------------------------------------
-- banners
---------------------------------------------------------------------------

-- "Pip's turn" ribbon that sweeps across the top of the board.
function Overlays.turnBanner(layer: Frame, text: string, seatColor: Color3, mine: boolean, speed: number)
	local banner = Util.new("Frame", {
		Name = "TurnBanner",
		BackgroundColor3 = if mine then C.brass else C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(-0.3, 0, 0.12, 0),
		Size = UDim2.fromOffset(if mine then 380 else 320, if mine then 62 else 50),
		ZIndex = 85,
		Parent = layer,
	})
	Util.corner(banner, 14)
	Util.stroke(banner, if mine then hex("5E430F") else C.brassDark, 3)
	local k = fitScale(layer, if mine then 380 else 320, if mine then 62 else 50)
	if k < 1 then
		Util.new("UIScale", { Name = "Fit", Scale = k, Parent = banner })
	end
	-- the player's seat colour as a pawn-like dot, inset from the edge
	local dotSize = if mine then 26 else 22
	local dot = Util.new("Frame", {
		Name = "SeatDot",
		BackgroundColor3 = seatColor,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(dotSize, dotSize),
		ZIndex = 86,
		Parent = banner,
	})
	Util.corner(dot, 0.5)
	Util.stroke(dot, C.ink, 2)
	Widgets.label(banner, {
		text = text,
		font = "chunky",
		size = if mine then 32 else 26,
		color = if mine then C.textOnLight else C.text,
		align = "center",
		sizeUDim = UDim2.new(1, -(dotSize + 40), 1, -10),
		position = UDim2.new(0, dotSize + 24, 0, 5),
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
	local outer = fitted(layer, "AbilityBanner", 520, 180, 0.5, 0.42, 88)
	local wrap = Util.frame(outer, { Name = "Inner", ZIndex = 88 })
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
	outer.Position = UDim2.new(-0.4, 0, 0.42, 0)
	Util.tween(outer, 0.3 * speed, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	Util.tween(s, 0.3 * speed, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play("ability")
	task.delay(1.1 * speed, function()
		Util.tween(outer, 0.25 * speed, { Position = UDim2.new(1.4, 0, 0.42, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.27 * speed, function()
			outer:Destroy()
		end)
	end)
end

-- Big centred message ("Pip collected every treasure!", "Your turn!" etc.)
function Overlays.shout(layer: Frame, text: string, color: Color3, speed: number, sub: string?)
	local outer = fitted(layer, "Shout", 700, 110, 0.5, 0.4, 89)
	local wrap = Util.frame(outer, { Name = "Inner", ZIndex = 89 })
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
			outer:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------
-- character reveal (match intro)
---------------------------------------------------------------------------

function Overlays.reveal(layer: Frame, seats, duration: number)
	local n = #seats
	local outer = fitted(layer, "Reveal", n * 144, 260, 0.5, 0.48, 95)
	local row = Util.frame(outer, { Name = "Row", ZIndex = 95 })
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
			color = C.text,
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
	Util.tween(outer, 0.3, { Position = UDim2.fromScale(0.5, 1.4) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.32, function()
		outer:Destroy()
	end)
end

return Overlays
