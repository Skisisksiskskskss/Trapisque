--!strict
-- Builds brainrot models entirely from parts: an object body + animal features + legs + face.
-- Everything is created in model-local space (origin = feet centre, facing -Z), scaled, welded to an anchored
-- invisible Root, then pivoted into place. Used by the server (pedestal brainrots) and clients (wave walkers).

local Brainrots = require(script.Parent.Parent.Config.Brainrots)
local Mutations = require(script.Parent.Parent.Config.Mutations)
local Rarities = require(script.Parent.Parent.Config.Rarities)

type Anchors = {
	bottom: number,
	top: number,
	width: number,
	depth: number,
	front: number, -- z of the front surface (negative)
	back: number, -- z of the back surface (positive)
	faceY: number,
	faceZ: number,
	faceX: number,
	faceScale: number,
	hideEyes: boolean,
	hideMouth: boolean,
	bigEyes: boolean,
	legSpread: number,
}

type Ctx = {
	model: Model,
	parts: { BasePart },
	color: Color3,
	accent: Color3,
	feature: Color3,
	legH: number,
	a: Anchors,
}

local BrainrotBuilder = {}

local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(20, 20, 25)
local ORANGE = Color3.fromRGB(255, 165, 40)
local PINK = Color3.fromRGB(255, 160, 190)
local IVORY = Color3.fromRGB(245, 235, 210)

local function rad(deg: number): number
	return math.rad(deg)
end

