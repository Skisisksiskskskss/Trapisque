--[[
	BoardLayout
	Where everything on a map goes. The map's scene (MapScenes) gives the winding route;
	this spaces the tiles evenly along a smooth curve through it, lays the trail under
	them, grows the land the trail runs through, cuts the rivers / tunnels / slime pools
	that belong to particular tiles, and finds room for the props. Pure logic (no Roblox
	APIs): MapArt and BoardView draw it, and the tests check nothing overlaps.

	Units are map units (about one tile radius). y runs down.

	BoardLayout.build(board, mapDef, Rng, { rotate = true }) stands the map up for upright
	phones: everything turns a quarter clockwise (props stay upright). `tileBounds` is
	what the camera fits; x0, y0, w, h is the whole map, open water included.

	layout = {
		tiles = { { id, x, y, angle, kind, branch, scale } },
		trail = { { x1, y1, x2, y2, branch } },      -- tile to tile
		land = { { x, y, r, inner } },                -- the land is the union of these discs
		rivers = { { tile, points } },  tunnels = { { points } },  pools = { { x, y, r } },
		props = { { kind, x, y, size, flip, ground, angle } },
		waves = { { x, y, w } },
	}
]]

local MapScenes = require(script.Parent.MapScenes)

local BoardLayout = {}

BoardLayout.Style = {
	tileR = 0.8, -- a tile's radius
	tileDepth = 0.15, -- its hard shadow, down and to the right
	trailW = 1.75, -- the trail under the tiles
	margin = 18, -- open water around the map: the camera never finds its edge
	pawn = 1.45, -- a character's size on a tile of its own
	pawnDisc = 0.92,
	propGap = 0.3, -- clear space around props
	reach = 0.5, -- a prop's ink stays within this x its size from its centre
}

-- Where pawns sit when several share a tile (offsets from the tile centre) and how much
-- they shrink so they stand side by side instead of piling up.
BoardLayout.PawnSlots = {
	{ scale = 1, { 0, -0.14 } },
	{ scale = 0.56, { -0.38, -0.12 }, { 0.38, -0.12 } },
	{ scale = 0.52, { -0.38, -0.3 }, { 0.38, -0.3 }, { 0, 0.3 } },
	{ scale = 0.46, { -0.34, -0.32 }, { 0.34, -0.32 }, { -0.34, 0.3 }, { 0.34, 0.3 } },
	{ scale = 0.375, { -0.505, -0.3 }, { 0, -0.3 }, { 0.505, -0.3 }, { -0.26, 0.16 }, { 0.26, 0.16 } },
	{ scale = 0.375, { -0.505, -0.3 }, { 0, -0.3 }, { 0.505, -0.3 }, { -0.505, 0.22 }, { 0, 0.22 }, { 0.505, 0.22 } },
}

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
}

