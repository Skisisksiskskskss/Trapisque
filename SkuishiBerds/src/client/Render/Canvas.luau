--[[
	Canvas: 2D drawing primitives built from plain GuiObjects (no uploaded
	images needed).

	Coordinates use a "space" that maps local units to the parent's Scale:
	  space = { ox, oy, sx, sy }  ->  scaleX = ox + x * sx, scaleY = oy + y * sy
	The arena space maps world units (0..480, 0..800) onto the arena frame.

	Shapes:
	  circle / ellipse (UICorner pill), rect, diamond (rotated square),
	  line (rotated thin frame), ring (stroked pill), text,
	  rtri (right triangle: rotated square clipped by an axis-aligned holder),
	  tri (isosceles, apex up/down/left/right = two right triangles)
]]

local Canvas = {}

export type Space = { ox: number, oy: number, sx: number, sy: number }

-- pixels per unit for the current arena (updated by the arena view on resize)
Canvas.ppu = 1

function Canvas.space(ox: number, oy: number, sx: number, sy: number): Space
	return { ox = ox, oy = oy, sx = sx, sy = sy }
end

local function pos(space: Space, x: number, y: number): UDim2
	return UDim2.fromScale(space.ox + x * space.sx, space.oy + y * space.sy)
end
Canvas.pos = pos

local function size(space: Space, w: number, h: number): UDim2
	return UDim2.fromScale(w * space.sx, h * space.sy)
end
Canvas.size = size

