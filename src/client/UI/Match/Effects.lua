--[[
	Effects
	Animations that play on the board when something happens: a spike springs up, a
	Grog lunges, gold bursts out of the treasure chest... Every function is
	fire-and-forget and lasts about as long as Pacing says the event takes.
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local Effects = {}

local function px(v: Vector2): UDim2
	return UDim2.fromOffset(v.X, v.Y)
end

-- A square holder in the board's effect layer, centred at `at` (world pixels).
local function holder(view, at: Vector2, size: number, z: number?): Frame
	return Util.frame(view.layers.Fx, {
		Name = "Fx",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(at),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 50,
	})
end

local function fadeOut(frame: Instance, after: number, time: number?)
	task.delay(after, function()
		if not frame.Parent then
			return
		end
		local t = time or 0.25
		for _, d in frame:GetDescendants() do
			if d:IsA("Frame") then
				Util.tween(d, t, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Util.tween(d, t, { Transparency = 1 })
			elseif d:IsA("TextLabel") then
				Util.tween(d, t, { TextTransparency = 1 })
			end
		end
		task.delay(t + 0.02, function()
			frame:Destroy()
		end)
	end)
end

local function burst(view, at: Vector2, color: Color3, count: number, dist: number, size: number, life: number?)
	local U = view.UNIT
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.4
		local d = dist * U * (0.6 + math.random() * 0.6)
		local dot = Util.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(at),
			Size = UDim2.fromOffset(size * U, size * U),
			ZIndex = 55,
			Parent = view.layers.Fx,
		})
		Util.corner(dot, 0.5)
		local l = life or 0.55
		Util.tween(dot, l, {
			Position = px(at + Vector2.new(math.cos(a), math.sin(a)) * d),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size * U * 0.3, size * U * 0.3),
		}, Enum.EasingStyle.Quad)
		task.delay(l + 0.02, function()
			dot:Destroy()
		end)
	end
end
Effects.burst = burst

