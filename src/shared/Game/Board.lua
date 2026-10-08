--[[
	Board
	Turns a map definition (a walk of hex steps) into a playable board graph.

	Tiles are numbered along the main route: 1 is Start, N is the Treasure.
	Junction-style maps add gated shortcut branches whose tiles are numbered after N.

	Hex layout is "pointy-top" axial coordinates (q, r).
		x = sqrt(3) * (q + r / 2)
		y = 1.5 * r
	(unit = hex circumradius)
]]

local Board = {}
Board.__index = Board

local SQRT3 = math.sqrt(3)

local DIRS = {
	E = { 1, 0 },
	W = { -1, 0 },
	NE = { 1, -1 },
	NW = { 0, -1 },
	SE = { 0, 1 },
	SW = { -1, 1 },
}
Board.DIRS = DIRS

local function key(q: number, r: number): string
	return q .. "," .. r
end

-- "E3 NE NW2" -> { "E", "E", "E", "NE", "NW", "NW" }
local function parseSteps(steps: string): { string }
	local out = {}
	for token in string.gmatch(steps, "%S+") do
		local dir, count = string.match(token, "^(%a+)(%d*)$")
		assert(dir and DIRS[dir], "Board: bad step '" .. token .. "'")
		local n = tonumber(count) or 1
		for _ = 1, n do
			table.insert(out, dir)
		end
	end
	return out
end
Board.parseSteps = parseSteps

local cache = {}

