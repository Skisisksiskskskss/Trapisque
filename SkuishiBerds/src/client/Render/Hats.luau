--[[
	Hats: every hat from the original drawHat(), transcribed into shape specs
	(coordinates in bird radii, y up = negative, exactly as in the web version),
	plus two Robux exclusives.

	Each hat is a function(b) using the builder from BirdView:
	  b.ell(x, y, rx, ry, color, opts)    opts: stroke, sw, rot (deg), half ("top"|"bottom"), alpha
	  b.circ(x, y, r, color, opts)
	  b.rect(cx, cy, w, h, color, opts)   opts.round
	  b.tri(cx, cy, w, h, apex, color, opts)   apex "up"|"down"|"left"|"right"
	  b.rtri(x, y, w, h, corner, color, opts)  top-left corner at (x, y)
	  b.line(x1, y1, x2, y2, thick, color)
	  b.ring(x, y, rx, ry, thick, color, opts) opts.half
	  b.anim(function(t, dt) ... end)     per-frame animation (only while visible)
	Builders return the created GuiObject so animations can move it.
]]

local Hats = {}

local function c(h: string): Color3
	return Color3.fromHex(h)
end

local INK = c("#222222")
local WHITE = c("#ffffff")
local DEG = 180 / math.pi

Hats.none = function(_b) end

Hats.propeller = function(b)
	b.ell(0, -1.2, 1.1, 0.4, c("#99d9ea"), { stroke = INK, half = "top" })
	b.rect(0, -1.5, 0.14, 0.6, INK)
	local blade = b.ell(0, -1.8, 0.65, 0.08, c("#ffcc66"), { stroke = INK, sw = 1 })
	b.anim(function(t)
		blade.Rotation = (t * 600) % 360
	end)
end

Hats.crown = function(b)
	local gold = c("#ffd700")
	b.rect(0, -0.95, 2, 0.3, gold, { stroke = INK })
	b.tri(-0.5, -1.3, 1, 0.42, "up", gold)
	b.tri(0.5, -1.3, 1, 0.42, "up", gold)
	b.circ(-0.5, -1.4, 0.15, c("#ff007f"))
	b.circ(0.5, -1.4, 0.15, c("#ff007f"))
end

Hats.beanie = function(b)
	b.ell(0, -0.8, 1.1, 0.78, c("#f39c12"), { stroke = INK, sw = 2, half = "top" })
	b.circ(0, -1.8, 0.3, WHITE, { stroke = INK })
end

Hats.fez = function(b)
	local red = c("#e74c3c")
	b.ell(0, -0.8, 1.1, 0.3, red, { stroke = INK, sw = 2 })
	b.tri(-0.45, -1.3, 0.75, 0.62, "up", red)
	b.tri(0.45, -1.3, 0.75, 0.62, "up", red)
	b.rect(0, -1.0, 1.5, 0.2, red)
	b.line(0.5, -1.6, 0.8, -1.8, 1.5, INK)
end

Hats.wizard = function(b)
	local purple = c("#5d3f6a")
	b.ell(0, -0.8, 1.2, 0.4, purple, { stroke = INK, sw = 2 })
	b.tri(0, -1.7, 1.6, 1.6, "up", purple)
	b.circ(-0.3, -1.5, 0.2, c("#ffd700"))
end

Hats.tophat = function(b)
	local black = c("#1a1a1a")
	b.ell(0, -0.9, 1.3, 0.3, black, { stroke = INK, sw = 2 })
	b.rect(0, -1.55, 1.6, 1.3, black, { stroke = INK, sw = 2 })
	b.ell(0, -2.2, 0.8, 0.2, black, { stroke = INK, sw = 2 })
	b.rect(0, -1.05, 1.6, 0.2, c("#c0392b"))
end

Hats.pirate = function(b)
	local navy = c("#2c3e50")
	b.rect(0, -1.3, 0.62, 1.0, navy)
	b.rtri(-1.2, -1.8, 0.92, 1.0, "BR", navy)
	b.rtri(0.28, -1.8, 0.92, 1.0, "BL", navy)
	b.circ(0, -1.2, 0.25, WHITE, { stroke = INK })
	b.line(-0.15, -0.95, 0.15, -0.9, 1.2, WHITE)
end

