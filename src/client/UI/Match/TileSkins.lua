--[[
	TileSkins
	What a tile turns into when something is on it. A placed trap, a neutral card or a
	natural hazard recolours the tile's top and adds a few flat details: slime goo
	bulging over the edges, flames rising off a burning tile, frost cracks on ice,
	bricks for a wall... The card's icon still sits in the middle so it reads at a glance.

		TileSkins.top(kind) -> Color3?          the tile's new top colour
		TileSkins.draw(holder, kind, ctx)       details into a square holder the size of the
		                                        tile's box (2 x 2 hex units, centred on it)
			ctx = { flat = boolean (flat-topped hexes), r = hex radius as a fraction of
			        the box, dir = degrees for a conveyor belt (0 = right) }

	Drawn with the Shapes primitives on a square canvas: (0.5, 0.5) is the tile centre.
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)

local hex = Theme.hex

local TileSkins = {}

local TOP = {
	-- traps
	spike = hex("6E747C"),
	fire = hex("4A2E22"),
	ice = hex("CFEBF6"),
	mud = hex("7A5233"),
	mudslide = hex("6A472D"),
	wall = hex("A9A196"),
	snare = hex("D6B06C"),
	grog = hex("4F6230"),
	-- neutral cards
	teleporter = hex("56368C"),
	spore_warper = hex("71824D"),
	shifting_sands = hex("E6C47C"),
	conveyor = hex("4F565E"),
	-- natural hazards
	river = hex("4E93C8"),
	gate = hex("8D8D8A"),
	slime = hex("7DBB45"),
}

function TileSkins.top(kind: string): Color3?
	return TOP[kind]
end

-- corners and edge midpoints of the hex (canvas fractions)
local function corners(flat: boolean, r: number): { { number } }
	local out = {}
	for k = 0, 5 do
		local a = math.rad((if flat then 0 else -90) + 60 * k)
		out[k + 1] = { 0.5 + r * math.cos(a), 0.5 + r * math.sin(a) }
	end
	return out
end

local function edges(flat: boolean, r: number): { { number } }
	local out = {}
	local d = r * math.cos(math.rad(30))
	for k = 0, 5 do
		local a = math.rad((if flat then 30 else -60) + 60 * k)
		out[k + 1] = { 0.5 + d * math.cos(a), 0.5 + d * math.sin(a) }
	end
	return out
end

-- y of the hex's bottom edge at horizontal offset dx from the centre
local function bottomAt(flat: boolean, r: number, dx: number): number
	if flat then
		return 0.5 + r * math.cos(math.rad(30))
	end
	return 0.5 + r - math.abs(dx) / math.sqrt(3)
end

-- an outline of the hex, inset to radius `r`
local function hexLine(c: Instance, flat: boolean, r: number, th: number, color: Color3, t: number?)
	local pts = corners(flat, r)
	for i = 1, 6 do
		local a, b = pts[i], pts[(i % 6) + 1]
		Shapes.line(c, a[1], a[2], b[1], b[2], th, color, { t = t })
	end
end

-- a soft teardrop flame pointing up
local function flame(c: Instance, cx: number, cy: number, h: number, w: number, color: Color3)
	Shapes.taper(c, { { cx, cy + h * 0.45 }, { cx + w * 0.12, cy }, { cx - w * 0.08, cy - h * 0.55 } }, w, w * 0.12, color, { steps = 4 })
end

local DRAW = {}

DRAW.slime = function(c, x)
	local goo = TOP.slime
	local dark = hex("4E8A27")
	-- blobs along every corner and edge make the rim bulge like goo
	for _, p in corners(x.flat, x.r * 0.97) do
		Shapes.circle(c, p[1], p[2], 0.12, goo)
	end
	for _, p in edges(x.flat, x.r * 0.95) do
		Shapes.circle(c, p[1], p[2], 0.15, goo)
	end
	-- drips hanging off the bottom
	for i, dx in { -0.15, 0.02, 0.17 } do
		local y0 = bottomAt(x.flat, x.r, dx)
		local len = ({ 0.07, 0.11, 0.06 })[i]
		Shapes.pill(c, 0.5 + dx, y0 + len / 2 - 0.01, 0.055, len + 0.02, goo)
		Shapes.circle(c, 0.5 + dx, y0 + len, 0.075, goo)
	end
	-- bubbles in the goo
	Shapes.ring(c, 0.33, 0.37, 0.1, 0.018, dark)
	Shapes.ring(c, 0.68, 0.64, 0.13, 0.02, dark)
	Shapes.circle(c, 0.66, 0.33, 0.05, dark)
	Shapes.circle(c, 0.34, 0.66, 0.04, dark)
end

DRAW.spike = function(c, x)
	local steel = hex("D7DCE2")
	local rivet = hex("4B5058")
	-- steel spikes poking out from under the card towards every corner
	for k = 0, 5 do
		local a = math.rad((if x.flat then 0 else -90) + 60 * k)
		local ca, sa = math.cos(a), math.sin(a)
		Shapes.taper(c, { { 0.5 + ca * 0.2, 0.5 + sa * 0.2 }, { 0.5 + ca * x.r * 0.84, 0.5 + sa * x.r * 0.84 } }, 0.08, 0.012, steel, { steps = 3 })
	end
	-- rivets between them
	for _, p in edges(x.flat, x.r * 0.6) do
		Shapes.circle(c, p[1], p[2], 0.036, rivet)
	end
end

DRAW.fire = function(c, x)
	local ember = hex("E2622B")
	local glow = hex("FFB547")
	hexLine(c, x.flat, x.r * 0.84, 0.028, ember)
	-- flames licking up from the top of the tile
	flame(c, 0.33, 0.29, 0.2, 0.11, ember)
	flame(c, 0.5, 0.22, 0.26, 0.13, ember)
	flame(c, 0.67, 0.29, 0.2, 0.11, ember)
	flame(c, 0.5, 0.25, 0.15, 0.07, glow)
	flame(c, 0.34, 0.31, 0.11, 0.055, glow)
	flame(c, 0.66, 0.31, 0.11, 0.055, glow)
	-- embers glowing in the coals
	Shapes.circle(c, 0.3, 0.66, 0.05, ember)
	Shapes.circle(c, 0.7, 0.62, 0.045, glow)
	Shapes.circle(c, 0.42, 0.76, 0.035, ember)
	Shapes.circle(c, 0.6, 0.78, 0.04, glow)
end

DRAW.ice = function(c, x)
	local frost = hex("FFFFFF")
	local deep = hex("9CCDE6")
	hexLine(c, x.flat, x.r * 0.86, 0.02, frost, 0.15)
	-- frost cracks running out from under the plaque
	for i, a in { -70, 10, 75, 150, 215 } do
		local rad = math.rad(a)
		local x1, y1 = 0.5 + math.cos(rad) * 0.17, 0.5 + math.sin(rad) * 0.17
		local x2, y2 = 0.5 + math.cos(rad) * 0.34, 0.5 + math.sin(rad) * 0.34
		Shapes.line(c, x1, y1, x2, y2, 0.022, deep)
		-- a little branch off each crack
		local b = math.rad(a + (if i % 2 == 0 then 35 else -35))
		local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
		Shapes.line(c, mx, my, mx + math.cos(b) * 0.08, my + math.sin(b) * 0.08, 0.016, deep)
	end
	-- frozen sparkle
	Shapes.sparkle(c, 0.7, 0.3, 0.1, frost)
	Shapes.sparkle(c, 0.3, 0.7, 0.07, frost)
end

DRAW.mud = function(c, x)
	local dark = hex("5C3B22")
	local wet = hex("8C6240")
	for _, s in { { 0.3, 0.34, 0.12 }, { 0.71, 0.36, 0.1 }, { 0.27, 0.66, 0.09 }, { 0.68, 0.7, 0.13 } } do
		Shapes.circle(c, s[1], s[2], s[3], dark)
	end
	Shapes.pill(c, 0.5, 0.78, 0.18, 0.05, wet)
	Shapes.pill(c, 0.5, 0.21, 0.14, 0.04, wet)
end

DRAW.mudslide = function(c, x)
	local dark = hex("4E321D")
	local wet = hex("8C6240")
	-- streaks of mud sliding down either side of the card (inside the tile's edges)
	for _, side in { -1, 1 } do
		Shapes.line(c, 0.5 + side * 0.19, 0.3, 0.5 + side * 0.25, 0.7, 0.034, dark)
		Shapes.line(c, 0.5 + side * 0.29, 0.37, 0.5 + side * 0.32, 0.63, 0.026, dark)
	end
	Shapes.pill(c, 0.5, 0.79, 0.16, 0.045, wet)
	Shapes.pill(c, 0.5, 0.21, 0.12, 0.04, wet)
end

DRAW.wall = function(c, x)
	local mortar = hex("6F685E")
	local w = if x.flat then x.r * 0.75 else x.r * 0.82
	-- three courses of bricks
	for row = -1, 1 do
		local y = 0.5 + row * 0.13
		Shapes.line(c, 0.5 - w, y - 0.065, 0.5 + w, y - 0.065, 0.018, mortar, { square = true })
		local offset = if row % 2 == 0 then 0 else 0.09
		for k = -2, 2 do
			local bx = 0.5 + k * 0.18 + offset
			if math.abs(bx - 0.5) < w - 0.03 then
				Shapes.line(c, bx, y - 0.065, bx, y + 0.065, 0.016, mortar, { square = true })
			end
		end
	end
	Shapes.line(c, 0.5 - w, 0.5 + 0.195, 0.5 + w, 0.5 + 0.195, 0.018, mortar, { square = true })
end

DRAW.snare = function(c, x)
	local rope = hex("7A5230")
	Shapes.ring(c, 0.5, 0.5, 0.66, 0.035, rope)
	for i = -1, 1 do
		local off = i * 0.13
		Shapes.line(c, 0.29 + off, 0.27, 0.45 + off, 0.73, 0.022, rope)
		Shapes.line(c, 0.71 + off, 0.27, 0.55 + off, 0.73, 0.022, rope)
	end
end

DRAW.grog = function(c, x)
	local pit = hex("2B3618")
	-- a dark pit in the middle, and the Grog's eyes peering out of it
	local parts = Shapes.hex(c, 0.5, 0.52, x.r * 1.45, pit, { rot = if x.flat then 90 else 0 })
	local _ = parts
	-- (above the card, so they peek out from the pit)
	for _, ex in { 0.42, 0.58 } do
		Shapes.circle(c, ex, 0.235, 0.085, hex("F2F0E6"))
		Shapes.circle(c, ex + 0.012, 0.24, 0.042, hex("1E2410"))
	end
end

DRAW.teleporter = function(c, x)
	local light = hex("A98BF2")
	local spin = Util.frame(c, {
		Name = "Spin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
	})
	Shapes.ring(spin, 0.5, 0.5, 0.72, 0.03, light, { cut = { 0, 0.8 } })
	Shapes.ring(spin, 0.5, 0.5, 0.54, 0.024, light, { cut = { 180, 0.75 } })
	Shapes.sparkle(c, 0.24, 0.3, 0.09, light)
	Shapes.sparkle(c, 0.76, 0.7, 0.08, light)
end

DRAW.spore_warper = function(c, x)
	local cap = hex("C2513B")
	local stem = hex("F0E2C4")
	local spot = hex("F7EDD8")
	for _, a in { 40, 140, 220, 320 } do
		local rad = math.rad(a)
		local mx, my = 0.5 + math.cos(rad) * 0.27, 0.5 + math.sin(rad) * 0.27
		Shapes.rect(c, mx, my + 0.04, 0.035, 0.07, stem)
		Shapes.half(c, mx, my, 0.11, cap, { dir = 0 })
		Shapes.circle(c, mx - 0.015, my - 0.02, 0.022, spot)
	end
end

DRAW.shifting_sands = function(c, x)
	local dune = hex("B8924A")
	for i = -1, 1 do
		local y = 0.5 + i * 0.16
		Shapes.taper(c, {
			{ 0.2, y },
			{ 0.32, y - 0.04 },
			{ 0.44, y + 0.02 },
			{ 0.56, y - 0.04 },
			{ 0.68, y + 0.02 },
			{ 0.8, y - 0.02 },
		}, 0.022, 0.022, dune, { steps = 3 })
	end
end

DRAW.conveyor = function(c, x)
	local rail = hex("2E3338")
	local mark = hex("F2C14E")
	local dir = x.dir or 0
	local a = math.rad(dir)
	local ux, uy = math.cos(a), math.sin(a)
	local px, py = -uy, ux
	for _, side in { -1, 1 } do
		local ox, oy = px * 0.2 * side, py * 0.2 * side
		Shapes.line(c, 0.5 - ux * 0.3 + ox, 0.5 - uy * 0.3 + oy, 0.5 + ux * 0.3 + ox, 0.5 + uy * 0.3 + oy, 0.03, rail)
	end
	-- chevrons pointing the way the belt runs (Shapes.chevron: 0 = up, 90 = right)
	for _, k in { -0.17, 0.17 } do
		Shapes.chevron(c, 0.5 + ux * k, 0.5 + uy * k, 0.2, 0.05, mark, { dir = dir + 90 })
	end
end

DRAW.river = function(c, x)
	local foam = hex("E8F4FB")
	Shapes.arc(c, 0.36, 0.36, 0.2, 0.025, foam, { dir = 0, t = 0.2 })
	Shapes.arc(c, 0.64, 0.64, 0.24, 0.025, foam, { dir = 0, t = 0.2 })
	Shapes.arc(c, 0.66, 0.34, 0.14, 0.02, foam, { dir = 0, t = 0.35 })
	Shapes.arc(c, 0.34, 0.68, 0.14, 0.02, foam, { dir = 0, t = 0.35 })
end

DRAW.gate = function(c, x)
	local iron = hex("3B3F44")
	for i = -2, 2 do
		Shapes.rect(c, 0.5 + i * 0.1, 0.5, 0.035, 0.56, iron)
	end
	Shapes.rect(c, 0.5, 0.27, 0.48, 0.04, iron)
	Shapes.rect(c, 0.5, 0.73, 0.48, 0.04, iron)
end

function TileSkins.draw(holder: Instance, kind: string, ctx): Frame?
	local fn = DRAW[kind]
	if not fn then
		return nil
	end
	local c = Shapes.canvas(holder, { Name = "Skin" })
	fn(c, { flat = ctx.flat == true, r = ctx.r or 0.44, dir = ctx.dir })
	return c
end

return TileSkins
