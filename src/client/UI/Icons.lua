--[[
	Icons
	Draws IconData / StickerArt / MapProps / AccessoryArt instruction lists with Shapes.

	Icons.draw(parent, ops, colors, outline?)   -- into an existing square canvas
	Icons.make(parent, id, colors, props, outline?) -- new square canvas with that icon
	Icons.sticker(parent, ops, props?, outline?) -- sticker art (own colours, outlined)
	Icons.engraved(parent, id, woodColor, props) -- one flat layer in a darker shade

	colors = { ink = Color3, bg = Color3?, acc = Color3?, acc2 = Color3?, hi = Color3?, line = Color3? }
	Ops can also carry `t` (transparency) for faint ink.

	outline: the sticker look. Every piece is first drawn grown by `outline` (a fraction
	of the canvas) in the line colour, then the pieces themselves go on top, so the whole
	drawing gets one clean dark outline. Pieces with ol = false (details inside a shape)
	and faces are left out of that pass.
]]

local Shapes = require(script.Parent.Shapes)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local IconData = require(script.Parent.IconData)
local StickerArt = require(script.Parent.StickerArt)

local Icons = {}
Icons.data = IconData

-- How thick a sticker outline is (fraction of the canvas): one look everywhere.
Icons.OUTLINE = 0.045

-- Every outline is drawn at this share of what was asked: a thin, even line, not a
-- heavy comic one.
Icons.OUTLINE_SCALE = 0.6

local function resolve(colors, c: any): Color3
	if c == nil then
		return colors.ink
	end
	if type(c) == "string" and string.sub(c, 1, 1) == "#" then
		return Color3.fromHex(c)
	end
	if c == "line" then
		return colors.line or Theme.C.line
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
	eyes = { 4, 5 },
	dots = { 4, 5 },
	brows = { 4, 5 },
	eye = { 4 },
	mouth = { 4 },
	blush = { 4, 5 },
	shine = { 4 },
}
local FACE = { eyes = true, eye = true, mouth = true, blush = true, shine = true, dots = true, brows = true }
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

-- Groups expanded into one flat list in canvas coordinates (colours passed down).
local function flatten(ops: { any }, out: { any }?, color: any?): { any }
	local list = out or {}
	for _, op in ops do
		local o = op
		if color ~= nil and op.c == nil then
			o = table.clone(op)
			o.c = color
		end
		if op[1] == "group" then
			local sub = {}
			for i, child in op.ops do
				sub[i] = transformOp(child, op.rot or 0, op.s or 1, op.dx or 0, op.dy or 0, op.fx == true)
			end
			flatten(sub, list, o.c)
		else
			table.insert(list, o)
		end
	end
	return list
end

-- The piece grown by `w` on every side, in the line colour (or nil: no outline for it).
local function inflate(op, w: number)
	local kind = op[1]
	if op.ol == false or op.c == "bg" or FACE[kind] or kind == "text" or (op.t or 0) > 0.5 then
		return nil
	end
	local a = table.clone(op)
	a.c = "line"
	a.t = nil
	if kind == "rect" then
		local m = math.min(op[4], op[5])
		a.r = ((op.r or 0) * m + w) / (m + 2 * w)
		a[4] += 2 * w
		a[5] += 2 * w
	elseif kind == "circle" then
		a[4] += 2 * w
	elseif kind == "pill" then
		a[4] += 2 * w
		a[5] += 2 * w
	elseif kind == "line" then
		a[6] += 2 * w
	elseif kind == "path" then
		a[3] += 2 * w
	elseif kind == "taper" then
		a[3] += 2 * w
		a[4] += 2 * w
	elseif kind == "tri" then
		local dr = math.rad((op.dir or 0) - 90)
		a[2] -= math.cos(dr) * w
		a[3] -= math.sin(dr) * w
		a[4] += w / 0.2071
	elseif kind == "half" then
		a[4] += 2 * w
	elseif kind == "ring" or kind == "arc" then
		a[4] += 2 * w
		a[5] += 2 * w
	elseif kind == "oring" then
		a[4] += 2 * w
		a[5] += 2 * w
		a[6] += 2 * w
	elseif kind == "drop" then
		a[4] += w
	elseif kind == "hex" then
		a[4] += 4 * w / math.sqrt(3)
	elseif kind == "star" or kind == "sparkle" or kind == "chevron" or kind == "arrow" then
		a.extra = w
	else
		return nil
	end
	return a