Hats.cowboy = function(b)
	local brown = c("#8b4513")
	b.ell(0, -0.9, 1.4, 0.4, brown, { stroke = INK, sw = 2 })
	b.ell(0, -0.9, 0.7, 0.75, brown, { stroke = INK, sw = 2, half = "top" })
	b.rect(0, -1.05, 1.35, 0.16, c("#5a2d0c"))
end

Hats.bunny = function(b)
	b.ell(-0.5, -1.8, 0.3, 0.8, c("#ffb3d9"), { stroke = INK, sw = 2, rot = -0.3 * DEG })
	b.ell(0.5, -1.8, 0.3, 0.8, c("#ffb3d9"), { stroke = INK, sw = 2, rot = 0.3 * DEG })
	b.ell(-0.5, -1.7, 0.15, 0.5, c("#ff80bf"), { rot = -0.3 * DEG })
	b.ell(0.5, -1.7, 0.15, 0.5, c("#ff80bf"), { rot = 0.3 * DEG })
end

Hats.antlers = function(b)
	local brown = c("#8b4513")
	for _, s in { -1, 1 } do
		b.line(0.4 * s, -1.0, 0.6 * s, -1.8, 3, brown)
		b.line(0.55 * s, -1.5, 0.8 * s, -1.6, 3, brown)
		b.line(0.55 * s, -1.3, 0.9 * s, -1.3, 3, brown)
	end
end

Hats.halo = function(b)
	local gold = c("#ffd700")
	b.ring(0, -1.8, 0.86, 0.2, 6, gold, { alpha = 0.25 })
	local ring = b.ring(0, -1.8, 0.8, 0.15, 4, gold)
	b.anim(function(t)
		ring.Position = b.at(0, -1.8 + math.sin(t * 3) * 0.06)
	end)
end

Hats.santa = function(b)
	local red = c("#e74c3c")
	b.rtri(-0.9, -1.85, 0.6, 1.05, "BR", red)
	b.rtri(-0.3, -1.85, 1.2, 1.05, "BL", red)
	b.ell(0, -0.8, 1.0, 0.3, WHITE, { stroke = INK })
	b.circ(0.3, -2.0, 0.3, WHITE, { stroke = INK })
end

Hats.visor = function(b)
	local blue = c("#3498db")
	b.ell(0, -1.0, 1.1, 0.3, blue, { stroke = INK, sw = 2 })
	b.ell(0.62, -1.0, 0.55, 0.28, blue, { stroke = INK, sw = 2, rot = -22 })
end

Hats.paperboat = function(b)
	local paper = c("#fff5e1")
	b.tri(0, -0.9, 1.8, 0.8, "up", paper)
	b.tri(0, -0.35, 1.8, 0.3, "down", paper)
	b.line(-0.9, -0.5, 0.9, -0.5, 1.5, INK)
	b.line(0, -1.3, 0, -0.2, 1, c("#cccccc"))
end

Hats.flower = function(b)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local hue = (i * 40) / 360
		b.ell(math.cos(a) * 0.35, -1.25 + math.sin(a) * 0.13, 0.25, 0.12, Color3.fromHSV(hue, 0.55, 0.95), { rot = a * DEG })
	end
	b.circ(0, -1.05, 0.18, c("#ffd700"), { stroke = INK })
	b.line(0, -1.0, 0, -0.85, 1.5, c("#27ae60"))
end

Hats.chef = function(b)
	b.ell(-0.45, -1.45, 0.55, 0.55, WHITE, { stroke = INK })
	b.ell(0.45, -1.45, 0.55, 0.55, WHITE, { stroke = INK })
	b.ell(0, -1.65, 0.65, 0.6, WHITE, { stroke = INK })
	b.rect(0, -0.95, 1.1, 0.5, WHITE, { stroke = INK })
end

Hats.space = function(b)
	b.ell(0, -0.25, 1.05, 0.9, c("#a0c8ff"), { alpha = 0.18 })
	b.ring(0, -0.1, 1.05, 1.05, 2, INK, { half = "top" })
	b.ell(0.4, -0.55, 0.2, 0.1, WHITE, { alpha = 0.7, rot = -30 })
end

