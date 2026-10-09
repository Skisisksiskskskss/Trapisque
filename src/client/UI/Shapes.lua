--[[
	Shapes
	Vector-style drawing with plain UI frames. Every icon, emblem and doodle in the game
	is built from these primitives (no image assets).

	Coordinates are normalized to a square "canvas" frame: (0,0) top-left, (1,1)
	bottom-right. Sizes are fractions of the canvas width.

	Non-square canvases set the attribute Aspect = width / height; coordinates are then
	in canvas-width units on both axes (y runs from 0 to 1 / Aspect).
]]

local Util = require(script.Parent.Util)

local Shapes = {}

-- Shapes draw in creation order: each new shape gets the next ZIndex among its
-- siblings (the UI uses ZIndexBehavior.Sibling).
local function nextZ(parent: Instance): number
	local z = (parent:GetAttribute("Z") or 0) + 1
	parent:SetAttribute("Z", z)
	return z
end

-- A square drawing surface inside `parent`.
function Shapes.canvas(parent: Instance, props: { [string]: any }?): Frame
	local c = Util.frame(parent, {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	if props then
		for k, v in props do
			(c :: any)[k] = v
		end
	end
	return c
end

local function base(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, o: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy * (parent:GetAttribute("Aspect") or 1))
	f.Size = UDim2.fromScale(w, h)
	f.SizeConstraint = Enum.SizeConstraint.RelativeXX
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.BackgroundTransparency = if o and o.t then o.t else 0
	f.Rotation = if o and o.rot then o.rot else 0
	f.ZIndex = if o and o.z then o.z else nextZ(parent)
	if o and o.name then
		f.Name = o.name
	end
	f.Parent = parent
	return f
end

function Shapes.rect(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, o: { [string]: any }?): Frame
	local f = base(parent, cx, cy, w, h, color, o)
	if o and o.r then
		Util.new("UICorner", { CornerRadius = UDim.new(o.r, 0), Parent = f })
	end
	return f
end

function Shapes.circle(parent: Instance, cx: number, cy: number, d: number, color: Color3, o: { [string]: any }?): Frame
	local f = base(parent, cx, cy, d, d, color, o)
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

function Shapes.pill(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, o: { [string]: any }?): Frame
	local f = base(parent, cx, cy, w, h, color, o)
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

-- A thick line between two points (rounded caps unless o.square).
function Shapes.line(parent: Instance, x1: number, y1: number, x2: number, y2: number, th: number, color: Color3, o: { [string]: any }?): Frame
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local opts = table.clone(o or {})
	opts.rot = math.deg(math.atan2(dy, dx))
	local f = base(parent, (x1 + x2) / 2, (y1 + y2) / 2, len + (if opts.square then 0 else th), th, color, opts)
	if not opts.square then
		Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	end
	return f
end

-- Connected line segments through a list of points {x, y}.
function Shapes.path(parent: Instance, points: { { number } }, th: number, color: Color3, o: { [string]: any }?)
	for i = 1, #points - 1 do
		Shapes.line(parent, points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], th, color, o)
	end
end

local function cutGradient(target: Instance, rotation: number, keep: number?)
	local k = keep or 0.5
	Util.new("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(math.max(0.001, k - 0.001), 0),
			NumberSequenceKeypoint.new(math.min(0.999, k), 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = target,
	})
end

--[[
	Right-angled isosceles triangle (90 degree apex).
	(bx, by) is the middle of its base, `width` the base length,
	o.dir the direction the apex points in degrees (0 = up, 90 = right).
]]
function Shapes.tri(parent: Instance, bx: number, by: number, width: number, color: Color3, o: { [string]: any }?): Frame
	local dir = if o and o.dir then o.dir else 0
	local side = width / math.sqrt(2)
	local opts = table.clone(o or {})
	opts.rot = 45 + dir
	local f = base(parent, bx, by, side, side, color, opts)
	cutGradient(f, 45)
	return f
end

-- Half disc; o.dir is where the round side faces (0 = up, a dome).
function Shapes.half(parent: Instance, cx: number, cy: number, d: number, color: Color3, o: { [string]: any }?): Frame
	local dir = if o and o.dir then o.dir else 0
	local opts = table.clone(o or {})
	opts.rot = dir
	local f = base(parent, cx, cy, d, d, color, opts)
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	cutGradient(f, 90)
	return f
end

-- Ring of outer diameter d and thickness th (both canvas fractions).
function Shapes.ring(parent: Instance, cx: number, cy: number, d: number, th: number, color: Color3, o: { [string]: any }?): Frame
	local inner = math.max(0.001, d - 2 * th)
	local f = base(parent, cx, cy, inner, inner, color, o)
	f.BackgroundTransparency = 1
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	local px = if o and o.px then o.px else 48
	local stroke = Util.scaledStroke(f, color, th / inner, math.max(1, th * px))
	if o and o.t then
		stroke.Transparency = o.t
	end
	if o and o.cut then
		-- keep only part of the ring: o.cut = { rotation, keep }
		cutGradient(stroke, o.cut[1], o.cut[2])
	end
	return f
end

-- Arc (part of a ring). dir = direction the arc's middle faces (0 = up), keep = 0.5 half.
function Shapes.arc(parent: Instance, cx: number, cy: number, d: number, th: number, color: Color3, o: { [string]: any }?): Frame
	local dir = if o and o.dir then o.dir else 0
	local opts = table.clone(o or {})
	opts.cut = { 90, opts.keep or 0.5 }
	opts.rot = dir
	return Shapes.ring(parent, cx, cy, d, th, color, opts)
end

-- Pointy-top hexagon of circumradius d/2.
function Shapes.hex(parent: Instance, cx: number, cy: number, d: number, color: Color3, o: { [string]: any }?): { Frame }
	local R = d / 2
	local w, h = math.sqrt(3) * R, R
	local parts = {}
	for _, rot in { 0, 60, 120 } do
		local opts = table.clone(o or {})
		opts.rot = rot + (if o and o.rot then o.rot else 0)
		local f = base(parent, cx, cy, w, h, color, opts)
		table.insert(parts, f)
	end
	return parts
end

-- Rounded cartoon star: a thick pentagram stroke with a filled middle.
function Shapes.star(parent: Instance, cx: number, cy: number, d: number, color: Color3, o: { [string]: any }?)
	local th = d * 0.18
	local R = d / 2 - th / 2
	local pts = {}
	for k = 0, 4 do
		local a = math.rad(-90 + 72 * k)
		pts[k] = { cx + R * math.cos(a), cy + R * math.sin(a) }
	end
	for k = 0, 4 do
		local a, b = pts[k], pts[(k + 2) % 5]
		Shapes.line(parent, a[1], a[2], b[1], b[2], th, color, o)
	end
	Shapes.circle(parent, cx, cy, d * 0.42, color, o)
end

-- 4-point twinkle made of thin rounded strokes.
function Shapes.sparkle(parent: Instance, cx: number, cy: number, d: number, color: Color3, o: { [string]: any }?)
	local R = d / 2
	local th = d * 0.12
	local r = R * 0.22
	local outer = {
		{ cx, cy - R + th / 2 },
		{ cx + R - th / 2, cy },
		{ cx, cy + R - th / 2 },
		{ cx - R + th / 2, cy },
	}
	local inner = { { cx + r, cy - r }, { cx + r, cy + r }, { cx - r, cy + r }, { cx - r, cy - r } }
	for i = 1, 4 do
		local prev = inner[if i == 1 then 4 else i - 1]
		Shapes.line(parent, outer[i][1], outer[i][2], inner[i][1], inner[i][2], th, color, o)
		Shapes.line(parent, outer[i][1], outer[i][2], prev[1], prev[2], th, color, o)
	end
	Shapes.circle(parent, cx, cy, r * 2.4, color, o)
end

-- Catmull-Rom smoothing of a point list (used by tapered strokes).
local function smooth(pts: { { number } }, steps: number): { { number } }
	local out = {}
	if #pts < 3 then
		local a, b = pts[1], pts[#pts]
		for i = 0, steps do
			local t = i / steps
			table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
		end
		return out
	end
	local P = { pts[1] }
	for _, p in pts do
		table.insert(P, p)
	end
	table.insert(P, pts[#pts])
	for i = 2, #P - 2 do
		local p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
		for k = 0, steps - 1 do
			local t = k / steps
			local t2, t3 = t * t, t * t * t
			local x = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
			local y = 0.5 * ((2 * p1[2]) + (-p0[2] + p2[2]) * t + (2 * p0[2] - 5 * p1[2] + 4 * p2[2] - p3[2]) * t2 + (-p0[2] + 3 * p1[2] - 3 * p2[2] + p3[2]) * t3)
			table.insert(out, { x, y })
		end
	end
	table.insert(out, pts[#pts])
	return out
end
Shapes.smooth = smooth

-- Brush stroke along a smooth path, thickness going from th0 to th1.
function Shapes.taper(parent: Instance, pts: { { number } }, th0: number, th1: number, color: Color3, o: { [string]: any }?)
	local dense = smooth(pts, if o and o.steps then o.steps else 5)
	local n = #dense
	for i = 1, n - 1 do
		local a, b = dense[i], dense[i + 1]
		local t = (i - 0.5) / (n - 1)
		Shapes.line(parent, a[1], a[2], b[1], b[2], th0 + (th1 - th0) * t, color, o)
	end
end

-- Oval ring (stroke around a pill shape).
function Shapes.oring(parent: Instance, cx: number, cy: number, w: number, h: number, th: number, color: Color3, o: { [string]: any }?): Frame
	local f = base(parent, cx, cy, math.max(0.001, w - 2 * th), math.max(0.001, h - 2 * th), color, o)
	f.BackgroundTransparency = 1
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	local px = if o and o.px then o.px else 48
	Util.scaledStroke(f, color, th / math.max(0.001, math.min(w, h) - 2 * th), math.max(1, th * px))
	return f
end

-- Chevron pointing in `dir` (0 = up, 90 = right).
function Shapes.chevron(parent: Instance, cx: number, cy: number, size: number, th: number, color: Color3, o: { [string]: any }?)
	local dir = if o and o.dir then o.dir else 90
	local a = math.rad(dir - 90)
	local ux, uy = math.cos(a), math.sin(a) -- forward
	local px, py = -uy, ux -- side
	local tipx, tipy = cx + ux * size * 0.3, cy + uy * size * 0.3
	local s = size * 0.5
	Shapes.line(parent, tipx - ux * s + px * s, tipy - uy * s + py * s, tipx, tipy, th, color, o)
	Shapes.line(parent, tipx - ux * s - px * s, tipy - uy * s - py * s, tipx, tipy, th, color, o)
end

-- Arrow: shaft + head, pointing in `dir`.
function Shapes.arrow(parent: Instance, cx: number, cy: number, len: number, th: number, color: Color3, o: { [string]: any }?)
	local dir = if o and o.dir then o.dir else 90
	local a = math.rad(dir - 90)
	local ux, uy = math.cos(a), math.sin(a)
	local x1, y1 = cx - ux * len / 2, cy - uy * len / 2
	local x2, y2 = cx + ux * len / 2, cy + uy * len / 2
	Shapes.line(parent, x1, y1, x2 - ux * th, y2 - uy * th, th, color, o)
	local opts = table.clone(o or {})
	opts.dir = dir
	Shapes.tri(parent, x2 - ux * th * 1.6, y2 - uy * th * 1.6, th * 3.2, color, opts)
end

function Shapes.text(parent: Instance, cx: number, cy: number, w: number, h: number, text: string, color: Color3, font: Font, o: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(cx, cy * (parent:GetAttribute("Aspect") or 1))
	t.Size = UDim2.fromScale(w, h)
	t.SizeConstraint = Enum.SizeConstraint.RelativeXX
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.FontFace = font
	t.TextScaled = true
	t.Rotation = if o and o.rot then o.rot else 0
	t.TextTransparency = if o and o.t then o.t else 0
	t.ZIndex = nextZ(parent)
	t.Parent = parent
	return t
end

return Shapes
