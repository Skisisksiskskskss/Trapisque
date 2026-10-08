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
	decorClear = 1.7, -- doodles keep this far from tile centers
	decorSpacing = 2.0,
	compassSize = 2.5,
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

	-- title banner: top centre unless tiles crowd it
	local titleY = y0 + S.titleSpace * 0.62
	layout.title = { x = (x0 + x1) / 2, y = titleY, w = math.min(9, layout.w * 0.6), h = 1.25 }

	-- compass rose: the emptiest corner
	local rng = Rng.new(#mapDef.id * 7919 + board.count * 31)
	local corners = {
		{ x0 + S.compassSize * 0.75, y1 - S.compassSize * 0.75 },
		{ x1 - S.compassSize * 0.75, y1 - S.compassSize * 0.75 },
		{ x1 - S.compassSize * 0.75, y0 + S.compassSize * 0.75 + S.titleSpace * 0.4 },
		{ x0 + S.compassSize * 0.75, y0 + S.compassSize * 0.75 + S.titleSpace * 0.4 },
	}
	local bestCorner, bestClear = corners[1], -1
	for _, c in corners do
		local clear = nearestTile(c[1], c[2])
		if clear > bestClear then
			bestCorner, bestClear = c, clear
		end
	end
	local compassSize = math.min(S.compassSize, math.max(1.4, (bestClear - 0.9) * 2))
	layout.compass = { x = bestCorner[1], y = bestCorner[2], size = compassSize }

	-- doodles in the empty spaces
	local theme = DecorData.themes[mapDef.theme] or DecorData.themes.water
	local candidates = {}
	local step = 0.8
	local y = y0 + 0.9
	while y < y1 - 0.9 do
		local x = x0 + 0.9
		while x < x1 - 0.9 do
			local clear = nearestTile(x, y)
			local inTitle = math.abs(y - layout.title.y) < 1.1 and math.abs(x - layout.title.x) < layout.title.w / 2 + 0.6
			local nearCompass = dist(x, y, layout.compass.x, layout.compass.y) < layout.compass.size * 0.75 + 1
			if clear >= S.decorClear and not inTitle and not nearCompass then
				table.insert(candidates, { x = x, y = y, clear = clear })
			end
			x += step
		end
		y += step
	end
	rng:shuffle(candidates)
	local used = {}
	for _, c in candidates do
		local ok = true
		for _, d in layout.decor do
			if dist(c.x, c.y, d.x, d.y) < S.decorSpacing then
				ok = false
				break
			end
		end
		if ok then
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
				local size = math.min(2.2, 1.05 + rng:float() * 0.9, (c.clear - 0.75) * 1.5)
				table.insert(layout.decor, {
					kind = kind,
					x = c.x,
					y = c.y,
					size = size,
					rot = (rng:float() - 0.5) * 16,
					flip = rng:float() < 0.5,
				})
			end
		end
	end
	return layout
end

return BoardLayout