end

local WHITE = Color3.new(1, 1, 1)
local BLUSH = Color3.fromHex("FF7BAC")
local TONGUE = Color3.fromHex("FF6B8A")

-- Eyes, mouths, cheeks and shines: drawn on top with their own lines.
local function drawFace(canvas: Instance, op, colors)
	local kind = op[1]
	local line = resolve(colors, "line")
	if kind == "dots" then
		-- the crew's eyes: plain ink dots that change shape with the mood
		local cx, cy, gap, d = op[2], op[3], op[4], op[5]
		local mood = op.mood or "normal"
		for i, sx in { -1, 1 } do
			local ex = cx + sx * gap / 2
			local m = mood
			if mood == "wink" then
				m = if i == 2 then "happy" else "normal"
			end
			if m == "happy" then
				Shapes.arc(canvas, ex, cy + d * 0.45, d * 1.7, d * 0.4, line, { dir = 0, keep = 0.5 })
			elseif m == "closed" then
				Shapes.line(canvas, ex - d * 0.8, cy, ex + d * 0.8, cy, d * 0.36, line)
			elseif m == "dizzy" then
				Shapes.line(canvas, ex - d * 0.7, cy - d * 0.7, ex + d * 0.7, cy + d * 0.7, d * 0.34, line)
				Shapes.line(canvas, ex - d * 0.7, cy + d * 0.7, ex + d * 0.7, cy - d * 0.7, d * 0.34, line)
			else
				-- a small white eye in an ink rim, with an ink pupil
				local big = if m == "shock" then 1.25 else 1
				Shapes.rect(canvas, ex, cy, d * 1.75 * big, d * 2.15 * big, line, { r = 0.5 })
				Shapes.rect(canvas, ex, cy, d * 1.25 * big, d * 1.65 * big, WHITE, { r = 0.5 })
				local pd = if m == "shock" then 0.5 else 0.8
				Shapes.rect(canvas, ex, cy + d * 0.15, d * pd, d * pd * 1.25, line, { r = 0.5 })
				if m == "smug" then
					-- heavy lids
					Shapes.rect(canvas, ex, cy - d * 0.45, d * 1.75, d * 1.05, line, { r = 0.3 })
				end
			end
		end
		return
	elseif kind == "brows" then
		local cx, cy, gap, w = op[2], op[3], op[4], op[5]
		local mood = op.mood or "normal"
		local col = if op.c then resolve(colors, op.c) else line
		local th = w * 0.32
		for i, sx in { -1, 1 } do
			local ex = cx + sx * gap / 2
			-- how far the inner end (nearest the nose) dips (+) or lifts (-)
			local tilt, lift = 0, 0
			if mood == "angry" then
				tilt = w * 0.35
			elseif mood == "sad" then
				tilt = -w * 0.3
			elseif mood == "raised" then
				lift = w * 0.3
			elseif mood == "smug" then
				lift = if i == 2 then w * 0.3 else -w * 0.05
			end
			local inner, outer = ex - sx * w / 2, ex + sx * w / 2
			Shapes.line(canvas, outer, cy - lift, inner, cy - lift + tilt, th, col)
		end
		return
	end
	if kind == "blush" then
		local cx, cy, gap, d = op[2], op[3], op[4], op[5]
		local col = if op.c then resolve(colors, op.c) else BLUSH
		for _, sx in { -1, 1 } do
			Shapes.rect(canvas, cx + sx * gap / 2, cy, d, d * 0.62, col, { r = 0.5, t = 0.45 })
		end
		return
	elseif kind == "shine" then
		Shapes.rect(canvas, op[2], op[3], op[4] * 0.28, op[4], WHITE, { r = 0.5, rot = op.rot or 35, t = op.t or 0.15 })
		return
	elseif kind == "mouth" then
		local cx, cy, w = op[2], op[3], op[4]
		local mood = op.mood or "smile"
		local th = math.max(w * 0.16, 0.02)
		if mood == "smile" then
			Shapes.arc(canvas, cx, cy - w * 0.25, w, th, line, { dir = 180, keep = 0.5 })
		elseif mood == "frown" then
			Shapes.arc(canvas, cx, cy + w * 0.25, w, th, line, { dir = 0, keep = 0.5 })
		elseif mood == "flat" then
			Shapes.line(canvas, cx - w / 2, cy, cx + w / 2, cy, th, line)
		elseif mood == "smirk" then
			Shapes.line(canvas, cx - w / 2, cy + w * 0.06, cx + w * 0.25, cy - w * 0.04, th, line)
			Shapes.arc(canvas, cx + w * 0.3, cy - w * 0.12, w * 0.4, th, line, { dir = 135, keep = 0.5 })
		elseif mood == "o" then
			Shapes.circle(canvas, cx, cy, w * 0.55, line)
			Shapes.circle(canvas, cx, cy + w * 0.08, w * 0.28, TONGUE)
		else -- grin, open, teeth: an open mouth
			Shapes.half(canvas, cx, cy - w * 0.12, w, line, { dir = 180 })
			if mood == "open" then
				Shapes.half(canvas, cx, cy + w * 0.14, w * 0.5, TONGUE, { dir = 0 })
			elseif mood == "grin" then
				Shapes.rect(canvas, cx, cy - w * 0.05, w * 0.72, w * 0.16, WHITE, { r = 0.3 })
			else
				for i = 0, 3 do
					Shapes.tri(canvas, cx - w * 0.34 + i * w * 0.68 / 3, cy - w * 0.12, w * 0.2, WHITE, { dir = 180 })
				end
			end
		end
		return
	end
	-- eyes
	local spots
	local d
	if kind == "eye" then
		d = op[4]
		spots = { { op[2], op[3] } }
	else
		d = op[5]
		spots = { { op[2] - op[4] / 2, op[3] }, { op[2] + op[4] / 2, op[3] } }
	end
	local mood = op.mood or "normal"
	local look = op.look or { 0, 0 }
	for i, spot in spots do
		local ex, ey = spot[1], spot[2]
		local m = mood
		if mood == "wink" then
			m = if i == 2 then "happy" else "normal"
		end
		if m == "happy" then
			Shapes.arc(canvas, ex, ey + d * 0.15, d * 0.9, d * 0.2, line, { dir = 0, keep = 0.5 })
		elseif m == "closed" then
			Shapes.line(canvas, ex - d * 0.4, ey, ex + d * 0.4, ey, d * 0.18, line)
		elseif m == "dizzy" then
			Shapes.line(canvas, ex - d * 0.3, ey - d * 0.3, ex + d * 0.3, ey + d * 0.3, d * 0.18, line)
			Shapes.line(canvas, ex - d * 0.3, ey + d * 0.3, ex + d * 0.3, ey - d * 0.3, d * 0.18, line)
		else
			Shapes.circle(canvas, ex, ey, d, line)
			Shapes.circle(canvas, ex, ey, d * 0.78, WHITE)
			local pd = d * (if m == "shock" then 0.3 else 0.46)
			local px, py = ex + look[1] * d * 0.16, ey + look[2] * d * 0.16
			Shapes.circle(canvas, px, py, pd, line)
			Shapes.circle(canvas, px - pd * 0.22, py - pd * 0.24, pd * 0.36, WHITE)
			if m == "sleepy" then
				local lid = if op.lid then resolve(colors, op.lid) else line
				Shapes.half(canvas, ex, ey, d * 0.82, lid, { dir = 0 })
				Shapes.line(canvas, ex - d * 0.42, ey, ex + d * 0.42, ey, d * 0.12, line)
			end
			if m == "angry" or m == "sad" then
				local sgn = if (i == 1) == (m == "angry") then 1 else -1
				if kind == "eye" then
					sgn = 0
				end
				Shapes.line(canvas, ex - d * 0.5, ey - d * 0.62 - sgn * d * 0.14, ex + d * 0.5, ey - d * 0.62 + sgn * d * 0.14, d * 0.2, line)
			end
		end
	end