Hats.samurai = function(b)
	b.ell(0, -1.2, 1.1, 0.45, c("#4b2e2e"), { stroke = INK })
	b.rect(0, -1.4, 0.3, 0.4, c("#ffd700"))
	b.tri(-0.35, -1.75, 0.3, 0.4, "up", c("#ffd700"))
	b.tri(0.35, -1.75, 0.3, 0.4, "up", c("#ffd700"))
end

Hats.beret = function(b)
	b.ell(0, -1.1, 1.1, 0.5, c("#b03060"), { stroke = INK, rot = -0.4 * DEG })
	b.rect(0, -1.6, 0.1, 0.2, INK)
end

Hats.viking = function(b)
	b.ell(-0.9, -1.15, 0.22, 0.45, WHITE, { stroke = INK, rot = -0.6 * DEG })
	b.ell(0.9, -1.15, 0.22, 0.45, WHITE, { stroke = INK, rot = 0.6 * DEG })
	b.ell(0, -1.0, 1.1, 0.5, c("#654321"), { stroke = INK, half = "top" })
	b.rect(0, -1.0, 2.0, 0.18, c("#bdc3c7"))
end

Hats.bearears = function(b)
	local tan = c("#dcae9c")
	b.circ(-0.6, -1.3, 0.25, tan, { stroke = INK })
	b.circ(0.6, -1.3, 0.25, tan, { stroke = INK })
	b.circ(-0.6, -1.3, 0.12, c("#c48b77"))
	b.circ(0.6, -1.3, 0.12, c("#c48b77"))
end

Hats.headphones = function(b)
	b.ring(0, -0.6, 1.05, 1.05, 3, INK, { half = "top" })
	b.circ(-0.95, -0.55, 0.28, c("#333333"))
	b.circ(0.95, -0.55, 0.28, c("#333333"))
	b.circ(-0.95, -0.55, 0.12, c("#ff6b9d"))
	b.circ(0.95, -0.55, 0.12, c("#ff6b9d"))
end

Hats.bucket = function(b)
	b.ell(0, -1.0, 1.05, 0.6, c("#e0cda9"), { stroke = INK })
	b.rect(0, -0.58, 0.9, 0.25, c("#d4b483"), { stroke = INK })
end

Hats.crest = function(b)
	b.tri(0, -1.25, 1.6, 0.7, "up", c("#c0392b"))
	b.circ(0, -1.2, 0.15, c("#ffd700"))
end

Hats.bandana = function(b)
	b.rect(0, -0.95, 2.1, 0.26, c("#ff4d6d"), { stroke = INK, sw = 1.2, round = 3 })
	b.ell(0.85, -0.9, 0.12, 0.06, WHITE)
	b.ell(-0.4, -0.97, 0.08, 0.05, WHITE)
	b.tri(1.05, -0.85, 0.3, 0.35, "right", c("#ff4d6d"))
end

Hats.scuba = function(b)
	b.ell(0, -0.4, 1.05, 0.9, c("#a0c8ff"), { alpha = 0.18 })
	b.ring(0, -0.4, 1.05, 0.9, 1.5, c("#0b3a57"), { half = "top" })
	b.rect(0, -0.45, 1.8, 0.2, c("#0b3a57"), { round = 4 })
end

Hats.goggles = function(b)
	b.rect(0, -0.89, 2.1, 0.12, c("#111111"))
	b.ell(-0.45, -0.9, 0.36, 0.28, c("#2b3b4f"), { stroke = c("#111111"), sw = 1.2 })
	b.ell(0.45, -0.9, 0.36, 0.28, c("#2b3b4f"), { stroke = c("#111111"), sw = 1.2 })
	b.ell(-0.55, -0.95, 0.18, 0.12, WHITE, { alpha = 0.14, rot = -11 })
	b.ell(0.35, -0.95, 0.18, 0.12, WHITE, { alpha = 0.14, rot = 11 })
end

Hats.saturn = function(b)
	b.circ(0, -1.4, 0.5, c("#f1c40f"))
	b.ring(0, -1.4, 0.9, 0.2, 3, c("#e67e22"), { rot = -0.3 * DEG })
end

Hats.fedora = function(b)
	local navy = c("#2c3e50")
	b.ell(0, -0.9, 1.3, 0.35, navy, { stroke = INK })
	b.rect(0, -1.3, 1.5, 0.8, navy, { stroke = INK, round = 4 })
	b.rect(0, -1.075, 1.5, 0.25, WHITE)
