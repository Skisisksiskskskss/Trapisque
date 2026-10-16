--[[
	MapArt
	Paints a map's scene (BoardLayout) under the tiles: the open water with its wave
	marks, the land the trail runs through (shallows, an inked coast, beach, inner
	ground), the trail itself, rivers / tunnels / slime pools, and the props. Flat inks
	and one heavy ink line, like the rest of the game.

		MapArt.draw(layers, layout, U)   -- layers = { Water, Land, Trail, Props }
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local MapProps = require(UI.MapProps)
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

-- A prop: its sticker on a square holder standing at (x, y).
local function prop(parent: Instance, L, U: number, p, z: number)
	local art = MapProps[p.kind]
	if not art then
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
	local ops = art
	if p.flip then
		ops = { { "group", fx = true, ops = art } }
	end
	Icons.sticker(holder, ops, nil, Icons.OUTLINE)
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
	for _, w in L.waves do
		local holder = Util.frame(layers.Water, {
			Name = "Wave",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((w.x - L.x0) * U, (w.y - L.y0) * U),
			Size = UDim2.fromOffset(w.w * U, w.w * U),
			ZIndex = 2,
		})
		Shapes.wave(Shapes.canvas(holder), 0.5, 0.5, 1, 0.09, col.waterMark)
	end
	water.Name = "Water"

	-- the land: shallows, the inked coast, the ground, the inner ground with its own line
	local land = layers.Land
	for _, c in L.land do
		disc(land, L, U, c.x, c.y, c.r + 0.75, col.shallows, 1, "Shallows")
	end
	for _, c in L.land do
		disc(land, L, U, c.x, c.y, c.r + 0.1, C.line, 2, "Coast")
	end
	for _, c in L.land do
		disc(land, L, U, c.x, c.y, c.r, col.land, 3, "Ground")
	end
	for _, c in L.land do
		if c.inner and c.inner > 0.3 then
			disc(land, L, U, c.x, c.y, c.inner + 0.07, C.line, 4, "InnerEdge")
		end
	end
	for _, c in L.land do
		if c.inner and c.inner > 0.3 then
			disc(land, L, U, c.x, c.y, c.inner, col.inner, 5, "Inner")
		end
	end

	-- patches of jungle, rock or moss, away from the trail
	for _, c in L.patches or {} do
		disc(land, L, U, c.x, c.y, c.r + 0.07, C.line, 6, "PatchEdge")
	end
	for _, c in L.patches or {} do
		disc(land, L, U, c.x, c.y, c.r, col.inner, 7, "Patch")
	end

	-- the trail (a shortcut runs through a dark tunnel), then what crosses it
	local trail = layers.Trail
	local W = S.trailW
	for _, s in L.trail do
		band(trail, L, U, s.x1, s.y1, s.x2, s.y2, W + 0.2, C.line, 1, "TrailEdge")
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
				band(trail, L, U, a[1], a[2], b[1], b[2], 1.15, C.line, 4, "RiverBank")
			end
		end
		for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
			if e[1] == "pond" then
				disc(trail, L, U, e[2][1], e[2][2], 0.85, C.line, 4, "PondEdge")
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
		for i = 3, #pts - 2, 4 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2], a[1] + (b[1] - a[1]) * 0.6, a[2] + (b[2] - a[2]) * 0.6, 0.12, C.white, 6, "Ripple")
		end
	end
	for _, p in L.pools do
		disc(trail, L, U, p.x, p.y, p.r + 0.1, C.line, 7, "PoolEdge")
	end
	for _, p in L.pools do
		disc(trail, L, U, p.x, p.y, p.r, col.pool or C.lime, 8, "Pool")
	end
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
