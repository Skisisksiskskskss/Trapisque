--!strict
-- Generates the world at boot: ground, plaza, ring road, radial paths, the Brainrot Portal, scenery and lighting.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MapGeometry = require(Shared.Modules.MapGeometry)

local MapService = {}

local mapFolder: Folder
local plotsFolder: Folder

local function part(
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	name: string?
): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function disc(
	diameter: number,
	thickness: number,
	y: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	name: string?
): Part
	local p = part(
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		parent,
		name
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = part(size, cf, color, material, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

MapService.PlotAngle = MapGeometry.PlotAngle
MapService.PlotCFrame = MapGeometry.PlotCFrame
MapService.StopPosition = MapGeometry.StopPosition
MapService.PortalEdge = MapGeometry.PortalEdge

function MapService.PlotsFolder(): Folder
	return plotsFolder
end

local function buildGround()
	local ground = part(
		Vector3.new(720, 4, 720),
		CFrame.new(0, -2, 0),
		Color3.fromRGB(110, 185, 85),
		Enum.Material.Grass,
		mapFolder,
		"Ground"
	)
	ground:SetAttribute("Ground", true)
	-- Road ring (under the plaza disc so only an annulus shows)
	disc(
		2 * (GameConfig.BaseFrontRadius - 2),
		0.3,
		0.1,
		Color3.fromRGB(70, 72, 82),
		Enum.Material.Asphalt,
		mapFolder,
		"RingRoad"
	)
	disc(
		2 * (GameConfig.RingRoadRadius - 8),
		0.34,
		0.12,
		Color3.fromRGB(225, 215, 195),
		Enum.Material.Pavement,
		mapFolder,
		"Plaza"
	)
	-- Dashed centre line on the ring road
	local dashes = 72
	for i = 0, dashes - 1 do
		local angle = i * 2 * math.pi / dashes
		local pos =
			Vector3.new(math.cos(angle) * GameConfig.RingRoadRadius, 0.27, math.sin(angle) * GameConfig.RingRoadRadius)
		local dash = part(
			Vector3.new(0.6, 0.05, 3.2),
			CFrame.lookAt(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle))),
			Color3.fromRGB(255, 210, 60),
			Enum.Material.SmoothPlastic,
			mapFolder,
			"Dash"
		)
		dash.CanCollide = false
	end
	-- Radial carpets from the portal to every base
	for index = 1, GameConfig.MaxPlots do
		local a = MapService.PortalEdge(index)
		local bPos = MapService.StopPosition(index) + (MapService.StopPosition(index) - a).Unit * 6
		local mid = (a + bPos) / 2
		local length = (bPos - a).Magnitude
		local carpet = part(
			Vector3.new(7, 0.1, length),
			CFrame.lookAt(Vector3.new(mid.X, 0.33, mid.Z), Vector3.new(bPos.X, 0.33, bPos.Z)),
			Color3.fromRGB(200, 55, 70),
			Enum.Material.Fabric,
			mapFolder,
			"Carpet"
		)
		carpet.CanCollide = false
		for _, side in { -1, 1 } do
			local edge = part(
				Vector3.new(0.4, 0.12, length),
				carpet.CFrame * CFrame.new(side * 3.6, 0.01, 0),
				Color3.fromRGB(255, 215, 80),
				Enum.Material.Neon,
				mapFolder,
				"CarpetEdge"
			)
			edge.CanCollide = false
		end
	end
end

local function buildPortal()
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	local base = disc(
		GameConfig.PortalRadius * 2 + 4,
		1.2,
		0.6,
		Color3.fromRGB(60, 45, 90),
		Enum.Material.Slate,
		portal,
		"PortalBase"
	)
	base.CanCollide = true
	local pit = disc(
		GameConfig.PortalRadius * 2 - 4,
		0.2,
		1.25,
		Color3.fromRGB(150, 70, 255),
		Enum.Material.Neon,
		portal,
		"Pit"
	)
	pit.Transparency = 0.15
	pit.CanCollide = false
	local segments = 24
	for i = 0, segments - 1 do
		local angle = i * 2 * math.pi / segments
		local pos = Vector3.new(
			math.cos(angle) * (GameConfig.PortalRadius - 0.5),
			1.6,
			math.sin(angle) * (GameConfig.PortalRadius - 0.5)
		)
		local seg = part(
			Vector3.new(1, 0.8, 3.6),
			CFrame.lookAt(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle))),
			if i % 2 == 0 then Color3.fromRGB(255, 80, 220) else Color3.fromRGB(80, 220, 255),
			Enum.Material.Neon,
			portal,
			"Rim"
		)
		seg.CanCollide = false
	end
	-- Four arches over the portal
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 8
		local pos = Vector3.new(
			math.cos(angle) * (GameConfig.PortalRadius + 1),
			9,
			math.sin(angle) * (GameConfig.PortalRadius + 1)
		)
		part(Vector3.new(2, 18, 2), CFrame.new(pos), Color3.fromRGB(70, 55, 110), Enum.Material.Slate, portal, "Spire")
		ball(
			Vector3.one * 3,
			CFrame.new(pos + Vector3.new(0, 10, 0)),
			Color3.fromRGB(190, 120, 255),
			Enum.Material.Neon,
			portal
		)
	end
	local beacon =
		part(Vector3.one, CFrame.new(0, 26, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, portal, "Beacon")
	beacon.Transparency = 1
	beacon.CanCollide = false
	local swirlAttachment = Instance.new("Attachment")
	swirlAttachment.Position = Vector3.new(0, -24, 0)
	swirlAttachment.Parent = beacon
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(90, 220, 255))
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	swirl.Lifetime = NumberRange.new(1.5, 2.5)
	swirl.Speed = NumberRange.new(4, 8)
	swirl.SpreadAngle = Vector2.new(25, 25)
	swirl.EmissionDirection = Enum.NormalId.Top
	swirl.Rate = 25
	swirl.Parent = swirlAttachment
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 120, 255)
	light.Range = 40
	light.Brightness = 2
	light.Parent = beacon
	portal.Parent = mapFolder