local function newPart(
	ctx: Ctx,
	className: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new(className) :: BasePart
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = ctx.model
	table.insert(ctx.parts, part)
	return part
end

local function box(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return newPart(ctx, "Part", size, cf, color, material)
end

local function ball(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part = newPart(ctx, "Part", size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylinder whose axis runs along local X of cf. Use vcyl for upright cylinders.
local function cyl(
	ctx: Ctx,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = newPart(ctx, "Part", Vector3.new(length, diameter, diameter), cf, color, material) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function vcyl(
	ctx: Ctx,
	height: number,
	diameter: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	return cyl(ctx, height, diameter, CFrame.new(pos) * CFrame.Angles(0, 0, rad(90)), color, material)
end

-- Cylinder facing forward (axis along Z), e.g. discs on the front of a body.
local function zcyl(
	ctx: Ctx,
	thickness: number,
	diameter: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	return cyl(ctx, thickness, diameter, CFrame.new(pos) * CFrame.Angles(0, rad(90), 0), color, material)
end

local function wedge(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return newPart(ctx, "WedgePart", size, cf, color, material)
end

local function keep(part: BasePart)
	part:SetAttribute("KeepColor", true)
end

-- Cone made of stacked discs from diameter d0 (bottom) to d1 (top).
local function cone(
	ctx: Ctx,
	base: Vector3,
	height: number,
	d0: number,
	d1: number,
	steps: number,
	color: Color3,
	material: Enum.Material?
)
	local h = height / steps
	for i = 0, steps - 1 do
		local t = i / math.max(steps - 1, 1)
		local d = d0 + (d1 - d0) * t
		vcyl(ctx, h * 1.02, d, base + Vector3.new(0, h * (i + 0.5), 0), color, material)
	end
end

-- Chain of segments following a list of points.
local function chain(ctx: Ctx, points: { Vector3 }, d0: number, d1: number, color: Color3)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local t = (i - 1) / math.max(#points - 2, 1)
		local d = d0 + (d1 - d0) * t
		local length = (p1 - p0).Magnitude
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, p1) * CFrame.Angles(0, rad(90), 0)
		cyl(ctx, length + d * 0.5, d, cf, color)
		ball(ctx, Vector3.one * d, CFrame.new(p1), color)
	end
end

local function defaultAnchors(bottom: number, width: number, height: number, depth: number): Anchors
	return {
		bottom = bottom,
		top = bottom + height,
		width = width,
		depth = depth,
		front = -depth / 2,
		back = depth / 2,
		faceY = bottom + height * 0.6,
		faceZ = -depth / 2,
		faceX = 0,
		faceScale = 1,
		hideEyes = false,
		hideMouth = false,
		bigEyes = false,
		legSpread = width * 0.25,
	}
end

---------------------------------------------------------------------------------------------------------------
-- Bodies. Each builds with its bottom at ctx.legH and returns anchors.
---------------------------------------------------------------------------------------------------------------

local bodies: { [string]: (Ctx) -> Anchors } = {}

bodies.Toaster = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(3, 2.4, 2), CFrame.new(0, b + 1.2, 0), ctx.color, Enum.Material.Metal)
	box(ctx, Vector3.new(3.1, 0.25, 2.1), CFrame.new(0, b + 0.12, 0), ctx.accent)
	for _, x in { -0.65, 0.65 } do
		box(ctx, Vector3.new(0.9, 0.12, 1.4), CFrame.new(x, b + 2.42, 0), ctx.accent)
		box(ctx, Vector3.new(0.7, 0.5, 1.1), CFrame.new(x, b + 2.55, 0), Color3.fromRGB(205, 150, 80))
	end
	box(ctx, Vector3.new(0.3, 0.25, 0.6), CFrame.new(1.6, b + 1.7, 0), ctx.accent)
	return defaultAnchors(b, 3, 2.4, 2)
end

bodies.Burger = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 0.6, 3.2, Vector3.new(0, b + 0.3, 0), ctx.color)
	vcyl(ctx, 0.55, 3.4, Vector3.new(0, b + 0.85, 0), ctx.accent)
	box(
		ctx,
		Vector3.new(2.6, 0.12, 2.6),
		CFrame.new(0, b + 1.15, 0) * CFrame.Angles(0, rad(45), 0),
		Color3.fromRGB(255, 205, 50)
	)
	vcyl(ctx, 0.18, 3.5, Vector3.new(0, b + 1.25, 0), Color3.fromRGB(90, 190, 70))
	ball(ctx, Vector3.new(3.2, 1.8, 3.2), CFrame.new(0, b + 1.5, 0), ctx.color)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		ball(
			ctx,
			Vector3.new(0.18, 0.1, 0.3),
			CFrame.new(math.cos(angle) * 0.9, b + 2.33, math.sin(angle) * 0.9),
			WHITE
		)
	end
	local a = defaultAnchors(b, 3.4, 2.4, 3.2)
	a.faceY = b + 1.75
	a.faceZ = -1.45
	return a
end

bodies.Cup = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 2.8, 2.4, Vector3.new(0, b + 1.4, 0), ctx.color, Enum.Material.Plastic)
	vcyl(ctx, 0.12, 2.15, Vector3.new(0, b + 2.78, 0), ctx.accent)
	box(ctx, Vector3.new(0.7, 0.3, 0.35), CFrame.new(1.45, b + 2.1, 0), ctx.color)
	box(ctx, Vector3.new(0.3, 1.2, 0.35), CFrame.new(1.75, b + 1.5, 0), ctx.color)
	box(ctx, Vector3.new(0.7, 0.3, 0.35), CFrame.new(1.45, b + 0.9, 0), ctx.color)
	local a = defaultAnchors(b, 2.4, 2.8, 2.4)
	a.faceZ = -1.18
	return a
end

bodies.Banana = function(ctx)
	local b = ctx.legH
	local segs = 5
	for i = 0, segs - 1 do
		local t = i / (segs - 1)
		local y = b + 0.5 + t * 3
		local x = math.sin((t - 0.5) * math.pi * 0.9) * -0.1 + (t - 0.5) ^ 2 * 2.2
		local d = 1.5 - math.abs(t - 0.45) * 0.8
		ball(ctx, Vector3.new(d, 1.1, d), CFrame.new(x, y, 0) * CFrame.Angles(0, 0, rad((t - 0.5) * 40)), ctx.color)
	end
	vcyl(ctx, 0.4, 0.3, Vector3.new(0.55, b + 3.95, 0), ctx.accent)
	ball(ctx, Vector3.new(0.4, 0.3, 0.4), CFrame.new(0.55, b + 0.2, 0), ctx.accent)
	local a = defaultAnchors(b, 1.6, 3.8, 1.4)
	a.faceY = b + 2.1
	a.faceZ = -0.62
	a.faceScale = 0.85
	return a
end

bodies.Cone = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(3, 0.3, 3), CFrame.new(0, b + 0.15, 0), Color3.fromRGB(40, 40, 40))
	local steps = 8
	for i = 0, steps - 1 do
		local t = i / (steps - 1)
		local color = if i == 3 or i == 4 then ctx.accent else ctx.color
		vcyl(ctx, 0.42, 2.6 - t * 1.9, Vector3.new(0, b + 0.5 + i * 0.4, 0), color)
	end
	local a = defaultAnchors(b, 2.6, 3.6, 2.4)
	a.faceY = b + 1.3
	a.faceZ = -1.05
	a.faceScale = 0.9
	return a
end

bodies.Cheese = function(ctx)
	local b = ctx.legH
	wedge(ctx, Vector3.new(2.4, 2.4, 3.2), CFrame.new(0, b + 1.2, 0) * CFrame.Angles(0, rad(90), 0), ctx.color)
	for _, p in { Vector3.new(0.6, b + 0.8, -1.22), Vector3.new(-0.5, b + 0.5, -1.22), Vector3.new(1.1, b + 1.6, 0.4) } do
		ball(ctx, Vector3.new(0.5, 0.5, 0.2), CFrame.new(p), ctx.accent)
	end
	local a = defaultAnchors(b, 3.2, 2.4, 2.4)
	a.faceX = 0.45
	a.faceY = b + 1.15
	a.faceZ = -1.2
	a.faceScale = 0.85
	return a
end

bodies.Fridge = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(2.6, 4, 2.2), CFrame.new(0, b + 2, 0), ctx.color)
	box(ctx, Vector3.new(2.62, 0.08, 2.22), CFrame.new(0, b + 2.7, 0), ctx.accent)
	box(ctx, Vector3.new(0.18, 1, 0.2), CFrame.new(-1, b + 3.3, -1.15), ctx.accent, Enum.Material.Metal)
	box(ctx, Vector3.new(0.18, 1.6, 0.2), CFrame.new(-1, b + 1.6, -1.15), ctx.accent, Enum.Material.Metal)
	local a = defaultAnchors(b, 2.6, 4, 2.2)
	a.faceY = b + 3.3
	a.faceX = 0.25
	return a
end

bodies.Pizza = function(ctx)
	local b = ctx.legH
	local h, w, t = 3.4, 3, 0.7
	wedge(
		ctx,
		Vector3.new(t, h, w / 2),
		CFrame.new(-w / 4, b + h / 2 + 0.3, 0) * CFrame.Angles(0, rad(90), 0),
		ctx.color
	)
	wedge(
		ctx,
		Vector3.new(t, h, w / 2),
		CFrame.new(w / 4, b + h / 2 + 0.3, 0) * CFrame.Angles(0, rad(-90), 0),
		ctx.color
	)
	cyl(ctx, w + 0.2, 0.75, CFrame.new(0, b + 0.35, 0), Color3.fromRGB(205, 130, 60))
	for _, p in { Vector3.new(-0.5, b + 1.0, -0.4), Vector3.new(0.55, b + 1.3, -0.4), Vector3.new(0, b + 2.1, -0.4) } do
		zcyl(ctx, 0.1, 0.55, p, ctx.accent)
	end
	local a = defaultAnchors(b, w, h + 0.3, t)
	a.faceY = b + 1.75
	a.faceZ = -0.38
	a.faceScale = 0.75
	return a
end

bodies.Lamp = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 0.3, 2, Vector3.new(0, b + 0.15, 0), ctx.accent)
	vcyl(ctx, 1.8, 0.3, Vector3.new(0, b + 1.1, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	local bulb =
		ball(ctx, Vector3.one * 0.9, CFrame.new(0, b + 2.1, 0), Color3.fromRGB(255, 245, 170), Enum.Material.Neon)
	keep(bulb)
	cone(ctx, Vector3.new(0, b + 1.9, 0), 2, 3.1, 1.6, 5, ctx.color)
	local a = defaultAnchors(b, 3.1, 3.9, 2.6)
	a.faceY = b + 2.8
	a.faceZ = -1.15
	a.faceScale = 0.85
	return a
end

bodies.Teacup = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 0.2, 3.8, Vector3.new(0, b + 0.1, 0), ctx.accent)
	vcyl(ctx, 1.7, 3, Vector3.new(0, b + 1.05, 0), ctx.color)
	vcyl(ctx, 0.1, 2.7, Vector3.new(0, b + 1.9, 0), Color3.fromRGB(150, 90, 50))
	box(ctx, Vector3.new(0.6, 0.9, 0.3), CFrame.new(1.75, b + 1.1, 0), ctx.color)
	local a = defaultAnchors(b, 3, 1.9, 3)
	a.faceY = b + 1.1
	a.faceZ = -1.48
	a.faceScale = 0.85
	return a
end

bodies.Donut = function(ctx)
	local b = ctx.legH
	local cy = b + 1.6
	for i = 0, 11 do
		local angle = i * math.pi / 6
		ball(
			ctx,
			Vector3.new(1.2, 1.2, 1.1),
			CFrame.new(math.cos(angle) * 1.25, cy + math.sin(angle) * 1.25, 0),
			ctx.color
		)
		if math.sin(angle) > -0.2 then
			ball(
				ctx,
				Vector3.new(1.15, 1.15, 0.6),
				CFrame.new(math.cos(angle) * 1.25, cy + math.sin(angle) * 1.25, -0.3),
				ctx.accent
			)
		end
	end
	for i = 0, 7 do
		local angle = i * 0.8 + 0.3
		local sprinkle = box(
			ctx,
			Vector3.new(0.3, 0.08, 0.08),
			CFrame.new(math.cos(angle) * 1.3, cy + math.sin(angle) * 1.3, -0.62) * CFrame.Angles(0, 0, angle),
			Color3.fromHSV(i / 8, 0.7, 1),
			Enum.Material.Neon
		)
		keep(sprinkle)
	end
	local a = defaultAnchors(b, 3.6, 3.2, 1.1)
	a.faceY = cy + 1.25
	a.faceZ = -0.62
	a.faceScale = 0.7
	return a
end

bodies.IceCream = function(ctx)
	local b = ctx.legH
	cone(ctx, Vector3.new(0, b, 0), 2.2, 0.4, 2.1, 6, ctx.accent, Enum.Material.Sand)
	ball(ctx, Vector3.new(2.5, 2.1, 2.5), CFrame.new(0, b + 2.8, 0), ctx.color)
	ball(ctx, Vector3.new(2, 1.8, 2), CFrame.new(0, b + 4.1, 0), ctx.color)
	local cherry = ball(ctx, Vector3.one * 0.6, CFrame.new(0, b + 5.1, 0), Color3.fromRGB(220, 30, 50))
	keep(cherry)
	local a = defaultAnchors(b, 2.5, 5.3, 2.5)
	a.faceY = b + 2.9
	a.faceZ = -1.2
	return a
end

bodies.Sneaker = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(1.9, 0.5, 3.8), CFrame.new(0, b + 0.25, 0), ctx.accent)
	box(ctx, Vector3.new(1.8, 1.5, 2.2), CFrame.new(0, b + 1.2, 0.7), ctx.color)
	ball(ctx, Vector3.new(1.8, 1.2, 1.8), CFrame.new(0, b + 0.85, -0.9), ctx.color)
	for i = 0, 2 do
		box(
			ctx,
			Vector3.new(1.4, 0.1, 0.15),
			CFrame.new(0, b + 1.5 + i * 0.05, -0.1 + i * 0.4) * CFrame.Angles(rad(-25), 0, 0),
			WHITE
		)
	end
	box(ctx, Vector3.new(1.85, 0.6, 0.4), CFrame.new(0, b + 1.8, 1.65), ctx.color)
	local a = defaultAnchors(b, 1.9, 2.2, 3.8)
	a.faceY = b + 1.55
	a.faceZ = -0.42
	a.faceScale = 0.75
	return a
end

bodies.TV = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(3.2, 2.6, 1.6), CFrame.new(0, b + 1.3, 0), ctx.color, Enum.Material.Wood)
	local screen =
		box(ctx, Vector3.new(2.5, 1.9, 0.1), CFrame.new(-0.15, b + 1.35, -0.8), ctx.accent, Enum.Material.Neon)
	keep(screen)
	for _, x in { 1.35 } do
		zcyl(ctx, 0.2, 0.35, Vector3.new(x, b + 1.8, -0.8), Color3.fromRGB(200, 200, 200))
		zcyl(ctx, 0.2, 0.35, Vector3.new(x, b + 1.2, -0.8), Color3.fromRGB(200, 200, 200))
	end
	chain(ctx, { Vector3.new(-0.3, b + 2.6, 0), Vector3.new(-1, b + 3.8, 0) }, 0.1, 0.1, BLACK)
	chain(ctx, { Vector3.new(0.3, b + 2.6, 0), Vector3.new(1.1, b + 3.7, 0) }, 0.1, 0.1, BLACK)
	local a = defaultAnchors(b, 3.2, 2.6, 1.6)
	a.faceX = -0.15
	a.faceY = b + 1.4
	a.faceZ = -0.86
	return a
end

bodies.Watermelon = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.new(3.4, 2.4, 3.4), CFrame.new(0, b + 1.2, 0), ctx.color)
	for _, angle in { -40, 0, 40 } do
		ball(
			ctx,
			Vector3.new(0.35, 2.42, 3.42),
			CFrame.new(0, b + 1.2, 0) * CFrame.Angles(0, rad(angle + 90), 0),
			Color3.fromRGB(30, 110, 40)
		)
	end
	local a = defaultAnchors(b, 3.4, 2.4, 3.4)
	a.faceY = b + 1.4
	a.faceZ = -1.6
	return a
