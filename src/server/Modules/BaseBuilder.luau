--!strict
-- Builds a themed base (walls, door, pillar, crystal, pedestals) from parts. Pure geometry: no game state.
-- Local space: origin = plot centre on the ground, -Z faces the map centre (the door side), floor top at y = 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Themes = require(Shared.Config.Themes)
local Economy = require(Shared.Config.Economy)

local BaseBuilder = {}

BaseBuilder.Size = 64
BaseBuilder.WallHeight = 12
BaseBuilder.DoorWidth = 12
BaseBuilder.FloorTop = 1
BaseBuilder.CrystalHeight = 30

local SLOT_POSITIONS: { Vector3 } = {}
do
	local rows = { -20, -12, -4, 4, 12, 20 }
	for _, column in { 16, 25 } do
		for _, z in rows do
			table.insert(SLOT_POSITIONS, Vector3.new(-column, 0, z))
			table.insert(SLOT_POSITIONS, Vector3.new(column, 0, z))
		end
	end
end
BaseBuilder.SlotPositions = SLOT_POSITIONS
BaseBuilder.MaxSlots = #SLOT_POSITIONS

type Builder = {
	root: CFrame,
	parent: Instance,
}

local function part(
	b: Builder,
	size: Vector3,
	localCf: CFrame,
	color: Color3,
	material: Enum.Material,
	name: string?,
	className: string?
): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Name = name or "Part"
	p.Size = size
	p.CFrame = b.root * localCf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = b.parent
	return p
end

local function cylinder(
	b: Builder,
	height: number,
	diameter: number,
	localPos: Vector3,
	color: Color3,
	material: Enum.Material,
	name: string?
): BasePart
	local p = part(
		b,
		Vector3.new(height, diameter, diameter),
		CFrame.new(localPos) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		name
	);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

