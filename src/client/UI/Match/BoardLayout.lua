--[[
	BoardLayout
	Where everything on a map goes. The map's scene (MapScenes) gives the winding route;
	this spaces the tiles evenly along a smooth curve through it, lays the trail under
	them, grows the land the trail runs through, cuts the rivers / tunnels / slime pools
	that belong to particular tiles, and finds room for the props. Pure logic (no Roblox
	APIs): MapArt and BoardView draw it, and the tests check nothing overlaps.

	Units are map units (about one tile radius). y runs down.

	The map is seen a little from the side: on screen the ground is squashed top to
	bottom (Style.squash), and the props and the pieces stand straight up off it, their
	foot on their spot. So a tall prop reaches up over whatever is behind it: the layout
	keeps props from standing in front of a tile (or whoever is on it) and checks what
	fits on screen in screen units (BoardLayout.toScreen).

	BoardLayout.build(board, mapDef, Rng, { rotate = true }) stands the map up for upright
	phones: everything turns a quarter clockwise (props stay upright). `view` is what the
	camera fits, on screen (the tiles, with room above them for the pieces); `tileBounds`
	is the tiles on the ground; x0, y0, w, h is the whole map, open water included.

	layout = {
		tiles = { { id, x, y, angle, kind, branch, scale } },
		trail = { { x1, y1, x2, y2, branch } },      -- tile to tile
		land = { { x, y, r, inner } },                -- the land is the union of these discs
		rivers = { { tile, points } },  lava = { { tile, points } } (lava streams),
		canals = { { tile, points } } (under Clockwork Cove's drawbridge),
		tunnels = { { points } },  pools = { { x, y, r } },
		props = { { kind, x, y, size, flip, ground, angle } },
		waves = { { x, y, w } },
		details = { { kind, x, y, size, flip } },     -- tufts, pebbles... lying on the land
		mottle = { { x, y, r, light } },              -- soft lighter / darker patches of it
	}
]]

local MapScenes = require(script.Parent.MapScenes)

local BoardLayout = {}

BoardLayout.Style = {
	tileR = 0.8, -- a tile's radius
	tileDepth = 0.12, -- how thick it is: its side shows below its top (on screen)
	squash = 0.72, -- seen a little from the side: the ground is this much shorter top to bottom
	trailW = 1.75, -- the trail under the tiles
	margin = 18, -- open water around the map: the camera never finds its edge
	pawn = 1.45, -- a character's size on a tile of its own
	pawnDisc = 0.92,
	pawnUp = 1.4, -- how far a piece standing on a tile reaches up from its middle (on screen)
	propGap = 0.3, -- clear space around props
	reach = 0.5, -- a prop's ink stays within this x its size from its middle
	foot = 0.35, -- a standing prop's foot: its ground, this x its size round its spot
}

-- Where pawns stand when several share a tile (where the middle of each one's base is,
-- from the tile's middle, on the ground) and how much they shrink so they stand side by
-- side instead of piling up.
BoardLayout.PawnSlots = {
	{ scale = 1, { 0, 0 } },
	{ scale = 0.56, { -0.38, 0 }, { 0.38, 0 } },
	{ scale = 0.52, { -0.38, -0.3 }, { 0.38, -0.3 }, { 0, 0.3 } },
	{ scale = 0.46, { -0.34, -0.32 }, { 0.34, -0.32 }, { -0.34, 0.3 }, { 0.34, 0.3 } },
	{ scale = 0.375, { -0.505, -0.3 }, { 0, -0.3 }, { 0.505, -0.3 }, { -0.26, 0.16 }, { 0.26, 0.16 } },
	{ scale = 0.375, { -0.505, -0.3 }, { 0, -0.3 }, { 0.505, -0.3 }, { -0.505, 0.22 }, { 0, 0.22 }, { 0.505, 0.22 } },
}

--[[
	What a tile looks like with something on it (BoardView draws it from art/items.py): a
	cover over its top (ice, mud, the river, lava, a portal...) or a thing standing on it,
	its foot on the tile's middle (a banana peel, spikes, a wall, the treasure chest...).
	[a card placed on the board, a map feature, embers, or what the tile is] =
	{ cover = sprite } or { stand = sprite, size = its canvas, map units }. A conveyor is
	its belt, drawn along the way it runs.
]]
BoardLayout.TileLooks = {
	-- standing on the tile (art/items.py; `facing`: turned to face the way the trail runs,
	-- art/tiles.py)
	spike = { stand = "spike", size = 1.3 },
	grog = { stand = "grog", size = 1.4 },
	fire = { stand = "fire", size = 1.4 },
	snare = { stand = "snare", size = 1.35 },
	banana = { stand = "banana", size = 1.3 },
	wall = { stand = "wall", size = 1.55, facing = true },
	spore_warper = { stand = "mushroom", size = 1.4 },
	gate = { stand = "gate", size = 1.5, facing = true },
	shortcutGate = { stand = "gate", size = 1.5, facing = true },
	treasure = { stand = "chest", size = 1.45 },
	start = { stand = "flag", size = 1.3 },
	-- what the tile turns into (art/tiles.py: its face, in the tile's own shape), and the
	-- colours its rim and side take. `bands`: stripes across it, cut to its shape (a
	-- conveyor's ridges, the sands' ripples, a deck's seams), `speed` periods a second
	ice = { face = "ice", rim = "#D7F1FB", side = "#6FA6C2" },
	mudslide = { face = "mud", rim = "#A47448", side = "#4E2F18" },
	teleporter = { face = "portal", rim = "#8EA4F2", side = "#26357A" },
	sands = {
		face = "sand",
		rim = "#F2DBA4",
		side = "#B08A4A",
		bands = { color = "#A8803E", alpha = 0.55, period = 0.2, duty = 0.62, speed = 0.45, slides = true },
	},
	river = { face = "water", rim = "#8ED3EE", side = "#2F86AE" },
	slime = { face = "slime", rim = "#A9DB5E", side = "#4E7E1A" },
	lava = { face = "lava", rim = "#7A2A12", side = "#3A1A12" },
	thinice = { face = "thinice", rim = "#E6F7FD", side = "#86B8D2" },
	thinice_cracked = { face = "thinice_cracked", rim = "#E6F7FD", side = "#86B8D2" },
	hole = { face = "hole", rim = "#E6F7FD", side = "#86B8D2" },
	cog = { face = "cog", rim = "#EDC66A", side = "#8A6212" },
	embers = { face = "embers", rim = "#5A4A42", side = "#2A211D" },
	conveyor = {
		face = "belt",
		rim = "#A3ABBB",
		side = "#596274",
		bands = { color = "#C9D0DC", alpha = 0.12, period = 0.24, duty = 0.55, sharp = 0.07, speed = 1.6 },
	},
	-- a drawbridge down (its deck) and up (the canal under it)
	deck = {
		face = "planks",
		rim = "#D4A672",
		side = "#7A5230",
		bands = { color = "#4E331C", alpha = 0.2, period = 0.2, duty = 0.07, sharp = 0.07 },
	},
	gap = { face = "canal", rim = "#7E7666", side = "#4A4438" },
}

-- Something standing across the trail faces the way it runs: its turn (art/tiles.py,
-- 22.5 degrees apart), for a tile where the trail heads `angle` degrees (on the ground).
-- Seen exactly end on it'd be a sliver, so that turn is the nearest one either side.
local TURNS = 8
function BoardLayout.facingTurn(angle: number): number
	local yaw = (angle + 90) % 180
	local k = math.floor(yaw / (180 / TURNS) + 0.5) % TURNS
	if k == TURNS / 2 then
		k = if yaw < 90 then k - 1 else k + 1
	end
	return k
end

-- How big each prop is, if a landmark or the scatter doesn't say.
BoardLayout.PropSize = {
	palm = 1.9,
	bush = 1.1,
	rock = 1.0,
	hut = 1.8,
	flowers = 0.8,
	gull = 0.8,
	barrel = 0.8,
	crate = 0.8,
	torch = 1.0,
	cannon = 1.3,
	mangrove = 2.0,
	reeds = 1.0,
	mushroom = 0.85,
	log = 1.3,
	stump = 0.9,
	lily = 0.9,
	bubbles = 0.7,
	islet = 1.0,
	grave = 0.9,
	pumpkin = 0.85,
	lamp = 1.2,
	fence = 1.1,
	mist = 1.3,
	lavarock = 1.0,
	charred = 1.4,
	vent = 1.1,
	pine_snow = 2.0,
	icerock = 1.0,
	snowman = 1.3,
	iceberg = 1.8,
	floe = 1.3,
	seal = 1.3,
	tentacle = 1.8,
	coral = 1.2,
	barnacle = 1.0,
	mast = 2.0,
	anchor = 1.2,
	bones = 1.6,
	gear = 1.4,
	pipes = 1.2,
	smokestack = 2.2,
	buoy = 1.0,
}

-- Props that lie flat on the ground (drawn under the tiles, may touch the trail).
local GROUND = { dock = true, whirlpool = true }

-- On screen (map units): a standing prop's ink, from its foot (sx, sy) up most of its
-- canvas (MapArt stands its canvas with its foot 0.92 of the way down)...
function BoardLayout.inkBox(sx: number, sy: number, size: number): (number, number, number, number)
	local h = size * 0.44
	return sx - h, sy - size * 0.88, sx + h, sy + size * 0.06
end

-- ...and a tile's top and side, with room above it for whoever stands on it.
function BoardLayout.tileBox(sx: number, sy: number, scale: number?): (number, number, number, number)
	local S = BoardLayout.Style
	local r = S.tileR * (scale or 1) + 0.08
	return sx - r, sy - S.pawnUp, sx + r, sy + r * S.squash + S.tileDepth + 0.05
end

-- Where a point of the (finished) map is on screen, in map units.
function BoardLayout.toScreen(x: number, y: number): (number, number)
	return x, y * BoardLayout.Style.squash
end

local function overlaps(a0: number, b0: number, a1: number, b1: number, c0: number, d0: number, c1: number, d1: number): boolean
	return a0 < c1 and c0 < a1 and b0 < d1 and d0 < b1
end
BoardLayout.overlaps = overlaps

local function dist(ax: number, ay: number, bx: number, by: number): number
	local dx, dy = ax - bx, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------
-- curves
---------------------------------------------------------------------------

-- One centripetal Catmull-Rom segment from p1 to p2, `n` samples (p2 itself left out).
local function segment(p0, p1, p2, p3, n: number, out: { { number } })
	local function knot(t: number, a, b): number
		return t + math.max(dist(a[1], a[2], b[1], b[2]), 1e-4) ^ 0.5
	end
	local t0 = 0
	local t1 = knot(t0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	local function lerp(a, b, ta: number, tb: number, t: number)
		if tb - ta < 1e-9 then
			return a
		end
		local u, v = (tb - t) / (tb - ta), (t - ta) / (tb - ta)
		return { u * a[1] + v * b[1], u * a[2] + v * b[2] }
	end
	for k = 0, n - 1 do
		local t = t1 + (t2 - t1) * k / n
		local a1 = lerp(p0, p1, t0, t1, t)
		local a2 = lerp(p1, p2, t1, t2, t)
		local a3 = lerp(p2, p3, t2, t3, t)
		local b1 = lerp(a1, a2, t0, t2, t)
		local b2 = lerp(a2, a3, t1, t3, t)
		table.insert(out, lerp(b1, b2, t1, t2, t))
	end
end

-- A smooth curve through `pts` (it leaves the ends heading straight on).
local function spline(pts: { { number } }): { { number } }
	if #pts < 2 then
		return { pts[1] }
	end
	local first, last = pts[1], pts[#pts]
	local P = { { 2 * first[1] - pts[2][1], 2 * first[2] - pts[2][2] } }
	for _, p in pts do
		table.insert(P, p)
	end
	table.insert(P, { 2 * last[1] - pts[#pts - 1][1], 2 * last[2] - pts[#pts - 1][2] })
	local out = {}
	for i = 2, #P - 2 do
		segment(P[i - 1], P[i], P[i + 1], P[i + 2], 24, out)
	end
	table.insert(out, last)
	return out
end

-- Cumulative length along a sampled curve.
local function lengths(samples: { { number } }): ({ number }, number)
	local L = { 0 }
	for i = 2, #samples do
		L[i] = L[i - 1] + dist(samples[i][1], samples[i][2], samples[i - 1][1], samples[i - 1][2])
	end
	return L, L[#L]
end

-- The point (and heading, in degrees) at length `at` along the curve.
local function pointAt(samples, L, at: number): (number, number, number)
	local lo, hi = 1, #L
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if L[mid] <= at then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = samples[lo], samples[hi]
	local seg = L[hi] - L[lo]
	local f = if seg < 1e-9 then 0 else math.clamp((at - L[lo]) / seg, 0, 1)
	local angle = math.deg(math.atan2(b[2] - a[2], b[1] - a[1]))
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, angle
end

-- `count` points evenly along the curve: from end to end, or (inner) strictly between.
local function spaced(samples, count: number, inner: boolean): { { number } }
	local L, total = lengths(samples)
	local out = {}
	for k = 1, count do
		local at = if inner then total * k / (count + 1) else total * (k - 1) / math.max(1, count - 1)
		local x, y, a = pointAt(samples, L, at)
		out[k] = { x, y, a }
	end
	return out
end
BoardLayout.spline = spline
BoardLayout.spaced = spaced

---------------------------------------------------------------------------
-- smooth edges
---------------------------------------------------------------------------

--[[
	Smooths a union of discs (a morphological closing): every corner of water caught
	where two discs meet is filled with a curve of radius `ball`, as if the sea had worn
	the coast round. For each of `grows` (the discs widened by that much first, and the
	curve narrowed by it, so a layer's edge stays parallel to the land's), returns the
	extra discs that fill those corners: draw them in the same ink as that layer. Holes
	narrower than `holes` (0.6 if not given) left where three discs nearly meet are
	filled too.
]]
function BoardLayout.fillets(discs: { any }, ball: number, grows: { number }, holes: number?): { { { x: number, y: number, r: number } } }
	local reach = holes or 0.6
	local out = {}
	for gi in grows do
		out[gi] = {}
	end
	-- each disc's neighbours: every disc close enough to share a corner, a ball or a hole
	-- with it (found through buckets, so not every pair is compared)
	local CELL = 4
	local buckets: { [string]: { number } } = {}
	local maxR = 0
	for i, c in discs do
		local key = math.floor(c.x / CELL) .. ":" .. math.floor(c.y / CELL)
		buckets[key] = buckets[key] or {}
		table.insert(buckets[key], i)
		maxR = math.max(maxR, c.r)
	end
	local margin = math.max(2 * ball, reach)
	local span = math.ceil((2 * maxR + margin) / CELL)
	local near: { { number } } = {}
	for i, a in discs do
		local list = {}
		local bx, by = math.floor(a.x / CELL), math.floor(a.y / CELL)
		for gx = bx - span, bx + span do
			for gy = by - span, by + span do
				for _, k in buckets[gx .. ":" .. gy] or {} do
					local c = discs[k]
					if k ~= i and dist(a.x, a.y, c.x, c.y) < a.r + c.r + margin then
						table.insert(list, k)
					end
				end
			end
		end
		near[i] = list
	end
	-- is there a disc near i (other than j) within `pad` of (qx, qy)?
	local function touches(i: number, qx: number, qy: number, pad: number, j: number?): boolean
		for _, k in near[i] do
			local c = discs[k]
			if k ~= j and dist(qx, qy, c.x, c.y) < c.r + pad then
				return true
			end
		end
		return false
	end
	-- the little holes left where three discs nearly meet: from each corner of one, a
	-- disc across to the land on its far side
	local function plug(i: number, a, b, d: number)
		local al = (a.r * a.r - b.r * b.r + d * d) / (2 * d)
		local h2 = a.r * a.r - al * al
		if h2 <= 0 then
			return
		end
		local ux, uy = (b.x - a.x) / d, (b.y - a.y) / d
		for _, side in { 1, -1 } do
			local h = math.sqrt(h2) * side
			local vx, vy = a.x + ux * al - uy * h, a.y + uy * al + ux * h
			if not touches(i, vx, vy, -1e-3) then
				-- heading out of the land, between the two
				local ox, oy = (vx - a.x) / a.r + (vx - b.x) / b.r, (vy - a.y) / a.r + (vy - b.y) / b.r
				local len = math.sqrt(ox * ox + oy * oy)
				if len > 1e-6 then
					ox, oy = ox / len, oy / len
					local t = 0.05
					while t <= reach do
						if touches(i, vx + ox * t, vy + oy * t, 0) then
							for gi, g in grows do
								table.insert(out[gi], { x = vx + ox * t / 2, y = vy + oy * t / 2, r = t / 2 + 0.06 + g })
							end
							break
						end
						t += 0.05
					end
				end
			end
		end
	end
	for i, a in discs do
		for _, j in near[i] do
			if j <= i then
				continue
			end
			local b = discs[j]
			local d = dist(a.x, a.y, b.x, b.y)
			if d > math.abs(a.r - b.r) and d < a.r + b.r then
				plug(i, a, b, d)
			end
			if d <= 1e-6 or d <= math.abs(a.r - b.r) then
				continue
			end
			local ux, uy = (b.x - a.x) / d, (b.y - a.y) / d
			for _, side in { 1, -1 } do
				-- the biggest ball that fits the corner (a tight one, in a little lagoon,
				-- gets a smaller ball, so it's still rounded instead of left as a spike)
				for _, size in { ball, ball * 0.6, ball * 0.35 } do
					local Ra, Rb = a.r + size, b.r + size
					-- the ball touches both where the circles of radius r + ball cross
					local along = (Ra * Ra - Rb * Rb + d * d) / (2 * d)
					local h2 = Ra * Ra - along * along
					if d >= Ra + Rb or h2 <= 0 then
						continue
					end
					local h = math.sqrt(h2)
					local qx, qy = a.x + ux * along - uy * h * side, a.y + uy * along + ux * h * side
					if touches(i, qx, qy, size - 1e-3, j) then
						continue
					end
					local ta = math.atan2(a.y - qy, a.x - qx)
					local sweep = (math.atan2(b.y - qy, b.x - qx) - ta + math.pi) % (2 * math.pi) - math.pi
					for gi, g in grows do
						local bg = size - g
						local ra, rb = a.r + g, b.r + g
						-- the corner's tip: where the widened discs cross on this side
						-- (or halfway across the gap between them)
						local px, py, past
						if d < ra + rb then
							local al = (ra * ra - rb * rb + d * d) / (2 * d)
							local hh = math.sqrt(math.max(0, ra * ra - al * al))
							px, py = a.x + ux * al - uy * hh * side, a.y + uy * al + ux * hh * side
							past = math.min(0.8, hh * 1.8)
						else
							local t = (ra + (d - ra - rb) / 2) / d
							px, py = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t
							past = 0.05
						end
						local depth = dist(px, py, qx, qy) - bg
						if bg > 0.05 and depth > 0.05 then
							-- a chain of discs along the ball's edge, each touching it,
							-- from inside one disc to inside the other
							local s = math.min(math.max(depth / 2 + 0.03, 0.25), (depth + past) / 2)
							local steps = math.clamp(math.ceil(math.abs(sweep) * (bg + s) / s), 1, 40)
							for k = 0, steps do
								local t = ta + sweep * k / steps
								table.insert(out[gi], { x = qx + math.cos(t) * (bg + s), y = qy + math.sin(t) * (bg + s), r = s })
							end
						end
					end
					break
				end
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- the layout
---------------------------------------------------------------------------

function BoardLayout.build(board, mapDef, Rng, opts: { [string]: any }?)
	local S = BoardLayout.Style
	local scene = MapScenes[mapDef.id] or MapScenes.blissful
	local rotate = opts ~= nil and opts.rotate == true
	local rng = Rng.new(#mapDef.id * 7919 + board.count * 31)
	local layout = {
		map = mapDef.id,
		theme = mapDef.theme,
		name = mapDef.name,
		scene = scene,
		rotated = rotate,
		tiles = {},
		trail = {},
		land = {},
		rivers = {},
		lava = {},
		canals = {},
		tunnels = {},
		pools = {},
		props = {},
		waves = {},
		details = {},
		mottle = {},
	}

	-- tiles along the route, then along each shortcut. A short board (house rules) has
	-- its tiles along the first part of the route only; the island is still all there.
	local pos: { [number]: { number } } = {}
	local wholeCurve = spline(scene.path)
	local mainCurve = wholeCurve
	if board.fullCount and board.count < board.fullCount then
		local L, total = lengths(wholeCurve)
		local keep = total * (board.count - 1) / (board.fullCount - 1)
		mainCurve = {}
		for i, p in wholeCurve do
			if L[i] <= keep then
				table.insert(mainCurve, p)
			else
				-- where the cut falls
				local a = wholeCurve[i - 1]
				local f = (keep - L[i - 1]) / math.max(1e-9, L[i] - L[i - 1])
				table.insert(mainCurve, { a[1] + (p[1] - a[1]) * f, a[2] + (p[2] - a[2]) * f })
				break
			end
		end
	end
	for i, p in spaced(mainCurve, board.count, false) do
		pos[i] = p
	end
	local curves = { { samples = mainCurve } }
	for bi, b in board.branches do
		local pts = { { pos[b.from][1], pos[b.from][2] } }
		for _, v in (scene.branches and scene.branches[b.index or bi]) or {} do
			table.insert(pts, v)
		end
		table.insert(pts, { pos[b.to][1], pos[b.to][2] })
		local curve = spline(pts)
		for k, p in spaced(curve, #b.tiles, true) do
			pos[b.tiles[k]] = p
		end
		table.insert(curves, { samples = curve, branch = bi })
	end
	for _, t in board.tiles do
		local p = pos[t.id]
		local scale = if t.kind == "treasure" then 1.3 elseif t.kind == "start" then 1.15 else 1
		table.insert(layout.tiles, { id = t.id, x = p[1], y = p[2], angle = p[3], kind = t.kind, branch = t.branch, scale = scale })
	end

	-- the trail, tile to tile
	for id, list in board.forward do
		for _, to in list do
			local a, c = board.tiles[id], board.tiles[to]
			local branch = a.branch or c.branch
			table.insert(layout.trail, { x1 = pos[id][1], y1 = pos[id][2], x2 = pos[to][1], y2 = pos[to][2], branch = branch })
		end
	end

	-- dense points along every trail (for keeping things off it), with how far along the
	-- main route each one is
	local trailPts = {}
	for _, cv in curves do
		local L = lengths(cv.samples)
		for i, p in cv.samples do
			table.insert(trailPts, { p[1], p[2], if cv.branch then -1000 * cv.branch else L[i] })
		end
	end
	local function nearTrail(x: number, y: number, skipFrom: number?, skipTo: number?): number
		local best = math.huge
		for _, p in trailPts do
			if not (skipFrom and p[3] >= skipFrom and p[3] <= skipTo) then
				local d = dist(x, y, p[1], p[2])
				if d < best then
					best = d
				end
			end
		end
		return best
	end
	-- how far from the trail as it's drawn (straight from tile to tile) or the curve it
	-- follows, whichever is nearer
	local function offTrail(x: number, y: number): number
		local best = nearTrail(x, y)
		for _, sg in layout.trail do
			local dx, dy = sg.x2 - sg.x1, sg.y2 - sg.y1
			local len2 = dx * dx + dy * dy
			local t = if len2 < 1e-12 then 0 else math.clamp(((x - sg.x1) * dx + (y - sg.y1) * dy) / len2, 0, 1)
			best = math.min(best, dist(x, y, sg.x1 + dx * t, sg.y1 + dy * t))
		end
		return best
	end

	-- land: discs along every trail (and the rest of a short board's route), plus the
	-- scene's extra land and islets
	local landCfg = scene.land
	local landCurves = table.clone(curves)
	landCurves[1] = { samples = wholeCurve }
	for _, cv in landCurves do
		local L, total = lengths(cv.samples)
		local at = 0
		while at <= total + 1e-6 do
			local x, y = pointAt(cv.samples, L, at)
			local r = landCfg.r + (rng:float() - 0.5) * 2 * landCfg.jitter
			table.insert(layout.land, { x = x, y = y, r = r })
			at += 1.1
		end
	end
	for _, a in landCfg.add or {} do
		table.insert(layout.land, { x = a[1], y = a[2], r = a[3] })
	end
	for _, a in scene.islets or {} do
		table.insert(layout.land, { x = a[1], y = a[2], r = a[3], islet = true })
	end
	-- how deep inside the land a point is (negative: that far out to sea)
	local function landDepth(x: number, y: number): number
		local best = -math.huge
		for _, c in layout.land do
			local d = c.r - dist(x, y, c.x, c.y)
			if d > best then
				best = d
			end
		end
		return best
	end
	layout.landDepth = landDepth

	-- fill the slivers of water caught between the trail's bends (a real lagoon, wider
	-- than a few tiles, stays)
	do
		local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
		for _, c in layout.land do
			x0, x1 = math.min(x0, c.x - c.r), math.max(x1, c.x + c.r)
			y0, y1 = math.min(y0, c.y - c.r), math.max(y1, c.y + c.r)
		end
		local fills = {}
		local y = y0
		while y <= y1 do
			local x = x0
			while x <= x1 do
				local d = landDepth(x, y)
				if d < 0 and d > -1.8 then
					local enclosed = true
					for k = 0, 7 do
						local a = k * math.pi / 4
						local hit = false
						local reach = 0.5
						while reach <= (landCfg.fill or 2.6) do
							if landDepth(x + math.cos(a) * reach, y + math.sin(a) * reach) > 0 then
								hit = true
								break
							end
							reach += 0.5
						end
						if not hit then
							enclosed = false
							break
						end
					end
					if enclosed then
						table.insert(fills, { x = x, y = y, r = 1.05, fill = true })
					end
				end
				x += 0.6
			end
			y += 0.6
		end
		for _, f in fills do
			table.insert(layout.land, f)
		end
		-- and bridge discs that almost touch (a hairline of coast ink between them looks
		-- like a scratch)
		local bridges = {}
		local n = #layout.land
		for i = 1, n do
			local a = layout.land[i]
			for j = i + 1, n do
				local b = layout.land[j]
				local d = dist(a.x, a.y, b.x, b.y)
				local gap = d - a.r - b.r
				if gap > 0 and gap < 0.7 and not (a.islet or b.islet) then
					local t = (a.r + gap / 2) / d
					table.insert(bridges, { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, r = gap / 2 + 0.55, fill = true })
				end
			end
		end
		for _, f in bridges do
			table.insert(layout.land, f)
		end
	end

	-- rivers (Blissful) and lava streams (Mount Kaboom), and the canal under Clockwork
	-- Cove's drawbridge: from the tile across the land to the sea, or to a pond before
	-- they'd meet the trail again. (`p` is where it crosses the trail, `here` how far
	-- along the trail that is; a canal runs straight.)
	local mainL = lengths(mainCurve)
	local spacing = mainL[#mainL] / math.max(1, board.count - 1)
	local function channel(tile: number, p: { number }, here: number, wiggle: number, sourceMax: number?)
		local heading = math.rad(p[3] + 90)
		local sides = {}
		for side = 1, 2 do
			local pts = {}
			local x, y = p[1], p[2]
			local base = heading + (if side == 2 then math.pi else 0)
			local phase = rng:float() * 6
			local walked, ends = 0, "pond"
			local out = 0
			while walked < 9 do
				local a = base + wiggle * math.sin(walked * 0.75 + phase)
				x += math.cos(a) * 0.4
				y += math.sin(a) * 0.4
				walked += 0.4
				if nearTrail(x, y, here - 2.4, here + 2.4) < 1.9 then
					break
				end
				table.insert(pts, { x, y })
				if landDepth(x, y) < 0 then
					out += 0.4
					if out >= 1.2 then
						ends = "sea"
						break
					end
				end
			end
			-- (lava wells up from a vent close by, where you can see it)
			if ends == "pond" and sourceMax then
				while #pts > 1 and #pts * 0.4 > sourceMax do
					table.remove(pts)
				end
			end
			sides[side] = { pts = pts, ends = ends }
		end
		local points = {}
		for i = #sides[1].pts, 1, -1 do
			table.insert(points, sides[1].pts[i])
		end
		table.insert(points, { p[1], p[2] })
		for _, q in sides[2].pts do
			table.insert(points, q)
		end
		return { tile = tile, points = points, endA = sides[1].ends, endB = sides[2].ends }
	end
	if scene.rivers or scene.lava then
		for tile, kind in board.naturalInit do
			if (kind == "river" and scene.rivers) or (kind == "lava" and scene.lava) then
				table.insert(if kind == "lava" then layout.lava else layout.rivers, channel(tile, pos[tile], (tile - 1) * spacing, 0.42, if kind == "lava" then 3.6 else nil))
			end
		end
	end
	for _, span in (if scene.canal then mapDef.drawbridges else nil) or {} do
		if pos[span[1]] and pos[span[2]] then
			-- (between the bridge's two tiles)
			local a, b = pos[span[1]], pos[span[2]]
			local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, a[3] }
			table.insert(layout.canals, channel(span[1], mid, (span[1] - 0.5) * spacing, 0.06))
		end
	end

	-- tunnels (Junction's shortcuts)
	if scene.tunnels then
		for _, cv in curves do
			if cv.branch then
				table.insert(layout.tunnels, { branch = cv.branch, points = cv.samples })
			end
		end
	end

	-- slime pools (Slimy)
	if scene.pools then
		for tile, kind in board.naturalInit do
			if kind == "slime" then
				local p = pos[tile]
				local a = math.rad(p[3])
				local blobs = { { 0, 0, 1.35 } }
				for _, o in { { 0.95, 0.35, 0.95 }, { -0.9, -0.3, 1.0 }, { 0.2, -0.75, 0.8 }, { -0.3, 0.8, 0.75 } } do
					local ox = o[1] * math.cos(a) - o[2] * math.sin(a)
					local oy = o[1] * math.sin(a) + o[2] * math.cos(a)
					table.insert(blobs, { ox, oy, o[3] })
				end
				for _, b in blobs do
					table.insert(layout.pools, { x = p[1] + b[1], y = p[2] + b[2], r = b[3], tile = tile })
				end
			end
		end
	end

	-- landmarks: each one only where it fits (on land or at sea as it should be, clear
	-- of the trail, the tiles and each other, inside the view), moved a little if that's
	-- what it takes; the dock runs from the Start out to the nearest water
	local props = layout.props
	local WATER = { ship = true, wreck = true, sunken = true, ghostship = true, frozenship = true, whirlpool = true, iceberg = true }
	-- where a point ends up on screen (the map turned for upright screens, then squashed)
	local K = S.squash
	local function toScreen(x: number, y: number): (number, number)
		if rotate then
			return -y, x * K
		end
		return x, y * K
	end
	-- what the camera fits (the tiles, a margin, room above for the pieces): a prop stands
	-- wholly inside it, so none is cut in half by the edge of the screen
	local vx0, vy0, vx1, vy1 = math.huge, math.huge, -math.huge, -math.huge
	for _, t in layout.tiles do
		local sx, sy = toScreen(t.x, t.y)
		vx0, vx1 = math.min(vx0, sx - 1.25), math.max(vx1, sx + 1.25)
		vy0, vy1 = math.min(vy0, sy - S.pawnUp - 0.2), math.max(vy1, sy + 1.05)
	end
	layout.view = { x0 = vx0, y0 = vy0, x1 = vx1, y1 = vy1 }
	local function inView(x: number, y: number, size: number): boolean
		local sx, sy = toScreen(x, y)
		local a0, b0, a1, b1 = BoardLayout.inkBox(sx, sy, size)
		return a0 >= vx0 and a1 <= vx1 and b0 >= vy0 and b1 <= vy1
	end
	-- a standing prop isn't on a tile, and doesn't stand in front of one (or of whoever
	-- is on it): on screen it would hide it
	local function clearOfTiles(x: number, y: number, size: number): boolean
		local sx, sy = toScreen(x, y)
		local a0, b0, a1, b1 = BoardLayout.inkBox(sx, sy, size)
		for _, t in layout.tiles do
			if dist(x, y, t.x, t.y) < S.tileR * (t.scale or 1) + size * S.foot then
				return false
			end
			local tx, ty = toScreen(t.x, t.y)
			if ty <= sy + 0.05 then
				local c0, d0, c1, d1 = BoardLayout.tileBox(tx, ty, t.scale)
				if overlaps(a0, b0, a1, b1, c0, d0, c1, d1) then
					return false
				end
			end
		end
		return true
	end
	-- and stands a little apart from the other standing props (on screen; one in front
	-- of another hides a bit of it, as it should)
	local function apart(x: number, y: number, size: number, gap: number): boolean
		local sx, sy = toScreen(x, y)
		for _, q in props do
			if not q.ground then
				local qx, qy = toScreen(q.x, q.y)
				if dist(sx, sy, qx, qy) < (size + q.size) * S.reach * 0.9 + gap then
					return false
				end
			end
		end
		return true
	end
	for _, m in scene.landmarks or {} do
		local kind = m[1]
		local size = m.size or BoardLayout.PropSize[kind] or 1.5
		local x, y, angle = m.x, m.y, 0
		if m.tile then
			local p = pos[m.tile]
			x, y, angle = p[1] + (m.dx or 0), p[2] + (m.dy or 0), p[3]
		end
		local fits = true
		if kind == "dock" then
			local p = pos[m.tile or 1]
			local bestA, bestD = nil, math.huge
			for k = 0, 23 do
				local a = k * math.pi / 12
				local reach = 0.5
				while reach <= 6 do
					local qx, qy = p[1] + math.cos(a) * reach, p[2] + math.sin(a) * reach
					if landDepth(qx, qy) < -0.4 then
						break
					end
					reach += 0.25
				end
				-- straight out to sea, and not across another bit of trail
				local clear = nearTrail(p[1] + math.cos(a) * (reach * 0.5 + 0.9), p[2] + math.sin(a) * (reach * 0.5 + 0.9), -1, 2.5) > 1.4
				if clear and reach < bestD then
					bestA, bestD = a, reach
				end
			end
			if bestA then
				local len = math.clamp(bestD + 1.2, size * 0.8, 3.4)
				size = len
				x = p[1] + math.cos(bestA) * len * 0.5
				y = p[2] + math.sin(bestA) * len * 0.5
				angle = math.deg(bestA)
			else
				fits = false
			end
		else
			local reach = size * S.reach
			local function fitsAt(px: number, py: number): boolean
				local depth = landDepth(px, py)
				local ok = if WATER[kind] then depth <= -(reach * 0.6) else depth >= reach * 0.3
				return ok
					and inView(px, py, size)
					and offTrail(px, py) >= S.trailW / 2 + size * S.foot
					and clearOfTiles(px, py, size)
					and apart(px, py, size, 0)
			end
			fits = fitsAt(x, y)
			-- or the nearest spot close by where it does fit (inside the view, say)
			for ring = 1, 12 do
				if fits then
					break
				end
				for k = 0, 11 do
					local a = k * math.pi / 6
					local qx, qy = x + math.cos(a) * ring * 0.4, y + math.sin(a) * ring * 0.4
					if fitsAt(qx, qy) then
						x, y, fits = qx, qy, true
						break
					end
				end
			end
		end
		if fits then
			table.insert(props, {
				kind = kind,
				x = x,
				y = y,
				size = size,
				angle = angle,
				ground = GROUND[kind] == true,
				fixed = true,
			})
		end
	end

	-- the scatter: props on the land and on the water, none on the trail, a tile, a
	-- river, a pool, or each other
	local function clearOfWater(x: number, y: number, reach: number): boolean
		for _, list in { layout.rivers, layout.lava, layout.canals } do
			for _, r in list do
				for _, q in r.points do
					if dist(x, y, q[1], q[2]) < reach + 0.75 then
						return false
					end
				end
			end
		end
		for _, pl in layout.pools do
			if dist(x, y, pl.x, pl.y) < reach + pl.r + 0.2 then
				return false
			end
		end
		return true
	end
	-- (and the little things lying about keep off the props' feet)
	local function clearOfFeatures(x: number, y: number, reach: number): boolean
		if not clearOfWater(x, y, reach) then
			return false
		end
		for _, pr in props do
			if not pr.ground and dist(x, y, pr.x, pr.y) < reach + pr.size * S.foot + S.propGap then
				return false
			end
		end
		return true
	end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, c in layout.land do
		minX, maxX = math.min(minX, c.x - c.r), math.max(maxX, c.x + c.r)
		minY, maxY = math.min(minY, c.y - c.r), math.max(maxY, c.y + c.r)
	end
	local trailClear = S.trailW / 2 + 0.15
	local function scatter(weights: { [string]: number }, count: number, onLand: boolean)
		local cands = {}
		local step = 0.45
		local y = minY - 1.5
		while y <= maxY + 1.5 do
			local x = minX - 1.5
			while x <= maxX + 1.5 do
				local depth = landDepth(x, y)
				if (onLand and depth > 0.7) or (not onLand and depth < -1.1) then
					table.insert(cands, { x + (rng:float() - 0.5) * 0.3, y + (rng:float() - 0.5) * 0.3, depth })
				end
				x += step
			end
			y += step
		end
		rng:shuffle(cands)
		local placed = 0
		for _, c in cands do
			if placed >= count then
				break
			end
			local kind = rng:weighted(weights)
			local size = (BoardLayout.PropSize[kind] or 1) * (0.85 + rng:float() * 0.3)
			local reach = size * S.reach
			local ok = inView(c[1], c[2], size) and offTrail(c[1], c[2]) >= trailClear + size * S.foot
			if ok and onLand then
				ok = c[3] >= reach * 0.75
			elseif ok then
				ok = -c[3] >= reach + 0.5
			end
			if ok then
				ok = clearOfWater(c[1], c[2], size * S.foot) and clearOfTiles(c[1], c[2], size) and apart(c[1], c[2], size, S.propGap)
			end
			if ok then
				table.insert(props, { kind = kind, x = c[1], y = c[2], size = size, flip = rng:float() < 0.5, water = not onLand })
				placed += 1
			end
		end
	end

	-- groves: the scene's grove prop (palms on the island, mangroves in the swamp...) in
	-- the widest parts of the land, well away from the trail, so open ground isn't bare
	local P = scene.props or {}
	if P.grove then
		local cands = {}
		local yy = minY
		while yy <= maxY do
			local xx = minX
			while xx <= maxX do
				local depth = landDepth(xx, yy)
				local room = nearTrail(xx, yy)
				if depth >= 1.5 and room >= 2.3 then
					table.insert(cands, { xx, yy, math.min(depth - 0.5, room - 1.3) })
				end
				xx += 0.8
			end
			yy += 0.8
		end
		table.sort(cands, function(a, b)
			return a[3] > b[3]
		end)
		local size = (BoardLayout.PropSize[P.grove] or 1.5) * 1.15
		local placed = 0
		for _, c in cands do
			if placed >= (P.groveCount or 3) then
				break
			end
			local free = inView(c[1], c[2], size)
				and clearOfWater(c[1], c[2], size * S.reach + 1)
				and clearOfTiles(c[1], c[2], size)
				and apart(c[1], c[2], size, S.propGap + 0.6)
			if free then
				table.insert(props, { kind = P.grove, x = c[1], y = c[2], size = size, flip = rng:float() < 0.5 })
				placed += 1
			end
		end
	end

	if P.land then
		scatter(P.land, P.landCount or 16, true)
	end
	if P.water then
		scatter(P.water, P.waterCount or 6, false)
	end

	-- wave marks on the open water
	do
		local x0, y0, x1, y1 = minX - 7, minY - 6, maxX + 7, maxY + 6
		local cands = {}
		local y = y0
		while y <= y1 do
			local x = x0
			while x <= x1 do
				table.insert(cands, { x + rng:float() * 2.2, y + rng:float() * 2.2 })
				x += 3.1
			end
			y += 2.4
		end
		for _, c in cands do
			if landDepth(c[1], c[2]) < -1.3 and clearOfFeatures(c[1], c[2], 0.6) then
				table.insert(layout.waves, { x = c[1], y = c[2], w = 0.9 + rng:float() * 0.5 })
			end
		end
	end

	-- the little things lying about on the land (tufts, pebbles, shells...), spread out
	-- and off the trail, the rivers, the pools and the props; and soft patches of lighter
	-- and darker ground, so the land isn't one flat colour
	local D = scene.details
	if D then
		local cands = {}
		local yy = minY
		while yy <= maxY do
			local xx = minX
			while xx <= maxX do
				local x, y = xx + (rng:float() - 0.5) * 0.4, yy + (rng:float() - 0.5) * 0.4
				if landDepth(x, y) > 0.6 and offTrail(x, y) >= S.trailW / 2 + 0.4 and clearOfFeatures(x, y, 0.3) and clearOfTiles(x, y, 0.7) then
					table.insert(cands, { x, y })
				end
				xx += 0.7
			end
			yy += 0.7
		end
		rng:shuffle(cands)
		for _, c in cands do
			if #layout.details >= (D.count or 16) then
				break
			end
			local free = true
			for _, q in layout.details do
				if dist(c[1], c[2], q.x, q.y) < 1.7 then
					free = false
					break
				end
			end
			if free then
				table.insert(layout.details, { kind = rng:weighted(D.kinds), x = c[1], y = c[2], size = 0.75 + rng:float() * 0.25, flip = rng:float() < 0.5 })
			end
		end
	end
	local M = scene.mottle
	if M then
		local tries = 0
		while #layout.mottle < (M.count or 10) and tries < 500 do
			tries += 1
			local x, y = minX + rng:float() * (maxX - minX), minY + rng:float() * (maxY - minY)
			if landDepth(x, y) > 1 then
				table.insert(layout.mottle, { x = x, y = y, r = 1.4 + rng:float() * 1.4, light = rng:float() < 0.5 })
			end
		end
	end

	-- stand it up for upright screens: a quarter turn clockwise
	if rotate then
		local function turn(x: number, y: number): (number, number)
			return -y, x
		end
		for _, t in layout.tiles do
			t.x, t.y = turn(t.x, t.y)
			t.angle += 90
		end
		for _, s in layout.trail do
			s.x1, s.y1 = turn(s.x1, s.y1)
			s.x2, s.y2 = turn(s.x2, s.y2)
		end
		for _, list in { layout.land, layout.pools, layout.props, layout.waves, layout.details, layout.mottle } do
			for _, c in list do
				c.x, c.y = turn(c.x, c.y)
				if c.angle then
					c.angle += 90
				end
			end
		end
		for _, list in { layout.rivers, layout.lava, layout.canals, layout.tunnels } do
			for _, r in list do
				local pts = {}
				for i, q in r.points do
					local x, y = turn(q[1], q[2])
					pts[i] = { x, y }
				end
				r.points = pts
			end
		end
		-- (landDepth reads the land discs, which have just turned with everything else,
		-- so it already answers for the upright map)
	end

	-- bounds: the tiles (what the camera fits) and the whole map (open water included)
	local tx0, ty0, tx1, ty1 = math.huge, math.huge, -math.huge, -math.huge
	for _, t in layout.tiles do
		tx0, tx1 = math.min(tx0, t.x), math.max(tx1, t.x)
		ty0, ty1 = math.min(ty0, t.y), math.max(ty1, t.y)
	end
	layout.tileBounds = { x0 = tx0 - 1.25, y0 = ty0 - 1.25, x1 = tx1 + 1.25, y1 = ty1 + 1.25 }
	local mx0, my0, mx1, my1 = tx0, ty0, tx1, ty1
	for _, c in layout.land do
		mx0, mx1 = math.min(mx0, c.x - c.r), math.max(mx1, c.x + c.r)
		my0, my1 = math.min(my0, c.y - c.r), math.max(my1, c.y + c.r)
	end
	for _, p in layout.props do
		-- (a standing prop reaches up from its foot, a long way on the squashed ground)
		local r = p.size / 2
		local up = if p.ground then r else p.size / K
		mx0, mx1 = math.min(mx0, p.x - r), math.max(mx1, p.x + r)
		my0, my1 = math.min(my0, p.y - up), math.max(my1, p.y + r)
	end
	layout.content = { x0 = mx0, y0 = my0, x1 = mx1, y1 = my1 }
	layout.x0 = mx0 - S.margin
	layout.y0 = my0 - S.margin
	layout.w = (mx1 - mx0) + 2 * S.margin
	layout.h = (my1 - my0) + 2 * S.margin
	layout.spacing = spacing
	return layout
end

return BoardLayout