end

bodies.Cactus = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 1, 2.2, Vector3.new(0, b + 0.5, 0), ctx.accent, Enum.Material.Slate)
	vcyl(ctx, 3.2, 1.6, Vector3.new(0, b + 2.4, 0), ctx.color, Enum.Material.Grass)
	ball(ctx, Vector3.one * 1.6, CFrame.new(0, b + 4, 0), ctx.color, Enum.Material.Grass)
	for _, side in { -1, 1 } do
		cyl(ctx, 0.9, 0.7, CFrame.new(side * 1.1, b + 2.3, 0), ctx.color, Enum.Material.Grass)
		vcyl(ctx, 1.2, 0.7, Vector3.new(side * 1.5, b + 2.8, 0), ctx.color, Enum.Material.Grass)
		ball(ctx, Vector3.one * 0.7, CFrame.new(side * 1.5, b + 3.4, 0), ctx.color, Enum.Material.Grass)
	end
	local flower = ball(ctx, Vector3.new(0.6, 0.3, 0.6), CFrame.new(0, b + 4.85, 0), PINK)
	keep(flower)
	local a = defaultAnchors(b, 2.2, 4.8, 1.6)
	a.faceY = b + 3.1
	a.faceZ = -0.8
	a.faceScale = 0.8
	return a
end

bodies.Washer = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(3, 3, 2.6), CFrame.new(0, b + 1.5, 0), ctx.color)
	zcyl(ctx, 0.2, 2.1, Vector3.new(0, b + 1.3, -1.3), Color3.fromRGB(190, 190, 200), Enum.Material.Metal)
	local glass = zcyl(ctx, 0.25, 1.7, Vector3.new(0, b + 1.3, -1.32), ctx.accent, Enum.Material.Glass)
	glass.Transparency = 0.2
	box(ctx, Vector3.new(3.02, 0.5, 0.2), CFrame.new(0, b + 2.7, -1.25), Color3.fromRGB(210, 210, 220))
	local a = defaultAnchors(b, 3, 3, 2.6)
	a.faceY = b + 2.72
	a.faceZ = -1.36
	a.faceScale = 0.7
	return a
end

bodies.Teapot = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.new(3, 2.4, 2.6), CFrame.new(0, b + 1.2, 0), ctx.color, Enum.Material.Glass)
	vcyl(ctx, 0.3, 1.6, Vector3.new(0, b + 2.45, 0), ctx.accent)
	ball(ctx, Vector3.one * 0.5, CFrame.new(0, b + 2.75, 0), ctx.accent)
	cyl(ctx, 1.4, 0.45, CFrame.new(1.8, b + 1.5, 0) * CFrame.Angles(0, 0, rad(40)), ctx.color)
	box(ctx, Vector3.new(0.3, 1.2, 0.3), CFrame.new(-1.75, b + 1.3, 0), ctx.accent)
	local a = defaultAnchors(b, 3, 2.75, 2.6)
	a.faceY = b + 1.35
	a.faceZ = -1.25
	return a
end

bodies.Rocket = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 3.4, 1.9, Vector3.new(0, b + 1.7, 0), ctx.color, Enum.Material.Metal)
	cone(ctx, Vector3.new(0, b + 3.4, 0), 1.4, 1.8, 0.3, 5, ctx.accent)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		wedge(
			ctx,
			Vector3.new(0.2, 1.2, 1),
			CFrame.new(math.cos(angle) * 1.1, b + 0.6, math.sin(angle) * 1.1) * CFrame.Angles(0, -angle + rad(90), 0),
			ctx.accent
		)
	end
	local flame = ball(
		ctx,
		Vector3.new(1.2, 1.4, 1.2),
		CFrame.new(0, b - 0.3, 0),
		Color3.fromRGB(255, 140, 30),
		Enum.Material.Neon
	)
	keep(flame)
	local window =
		zcyl(ctx, 0.15, 0.9, Vector3.new(0, b + 2.8, -0.93), Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
	keep(window)
	local a = defaultAnchors(b, 1.9, 4.8, 1.9)
	a.faceY = b + 1.8
	a.faceZ = -0.93
	a.faceScale = 0.8
	return a
end

bodies.Microphone = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 2.4, 0.8, Vector3.new(0, b + 1.2, 0), ctx.color, Enum.Material.Metal)
	vcyl(ctx, 0.3, 1.1, Vector3.new(0, b + 2.5, 0), ctx.accent, Enum.Material.Metal)
	ball(ctx, Vector3.one * 2.1, CFrame.new(0, b + 3.4, 0), ctx.accent, Enum.Material.DiamondPlate)
	local a = defaultAnchors(b, 2.1, 4.45, 2.1)
	a.faceY = b + 3.45
	a.faceZ = -1
	a.faceScale = 0.8
	return a
end

bodies.Toilet = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 1, 1.6, Vector3.new(0, b + 0.5, -0.2), ctx.color)
	ball(ctx, Vector3.new(2.4, 0.9, 2.8), CFrame.new(0, b + 1.1, -0.4), ctx.color)
	vcyl(ctx, 0.12, 2.2, Vector3.new(0, b + 1.55, -0.4), ctx.accent)
	box(ctx, Vector3.new(2.6, 2.2, 1), CFrame.new(0, b + 2.1, 1.2), ctx.color)
	box(ctx, Vector3.new(2.7, 0.25, 1.1), CFrame.new(0, b + 3.25, 1.2), ctx.accent)
	box(
		ctx,
		Vector3.new(0.5, 0.12, 0.2),
		CFrame.new(-0.8, b + 2.8, 0.65),
		Color3.fromRGB(200, 200, 210),
		Enum.Material.Metal
	)
	local a = defaultAnchors(b, 2.6, 3.4, 3.2)
	a.faceY = b + 2.35
	a.faceZ = 0.68
	a.faceScale = 0.85
	return a
end

bodies.Clock = function(ctx)
	local b = ctx.legH
	zcyl(ctx, 1.1, 3, Vector3.new(0, b + 1.6, 0), ctx.color, Enum.Material.Metal)
	zcyl(ctx, 0.1, 2.5, Vector3.new(0, b + 1.6, -0.55), ctx.accent)
	for _, x in { -1, 1 } do
		ball(
			ctx,
			Vector3.new(1.1, 0.8, 1.1),
			CFrame.new(x, b + 3.1, 0) * CFrame.Angles(0, 0, rad(x * -25)),
			Color3.fromRGB(230, 200, 60),
			Enum.Material.Metal
		)
	end
	box(ctx, Vector3.new(0.12, 0.8, 0.05), CFrame.new(0, b + 1.3, -0.62) * CFrame.Angles(0, 0, rad(30)), BLACK)
	local a = defaultAnchors(b, 3, 3.4, 1.1)
	a.faceY = b + 1.95
	a.faceZ = -0.62
	a.faceScale = 0.8
	return a
end

bodies.Pineapple = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.new(2.6, 3.2, 2.6), CFrame.new(0, b + 1.6, 0), ctx.color)
	for row = 0, 2 do
		for col = -1, 1 do
			box(
				ctx,
				Vector3.new(0.3, 0.3, 0.1),
				CFrame.new(col * 0.7, b + 0.8 + row * 0.6, -1.24) * CFrame.Angles(0, 0, rad(45)),
				Color3.fromRGB(170, 120, 40)
			)
		end
	end
	for i = 0, 6 do
		local angle = i * math.pi * 2 / 7
		wedge(
			ctx,
			Vector3.new(0.2, 1.6, 0.8),
			CFrame.new(math.cos(angle) * 0.35, b + 3.8, math.sin(angle) * 0.35) * CFrame.Angles(0, -angle, rad(-15)),
			ctx.accent,
			Enum.Material.Grass
		)
	end
	local a = defaultAnchors(b, 2.6, 4.4, 2.6)
	a.faceY = b + 2.4
	a.faceZ = -1.15
	return a
end