end

local function drawOne(canvas: Instance, op, colors)
	local kind = op[1]
	if FACE[kind] then
		drawFace(canvas, op, colors)
		return
	end
	local col = resolve(colors, op.c)
	if kind == "rect" then
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
		Shapes.star(canvas, op[2], op[3], op[4], col, opts(op, { extra = op.extra }))
	elseif kind == "sparkle" then
		Shapes.sparkle(canvas, op[2], op[3], op[4], col, opts(op, { extra = op.extra }))
	elseif kind == "chevron" then
		Shapes.chevron(canvas, op[2], op[3], op[4], op[5], col, opts(op, { dir = op.dir, extra = op.extra }))
	elseif kind == "arrow" then
		Shapes.arrow(canvas, op[2], op[3], op[4], op[5], col, opts(op, { dir = op.dir, extra = op.extra }))
	elseif kind == "text" then
		local font = Theme.Font.Chunky
		if op.font == "body" then
			font = Theme.Font.BodyHeavy
		end
		Shapes.text(canvas, op[2], op[3], op[4], op[5], op[6], col, font, opts(op, { rot = op.rot, stroke = op.stroke }))
	end
end

function Icons.draw(canvas: Instance, ops: { any }, colors, outline: number?)
	local flat = flatten(ops)
	if outline and outline > 0 then
		local w = outline * Icons.OUTLINE_SCALE
		for _, op in flat do
			local big = inflate(op, w)
			if big then
				drawOne(canvas, big, colors)
			end
		end
	end
	for _, op in flat do
		drawOne(canvas, op, colors)
	end