local function sphere(b: Builder, size: Vector3, localCf: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = part(b, size, localCf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function noCollide(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

---------------------------------------------------------------------------------------------------------------
-- Crystal styles. Each builds around local origin (crystal centre) and returns nothing; parts go in b.parent.
---------------------------------------------------------------------------------------------------------------

local crystalStyles: { [string]: (Builder, Themes.Theme, number) -> () } = {}

local function shard(
	b: Builder,
	height: number,
	width: number,
	localCf: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local mat = material or Enum.Material.Glass
	local body = part(b, Vector3.new(width, height, width), localCf, color, mat)
	body.Transparency = 0.15
	noCollide(body)
	local tip = part(
		b,
		Vector3.new(width, width * 1.2, width),
		localCf * CFrame.new(0, height / 2 + width * 0.6, 0) * CFrame.Angles(0, math.rad(45), 0),
		color,
		mat,
		"Tip",
		"WedgePart"
	)
	tip.Transparency = 0.15
	noCollide(tip)
end

crystalStyles.Totem = function(b, theme, s)
	local wood = Color3.fromRGB(110, 75, 45)
	local c1 = cylinder(b, 3 * s, 2.2 * s, Vector3.new(0, -2.5 * s, 0), wood, Enum.Material.Wood)
	noCollide(c1)
	shard(b, 3.2 * s, 2.2 * s, CFrame.new(0, 0.6 * s, 0) * CFrame.Angles(0, math.rad(20), math.rad(8)), theme.Crystal)
	shard(b, 2 * s, 1.2 * s, CFrame.new(1.2 * s, 0, 0.3 * s) * CFrame.Angles(0, 0, math.rad(-25)), theme.Crystal)
	shard(
		b,
		1.8 * s,
		1.1 * s,
		CFrame.new(-1.1 * s, -0.2 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(25)),
		theme.Crystal
	)
end

crystalStyles.Obelisk = function(b, theme, s)
	shard(b, 6 * s, 2.4 * s, CFrame.new(0, 0, 0), theme.Crystal)
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		shard(
			b,
			2.2 * s,
			1 * s,
			CFrame.new(math.cos(angle) * 1.6 * s, -2 * s, math.sin(angle) * 1.6 * s)
				* CFrame.Angles(math.sin(angle) * 0.4, 0, -math.cos(angle) * 0.4),
			theme.Crystal
		)
	end
end

crystalStyles.Prism = function(b, theme, s)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		shard(
			b,
			6.5 * s,
			1.5 * s,
			CFrame.new(math.cos(angle) * 0.9 * s, 0, math.sin(angle) * 0.9 * s) * CFrame.Angles(0, angle, math.rad(6)),
			theme.Crystal
		)
	end
	local ring =
		cylinder(b, 0.4 * s, 5 * s, Vector3.new(0, -1.5 * s, 0), Color3.fromRGB(70, 72, 80), Enum.Material.Metal)
	noCollide(ring)
end

crystalStyles.Gem = function(b, theme, s)
	local gem = part(
		b,
		Vector3.one * 4 * s,
		CFrame.Angles(math.rad(45), 0, math.rad(35.26)),
		theme.Crystal,
		Enum.Material.Glass
	)
	gem.Transparency = 0.1
	gem.Reflectance = 0.2
	noCollide(gem)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local small = part(
			b,
			Vector3.one * 1.1 * s,
			CFrame.new(math.cos(angle) * 3.4 * s, -1 * s, math.sin(angle) * 3.4 * s)
				* CFrame.Angles(math.rad(45), angle, math.rad(35)),
			Color3.fromRGB(255, 255, 255),
			Enum.Material.Glass
		)
		small.Transparency = 0.2
		noCollide(small)
	end
end

crystalStyles.Shards = function(b, theme, s)
	shard(b, 5.5 * s, 1.8 * s, CFrame.new(0, 0, 0), theme.Crystal, Enum.Material.Ice)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		shard(
			b,
			(2.5 + (i % 2)) * s,
			1.1 * s,
			CFrame.new(math.cos(angle) * 1.4 * s, -1.2 * s, math.sin(angle) * 1.4 * s)
				* CFrame.Angles(math.sin(angle) * 0.6, 0, -math.cos(angle) * 0.6),
			theme.Crystal,
			Enum.Material.Ice
		)
	end
end

crystalStyles.Core = function(b, theme, s)
	local core = sphere(b, Vector3.one * 4 * s, CFrame.identity, theme.Crystal, Enum.Material.Neon)
	noCollide(core)
	for i = 0, 2 do
		local ring = part(
			b,
			Vector3.new(0.35 * s, 6.5 * s, 6.5 * s),
			CFrame.Angles(i * 1.05, i * 0.7, 0),
			Color3.fromRGB(40, 35, 35),
			Enum.Material.Basalt
		);
		(ring :: Part).Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.1
		noCollide(ring)
	end
end

crystalStyles.Emerald = function(b, theme, s)
	shard(b, 7 * s, 2 * s, CFrame.new(0, 0.5 * s, 0) * CFrame.Angles(0, math.rad(45), 0), theme.Crystal)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local leaf = part(
			b,
			Vector3.new(0.3 * s, 2.5 * s, 1.6 * s),
			CFrame.new(math.cos(angle) * 1.6 * s, -2.6 * s, math.sin(angle) * 1.6 * s)
				* CFrame.Angles(0, -angle, math.rad(-35)),
			Color3.fromRGB(60, 140, 50),
			Enum.Material.Grass,
			"Leaf",
			"WedgePart"
		)
		noCollide(leaf)
	end
end

crystalStyles.Rings = function(b, theme, s)
	local core =
		part(b, Vector3.one * 3 * s, CFrame.Angles(math.rad(45), 0, math.rad(35.26)), theme.Crystal, Enum.Material.Neon)
	noCollide(core)
	for i = 0, 1 do
		local ring = cylinder(
			b,
			0.3 * s,
			(5.5 + i * 2) * s,
			Vector3.zero,
			if i == 0 then Color3.fromRGB(60, 230, 255) else theme.Crystal,
			Enum.Material.Neon
		)
		ring.CFrame = b.root
			* CFrame.Angles(math.rad(70 - i * 40), math.rad(i * 60), 0)
			* CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.35
		noCollide(ring)
	end
end

crystalStyles.Lollipop = function(b, theme, s)
	local stick = cylinder(
		b,
		4 * s,
		0.5 * s,
		Vector3.new(0, -3 * s, 0),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	noCollide(stick)
	for i = 0, 4 do
		local disc = part(
			b,
			Vector3.new(0.6 * s, (5 - i * 0.9) * s, (5 - i * 0.9) * s),
			CFrame.new(0, 0.8 * s, -i * 0.05 * s) * CFrame.Angles(0, math.rad(90), 0),
			if i % 2 == 0 then theme.Crystal else Color3.fromRGB(255, 255, 255),
			Enum.Material.SmoothPlastic
		);
		(disc :: Part).Shape = Enum.PartType.Cylinder
		noCollide(disc)
	end
end

crystalStyles.Star = function(b, theme, s)
	local core = sphere(b, Vector3.one * 3.6 * s, CFrame.identity, theme.Crystal, Enum.Material.Neon)
	noCollide(core)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local spike = part(
			b,
			Vector3.new(0.9 * s, 2.6 * s, 0.9 * s),
			CFrame.Angles(0, 0, angle) * CFrame.new(0, 2.6 * s, 0),
			Color3.fromRGB(255, 255, 255),
			Enum.Material.Neon,
			"Spike"
		)
		noCollide(spike)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		local moon = sphere(
			b,
			Vector3.one * 0.9 * s,
			CFrame.new(math.cos(angle) * 4.2 * s, math.sin(angle * 2) * s, math.sin(angle) * 4.2 * s),
			Color3.fromRGB(120, 200, 255),
			Enum.Material.Neon
		)
		noCollide(moon)
	end
end

function BaseBuilder.BuildCrystal(
	theme: Themes.Theme,
	tier: number,
	rebirths: number,
	worldCf: CFrame,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "Crystal"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.one
	core.Transparency = 1
	core.Anchored = true
	noCollide(core)
	core.CFrame = worldCf
	core.Parent = model
	model.PrimaryPart = core

	local scale = 1 + (tier - 1) * 0.07
	local b: Builder = { root = worldCf, parent = model }
	local style = crystalStyles[theme.CrystalStyle] or crystalStyles.Obelisk
	style(b, theme, scale)

	-- Everything except Core becomes unanchored and welded so clients can spin the whole crystal by moving Core.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= core then
			child.Anchored = false
			child.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = core
			weld.Part1 = child
			weld.Parent = child
		end
	end

	local beamOrigin = Instance.new("Attachment")
	beamOrigin.Name = "BeamOrigin"
	beamOrigin.Parent = core

	local light = Instance.new("PointLight")
	light.Color = theme.Glow
	light.Range = 22 + tier
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(theme.Glow)
	sparkle.LightEmission = 1
	sparkle.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 + rebirths * 0.05), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 6 + tier
	sparkle.Parent = beamOrigin

	model:SetAttribute("Style", theme.CrystalStyle)
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------------------------------------------
-- Decorations per theme
---------------------------------------------------------------------------------------------------------------

local function wallTopPoints(): { CFrame }
	-- Points along the top of every wall (outer perimeter), skipping the door opening.
	local points = {}
	local half = BaseBuilder.Size / 2 - 1
	local y = BaseBuilder.FloorTop + BaseBuilder.WallHeight
	for x = -half + 3, half - 3, 6 do
		table.insert(points, CFrame.new(x, y, half))
		if math.abs(x) > BaseBuilder.DoorWidth / 2 + 2 then
			table.insert(points, CFrame.new(x, y, -half))
		end
	end
	for z = -half + 3, half - 3, 6 do
		table.insert(points, CFrame.new(half, y, z) * CFrame.Angles(0, math.rad(90), 0))
		table.insert(points, CFrame.new(-half, y, z) * CFrame.Angles(0, math.rad(90), 0))
	end
	return points
end

local function decorate(b: Builder, theme: Themes.Theme)
	local decor = theme.Decor
	local points = wallTopPoints()
	if decor == "Crenels" then
		for _, cf in points do
			part(b, Vector3.new(2.5, 1.6, 2.2), cf * CFrame.new(0, 0.8, 0), theme.Trim, theme.TrimMaterial)
		end
	elseif decor == "Fence" then
		for _, cf in points do
			part(b, Vector3.new(0.6, 2.2, 0.6), cf * CFrame.new(0, 1.1, 0), theme.Trim, theme.TrimMaterial)
		end
	elseif decor == "Spikes" then
		for _, cf in points do
			local spike = part(
				b,
				Vector3.new(1.4, 2.4, 1.4),
				cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(45), 0),
				theme.Trim,
				theme.TrimMaterial,
				"Spike",
				"WedgePart"
			)
			noCollide(spike)
		end
	elseif decor == "Domes" then
		for i, cf in points do
			if i % 2 == 0 then
				sphere(b, Vector3.new(2.6, 2.6, 2.6), cf * CFrame.new(0, 0.6, 0), theme.Trim, theme.TrimMaterial)
			end
		end
	elseif decor == "Icicles" then
		for _, cf in points do
			local icicle = part(
				b,
				Vector3.new(0.8, 2.2, 0.8),
				cf * CFrame.new(0, -BaseBuilder.WallHeight * 0.2, -1.4) * CFrame.Angles(math.rad(180), 0, 0),
				theme.Trim,
				Enum.Material.Ice,
				"Icicle",
				"WedgePart"
			)
			noCollide(icicle)
			part(
				b,
				Vector3.new(2.6, 0.8, 2.6),
				cf * CFrame.new(0, 0.4, 0),
				Color3.fromRGB(250, 252, 255),
				Enum.Material.Snow
			)
		end
	elseif decor == "Vines" then
		for i, cf in points do
			if i % 2 == 1 then
				local vine = part(
					b,
					Vector3.new(0.5, BaseBuilder.WallHeight * 0.7, 0.5),
					cf * CFrame.new(0, -BaseBuilder.WallHeight * 0.35, -1.1),
					theme.Trim,
					Enum.Material.Grass
				)
				noCollide(vine)
				sphere(b, Vector3.new(2, 1.2, 2), cf * CFrame.new(0, 0.4, 0), theme.Trim, Enum.Material.Grass)
			end
		end
	elseif decor == "NeonStrips" then
		local half = BaseBuilder.Size / 2 - 1
		local y = BaseBuilder.FloorTop + BaseBuilder.WallHeight * 0.55
		for _, z in { half + 1.05 } do
			part(b, Vector3.new(BaseBuilder.Size, 0.4, 0.1), CFrame.new(0, y, z), theme.Trim, Enum.Material.Neon)
		end
		for _, x in { half + 1.05, -half - 1.05 } do
			part(
				b,
				Vector3.new(0.1, 0.4, BaseBuilder.Size),
				CFrame.new(x, y, 0),
				Color3.fromRGB(60, 230, 255),
				Enum.Material.Neon
			)
		end
		for _, cf in points do
			part(b, Vector3.new(1.6, 0.4, 2.2), cf * CFrame.new(0, 0.2, 0), theme.Trim, Enum.Material.Neon)
		end
	elseif decor == "Candy" then
		for i, cf in points do
			local color = if i % 2 == 0 then Color3.fromRGB(255, 90, 140) else Color3.fromRGB(255, 255, 255)
			sphere(b, Vector3.new(2.2, 2.2, 2.2), cf * CFrame.new(0, 1.1, 0), color, Enum.Material.SmoothPlastic)
		end
	elseif decor == "Stars" then
		for i, cf in points do
			if i % 2 == 0 then
				local star = sphere(
					b,
					Vector3.one * 1.2,
					cf * CFrame.new(0, 2.2, 0),
					Color3.fromRGB(255, 255, 220),
					Enum.Material.Neon
				)
				noCollide(star)
			end
			part(b, Vector3.new(2.2, 0.6, 2.2), cf * CFrame.new(0, 0.3, 0), theme.Trim, Enum.Material.Neon)
		end
	end
end

local function towers(b: Builder, theme: Themes.Theme)
	local half = BaseBuilder.Size / 2 - 1
	local height = BaseBuilder.WallHeight + 5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local pos = Vector3.new(sx * half, BaseBuilder.FloorTop + height / 2, sz * half)
			cylinder(b, height, 7, pos, theme.Wall, theme.WallMaterial, "Tower")
			local capY = BaseBuilder.FloorTop + height
			if theme.Decor == "Domes" or theme.Decor == "Candy" or theme.Decor == "Stars" then
				sphere(
					b,
					Vector3.new(7.4, 6, 7.4),
					CFrame.new(pos.X, capY + 0.5, pos.Z),
					theme.Trim,
					theme.TrimMaterial
				)
			else
				for i = 0, 3 do
					local d = 8 - i * 2
					cylinder(b, 1.2, d, Vector3.new(pos.X, capY + 0.6 + i * 1.1, pos.Z), theme.Trim, theme.TrimMaterial)
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Base
---------------------------------------------------------------------------------------------------------------

export type BaseParts = {
	Model: Model,
	Door: Model,
	Crystal: Model,
	Sign: BasePart,
	Spawn: BasePart,
	Pedestals: { [number]: { Stand: BasePart, Pad: BasePart, Locked: boolean } },
	Kiosk: BasePart,
}

function BaseBuilder.SlotLocalCFrame(slot: number): CFrame
	local pos = SLOT_POSITIONS[slot]
	-- Brainrots face the central aisle.
	local facing = if pos.X < 0 then math.rad(-90) else math.rad(90)
	return CFrame.new(pos.X, BaseBuilder.FloorTop + 1.2, pos.Z) * CFrame.Angles(0, facing, 0)
end

function BaseBuilder.PadLocalPosition(slot: number): Vector3
	local pos = SLOT_POSITIONS[slot]
	local towardAisle = if pos.X < 0 then 1 else -1
	return Vector3.new(pos.X + towardAisle * 4.2, BaseBuilder.FloorTop + 0.13, pos.Z)
end

function BaseBuilder.Build(
	plotCf: CFrame,
	tier: number,
	rebirths: number,
	ownerName: string,
	parent: Instance
): BaseParts
	local theme = Themes.Get(tier)
	local model = Instance.new("Model")
	model.Name = "Base"
	local b: Builder = { root = plotCf, parent = model }
	local size = BaseBuilder.Size
	local half = size / 2
	local wallH = BaseBuilder.WallHeight
	local floorTop = BaseBuilder.FloorTop

	-- Floor and trim
	part(b, Vector3.new(size, 1, size), CFrame.new(0, 0.5, 0), theme.Floor, theme.FloorMaterial, "Floor")
	part(b, Vector3.new(size + 1, 0.6, 1), CFrame.new(0, 1.05, -half), theme.Trim, theme.TrimMaterial)
	-- Central aisle
	part(b, Vector3.new(10, 0.1, size - 6), CFrame.new(0, floorTop + 0.05, 0), theme.Trim, theme.TrimMaterial, "Aisle")

	-- Walls
	local wallY = floorTop + wallH / 2
	part(b, Vector3.new(size, wallH, 2), CFrame.new(0, wallY, half - 1), theme.Wall, theme.WallMaterial, "Wall")
	part(b, Vector3.new(2, wallH, size), CFrame.new(half - 1, wallY, 0), theme.Wall, theme.WallMaterial, "Wall")
	part(b, Vector3.new(2, wallH, size), CFrame.new(-half + 1, wallY, 0), theme.Wall, theme.WallMaterial, "Wall")
	local segment = (size - BaseBuilder.DoorWidth) / 2
	for _, side in { -1, 1 } do
		part(
			b,
			Vector3.new(segment, wallH, 2),
			CFrame.new(side * (BaseBuilder.DoorWidth / 2 + segment / 2), wallY, -half + 1),
			theme.Wall,
			theme.WallMaterial,
			"Wall"
		)
	end
	-- Wall caps
	for _, cf in { CFrame.new(0, floorTop + wallH + 0.3, half - 1), CFrame.new(0, floorTop + wallH + 0.3, -half + 1) } do
		part(b, Vector3.new(size + 0.6, 0.6, 2.6), cf, theme.Trim, theme.TrimMaterial)
	end
	for _, x in { half - 1, -half + 1 } do
		part(
			b,
			Vector3.new(2.6, 0.6, size + 0.6),
			CFrame.new(x, floorTop + wallH + 0.3, 0),
			theme.Trim,
			theme.TrimMaterial
		)
	end
	towers(b, theme)
	decorate(b, theme)

	-- Invisible tall barrier so nobody jumps over walls (doors are the only way in)
	local barrierH = 40
	local barrierY = floorTop + wallH + barrierH / 2
	local barrierSizes = {
		Vector3.new(size, barrierH, 1),
		Vector3.new(1, barrierH, size),
		Vector3.new(1, barrierH, size),
		Vector3.new(size, barrierH, 1),
	}
	local barrierFrames = {
		CFrame.new(0, barrierY, half - 1),
		CFrame.new(half - 1, barrierY, 0),
		CFrame.new(-half + 1, barrierY, 0),
		CFrame.new(0, barrierY, -half + 1),
	}
	for i, barrierSize in barrierSizes do
		local barrier =
			part(b, barrierSize, barrierFrames[i], Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, "Barrier")
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CanTouch = false
	end

	-- Door frame + door
	for _, side in { -1, 1 } do
		part(
			b,
			Vector3.new(1.2, wallH + 1.5, 2.8),
			CFrame.new(side * (BaseBuilder.DoorWidth / 2 + 0.3), floorTop + (wallH + 1.5) / 2, -half + 1),
			theme.Trim,
			theme.TrimMaterial,
			"DoorFrame"
		)
	end
	part(
		b,
		Vector3.new(BaseBuilder.DoorWidth + 2.6, 1.6, 2.8),
		CFrame.new(0, floorTop + wallH + 0.8, -half + 1),
		theme.Trim,
		theme.TrimMaterial,
		"DoorFrame"
	)

	local door = Instance.new("Model")
	door.Name = "Door"
	local doorB: Builder = { root = plotCf, parent = door }
	local panel = part(
		doorB,
		Vector3.new(BaseBuilder.DoorWidth, wallH, 1.2),
		CFrame.new(0, floorTop + wallH / 2, -half + 1),
		theme.Door,
		theme.DoorMaterial,
		"Panel"
	)
	for i = 0, 2 do
		local plank = part(
			doorB,
			Vector3.new(BaseBuilder.DoorWidth - 0.6, 0.8, 0.3),
			CFrame.new(0, floorTop + 2 + i * 4, -half + 0.3),
			theme.Trim,
			theme.TrimMaterial,
			"Brace"
		)
		plank.CanCollide = false
	end
	local knob = part(
		doorB,
		Vector3.new(0.8, 0.8, 0.5),
		CFrame.new(3.8, floorTop + wallH * 0.45, -half + 0.2),
		Color3.fromRGB(255, 210, 80),
		Enum.Material.Foil,
		"Knob"
	)
	knob.CanCollide = false
	door.PrimaryPart = panel
	door.Parent = model
	for _, child in door:GetDescendants() do
		if child:IsA("BasePart") then
			child:SetAttribute("BaseTransparency", child.Transparency)
		end
	end

	-- Owner sign above the door
	local sign = part(
		b,
		Vector3.new(22, 4, 0.6),
		CFrame.new(0, floorTop + wallH + 3.6, -half - 0.2),
		theme.Trim,
		theme.TrimMaterial,
		"Sign"
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(660, 120)
	gui.LightInfluence = 0
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Owner"
	title.Size = UDim2.new(1, 0, 0.62, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.Text = string.upper(ownerName) .. "'S BASE"
	title.Parent = gui
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Tier"
	subtitle.Position = UDim2.new(0, 0, 0.62, 0)
	subtitle.Size = UDim2.new(1, 0, 0.38, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextScaled = true
	subtitle.TextColor3 = theme.Glow
	subtitle.TextStrokeTransparency = 0
	subtitle.Text = string.format("Tier %d · %s", tier, theme.Name)
	subtitle.Parent = gui

	-- Pillar + crystal
	cylinder(b, 1, 9, Vector3.new(0, floorTop + 0.5, 0), theme.Trim, theme.TrimMaterial, "PillarBase")
	cylinder(b, 1, 7, Vector3.new(0, floorTop + 1.5, 0), theme.Pillar, theme.PillarMaterial, "PillarBase")
	local pillarHeight = BaseBuilder.CrystalHeight - 5 - floorTop - 2
	cylinder(
		b,
		pillarHeight,
		4,
		Vector3.new(0, floorTop + 2 + pillarHeight / 2, 0),
		theme.Pillar,
		theme.PillarMaterial,
		"Pillar"
	)
	cylinder(
		b,
		1,
		6.5,
		Vector3.new(0, floorTop + 2 + pillarHeight + 0.5, 0),
		theme.Trim,
		theme.TrimMaterial,
		"PillarTop"
	)
	local crystal =
		BaseBuilder.BuildCrystal(theme, tier, rebirths, plotCf * CFrame.new(0, BaseBuilder.CrystalHeight, 0), model)

	-- Pedestals
	local pedestals = {}
	local pedestalFolder = folder("Pedestals", model)
	local unlocked = Economy.Slots(tier)
	for slot = 1, BaseBuilder.MaxSlots do
		local pos = SLOT_POSITIONS[slot]
		local locked = slot > unlocked
		local slotB: Builder = { root = plotCf, parent = pedestalFolder }
		local stand = cylinder(
			slotB,
			1.2,
			5,
			Vector3.new(pos.X, floorTop + 0.6, pos.Z),
			if locked then Color3.fromRGB(90, 90, 95) else theme.Trim,
			if locked then Enum.Material.Slate else theme.TrimMaterial,
			"Stand" .. slot
		)
		stand:SetAttribute("Slot", slot)
		if locked then
			stand.Transparency = 0.5
			local lockGui = Instance.new("BillboardGui")
			lockGui.Name = "Lock"
			lockGui.Size = UDim2.fromOffset(110, 40)
			lockGui.StudsOffset = Vector3.new(0, 2.2, 0)
			lockGui.MaxDistance = 60
			lockGui.Parent = stand
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(230, 230, 230)
			label.TextStrokeTransparency = 0.2
			local needed = tier
			while needed < Economy.MaxTier and Economy.Slots(needed) < slot do
				needed += 1
			end
			label.Text = "🔒 Tier " .. needed
			label.Parent = lockGui
		end
		local padPos = BaseBuilder.PadLocalPosition(slot)
		local pad =
			part(slotB, Vector3.new(2.6, 0.25, 3.4), CFrame.new(padPos), theme.Glow, Enum.Material.Neon, "Pad" .. slot)
		pad.CanCollide = false
		pad:SetAttribute("Slot", slot)
		pad.Transparency = if locked then 1 else 0.25
		pedestals[slot] = { Stand = stand, Pad = pad, Locked = locked }
	end

	-- Upgrade kiosk in the aisle, facing the door
	local kiosk = part(
		b,
		Vector3.new(5, 3.2, 1.2),
		CFrame.new(0, floorTop + 1.6, -13) * CFrame.Angles(math.rad(-15), 0, 0),
		theme.Trim,
		theme.TrimMaterial,
		"Kiosk"
	)
	local kioskGui = Instance.new("SurfaceGui")
	kioskGui.Face = Enum.NormalId.Front
	kioskGui.CanvasSize = Vector2.new(250, 160)
	kioskGui.LightInfluence = 0
	kioskGui.Parent = kiosk
	local kioskLabel = Instance.new("TextLabel")
	kioskLabel.Size = UDim2.fromScale(1, 1)
	kioskLabel.BackgroundTransparency = 1
	kioskLabel.Font = Enum.Font.FredokaOne
	kioskLabel.TextScaled = true
	kioskLabel.TextColor3 = Color3.new(1, 1, 1)
	kioskLabel.TextStrokeTransparency = 0
	kioskLabel.Text = "⬆️ UPGRADE"
	kioskLabel.Parent = kioskGui

	-- Spawn point just inside the door
	local spawn = part(
		b,
		Vector3.new(4, 1, 4),
		CFrame.new(0, floorTop + 0.5, -half + 8),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		"SpawnPoint"
	)
	spawn.Transparency = 1
	noCollide(spawn)

	model:SetAttribute("Tier", tier)
	model:SetAttribute("Theme", theme.Name)
	model.Parent = parent

	return {
		Model = model,
		Door = door,
		Crystal = crystal,
		Sign = sign,
		Spawn = spawn,
		Pedestals = pedestals,
		Kiosk = kiosk,
	}
end

-- Empty plot placeholder (shown when nobody owns the plot).
function BaseBuilder.BuildEmpty(plotCf: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "EmptyPlot"
	local b: Builder = { root = plotCf, parent = model }
	local p = part(
		b,
		Vector3.new(BaseBuilder.Size, 0.6, BaseBuilder.Size),
		CFrame.new(0, 0.3, 0),
		Color3.fromRGB(120, 170, 90),
		Enum.Material.Grass,
		"Floor"
	)
	p.Transparency = 0
	local sign = part(
		b,
		Vector3.new(14, 3, 0.5),
		CFrame.new(0, 3, -BaseBuilder.Size / 2 + 4),
		Color3.fromRGB(140, 100, 60),
		Enum.Material.Wood,
		"Sign"
	)
	local gui = Instance.new("SurfaceGui")
	gui.CanvasSize = Vector2.new(420, 90)
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = "Waiting for a player..."
	label.Parent = gui
	part(
		b,
		Vector3.new(0.6, 3, 0.6),
		CFrame.new(0, 1.2, -BaseBuilder.Size / 2 + 4.3),
		Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood
	)
	model.Parent = parent
	return model
end

return BaseBuilder