bodies.Balloon = function(ctx)
	local b = ctx.legH
	local skin = ball(ctx, Vector3.new(2.8, 3.2, 2.8), CFrame.new(0, b + 2.2, 0), ctx.color)
	skin.Reflectance = 0.15
	cone(ctx, Vector3.new(0, b + 0.4, 0), 0.3, 0.2, 0.5, 2, ctx.color)
	vcyl(ctx, 1, 0.06, Vector3.new(0, b - 0.1, 0), ctx.accent)
	local a = defaultAnchors(b, 2.8, 3.8, 2.8)
	a.faceY = b + 2.4
	a.faceZ = -1.35
	return a
end

bodies.Train = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(2.2, 1.8, 3.2), CFrame.new(0, b + 1.2, 0), ctx.color)
	box(ctx, Vector3.new(2.3, 1.4, 1.2), CFrame.new(0, b + 2.6, 1), ctx.color)
	box(ctx, Vector3.new(2.5, 0.2, 1.4), CFrame.new(0, b + 3.4, 1), ctx.accent)
	vcyl(ctx, 1, 0.7, Vector3.new(0, b + 2.6, -0.9), BLACK)
	vcyl(ctx, 0.2, 0.9, Vector3.new(0, b + 3.15, -0.9), ctx.accent)
	for _, z in { -1, 1 } do
		for _, x in { -1.15, 1.15 } do
			cyl(ctx, 0.3, 0.9, CFrame.new(x, b + 0.35, z), BLACK)
		end
	end
	wedge(ctx, Vector3.new(2.2, 0.7, 0.6), CFrame.new(0, b + 0.35, -1.9) * CFrame.Angles(0, rad(180), 0), ctx.accent)
	local a = defaultAnchors(b, 2.3, 3.5, 3.2)
	a.faceY = b + 1.35
	a.faceZ = -1.62
	a.faceScale = 0.85
	return a
end

bodies.Guitar = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.new(2.7, 2.3, 0.8), CFrame.new(0, b + 1.15, 0), ctx.color, Enum.Material.Wood)
	ball(ctx, Vector3.new(2.1, 1.8, 0.8), CFrame.new(0, b + 2.6, 0), ctx.color, Enum.Material.Wood)
	zcyl(ctx, 0.1, 0.8, Vector3.new(0, b + 1.6, -0.4), ctx.accent)
	box(ctx, Vector3.new(0.45, 2.3, 0.35), CFrame.new(0, b + 4.4, 0), ctx.accent, Enum.Material.Wood)
	box(ctx, Vector3.new(0.7, 0.8, 0.35), CFrame.new(0, b + 5.9, 0), ctx.accent, Enum.Material.Wood)
	local a = defaultAnchors(b, 2.7, 6.3, 0.8)
	a.faceY = b + 2.7
	a.faceZ = -0.42
	a.faceScale = 0.8
	return a
end

bodies.Volcano = function(ctx)
	local b = ctx.legH
	cone(ctx, Vector3.new(0, b, 0), 3.2, 3.8, 1.7, 6, ctx.color, Enum.Material.Slate)
	local lava = vcyl(ctx, 0.15, 1.5, Vector3.new(0, b + 3.25, 0), ctx.accent, Enum.Material.Neon)
	keep(lava)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3 + 0.4
		local drip = box(
			ctx,
			Vector3.new(0.35, 1.2, 0.2),
			CFrame.new(math.cos(angle) * 0.95, b + 2.7, math.sin(angle) * 0.95) * CFrame.Angles(0, -angle, rad(15)),
			ctx.accent,
			Enum.Material.Neon
		)
		keep(drip)
	end
	local a = defaultAnchors(b, 3.8, 3.3, 3.8)
	a.faceY = b + 1.5
	a.faceZ = -1.6
	return a
end

bodies.UFO = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.new(4.4, 1.1, 4.4), CFrame.new(0, b + 1, 0), ctx.color, Enum.Material.Metal)
	local dome = ball(ctx, Vector3.new(2.2, 1.6, 2.2), CFrame.new(0, b + 1.6, 0), ctx.accent, Enum.Material.Glass)
	dome.Transparency = 0.3
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local light = ball(
			ctx,
			Vector3.one * 0.35,
			CFrame.new(math.cos(angle) * 2, b + 0.95, math.sin(angle) * 2),
			Color3.fromHSV(i / 8, 0.6, 1),
			Enum.Material.Neon
		)
		keep(light)
	end
	local a = defaultAnchors(b, 4.4, 2.4, 4.4)
	a.faceY = b + 1.75
	a.faceZ = -0.95
	a.faceScale = 0.7
	return a
end

bodies.Blender = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(2.2, 1, 2.2), CFrame.new(0, b + 0.5, 0), ctx.accent)
	local jar = vcyl(ctx, 2.6, 2, Vector3.new(0, b + 2.3, 0), ctx.color, Enum.Material.Glass)
	jar.Transparency = 0.35
	vcyl(ctx, 1.4, 1.75, Vector3.new(0, b + 1.75, 0), ctx.accent)
	vcyl(ctx, 0.3, 2.1, Vector3.new(0, b + 3.7, 0), Color3.fromRGB(60, 60, 70))
	local a = defaultAnchors(b, 2.2, 3.85, 2.2)
	a.faceY = b + 2.5
	a.faceZ = -1.02
	a.faceScale = 0.8
	return a
end

bodies.Spaghetti = function(ctx)
	local b = ctx.legH
	vcyl(ctx, 0.8, 2, Vector3.new(0, b + 0.4, 0), WHITE)
	ball(ctx, Vector3.new(3.4, 1.6, 3.4), CFrame.new(0, b + 1.1, 0), WHITE)
	ball(ctx, Vector3.new(3, 1.2, 3), CFrame.new(0, b + 1.75, 0), ctx.color)
	for i = 0, 9 do
		local angle = i * 2.39
		local noodle = cyl(
			ctx,
			1.6,
			0.18,
			CFrame.new(math.cos(angle) * 0.8, b + 2.2, math.sin(angle) * 0.8)
				* CFrame.Angles(angle, angle * 0.5, rad(20)),
			ctx.color
		)
		noodle.Material = Enum.Material.SmoothPlastic
	end
	vcyl(ctx, 0.15, 1.6, Vector3.new(0, b + 2.3, 0), ctx.accent)
	ball(ctx, Vector3.one * 1.1, CFrame.new(0, b + 2.75, 0), Color3.fromRGB(120, 60, 40))
	local a = defaultAnchors(b, 3.4, 3.3, 3.4)
	a.faceY = b + 1.0
	a.faceZ = -1.6
	return a
end

bodies.Orb = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.one * 3.4, CFrame.new(0, b + 1.7, 0), ctx.color, Enum.Material.Neon)
	cyl(
		ctx,
		0.12,
		5,
		CFrame.new(0, b + 1.7, 0) * CFrame.Angles(0, 0, rad(90)) * CFrame.Angles(rad(20), 0, 0),
		ctx.feature,
		Enum.Material.Neon
	)
	for i = 0, 7 do
		local angle = i * 2.1
		local star = ball(
			ctx,
			Vector3.one * 0.2,
			CFrame.new(math.cos(angle) * 1.2, b + 1.7 + math.sin(angle * 1.7) * 1.1, math.sin(angle) * 1.2),
			WHITE,
			Enum.Material.Neon
		)
		keep(star)
	end
	local a = defaultAnchors(b, 3.4, 3.4, 3.4)
	a.faceY = b + 1.9
	a.faceZ = -1.6
	return a
end

bodies.CrystalGolem = function(ctx)
	local b = ctx.legH
	box(ctx, Vector3.new(2.6, 3, 2), CFrame.new(0, b + 1.5, 0), ctx.color, Enum.Material.Glass)
	local core = ball(ctx, Vector3.one * 1.4, CFrame.new(0, b + 1.5, 0), ctx.accent, Enum.Material.Neon)
	keep(core)
	for _, x in { -1, 1 } do
		box(
			ctx,
			Vector3.new(0.9, 1.8, 0.9),
			CFrame.new(x * 1.6, b + 2.6, 0) * CFrame.Angles(rad(15), 0, rad(x * -25)),
			ctx.color,
			Enum.Material.Glass
		)
		box(ctx, Vector3.new(0.6, 1.8, 0.6), CFrame.new(x * 1.7, b + 1.2, 0), ctx.color, Enum.Material.Glass)
	end
	box(
		ctx,
		Vector3.new(1.6, 1.4, 1.6),
		CFrame.new(0, b + 3.6, 0) * CFrame.Angles(0, rad(45), 0),
		ctx.color,
		Enum.Material.Glass
	)
	local a = defaultAnchors(b, 2.6, 4.3, 2)
	a.faceY = b + 3.6
	a.faceZ = -1.15
	a.faceScale = 0.75
	return a
