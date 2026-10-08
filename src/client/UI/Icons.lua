--[[
	Icons
	Draws IconData / DecorData instruction lists with Shapes.

	Icons.draw(parent, ops, colors)            -- into an existing square canvas
	Icons.make(parent, id, colors, props)      -- new square canvas with that icon
	Icons.engraved(parent, id, woodColor, props) -- carved-into-wood version

	colors = { ink = Color3, bg = Color3?, acc = Color3?, acc2 = Color3?, hi = Color3? }
	Ops can also carry `t` (transparency) for faint ink.
]]

local Shapes = require(script.Parent.Shapes)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local IconData = require(script.Parent.IconData)

local Icons = {}
Icons.data = IconData

local function resolve(colors, c: any): Color3
	if c == nil then
		return colors.ink
	end
	if type(c) == "string" and string.sub(c, 1, 1) == "#" then
		return Color3.fromHex(c)
	end
	return colors[c] or colors.ink
end

local function opts(op, extra: any?)
	local o = {}
	if op.t then
		o.t = op.t
	end
	if op.px then
		o.px = op.px
	end
	if extra then
		for k, v in extra do
			o[k] = v
		end
	end
	return o
end

-- group transform helpers (mirror -> scale -> rotate about the centre -> shift)
local function makeTransform(rot: number, s: number, dx: number, dy: number, fx: boolean)
	local th = math.rad(rot)
	local c, sn = math.cos(th), math.sin(th)
	return function(x: number, y: number): (number, number)
		if fx then
			x = 1 - x
		end
		x, y = 0.5 + (x - 0.5) * s, 0.5 + (y - 0.5) * s
		local rx = 0.5 + (x - 0.5) * c - (y - 0.5) * sn
		local ry = 0.5 + (x - 0.5) * sn + (y - 0.5) * c
		return rx + dx, ry + dy
	end
end

local SIZE_ARGS = {
	rect = { 4, 5 },
	circle = { 4 },
	pill = { 4, 5 },
	tri = { 4 },
	half = { 4 },
	ring = { 4, 5 },
	oring = { 4, 5, 6 },
	arc = { 4, 5 },
	drop = { 4 },
	hex = { 4 },
	star = { 4 },
	sparkle = { 4 },
	chevron = { 4, 5 },
	arrow = { 4, 5 },
	text = { 4, 5 },
}
local DIR_DEFAULT = { tri = 0, half = 0, arc = 0, drop = 0, chevron = 90, arrow = 90 }
local ROT_KINDS = { rect = true, pill = true, hex = true, text = true }

local function transformOp(op, rot: number, s: number, dx: number, dy: number, fx: boolean)
	local tp = makeTransform(rot, s, dx, dy, fx)
	local out = table.clone(op)
	local kind = op[1]
	if kind == "group" then
		-- nested group: apply its own transform first, then ours, and pass its colour down
		local flat = {}
		for i, child in op.ops do
			local inner = transformOp(child, op.rot or 0, op.s or 1, op.dx or 0, op.dy or 0, op.fx == true)
			if op.c and inner.c == nil then
				inner.c = op.c
			end
			flat[i] = transformOp(inner, rot, s, dx, dy, fx)
		end
		out.ops = flat
		out.rot, out.s, out.dx, out.dy, out.fx, out.c = nil, nil, nil, nil, nil, nil
		return out
	elseif kind == "line" then
		out[2], out[3] = tp(op[2], op[3])
		out[4], out[5] = tp(op[4], op[5])
		out[6] = op[6] * s
	elseif kind == "path" or kind == "taper" then
		local pts = {}
		for i, p in op[2] do
			local x, y = tp(p[1], p[2])
			pts[i] = { x, y }
		end
		out[2] = pts
		out[3] = op[3] * s
		if kind == "taper" then
			out[4] = op[4] * s
		end
	else
		out[2], out[3] = tp(op[2], op[3])
		for _, i in SIZE_ARGS[kind] or {} do
			out[i] = op[i] * s
		end
		if ROT_KINDS[kind] then
			local r0 = op.rot or 0
			if fx and kind ~= "text" then
				r0 = -r0
			end
			out.rot = r0 + rot
		end
		if DIR_DEFAULT[kind] ~= nil then
			local d0 = op.dir or DIR_DEFAULT[kind]
			if fx then
				d0 = -d0
			end
			out.dir = d0 + rot
		end
	end
	return out
end

