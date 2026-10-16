--[[
	Effects
	Animations that play on the board when something happens: a spike springs up, a
	Grog lunges, a bonk sends someone flying with a BOING, a hidden trap goes GOTCHA,
	a Blizzard snows over everyone... Every function is fire-and-forget and lasts about
	as long as Pacing says the event takes. The pictures are the same stickers as the
	cards, so a trap going off looks like its card.
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local StickerArt = require(UI.StickerArt)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local Effects = {}

-- what each card sounds like when someone steps on it: { sound, pitch }
local TRAP_SOUND = {
	spike = { "trap", 1 },
	fire = { "fire", 1 },
	ice = { "ice", 1 },
	mudslide = { "slime", 0.65 },
	banana = { "slime", 1.3 },
	wall = { "place", 0.8 },
	snare = { "trap", 1.15 },
	grog = { "trap", 0.7 },
	teleporter = { "teleport", 1 },
	spore_warper = { "teleport", 0.8 },
	conveyor = { "whoosh", 0.9 },
	trampoline = { "whoosh", 1.3 },
}

-- each ability's colour
local ABILITY_COLOR = {
	blizzard = C.sky,
	scavenge = C.orange,
	blast = C.coral,
	overgrow = C.lime,
	warp = C.grape,
	nudge = C.sun,
}
Effects.abilityColor = ABILITY_COLOR

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
		local s = Util.scaler(frame :: GuiObject)
		Util.tween(s, t, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
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
		Util.stroke(dot, C.line, math.max(1, size * U * 0.12))
		local l = life or 0.55
		Util.tween(dot, l, {
			Position = px(at + Vector2.new(math.cos(a), math.sin(a)) * d),
			Size = UDim2.fromOffset(size * U * 0.2, size * U * 0.2),
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

-- A sticker (a card's art, or one of the extras) pops up at a spot, rises, then shrinks away.
local function popSticker(view, at: Vector2, id: string, size: number, life: number): Frame?
	local art = Icons.stickerFor(id)
	if not art then
		return nil
	end
	local U = view.UNIT
	local h = holder(view, at - Vector2.new(0, 0.4 * U), size * U, 58)
	Icons.sticker(h, art, nil, 0.06)
	Util.popIn(h, 0.3, 0.2)
	Util.tween(h, life, { Position = px(at - Vector2.new(0, 1.1 * U)) }, Enum.EasingStyle.Quad)
	fadeOut(h, life * 0.75, life * 0.25)
	return h
end
Effects.popSticker = popSticker

--[[
	Comic lettering over the board ("BOING!", "GOTCHA!"): a candy word with the thick
	outline, tilted, that punches in and floats off. Sized for the screen, not the map.
]]
local function shoutAt(view, at: Vector2, text: string, color: Color3, size: number?)
	view:floatText(at - Vector2.new(0, 0.3 * view.UNIT), text, color, size or 30)
end
Effects.shoutAt = shoutAt

-- A spiky comic burst (a star) behind a word.
local function boom(view, at: Vector2, color: Color3, size: number)
	local U = view.UNIT
	local h = holder(view, at, size * U, 56)
	local c = Shapes.canvas(h)
	local star = Shapes.star(c, 0.5, 0.5, 1, color)
	local _ = star
	Util.popIn(h, 0.2, 0.2)
	h.Rotation = math.random(-15, 15)
	fadeOut(h, 0.45, 0.2)
end

---------------------------------------------------------------------------
-- cards on the board
---------------------------------------------------------------------------

-- A card slapped down onto a tile: a thud, a ring, a jolt and the card's own sound.
function Effects.place(view, item: string, tile: number, color: Color3?)
	local U = view.UNIT
	local at = view:tileWorld(tile)
	Sound.play("place", 0.92 + math.random() * 0.08)
	local sound = TRAP_SOUND[item]
	if sound and sound[1] ~= "place" then
		task.delay(0.07, function()
			Sound.play(sound[1], sound[2])
		end)
	end
	view:shake(0.07, 0.2)
	ring(view, at, color or C.sun, 0.7, 2.4, 0.45, 5)
	burst(view, at + Vector2.new(0, 0.25 * U), C.cream, 8, 1.05, 0.14, 0.42)
end

-- Someone hid a trap: a puff of smoke beside them and a "shh". Where it went is a secret.
function Effects.hide(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("whoosh", 1.25)
	for i = 1, 3 do
		task.delay(i * 0.06, function()
			burst(view, at, hex("B8BDC7"), 7, 0.9 + i * 0.2, 0.26, 0.5)
		end)
	end
	shoutAt(view, at, "SHH...", C.textSoft, 24)
end

function Effects.trap(view, item: string, tile: number)
	local U = view.UNIT
	local at = view:tileWorld(tile)
	local sound = TRAP_SOUND[item]
	if sound then
		Sound.play(sound[1], sound[2])
	end
	-- the trap's own sticker springs out of the tile
	popSticker(view, at, item, 1.5, 0.9)
	view:shake(0.06, 0.18)
	if item == "spike" then
		ring(view, at, C.coral, 0.6, 2.2, 0.5, 5)
		burst(view, at, C.steel, 8, 1.1, 0.14)
	elseif item == "fire" then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			local p = at + Vector2.new(math.cos(a), math.sin(a) * 0.6) * 0.5 * U
			task.delay(i * 0.05, function()
				popSticker(view, p, "flame", 0.6, 0.7)
			end)
		end
		ring(view, at, C.orange, 0.5, 2, 0.6, 6)
	elseif item == "ice" then
		ring(view, at, hex("AEE6FF"), 0.4, 2.4, 0.6, 6)
		burst(view, at, hex("DDF6FF"), 10, 1.2, 0.16)
	elseif item == "mudslide" then
		burst(view, at, hex("B07A45"), 14, 1.4, 0.24, 0.6)
	elseif item == "banana" then
		burst(view, at, C.sun, 8, 1, 0.18, 0.5)
	elseif item == "wall" then
		task.delay(0.35, function()
			burst(view, at - Vector2.new(0, 0.6 * U), C.woodLight, 8, 1.1, 0.18, 0.5)
		end)
	elseif item == "snare" then
		ring(view, at, C.textSoft, 2, 0.4, 0.4, 6)
	elseif item == "grog" then
		ring(view, at, C.lime, 0.5, 2.4, 0.6, 7)
	elseif item == "teleporter" then
		for i = 1, 3 do
			task.delay(i * 0.1, function()
				ring(view, at, C.grape, 2, 0.2, 0.45, 5)
			end)
		end
	elseif item == "spore_warper" then
		burst(view, at, hex("8FB3E8"), 12, 1.3, 0.2, 0.7)
	elseif item == "trampoline" then
		ring(view, at, C.pink, 0.5, 2.2, 0.5, 6)
	end
end

function Effects.blocked(view, tile: number)
	local at = view:tileWorld(tile)
	popSticker(view, at, "wall", 1.2, 0.8)
	shoutAt(view, at, "BLOCKED!", C.sun)
	Sound.play("place", 0.7)
end

-- A hazard stops you (or slime drags you back `drag` steps).
function Effects.natural(view, kind: string, tile: number, drag: number?)
	local at = view:tileWorld(tile)
	if kind == "river" then
		Sound.play("splash")
		for i = 1, 3 do
			task.delay(i * 0.12, function()
				ring(view, at, hex("D6F0FF"), 0.4, 1.8, 0.55, 4)
			end)
		end
		burst(view, at - Vector2.new(0, 0.3 * view.UNIT), C.sky, 10, 1, 0.16, 0.6)
		shoutAt(view, at, "SPLASH!", C.sky)
	elseif kind == "gate" then
		Sound.play("trap", 0.7)
		shoutAt(view, at, "LOCKED!", C.steel)
	elseif kind == "slime" then
		Sound.play("slime")
		burst(view, at, C.slime, 12, 1, 0.2, 0.6)
		shoutAt(view, at, if drag then ("SLIMED -" .. drag) else "SLIMED!", C.slime)
	end
end

---------------------------------------------------------------------------
-- player fortunes
---------------------------------------------------------------------------

-- BOING: the mover lands on a rival, who goes flying back.
function Effects.bonk(view, attacker: number, victim: number)
	local at = view:pawnWorld(victim)
	Sound.play("death", 1.35)
	boom(view, at, C.sun, 2)
	shoutAt(view, at, "BOING!", C.sun, 36)
	burst(view, at, C.white, 8, 1.2, 0.14, 0.45)
	view:shake(0.12, 0.25)
	view:setMood(victim, "dizzy", 1.8)
	view:setMood(attacker, "cheeky", 1.4)
end

-- GOTCHA: someone stepped on a hidden trap. Its owner gets a coin and Power.
function Effects.gotcha(view, owner: number, victim: number)
	local at = view:pawnWorld(victim)
	Sound.play("reveal", 0.9)
	boom(view, at, C.coral, 2.2)
	shoutAt(view, at, "GOTCHA!", C.coral, 34)
	view:setMood(victim, "shock", 1.6)
	view:setMood(owner, "smug", 1.8)
	-- a bolt of Power flies to the trap's owner
	local from = at
	local to = view:pawnWorld(owner)
	local U = view.UNIT
	local bolt = holder(view, from, 0.7 * U, 62)
	Icons.sticker(bolt, StickerArt.misc.bolt, nil, 0.08)
	Util.tween(bolt, 0.5, { Position = px(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	task.delay(0.52, function()
		bolt:Destroy()
		ring(view, to, C.sun, 0.4, 1.8, 0.4, 5)
	end)
end

function Effects.death(view, seat: number)
	local pawn = view.pawns[seat]
	if not pawn then
		return
	end
	local at = view:pawnWorld(seat)
	Sound.play("death")
	burst(view, at, Theme.seatColor(seat), 10, 1.2, 0.2, 0.6)
	burst(view, at, C.white, 6, 0.8, 0.12, 0.5)
	shoutAt(view, at, "BACK TO START!", C.coral, 26)
	view:setMood(seat, "sad", 2.2)
	Util.shake(pawn.lift, 6, 0.3)
end

function Effects.phoenix(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("magic", 0.8)
	ring(view, at, C.orange, 0.5, 2.6, 0.7, 8)
	burst(view, at, C.coral, 14, 1.6, 0.18, 0.7)
	shoutAt(view, at, "PHOENIX!", C.orange)
	view:setMood(seat, "happy", 1.6)
end

function Effects.shield(view, seat: number)
	local U = view.UNIT
	local at = view:pawnWorld(seat)
	Sound.play("magic", 1.2)
	local bubble = holder(view, at, 1.5 * U, 60)
	local disc = Util.new("Frame", {
		Name = "Bubble",
		BackgroundColor3 = hex("8FD3FF"),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = bubble,
	})
	Util.corner(disc, 0.5)
	Util.stroke(disc, C.sky, 0.08 * U)
	Util.popIn(bubble, 0.3, 0.3)
	fadeOut(bubble, 0.7)
	shoutAt(view, at, "BLOCKED!", C.sky)
	view:setMood(seat, "smug", 1.4)
end

function Effects.treasure(view, tile: number, seat: number)
	local U = view.UNIT
	local at = view:tileWorld(tile)
	Sound.play("treasure")
	popSticker(view, at, "chest", 1.6, 1.3)
	for i = 1, 3 do
		task.delay(0.15 * i, function()
			burst(view, at, C.sun, 10, 1.8, 0.2, 0.8)
		end)
	end
	ring(view, at, C.sunLight, 0.6, 3, 0.8, 8)
	shoutAt(view, at - Vector2.new(0, 0.6 * U), "+1 TREASURE", C.sun)
	view:setMood(seat, "happy", 2.4)
end

function Effects.status(view, seat: number, status: string)
	local at = view:pawnWorld(seat)
	if status == "burning" then
		Sound.play("fire", 1.1)
		popSticker(view, at, "flame", 1, 0.9)
		shoutAt(view, at, "BURNING!", C.orange)
		view:setMood(seat, "shock", 1.4)
	elseif status == "frozen" then
		Sound.play("ice")
		popSticker(view, at, "snowflake", 1, 0.9)
		shoutAt(view, at, "FROZEN!", hex("8FD3FF"))
	end
end

-- A Snare: you'll miss a turn.
function Effects.snared(view, seat: number)
	local at = view:pawnWorld(seat)
	popSticker(view, at, "zzz", 1, 1)
	shoutAt(view, at, "SNARED!", C.textSoft)
	view:setMood(seat, "dizzy", 1.6)
end

-- A banana slip made someone drop a card.
function Effects.drop(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("card", 0.8)
	shoutAt(view, at, "DROPPED A CARD!", C.sun, 22)
end

---------------------------------------------------------------------------
-- abilities
---------------------------------------------------------------------------

function Effects.ability(view, ability: string, seat: number, target: number?)
	local color = ABILITY_COLOR[ability] or C.sun
	local from = view:pawnWorld(seat)
	Sound.play("ability")
	ring(view, from, color, 0.5, 2.8, 0.7, 7)
	burst(view, from, color, 12, 1.4, 0.16, 0.6)
	view:setMood(seat, "happy", 1.4)
	if target and target ~= seat then
		local to = view:pawnWorld(target)
		-- a bolt of colour travels from caster to target
		local orb = holder(view, from, 0.55 * view.UNIT, 62)
		local disc = Util.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 62,
			Parent = orb,
		})
		Util.corner(disc, 0.5)
		Util.stroke(disc, C.line, 3)
		Util.tween(orb, 0.35, { Position = px(to) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.36, function()
			orb:Destroy()
			ring(view, to, color, 0.4, 2, 0.5, 6)
			burst(view, to, color, 10, 1.1, 0.14, 0.5)
		end)
	end
end

-- Blizzard: snow whirls over every frozen rival.
function Effects.blizzard(view, seat: number, targets: { number })
	local U = view.UNIT
	Sound.play("ice", 0.9)
	ring(view, view:pawnWorld(seat), C.sky, 0.5, 6, 0.9, 10)
	for i, t in targets do
		local at = view:pawnWorld(t)
		task.delay(0.1 * i, function()
			for k = 1, 4 do
				local p = at + Vector2.new((math.random() - 0.5) * 1.6 * U, -1.4 * U)
				local flake = holder(view, p, 0.45 * U, 60)
				Icons.sticker(flake, StickerArt.misc.snowflake, nil, 0.08)
				Util.tween(flake, 0.7, { Position = px(at + Vector2.new((math.random() - 0.5) * U, 0.2 * U)), Rotation = 180 }, Enum.EasingStyle.Quad)
				fadeOut(flake, 0.6 + k * 0.03, 0.15)
			end
			view:setMood(t, "shock", 1.2)
		end)
	end
end

-- Blast Off: the Fire Starter launches with a bang.
function Effects.blast(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("fire", 0.8)
	boom(view, at, C.orange, 2.4)
	shoutAt(view, at, "BLAST OFF!", C.coral, 30)
	burst(view, at, C.coral, 14, 1.6, 0.2, 0.6)
end

-- The tiles a Blast Off flew over catch fire.
function Effects.embers(view, tiles: { number })
	for i, tile in tiles do
		task.delay(i * 0.06, function()
			popSticker(view, view:tileWorld(tile), "flame", 0.8, 0.5)
		end)
	end
end

-- Stepping into embers sets you burning.
function Effects.scorch(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("fire", 1.2)
	shoutAt(view, at, "OUCH! HOT!", C.orange, 24)
	view:setMood(seat, "shock", 1.4)
end

-- The Trapper's Bounty Hunter hop.
function Effects.bounty(view, seat: number)
	local at = view:pawnWorld(seat)
	Sound.play("coin", 1.2)
	shoutAt(view, at, "BOUNTY!", C.sun, 24)
	burst(view, at, C.sun, 8, 1, 0.14, 0.45)
end

-- Overgrow: a hazard sprouts out of the ground.
function Effects.grow(view, tile: number)
	local at = view:tileWorld(tile)
	Sound.play("slime", 1.4)
	burst(view, at, C.lime, 12, 1.2, 0.2, 0.6)
	ring(view, at, C.lime, 0.4, 2.2, 0.5, 6)
	view:shake(0.05, 0.15)
end

-- X-Ray: a scan sweeps the board; the traps it found pop up.
function Effects.xray(view, seat: number, tiles: { number })
	Sound.play("magic", 1.1)
	ring(view, view:pawnWorld(seat), C.mint, 0.5, 8, 1, 10)
	for i, tile in tiles do
		task.delay(0.15 + i * 0.05, function()
			ring(view, view:tileWorld(tile), C.mint, 0.3, 1.6, 0.5, 5)
		end)
	end
end

function Effects.grogRoll(view, tile: number, roll: number, survived: boolean)
	local at = view:tileWorld(tile)
	shoutAt(view, at - Vector2.new(0, 0.4 * view.UNIT), "ROLLED " .. roll .. (if survived then " - ESCAPED!" else " - CHOMP!"), if survived then C.good else C.bad, 24)
end

function Effects.recall(view, seat: number)
	local at = view:pawnWorld(seat)
	ring(view, at, C.grape, 2.4, 0.2, 0.5, 6)
	popSticker(view, at, "time_potion", 0.9, 0.7)
end

return Effects
