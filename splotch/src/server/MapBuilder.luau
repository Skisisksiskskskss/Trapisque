--[[
	MapBuilder: builds "Dye District", the battleground: an art-district city
	block on an island in a rinse sea.

	Layout (top down, north is -Z):

	      NW kiosk     brick apt          tan apt ====== sky bridge   NE kiosk
	   west   |    road |           MIXER PLAZA            |
	   strip  ~ canal   |   concrete    (sweeper)  wall    |  E kiosk
	          |  ======== road =====================================
	          |      brick apt                            tall tower  warehouse
	      SW kiosk               GALLERY (spawn, safe)   PRACTICE YARD

	Every building wall is paintable and climbable: windows, doors and graffiti
	are surface graphics, never extra parts, so wall-swimming is never blocked.
	Small props (lamps, benches, cones) are not paintable. Edges drop into the
	sea. Only Instance APIs that also exist in Lune are used, so
	tools/dump-map can build the same map offline; terrain water is added
	separately by MapBuilder.terrain().
]]

local MapBuilder = {}

local COLORS = {
	pavement = Color3.fromRGB(186, 182, 174),
	curb = Color3.fromRGB(214, 210, 202),
	asphalt = Color3.fromRGB(56, 58, 64),
	lane = Color3.fromRGB(240, 200, 60),
	marble = Color3.fromRGB(232, 228, 220),
	cliff = Color3.fromRGB(98, 92, 88),
	redBrick = Color3.fromRGB(146, 70, 56),
	tanBrick = Color3.fromRGB(196, 160, 118),
	concrete = Color3.fromRGB(172, 174, 178),
	warehouse = Color3.fromRGB(104, 124, 138),
	roof = Color3.fromRGB(62, 64, 72),
	metal = Color3.fromRGB(58, 62, 72),
	wood = Color3.fromRGB(142, 100, 68),
	sweeper = Color3.fromRGB(255, 120, 30),
	pad = Color3.fromRGB(170, 255, 40),
	spawn = Color3.fromRGB(250, 250, 250),
	glass = Color3.fromRGB(44, 58, 84),
	litWindow = Color3.fromRGB(255, 214, 150),
	lamp = Color3.fromRGB(255, 228, 180),
	skyline = Color3.fromRGB(70, 78, 96),
}

type Options = {
	color: Color3?,
	material: Enum.Material?,
	paintable: boolean?,
	transparency: number?,
	collide: boolean?,
	query: boolean?,
	shadow: boolean?,
	shape: Enum.PartType?,
	tags: { string }?,
}

-- Deterministic pseudo-random numbers (Lune has no Random), 0..1.
local seed = 1234567
local function rand(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function box(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, options: Options?): Part
	local opts = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	if opts.shape then
		part.Shape = opts.shape
	end
	part.Size = size
	part.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	part.Color = opts.color or COLORS.concrete
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = opts.transparency or 0
	part.CanCollide = if opts.collide == nil then true else opts.collide
	part.CanQuery = if opts.query == nil then true else opts.query
	part.CastShadow = if opts.shadow == nil then true else opts.shadow
	if opts.paintable ~= false and (opts.shape == nil or opts.shape == Enum.PartType.Block) then
		part:AddTag("Paintable")
	end
	for _, tag in opts.tags or {} do
		part:AddTag(tag)
	end
	part.Parent = parent
	return part
end

-- Props: solid, not paintable.
local function prop(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, options: Options?): Part
	local opts = options or {}
	opts.paintable = false
	return box(parent, name, size, cframe, opts)
end

-- An invisible volume used for zone checks (never collides, never queried).
local function zone(parent: Instance, name: string, tag: string, size: Vector3, cframe: CFrame | Vector3): Part
	local part = box(parent, name, size, cframe, {
		paintable = false,
		transparency = 1,
		collide = false,
		query = false,
		shadow = false,
		tags = { tag },
	})
	part.CanTouch = false
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

-- Surface graphics ------------------------------------------------------------------

local function surfaceGui(part: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 1
	gui.Parent = part
	return gui
end

-- Rows of windows (and a dark band at the top) painted onto one face.
local function windows(part: BasePart, face: Enum.NormalId, width: number, height: number, litChance: number)
	local gui = surfaceGui(part, face, 10)
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0, 12)
	band.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	band.BackgroundTransparency = 0.35
	band.BorderSizePixel = 0
	band.Parent = gui

	local columns = math.max(1, math.floor((width - 2) / 4))
	local rows = math.max(1, math.floor((height - 5) / 5))
	local holder = Instance.new("Frame")
	holder.Position = UDim2.new(0, 14, 0, 30)
	holder.Size = UDim2.new(1, -28, 1, -64)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.new(0, 14, 0, 20)
	grid.CellSize = UDim2.new(1 / columns, -14, 1 / rows, -20)
	grid.Parent = holder
	for _ = 1, columns * rows do
		local window = Instance.new("Frame")
		window.BackgroundColor3 = if rand() < litChance then COLORS.litWindow else COLORS.glass
		window.BorderSizePixel = 0
		local frame = Instance.new("UIStroke")
		frame.Color = Color3.fromRGB(225, 220, 210)
		frame.Thickness = 2
		frame.Parent = window
		window.Parent = holder
	end
end

-- A door painted at the bottom middle of a face.
local function door(part: BasePart, face: Enum.NormalId, color: Color3)
	local gui = surfaceGui(part, face, 10)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, 0)
	frame.Size = UDim2.new(0, 40, 0, 70)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 30, 36)
	stroke.Thickness = 3
	stroke.Parent = frame