end

bodies.Moon = function(ctx)
	local b = ctx.legH
	ball(ctx, Vector3.one * 3.4, CFrame.new(0, b + 1.7, 0), ctx.color, Enum.Material.Slate)
	for _, p in { Vector3.new(0.9, b + 2.5, -1.25), Vector3.new(-1.1, b + 1.1, -1.2), Vector3.new(1.2, b + 0.9, -1.1) } do
		ball(
			ctx,
			Vector3.new(0.7, 0.7, 0.3),
			CFrame.lookAt(p, p * Vector3.new(2, 1, 2)),
			ctx.accent,
			Enum.Material.Slate
		)
	end
	local a = defaultAnchors(b, 3.4, 3.4, 3.4)
	a.faceY = b + 1.9
	a.faceZ = -1.62
	return a
end

---------------------------------------------------------------------------------------------------------------
-- Features. They decorate the body and may move the face or hide parts of it.
---------------------------------------------------------------------------------------------------------------

local features: { [string]: (Ctx) -> () } = {}

features.Flippers = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		box(
			ctx,
			Vector3.new(0.25, 1.6, 0.9),
			CFrame.new(side * (a.width / 2 + 0.1), a.bottom + (a.top - a.bottom) * 0.45, 0)
				* CFrame.Angles(0, 0, rad(side * 25)),
			ctx.feature
		)
	end
end

features.Beak = function(ctx)
	local a = ctx.a
	local s = a.faceScale
	wedge(
		ctx,
		Vector3.new(0.7 * s, 0.4 * s, 0.8 * s),
		CFrame.new(a.faceX, a.faceY - 0.35 * s, a.faceZ - 0.35 * s) * CFrame.Angles(0, rad(180), 0),
		ORANGE
	)
	a.hideMouth = true
end

features.DuckBill = function(ctx)
	local a = ctx.a
	local s = a.faceScale
	ball(
		ctx,
		Vector3.new(1.3 * s, 0.35 * s, 1.1 * s),
		CFrame.new(a.faceX, a.faceY - 0.5 * s, a.faceZ - 0.4 * s),
		ORANGE
	)
	ball(
		ctx,
		Vector3.new(1.2 * s, 0.25 * s, 1.0 * s),
		CFrame.new(a.faceX, a.faceY - 0.72 * s, a.faceZ - 0.35 * s),
		ORANGE
	)
	a.hideMouth = true
end

features.FrogEyes = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * a.width * 0.25
		ball(ctx, Vector3.one * 1.1, CFrame.new(x, a.top + 0.3, a.faceZ * 0.5), ctx.feature)
		local eye = ball(ctx, Vector3.one * 0.75, CFrame.new(x, a.top + 0.4, a.faceZ * 0.5 - 0.3), WHITE)
		keep(eye)
		local pupil =
			ball(ctx, Vector3.one * 0.35, CFrame.new(x + side * 0.08, a.top + 0.4, a.faceZ * 0.5 - 0.6), BLACK)
		keep(pupil)
	end
	a.hideEyes = true
end

features.CatEars = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * a.width * 0.28
		wedge(
			ctx,
			Vector3.new(0.25, 1, 0.9),
			CFrame.new(x, a.top + 0.45, 0) * CFrame.Angles(0, rad(90), 0),
			ctx.feature
		)
		local inner = wedge(
			ctx,
			Vector3.new(0.1, 0.7, 0.55),
			CFrame.new(x, a.top + 0.38, -0.14) * CFrame.Angles(0, rad(90), 0),
			PINK
		)
		keep(inner)
	end
end

features.CatTail = function(ctx)
	local a = ctx.a
	local y = a.bottom + 0.5
	chain(ctx, {
		Vector3.new(0, y, a.back),
		Vector3.new(0.2, y + 0.3, a.back + 0.9),
		Vector3.new(0.3, y + 1.3, a.back + 1.3),
		Vector3.new(0.1, y + 2.2, a.back + 1.1),
	}, 0.45, 0.35, ctx.feature)
end

features.MouseEars = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * a.width * 0.35
		zcyl(ctx, 0.2, 1.3, Vector3.new(x, a.top + 0.45, 0), ctx.feature)
		local inner = zcyl(ctx, 0.22, 0.8, Vector3.new(x, a.top + 0.45, -0.02), PINK)
		keep(inner)
	end
end

features.MouseTail = function(ctx)
	local a = ctx.a
	local y = a.bottom + 0.3
	chain(ctx, {
		Vector3.new(0, y, a.back),
		Vector3.new(0.4, y - 0.1, a.back + 1),
		Vector3.new(1, y + 0.5, a.back + 1.6),
		Vector3.new(1.2, y + 1.2, a.back + 1.4),
	}, 0.18, 0.1, PINK)
end

features.Trunk = function(ctx)
	local a = ctx.a
	local s = a.faceScale
	local x, y, z = a.faceX, a.faceY - 0.4 * s, a.faceZ
	chain(ctx, {
		Vector3.new(x, y, z),
		Vector3.new(x, y - 0.5, z - 0.7),
		Vector3.new(x, y - 1.3, z - 0.9),
		Vector3.new(x, y - 1.8, z - 1.3),
	}, 0.6, 0.35, ctx.feature)
	a.hideMouth = true
end

features.BigEars = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		ball(
			ctx,
			Vector3.new(0.3, 1.8, 1.5),
			CFrame.new(side * (a.width / 2 + 0.3), a.faceY, 0) * CFrame.Angles(0, rad(side * 20), 0),
			ctx.feature
		)
	end
end

features.SharkFin = function(ctx)
	local a = ctx.a
	wedge(ctx, Vector3.new(0.3, 1.4, 1.4), CFrame.new(0, a.top + 0.65, 0.3), ctx.feature)
end

features.SharkTail = function(ctx)
	local a = ctx.a
	local y = a.bottom + (a.top - a.bottom) * 0.4
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(0.25, 1.2, 1),
			CFrame.new(0, y + side * 0.5, a.back + 0.5) * CFrame.Angles(rad(side > 0 and 0 or 180), 0, 0),
			ctx.feature
		)
	end
end

features.Teeth = function(ctx)
	local a = ctx.a
	local s = a.faceScale
	box(
		ctx,
		Vector3.new(1.4 * s, 0.35 * s, 0.1),
		CFrame.new(a.faceX, a.faceY - 0.55 * s, a.faceZ - 0.02),
		Color3.fromRGB(120, 20, 30)
	)
	for i = -2, 2 do
		local tooth = wedge(
			ctx,
			Vector3.new(0.22 * s, 0.25 * s, 0.08),
			CFrame.new(a.faceX + i * 0.27 * s, a.faceY - 0.45 * s, a.faceZ - 0.08) * CFrame.Angles(rad(180), 0, 0),
			WHITE
		)
		keep(tooth)
	end
	a.hideMouth = true
end

features.CrabClaws = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * (a.width / 2 + 0.6)
		local y = a.bottom + (a.top - a.bottom) * 0.5
		cyl(ctx, 0.8, 0.3, CFrame.new(side * (a.width / 2 + 0.2), y, 0), ctx.feature)
		ball(ctx, Vector3.new(0.9, 0.7, 1.1), CFrame.new(x, y + 0.3, -0.2), ctx.feature)
		wedge(ctx, Vector3.new(0.4, 0.3, 0.6), CFrame.new(x, y + 0.75, -0.5), ctx.feature)
	end
end

features.StalkEyes = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * 0.5
		vcyl(ctx, 1, 0.15, Vector3.new(x, a.top + 0.5, -0.3), ctx.feature)
		local eye = ball(ctx, Vector3.one * 0.6, CFrame.new(x, a.top + 1.1, -0.3), WHITE)
		keep(eye)
		local pupil = ball(ctx, Vector3.one * 0.3, CFrame.new(x, a.top + 1.1, -0.58), BLACK)
		keep(pupil)
	end
	a.hideEyes = true
end

features.BeeWings = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local wing = ball(
			ctx,
			Vector3.new(0.12, 1.4, 2),
			CFrame.new(side * 0.6, a.top + 0.2, a.back + 0.2) * CFrame.Angles(rad(-30), 0, rad(side * -35)),
			WHITE,
			Enum.Material.Glass
		)
		wing.Transparency = 0.45
		keep(wing)
	end
end

features.Antennae = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		chain(
			ctx,
			{ Vector3.new(side * 0.3, a.top - 0.1, 0), Vector3.new(side * 0.7, a.top + 1, -0.2) },
			0.1,
			0.1,
			BLACK
		)
		ball(ctx, Vector3.one * 0.35, CFrame.new(side * 0.7, a.top + 1.05, -0.2), ctx.feature)
	end
