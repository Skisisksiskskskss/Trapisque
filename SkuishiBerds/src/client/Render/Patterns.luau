--[[
	Patterns: the 18 original bird patterns (+ Galaxy exclusive), drawn inside
	the bird body (a CanvasGroup with UICorner clips them to the circle).

	Uses the original's seeded layout function (FNV hash of "pattern:seed"), so
	each pattern looks like the web version.

	draw(parent, pattern, color, alpha, seed)
	  parent: the body CanvasGroup; local space is -1.5..1.5 radii mapped onto it
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rng = require(Shared.Sim.Rng)
local Canvas = require(script.Parent.Canvas)

local Patterns = {}

-- original FNV-1a hash + rnd(n)
local function makeRnd(pattern: string, seed: number)
	local s = pattern .. ":" .. tostring(seed)
	local h = 2166136261
	for i = 1, #s do
		h = Rng.imul(bit32.bxor(h, string.byte(s, i)), 16777619)
	end
	return function(n: number): number
		local t = (h + Rng.imul(n, 2654435761)) % 4294967296
		t = bit32.bxor(t, bit32.rshift(t, 16))
		return (t % 1000) / 1000
	end
end

-- body local space: unit = bird radius, (0,0) = center; body frame spans -1..1
local SPACE = Canvas.space(0.5, 0.5, 0.5, 0.5)

local function dot(parent, x, y, r, color, alpha, z)
	return Canvas.circle(parent, SPACE, x, y, r, { color = color, alpha = alpha, z = z })
end

local function seg(parent, x1, y1, x2, y2, w, color, alpha, z)
	return Canvas.line(parent, SPACE, x1, y1, x2, y2, w, { color = color, alpha = alpha, z = z })
end

local draw = {}

function draw.spots(p, rnd, c, a, z)
	for i = 0, 14 do
		local ang = rnd(i) * math.pi * 2
		local r = 0.2 + rnd(i + 1) * 0.6
		dot(p, math.cos(ang) * r, math.sin(ang) * r, 0.1 + rnd(i + 2) * 0.15, c, a, z)
	end
end

function draw.stripes(p, _rnd, c, a, z)
	local i = -2
	while i <= 2 do
		seg(p, i, -1.5, i + 0.5, 1.5, 0.12 * 15, c, a, z)
		i += 0.25
	end
end

function draw.stars(p, rnd, c, a, z)
	for i = 0, 7 do
		local ang = (i / 8) * math.pi * 2 + rnd(i + 9)
		local r = 0.25 + rnd(i) * 0.55
		local sx, sy = math.cos(ang) * r, math.sin(ang) * r
		local sz = 0.12 + rnd(i + 3) * 0.1
		seg(p, sx - sz, sy, sx + sz, sy, 1.5, c, a, z)
		seg(p, sx, sy - sz, sx, sy + sz, 1.5, c, a, z)
	end
end

function draw.scales(p, _rnd, c, a, z)
	local s = 0.5
	local row = 0
	local y = -1.5
	while y < 1.5 do
		local off = (row % 2) * s * 0.5
		local x = -1.5
		while x < 1.5 do
			Canvas.ring(p, SPACE, x + off, y, s * 0.5, s * 0.5, 1.5, { color = c, alpha = a, z = z })
			x += s
		end
		y += s * 0.6
		row += 1
	end
end

function draw.hexagons(p, _rnd, c, a, z)
	local hexR = 0.35
	local vert = hexR * math.sqrt(3)
	for i = -2, 2 do
		for j = -2, 2 do
			local x = i * hexR * 1.5
			local y = j * vert + (i % 2) * (vert / 2)
			if x * x + y * y < 1.6 then
				Canvas.ring(p, SPACE, x, y, hexR * 0.85, hexR * 0.85, 1.5, { color = c, alpha = a, z = z })
			end
		end
	end
end

function draw.diamonds(p, _rnd, c, a, z)
	local dW, dH = 0.5, 0.7
	for i = -3, 3 do
		for j = -3, 3 do
			local x = i * dW + (j % 2) * (dW / 2)
			local y = j * dH / 2
			if x * x + y * y < 1.5 then
				Canvas.diamond(p, SPACE, x, y, dW / 2 - 0.08, { color = c, alpha = a, z = z })
			end
		end
	end
end

function draw.camo(p, rnd, c, a, z)
	for i = 0, 4 do
		local x = (rnd(i * 3) - 0.5) * 1.5
		local y = (rnd(i * 3 + 1) - 0.5) * 1.5
		Canvas.ellipse(p, SPACE, x, y, 0.3 + rnd(i) * 0.3, 0.3 + rnd(i + 1) * 0.3, {
			color = c,
			alpha = a,
			z = z,
			rot = math.deg(rnd(i * 2) * math.pi),
		})
	end
end

local function heart(p, x, y, s, c, a, z)
	-- two lobes + a diamond point
	dot(p, x - s * 0.5, y, s * 0.55, c, a, z)
	dot(p, x + s * 0.5, y, s * 0.55, c, a, z)
	Canvas.diamond(p, SPACE, x, y + s * 0.45, s * 0.75, { color = c, alpha = a, z = z })
end
Patterns.heart = heart

function draw.hearts(p, rnd, c, a, z)
	for i = 0, 5 do
		heart(p, (rnd(i + 20) - 0.5) * 1.6, (rnd(i + 21) - 0.5) * 1.6, 0.2 + rnd(i + 50) * 0.15, c, a, z)
	end
end

function draw.mosaic(p, rnd, c, a, z)
	for i = 0, 14 do
		local alphaVar = math.clamp(a * (0.5 + rnd(i + 99)), 0.1, 1)
		local x = (rnd(i + 60) - 0.5) * 2.2
		local y = (rnd(i + 61) - 0.5) * 2.2
		Canvas.rect(p, SPACE, x, y, 0.3 + rnd(i + 62) * 0.5, 0.25 + rnd(i + 63) * 0.4, {
			color = c,
			alpha = alphaVar,
			z = z,
			rot = math.deg(rnd(i + 64) * math.pi),
		})
	end
end

function draw.zigzag(p, _rnd, c, a, z)
	local y = -1.5
	while y < 1.5 do
		local x = -1.5
		local up = true
		while x < 1.5 do
			local y1 = y + (if up then 0.18 else -0.18)
			local y2 = y + (if up then -0.18 else 0.18)
			seg(p, x, y1, x + 0.34, y2, 2, c, a, z)
			x += 0.34
			up = not up
		end
		y += 0.4
	end
end

function draw.waves(p, _rnd, c, a, z)
	local y = -1.5
	while y < 1.5 do
		local x = -1.5
		while x < 1.5 do
			local wy1 = y + math.sin(x * 15 * 0.1) * 0.2
			local wy2 = y + math.sin((x + 0.3) * 15 * 0.1) * 0.2
			seg(p, x, wy1, x + 0.3, wy2, 2, c, a, z)
			x += 0.3
		end
		y += 0.3
	end
end

function draw.target(p, _rnd, c, a, z)
	local r = 0.2
	while r < 1.2 do
		Canvas.ring(p, SPACE, 0, 0, r, r, 2, { color = c, alpha = a, z = z })
		r += 0.25
	end
end

function draw.dots(p, rnd, c, a, z)
	for i = 0, 19 do
		dot(p, (rnd(i * 12) - 0.5) * 1.6, (rnd(i * 13) - 0.5) * 1.6, 0.1 + rnd(i * 14) * 0.12, c, a, z)
	end
end

function draw.checkered(p, _rnd, c, a, z)
	local s = 0.4
	local ix = 0
	local x = -1.5
	while x < 1.5 do
		local iy = 0
		local y = -1.5
		while y < 1.5 do
			if (math.floor(x / s) + math.floor(y / s)) % 2 == 0 then
				Canvas.rect(p, SPACE, x + s / 2, y + s / 2, s, s, { color = c, alpha = a, z = z })
			end
			y += s
			iy += 1
		end
		x += s
		ix += 1
	end
end

function draw.confetti(p, rnd, c, a, z)
	for i = 0, 19 do
		local alphaVar = math.clamp(a * (0.7 + rnd(i) * 0.6), 0.1, 1)
		Canvas.rect(
			p,
			SPACE,
			(rnd(i * 7) - 0.5) * 1.6,
			(rnd(i * 8) - 0.5) * 1.6,
			(4 + rnd(i) * 5) / 15,
			(4 + rnd(i + 1) * 5) / 15,
			{
				color = c,
				alpha = alphaVar,
				z = z,
				rot = math.deg(rnd(i * 9) * math.pi),
			}
		)
	end
end

function draw.swirls(p, rnd, c, a, z)
	for i = 0, 5 do
		local x = (rnd(i * 10) - 0.5) * 1.2
		local y = (rnd(i * 11) - 0.5) * 1.2
		-- nested off-center rings read as a swirl at this size
		for k = 1, 3 do
			local r = 0.07 * k
			Canvas.ring(
				p,
				SPACE,
				x + r * 0.3 * (if rnd(i) > 0.5 then 1 else -1),
				y,
				r,
				r,
				1.5,
				{ color = c, alpha = a, z = z }
			)
		end
	end
end

function draw.triangles(p, rnd, c, a, z)
	local apexes = { "up", "down", "left", "right" }
	for i = 0, 11 do
		local x = (rnd(i * 5 + 10) - 0.5) * 1.6
		local y = (rnd(i * 6 + 10) - 0.5) * 1.6
		local s = 0.15 + rnd(i) * 0.2
		Canvas.tri(
			p,
			SPACE,
			x,
			y,
			s * 1.7,
			s * 1.5,
			apexes[math.floor(rnd(i * 7) * 4) + 1],
			{ color = c, alpha = a, z = z }
		)
	end
end

-- Exclusive: animated-feel galaxy (star specks over a deep gradient)
function draw.galaxy(p, rnd, _c, a, z)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#2c1a5a")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#6c2bd9")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#0b0b2b")),
	})
	g.Rotation = 35
	local back = Canvas.rect(p, SPACE, 0, 0, 3, 3, { color = Color3.new(1, 1, 1), alpha = math.max(a, 0.7), z = z })
	g.Parent = back
	for i = 0, 18 do
		dot(
			p,
			(rnd(i * 3) - 0.5) * 2,
			(rnd(i * 3 + 1) - 0.5) * 2,
			0.03 + rnd(i * 3 + 2) * 0.05,
			Color3.new(1, 1, 1),
			0.9,
			z
		)
	end
end

function Patterns.draw(parent: Instance, pattern: string?, color: Color3, alpha: number, seed: number, z: number?)
	if not pattern or pattern == "solid" then
		return
	end
	local fn = draw[pattern]
	if not fn then
		return
	end
	fn(parent, makeRnd(pattern, seed), color, alpha, z or 3)
end

return Patterns