end

-- Spray-painted text on a face.
local function graffiti(part: BasePart, face: Enum.NormalId, text: string, color: Color3, rotation: number)
	local gui = surfaceGui(part, face, 12)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.Size = UDim2.new(0.9, 0, 0.7, 0)
	label.Rotation = rotation
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 24)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

-- Buildings --------------------------------------------------------------------------

type Style = { color: Color3, material: Enum.Material, lit: number }

local STYLES: { [string]: Style } = {
	RedBrick = { color = COLORS.redBrick, material = Enum.Material.Brick, lit = 0.25 },
	TanBrick = { color = COLORS.tanBrick, material = Enum.Material.Brick, lit = 0.2 },
	Concrete = { color = COLORS.concrete, material = Enum.Material.Concrete, lit = 0.3 },
	Warehouse = { color = COLORS.warehouse, material = Enum.Material.DiamondPlate, lit = 0 },
}

local FACES = {
	{ Enum.NormalId.Front, "X" },
	{ Enum.NormalId.Back, "X" },
	{ Enum.NormalId.Left, "Z" },
	{ Enum.NormalId.Right, "Z" },
}

local function building(parent: Instance, name: string, center: Vector3, size: Vector3, styleName: string): Part
	local style = STYLES[styleName]
	local body = box(parent, name, size, center + Vector3.new(0, size.Y / 2, 0), {
		color = style.color,
		material = style.material,
	})
	for _, entry in FACES do
		local width = if entry[2] == "X" then size.X else size.Z
		if style.lit > 0 then
			windows(body, entry[1], width, size.Y, style.lit)
		end
	end
	door(body, Enum.NormalId.Back, Color3.fromRGB(70, 50, 40))
	-- Rooftop units, kept away from the edges so nothing blocks a wall climb.
	local top = center.Y + size.Y
	prop(parent, name .. "AC", Vector3.new(3, 2, 2.4), Vector3.new(center.X - size.X / 5, top + 1, center.Z), {
		color = Color3.fromRGB(150, 154, 160),
		material = Enum.Material.Metal,
	})
	prop(
		parent,
		name .. "Vent",
		Vector3.new(1.2, 1.4, 1.2),
		Vector3.new(center.X + size.X / 5, top + 0.7, center.Z + 1),
		{
			color = COLORS.metal,
			material = Enum.Material.Metal,
		}
	)
	return body
end

local function waterTower(parent: Instance, center: Vector3)
	for _, offset in
		{ Vector3.new(-1.8, 0, -1.8), Vector3.new(1.8, 0, -1.8), Vector3.new(-1.8, 0, 1.8), Vector3.new(1.8, 0, 1.8) }
	do
		prop(parent, "WaterTowerLeg", Vector3.new(0.4, 4, 0.4), center + offset + Vector3.new(0, 2, 0), {
			color = COLORS.metal,
			material = Enum.Material.Metal,
		})
	end
	prop(
		parent,
		"WaterTowerTank",
		Vector3.new(5, 6, 6),
		CFrame.new(center + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = COLORS.wood,
			material = Enum.Material.WoodPlanks,
			shape = Enum.PartType.Cylinder,
		}
	)
	prop(
		parent,
		"WaterTowerCap",
		Vector3.new(1.4, 6.6, 6.6),
		CFrame.new(center + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = COLORS.roof,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		}
	)
