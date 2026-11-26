--[[
	BirdView: draws one bird (used in the arena and in menu previews).

	root (8R x 8R, centered on the bird, squish/stretch = root size)
	  body      circle in the bird's color (a CanvasGroup when a pattern needs clipping)
	  outline   #222 ring
	  look[d]   per facing variant (dir x upside): wing, eye, beak, species details, hat
	  status    shield ring, bubble, frozen tint, item gear

	Parts are laid out in "bird radii" (R) exactly like the original canvas code
	and mirrored for direction (x) and upside-down birds (y).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Birds = require(Shared.Config.Birds)
local Canvas = require(script.Parent.Canvas)
local Patterns = require(script.Parent.Patterns)
local Hats = require(script.Parent.Hats)

local BirdView = {}
BirdView.__index = BirdView

local INK = Color3.fromHex("#222222")
local WHITE = Color3.new(1, 1, 1)
local BEAK = Color3.fromHex("#ffcc66")
local ROOT_R = 8 -- root spans 8 radii
local S = Canvas.space(0.5, 0.5, 1 / ROOT_R, 1 / ROOT_R)

-- Builder: shapes in bird radii, mirrored by (fx, fy) -----------------------------
local function makeBuilder(parent: Instance, fx: number, fy: number, z: number, anims)
	local b = {}
	local flipRot = fx * fy < 0
	local function X(x)
		return x * fx
	end
	local function Y(y)
		return y * fy
	end
	local function R(r)
		r = r or 0
		return if flipRot then -r else r
	end
	local function style(color, o)
		o = o or {}
		return {
			color = color,
			alpha = o.alpha,
			stroke = o.stroke,
			strokeW = o.sw or 1.5,
			z = o.z or z,
			rot = R(o.rot),
			round = o.round,
		}
	end
	local function flipHalf(half)
		if fy < 0 then
			return if half == "top" then "bottom" else "top"
		end
		return half
	end

	function b.at(x: number, y: number): UDim2
		return Canvas.pos(S, X(x), Y(y))
	end
	function b.lineAngle(x1, y1, x2, y2): number
		return math.deg(math.atan2(Y(y2) - Y(y1), X(x2) - X(x1)))
	end
	function b.ell(x, y, rx, ry, color, o)
		o = o or {}
		if o.half then
			local half = flipHalf(o.half)
			local cx, cy = X(x), Y(y)
			local top = if half == "top" then cy - ry else cy
			local holder = Canvas.clipHolder(parent, S, cx - rx, top, rx * 2, ry, o.z or z)
			local inner = Canvas.space(0, 0, 1 / (rx * 2), 1 / ry)
			local st = style(color, o)
			st.rot = nil
			Canvas.ellipse(holder, inner, rx, if half == "top" then ry else 0, rx, ry, st)
			return holder
		end
		return Canvas.ellipse(parent, S, X(x), Y(y), rx, ry, style(color, o))
	end
	function b.circ(x, y, r, color, o)
		return Canvas.circle(parent, S, X(x), Y(y), r, style(color, o))
	end
	function b.rect(x, y, w, h, color, o)
		return Canvas.rect(parent, S, X(x), Y(y), w, h, style(color, o))
	end
	function b.tri(cx, cy, w, h, apex, color, o)
		if fx < 0 then
			if apex == "left" then
				apex = "right"
			elseif apex == "right" then
				apex = "left"
			end
		end
		if fy < 0 then
			if apex == "up" then
				apex = "down"
			elseif apex == "down" then
				apex = "up"
			end
		end
		local st = style(color, o)
		st.rot = nil
		st.stroke = nil
		return Canvas.tri(parent, S, X(cx), Y(cy), w, h, apex, st)
	end
	function b.rtri(x, y, w, h, cornerName, color, o)
		local nx, ny = X(x), Y(y)
		if fx < 0 then
			nx -= w
			cornerName = string.gsub(cornerName, "[LR]", { L = "R", R = "L" })
		end
		if fy < 0 then
			ny -= h
			cornerName = string.gsub(cornerName, "[TB]", { T = "B", B = "T" })
		end
		local st = style(color, o)
		st.stroke = nil
		return Canvas.rtri(parent, S, nx, ny, w, h, cornerName, st)
	end
	function b.line(x1, y1, x2, y2, thick, color, o)
		return Canvas.line(parent, S, X(x1), Y(y1), X(x2), Y(y2), thick, { color = color, z = (o and o.z) or z })
	end
	function b.ring(x, y, rx, ry, thick, color, o)
		o = o or {}
		if o.half then
			local half = flipHalf(o.half)
			local cx, cy = X(x), Y(y)
			local pad = thick / 15
			local top = if half == "top" then cy - ry - pad else cy
			local holder = Canvas.clipHolder(parent, S, cx - rx - pad, top, rx * 2 + pad * 2, ry + pad, o.z or z)
			local inner = Canvas.space(0, 0, 1 / (rx * 2 + pad * 2), 1 / (ry + pad))
			Canvas.ring(
				holder,
				inner,
				rx + pad,
				if half == "top" then ry + pad else 0,
				rx,
				ry,
				thick,
				{ color = color, alpha = o.alpha }
			)
			return holder
		end
		return Canvas.ring(
			parent,
			S,
			X(x),
			Y(y),
			rx,
			ry,
			thick,
			{ color = color, alpha = o.alpha, rot = R(o.rot), z = o.z or z }
		)
	end
	function b.anim(fn)
		table.insert(anims, fn)
	end
	return b
end

-- Species details -------------------------------------------------------------------
local function drawBeak(b, kind: string)
	if kind == "needle" then
		b.rect(1.45, 0.02, 1.0, 0.12, Color3.fromHex("#333333"), { z = 2 })
		b.circ(1.95, 0.02, 0.06, Color3.fromHex("#333333"), { z = 2 })
	elseif kind == "stub" then
		b.ell(1.05, 0.1, 0.28, 0.2, BEAK, { stroke = INK, sw = 1.4, z = 2 })
	elseif kind == "puffin" then
		b.ell(1.15, 0.05, 0.55, 0.42, Color3.fromHex("#ff6b35"), { stroke = INK, sw = 1.5, z = 2 })
		b.rect(1.12, 0.05, 0.12, 0.6, Color3.fromHex("#ffd166"), { z = 2 })
	elseif kind == "chisel" then
		b.rect(1.25, 0, 0.75, 0.32, Color3.fromHex("#95a5a6"), { stroke = INK, sw = 1.4, z = 2 })
		b.tri(1.75, 0, 0.3, 0.32, "right", Color3.fromHex("#95a5a6"), { z = 2 })
	elseif kind == "hook" then
		b.ell(0.98, 0.18, 0.22, 0.2, Color3.fromHex("#f39c12"), { stroke = INK, sw = 1.3, z = 2 })
		b.circ(1.05, 0.34, 0.08, Color3.fromHex("#f39c12"), { z = 2 })
	elseif kind == "bill" then
		b.rect(1.3, 0.1, 0.85, 0.36, Color3.fromHex("#ff9f43"), { stroke = INK, sw = 1.5, round = 4, z = 2 })
		b.line(1.0, 0.12, 1.7, 0.12, 1, INK, { z = 2 })
	elseif kind == "bent" then
		b.rect(1.2, 0.08, 0.6, 0.24, Color3.fromHex("#ffe0f0"), { stroke = INK, sw = 1.3, round = 3, z = 2 })
		b.circ(1.5, 0.22, 0.14, INK, { z = 2 })
	else
		-- classic: the original rounded beak, tip in front of the face
		b.tri(1.25, 0, 0.9, 0.8, "right", BEAK, { z = 2 })
		b.line(0.85, -0.38, 1.7, 0, 1.4, INK, { z = 2 })
		b.line(0.85, 0.38, 1.7, 0, 1.4, INK, { z = 2 })
	end
end

local function drawEye(b, kind: string, bodyColor: Color3)
	if kind == "owl" then
		b.circ(0.42, -0.2, 0.42, Color3.fromHex("#fff3dc"), { z = 7 })
		b.circ(0.5, -0.2, 0.3, Color3.fromHex("#f39c12"), { stroke = INK, sw = 1.3, z = 8 })
		b.circ(0.55, -0.2, 0.16, INK, { z = 9 })
		b.circ(0.5, -0.28, 0.06, WHITE, { z = 10 })
		return
	end
	local r = if kind == "sparkle" then 0.3 else 0.25
	b.circ(0.5, -0.2, r, WHITE, { stroke = INK, sw = 1.5, z = 7 })
	b.circ(0.55, -0.2, 0.13, INK, { z = 8 })
	if kind == "sparkle" then
		b.circ(0.5, -0.29, 0.06, WHITE, { z = 9 })
	elseif kind == "angry" then
		b.line(0.25, -0.55, 0.78, -0.4, 2, INK, { z = 9 })
	elseif kind == "sleepy" then
		b.ell(0.5, -0.34, 0.3, 0.16, bodyColor, { z = 9 })
		b.line(0.24, -0.24, 0.76, -0.24, 1.5, INK, { z = 10 })
	end
end

local function drawCrest(b, kind: string?, bodyColor: Color3)
	if kind == "tuft" then
		b.line(0.1, -0.95, -0.1, -1.35, 2, INK, { z = 4 })
		b.line(0.25, -0.95, 0.25, -1.4, 2, INK, { z = 4 })
		b.line(0.4, -0.92, 0.55, -1.3, 2, INK, { z = 4 })
	elseif kind == "mohawk" then
		local red = Color3.fromHex("#e74c3c")
		b.tri(-0.25, -1.08, 0.3, 0.4, "up", red, { z = 2 })
		b.tri(0.05, -1.15, 0.3, 0.5, "up", red, { z = 2 })
		b.tri(0.35, -1.08, 0.3, 0.4, "up", red, { z = 2 })
	elseif kind == "ears" then
		b.tri(-0.45, -1.02, 0.35, 0.5, "up", Canvas.shade(bodyColor, -30), { z = 2 })
		b.tri(0.45, -1.02, 0.35, 0.5, "up", Canvas.shade(bodyColor, -30), { z = 2 })
	end
end

local function drawExtra(b, kind: string?)
	if kind == "facepatch" then
		b.ell(0.45, -0.05, 0.45, 0.42, WHITE, { z = 6 })
	elseif kind == "cheeks" then
		b.circ(0.32, 0.32, 0.16, Color3.fromHex("#ff8fab"), { alpha = 0.7, z = 6 })
	elseif kind == "longneck" then
		b.ell(0.15, 0.55, 0.5, 0.25, Color3.fromHex("#2d2d2d"), { alpha = 0.25, z = 6 })
	end
end

-- BirdView --------------------------------------------------------------------------

--[[
	opts:
	  space    Canvas space mapping world units into `parent` (arena) or preview units
	  loadout  { bird, color, pattern, patternColor, patternAlpha, hat }
	  seed     pattern seed
	  ppu      pixels per world unit for stroke widths (defaults to Canvas.ppu)
	  name     optional name tag
]]
function BirdView.new(parent: Instance, opts)
	local self = setmetatable({}, BirdView)
	self.parent = parent
	self.space = opts.space
	self.seed = opts.seed or 1
	self.ppu = opts.ppu
	self.radius = opts.radius or 15
	self.anims = {}
	self.looks = {}
	self.lookKey = ""
	self.wingUp = false
	self.bigWings = false
	self.zBase = opts.z or 20

	local root = Instance.new("Frame")
	root.Name = "Bird"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.ZIndex = self.zBase
	root.Parent = parent
	self.root = root

	self:setLook(opts.loadout or {})
	if opts.name then
		self:setName(opts.name)
	end
	return self
end

function BirdView:withPpu(fn)
	local old = Canvas.ppu
	if self.ppu then
		Canvas.ppu = self.ppu
	end
	fn()
	Canvas.ppu = old
end

function BirdView:setLook(loadout)
	self.loadout = loadout
	local def = Birds.get(loadout.bird)
	self.def = def
	self.color = Canvas.color(loadout.color or def.defaultColor)
	self.rainbow = loadout.color == "rainbow" or loadout.color == "holo"
	if self.rainbow then
		self.color = Color3.fromHex("#ff77ff")
	end
	-- rebuild body + clear cached looks
	if self.body then
		self.body:Destroy()
	end
	if self.outline then
		self.outline:Destroy()
	end
	for _, look in self.looks do
		look.frame:Destroy()
	end
	self.looks = {}
	self.lookKey = ""

	self:withPpu(function()
		local pattern = loadout.pattern or "solid"
		local body: GuiObject
		if pattern ~= "solid" then
			local cg = Instance.new("CanvasGroup")
			cg.BackgroundColor3 = self.color
			cg.BorderSizePixel = 0
			Canvas.corner(cg)
			body = cg
		else
			local f = Instance.new("Frame")
			f.BackgroundColor3 = self.color
			f.BorderSizePixel = 0
			Canvas.corner(f)
			body = f
		end
		body.Name = "Body"
		body.AnchorPoint = Vector2.new(0.5, 0.5)
		body.Position = UDim2.fromScale(0.5, 0.5)
		body.Size = UDim2.fromScale(2 / ROOT_R, 2 / ROOT_R)
		body.ZIndex = self.zBase + 3
		body.Parent = self.root
		local pc = Canvas.color(loadout.patternColor or "#ffffff")
		Patterns.draw(body, pattern, pc, loadout.patternAlpha or 0.6, self.seed, self.zBase + 4)
		-- glossy highlight (upper-left)
		local gloss = Canvas.circle(body, Canvas.space(0.5, 0.5, 0.5, 0.5), -0.3, -0.45, 0.42, {
			color = WHITE,
			alpha = 0.45,
			z = self.zBase + 5,
		})
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Rotation = 45
		g.Parent = gloss
		self.body = body

		local outline = Instance.new("Frame")
		outline.Name = "Outline"
		outline.BackgroundTransparency = 1
		outline.AnchorPoint = Vector2.new(0.5, 0.5)
		outline.Position = UDim2.fromScale(0.5, 0.5)
		outline.Size = body.Size
		outline.ZIndex = self.zBase + 6
		Canvas.corner(outline)
		Canvas.stroke(outline, INK, math.max(1, 2 * Canvas.ppu))
		outline.Parent = self.root
		self.outline = outline
	end)
	self:refreshLook(true)
end

function BirdView:buildLook(fx: number, fy: number)
	local frame = Instance.new("Frame")
	frame.Name = "Look"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = self.zBase
	frame.Parent = self.root
	local anims = {}
	self:withPpu(function()
		local z = self.zBase
		-- body-behind layer (beak, crest) uses z+2, face uses z+7..10, hat z+12
		local behind = makeBuilder(frame, fx, fy, z + 2, anims)
		local sil = self.def.silhouette
		drawBeak(behind, sil.beak)
		drawCrest(behind, sil.crest, self.color)

		local face = makeBuilder(frame, fx, fy, z + 7, anims)
		drawExtra(face, sil.extra)
		drawEye(face, sil.eye, self.color)

		-- wing (white ellipse, rotates with the flap)
		local wing = Canvas.ellipse(frame, S, 0, 0, 0.5, 0.75, {
			color = WHITE,
			stroke = INK,
			strokeW = 1.5,
			z = z + 8,
		})
		self:placeWing(wing, fx, fy, false)

		local hatB = makeBuilder(frame, fx, fy, z + 12, anims)
		local hatFn = Hats[self.loadout.hat or "none"] or Hats.none
		hatFn(hatB)

		self.looks[fx .. "|" .. fy] = { frame = frame, wing = wing, anims = anims, fx = fx, fy = fy }
	end)
	return self.looks[fx .. "|" .. fy]
end

function BirdView:placeWing(wing: GuiObject, fx: number, fy: number, up: boolean)
	local angle = if up then -0.5 else 0.5
	local scale = if self.bigWings then 1.8 else 1
	-- original: ctx.rotate(wingAngle); ellipse(-0.3R, 0.3R, 0.5R, 0.75R, PI/4)
	local px, py = -0.3, 0.3
	local c, s = math.cos(angle), math.sin(angle)
	local rx, ry = px * c - py * s, px * s + py * c
	wing.Position = Canvas.pos(S, rx * fx * scale, ry * fy * scale)
	wing.Size = Canvas.size(S, 1.0 * scale, 1.5 * scale)
	local rot = math.deg(angle) + 45
	wing.Rotation = if fx * fy < 0 then -rot else rot
end

function BirdView:refreshLook(force: boolean?)
	local fx = if (self.dir or 1) >= 0 then 1 else -1
	local fy = if self.upside then -1 else 1
	local key = fx .. "|" .. fy
	if key == self.lookKey and not force then
		return
	end
	for k, look in self.looks do
		look.frame.Visible = k == key
	end
	local look = self.looks[key] or self:buildLook(fx, fy)
	look.frame.Visible = true
	self.lookKey = key
	self.look = look
end

function BirdView:setName(text: string?)
	if not text then
		if self.nameTag then
			self.nameTag:Destroy()
			self.nameTag = nil
		end
		return
	end
	if not self.nameTag then
		self.nameTag = Canvas.text(self.root, {
			text = text,
			position = UDim2.fromScale(0.5, 0.18),
			size = UDim2.fromScale(1.6, 0.11),
			font = Enum.Font.GothamBold,
			color = Color3.new(1, 1, 1),
			strokeColor = Color3.new(0, 0, 0),
			strokeThickness = 1.5,
			z = self.zBase + 30,
		})
	else
		self.nameTag.Text = text
	end
end

--[[
	pose = { x, y, dir, upside, radius, squishX, squishY, wingUp, now, bigWings }
]]
function BirdView:setPose(pose)
	local dirChanged = pose.dir ~= self.dir or pose.upside ~= self.upside
	self.dir = pose.dir
	self.upside = pose.upside
	if dirChanged then
		self:refreshLook(false)
	end
	local r = pose.radius or self.radius
	local sx, sy = pose.squishX or 1, pose.squishY or 1
	local space = self.space
	self.root.Position = Canvas.pos(space, pose.x, pose.y)
	-- quantize stretch so CanvasGroup bodies don't re-render every frame
	sx = math.floor(sx * 20 + 0.5) / 20
	sy = math.floor(sy * 20 + 0.5) / 20
	local size = Canvas.size(space, r * ROOT_R * sx, r * ROOT_R * sy)
	if self.root.Size ~= size then
		self.root.Size = size
	end
	if pose.bigWings ~= self.bigWings or pose.wingUp ~= self.wingUp then
		self.bigWings = pose.bigWings == true
		self.wingUp = pose.wingUp == true
		local look = self.look
		if look then
			self:placeWing(look.wing, look.fx, look.fy, self.wingUp)
		end
	end
	if self.rainbow then
		local hue = ((pose.now or os.clock()) * 0.6) % 1
		self.body.BackgroundColor3 = Color3.fromHSV(hue, 0.55, 1)
	end
	if self.look and #self.look.anims > 0 then
		local t = pose.now or os.clock()
		for _, fn in self.look.anims do
			fn(t)
		end
	end
end

function BirdView:setBodyColor(c: Color3?)
	self.body.BackgroundColor3 = c or self.color
end

function BirdView:setTransparency(alpha: number)
	-- used for ghost mode
	self.body.BackgroundTransparency = alpha
	local st = self.outline:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = alpha
	end
end

function BirdView:setVisible(v: boolean)
	self.root.Visible = v
end

function BirdView:destroy()
	self.root:Destroy()
end

return BirdView
