--[[
	MapArt
	Paints a map's scene (BoardLayout) under the tiles: the open water, the land the
	trail runs through (shallows, a darker coast, the ground; every edge smoothed where
	its discs meet), the trail itself, rivers / tunnels / slime pools, and the props: the
	illustrations (Art) once their sheets are uploaded, the code-drawn stickers (MapProps)
	until then.

		MapArt.draw(layers, layout, U)   -- layers = { Water, Land, Trail, Props }
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local MapProps = require(UI.MapProps)
local Art = require(UI.Art)
local BoardLayout = require(script.Parent.BoardLayout)

local C = Theme.C
local hex = Theme.hex
local S = BoardLayout.Style

local MapArt = {}

-- A disc in map units.
local function disc(parent: Instance, L, U: number, x: number, y: number, r: number, color: Color3, z: number, name: string?): Frame
	local f = Util.new("Frame", {
		Name = name or "Disc",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x - L.x0) * U, (y - L.y0) * U),
		Size = UDim2.fromOffset(2 * r * U, 2 * r * U),
		ZIndex = z,
		Parent = parent,
	})
	Util.corner(f, 0.5)
	return f
end

-- A band `w` wide from (x1, y1) to (x2, y2), round at both ends.
local function band(parent: Instance, L, U: number, x1: number, y1: number, x2: number, y2: number, w: number, color: Color3, z: number, name: string?): Frame
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local f = Util.new("Frame", {
		Name = name or "Band",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(((x1 + x2) / 2 - L.x0) * U, ((y1 + y2) / 2 - L.y0) * U),
		Size = UDim2.fromOffset((len + w) * U, w * U),
		Rotation = math.deg(math.atan2(dy, dx)),
		ZIndex = z,
		Parent = parent,
	})
	Util.corner(f, 0.5)
	return f
end
MapArt.disc = disc
MapArt.band = band

-- A prop on a square holder standing at (x, y): its illustration (the one for standing
-- in the water, if it has one), or its sticker.
local function prop(parent: Instance, L, U: number, p, z: number)
	local name = "props/" .. p.kind
	if p.water and Art.has(name .. "_sea") then
		name ..= "_sea"
	end
	local art = MapProps[p.kind]
	if not art and not Art.has(name) then
		return
	end
	local size = p.size * U
	local holder = Util.frame(parent, {
		Name = "Prop_" .. p.kind,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((p.x - L.x0) * U, (p.y - L.y0) * U),
		Size = UDim2.fromOffset(size, size),
		Rotation = if p.ground and p.angle then p.angle else 0,
		ZIndex = z,
	})
	if Art.image(holder, name, { ZIndex = z }) then
		return
	end
	local ops = art
	if p.flip then
		ops = { { "group", fx = true, ops = art } }
	end
	Icons.sticker(holder, ops, nil, Icons.OUTLINE)
end

-- Discs plus the ones that round off the corners where they meet (BoardLayout.fillets).
local function smooth(parent: Instance, L, U: number, discs, fill, grow: number, color: Color3, z: number, name: string)
	for _, c in discs do
		disc(parent, L, U, c.x, c.y, c.r + grow, color, z, name)
	end
	for _, c in fill do
		disc(parent, L, U, c.x, c.y, c.r, color, z, name)
	end
end