end

Hats.lantern = function(b)
	b.line(0, -0.5, 0, -2.5, 2, c("#c0392b"))
	b.ell(0, -1.5, 0.6, 0.7, c("#e74c3c"))
	local glow = b.ell(0, -1.5, 0.3, 0.4, c("#ffff00"), { alpha = 0.4 })
	b.rect(0, -2.15, 0.5, 0.12, c("#2b2b2b"))
	b.rect(0, -0.85, 0.5, 0.12, c("#2b2b2b"))
	b.anim(function(t)
		glow.BackgroundTransparency = 0.45 + math.sin(t * 6) * 0.15
	end)
end

Hats.paperplane = function(b)
	b.tri(0.2, -1.12, 1.6, 0.55, "right", WHITE, { stroke = c("#cccccc") })
	b.line(-0.6, -1.12, 1.0, -1.12, 1, c("#cccccc"))
	b.tri(-0.25, -0.92, 0.7, 0.25, "right", c("#eeeeee"))
end

Hats.mechanic = function(b)
	b.ell(0, -0.9, 0.9, 0.9, c("#34495e"), { stroke = INK, half = "top" })
	b.rect(0.35, -0.8, 1.6, 0.2, c("#2c3e50"))
end

Hats.bamboo = function(b)
	b.tri(0, -1.3, 2.8, 1.0, "up", c("#f1c40f"))
	b.line(-1.4, -0.8, 1.4, -0.8, 1.5, c("#d35400"))
	b.line(-0.7, -1.3, 0.7, -1.3, 1.5, c("#d35400"))
end

Hats.neonvisor = function(b)
	b.rect(0, -1.1, 1.8, 0.6, c("#111111"), { round = 3 })
	b.rect(0, -1.1, 1.75, 0.34, c("#00ffff"), { alpha = 0.25, round = 3 })
	local strip = b.rect(0, -1.1, 1.6, 0.2, c("#00ffff"))
	b.anim(function(t)
		strip.BackgroundTransparency = 0.1 + (math.sin(t * 8) + 1) * 0.12
	end)
end

Hats.flowercrown = function(b)
	local colors = { "#ff9ff3", "#feca57", "#ff6b6b", "#48dbfb", "#1dd1a1" }
	for i = 0, 4 do
		local ang = (i / 4) * math.pi + math.pi
		local fx, fy = math.cos(ang) * 1.1, math.sin(ang) * 1.1 - 0.2
		b.circ(fx, fy, 0.25, c(colors[i + 1]))
		b.circ(fx, fy, 0.08, WHITE)
	end
end

Hats.devil = function(b)
	local red = c("#e74c3c")
	b.tri(-0.4, -1.32, 0.42, 1.0, "up", red)
	b.tri(0.4, -1.32, 0.42, 1.0, "up", red)
end

Hats.astro = function(b)
	b.circ(0, 0, 1.3, c("#ecf0f1"), { alpha = 0.4, stroke = c("#bdc3c7"), sw = 3 })
	b.ell(0, -0.1, 1.0, 0.8, c("#3498db"), { alpha = 0.6 })
	b.ell(0.4, -0.4, 0.2, 0.1, WHITE, { alpha = 0.7, rot = -0.5 * DEG })
	b.line(0, -1.3, 0, -1.8, 2, c("#7f8c8d"))
	local light = b.circ(0, -1.8, 0.2, c("#e74c3c"))
	b.anim(function(t)
		light.BackgroundColor3 = if math.sin(t * 10) > 0 then c("#e74c3c") else c("#7f8c8d")
	end)
end

Hats.fishbowl = function(b)
	b.circ(0, 0, 1.35, c("#aed8e6"), { alpha = 0.2, stroke = c("#aed8e6"), sw = 2 })
	b.ell(0, 0.55, 1.18, 0.75, c("#0096ff"), { alpha = 0.3, half = "bottom" })
	local fish = b.ell(0.5, 0.4, 0.4, 0.2, c("#ff9f43"))
	b.anim(function(t)
		local ft = t * 2
		fish.Position = b.at(math.cos(ft) * 0.8, math.sin(ft) * 0.2 + 0.45)
	end)
end

