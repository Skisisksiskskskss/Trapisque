--[[
	MapArt
	Paints a map's scene (BoardLayout) under the tiles, seen the way the props and the
	pieces are: a little from above and in front, lit from the upper left. The land is a
	slab: its top (with a light lip along the edges that face the light), its side (a
	band of cliff under every edge that faces you, darker at the foot) and foam where it
	meets the water, which is lighter in the shallows around it. The trail is worn into
	the ground (its far bank in shadow), and so are the rivers, the lava streams and the
	slime pools. Soft patches of lighter and darker ground and little things lying about
	(tufts, pebbles, shells...) keep the land from being one flat colour; then the props.

	The soft shapes and the little things are sprites (Art); without the art sheets the
	shallows are a plain band and the rest is left out. Every shape is a union of discs
	(BoardLayout.fillets rounds the corners where they meet); the copies drawn under the
	ground that it hides completely are skipped.

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

local CLIFF = 0.55 -- how tall the land's side is (map units)
local LIP_X, LIP_Y = -0.06, -0.08 -- the lit lip: the ground's edge, nudged toward the light
local SUNK = 0.05 -- how far the trail and the rivers sit below the ground

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

-- A sprite from the art sheets (one ImageLabel), its canvas `size` map units across,
-- centred on (x, y), tinted.
local function sprite(parent: Instance, L, U: number, name: string, x: number, y: number, size: number, z: number, tint: Color3?, transparency: number?, flip: boolean?): ImageLabel?
	return Art.label(parent, name, Vector2.new((x - L.x0) * U, (y - L.y0) * U), size * U, flip, {
		ImageColor3 = tint or Color3.new(1, 1, 1),
		ImageTransparency = transparency or 0,
		ZIndex = z,
	})
end
MapArt.sprite = sprite

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

-- "Is (x, y) on the ground?", quickly: the ground's discs bucketed by where they are.
-- `pad`: at least that far inside a disc; a disc marked `gone` doesn't count.
local function groundOf(discs: { any }): (number, number, number?) -> boolean
	local CELL = 2
	local grid: { [number]: { any } } = {}
	local function key(gx: number, gy: number): number
		return (gx + 4096) * 8192 + gy + 4096
	end
	for _, c in discs do
		for gx = math.floor((c.x - c.r) / CELL), math.floor((c.x + c.r) / CELL) do
			for gy = math.floor((c.y - c.r) / CELL), math.floor((c.y + c.r) / CELL) do
				local k = key(gx, gy)
				local list = grid[k]
				if not list then
					list = {}
					grid[k] = list
				end
				table.insert(list, c)
			end
		end
	end
	return function(x: number, y: number, pad: number?): boolean
		local list = grid[key(math.floor(x / CELL), math.floor(y / CELL))]
		if list then
			for _, c in list do
				local rr = c.r - (pad or 0)
				if not c.gone and rr > 0 and (x - c.x) ^ 2 + (y - c.y) ^ 2 <= rr * rr then
					return true
				end
			end
		end
		return false
	end
end

-- Is the whole disc of radius r at (x, y) under the ground? (Its middle and points all
-- round just outside its edge are, close enough together that no part of it showing
-- could slip between them.)
local function under(onGround: (number, number, number?) -> boolean, x: number, y: number, r: number): boolean
	if not onGround(x, y) then
		return false
	end
	local n = math.max(24, math.ceil(2 * math.pi * r / 0.3))
	for k = 0, n - 1 do
		local a = k * 2 * math.pi / n
		if not onGround(x + math.cos(a) * (r + 0.1), y + math.sin(a) * (r + 0.1)) then
			return false
		end
	end
	return true
end

-- One layer of a shape made of discs: every disc (and the fill discs that round off the
-- corners where they meet) grown by `grow` and moved by (ox, oy). With `onGround`, a disc
-- the ground covers completely is left out.
local function layer(parent: Instance, L, U: number, discs, fill, grow: number, ox: number, oy: number, color: Color3, z: number, name: string, onGround: ((number, number, number?) -> boolean)?)
	for _, list in { discs, fill } do
		for _, c in list do
			local r = c.r + (if list == discs then grow else 0)
			local x, y = c.x + ox, c.y + oy
			if not (onGround and under(onGround, x, y, r)) then
				disc(parent, L, U, x, y, r, color, z, name)
			end
		end
	end
end

-- A stream (river or lava) cut into the ground: its banks, then what runs in it, sunk a
-- little so the far bank shows.
local function stream(parent: Instance, L, U: number, r, bank: Color3, fill: Color3, wBank: number, wFill: number, z: number, name: string, onLand: ((number, number) -> boolean)?)
	local pts = r.points
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if not onLand or onLand(a[1], a[2]) or onLand(b[1], b[2]) then
			band(parent, L, U, a[1], a[2], b[1], b[2], wBank, bank, z, name .. "Bank")
		end
	end
	for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
		if e[1] == "pond" then
			disc(parent, L, U, e[2][1], e[2][2], 0.85 + (wBank - 1.15) / 2, bank, z, name .. "PondBank")
		end
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		band(parent, L, U, a[1], a[2] + SUNK * 2, b[1], b[2] + SUNK * 2, wFill, fill, z + 1, name)
	end
	for _, e in { { r.endA, pts[1] }, { r.endB, pts[#pts] } } do
		if e[1] == "pond" then
			disc(parent, L, U, e[2][1], e[2][2] + SUNK * 2, 0.75 + (wFill - 0.95) / 2, fill, z + 1, name .. "Pond")
		end
	end
end

function MapArt.draw(layers: { [string]: Frame }, L, U: number)
	local scene = L.scene
	local col = {}
	for k, v in scene.colors do
		col[k] = hex(string.sub(v, 2))
	end
	local ground = col.land
	local soft = Art.has("ground/soft")
	local depth = L.landDepth
	-- what the camera can see (the tiles and a margin), and how far past it to bother
	local tb = L.tileBounds
	local function nearView(x: number, y: number, pad: number): boolean
		return x > tb.x0 - pad and x < tb.x1 + pad and y > tb.y0 - pad and y < tb.y1 + pad
	end

	-- the land's discs: the ones the others already cover are left out (the same shape,
	-- far fewer frames), smallest first. A disc goes only when its whole edge and a grid
	-- over it are well inside the discs that stay: every point of it is within
	-- STEP / sqrt(2) of a sample at least PAD inside one, so no pinhole opens where it was.
	local fill = BoardLayout.fillets(L.land, 1.1, { 0.16, 0.05, 0 })
	local all = {}
	for _, list in { L.land, fill[3] } do
		for _, c in list do
			table.insert(all, { x = c.x, y = c.y, r = c.r, fillet = list ~= L.land })
		end
	end
	local onGround = groundOf(all)
	local smallest = table.clone(all)
	table.sort(smallest, function(a, b)
		return a.r < b.r
	end)
	local STEP, PAD = 0.3, 0.22
	for _, c in smallest do
		c.gone = true
		local covered = true
		local n = math.max(12, math.ceil(2 * math.pi * c.r / STEP))
		for k = 0, n - 1 do
			local a = k * 2 * math.pi / n
			if not onGround(c.x + math.cos(a) * c.r, c.y + math.sin(a) * c.r, PAD) then
				covered = false
				break
			end
		end
		local reach = c.r + PAD
		local gy = c.y - reach
		while covered and gy <= c.y + reach do
			local gx = c.x - reach
			while gx <= c.x + reach do
				if (gx - c.x) ^ 2 + (gy - c.y) ^ 2 <= reach * reach and not onGround(gx, gy, PAD) then
					covered = false
					break
				end
				gx += STEP
			end
			gy += STEP
		end
		c.gone = covered
	end
	local discs, fillets = {}, {}
	for _, c in all do
		if not c.gone then
			table.insert(if c.fillet then fillets else discs, c)
		end
	end

	-- the water, far past the edges of the map, darker further out, with a few swells
	Util.new("Frame", {
		Name = "Water",
		BackgroundColor3 = col.water,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(L.w * U, L.h * U),
		ZIndex = 1,
		Parent = layers.Water,
	})
	if soft then
		-- deeper further out: soft darker spots wherever the sea is far from the land
		local deep = Util.shade(col.water, -0.25)
		for gy = tb.y0 - 6, tb.y1 + 6, 5 do
			for gx = tb.x0 - 6, tb.x1 + 6, 5 do
				if depth(gx, gy) < -4 then
					sprite(layers.Water, L, U, "ground/soft", gx, gy, 13, 2, deep, 0.4)
				end
			end
		end
	end
	for _, w in L.waves do
		if nearView(w.x, w.y, 1) then
			sprite(layers.Water, L, U, "ground/wave", w.x, w.y, w.w * 1.1, 3, Util.shade(col.shallows, 0.3), 0.6)
		end
	end

	-- the shallows: a soft light glow around the land (around its foot, under the cliff)
	local land = layers.Land
	if soft then
		for _, c in discs do
			local x, y, r = c.x, c.y + CLIFF * 0.6, c.r + 1.8
			if nearView(x, y, r) and not under(onGround, x, y, c.r + 1.1) then
				sprite(land, L, U, "ground/soft", x, y, 2 * r, 1, col.shallows, 0.3)
			end
		end
	else
		local shallows = {}
		for i, c in L.land do
			shallows[i] = { x = c.x, y = c.y + CLIFF, r = c.r + 0.75 }
		end
		layer(land, L, U, shallows, BoardLayout.fillets(shallows, 0.6, { 0 }, 1.6)[1], 0, 0, 0, col.shallows, 1, "Shallows")
	end

	-- the land: foam at the waterline, the waterline itself, the cliff (darker at its
	-- foot), the lit lip, then the ground on top
	local foam = col.foam or Util.mix(col.shallows, C.white, 0.75)
	local cliff = col.cliff or Util.shade(ground, -0.2)
	layer(land, L, U, discs, fill[1], 0.16, 0, CLIFF, foam, 2, "Foam", onGround)
	layer(land, L, U, discs, fill[2], 0.05, 0, CLIFF, col.cliffLine or Util.shade(cliff, -0.5), 3, "Waterline", onGround)
	layer(land, L, U, discs, fillets, 0, 0, CLIFF, col.cliffDark or Util.shade(cliff, -0.2), 4, "CliffFoot", onGround)
	layer(land, L, U, discs, fillets, 0, 0, CLIFF * 0.45, cliff, 5, "Cliff", onGround)
	layer(land, L, U, discs, fillets, 0, LIP_X, LIP_Y, col.lip or Util.shade(ground, 0.25), 6, "Lip", onGround)
	layer(land, L, U, discs, fillets, 0, 0, 0, ground, 7, "Ground")

	-- soft patches of lighter and darker ground, and the little things lying about
	local M = scene.mottle
	if soft and M then
		local light, dark = hex(string.sub(M.light, 2)), hex(string.sub(M.dark, 2))
		for _, m in L.mottle do
			sprite(land, L, U, "ground/soft", m.x, m.y, 2 * m.r, 8, if m.light then light else dark, 0.45)
		end
	end
	local tints = (scene.details and scene.details.tint) or {}
	for _, d in L.details do
		local tint = tints[d.kind]
		sprite(land, L, U, "ground/" .. d.kind, d.x, d.y, d.size, 9, if tint then hex(string.sub(tint, 2)) else nil, 0)
	end

	-- the trail, worn into the ground: a soft edge, the far bank in shadow, the path (a
	-- shortcut runs through a dark tunnel), then what's on it
	local trail = layers.Trail
	local W = S.trailW
	local edge = Util.mix(ground, Util.shade(col.trail, -0.2), 0.5)
	for _, s in L.trail do
		band(trail, L, U, s.x1, s.y1, s.x2, s.y2, W + 0.14, edge, 1, "TrailEdge")
	end
	for _, s in L.trail do
		local c = if s.branch and col.tunnel then col.tunnel else col.trail
		band(trail, L, U, s.x1, s.y1, s.x2, s.y2, W, Util.shade(c, -0.3), 2, "TrailBank")
	end
	for _, s in L.trail do
		local c = if s.branch and col.tunnel then col.tunnel else col.trail
		band(trail, L, U, s.x1, s.y1 + SUNK, s.x2, s.y2 + SUNK, W - 2 * SUNK, c, 3, if s.branch then "Tunnel" else "Trail")
	end
	if col.trailMark then
		-- boardwalk planks
		for _, s in L.trail do
			local dx, dy = s.x2 - s.x1, s.y2 - s.y1
			local len = math.sqrt(dx * dx + dy * dy)
			local nx, ny = -dy / len, dx / len
			for _, f in { 0.36, 0.64 } do
				local mx, my = s.x1 + dx * f, s.y1 + dy * f + SUNK
				band(trail, L, U, mx - nx * W * 0.4, my - ny * W * 0.4, mx + nx * W * 0.4, my + ny * W * 0.4, 0.07, col.trailMark, 4, "Plank")
			end
		end
	end
	if col.tunnel then
		-- the shortcut's dashes
		for _, s in L.trail do
			if s.branch then
				band(trail, L, U, s.x1 + (s.x2 - s.x1) * 0.4, s.y1 + (s.y2 - s.y1) * 0.4 + SUNK, s.x1 + (s.x2 - s.x1) * 0.6, s.y1 + (s.y2 - s.y1) * 0.6 + SUNK, 0.16, C.coral, 4, "Dash")
			end
		end
	end

	-- rivers and lava streams, cut into the ground the same way (lava glows on the
	-- ground around it)
	local function onLand(x: number, y: number): boolean
		return depth(x, y) > -0.05
	end
	for _, r in L.rivers do
		stream(trail, L, U, r, Util.shade(col.shallows, -0.45), col.shallows, 1.2, 0.98, 5, "River", onLand)
	end
	local lava = col.lava or C.coral
	for _, r in L.lava or {} do
		if soft then
			for i = 1, #r.points, 2 do
				local q = r.points[i]
				sprite(trail, L, U, "ground/soft", q[1], q[2], 2.8, 4, lava, 0.6)
			end
		end
		stream(trail, L, U, r, Util.shade(lava, -0.55), lava, 1.3, 1.02, 5, "Lava")
		-- its hottest line down the middle
		local pts = r.points
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			band(trail, L, U, a[1], a[2] + SUNK * 2, b[1], b[2] + SUNK * 2, 0.36, col.lavaGlow or C.sun, 7, "LavaGlow")
		end
	end

	-- slime pools: a muddy bank, the slime sunk inside it, a few bubbles
	local pool = col.pool or C.lime
	local pfill = BoardLayout.fillets(L.pools, 0.5, { 0.12, 0 })
	layer(trail, L, U, L.pools, pfill[1], 0.12, 0, 0, Util.shade(pool, -0.5), 8, "PoolBank")
	layer(trail, L, U, L.pools, pfill[2], 0, 0, SUNK * 2, pool, 9, "Pool")
	for i, p in L.pools do
		if i % 2 == 0 then
			local ring = disc(trail, L, U, p.x + p.r * 0.45, p.y - p.r * 0.35 + SUNK * 2, 0.16, C.white, 10, "Bubble")
			ring.BackgroundTransparency = 1
			Util.stroke(ring, Util.shade(pool, 0.5), 0.05 * U)
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