local function ring(view, at: Vector2, color: Color3, from: number, to: number, life: number, thickness: number?)
	local U = view.UNIT
	local r = Util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(at),
		Size = UDim2.fromOffset(from * U, from * U),
		ZIndex = 52,
		Parent = view.layers.Fx,
	})
	Util.corner(r, 0.5)
	local st = Util.stroke(r, color, thickness or 4)
	Util.tween(r, life, { Size = UDim2.fromOffset(to * U, to * U) }, Enum.EasingStyle.Quad)
	Util.tween(st, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(life + 0.02, function()
		r:Destroy()
	end)
end
Effects.ring = ring

-- An icon that pops up at a spot, wobbles, then fades.
local function popIcon(view, at: Vector2, iconId: string, colors, size: number, life: number)
	local U = view.UNIT
	local h = holder(view, at - Vector2.new(0, 0.5 * U), size * U, 58)
	Icons.make(h, iconId, colors)
	Util.popIn(h, 0.3, 0.2)
	Util.tween(h, life, { Position = px(at - Vector2.new(0, 1.2 * U)) }, Enum.EasingStyle.Quad)
	fadeOut(h, life * 0.7, life * 0.3)
	return h
end
Effects.popIcon = popIcon

---------------------------------------------------------------------------
-- traps and neutral cards
---------------------------------------------------------------------------

function Effects.trap(view, item: string, tile: number)
	local U = view.UNIT
	local at = view:tileWorld(tile)
	Sound.play("trap")
	if item == "spike" then
		local h = holder(view, at, 1.6 * U, 54)
		for i, x in { 0.3, 0.5, 0.7 } do
			local spike = Util.frame(h, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(x, 0.7),
				Size = UDim2.fromScale(0.22, 0),
				ZIndex = 54,
			})
			local c = Shapes.canvas(spike, { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeXY })
			Shapes.rect(c, 0.5, 0.65, 0.4, 0.7, hex("8A8F96"))
			Shapes.tri(c, 0.5, 0.3, 0.8, hex("C9CED6"))
			task.delay((i - 1) * 0.05, function()
				Util.tween(spike, 0.18, { Size = UDim2.fromScale(0.22, if i == 2 then 0.7 else 0.5) }, Enum.EasingStyle.Back)
			end)
		end
		ring(view, at, C.trap, 0.6, 2.2, 0.5, 5)
		fadeOut(h, 0.7)
	elseif item == "fire" then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			local p = at + Vector2.new(math.cos(a), math.sin(a) * 0.6) * 0.45 * U
			task.delay(i * 0.05, function()
				popIcon(view, p, "fire", Icons.flatColors(hex("FF7B2E"), hex("FFD166"), hex("FFD166")), 0.7, 0.8)
			end)
		end
		ring(view, at, hex("FF7B2E"), 0.5, 2, 0.6, 6)
	elseif item == "ice" then
		popIcon(view, at, "ice", Icons.flatColors(hex("5DADE2"), C.white), 1.3, 0.9)
		ring(view, at, hex("AEE6FF"), 0.4, 2.4, 0.6, 6)
		burst(view, at, hex("DDF6FF"), 10, 1.2, 0.16)
	elseif item == "mud" or item == "mudslide" then
		burst(view, at, hex("7A5230"), if item == "mud" then 8 else 14, if item == "mud" then 0.9 else 1.4, 0.24, 0.6)
		popIcon(view, at, item, Icons.flatColors(hex("7A5230"), C.parchment), 1.1, 0.8)
	elseif item == "wall" then
		popIcon(view, at, "wall", Icons.flatColors(hex("A0522D"), C.parchment), 1.2, 0.8)
		task.delay(0.35, function()
			burst(view, at - Vector2.new(0, 0.6 * U), hex("A0522D"), 8, 1.1, 0.18, 0.5)
		end)
	elseif item == "snare" then
		local h = holder(view, at, 1.6 * U, 54)
		local c = Shapes.canvas(h)
		Shapes.oring(c, 0.5, 0.6, 1, 0.5, 0.06, hex("C9A26B"), { px = 70 })
		Util.tween(h, 0.35, { Size = UDim2.fromOffset(0.6 * U, 0.6 * U) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		fadeOut(h, 0.6)
		popIcon(view, at, "snare", Icons.flatColors(hex("8B6B3E"), C.parchment), 1, 0.9)
	elseif item == "grog" then
		local h = holder(view, at - Vector2.new(0, 0.4 * U), 1.8 * U, 59)
		Icons.medallion(h, "grog", hex("4E9A47"), { Size = UDim2.fromScale(1, 1) })
		local s = Util.scaler(h)
		s.Scale = 0
		Util.tween(s, 0.35, { Scale = 1.15 }, Enum.EasingStyle.Back)
		task.delay(0.4, function()
			for _ = 1, 3 do
				Util.tween(s, 0.08, { Scale = 0.95 })
				task.wait(0.08)
				Util.tween(s, 0.08, { Scale = 1.15 })
				task.wait(0.08)
			end
		end)
		fadeOut(h, 1.6)
	elseif item == "teleporter" then
		for i = 1, 3 do
			task.delay(i * 0.1, function()
				ring(view, at, Theme.Category.neutral, 2, 0.2, 0.45, 5)
			end)
		end
		Sound.play("magic")
	elseif item == "spore_warper" then
		burst(view, at, hex("B9A3E3"), 12, 1.3, 0.22, 0.7)
		popIcon(view, at, "spore_warper", Icons.flatColors(Theme.Category.neutral, C.white), 1, 0.8)
	elseif item == "conveyor" then
		popIcon(view, at, "conveyor", Icons.flatColors(Theme.Category.neutral, C.white), 1, 0.7)
	elseif item == "shifting_sands" then
		for i = 1, 3 do
			task.delay(i * 0.08, function()
				burst(view, at, hex("E2C27A"), 10, 1 + i * 0.2, 0.12, 0.6)
			end)
		end
		popIcon(view, at, "shifting_sands", Icons.flatColors(hex("B8862E"), C.parchment), 1, 0.8)
	end
end

function Effects.blocked(view, tile: number)
	local at = view:tileWorld(tile)
	popIcon(view, at, "wall", Icons.flatColors(hex("A0522D"), C.parchment), 1.1, 0.8)
	view:floatText(at, "BLOCKED!", hex("FFD166"))
	Sound.play("trap", 0.8)
end

function Effects.natural(view, kind: string, tile: number)
	local at = view:tileWorld(tile)
	if kind == "river" then
		Sound.play("splash")
		for i = 1, 3 do
			task.delay(i * 0.12, function()
				ring(view, at, hex("D6F0FF"), 0.4, 1.8, 0.55, 4)
			end)
		end
		burst(view, at - Vector2.new(0, 0.3 * view.UNIT), hex("8DBFE0"), 10, 1, 0.16, 0.6)
		view:floatText(at, "SPLASH!", hex("8DBFE0"))
	elseif kind == "gate" then
		Sound.play("trap", 0.7)
		popIcon(view, at, "gate_trap", Icons.flatColors(hex("3A3F45"), C.parchment), 1.2, 1)
		view:floatText(at, "LOCKED IN!", hex("C9CED6"))
	elseif kind == "slime" then
		burst(view, at, C.slime, 12, 1, 0.2, 0.6)
		view:floatText(at, "SLIMED!", C.slime)
	end
end

---------------------------------------------------------------------------
-- player fortunes
---------------------------------------------------------------------------

function Effects.death(view, seat: number)
	local pawn = view.pawns[seat]
	if not pawn then
		return
	end
	local at = view:pawnWorld(seat)
	Sound.play("death")
	burst(view, at, Theme.Seat[((seat - 1) % 6) + 1], 10, 1.2, 0.2, 0.6)
	burst(view, at, C.white, 6, 0.8, 0.12, 0.5)
	popIcon(view, at, "skull", Icons.flatColors(C.white, C.ink), 1, 1.1)
	Util.shake(pawn.lift, 6, 0.3)
end

function Effects.phoenix(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("magic", 0.8)
	ring(view, at, hex("FFB13B"), 0.5, 2.6, 0.7, 8)
	burst(view, at, hex("FF7B2E"), 14, 1.6, 0.18, 0.7)
	view:floatText(at, "PHOENIX!", hex("FFB13B"))
end

function Effects.shield(view, seat: number)
	local U = view.UNIT
	local at = view:pawnWorld(seat)
	Sound.play("magic", 1.2)
	local bubble = holder(view, at, 1.4 * U, 60)
	local c = Shapes.canvas(bubble)
	Shapes.circle(c, 0.5, 0.5, 1, hex("8FD3FF"), { t = 0.7 })
	Shapes.ring(c, 0.5, 0.5, 1, 0.06, hex("D6F0FF"), { px = 64 })
	Util.popIn(bubble, 0.3, 0.3)
	fadeOut(bubble, 0.7)
	view:floatText(at, "BLOCKED!", hex("8FD3FF"))
end

function Effects.treasure(view, tile: number, seat: number)
	local U = view.UNIT
	local at = view:tileWorld(tile)
	Sound.play("treasure")
	local chest = holder(view, at - Vector2.new(0, 0.3 * U), 1.4 * U, 60)
	Icons.medallion(chest, "chest", C.brass, { Size = UDim2.fromScale(1, 1) })
	Util.popIn(chest, 0.4, 0.2)
	for i = 1, 3 do
		task.delay(0.15 * i, function()
			burst(view, at, C.gold, 10, 1.8, 0.2, 0.8)
		end)
	end
	ring(view, at, C.brassLight, 0.6, 3, 0.8, 8)
	fadeOut(chest, 1.4)
	view:floatText(at - Vector2.new(0, 0.6 * U), "+1 TREASURE", C.gold)
	local _ = seat
end

function Effects.status(view, seat: number, status: string)
	local at = view:pawnWorld(seat)
	if status == "burning" then
		popIcon(view, at, "fire", Icons.flatColors(hex("FF7B2E"), hex("FFD166"), hex("FFD166")), 1, 0.9)
		view:floatText(at, "BURNING", hex("FF7B2E"))
	elseif status == "frozen" then
		popIcon(view, at, "ice", Icons.flatColors(hex("5DADE2"), C.white), 1, 0.9)
		view:floatText(at, "FROZEN", hex("8FD3FF"))
	end
end

function Effects.ability(view, ability: string, seat: number, target: number?)
	local color = ({
		hex = hex("5876D6"),
		scavenge = hex("A86B39"),
		ignite = hex("E2622B"),
		warp = hex("8B57CC"),
		nudge = hex("CDA42A"),
	})[ability] or C.brass
	local from = view:pawnWorld(seat)
	ring(view, from, color, 0.5, 2.8, 0.7, 7)
	burst(view, from, color, 12, 1.4, 0.16, 0.6)
	if target and target ~= seat then
		local to = view:pawnWorld(target)
		-- a bolt of colour travels from caster to target
		local orb = holder(view, from, 0.5 * view.UNIT, 62)
		local c = Shapes.canvas(orb)
		Shapes.circle(c, 0.5, 0.5, 1, color)
		Shapes.circle(c, 0.5, 0.5, 0.5, C.white)
		Util.tween(orb, 0.35, { Position = px(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.36, function()
			orb:Destroy()
			ring(view, to, color, 0.4, 2, 0.5, 6)
			burst(view, to, color, 10, 1.1, 0.14, 0.5)
		end)
	end
	Sound.play("magic")
end

function Effects.grogRoll(view, tile: number, roll: number, survived: boolean)
	local at = view:tileWorld(tile)
	view:floatText(at - Vector2.new(0, 0.4 * view.UNIT), "ROLLED " .. roll .. (if survived then " - ESCAPED!" else " - CHOMP!"), if survived then C.good else C.bad)
end

function Effects.recall(view, seat: number)
	local at = view:pawnWorld(seat)
	ring(view, at, hex("B98CFF"), 2.4, 0.2, 0.5, 6)
	popIcon(view, at, "hourglass", Icons.flatColors(hex("B98CFF"), C.white), 0.9, 0.7)
end

return Effects