Hats.tv = function(b)
	b.line(-0.5, -1.2, -1.2, -1.8, 2, c("#7f8c8d"))
	b.line(0.5, -1.2, 1.2, -1.8, 2, c("#7f8c8d"))
	b.rect(0, -0.1, 2.8, 2.2, c("#95a5a6"), { stroke = c("#7f8c8d"), sw = 2, round = 4 })
	b.rect(0, -0.1, 2.2, 1.6, c("#2c3e50"))
	local specks = {}
	for i = 1, 10 do
		specks[i] = b.rect(0, 0, 0.14, 0.14, WHITE)
	end
	local rng = Random.new()
	b.anim(function()
		for _, s in specks do
			s.Position = b.at(rng:NextNumber(-1.05, 1.05), rng:NextNumber(-0.85, 0.65))
			s.BackgroundColor3 = if rng:NextNumber() > 0.5 then WHITE else c("#555555")
		end
	end)
end

Hats.cone = function(b)
	local orange = c("#e67e22")
	b.tri(0, -1.5, 1.4, 1.4, "up", orange)
	b.rect(0, -1.55, 0.78, 0.28, c("#ecf0f1"))
	b.ell(0, -0.8, 0.8, 0.15, orange)
end

Hats.sprout = function(b)
	local stem = b.line(0, -0.8, -0.1, -1.8, 2, c("#27ae60"))
	local l1 = b.ell(-0.4, -1.8, 0.35, 0.15, c("#2ecc71"), { rot = -0.5 * DEG })
	local l2 = b.ell(0.2, -1.9, 0.25, 0.12, c("#2ecc71"), { rot = 0.2 * DEG })
	b.anim(function(t)
		local sway = math.sin(t * 4) * 0.15
		l1.Position = b.at(-0.4 + sway * 1.8, -1.8)
		l2.Position = b.at(0.2 + sway * 1.9, -1.9)
		stem.Rotation = b.lineAngle(0, -0.8, -0.1 + sway * 1.0, -1.8)
	end)
end

Hats.plunger = function(b)
	b.rect(0, -1.8, 0.2, 1.2, c("#d35400"))
	b.ell(0, -0.8, 0.62, 0.6, c("#c0392b"), { half = "top" })
end

Hats.brainjar = function(b)
	b.ell(0, -0.4, 1.0, 1.1, c("#2ecc71"), { alpha = 0.3, stroke = c("#27ae60"), sw = 2 })
	local brain = b.ell(0, -0.4, 0.6, 0.4, c("#ff9ff3"), { stroke = c("#e056fd"), sw = 1.5 })
	b.anim(function(t)
		brain.Position = b.at(0, -0.4 + math.sin(t * 3.3) * 0.2)
	end)
end

-- Exclusives ----------------------------------------------------------------------

Hats.goldcrown = function(b)
	local gold = c("#ffcc00")
	b.rect(0, -1.0, 2.1, 0.35, gold, { stroke = c("#8a6d00") })
	b.tri(-0.7, -1.4, 0.7, 0.5, "up", gold)
	b.tri(0, -1.5, 0.8, 0.7, "up", gold)
	b.tri(0.7, -1.4, 0.7, 0.5, "up", gold)
	b.circ(0, -1.0, 0.16, c("#3498db"))
	b.circ(-0.65, -1.0, 0.12, c("#e74c3c"))
	b.circ(0.65, -1.0, 0.12, c("#2ecc71"))
	local shine = b.rect(-0.8, -1.0, 0.12, 0.3, WHITE, { alpha = 0.6 })
	b.anim(function(t)
		shine.Position = b.at(-0.9 + ((t * 0.8) % 1) * 1.8, -1.0)
	end)
end

Hats.dragon = function(b)
	local horn = c("#7a1f1f")
	b.tri(-0.55, -1.45, 0.45, 1.1, "up", horn)
	b.tri(0.55, -1.45, 0.45, 1.1, "up", horn)
	b.tri(-0.2, -1.05, 0.25, 0.35, "up", c("#c0392b"))
	b.tri(0.2, -1.05, 0.25, 0.35, "up", c("#c0392b"))
	b.circ(-0.55, -1.95, 0.08, c("#ffd700"))
	b.circ(0.55, -1.95, 0.08, c("#ffd700"))
end

return Hats