end

local function buildTree(pos: Vector3, scale: number, parent: Instance)
	local trunk = part(
		Vector3.new(1.6, 8, 1.6) * scale,
		CFrame.new(pos + Vector3.new(0, 4 * scale, 0)),
		Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood,
		parent,
		"Trunk"
	)
	trunk.CanCollide = true
	local green = Color3.fromRGB(70 + math.floor(scale * 20), 160, 70)
	ball(
		Vector3.new(8, 7, 8) * scale,
		CFrame.new(pos + Vector3.new(0, 9 * scale, 0)),
		green,
		Enum.Material.Grass,
		parent
	)
	ball(
		Vector3.new(6, 5, 6) * scale,
		CFrame.new(pos + Vector3.new(1.5 * scale, 12 * scale, 0.5 * scale)),
		green,
		Enum.Material.Grass,
		parent
	)
end

local function buildScenery()
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	local rng = Random.new(1337)
	for i = 0, 47 do
		local angle = i * 2 * math.pi / 48 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(205, 300)
		buildTree(Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), rng:NextNumber(0.9, 1.6), scenery)
	end
	-- Trees in the gaps between bases (outside the ring)
	for index = 1, GameConfig.MaxPlots do
		local angle = (index - 0.5) * (2 * math.pi / GameConfig.MaxPlots)
		for _, radius in { 104, 140, 170 } do
			buildTree(
				Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
				rng:NextNumber(0.8, 1.2),
				scenery
			)
		end
	end
	-- Flower clusters on the plaza
	for i = 0, 15 do
		local angle = i * 2 * math.pi / 16 + math.pi / 16
		local pos = Vector3.new(math.cos(angle) * 46, 0.4, math.sin(angle) * 46)
		disc(5, 0.6, 0, Color3.fromRGB(120, 85, 60), Enum.Material.Ground, scenery).CFrame = CFrame.new(pos)
			* CFrame.Angles(0, 0, math.rad(90))
		for j = 0, 4 do
			local fa = j * 1.3
			ball(
				Vector3.one * 0.9,
				CFrame.new(pos + Vector3.new(math.cos(fa) * 1.4, 0.8, math.sin(fa) * 1.4)),
				Color3.fromHSV((i * 0.13 + j * 0.05) % 1, 0.6, 1),
				Enum.Material.SmoothPlastic,
				scenery
			)
		end
	end
	-- Invisible world boundary
	local walls = 32
	for i = 0, walls - 1 do
		local angle = i * 2 * math.pi / walls
		local pos = Vector3.new(math.cos(angle) * 330, 60, math.sin(angle) * 330)
		local wall = part(
			Vector3.new(70, 120, 2),
			CFrame.lookAt(pos, Vector3.new(0, 60, 0)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			scenery,
			"Boundary"
		)
		wall.Transparency = 1
	end
	scenery.Parent = mapFolder
end

local function buildLighting()
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 190)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.05
	color.Brightness = 0.02
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting
end

function MapService.Init()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	buildGround()
	buildPortal()
	buildScenery()
	buildLighting()

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlazaSpawn"
	spawnLocation.Size = Vector3.new(8, 0.4, 8)
	spawnLocation.CFrame = CFrame.new(math.cos(math.pi / 8) * 34, 0.3, math.sin(math.pi / 8) * 34)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Anchored = true
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Parent = mapFolder

	-- Leaderboard anchor positions are exposed for LeaderboardService.
	local boards = Instance.new("Folder")
	boards.Name = "LeaderboardAnchors"
	for i, angle in { math.rad(22.5), math.rad(157.5), math.rad(292.5) } do
		local pos = Vector3.new(math.cos(angle) * 58, 0, math.sin(angle) * 58)
		local anchor = Instance.new("Part")
		anchor.Name = "Anchor" .. i
		anchor.Size = Vector3.one
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.rad(180), 0)
		anchor.Parent = boards
	end
	boards.Parent = mapFolder
end

function MapService.LeaderboardAnchors(): { BasePart }
	local list = {}
	for _, child in (mapFolder:WaitForChild("LeaderboardAnchors")):GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

return MapService
