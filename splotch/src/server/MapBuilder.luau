--[[
	MapBuilder: builds "The Gallery", the battleground, out of plain parts.

	Layout (top down, north is -Z):

	        NW hut                      NE hut
	          |      T1        T2 ======== sky bridge
	   west   |          STAGE           |     E hut
	   strip  ~ trench    (sweeper)      |
	          |      T4                  T3
	        SW hut          SPAWN PAVILION (safe)

	Surfaces are near-white so every paint color reads. Everything solid is
	paintable except spawn pads, the sign and hazards. Edges drop into the void.
	Only Instance APIs that also exist in Lune are used, so tools/preview-map
	can build the same map offline.
]]

local MapBuilder = {}

local COLORS = {
	floor = Color3.fromRGB(226, 223, 216),
	structure = Color3.fromRGB(238, 236, 232),
	accent = Color3.fromRGB(208, 212, 220),
	roof = Color3.fromRGB(78, 84, 102),
	metal = Color3.fromRGB(58, 62, 72),
	rinse = Color3.fromRGB(40, 225, 255),
	sweeper = Color3.fromRGB(255, 120, 30),
	pad = Color3.fromRGB(170, 255, 40),
	spawn = Color3.fromRGB(250, 250, 250),
}

type Options = {
	color: Color3?,
	material: Enum.Material?,
	paintable: boolean?,
	transparency: number?,
	collide: boolean?,
	query: boolean?,
	tags: { string }?,
}

local function box(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, options: Options?): Part
	local opts = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	part.Color = opts.color or COLORS.structure
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = opts.transparency or 0
	part.CanCollide = if opts.collide == nil then true else opts.collide
	part.CanQuery = if opts.query == nil then true else opts.query
	if opts.paintable ~= false then
		part:AddTag("Paintable")
	end
	for _, tag in opts.tags or {} do
		part:AddTag(tag)
	end
	part.Parent = parent
	return part
end

-- An invisible volume used for zone checks (never collides, never queried).
local function zone(parent: Instance, name: string, tag: string, size: Vector3, position: Vector3)
	local part = box(parent, name, size, position, {
		paintable = false,
		transparency = 1,
		collide = false,
		query = false,
		tags = { tag },
	})
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- A slab whose top surface runs from `low` to `high` (both top-surface points).
local function ramp(
	parent: Instance,
	name: string,
	low: Vector3,
	high: Vector3,
	width: number,
	thickness: number,
	options: Options?
)
	local mid = (low + high) / 2
	local look = CFrame.lookAt(mid, high)
	local cframe = look * CFrame.new(0, -thickness / 2, 0)
	return box(parent, name, Vector3.new(width, thickness, (high - low).Magnitude), cframe, options)
end

-- Three walls and a roof. `facing` is a yaw in degrees: -90 opens east, 90 west.
local function hut(parent: Instance, zones: Instance, name: string, center: Vector3, facing: number)
	local origin = CFrame.new(center) * CFrame.Angles(0, math.rad(facing), 0)
	local wall = { color = COLORS.structure }
	-- In hut space the open side faces local -Z.
	box(parent, name .. "Back", Vector3.new(18, 11, 2), origin * CFrame.new(0, 5.5, 8), wall)
	box(parent, name .. "Left", Vector3.new(2, 11, 16), origin * CFrame.new(-8, 5.5, 0), wall)
	box(parent, name .. "Right", Vector3.new(2, 11, 16), origin * CFrame.new(8, 5.5, 0), wall)
	box(parent, name .. "Roof", Vector3.new(22, 2, 22), origin * CFrame.new(0, 12, 0), { color = COLORS.roof })
	local volume = zone(zones, name .. "Shelter", "Shelter", Vector3.new(14, 11, 16), center + Vector3.new(0, 5.5, 0))
	volume.CFrame = origin * CFrame.new(0, 5.5, -1)
end

local function bouncePad(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: number,
	power: number,
	forward: number
)
	local pad =
		box(parent, name, Vector3.new(6, 0.5, 6), CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0), {
			color = COLORS.pad,
			material = Enum.Material.Neon,
			paintable = false,
			tags = { "BouncePad" },
		})
	pad:SetAttribute("Power", power)
	pad:SetAttribute("Forward", forward)
	return pad
