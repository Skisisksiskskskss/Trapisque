--[[
	MapArt
	Paints a map's scene (BoardLayout) under the tiles, seen a little from the side the
	way the props and the pieces are: the ground is squashed top to bottom
	(BoardLayout.Style.squash), so what lies on it (the land, the trail, a pool) is
	foreshortened and anything round on it is an ellipse, while what stands (a prop, the
	land's cliff) stands straight up, a prop's foot on its spot.

	The land is a slab: its top, with a light lip along the edges that face the light
	(upper left); its side, a band of cliff under every edge that faces you, darker at its
	foot; a waterline and foam where it meets the sea, which is lighter in the shallows.
	The trail is worn into the ground (its far bank in shadow). Rivers, lava streams and
	slime pools are cut into the ground the way the coast is: a low bank in the land's
	own cliff colours along the far side, foam (or a dark crust) where it meets the water,
	the lit lip of the near side; a river that reaches the coast pours off the cliff. Soft
	patches of lighter and darker ground and a few little things lying about (tufts,
	pebbles...) keep the land from being one colour; then the props.

	Ellipses and rounded squares are white sprites stretched and tinted (Art); without the
	art sheets they're rounded frames, the shallows are a plain band and the soft patches
	and little things are left out. Every shape on the ground is a union of discs
	(BoardLayout.fillets rounds the corners where they meet); copies the ground hides
	completely are left out.

		MapArt.draw(layers, layout, U)          -- layers = { Water, Land, Trail, Props }
		MapArt.project(layout, U, x, y)         -- map units -> world pixels
		MapArt.ellipse / roundRect / strip      -- the shapes (BoardView's tiles use them too)
		MapArt.propCenter(layout, U, prop)      -- the middle of a prop as it stands
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
local K = S.squash

local MapArt = {}

local CLIFF = 0.5 -- how tall the land's side looks (map units, on screen)
local LIP_X, LIP_Y = -0.06, -0.07 -- the lit lip: the ground's edge, nudged toward the light
local SUNK = 0.05 -- how far the trail sits below the ground
local FOOT = 0.92 -- a standing prop's foot, down its canvas
local FLAT = { pebbles = true, shell = true, leaves = true } -- little things that lie flat

-- Map units -> world pixels.
local function project(L, U: number, x: number, y: number): Vector2
	return Vector2.new((x - L.x0) * U, (y - L.y0) * U * K)
end
MapArt.project = project

-- An ellipse w x h pixels centred on `at`: the white disc stretched and tinted (or a
-- rounded frame, a pill when it isn't round).
local function ellipse(parent: Instance, at: Vector2, w: number, h: number, color: Color3, z: number, name: string?, transparency: number?): GuiObject
	local img = Art.label(parent, "ground/disc", at, Vector2.new(w, h), false, {
		Name = name or "Disc",
		ImageColor3 = color,
		ImageTransparency = transparency or 0,
		ZIndex = z,
	})
	if img then
		return img
	end
	local f = Util.new("Frame", {
		Name = name or "Disc",
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z,
		Parent = parent,
	})
	Util.corner(f, 0.5)
	return f
end
MapArt.ellipse = ellipse

-- A rounded square stretched to w x h pixels (a slab's top, seen from the side).
local function roundRect(parent: Instance, at: Vector2, w: number, h: number, color: Color3, z: number, name: string?, transparency: number?): GuiObject
	local img = Art.label(parent, "ground/rsq", at, Vector2.new(w, h), false, {
		Name = name or "Slab",
		ImageColor3 = color,
		ImageTransparency = transparency or 0,
		ZIndex = z,
	})
	if img then
		return img
	end
	local f = Util.new("Frame", {
		Name = name or "Slab",
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z,
		Parent = parent,
	})
	Util.corner(f, math.floor(0.22 * math.min(w, h) + 0.5))
	return f
end
MapArt.roundRect = roundRect

-- A straight strip `width` pixels wide from a to b (pixels), square at both ends
-- (`over` pixels longer at each, to run into its neighbours).
local function strip(parent: Instance, a: Vector2, b: Vector2, width: number, color: Color3, z: number, name: string?, over: number?): Frame
	local d = b - a
	return Util.new("Frame", {
		Name = name or "Strip",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude + 2 * (over or 0), width),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		ZIndex = z,
		Parent = parent,
	})
end
MapArt.strip = strip

-- How wide a band `w` across lying on the ground looks, running from (x1, y1) to (x2, y2).
local function across(w: number, x1: number, y1: number, x2: number, y2: number): number
	local ux, uy = x2 - x1, y2 - y1
	local len = math.sqrt(ux * ux + uy * uy)
	if len < 1e-6 then
		return w
	end
	ux, uy = ux / len, uy / len
	return w * K / math.sqrt(ux * ux + K * K * uy * uy)
end

-- A disc lying on the ground (an ellipse on screen), nudged (dx, dy) on screen.
local function disc(parent: Instance, L, U: number, x: number, y: number, r: number, color: Color3, z: number, name: string?, dx: number?, dy: number?): GuiObject
	local at = project(L, U, x, y) + Vector2.new(dx or 0, dy or 0) * U
	return ellipse(parent, at, 2 * r * U, 2 * r * U * K, color, z, name)
end
MapArt.disc = disc

-- A band `w` wide lying along segments { x1, y1, x2, y2 } (a path, round at every end):
-- a strip down each segment, an ellipse at each end. dy nudges it down the screen.
local function path(parent: Instance, L, U: number, segs, w: number, color: Color3, z: number, name: string, dy: number?)
	local off = Vector2.new(0, (dy or 0) * U)
	local ends = {}
	for _, s in segs do
		local a, b = project(L, U, s.x1, s.y1) + off, project(L, U, s.x2, s.y2) + off
		strip(parent, a, b, across(w, s.x1, s.y1, s.x2, s.y2) * U, color, z, name)
		for _, p in { a, b } do
			ends[math.floor(p.X + 0.5) .. ":" .. math.floor(p.Y + 0.5)] = p
		end
	end
	for _, p in ends do
		ellipse(parent, p, w * U, w * U * K, color, z, name)
	end
end

-- A sprite (one ImageLabel), its canvas `size` map units across, centred on the spot
-- (x, y); a `flat` one lies on the ground (squashed like it).
local function sprite(parent: Instance, L, U: number, name: string, x: number, y: number, size: number, z: number, tint: Color3?, transparency: number?, flat: boolean?): ImageLabel?
	local px = size * U
	return Art.label(parent, name, project(L, U, x, y), if flat then Vector2.new(px, px * K) else px, false, {
		ImageColor3 = tint or Color3.new(1, 1, 1),
		ImageTransparency = transparency or 0,
		ZIndex = z,
	})
end
MapArt.sprite = sprite

-- The middle of a prop as it's drawn: a standing one's canvas reaches up from its foot.
function MapArt.propCenter(L, U: number, p): Vector2
	local at = project(L, U, p.x, p.y)
	if p.ground then
		return at
	end
	return at - Vector2.new(0, (FOOT - 0.5) * p.size * U)
end

-- A prop: one that stands has its foot (near the bottom of its canvas) on its spot; one
-- that lies flat (the dock) is stretched along its length the way the ground is. Its
-- illustration (the one for standing in the water, if it has one), or its sticker.
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
	local at = MapArt.propCenter(L, U, p)
	if p.ground then
		local a = math.rad(p.angle or 0)
		local ux, uy = math.cos(a), math.sin(a)
		local long = math.sqrt(ux * ux + K * K * uy * uy)
		if Art.label(parent, name, at, Vector2.new(size * long, size * K / long), false, {
			Name = "Prop_" .. p.kind,
			Rotation = math.deg(math.atan2(uy * K, ux)),
			ZIndex = z,
		}) then
			return
		end
	elseif Art.label(parent, name, at, size, false, { Name = "Prop_" .. p.kind, ZIndex = z }) then
		return
	end
	if not art then
		return
	end
	local holder = Util.frame(parent, {
		Name = "Prop_" .. p.kind,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size, if p.ground then size * K else size),
		Rotation = if p.ground and p.angle then p.angle else 0,
		ZIndex = z,
	})
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
-- corners where they meet) grown by `grow` and nudged (dx, dy) on screen. With
-- `onGround`, a disc the ground covers completely is left out.
local function layer(parent: Instance, L, U: number, discs, fill, grow: number, dx: number, dy: number, color: Color3, z: number, name: string, onGround: ((number, number, number?) -> boolean)?)
	for _, list in { discs, fill } do
		for _, c in list do
			local r = c.r + (if list == discs then grow else 0)
			-- (a nudge down the screen is a longer one on the squashed ground)
			if not (onGround and under(onGround, c.x + dx, c.y + dy / K, r)) then
				disc(parent, L, U, c.x, c.y, r, color, z, name, dx, dy)
			end
		end
	end
end

-- How a bank cut into the ground is drawn, top to bottom: the near side's lit lip
-- (showing past the cut's lower right), the cut itself (the far side's bank), the line
-- where it meets the water, the water. { grow, dx, dy } per layer.
local CUT = {
	lip = { 0.08, 0.06, 0.07 },
	bank = { 0.08, 0, 0 },
	edge = { -0.06, 0, 0.1 },
	fill = { -0.1, 0, 0.12 },
}

-- A river or lava stream, cut into the ground like the coast: narrow where it rises,
-- wider toward the sea, its banks never quite straight; an inland end is a small lake.
-- Where it reaches the coast it runs on into the sea, or pours off the cliff where the
-- cliff faces you. Lava runs hotter toward its middle, with bits of crust riding on it.
local function stream(parent: Instance, L, U: number, r, look, z: number, name: string, depth: (number, number) -> number, seed: number)
	local pts = r.points
	if #pts < 2 then
		return
	end
	local lens = { 0 }
	for i = 2, #pts do
		lens[i] = lens[i - 1] + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2)
	end
	local total = lens[#pts]
	if total < 1e-6 then
		return
	end
	-- the path every 0.3, with its width there
	local samples = {}
	local j = 1
	local d = 0
	while d <= total + 1e-6 do
		while j < #pts - 1 and lens[j + 1] < d do
			j += 1
		end
		local seg = math.max(1e-6, lens[j + 1] - lens[j])
		local t = math.clamp((d - lens[j]) / seg, 0, 1)
		local ax, ay, bx, by = pts[j][1], pts[j][2], pts[j + 1][1], pts[j + 1][2]
		local open = 0
		if r.endA == "sea" then
			open = math.max(open, 1 - d / total)
		end
		if r.endB == "sea" then
			open = math.max(open, d / total)
		end
		local x, y = ax + (bx - ax) * t, ay + (by - ay) * t
		table.insert(samples, {
			x = x,
			y = y,
			r = look.width + 0.2 * open * open + 0.035 * math.sin(d * 2.3 + seed),
			nx = -(by - ay) / seg,
			ny = (bx - ax) / seg,
			land = depth(x, y) > -0.02,
		})
		d += 0.3
	end
	-- the stretch on land (an end out at sea runs on into the sea, or pours off the cliff)
	local first, last
	for i, q in samples do
		if q.land then
			first = first or i
			last = i
		end
	end
	if not first or not last then
		return
	end
	-- where it reaches the sea its banks stop short of the coast, so the water runs on
	-- out into the sea (its bed only, no bank closing it off)
	local open = {}
	local reach = math.ceil((look.width + 0.25) / 0.3)
	if r.endA == "sea" then
		for i = first, math.min(last, first + reach - 1) do
			open[i] = true
		end
	end
	if r.endB == "sea" then
		for i = math.max(first, last - reach + 1), last do
			open[i] = true
		end
	end
	local discs, banked = {}, {}
	for i = first, last do
		if samples[i].land then
			table.insert(discs, samples[i])
			if not open[i] then
				table.insert(banked, samples[i])
			end
		end
	end
	local soft = Art.has("ground/soft")
	local ends = {
		{ kind = r.endA, point = pts[1], at = samples[first], from = samples[first + 1], sea = {}, inward = 1 },
		{ kind = r.endB, point = pts[#pts], at = samples[last], from = samples[last - 1], sea = {}, inward = -1 },
	}
	-- the samples out at sea, nearest the coast first
	for i = first - 1, 1, -1 do
		table.insert(ends[1].sea, samples[i])
	end
	for i = last + 1, #samples do
		table.insert(ends[2].sea, samples[i])
	end
	for k, e in ends do
		if e.kind == "pond" and look.vent then
			-- lava wells up from a vent: a cone of dark rock, glowing at its mouth, smoking
			local x, y = e.point[1], e.point[2]
			if soft then
				sprite(parent, L, U, "ground/soft", x, y, 3.2, z + 1, look.core, 0.55, true)
			end
			disc(parent, L, U, x + 0.05, y + 0.12, 0.92, look.bank, z + 2, name .. "VentFoot")
			disc(parent, L, U, x, y, 0.82, look.vent, z + 3, name .. "Vent")
			disc(parent, L, U, x - 0.08, y - 0.1, 0.62, Util.shade(look.vent, 0.18), z + 4, name .. "VentLip")
			disc(parent, L, U, x, y, 0.46, look.edge, z + 5, name .. "VentRim")
			disc(parent, L, U, x, y + 0.02, 0.38, look.fill, z + 6, name .. "VentLava", 0, 0.04)
			disc(parent, L, U, x - 0.04, y, 0.22, look.core, z + 7, name .. "VentHeart", 0, 0.04)
			if soft and look.steam then
				for n, o in { { 0.1, -0.9, 1.3 }, { -0.2, -1.6, 1.7 }, { 0.25, -2.3, 2.0 } } do
					sprite(parent, L, U, "ground/soft", x + o[1], y + o[2], o[3], z + 9, Util.shade(look.vent, 0.5), 0.45 + n * 0.12)
				end
			end
		elseif e.kind == "pond" then
			-- a small lake
			local x, y = e.point[1], e.point[2]
			for _, o in { { 0, 0, 0.72 }, { 0.48, 0.16, 0.52 }, { -0.4, 0.24, 0.48 }, { 0.1 * k, -0.34, 0.44 } } do
				local c = { x = x + o[1], y = y + o[2], r = o[3] }
				table.insert(discs, c)
				table.insert(banked, c)
			end
		elseif e.kind == "sea" and e.from and look.cooled then
			-- lava meeting the sea: it cools into a shelf of dark rock, steaming
			local m = e.at
			for n, q in e.sea do
				if n > 4 then
					break
				end
				local rr = (q.r + CUT.fill[1]) * (1.05 - n * 0.16)
				disc(parent, L, U, q.x, q.y, rr + 0.08, Util.shade(look.cooled, -0.3), z + 1, name .. "Shelf", 0, CUT.fill[3] + 0.04)
				disc(parent, L, U, q.x, q.y, rr, look.cooled, z + 2, name .. "Shelf", 0, CUT.fill[3])
			end
			if soft then
				sprite(parent, L, U, "ground/soft", m.x, m.y, 1.6, z + 8, look.core, 0.45, true)
				for n, o in { { 0, -0.6, 1.6 }, { -0.35, -1.3, 2.1 }, { 0.3, -2.0, 2.5 } } do
					sprite(parent, L, U, "ground/soft", m.x + o[1], m.y + o[2], o[3], z + 9, look.steam, 0.3 + n * 0.12)
				end
			end
		elseif e.kind == "sea" and e.from then
			local m = e.at
			local hx, hy = m.x - e.from.x, m.y - e.from.y
			local len = math.sqrt(hx * hx + hy * hy)
			local top = project(L, U, m.x, m.y) + Vector2.new(0, CUT.fill[3] * U)
			if len > 1e-6 and hy / len > 0.3 then
				-- the cliff faces you: it pours down it, white water at its foot
				local w = 2 * (m.r + CUT.fill[1]) * U * 0.9
				local drop = (math.max(0, depth(m.x, m.y)) * K + CLIFF + 0.05) * U
				local fall = Util.new("Frame", {
					Name = name .. "Fall",
					BackgroundColor3 = look.fill,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(top.X, top.Y - 0.1 * U),
					Size = UDim2.fromOffset(w, drop + 0.1 * U),
					ZIndex = z + 6,
					Parent = parent,
				})
				Util.corner(fall, math.floor(w * 0.2))
				Util.grad(fall, { Color3.new(1, 1, 1), Util.mix(Color3.new(1, 1, 1), look.splash, 0.3) }, 90)
				for n = 1, 3 do
					local streak = Util.new("Frame", {
						Name = name .. "Streak",
						BackgroundColor3 = look.splash,
						BackgroundTransparency = 0.35,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromOffset(top.X + (n - 2) * w * 0.28, top.Y + drop * (0.1 + 0.15 * n)),
						Size = UDim2.fromOffset(math.max(2, w * 0.07), drop * 0.55),
						ZIndex = z + 7,
						Parent = parent,
					})
					Util.corner(streak, 0.5)
				end
				if soft then
					sprite(parent, L, U, "ground/soft", m.x, m.y + (drop / U) / K, 1.9, z + 8, look.splash, 0.15, true)
				else
					ellipse(parent, top + Vector2.new(0, drop), w * 1.5, w * 0.5, look.splash, z + 1, name .. "Splash")
				end
			elseif soft then
				-- it runs on out into the sea, its colour fading into the sea's
				for n, q in e.sea do
					if n > 6 then
						break
					end
					local t = n / 6
					sprite(parent, L, U, "ground/soft", q.x, q.y + CUT.fill[3] / K * 0.5, 2.4 * (q.r + 0.1) * (1 + t * 0.6), z + 1, look.fill, 0.15 + 0.7 * t, true)
				end
			else
				for _, q in e.sea do
					if depth(q.x, q.y) > -0.6 then
						disc(parent, L, U, q.x, q.y, q.r + CUT.fill[1], look.fill, z + 1, name .. "Mouth", 0, CUT.fill[3])
					end
				end
			end
		end
	end
	for i, key in { "lip", "bank", "edge", "fill" } do
		local ly = CUT[key]
		for _, c in (if key == "fill" then discs else banked) do
			disc(parent, L, U, c.x, c.y, c.r + ly[1], look[key], z + 1 + i, name .. (if key == "fill" then "" else key), ly[2], ly[3])
		end
	end
	-- down its middle: deeper water, or lava's hotter heart (which breaks up into seams
	-- here and there, where the crust closes over it)
	local off = Vector2.new(0, CUT.fill[3] * U)
	for _, band in { { look.midWidth or 0.56, look.mid, "Mid", false }, { 0.24, look.core, "Core", true } } do
		if band[2] then
			for i = 1, #samples - 1 do
				local a, b = samples[i], samples[i + 1]
				local showing = not band[4] or math.sin(i * 0.8 + seed) > -0.35
				if a.land and b.land and showing then
					local k = if band[4] then 0.7 + 0.3 * math.sin(i * 1.9 + seed) else 1
					local w = across(2 * (a.r + CUT.fill[1]) * band[1] * k, a.x, a.y, b.x, b.y) * U
					strip(parent, project(L, U, a.x, a.y) + off, project(L, U, b.x, b.y) + off, w, band[2], z + 6, name .. band[3], w * 0.3)
				end
			end
		end
	end
	-- little wave strokes on it, like the sea's, first one side then the other
	if look.ripple then
		for i = 3, #samples - 1, 4 do
			local a = samples[i]
			if a.land then
				local side = ({ 0.4, -0.15, -0.42, 0.1 })[(i // 4) % 4 + 1]
				local w = a.r + CUT.fill[1]
				sprite(parent, L, U, "ground/wave", a.x + a.nx * w * side, a.y + a.ny * w * side - 0.02, 0.42, z + 7, look.ripple, 0.35, true)
			end
		end
	end
	if look.crust then
		-- plates of cooling crust riding on the lava, each with a lighter top
		for i, s in samples do
			if i % 3 == 1 and s.land then
				local side = ({ 0.45, -0.4, 0.1 })[(i // 3) % 3 + 1]
				local w = s.r + CUT.fill[1]
				local size = 0.07 + 0.035 * ((i * 7) % 3)
				local x, y = s.x + s.nx * w * side, s.y + s.ny * w * side
				disc(parent, L, U, x, y, size, look.crust, z + 7, name .. "Crust", 0, CUT.fill[3])
				disc(parent, L, U, x - size * 0.2, y - size * 0.25, size * 0.6, Util.shade(look.crust, 0.18), z + 8, name .. "CrustTop", 0, CUT.fill[3])
			end
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
		return x > tb.x0 - pad and x < tb.x1 + pad and y > tb.y0 - pad - 2 and y < tb.y1 + pad
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
		Size = UDim2.fromOffset(L.w * U, L.h * U * K),
		ZIndex = 1,
		Parent = layers.Water,
	})
	if soft then
		-- deeper further out: soft darker spots wherever the sea is far from the land
		local deep = Util.shade(col.water, -0.25)
		for gy = tb.y0 - 8, tb.y1 + 6, 5 do
			for gx = tb.x0 - 6, tb.x1 + 6, 5 do
				if depth(gx, gy) < -4 then
					sprite(layers.Water, L, U, "ground/soft", gx, gy, 13, 2, deep, 0.4, true)
				end
			end
		end
	end
	for _, w in L.waves do
		if nearView(w.x, w.y, 1) then
			sprite(layers.Water, L, U, "ground/wave", w.x, w.y, w.w * 1.1, 3, Util.shade(col.shallows, 0.3), 0.6, true)
		end
	end

	-- the shallows: a soft light glow around the land (around its foot, under the cliff)
	local land = layers.Land
	if soft then
		for _, c in discs do
			local x, y, r = c.x, c.y + CLIFF * 0.6 / K, c.r + 1.8
			if nearView(x, y, r) and not under(onGround, x, y, c.r + 1.1) then
				sprite(land, L, U, "ground/soft", x, y, 2 * r, 1, col.shallows, 0.3, true)
			end
		end
	else
		local shallows = {}
		for i, c in L.land do
			shallows[i] = { x = c.x, y = c.y + CLIFF / K, r = c.r + 0.75 }
		end
		layer(land, L, U, shallows, BoardLayout.fillets(shallows, 0.6, { 0 }, 1.6)[1], 0, 0, 0, col.shallows, 1, "Shallows")
	end

	-- the land: foam at the waterline, the waterline itself, the cliff (darker at its
	-- foot), the lit lip, then the ground on top
	local foam = col.foam or Util.mix(col.shallows, C.white, 0.75)
	local cliff = col.cliff or Util.shade(ground, -0.2)
	local cliffDark = col.cliffDark or Util.shade(cliff, -0.2)
	local lip = col.lip or Util.shade(ground, 0.25)
	layer(land, L, U, discs, fill[1], 0.16, 0, CLIFF, foam, 2, "Foam", onGround)
	layer(land, L, U, discs, fill[2], 0.05, 0, CLIFF, col.cliffLine or Util.shade(cliff, -0.5), 3, "Waterline", onGround)
	layer(land, L, U, discs, fillets, 0, 0, CLIFF, cliffDark, 4, "CliffFoot", onGround)
	layer(land, L, U, discs, fillets, 0, 0, CLIFF * 0.45, cliff, 5, "Cliff", onGround)
	layer(land, L, U, discs, fillets, 0, LIP_X, LIP_Y, lip, 6, "Lip", onGround)
	layer(land, L, U, discs, fillets, 0, 0, 0, ground, 7, "Ground")

	-- soft patches of lighter and darker ground
	local M = scene.mottle
	if soft and M then
		local light, dark = hex(string.sub(M.light, 2)), hex(string.sub(M.dark, 2))
		for _, m in L.mottle do
			sprite(land, L, U, "ground/soft", m.x, m.y, 2 * m.r, 8, if m.light then light else dark, 0.45, true)
		end
	end

	-- the trail, worn into the ground: a soft edge, the far bank in shadow, the path (a
	-- shortcut runs through a dark tunnel), then what's on it
	local trail = layers.Trail
	local W = S.trailW
	local edge = Util.mix(ground, Util.shade(col.trail, -0.2), 0.5)
	local main, branch = {}, {}
	for _, s in L.trail do
		table.insert(if s.branch and col.tunnel then branch else main, s)
	end
	path(trail, L, U, L.trail, W + 0.14, edge, 1, "TrailEdge")
	path(trail, L, U, main, W, Util.shade(col.trail, -0.3), 2, "TrailBank")
	path(trail, L, U, main, W - 2 * SUNK, col.trail, 3, "Trail", SUNK)
	if #branch > 0 then
		path(trail, L, U, branch, W, Util.shade(col.tunnel, -0.3), 2, "TunnelBank")
		path(trail, L, U, branch, W - 2 * SUNK, col.tunnel, 3, "Tunnel", SUNK)
	end
	local sunk = Vector2.new(0, SUNK * U)
	if col.trailMark then
		-- boardwalk planks, across the path
		for _, s in main do
			local dx, dy = s.x2 - s.x1, s.y2 - s.y1
			local len = math.sqrt(dx * dx + dy * dy)
			local nx, ny = -dy / len * W * 0.4, dx / len * W * 0.4
			for _, f in { 0.36, 0.64 } do
				local mx, my = s.x1 + dx * f, s.y1 + dy * f
				strip(trail, project(L, U, mx - nx, my - ny) + sunk, project(L, U, mx + nx, my + ny) + sunk, 0.07 * U, col.trailMark, 4, "Plank")
			end
		end
	end
	for _, s in branch do
		-- the shortcut's dash down the middle
		local a = project(L, U, s.x1 + (s.x2 - s.x1) * 0.4, s.y1 + (s.y2 - s.y1) * 0.4) + sunk
		local b = project(L, U, s.x1 + (s.x2 - s.x1) * 0.6, s.y1 + (s.y2 - s.y1) * 0.6) + sunk
		strip(trail, a, b, across(0.16, s.x1, s.y1, s.x2, s.y2) * U, C.coral, 4, "Dash")
	end

	-- the little things lying about (over the trail's edge, so one in front of it isn't
	-- hidden under it)
	local tints = (scene.details and scene.details.tint) or {}
	for _, d in L.details do
		local tint = tints[d.kind]
		sprite(trail, L, U, "ground/" .. d.kind, d.x, d.y, d.size, 5, if tint then hex(string.sub(tint, 2)) else nil, 0, FLAT[d.kind])
	end

	-- rivers and lava streams, cut into the ground in its own colours (lava glows on the
	-- ground around it)
	-- (water: a light, shallow rim along the banks rather than a hard line of foam,
	-- deeper down its middle, ripples showing which way it runs)
	local water = Util.mix(col.shallows, col.water, 0.3)
	local riverLook = {
		width = 0.38,
		lip = lip,
		bank = Util.mix(cliff, cliffDark, 0.35),
		edge = Util.mix(col.shallows, foam, 0.35),
		fill = water,
		mid = Util.mix(water, col.water, 0.3),
		midWidth = 0.66,
		ripple = foam,
		splash = foam,
	}
	for i, r in L.rivers do
		stream(trail, L, U, r, riverLook, 10, "River", depth, i * 1.7)
	end
	-- (a canal: the same, a little wider, under the drawbridge)
	local canalLook = table.clone(riverLook)
	canalLook.width = 0.46
	for i, r in L.canals or {} do
		stream(trail, L, U, r, canalLook, 10, "Canal", depth, i * 3.1)
	end
	local lava = col.lava or C.coral
	local glow = col.lavaGlow or C.sun
	for i, r in L.lava or {} do
		if soft then
			for k = 1, #r.points, 3 do
				local q = r.points[k]
				sprite(trail, L, U, "ground/soft", q[1], q[2], 2.2, 9, lava, 0.72, true)
			end
		end
		stream(trail, L, U, r, {
			width = 0.4,
			lip = lip,
			bank = cliffDark,
			edge = hex("3A1A12"),
			fill = Util.shade(lava, -0.06),
			mid = Util.mix(lava, glow, 0.45),
			core = glow,
			crust = hex("4A2016"),
			cooled = hex("3A2A26"),
			vent = hex("4A3E38"),
			splash = Util.mix(C.white, col.shallows, 0.3),
			steam = C.white,
		}, 10, "Lava", depth, i * 2.3)
	end

	-- slime pools: the same, slime in a hollow, a few bubbles
	local pool = col.pool or C.lime
	local pfill = BoardLayout.fillets(L.pools, 0.5, { CUT.lip[1], CUT.bank[1], CUT.edge[1], CUT.fill[1] })
	for i, key in { "lip", "bank", "edge", "fill" } do
		local ly = CUT[key]
		local color = ({ lip = lip, bank = Util.mix(cliff, cliffDark, 0.35), edge = Util.shade(pool, -0.35), fill = pool })[key]
		layer(trail, L, U, L.pools, pfill[i], ly[1], ly[2], ly[3], color, 20 + i, if key == "fill" then "Pool" else "Pool" .. key)
	end
	for i, p in L.pools do
		if i % 2 == 0 then
			local at = project(L, U, p.x + p.r * 0.4, p.y - p.r * 0.3) + Vector2.new(0, CUT.fill[3] * U)
			ellipse(trail, at, 0.3 * U, 0.3 * U * K, Util.shade(pool, 0.5), 25, "Bubble")
			ellipse(trail, at + Vector2.new(0, 0.02 * U), 0.2 * U, 0.2 * U * K, pool, 26, "BubbleInner")
		end
	end

	-- props: the flat ones on the ground, the rest standing up (the lower ones in front)
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
		prop(if p.ground then trail else layers.Props, L, U, p, if p.ground then 40 + i else i)
	end
end

return MapArt