end

-- Kiosks double as Washout shelters. `facing` is a yaw in degrees: -90 opens
-- east, 90 west. The striped roof is paintable like everything else.
local function kiosk(parent: Instance, zones: Instance, name: string, center: Vector3, facing: number, stripe: Color3)
	local origin = CFrame.new(center) * CFrame.Angles(0, math.rad(facing), 0)
	local wall = { color = COLORS.tanBrick, material = Enum.Material.Brick }
	-- In kiosk space the open side faces local -Z.
	box(parent, name .. "Back", Vector3.new(18, 11, 2), origin * CFrame.new(0, 5.5, 8), wall)
	box(parent, name .. "Left", Vector3.new(2, 11, 16), origin * CFrame.new(-8, 5.5, 0), wall)
	box(parent, name .. "Right", Vector3.new(2, 11, 16), origin * CFrame.new(8, 5.5, 0), wall)
	for index = 0, 4 do
		box(
			parent,
			name .. "Roof" .. index,
			Vector3.new(22, 1, 4.4),
			origin * CFrame.new(0, 11.5, -8.8 + index * 4.4),
			{
				color = if index % 2 == 0 then stripe else Color3.fromRGB(245, 242, 235),
				material = Enum.Material.Fabric,
			}
		)
	end
	prop(parent, name .. "Counter", Vector3.new(10, 3, 2), origin * CFrame.new(0, 1.5, 5), {
		color = COLORS.wood,
		material = Enum.Material.WoodPlanks,
	})
	local volume = zone(zones, name .. "Shelter", "Shelter", Vector3.new(14, 11, 16), origin * CFrame.new(0, 5.5, -1))
	volume:SetAttribute("Kiosk", name)
end

local function lamp(parent: Instance, position: Vector3, facing: number)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	prop(parent, "LampPole", Vector3.new(0.5, 13, 0.5), base * CFrame.new(0, 6.5, 0), {
		color = COLORS.metal,
		material = Enum.Material.Metal,
	})
	prop(parent, "LampArm", Vector3.new(0.35, 0.35, 3), base * CFrame.new(0, 12.8, -1.4), {
		color = COLORS.metal,
		material = Enum.Material.Metal,
	})
	local head = prop(parent, "LampHead", Vector3.new(1.4, 0.5, 1.6), base * CFrame.new(0, 12.5, -2.8), {
		color = COLORS.lamp,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = COLORS.lamp
	light.Range = 20
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = head
end

local function bench(parent: Instance, position: Vector3, facing: number)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	local wood = { color = COLORS.wood, material = Enum.Material.WoodPlanks }
	prop(parent, "BenchSeat", Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.6, 0), wood)
	prop(parent, "BenchBack", Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.6, 0.75), wood)
	for _, x in { -2.1, 2.1 } do
		prop(parent, "BenchLeg", Vector3.new(0.3, 1.4, 1.4), base * CFrame.new(x, 0.7, 0), {
			color = COLORS.metal,
			material = Enum.Material.Metal,
		})
	end
end

local function cone(parent: Instance, position: Vector3)
	prop(parent, "ConeBase", Vector3.new(1.4, 0.2, 1.4), position + Vector3.new(0, 0.1, 0), {
		color = Color3.fromRGB(255, 110, 30),
	})
	prop(
		parent,
		"Cone",
		Vector3.new(1.6, 0.7, 0.7),
		CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = Color3.fromRGB(255, 110, 30),
			shape = Enum.PartType.Cylinder,
		}
	)
	prop(
		parent,
		"ConeBand",
		Vector3.new(0.35, 0.74, 0.74),
		CFrame.new(position + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = Color3.fromRGB(245, 245, 245),
			shape = Enum.PartType.Cylinder,
		}
	)
end

local function barrel(parent: Instance, position: Vector3, color: Color3)
	prop(
		parent,
		"Barrel",
		Vector3.new(3, 2, 2),
		CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = color,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		}
	)
end

local function bin(parent: Instance, position: Vector3)
	prop(
		parent,
		"Bin",
		Vector3.new(2.6, 1.8, 1.8),
		CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		{
			color = Color3.fromRGB(46, 90, 64),
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		}
	)
end