end

local SIGN_TEXT = table.concat({
	"SPLOTCH",
	"",
	"WASD move   |   Mouse aim   |   M1 paint shot",
	"1 / 2 / 3 skills   |   Q dash   |   F block",
	"Hold SHIFT to dive into your own paint (fast, heals, climbs walls)",
	"SPACE while diving: leap out   |   M: pick character   |   ALT: free mouse",
	"",
	"Enemy paint slows and hurts you. Low health = you fly further.",
	"When the WASHOUT storm comes, get under a roof.",
}, "\n")

local function sign(parent: Instance)
	local board = box(parent, "Sign", Vector3.new(22, 10, 0.6), Vector3.new(0, 7.5, 114.7), {
		color = Color3.fromRGB(30, 32, 40),
		paintable = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = SIGN_TEXT
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label
end

function MapBuilder.build(): (Folder, Folder)
	local map = Instance.new("Folder")
	map.Name = "Map"
	local zones = Instance.new("Folder")
	zones.Name = "Zones"

	local floor = { color = COLORS.floor, material = Enum.Material.Concrete }
	local accent = { color = COLORS.accent }

	-- Ground ----------------------------------------------------------------
	box(map, "MainFloor", Vector3.new(188, 10, 240), Vector3.new(26, -5, 0), floor)
	box(map, "WestStrip", Vector3.new(40, 10, 240), Vector3.new(-100, -5, 0), floor)
	box(map, "TrenchBridgeNorth", Vector3.new(12, 2, 10), Vector3.new(-74, -1, -60), accent)
	box(map, "TrenchBridgeSouth", Vector3.new(12, 2, 10), Vector3.new(-74, -1, 60), accent)
	box(map, "Rinse", Vector3.new(12, 2, 240), Vector3.new(-74, -9, 0), {
		color = COLORS.rinse,
		material = Enum.Material.Neon,
		paintable = false,
		transparency = 0.15,
		collide = false,
		query = false,
	})
	zone(zones, "RinseKill", "Hazard", Vector3.new(12, 6, 240), Vector3.new(-74, -8, 0))

	-- Spawn pavilion (safe zone + shelter) ----------------------------------
	for _, x in { -23.5, 23.5 } do
		for _, z in { 86.5, 113.5 } do
			box(map, "PavilionPillar", Vector3.new(3, 18, 3), Vector3.new(x, 9, z), accent)
		end
	end
	box(map, "PavilionRoof", Vector3.new(54, 2, 34), Vector3.new(0, 19, 100), { color = COLORS.roof })
	box(map, "PavilionWall", Vector3.new(50, 18, 2), Vector3.new(0, 9, 116))
	zone(zones, "PavilionSafe", "SafeZone", Vector3.new(50, 18, 30), Vector3.new(0, 9, 100))
	zone(zones, "PavilionShelter", "Shelter", Vector3.new(50, 18, 30), Vector3.new(0, 9, 100))
	for index, x in { -14, 0, 14 } do
		local spawnPad = Instance.new("SpawnLocation")
		spawnPad.Name = "Spawn" .. index
		spawnPad.Anchored = true
		spawnPad.Size = Vector3.new(6, 0.4, 6)
		spawnPad.CFrame = CFrame.new(x, 0.2, 106)
		spawnPad.Color = COLORS.spawn
		spawnPad.Material = Enum.Material.Neon
		spawnPad.Duration = 0
		spawnPad.Neutral = true
		spawnPad.TopSurface = Enum.SurfaceType.Smooth
		spawnPad.Parent = map
	end
	sign(map)

	-- Central stage with sweeper ----------------------------------------------
	box(map, "Stage", Vector3.new(48, 6, 48), Vector3.new(0, 3, -10), accent)
	ramp(map, "StageRampSouth", Vector3.new(0, 0, 34), Vector3.new(0, 6, 14), 14, 2, floor)
	ramp(map, "StageRampNorth", Vector3.new(0, 0, -54), Vector3.new(0, 6, -34), 14, 2, floor)
	ramp(map, "StageRampEast", Vector3.new(44, 0, -10), Vector3.new(24, 6, -10), 14, 2, floor)
	ramp(map, "StageRampWest", Vector3.new(-44, 0, -10), Vector3.new(-24, 6, -10), 14, 2, floor)
	box(map, "SweeperPost", Vector3.new(3, 4, 3), Vector3.new(0, 8, -10), {
		color = COLORS.metal,
		material = Enum.Material.Metal,
		paintable = false,
	})
	local bar = box(map, "SweeperBar", Vector3.new(42, 1.6, 1.6), Vector3.new(0, 7.6, -10), {
		color = COLORS.sweeper,
		material = Enum.Material.Neon,
		paintable = false,
		collide = false,
		query = false,
	})
	bar:SetAttribute("ArmLength", 21)
	bar:SetAttribute("Speed", 1.1)

	-- Towers and the sky bridge -----------------------------------------------
	box(map, "TowerNW", Vector3.new(14, 16, 14), Vector3.new(-58, 8, -72))
	box(map, "TowerNE", Vector3.new(16, 26, 16), Vector3.new(62, 13, -74))
	box(map, "TowerSE", Vector3.new(14, 36, 14), Vector3.new(72, 18, 52))
	box(map, "TowerSW", Vector3.new(18, 22, 18), Vector3.new(-46, 11, 40))
	ramp(map, "SkyBridge", Vector3.new(66, 26, -66), Vector3.new(70, 36, 45), 5, 1.5, accent)

	-- Buildings: big climbable blocks that break up sight lines ----------------
	box(map, "GalleryEast", Vector3.new(18, 14, 24), Vector3.new(95, 7, 50))
	box(map, "GalleryWest", Vector3.new(20, 12, 20), Vector3.new(-55, 6, 5))
	box(map, "GalleryWestCap", Vector3.new(8, 6, 8), Vector3.new(-55, 15, 5), accent)

	-- Cover -------------------------------------------------------------------
	box(map, "WallSouthWest", Vector3.new(30, 10, 3), Vector3.new(-32, 5, 62))
	box(map, "WallEast", Vector3.new(3, 10, 30), Vector3.new(40, 5, 10))
	box(map, "WallSouthEast", Vector3.new(30, 10, 3), Vector3.new(40, 5, 75))
	box(map, "WallNorthWest", Vector3.new(3, 12, 36), Vector3.new(-40, 6, -40))
	box(map, "WallNorth", Vector3.new(24, 8, 3), Vector3.new(10, 4, -75))
	for index, position in
		{
			Vector3.new(20, 3, 40),
			Vector3.new(26, 3, 40),
			Vector3.new(23, 9, 40),
			Vector3.new(-60, 3, -20),
			Vector3.new(85, 3, -20),
			Vector3.new(85, 3, -14),
			Vector3.new(-10, 3, 60),
		}
	do
		box(map, "Crate" .. index, Vector3.new(6, 6, 6), position, accent)
	end

	-- Shelters for the Washout -----------------------------------------------
	hut(map, zones, "HutNorthWest", Vector3.new(-100, 0, -95), -90)
	hut(map, zones, "HutSouthWest", Vector3.new(-100, 0, 95), -90)
	hut(map, zones, "HutNorthEast", Vector3.new(95, 0, -95), 90)
	hut(map, zones, "HutEast", Vector3.new(100, 0, 10), 90)

	-- Bounce pads ---------------------------------------------------------------
	bouncePad(map, "PadTowerNE", Vector3.new(62, 0.25, -56), 0, 105, 14)
	bouncePad(map, "PadSouthWest", Vector3.new(-30, 0.25, 72), 0, 90, 0)
	bouncePad(map, "PadNorth", Vector3.new(40, 0.25, -40), 0, 90, 0)
	bouncePad(map, "PadWestStrip", Vector3.new(-100, 0.25, 0), 0, 90, 0)

	return map, zones
end

return MapBuilder