function MapArt.draw(layers: { [string]: Frame }, L, U: number)
	local scene = L.scene
	local col = {}
	for k, v in scene.colors do
		col[k] = hex(string.sub(v, 2))
	end

	-- the water, far past the edges of the map
	local water = Util.new("Frame", {
		Name = "Water",
		BackgroundColor3 = col.water,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(L.w * U, L.h * U),
		ZIndex = 1,
		Parent = layers.Water,
	})
	-- (flat water: no wave marks)
	water.Name = "Water"

	-- the land: shallows, the coast (a darker band of the ground), the ground. Edges are
	-- darker shades of what they edge, never a black line, and they run smooth: the
	-- corners where two discs meet are filled in. The shallows get their own pass, which
	-- also fills the deep water left in the middle of a small lagoon (it's shallow all over).
	local land = layers.Land
	local shallows = {}
	for i, c in L.land do
		shallows[i] = { x = c.x, y = c.y, r = c.r + 0.75 }
	end
	smooth(land, L, U, shallows, BoardLayout.fillets(shallows, 0.6, { 0 }, 1.6)[1], 0, col.shallows, 1, "Shallows")
	local fill = BoardLayout.fillets(L.land, 1.1, { 0.1, 0 })
	smooth(land, L, U, L.land, fill[1], 0.1, Util.shade(col.land, -0.22), 2, "Coast")
	smooth(land, L, U, L.land, fill[2], 0, col.land, 3, "Ground")

	-- the trail (a shortcut runs through a dark tunnel), then what crosses it
	local trail = layers.Trail
	local W = S.trailW
	for _, s in L.trail do
		band(trail, L, U, s.x1, s.y1, s.x2, s.y2, W + 0.2, Util.shade(col.trail, -0.25), 1, "TrailEdge")
	end
	for _, s in L.trail do
		local c = if s.branch and col.tunnel then col.tunnel else col.trail
		band(trail, L, U, s.x1, s.y1, s.x2, s.y2, W, c, 2, if s.branch then "Tunnel" else "Trail")
	end
	if col.trailMark then
		-- boardwalk planks
		for _, s in L.trail do
			local dx, dy = s.x2 - s.x1, s.y2 - s.y1
			local len = math.sqrt(dx * dx + dy * dy)
			local nx, ny = -dy / len, dx / len
			for _, f in { 0.36, 0.64 } do
				local mx, my = s.x1 + dx * f, s.y1 + dy * f
				band(trail, L, U, mx - nx * W * 0.42, my - ny * W * 0.42, mx + nx * W * 0.42, my + ny * W * 0.42, 0.07, col.trailMark, 3, "Plank")
			end
		end
	end
	if col.tunnel then
		-- the shortcut's dashes
		for _, s in L.trail do
			if s.branch then
				band(trail, L, U, s.x1 + (s.x2 - s.x1) * 0.4, s.y1 + (s.y2 - s.y1) * 0.4, s.x1 + (s.x2 - s.x1) * 0.6, s.y1 + (s.y2 - s.y1) * 0.6, 0.16, C.coral, 3, "Dash")
			end
		end
	end
	for _, r in L.rivers do
		local pts = r.points
		local depth = L.landDepth
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			if depth(a[1], a[2]) > -0.05 or depth(b[1], b[2]) > -0.05 then
				band(trail, L, U, a[1], a[2], b[1], b[2], 1.15, Util.shade(col.shallows, -0.3), 4, "RiverBank")
			end
		end
		for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
			if e[1] == "pond" then
				disc(trail, L, U, e[2][1], e[2][2], 0.85, Util.shade(col.shallows, -0.3), 4, "PondEdge")
			end
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2], b[1], b[2], 0.95, col.shallows, 5, "River")
		end
		for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
			if e[1] == "pond" then
				disc(trail, L, U, e[2][1], e[2][2], 0.75, col.shallows, 5, "Pond")
			end
		end
	end
	-- lava streams (Mount Kaboom): a glowing band with a dark crust, pooling at the ends
	for _, r in L.lava or {} do
		local pts = r.points
		local lava = col.lava or C.coral
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2], b[1], b[2], 1.2, Util.shade(lava, -0.4), 4, "LavaBank")
		end
		for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
			if e[1] == "pond" then
				disc(trail, L, U, e[2][1], e[2][2], 0.9, Util.shade(lava, -0.4), 4, "LavaPoolEdge")
			end
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2], b[1], b[2], 1.0, lava, 5, "Lava")
		end
		for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
			if e[1] == "pond" then
				disc(trail, L, U, e[2][1], e[2][2], 0.8, lava, 5, "LavaPool")
			end
		end
		-- its hottest line down the middle
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2], b[1], b[2], 0.34, col.lavaGlow or C.sun, 6, "LavaGlow")
		end
	end
	local pfill = BoardLayout.fillets(L.pools, 0.5, { 0.1, 0 })
	smooth(trail, L, U, L.pools, pfill[1], 0.1, Util.shade(col.pool or C.lime, -0.3), 7, "PoolEdge")
	smooth(trail, L, U, L.pools, pfill[2], 0, col.pool or C.lime, 8, "Pool")
	for i, p in L.pools do
		if i % 2 == 0 then
			local ring = disc(trail, L, U, p.x + p.r * 0.45, p.y - p.r * 0.35, 0.16, C.white, 9, "Bubble")
			ring.BackgroundTransparency = 1
			Util.stroke(ring, Util.shade(col.pool or C.lime, 0.5), 0.05 * U)
		end
	end

	-- props: the flat ones on the ground, the rest standing up (lower ones in front)
	local order = {}
	for _, p in L.props do
		table.insert(order, p)
	end
	table.sort(order, function(a, b)
		if (a.ground == true) ~= (b.ground == true) then
			return a.ground == true
		end
		return a.y < b.y
	end)
	for i, p in order do
		prop(if p.ground then trail else layers.Props, L, U, p, if p.ground then 20 + i else i)
	end
end

return MapArt