local function bouncePad(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: number,
	power: number,
	forward: number
)
	prop(
		parent,
		name .. "Rim",
		Vector3.new(7, 0.3, 7),
		CFrame.new(position - Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.rad(facing), 0),
		{
			color = COLORS.metal,
			material = Enum.Material.DiamondPlate,
		}
	)
	local pad =
		prop(parent, name, Vector3.new(6, 0.5, 6), CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0), {
			color = COLORS.pad,
			material = Enum.Material.Neon,
			tags = { "BouncePad" },
		})
	pad:SetAttribute("Power", power)
	pad:SetAttribute("Forward", forward)
	return pad
end

-- A board on two posts with spray-painted text facing `facing` (yaw, degrees).
local function billboard(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: number,
	size: Vector2,
	text: string,
	color: Color3
)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	local board = prop(parent, name, Vector3.new(size.X, size.Y, 0.6), base * CFrame.new(0, size.Y / 2 + 3, 0), {
		color = Color3.fromRGB(28, 28, 34),
	})
	for _, x in { -size.X / 3, size.X / 3 } do
		prop(parent, name .. "Post", Vector3.new(0.5, 3.2, 0.5), base * CFrame.new(x, 1.6, 0.2), {
			color = COLORS.metal,
			material = Enum.Material.Metal,
		})
	end
	graffiti(board, Enum.NormalId.Front, text, color, -3)
	return board
end

local CONTROLS_TEXT = table.concat({
	"M1 attack chain   ·   1 2 3 4 skills   ·   Q dash (hold A/D/S to side-step)",
	"F block   ·   R dive into your paint   ·   G awaken   ·   double-tap W to run",
	"Jump during your 4th hit = uppercut  ·  falling = downslam",
	"Q while ragdolled with a full blue bar = evasive  ·  P settings  ·  M characters",
}, "\n")

-- Map --------------------------------------------------------------------------------