-- Props that lie flat on the ground (drawn under the tiles, may touch the trail).
local GROUND = { dock = true, xmark = true }

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
		tunnels = {},
		pools = {},
		props = {},
		waves = {},
	}

	-- tiles along the route, then along each shortcut
	local pos: { [number]: { number } } = {}
	local mainCurve = spline(scene.path)
	for i, p in spaced(mainCurve, board.count, false) do
		pos[i] = p
	end
	local curves = { { samples = mainCurve } }
	for bi, b in board.branches do
		local pts = { { pos[b.from][1], pos[b.from][2] } }
		for _, v in (scene.branches and scene.branches[bi]) or {} do
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

	-- land: discs along every trail, plus the scene's extra land and islets
	local landCfg = scene.land
	for _, cv in curves do
		local L, total = lengths(cv.samples)
		local at = 0
		while at <= total + 1e-6 do
			local x, y = pointAt(cv.samples, L, at)
			local r = landCfg.r + (rng:float() - 0.5) * 2 * landCfg.jitter
			table.insert(layout.land, { x = x, y = y, r = r, inner = r - landCfg.beach })
			at += 1.1
		end
	end
	for _, a in landCfg.add or {} do
		table.insert(layout.land, { x = a[1], y = a[2], r = a[3], inner = if a.inner == false then nil else a[3] - landCfg.beach })
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

	-- rivers (Blissful): from the river tile across the land to the sea, or to a pond
	-- before they'd meet the trail again
	local mainL = lengths(mainCurve)
	local spacing = mainL[#mainL] / math.max(1, board.count - 1)
	if scene.rivers then
		for tile, kind in board.naturalInit do
			if kind == "river" then
				local p = pos[tile]
				local here = (tile - 1) * spacing
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
						local a = base + 0.42 * math.sin(walked * 0.75 + phase)
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
				table.insert(layout.rivers, { tile = tile, points = points, endA = sides[1].ends, endB = sides[2].ends })
			end
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

	-- the gates' posts (Junction): a squat tower either side of each gate tile
	local props = layout.props
	if scene.gates then
		for tile, kind in board.naturalInit do
			if kind == "gate" then
				local p = pos[tile]
				local a = math.rad(p[3] + 90)
				for _, sgn in { 1, -1 } do
					table.insert(props, {
						kind = "gatepost",
						x = p[1] + math.cos(a) * 1.45 * sgn,
						y = p[2] + math.sin(a) * 1.45 * sgn,
						size = 1.15,
						fixed = true,
					})
				end
			end
		end
	end

	-- landmarks
	for _, m in scene.landmarks or {} do
		local kind = m[1]
		local x, y, angle = m.x, m.y, 0
		if m.tile then
			local p = pos[m.tile]
			x, y, angle = p[1] + (m.dx or 0), p[2] + (m.dy or 0), p[3]
			if kind == "dock" then
				-- the pier runs out to sea behind the Start
				local back = math.rad(p[3] + 180)
				x, y = p[1] + math.cos(back) * m.size * 0.42, p[2] + math.sin(back) * m.size * 0.42
			end
		end
		table.insert(props, {
			kind = kind,
			x = x,
			y = y,
			size = m.size or BoardLayout.PropSize[kind] or 1.5,
			angle = angle,
			ground = GROUND[kind] == true,
			fixed = true,
		})
	end

	-- the scatter: props on the land and on the water, none on the trail, a tile, a
	-- river, a pool, or each other
	local function clearOfFeatures(x: number, y: number, reach: number): boolean
		for _, r in layout.rivers do
			for _, q in r.points do
				if dist(x, y, q[1], q[2]) < reach + 0.75 then
					return false
				end
			end
		end
		for _, pl in layout.pools do
			if dist(x, y, pl.x, pl.y) < reach + pl.r + 0.2 then
				return false
			end
		end
		for _, pr in props do
			if not pr.ground and dist(x, y, pr.x, pr.y) < reach + pr.size * S.reach + S.propGap then
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
			local ok = nearTrail(c[1], c[2]) >= trailClear + reach
			if ok and onLand then
				ok = c[3] >= reach * 0.75
			elseif ok then
				ok = -c[3] >= reach + 0.5
			end
			if ok then
				ok = clearOfFeatures(c[1], c[2], reach)
			end
			if ok then
				table.insert(props, { kind = kind, x = c[1], y = c[2], size = size, flip = rng:float() < 0.5, water = not onLand })
				placed += 1
			end
		end
	end
	local P = scene.props or {}
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
		for _, list in { layout.land, layout.pools, layout.props, layout.waves } do
			for _, c in list do
				c.x, c.y = turn(c.x, c.y)
				if c.angle then
					c.angle += 90
				end
			end
		end
		for _, list in { layout.rivers, layout.tunnels } do
			for _, r in list do
				local pts = {}
				for i, q in r.points do
					local x, y = turn(q[1], q[2])
					pts[i] = { x, y }
				end
				r.points = pts
			end
		end
		local depth = landDepth
		layout.landDepth = function(x: number, y: number): number
			return depth(y, -x)
		end
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
		local r = p.size / 2
		mx0, mx1 = math.min(mx0, p.x - r), math.max(mx1, p.x + r)
		my0, my1 = math.min(my0, p.y - r), math.max(my1, p.y + r)
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