end

features.Humps = function(ctx)
	local a = ctx.a
	for _, z in { -0.3, 0.7 } do
		ball(ctx, Vector3.new(1.1, 1, 1), CFrame.new(0, a.top + 0.2, z), ctx.feature)
	end
end

features.CrocSnout = function(ctx)
	local a = ctx.a
	local y = a.faceY - 0.45
	box(ctx, Vector3.new(1.3, 0.55, 1.8), CFrame.new(a.faceX, y, a.front - 0.85), ctx.feature)
	box(ctx, Vector3.new(1.25, 0.35, 1.7), CFrame.new(a.faceX, y - 0.42, a.front - 0.8), ctx.feature)
	for i = 0, 3 do
		for _, side in { -1, 1 } do
			local tooth = wedge(
				ctx,
				Vector3.new(0.12, 0.2, 0.15),
				CFrame.new(a.faceX + side * 0.55, y - 0.32, a.front - 0.2 - i * 0.45) * CFrame.Angles(rad(180), 0, 0),
				WHITE
			)
			keep(tooth)
		end
	end
	a.hideMouth = true
end

features.MonkeyArms = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * (a.width / 2 + 0.25)
		local y = a.bottom + (a.top - a.bottom) * 0.65
		chain(
			ctx,
			{ Vector3.new(x, y, 0), Vector3.new(x + side * 0.5, y - 1, -0.2), Vector3.new(x + side * 0.6, y - 2, -0.4) },
			0.35,
			0.3,
			ctx.feature
		)
		ball(ctx, Vector3.one * 0.55, CFrame.new(x + side * 0.6, y - 2.2, -0.4), ctx.feature)
	end
end

features.MonkeyEars = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * (a.width / 2 + 0.15), a.faceY + 0.2, 0) * CFrame.Angles(0, rad(90), 0)
		cyl(ctx, 0.2, 0.9, cf * CFrame.Angles(0, rad(90), 0), ctx.feature)
	end
end

features.TurtleHead = function(ctx)
	local a = ctx.a
	local y = a.bottom + 1.1
	cyl(ctx, 0.8, 0.8, CFrame.new(0, y, a.front - 0.3) * CFrame.Angles(0, rad(90), 0), ctx.feature)
	ball(ctx, Vector3.new(1.5, 1.4, 1.5), CFrame.new(0, y + 0.3, a.front - 0.9), ctx.feature)
	a.faceY = y + 0.35
	a.faceZ = a.front - 1.6
	a.faceX = 0
	a.faceScale = 0.6
end

features.OwlTufts = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(0.2, 0.8, 0.6),
			CFrame.new(side * 0.55, a.top + 0.3, 0) * CFrame.Angles(0, rad(90), rad(side * -15)),
			ctx.feature
		)
	end
	a.bigEyes = true
end

features.Wings = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		ball(
			ctx,
			Vector3.new(0.3, 1.8, 1.4),
			CFrame.new(side * (a.width / 2 + 0.15), a.bottom + (a.top - a.bottom) * 0.5, 0.2)
				* CFrame.Angles(rad(15), 0, rad(side * 15)),
			ctx.feature
		)
	end
end

features.DragonWings = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local base = CFrame.new(side * 0.7, a.top - 0.3, a.back + 0.1)
		wedge(
			ctx,
			Vector3.new(0.15, 1.6, 2),
			base * CFrame.Angles(0, rad(side * 70), rad(side * -20)) * CFrame.new(0, 0.4, 0.9),
			ctx.feature
		)
		wedge(
			ctx,
			Vector3.new(0.15, 1.1, 1.4),
			base * CFrame.Angles(0, rad(side * 70), rad(side * -50)) * CFrame.new(0, 0.6, 1.6),
			ctx.feature
		)
	end
end

features.Horns = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * a.width * 0.25, a.top - 0.05, 0)
		for i = 0, 2 do
			vcyl(ctx, 0.3, 0.45 - i * 0.12, base + Vector3.new(side * i * 0.08, 0.15 + i * 0.28, 0), IVORY)
		end
	end
end

features.CapybaraHead = function(ctx)
	local a = ctx.a
	local y = a.top + 0.7
	ball(ctx, Vector3.new(1.9, 1.5, 2.3), CFrame.new(0, y, -0.2), ctx.feature)
	box(ctx, Vector3.new(1.3, 0.9, 0.8), CFrame.new(0, y - 0.15, -1.25), ctx.feature)
	for _, side in { -1, 1 } do
		ball(ctx, Vector3.new(0.4, 0.4, 0.25), CFrame.new(side * 0.6, y + 0.75, 0.2), ctx.feature)
	end
	local nose = box(ctx, Vector3.new(0.6, 0.2, 0.1), CFrame.new(0, y + 0.05, -1.66), BLACK)
	keep(nose)
	a.faceY = y + 0.35
	a.faceZ = -1.1
	a.faceX = 0
	a.faceScale = 0.6
	a.hideMouth = true
	a.top = y + 0.8
end

features.GiraffeNeck = function(ctx)
	local a = ctx.a
	vcyl(ctx, 2.2, 0.8, Vector3.new(0, a.top + 1, 0), ctx.feature)
	for i = 0, 2 do
		local spot = zcyl(
			ctx,
			0.05,
			0.35,
			Vector3.new(0.15 * (i % 2 == 0 and 1 or -1), a.top + 0.4 + i * 0.6, -0.4),
			Color3.fromRGB(140, 80, 30)
		)
		keep(spot)
	end
	local y = a.top + 2.4
	ball(ctx, Vector3.new(1.3, 1.1, 1.9), CFrame.new(0, y, -0.3), ctx.feature)
	for _, side in { -1, 1 } do
		vcyl(ctx, 0.5, 0.15, Vector3.new(side * 0.3, y + 0.75, 0), Color3.fromRGB(140, 80, 30))
		ball(ctx, Vector3.one * 0.25, CFrame.new(side * 0.3, y + 1, 0), Color3.fromRGB(140, 80, 30))
	end
	a.faceY = y + 0.1
	a.faceZ = -1.2
	a.faceX = 0
	a.faceScale = 0.55
	a.top = y + 1.1
end

features.GorillaArms = function(ctx)
	local a = ctx.a
	for _, side in { -1, 1 } do
		local x = side * (a.width / 2 + 0.5)
		local y = a.bottom + (a.top - a.bottom) * 0.7
		ball(ctx, Vector3.one * 1.2, CFrame.new(x, y, 0), ctx.feature)
		chain(ctx, {
			Vector3.new(x, y, 0),
			Vector3.new(x + side * 0.4, y - 1.2, -0.3),
			Vector3.new(x + side * 0.3, a.bottom + 0.2, -0.5),
		}, 0.9, 0.7, ctx.feature)
		ball(ctx, Vector3.one * 1, CFrame.new(x + side * 0.3, a.bottom + 0.1, -0.6), ctx.feature)
	end
end

features.Mane = function(ctx)
	local a = ctx.a
	local s = a.faceScale
	for i = 0, 11 do
		local angle = i * math.pi / 6
		ball(
			ctx,
			Vector3.new(0.9, 0.9, 0.6) * s,
			CFrame.new(a.faceX + math.cos(angle) * 1.25 * s, a.faceY + math.sin(angle) * 1.25 * s, a.faceZ + 0.25),
			ctx.feature
		)
	end
end

features.Horn = function(ctx)
	local a = ctx.a
	local base = Vector3.new(0, a.top - 0.1, a.faceZ * 0.5)
	for i = 0, 4 do
		local d = 0.6 - i * 0.11
		local part = vcyl(
			ctx,
			0.35,
			d,
			base + Vector3.new(0, 0.18 + i * 0.32, -i * 0.06),
			Color3.fromRGB(255, 215, 80),
			Enum.Material.Foil
		)
		keep(part)
	end
end

features.Caterpillar = function(ctx)
	local a = ctx.a
	for i = 1, 3 do
		local z = a.back + i * 1.05
		ball(ctx, Vector3.one * (1.5 - i * 0.15), CFrame.new(0, a.bottom + 0.9, z), ctx.feature)
		for _, side in { -1, 1 } do
			vcyl(ctx, 0.6, 0.15, Vector3.new(side * 0.5, a.bottom + 0.15, z), BLACK)
		end
	end
end