function MapBuilder.build(): (Folder, Folder)
	local map = Instance.new("Folder")
	map.Name = "Map"
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = map

	local ground = { color = COLORS.pavement, material = Enum.Material.Pavement }
	local cliff = { color = COLORS.cliff, material = Enum.Material.Slate }

	-- Island ------------------------------------------------------------------------
	box(map, "MainFloor", Vector3.new(188, 10, 240), Vector3.new(26, -5, 0), ground)
	box(map, "WestStrip", Vector3.new(40, 10, 240), Vector3.new(-100, -5, 0), ground)
	prop(map, "CliffEast", Vector3.new(188, 22, 240), Vector3.new(26, -21, 0), cliff)
	prop(map, "CliffWest", Vector3.new(40, 22, 240), Vector3.new(-100, -21, 0), cliff)
	prop(map, "CanalBed", Vector3.new(12, 2, 240), Vector3.new(-74, -13, 0), cliff)
	for _, z in { -119.5, 119.5 } do
		box(map, "Curb", Vector3.new(188, 0.5, 1), Vector3.new(26, 0.25, z), { color = COLORS.curb })
		box(map, "Curb", Vector3.new(40, 0.5, 1), Vector3.new(-100, 0.25, z), { color = COLORS.curb })
	end
	box(map, "Curb", Vector3.new(1, 0.5, 238), Vector3.new(119.5, 0.25, 0), { color = COLORS.curb })
	box(map, "Curb", Vector3.new(1, 0.5, 238), Vector3.new(-119.5, 0.25, 0), { color = COLORS.curb })

	-- The rinse canal: deadly water (terrain) between the west strip and the rest.
	zone(zones, "RinseKill", "Hazard", Vector3.new(12, 6, 240), Vector3.new(-74, -8, 0))
	for _, z in { -60, 60 } do
		box(map, "CanalBridge", Vector3.new(12, 2, 10), Vector3.new(-74, -1, z), {
			color = COLORS.wood,
			material = Enum.Material.WoodPlanks,
		})
		for _, side in { -4.6, 4.6 } do
			prop(props, "BridgeRail", Vector3.new(12, 0.4, 0.3), Vector3.new(-74, 2.2, z + side), {
				color = COLORS.metal,
				material = Enum.Material.Metal,
			})
			for _, x in { -79, -74, -69 } do
				prop(props, "BridgePost", Vector3.new(0.3, 2.2, 0.3), Vector3.new(x, 1.1, z + side), {
					color = COLORS.metal,
					material = Enum.Material.Metal,
				})
			end
		end
	end

	-- Roads ---------------------------------------------------------------------------
	local asphalt = { color = COLORS.asphalt, material = Enum.Material.Asphalt }
	box(map, "RoadEastWest", Vector3.new(154, 0.3, 11), Vector3.new(9, 0, 23.5), asphalt)
	box(map, "RoadNorthSouth", Vector3.new(11, 0.3, 138), Vector3.new(-24.5, 0, -51), asphalt)
	local lane = { color = COLORS.lane, collide = false, query = false, shadow = false }
	for x = -62, 82, 8 do
		if math.abs(x) > 44 then
			prop(props, "LaneDash", Vector3.new(3.5, 0.05, 0.35), Vector3.new(x, 0.17, 23.5), lane)
		end
	end
	for z = -116, 12, 8 do
		if z < -54 then
			prop(props, "LaneDash", Vector3.new(0.35, 0.05, 3.5), Vector3.new(-24.5, 0.17, z), lane)
		end
	end

	-- Mixer Plaza: the central stage with the sweeper ----------------------------------
	local marble = { color = COLORS.marble, material = Enum.Material.Marble }
	box(map, "PlazaTiles", Vector3.new(80, 0.4, 80), Vector3.new(0, 0, -10), {
		color = Color3.fromRGB(206, 200, 190),
		material = Enum.Material.Slate,
	})
	box(map, "Stage", Vector3.new(48, 6, 48), Vector3.new(0, 3, -10), marble)
	ramp(map, "StageRampSouth", Vector3.new(0, 0, 34), Vector3.new(0, 6, 14), 14, 2, marble)
	ramp(map, "StageRampNorth", Vector3.new(0, 0, -54), Vector3.new(0, 6, -34), 14, 2, marble)
	ramp(map, "StageRampEast", Vector3.new(44, 0, -10), Vector3.new(24, 6, -10), 14, 2, marble)
	ramp(map, "StageRampWest", Vector3.new(-44, 0, -10), Vector3.new(-24, 6, -10), 14, 2, marble)
	prop(map, "SweeperPost", Vector3.new(3, 4, 3), Vector3.new(0, 8, -10), {
		color = COLORS.metal,
		material = Enum.Material.Metal,
	})
	local bar = prop(map, "SweeperBar", Vector3.new(42, 1.6, 1.6), Vector3.new(0, 7.6, -10), {
		color = COLORS.sweeper,
		material = Enum.Material.Neon,
		collide = false,
		query = false,
	})
	bar:SetAttribute("ArmLength", 21)
	bar:SetAttribute("Speed", 1.1)

	-- Buildings ----------------------------------------------------------------------
	local brickNW = building(map, "BrickApartment", Vector3.new(-58, 0, -72), Vector3.new(14, 16, 14), "RedBrick")
	local tanNE = building(map, "TanApartment", Vector3.new(62, 0, -74), Vector3.new(16, 26, 16), "TanBrick")
	local tower = building(map, "TallTower", Vector3.new(72, 0, 52), Vector3.new(14, 36, 14), "Concrete")
	local brickSW = building(map, "CornerShop", Vector3.new(-46, 0, 40), Vector3.new(18, 22, 18), "RedBrick")
	local warehouse = building(map, "Warehouse", Vector3.new(95, 0, 50), Vector3.new(18, 14, 24), "Warehouse")
	local block = building(map, "PrintShop", Vector3.new(-55, 0, 5), Vector3.new(20, 12, 20), "Concrete")
	box(map, "PrintShopTop", Vector3.new(8, 6, 8), Vector3.new(-55, 15, 5), {
		color = COLORS.concrete,
		material = Enum.Material.Concrete,
	})
	waterTower(props, Vector3.new(72, 36, 52))
	ramp(map, "SkyBridge", Vector3.new(66, 26, -66), Vector3.new(70, 36, 45), 5, 1.5, {
		color = COLORS.metal,
		material = Enum.Material.DiamondPlate,
	})
	graffiti(brickNW, Enum.NormalId.Right, "WET PAINT", Color3.fromRGB(255, 90, 160), -6)
	graffiti(tanNE, Enum.NormalId.Left, "DYE DISTRICT", Color3.fromRGB(80, 220, 255), 4)
	graffiti(tower, Enum.NormalId.Left, "SPLASH ZONE", Color3.fromRGB(255, 196, 64), -4)
	graffiti(brickSW, Enum.NormalId.Front, "NO RINSING", Color3.fromRGB(160, 255, 90), 5)
	graffiti(warehouse, Enum.NormalId.Left, "PIGMENT CO.", Color3.fromRGB(255, 255, 255), 0)
	graffiti(block, Enum.NormalId.Right, "PRINT SHOP", Color3.fromRGB(255, 120, 60), -3)

	-- Cover walls and crates ---------------------------------------------------------
	local brickWall = { color = COLORS.redBrick, material = Enum.Material.Brick }
	local southWest = box(map, "WallSouthWest", Vector3.new(30, 10, 3), Vector3.new(-32, 5, 62), brickWall)
	box(map, "WallEast", Vector3.new(3, 10, 30), Vector3.new(40, 5, 10), brickWall)
	local southEast = box(map, "WallSouthEast", Vector3.new(30, 10, 3), Vector3.new(40, 5, 75), brickWall)
	box(map, "WallNorthWest", Vector3.new(3, 12, 36), Vector3.new(-40, 6, -40), brickWall)
	local north = box(map, "WallNorth", Vector3.new(24, 8, 3), Vector3.new(10, 4, -75), brickWall)
	graffiti(southWest, Enum.NormalId.Front, "SPLOTCH!", Color3.fromRGB(255, 196, 64), -5)
	graffiti(southEast, Enum.NormalId.Front, "KEEP IT WET", Color3.fromRGB(110, 160, 255), 4)
	graffiti(north, Enum.NormalId.Back, "TAG YOU'RE IT", Color3.fromRGB(255, 90, 90), -3)
	local crate = { color = COLORS.wood, material = Enum.Material.WoodPlanks }
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
		box(map, "Crate" .. index, Vector3.new(6, 6, 6), position, crate)
	end

	-- Gallery: spawn pavilion (safe zone + shelter) -----------------------------------
	for _, x in { -23.5, 23.5 } do
		for _, z in { 86.5, 113.5 } do
			box(map, "GalleryColumn", Vector3.new(3, 18, 3), Vector3.new(x, 9, z), marble)
		end
	end
	box(map, "GalleryRoof", Vector3.new(54, 2, 34), Vector3.new(0, 19, 100), {
		color = COLORS.roof,
		material = Enum.Material.Slate,
	})
	local backWall = box(map, "GalleryWall", Vector3.new(50, 18, 2), Vector3.new(0, 9, 116), {
		color = COLORS.tanBrick,
		material = Enum.Material.Brick,
	})
	local controls = surfaceGui(backWall, Enum.NormalId.Front, 12)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.6, 0)
	label.Size = UDim2.new(0.86, 0, 0.42, 0)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	label.Font = Enum.Font.Oswald
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 245, 248)
	label.Text = CONTROLS_TEXT
	label.Parent = controls
	local sign = prop(map, "GallerySign", Vector3.new(34, 7, 1), Vector3.new(0, 23.5, 86), {
		color = Color3.fromRGB(24, 24, 30),
	})
	graffiti(sign, Enum.NormalId.Front, "SPLOTCH", Color3.fromRGB(255, 120, 200), -2)
	zone(zones, "GallerySafe", "SafeZone", Vector3.new(50, 18, 30), Vector3.new(0, 9, 100))
	zone(zones, "GalleryShelter", "Shelter", Vector3.new(50, 18, 30), Vector3.new(0, 9, 100))
	for index, x in { -14, 0, 14 } do
		prop(map, "SpawnPad" .. index, Vector3.new(6, 0.3, 6), Vector3.new(x, 0.15, 106), {
			color = COLORS.spawn,
			material = Enum.Material.Neon,
			tags = { "SpawnPad" },
		})
	end
	bench(props, Vector3.new(-17, 0, 92), 180)
	bench(props, Vector3.new(17, 0, 92), 180)

	-- Practice yard: training dummies just outside the safe zone ---------------------
	box(map, "PracticeYard", Vector3.new(36, 0.3, 28), Vector3.new(55, 0, 100), {
		color = Color3.fromRGB(120, 124, 132),
		material = Enum.Material.Concrete,
	})
	for _, spot in { { 46, false }, { 64, true } } do
		local pad = prop(
			map,
			"DummyPad",
			Vector3.new(5, 0.3, 5),
			CFrame.lookAt(Vector3.new(spot[1], 0.3, 98), Vector3.new(spot[1] - 1, 0.3, 98)),
			{
				color = if spot[2] then Color3.fromRGB(110, 160, 255) else Color3.fromRGB(255, 196, 64),
				material = Enum.Material.Neon,
				tags = { "DummySpot" },
			}
		)
		pad:SetAttribute("Blocking", spot[2])
	end
	billboard(
		props,
		"PracticeSign",
		Vector3.new(55, 0, 112),
		180,
		Vector2.new(16, 5),
		"PRACTICE YARD",
		Color3.fromRGB(255, 196, 64)
	)

	-- Shelters for the Washout -------------------------------------------------------
	kiosk(map, zones, "KioskNorthWest", Vector3.new(-100, 0, -95), -90, Color3.fromRGB(230, 70, 70))
	kiosk(map, zones, "KioskSouthWest", Vector3.new(-100, 0, 95), -90, Color3.fromRGB(70, 150, 230))
	kiosk(map, zones, "KioskNorthEast", Vector3.new(95, 0, -95), 90, Color3.fromRGB(240, 180, 40))
	kiosk(map, zones, "KioskEast", Vector3.new(100, 0, 10), 90, Color3.fromRGB(120, 200, 90))

	-- Bounce pads ---------------------------------------------------------------------
	bouncePad(props, "PadTanApartment", Vector3.new(62, 0.25, -56), 0, 105, 14)
	bouncePad(props, "PadSouthWest", Vector3.new(-30, 0.25, 72), 0, 90, 0)
	bouncePad(props, "PadNorth", Vector3.new(40, 0.25, -40), 0, 90, 0)
	bouncePad(props, "PadWestStrip", Vector3.new(-100, 0.25, 0), 0, 90, 0)

	-- Street dressing ------------------------------------------------------------------
	for _, x in { -60, -30, 30, 60 } do
		lamp(props, Vector3.new(x, 0, 31), 0)
		lamp(props, Vector3.new(x + 12, 0, 16), 180)
	end
	for _, z in { -110, -84, -58 } do
		lamp(props, Vector3.new(-32, 0, z), 90)
		lamp(props, Vector3.new(-17, 0, z + 12), -90)
	end
	lamp(props, Vector3.new(-104, 0, -40), -90)
	lamp(props, Vector3.new(-104, 0, 40), -90)
	for _, position in
		{
			Vector3.new(-14, 0, 31),
			Vector3.new(14, 0, 31),
			Vector3.new(-20, 0, -104),
			Vector3.new(-29, 0, -80),
		}
	do
		cone(props, position)
	end
	for _, position in { Vector3.new(84, 0, 64), Vector3.new(87, 0, 66), Vector3.new(106, 0, 66) } do
		barrel(props, position, Color3.fromRGB(60, 110, 200))
	end
	barrel(props, Vector3.new(-62, 0, -26), Color3.fromRGB(200, 60, 50))
	bin(props, Vector3.new(-20, 0, 33))
	bin(props, Vector3.new(34, 0, 14))
	bin(props, Vector3.new(-66, 0, 34))
	billboard(
		props,
		"CanalSign",
		Vector3.new(-84, 0, -48),
		-90,
		Vector2.new(12, 4),
		"RINSE CANAL - KEEP OUT",
		Color3.fromRGB(80, 220, 255)
	)

	-- A distant skyline for depth. Not solid, never queried.
	local skyline = {
		color = COLORS.skyline,
		material = Enum.Material.Concrete,
		collide = false,
		query = false,
		shadow = false,
	}
	for index = 0, 15 do
		local angle = index / 16 * math.pi * 2 + rand() * 0.2
		local distance = 420 + rand() * 120
		local height = 60 + rand() * 120
		local width = 40 + rand() * 50
		prop(
			props,
			"Skyline",
			Vector3.new(width, height, width * 0.8),
			CFrame.new(math.cos(angle) * distance, height / 2 - 30, math.sin(angle) * distance)
				* CFrame.Angles(0, -angle, 0),
			skyline
		)
	end

	return map, zones
end

-- Terrain water: the rinse sea around the island and the canal. Server only.
function MapBuilder.terrain(terrain: Terrain)
	terrain:FillBlock(CFrame.new(0, -31, 0), Vector3.new(1400, 14, 1400), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(-74, -9, 0), Vector3.new(12, 6, 240), Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(40, 150, 170)
	terrain.WaterTransparency = 0.25
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
end

return MapBuilder