function Icons.draw(canvas: Instance, ops: { any }, colors)
	for _, op in ops do
		local kind = op[1]
		local col = resolve(colors, op.c)
		if kind == "group" then
			local sub = {}
			for i, child in op.ops do
				sub[i] = transformOp(child, op.rot or 0, op.s or 1, op.dx or 0, op.dy or 0, op.fx == true)
				if op.c and sub[i].c == nil then
					sub[i].c = op.c
				end
			end
			Icons.draw(canvas, sub, colors)
		elseif kind == "rect" then
			Shapes.rect(canvas, op[2], op[3], op[4], op[5], col, opts(op, { r = op.r, rot = op.rot }))
		elseif kind == "circle" then
			Shapes.circle(canvas, op[2], op[3], op[4], col, opts(op))
		elseif kind == "pill" then
			Shapes.pill(canvas, op[2], op[3], op[4], op[5], col, opts(op, { rot = op.rot }))
		elseif kind == "line" then
			Shapes.line(canvas, op[2], op[3], op[4], op[5], op[6], col, opts(op, { square = op.square }))
		elseif kind == "path" then
			local pts = op[2]
			if op.closed then
				pts = table.clone(pts)
				table.insert(pts, pts[1])
			end
			Shapes.path(canvas, pts, op[3], col, opts(op))
		elseif kind == "taper" then
			Shapes.taper(canvas, op[2], op[3], op[4], col, opts(op, { steps = op.steps }))
		elseif kind == "tri" then
			Shapes.tri(canvas, op[2], op[3], op[4], col, opts(op, { dir = op.dir }))
		elseif kind == "half" then
			Shapes.half(canvas, op[2], op[3], op[4], col, opts(op, { dir = op.dir }))
		elseif kind == "ring" then
			Shapes.ring(canvas, op[2], op[3], op[4], op[5], col, opts(op))
		elseif kind == "oring" then
			Shapes.oring(canvas, op[2], op[3], op[4], op[5], op[6], col, opts(op))
		elseif kind == "arc" then
			Shapes.arc(canvas, op[2], op[3], op[4], op[5], col, opts(op, { dir = op.dir, keep = op.keep }))
		elseif kind == "drop" then
			local r = op[4]
			local dir = op.dir or 0
			local a = math.rad(dir - 90)
			Shapes.circle(canvas, op[2], op[3], 2 * r, col, opts(op))
			Shapes.tri(canvas, op[2] + math.cos(a) * 0.7071 * r, op[3] + math.sin(a) * 0.7071 * r, 1.4142 * r, col, opts(op, { dir = dir }))
		elseif kind == "hex" then
			Shapes.hex(canvas, op[2], op[3], op[4], col, opts(op, { rot = op.rot }))
		elseif kind == "star" then
			Shapes.star(canvas, op[2], op[3], op[4], col, opts(op))
		elseif kind == "sparkle" then
			Shapes.sparkle(canvas, op[2], op[3], op[4], col, opts(op))
		elseif kind == "chevron" then
			Shapes.chevron(canvas, op[2], op[3], op[4], op[5], col, opts(op, { dir = op.dir }))
		elseif kind == "arrow" then
			Shapes.arrow(canvas, op[2], op[3], op[4], op[5], col, opts(op, { dir = op.dir }))
		elseif kind == "text" then
			local font = Theme.Font.Chunky
			if op.font == "display" then
				font = Theme.Font.Display
			elseif op.font == "body" then
				font = Theme.Font.BodyHeavy
			end
			Shapes.text(canvas, op[2], op[3], op[4], op[5], op[6], col, font, opts(op, { rot = op.rot }))
		end
	end
end

-- Standard color sets
function Icons.inkColors(ink: Color3?, bg: Color3?)
	local c = ink or Theme.C.ink
	local b = bg or Theme.C.parchment
	return { ink = c, bg = b, acc = c, acc2 = c, hi = b }
end

function Icons.flatColors(ink: Color3, bg: Color3, acc: Color3?)
	return { ink = ink, bg = bg, acc = acc or ink, acc2 = acc or ink, hi = bg }
end

-- New square canvas containing icon `id`. Returns the canvas frame.
function Icons.make(parent: Instance, id: string, colors, props: { [string]: any }?): Frame
	local ops = IconData[id]
	local canvas = Shapes.canvas(parent, props)
	canvas.Name = "Icon_" .. id
	if ops then
		Icons.draw(canvas, ops, colors)
	end
	return canvas
end

-- Burned-in look: the symbol in dark wood on wood of color `wood` (one flat layer).
function Icons.engraved(parent: Instance, id: string, wood: Color3, props: { [string]: any }?, accent: Color3?): Frame
	local ops = IconData[id] or {}
	local holder = Util.frame(parent, props)
	holder.Name = "Engraved_" .. id
	local burn = Util.shade(wood, -0.62)
	local inkColors = { ink = burn, bg = wood, acc = accent or burn, acc2 = accent or burn, hi = wood }
	local dark = Shapes.canvas(holder, { Name = "Ink", ZIndex = 2 })
	Icons.draw(dark, ops, inkColors)
	return holder
end

-- Icon on a colored medallion (board tokens, category badges).
function Icons.medallion(parent: Instance, id: string, color: Color3, props: { [string]: any }?): Frame
	local disc = Util.new("Frame", {
		Name = "Medallion",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	if props then
		for k, v in props do
			(disc :: any)[k] = v
		end
	end
	Util.corner(disc, 0.5)
	Util.scaledStroke(disc, Theme.C.brass, 0.08, 2)
	disc.Parent = parent
	Icons.make(disc, id, Icons.flatColors(Theme.C.white, color, Theme.C.brassLight), {
		Size = UDim2.fromScale(0.64, 0.64),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 2,
	})
	return disc
end

return Icons