features.PeacockTail = function(ctx)
	local a = ctx.a
	for i = -3, 3 do
		local angle = rad(i * 22)
		local cf = CFrame.new(0, a.bottom + 1, a.back + 0.1) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 2, 0.2)
		local hue = (i + 3) / 7 * 0.35 + 0.35
		local feather = ball(ctx, Vector3.new(0.9, 3.4, 0.15), cf, Color3.fromHSV(hue, 0.7, 0.85))
		keep(feather)
		local spot = ball(ctx, Vector3.new(0.5, 0.5, 0.18), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(30, 60, 140))
		keep(spot)
	end
end

features.Comb = function(ctx)
	local a = ctx.a
	for i = -1, 1 do
		local comb = ball(
			ctx,
			Vector3.new(0.3, 0.8, 0.7),
			CFrame.new(0, a.top + 0.3 + (1 - math.abs(i)) * 0.15, i * 0.45),
			Color3.fromRGB(230, 40, 40)
		)
		keep(comb)
	end
end

features.WhaleTail = function(ctx)
	local a = ctx.a
	local y = a.bottom + (a.top - a.bottom) * 0.5
	box(ctx, Vector3.new(0.6, 0.6, 1.2), CFrame.new(0, y, a.back + 0.5), ctx.feature)
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(1.2, 0.2, 0.9),
			CFrame.new(side * 0.6, y + 0.2, a.back + 1.2) * CFrame.Angles(0, rad(side * 90), rad(side * -10)),
			ctx.feature
		)
	end
end

features.Spout = function(ctx)
	local a = ctx.a
	for i = 0, 2 do
		local water = vcyl(
			ctx,
			0.5,
			0.35 - i * 0.05,
			Vector3.new(0, a.top + 0.3 + i * 0.5, 0.2),
			Color3.fromRGB(120, 200, 255),
			Enum.Material.Neon
		)
		water.Transparency = 0.3
		keep(water)
	end
	for _, side in { -1, 1 } do
		local drop = ball(
			ctx,
			Vector3.one * 0.35,
			CFrame.new(side * 0.45, a.top + 1.6, 0.2),
			Color3.fromRGB(120, 200, 255),
			Enum.Material.Neon
		)
		keep(drop)
	end
end

features.DinoHead = function(ctx)
	local a = ctx.a
	local y = a.top + 0.9
	box(ctx, Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, y, 0), ctx.feature)
	box(ctx, Vector3.new(1.4, 0.8, 1.3), CFrame.new(0, y - 0.2, -1.3), ctx.feature)
	for i = 0, 2 do
		for _, side in { -1, 1 } do
			local tooth = wedge(
				ctx,
				Vector3.new(0.12, 0.2, 0.15),
				CFrame.new(side * 0.6, y - 0.7, -0.9 - i * 0.35) * CFrame.Angles(rad(180), 0, 0),
				WHITE
			)
			keep(tooth)
		end
	end
	a.faceY = y + 0.25
	a.faceZ = -0.82
	a.faceX = 0
	a.faceScale = 0.6
	a.hideMouth = true
	a.top = y + 0.7
end

features.DinoTail = function(ctx)
	local a = ctx.a
	local y = a.bottom + 0.8
	chain(ctx, {
		Vector3.new(0, y, a.back - 0.2),
		Vector3.new(0, y - 0.1, a.back + 1),
		Vector3.new(0.3, y - 0.3, a.back + 2),
		Vector3.new(0.6, y - 0.4, a.back + 2.8),
	}, 0.9, 0.35, ctx.feature)
end

features.Crown = function(ctx)
	local a = ctx.a
	local gold = Color3.fromRGB(255, 205, 50)
	local y = a.top + 0.25
	local band = vcyl(ctx, 0.5, 1.6, Vector3.new(0, y, 0), gold, Enum.Material.Foil)
	keep(band)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local spike = wedge(
			ctx,
			Vector3.new(0.2, 0.6, 0.4),
			CFrame.new(math.cos(angle) * 0.7, y + 0.5, math.sin(angle) * 0.7) * CFrame.Angles(0, -angle + rad(90), 0),
			gold,
			Enum.Material.Foil
		)
		keep(spike)
	end
	local gem = ball(ctx, Vector3.one * 0.3, CFrame.new(0, y, -0.8), Color3.fromRGB(230, 40, 80), Enum.Material.Neon)
	keep(gem)
	a.top = y + 0.8
end

features.Halo = function(ctx)
	local a = ctx.a
	local y = a.top + 0.8
	for i = 0, 9 do
		local angle = i * math.pi / 5
		local dot = ball(
			ctx,
			Vector3.one * 0.3,
			CFrame.new(math.cos(angle) * 0.8, y, math.sin(angle) * 0.8),
			Color3.fromRGB(255, 250, 200),
			Enum.Material.Neon
		)
		keep(dot)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Legs
---------------------------------------------------------------------------------------------------------------

local legHeights: { [string]: number } = {
	Stick = 1.6,
	Stubby = 0.8,
	Webbed = 0.9,
	Frog = 1.0,
	Flamingo = 3.0,
	Chicken = 1.6,
	Crab = 1.0,
	Tentacles = 1.4,
	None = 1.0,
}

local function buildLegs(ctx: Ctx, style: string)
	local a = ctx.a
	local h = ctx.legH
	local spread = math.clamp(a.legSpread, 0.5, 1.2)
	if style == "Stick" then
		for _, side in { -1, 1 } do
			vcyl(ctx, h, 0.3, Vector3.new(side * spread, h / 2, 0), BLACK)
			box(ctx, Vector3.new(0.6, 0.35, 0.95), CFrame.new(side * spread, 0.18, -0.15), WHITE)
		end
	elseif style == "Stubby" then
		for _, side in { -1, 1 } do
			vcyl(ctx, h + 0.1, 0.9, Vector3.new(side * spread, h / 2, 0), ctx.feature)
		end
	elseif style == "Webbed" or style == "Frog" then
		local color = if style == "Frog" then ctx.feature else ORANGE
		for _, side in { -1, 1 } do
			vcyl(ctx, h, 0.3, Vector3.new(side * spread, h / 2 + 0.1, 0), color)
			wedge(
				ctx,
				Vector3.new(0.8, 0.2, 0.9),
				CFrame.new(side * spread, 0.1, -0.35) * CFrame.Angles(0, rad(180), 0),
				color
			)
		end
	elseif style == "Flamingo" then
		local color = if ctx.feature == BLACK then PINK else Color3.fromRGB(255, 130, 170)
		for _, side in { -1, 1 } do
			vcyl(ctx, h * 0.5, 0.2, Vector3.new(side * spread * 0.6, h * 0.75, 0), color)
			ball(ctx, Vector3.one * 0.3, CFrame.new(side * spread * 0.6, h * 0.5, 0), color)
			vcyl(ctx, h * 0.5, 0.2, Vector3.new(side * spread * 0.6, h * 0.25, 0), color)
			wedge(
				ctx,
				Vector3.new(0.5, 0.15, 0.6),
				CFrame.new(side * spread * 0.6, 0.08, -0.25) * CFrame.Angles(0, rad(180), 0),
				color
			)
		end
	elseif style == "Chicken" then
		local yellow = Color3.fromRGB(250, 190, 40)
		for _, side in { -1, 1 } do
			vcyl(ctx, h, 0.25, Vector3.new(side * spread, h / 2, 0), yellow)
			for _, angle in { -30, 0, 30 } do
				box(
					ctx,
					Vector3.new(0.12, 0.12, 0.6),
					CFrame.new(side * spread, 0.06, 0) * CFrame.Angles(0, rad(angle), 0) * CFrame.new(0, 0, -0.3),
					yellow
				)
			end
		end
	elseif style == "Crab" then
		for _, side in { -1, 1 } do
			for i = -1, 1 do
				chain(ctx, {
					Vector3.new(side * a.width * 0.35, h, i * 0.5),
					Vector3.new(side * (a.width * 0.35 + 0.7), h * 0.6, i * 0.6),
					Vector3.new(side * (a.width * 0.35 + 0.9), 0.05, i * 0.7),
				}, 0.18, 0.14, ctx.feature)
			end
		end
	elseif style == "Tentacles" then
		for i = 0, 5 do
			local angle = i * math.pi / 3
			local dx, dz = math.cos(angle), math.sin(angle)
			chain(ctx, {
				Vector3.new(dx * 0.6, h + 0.2, dz * 0.6),
				Vector3.new(dx * 0.9, h * 0.5, dz * 0.9),
				Vector3.new(dx * 1.3, 0.15, dz * 1.3),
				Vector3.new(dx * 1.7, 0.25, dz * 1.7),
			}, 0.45, 0.2, ctx.feature)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Face
---------------------------------------------------------------------------------------------------------------