function Board.build(def)
	local self = setmetatable({}, Board)
	self.id = def.id
	self.def = def
	self.tiles = {} -- [id] = { id, q, r, x, y, kind, branch }
	self.nextMain = {} -- [id] = id (the default way forward)
	self.shortcut = {} -- [forkId] = first tile of a gated shortcut
	self.prevMain = {} -- [id] = id (the default way back)
	self.mainRoute = {}

	local byCoord = {}
	local function addTile(q, r, branch)
		local k = key(q, r)
		assert(byCoord[k] == nil, "Board " .. def.id .. ": two tiles at " .. k)
		local id = #self.tiles + 1
		local tile = {
			id = id,
			q = q,
			r = r,
			x = SQRT3 * (q + r / 2),
			y = 1.5 * r,
			kind = "normal",
			branch = branch,
		}
		self.tiles[id] = tile
		byCoord[k] = id
		return tile
	end

	-- main route
	local q, r = def.start[1], def.start[2]
	addTile(q, r, nil)
	table.insert(self.mainRoute, 1)
	for _, dir in parseSteps(def.route) do
		local d = DIRS[dir]
		q += d[1]
		r += d[2]
		local t = addTile(q, r, nil)
		table.insert(self.mainRoute, t.id)
	end
	self.count = #self.tiles
	self.start = 1
	self.treasure = self.count
	self.tiles[1].kind = "start"
	self.tiles[self.treasure].kind = "treasure"
	for i = 1, self.count - 1 do
		self.nextMain[i] = i + 1
		self.prevMain[i + 1] = i
	end

	-- gated shortcut branches
	self.branches = {}
	for bi, b in def.branches or {} do
		local fromId, toId = b.from, b.to
		assert(fromId > 1 and toId > fromId and toId < self.count, "Board " .. def.id .. ": bad branch " .. bi)
		local steps = parseSteps(b.steps)
		local bq, br = self.tiles[fromId].q, self.tiles[fromId].r
		local prev = fromId
		local branchTiles = {}
		for si, dir in steps do
			local d = DIRS[dir]
			bq += d[1]
			br += d[2]
			if si == #steps then
				assert(byCoord[key(bq, br)] == toId, "Board " .. def.id .. ": branch " .. bi .. " must end on tile " .. toId)
				self.nextMain[prev] = toId
			else
				local t = addTile(bq, br, bi)
				table.insert(branchTiles, t.id)
				if prev == fromId then
					self.shortcut[fromId] = t.id
					t.kind = "shortcutGate"
				else
					self.nextMain[prev] = t.id
				end
				self.prevMain[t.id] = prev
				prev = t.id
			end
		end
		assert(#branchTiles > 0, "Board " .. def.id .. ": branch " .. bi .. " has no tiles")
		table.insert(self.branches, { from = fromId, to = toId, tiles = branchTiles })
	end
	self.totalTiles = #self.tiles

	-- forward adjacency (for BFS)
	self.forward = {}
	for id = 1, self.totalTiles do
		local list = {}
		if self.nextMain[id] then
			table.insert(list, self.nextMain[id])
		end
		if self.shortcut[id] then
			table.insert(list, self.shortcut[id])
		end
		self.forward[id] = list
	end

	-- distance to treasure (shortest, any route)
	self.dist = {}
	do
		local reverse = {}
		for id = 1, self.totalTiles do
			reverse[id] = {}
		end
		for id, list in self.forward do
			for _, to in list do
				table.insert(reverse[to], id)
			end
		end
		local queue, head = { self.treasure }, 1
		self.dist[self.treasure] = 0
		while head <= #queue do
			local cur = queue[head]
			head += 1
			for _, from in reverse[cur] do
				if self.dist[from] == nil then
					self.dist[from] = self.dist[cur] + 1
					table.insert(queue, from)
				end
			end
		end
	end
	-- distance along the main route (what a player without a Key walks)
	self.mainDist = {}
	for id = 1, self.totalTiles do
		local steps, cur, guard = 0, id, 0
		while cur ~= self.treasure and guard < 1000 do
			cur = self.nextMain[cur]
			steps += 1
			guard += 1
		end
		self.mainDist[id] = steps
	end
	self.routeLength = self.mainDist[self.start]

	-- a shortest path from Start to every tile (used to rebuild a trail after teleports)
	self.pathFromStart = {}
	do
		local parent = { [self.start] = 0 }
		local queue, head = { self.start }, 1
		while head <= #queue do
			local cur = queue[head]
			head += 1
			for _, to in self.forward[cur] do
				if parent[to] == nil then
					parent[to] = cur
					table.insert(queue, to)
				end
			end
		end
		for id = 1, self.totalTiles do
			local path = {}
			local cur = id
			while cur and cur ~= 0 do
				table.insert(path, 1, cur)
				cur = parent[cur]
			end
			self.pathFromStart[id] = path
		end
	end

	-- undirected adjacency for "nearest player" distances
	self.neighbors = {}
	for id = 1, self.totalTiles do
		self.neighbors[id] = {}
	end
	for id, list in self.forward do
		for _, to in list do
			table.insert(self.neighbors[id], to)
			table.insert(self.neighbors[to], id)
		end
	end
	self._pairCache = {}

	-- token spots: every `tokenEvery` tiles along the main route
	self.tokenSpots = {}
	local naturalInit = {}
	for idx, kind in def.natural or {} do
		naturalInit[idx] = kind
	end
	self.naturalInit = naturalInit
	local every = def.tokenEvery or 3
	for i = 1 + every, self.count - 1, every do
		if naturalInit[i] == nil then
			table.insert(self.tokenSpots, i)
		end
	end

	-- bounds (for rendering)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, t in self.tiles do
		minX = math.min(minX, t.x)
		maxX = math.max(maxX, t.x)
		minY = math.min(minY, t.y)
		maxY = math.max(maxY, t.y)
	end
	self.bounds = { minX = minX, minY = minY, maxX = maxX, maxY = maxY }

	return self
end

function Board.get(def)
	local b = cache[def.id]
	if not b then
		b = Board.build(def)
		cache[def.id] = b
	end
	return b
end

-- Shortest undirected tile distance between a and b.
function Board:tileDistance(a: number, b: number): number
	if a == b then
		return 0
	end
	local row = self._pairCache[a]
	if not row then
		row = { [a] = 0 }
		local queue, head = { a }, 1
		while head <= #queue do
			local cur = queue[head]
			head += 1
			for _, n in self.neighbors[cur] do
				if row[n] == nil then
					row[n] = row[cur] + 1
					table.insert(queue, n)
				end
			end
		end
		self._pairCache[a] = row
	end
	return row[b] or math.huge
end

function Board:isSpecial(id: number): boolean
	return id == self.start or id == self.treasure
end

-- The `count` tiles starting at `id` and walking forward along the default route.
-- Returns nil if the walk would hit the treasure or run off the board.
function Board:span(id: number, count: number): { number }?
	local out = { id }
	local cur = id
	for _ = 2, count do
		cur = self.nextMain[cur]
		if cur == nil or cur == self.treasure then
			return nil
		end
		table.insert(out, cur)
	end
	return out
end

return Board