end

-- Colours for sticker art (it carries its own; these fill in the roles it uses).
function Icons.stickerColors()
	local C = Theme.C
	return { ink = C.ink, line = C.ink, bg = C.cream, acc = C.sun, acc2 = C.sun, hi = C.white }
end

-- A new square canvas with sticker art `ops` on it, outlined.
function Icons.sticker(parent: Instance, ops: { any }, props: { [string]: any }?, outline: number?): Frame
	local canvas = Shapes.canvas(parent, props)
	canvas.Name = "Sticker"
	Icons.draw(canvas, ops, Icons.stickerColors(), outline or Icons.OUTLINE)
	return canvas
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
function Icons.make(parent: Instance, id: string, colors, props: { [string]: any }?, outline: number?): Frame
	local ops = IconData[id]
	local canvas = Shapes.canvas(parent, props)
	canvas.Name = "Icon_" .. id
	if ops then
		Icons.draw(canvas, ops, colors, outline)
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

-- The sticker art for an id, if it has one: a card's illustration or a character's mascot.
function Icons.stickerFor(id: string): { any }?
	local art = StickerArt.cards[id]
	if art then
		return art
	end
	if StickerArt.bodyColor[id] then
		return StickerArt.mascot(id, nil, { bust = true })
	end
	return StickerArt.misc[id]
end

--[[
	An icon on a coloured disc with the sticker outline (tokens, badges, portraits).
	Cards and characters show their sticker art; anything else is a white glyph.
]]
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
	Util.scaledStroke(disc, Theme.C.line, 0.035, 2)
	disc.Parent = parent
	if StickerArt.bodyColor[id] then
		-- a character: a real portrait on a pale disc of their colour, cropped to the circle
		disc.BackgroundColor3 = color:Lerp(Theme.C.cream, 0.62)
		local crop = Util.new("CanvasGroup", {
			Name = "Portrait",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = disc.ZIndex + 1,
			Parent = disc,
		})
		Util.corner(crop, 0.5)
		local s = Icons.sticker(crop, StickerArt.mascot(id, nil, { crop = true }), {
			Size = UDim2.fromScale(1, 1),
			ZIndex = disc.ZIndex + 1,
		}, 0.045)
		s.ZIndex = disc.ZIndex + 1
		return disc
	end
	local art = Icons.stickerFor(id)
	if art then
		local s = Icons.sticker(disc, art, {
			Size = UDim2.fromScale(0.86, 0.86),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = disc.ZIndex + 1,
		}, 0.055)
		s.ZIndex = disc.ZIndex + 1
	else
		Icons.make(disc, id, { ink = Color3.new(1, 1, 1), bg = color, acc = Theme.C.sunLight, acc2 = Theme.C.sunLight, hi = color, line = color }, {
			Size = UDim2.fromScale(0.56, 0.56),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = disc.ZIndex + 1,
		})
	end
	return disc
end

return Icons