local function frame(parent: Instance?, z: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end
Canvas.frame = frame

local function corner(f: GuiObject, scale: number?, offset: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, offset or 0)
	c.Parent = f
	return c
end
Canvas.corner = corner

function Canvas.stroke(f: GuiObject, color: Color3, thicknessPx: number, transparency: number?): UIStroke
	local s = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thicknessPx
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = f
	return s
end

-- style = { color, alpha (0..1 opacity), stroke, strokeW (units), strokeAlpha, z, rot }
local function applyStyle(f: GuiObject, style)
	if style.color then
		f.BackgroundColor3 = style.color
		f.BackgroundTransparency = 1 - (style.alpha or 1)
	else
		f.BackgroundTransparency = 1
	end
	if style.stroke then
		Canvas.stroke(f, style.stroke, math.max(1, (style.strokeW or 1.5) * Canvas.ppu), 1 - (style.strokeAlpha or 1))
	end
	if style.rot then
		f.Rotation = style.rot
	end
	if style.z then
		f.ZIndex = style.z
	end
end
Canvas.applyStyle = applyStyle

function Canvas.circle(parent: Instance, space: Space, x: number, y: number, r: number, style): Frame
	local f = frame(parent)
	f.Position = pos(space, x, y)
	f.Size = size(space, r * 2, r * 2)
	corner(f)
	applyStyle(f, style)
	return f
end

-- Ellipses are drawn as pills (rounded rects); with rot they can tilt
function Canvas.ellipse(parent: Instance, space: Space, x: number, y: number, rx: number, ry: number, style): Frame
	local f = frame(parent)
	f.Position = pos(space, x, y)
	f.Size = size(space, rx * 2, ry * 2)
	corner(f)
	applyStyle(f, style)
	return f
end

function Canvas.rect(parent: Instance, space: Space, x: number, y: number, w: number, h: number, style): Frame
	local f = frame(parent)
	f.Position = pos(space, x, y)
	f.Size = size(space, w, h)
	if style.round then
		corner(f, 0, style.round * Canvas.ppu)
	end
	applyStyle(f, style)
	return f
end

-- Square rotated 45 degrees; `d` = distance from center to a corner
function Canvas.diamond(parent: Instance, space: Space, x: number, y: number, d: number, style): Frame
	local f = frame(parent)
	local side = d * math.sqrt(2)
	f.Position = pos(space, x, y)
	f.Size = size(space, side, side)
	applyStyle(f, style)
	f.Rotation = 45 + (style.rot or 0)
	return f
end

-- A line segment; thickness in units
function Canvas.line(parent: Instance, space: Space, x1: number, y1: number, x2: number, y2: number, thick: number, style): Frame
	local f = frame(parent)
	Canvas.setLine(f, space, x1, y1, x2, y2, thick)
	style = style or {}
	if style.round then
		corner(f)
	end
	applyStyle(f, { color = style.color, alpha = style.alpha, z = style.z })
	return f
end

function Canvas.setLine(f: GuiObject, space: Space, x1: number, y1: number, x2: number, y2: number, thick: number)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	f.Position = pos(space, (x1 + x2) / 2, (y1 + y2) / 2)
	-- width follows the x-scale of the space; uniform pixels-per-unit keeps the angle exact
	f.Size = UDim2.new(len * space.sx, 0, 0, math.max(1, thick * Canvas.ppu))
	f.Rotation = math.deg(math.atan2(dy, dx))
end

-- Stroked outline only (optionally just the top/bottom half via a clip holder)
function Canvas.ring(parent: Instance, space: Space, x: number, y: number, rx: number, ry: number, thick: number, style)
	local f = frame(parent)
	f.Position = pos(space, x, y)
	f.Size = size(space, rx * 2, ry * 2)
	f.BackgroundTransparency = 1
	corner(f)
	Canvas.stroke(f, style.color, math.max(1, thick * Canvas.ppu), 1 - (style.alpha or 1))
	if style.rot then
		f.Rotation = style.rot
	end
	if style.z then
		f.ZIndex = style.z
	end
	return f
end

--[[
	Clip holder: an axis-aligned frame with ClipsDescendants, in the parent's
	space. Children inside use their own space mapping (0..1 of the holder).
]]
function Canvas.clipHolder(parent: Instance, space: Space, x: number, y: number, w: number, h: number, z: number?): Frame
	local holder = frame(parent, z)
	holder.AnchorPoint = Vector2.new(0, 0)
	holder.Position = pos(space, x, y)
	holder.Size = size(space, w, h)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	return holder
end

--[[
	Right triangle in a w x h box whose top-left is (x, y).
	corner = where the right angle sits: "BL" | "BR" | "TL" | "TR"
]]
function Canvas.rtri(parent: Instance, space: Space, x: number, y: number, w: number, h: number, cornerName: string, style): Frame
	local holder = Canvas.clipHolder(parent, space, x, y, w, h, style.z)
	-- hypotenuse endpoints in box units, and a point inside the triangle
	local ax, ay, bx, by, ix, iy
	if cornerName == "BL" then
		ax, ay, bx, by, ix, iy = 0, 0, w, h, 0, h
	elseif cornerName == "BR" then
		ax, ay, bx, by, ix, iy = w, 0, 0, h, w, h
	elseif cornerName == "TL" then
		ax, ay, bx, by, ix, iy = w, 0, 0, h, 0, 0
	else -- "TR"
		ax, ay, bx, by, ix, iy = 0, 0, w, h, w, 0
	end
	local mx, my = (ax + bx) / 2, (ay + by) / 2
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / len, dx / len
	if (ix - mx) * nx + (iy - my) * ny < 0 then
		nx, ny = -nx, -ny
	end
	local L = (w + h) * 2
	local cx, cy = mx + nx * L / 2, my + ny * L / 2
	local sq = frame(holder)
	sq.Position = UDim2.fromScale(cx / w, cy / h)
	sq.Size = UDim2.fromScale(L / w, L / h)
	sq.Rotation = math.deg(math.atan2(dy, dx))
	sq.BackgroundColor3 = style.color or Color3.new(1, 1, 1)
	sq.BackgroundTransparency = 1 - (style.alpha or 1)
	if style.z then
		sq.ZIndex = style.z
	end
	return holder
end

--[[
	Isosceles triangle. apex = "up" | "down" | "left" | "right".
	(cx, cy) = center of the bounding box, w x h = box size.
	Returns a holder frame containing both halves.
]]
function Canvas.tri(parent: Instance, space: Space, cx: number, cy: number, w: number, h: number, apex: string, style): Frame
	local group = frame(parent, style.z)
	group.BackgroundTransparency = 1
	group.Position = pos(space, cx, cy)
	group.Size = size(space, w, h)
	local inner = Canvas.space(0, 0, 1 / w, 1 / h)
	if apex == "up" then
		Canvas.rtri(group, inner, 0, 0, w / 2, h, "BR", style)
		Canvas.rtri(group, inner, w / 2, 0, w / 2, h, "BL", style)
	elseif apex == "down" then
		Canvas.rtri(group, inner, 0, 0, w / 2, h, "TR", style)
		Canvas.rtri(group, inner, w / 2, 0, w / 2, h, "TL", style)
	elseif apex == "left" then
		Canvas.rtri(group, inner, 0, 0, w, h / 2, "BR", style)
		Canvas.rtri(group, inner, 0, h / 2, w, h / 2, "TR", style)
	else -- right
		Canvas.rtri(group, inner, 0, 0, w, h / 2, "BL", style)
		Canvas.rtri(group, inner, 0, h / 2, w, h / 2, "TL", style)
	end
	if style.rot then
		group.Rotation = style.rot
	end
	return group
end

function Canvas.text(parent: Instance, props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	t.Position = props.position or UDim2.fromScale(0.5, 0.5)
	t.Size = props.size or UDim2.fromScale(1, 0.1)
	t.Font = props.font or Enum.Font.FredokaOne
	t.Text = props.text or ""
	t.TextColor3 = props.color or Color3.new(0.13, 0.13, 0.13)
	t.TextScaled = props.scaled ~= false
	t.TextSize = props.textSize or 24
	t.TextTransparency = props.transparency or 0
	t.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	t.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	t.RichText = props.rich == true
	t.ZIndex = props.z or 1
	t.Rotation = props.rot or 0
	if props.strokeColor then
		local s = Instance.new("UIStroke")
		s.Color = props.strokeColor
		s.Thickness = props.strokeThickness or 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = t
	end
	t.Parent = parent
	return t
end

-- Color helpers -------------------------------------------------------------------

function Canvas.hsl(h: number, s: number, l: number): Color3
	h = (h % 360) / 360
	local function hue2rgb(p, q, t)
		if t < 0 then
			t += 1
		end
		if t > 1 then
			t -= 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end
	if s == 0 then
		return Color3.new(l, l, l)
	end
	local q = if l < 0.5 then l * (1 + s) else l + s - l * s
	local p = 2 * l - q
	return Color3.new(hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3))
end

function Canvas.shade(c: Color3, amount: number): Color3
	-- amount in -255..255 like the original shade(hex, percent)
	local k = amount / 255
	return Color3.new(math.clamp(c.R + k, 0, 1), math.clamp(c.G + k, 0, 1), math.clamp(c.B + k, 0, 1))
end

function Canvas.color(value: string?): Color3
	if not value or value == "" then
		return Color3.new(1, 1, 1)
	end
	local ok, c = pcall(Color3.fromHex, value)
	if ok then
		return c
	end
	return Color3.new(1, 1, 1)
end

return Canvas
