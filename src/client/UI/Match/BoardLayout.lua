--[[
	BoardLayout
	Turns a board graph into a treasure-map scene: where the parchment ends, where each
	hex tile sits, the dashed route between tiles, and where the ink doodles, compass
	rose and title banner go. Pure logic (no Roblox APIs): the BoardView draws it and
	the offline previewer can draw it too.

	Units: 1 = one hex circumradius.
]]

local DecorData = require(script.Parent.Parent.DecorData)

local BoardLayout = {}

BoardLayout.Style = {
	tileScale = 0.86, -- drawn hex radius (leaves a gap so the dashed route shows)
	tileDepth = 0.16, -- height of the wooden side under each tile
	margin = 2.1,
	titleSpace = 1.3,
	coast = 1.29, -- radius of the pale land around each tile centre (BoardView draws it)
	washInset = 0.55, -- where the sea / stone / swamp wash starts inside the paper
	gap = 0.22, -- clear space between any two drawn things
	decorReach = 0.6, -- a doodle's ink stays within this x its size from its centre
	decorMin = 1.0,
	decorMax = 2.1,
	compassSize = 2.4,
	compassReach = 0.62, -- compass rose + its "N"
}

-- Where pawns sit when several share a tile (offsets in hex units from the tile centre)
-- and how much they shrink so they sit side by side instead of piling up.
BoardLayout.PawnSlots = {
	{ scale = 1, { 0, -0.3 } },
	{ scale = 0.76, { -0.34, -0.24 }, { 0.34, -0.24 } },
	{ scale = 0.68, { -0.33, -0.36 }, { 0.33, -0.36 }, { 0, 0.16 } },
	{ scale = 0.64, { -0.3, -0.4 }, { 0.3, -0.4 }, { -0.3, 0.18 }, { 0.3, 0.18 } },
	{ scale = 0.54, { -0.5, -0.34 }, { 0, -0.34 }, { 0.5, -0.34 }, { -0.26, 0.16 }, { 0.26, 0.16 } },
	{ scale = 0.54, { -0.5, -0.34 }, { 0, -0.34 }, { 0.5, -0.34 }, { -0.5, 0.16 }, { 0, 0.16 }, { 0.5, 0.16 } },
}

local function dist(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

function BoardLayout.build(board, mapDef, Rng)
	local S = BoardLayout.Style
	local b = board.bounds
	local x0 = b.minX - S.margin
	local y0 = b.minY - S.margin - S.titleSpace
	local x1 = b.maxX + S.margin
	local y1 = b.maxY + S.margin
	local layout = {
		map = mapDef.id,
		theme = mapDef.theme,
		name = mapDef.name,
		x0 = x0,
		y0 = y0,
		w = x1 - x0,
		h = y1 - y0,
		tiles = {},
		links = {},
		decor = {},
	}

	local function nearestTile(x, y)
		local best = math.huge
		for _, t in board.tiles do
			local d = dist(x, y, t.x, t.y)
			if d < best then
				best = d
			end
		end
		return best
	end

	for _, t in board.tiles do
		table.insert(layout.tiles, { id = t.id, x = t.x, y = t.y, kind = t.kind, branch = t.branch })
	end

	-- dashed route between consecutive tiles (and the gated shortcuts)
	for id, list in board.forward do
		for _, to in list do
			local a, c = board.tiles[id], board.tiles[to]
			table.insert(layout.links, {
				from = id,
				to = to,
				x1 = a.x,
				y1 = a.y,
				x2 = c.x,
				y2 = c.y,
				shortcut = (a.branch ~= nil) or (c.branch ~= nil),
			})
		end
	end

	-- title banner: top centre, in the strip reserved above the tiles
	local titleY = y0 + S.titleSpace * 0.62
	layout.title = { x = (x0 + x1) / 2, y = titleY, w = math.min(9, layout.w * 0.6), h = 1.25 }
	local tb = layout.title
	local titleHalfW, titleHalfH = tb.w / 2 + S.gap, tb.h / 2 + S.gap

	-- Largest square (side) centred at (x, y) that stays inside the wash and clear of the title.
	local innerX0, innerX1 = x0 + S.washInset + S.gap, x1 - S.washInset - S.gap
	local innerY0, innerY1 = y0 + S.washInset + S.gap, y1 - S.washInset - S.gap
	local function roomInFrame(x, y)
		local side = 2 * math.min(x - innerX0, innerX1 - x, y - innerY0, innerY1 - y)
		local ox = math.abs(x - tb.x) - titleHalfW
		local oy = math.abs(y - tb.y) - titleHalfH
		if ox < 0 and oy < 0 then
			return 0
		end
		return math.min(side, 2 * math.max(ox, oy))
	end
	-- Largest size whose ink (reach x size) stays off the land around the path.
	local function roomFromPath(x, y, reach)
		return (nearestTile(x, y) - S.coast - S.gap) / reach
	end

	local rng = Rng.new(#mapDef.id * 7919 + board.count * 31)

	-- compass rose: the roomiest spot, leaning towards the corners
	local best, bestScore = nil, -math.huge
	local cy = innerY0 + 0.5
	while cy < innerY1 - 0.5 do
		local cx = innerX0 + 0.5
		while cx < innerX1 - 0.5 do
			local size = math.min(S.compassSize, roomFromPath(cx, cy, S.compassReach), roomInFrame(cx, cy) / (2 * S.compassReach))
			if size >= 1.3 then
				local corner = math.min(dist(cx, cy, x0, y0), dist(cx, cy, x1, y0), dist(cx, cy, x0, y1), dist(cx, cy, x1, y1))
				local score = size - corner * 0.12
				if score > bestScore then
					best, bestScore = { x = cx, y = cy, size = size }, score
				end
			end
			cx += 0.25
		end
		cy += 0.25
	end
	layout.compass = best

	-- doodles in the empty spaces, none touching the path, the title, the compass or each other
	local theme = DecorData.themes[mapDef.theme] or DecorData.themes.water
	local candidates = {}
	local step = 0.4
	local y = innerY0 + S.decorMin / 2
	while y <= innerY1 - S.decorMin / 2 do
		local x = innerX0 + S.decorMin / 2
		while x <= innerX1 - S.decorMin / 2 do
			local room = math.min(S.decorMax, roomFromPath(x, y, S.decorReach), roomInFrame(x, y))
			if best then
				room = math.min(room, (dist(x, y, best.x, best.y) - best.size * S.compassReach - S.gap) / S.decorReach)
			end
			if room >= S.decorMin then
				table.insert(candidates, { x = x, y = y, room = room })
			end
			x += step
		end
		y += step
	end
	rng:shuffle(candidates)
	local used = {}
	for _, c in candidates do
		local room = c.room
		for _, d in layout.decor do
			-- keep a wider gap between doodles so the sea doesn't look cluttered
			room = math.min(room, (dist(c.x, c.y, d.x, d.y) - d.size * S.decorReach - 0.6) / S.decorReach)
		end
		if room >= S.decorMin then
			local kind
			for _ = 1, 6 do
				kind = rng:weighted(theme)
				if not (DecorData.unique[kind] and used[kind]) then
					break
				end
				kind = nil
			end
			if kind then
				used[kind] = true
				table.insert(layout.decor, {
					kind = kind,
					x = c.x,
					y = c.y,
					size = math.min(room, 1.1 + rng:float() * 0.8),
					rot = (rng:float() - 0.5) * 12,
					flip = rng:float() < 0.5,
				})
			end
		end
	end
	return layout
end

return BoardLayout