local function buildFace(ctx: Ctx, style: string)
	local a = ctx.a
	local s = a.faceScale
	local x, y, z = a.faceX, a.faceY, a.faceZ
	if not a.hideEyes then
		local eyeSize = (if a.bigEyes then 0.85 else 0.62) * s
		for _, side in { -1, 1 } do
			local ex = x + side * 0.42 * s
			if a.bigEyes then
				local ring =
					zcyl(ctx, 0.08, eyeSize * 1.45, Vector3.new(ex, y, z - 0.02), Color3.fromRGB(255, 220, 120))
				keep(ring)
			end
			local eye = ball(ctx, Vector3.new(eyeSize, eyeSize, eyeSize * 0.5), CFrame.new(ex, y, z - 0.05), WHITE)
			keep(eye)
			local px = ex
			local py = y
			if style == "Derp" then
				px += side * 0.08 * s
				py += side * 0.08 * s
			end
			local pupil = ball(
				ctx,
				Vector3.new(eyeSize * 0.48, eyeSize * 0.48, eyeSize * 0.3),
				CFrame.new(px, py, z - 0.2 * s),
				BLACK
			)
			keep(pupil)
			if style == "Angry" then
				local brow = box(
					ctx,
					Vector3.new(0.5 * s, 0.12 * s, 0.08),
					CFrame.new(ex, y + 0.42 * s, z - 0.08) * CFrame.Angles(0, 0, rad(side * 20)),
					BLACK
				)
				keep(brow)
			end
		end
		if style == "Cool" then
			local shades = box(ctx, Vector3.new(1.5 * s, 0.38 * s, 0.1), CFrame.new(x, y + 0.02, z - 0.28 * s), BLACK)
			shades.Reflectance = 0.3
			keep(shades)
		end
	end
	if not a.hideMouth then
		local my = y - 0.55 * s
		if style == "Happy" or style == "Cool" then
			for i = -1, 1 do
				local seg = box(
					ctx,
					Vector3.new(0.28 * s, 0.1 * s, 0.06),
					CFrame.new(x + i * 0.24 * s, my + math.abs(i) * 0.08 * s, z - 0.04)
						* CFrame.Angles(0, 0, rad(i * 25)),
					BLACK
				)
				keep(seg)
			end
		elseif style == "Derp" then
			local mouth = ball(
				ctx,
				Vector3.new(0.45 * s, 0.35 * s, 0.08),
				CFrame.new(x + 0.1 * s, my, z - 0.04),
				Color3.fromRGB(120, 20, 30)
			)
			keep(mouth)
			local tongue =
				ball(ctx, Vector3.new(0.22 * s, 0.18 * s, 0.06), CFrame.new(x + 0.12 * s, my - 0.1 * s, z - 0.07), PINK)
			keep(tongue)
		else
			local mouth = box(ctx, Vector3.new(0.6 * s, 0.1 * s, 0.06), CFrame.new(x, my, z - 0.04), BLACK)
			keep(mouth)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Mutation + rarity dressing
---------------------------------------------------------------------------------------------------------------

local function applyMutation(model: Model, parts: { BasePart }, mutationName: string)
	local mutation = Mutations.Get(mutationName)
	if mutation.Name == "None" or mutation.Color == nil then
		return
	end
	local tint = mutation.Color :: Color3
	for _, part in parts do
		if part:GetAttribute("KeepColor") then
			continue
		end
		if mutation.Name == "Gold" then
			part.Color = part.Color:Lerp(tint, 0.75)
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0.35
		elseif mutation.Name == "Diamond" then
			part.Color = part.Color:Lerp(tint, 0.7)
			part.Material = Enum.Material.Glass
			part.Transparency = math.max(part.Transparency, 0.12)
		elseif mutation.Name == "Rainbow" then
			part.Material = Enum.Material.SmoothPlastic
		elseif mutation.Name == "Galaxy" then
			part.Color = part.Color:Lerp(tint, 0.8)
			part.Material = Enum.Material.Glass
		end
	end
	if mutation.Name == "Rainbow" then
		for i, part in parts do
			if not part:GetAttribute("KeepColor") then
				part.Color = Color3.fromHSV((i * 0.07) % 1, 0.75, 1)
			end
		end
		model:SetAttribute("Rainbow", true)
	end
end

local function addAura(root: BasePart, color: Color3, rate: number, texture: string)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 2, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = rate
	emitter.Parent = attachment
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function dress(model: Model, root: BasePart, rarityIndex: number, mutationName: string)
	local rarity = Rarities.Get(rarityIndex)
	if rarityIndex >= 5 then
		local light = Instance.new("PointLight")
		light.Color = if rarityIndex == 8 then Color3.new(1, 1, 1) else rarity.Color
		light.Range = 12
		light.Brightness = 1.4
		light.Parent = root
		addAura(
			root,
			if rarityIndex == 8 then Color3.new(1, 1, 1) else rarity.Color,
			4 + (rarityIndex - 5) * 4,
			SPARKLE
		)
	end
	if mutationName == "Diamond" then
		addAura(root, Color3.fromRGB(200, 240, 255), 6, SPARKLE)
	elseif mutationName == "Galaxy" then
		addAura(root, Color3.fromRGB(200, 160, 255), 12, SPARKLE)
	elseif mutationName == "Gold" then
		addAura(root, Color3.fromRGB(255, 220, 90), 3, SPARKLE)
	end
	model:SetAttribute("RarityIndex", rarityIndex)
end

---------------------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------------------

export type BuildOptions = {
	Mutation: string?,
	Scale: number?,
	Effects: boolean?, -- particles/lights (off for tiny UI previews)
}

-- Returns a Model whose pivot is the feet centre, facing -Z, with an anchored invisible Root as PrimaryPart.
function BrainrotBuilder.Build(id: string, options: BuildOptions?): Model
	local def = Brainrots.Get(id)
	assert(def ~= nil, "unknown brainrot " .. id)
	local opts: BuildOptions = options or {}
	local mutation = opts.Mutation or "None"
	local scale = opts.Scale or 1

	local model = Instance.new("Model")
	model.Name = def.Name
	local ctx: Ctx = {
		model = model,
		parts = {},
		color = def.BodyColor,
		accent = def.Accent,
		feature = def.FeatureColor,
		legH = legHeights[def.Legs] or 1,
		a = defaultAnchors(0, 2, 2, 2),
	}

	local bodyBuilder = bodies[def.Body]
	assert(bodyBuilder ~= nil, "unknown body kit " .. def.Body)
	ctx.a = bodyBuilder(ctx)
	for _, featureName in def.Features do
		local featureBuilder = features[featureName]
		assert(featureBuilder ~= nil, "unknown feature kit " .. featureName)
		featureBuilder(ctx)
	end
	buildFace(ctx, def.Face)
	buildLegs(ctx, def.Legs)

	-- Scale every part around the feet origin.
	if scale ~= 1 then
		for _, part in ctx.parts do
			local cf = part.CFrame
			part.Size *= scale
			part.CFrame = CFrame.new(cf.Position * scale) * cf.Rotation
		end
	end

	applyMutation(model, ctx.parts, mutation)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	for _, part in ctx.parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	if opts.Effects ~= false then
		dress(model, root, def.Rarity, mutation)
	end

	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Height", (ctx.a.top + 0.3) * scale)
	model:SetAttribute("Width", math.max(ctx.a.width, ctx.a.depth) * scale)
	return model
end

local dimensionCache: { [string]: Vector2 } = {}

-- Natural (unscaled) width/height of a brainrot, measured once and cached.
function BrainrotBuilder.Dimensions(id: string): Vector2
	local cached = dimensionCache[id]
	if cached then
		return cached
	end
	local probe = BrainrotBuilder.Build(id, { Effects = false })
	local dims = Vector2.new(probe:GetAttribute("Width") :: number, probe:GetAttribute("Height") :: number)
	probe:Destroy()
	dimensionCache[id] = dims
	return dims
end

-- Scale that fits a brainrot inside a box of the given height and width (used for pedestals and UI).
function BrainrotBuilder.FitScale(id: string, maxHeight: number, maxWidth: number): number
	local dims = BrainrotBuilder.Dimensions(id)
	return math.min(maxHeight / dims.Y, maxWidth / dims.X, 1.4)
end

function BrainrotBuilder.HasKits(def: Brainrots.BrainrotDef): (boolean, string?)
	if bodies[def.Body] == nil then
		return false, "body " .. def.Body
	end
	for _, featureName in def.Features do
		if features[featureName] == nil then
			return false, "feature " .. featureName
		end
	end
	if legHeights[def.Legs] == nil then
		return false, "legs " .. def.Legs
	end
	return true, nil
end

return BrainrotBuilder
