--!nocheck
-- Headless runtime check. Loads the BUILT place file with Lune, shims the few engine methods Lune lacks, then
-- runs the real world builders (map, every base tier, crystals, brainrots) to catch runtime errors that static
-- analysis can't see. Optionally dumps geometry to JSON for the preview renderer (scripts/render.py).
-- Usage: lune run tests/runtime <place.rbxlx> [dump.json]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local placePath = process.args[1] or "builds/BeamABrainrot.rbxlx"
local dumpPath = process.args[2]

-- Lune's CFrame.lookAt returns wrong orientations for some directions; Roblox's is correct. Use a faithful version
-- so previews and checks match the real engine.
local function fixedLookAt(at, target, upVector)
	local look = (target - at).Unit
	local up = upVector or roblox.Vector3.new(0, 1, 0)
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(roblox.Vector3.new(0, 0, 1))
	end
	right = right.Unit
	local up2 = right:Cross(look).Unit
	return roblox.CFrame.fromMatrix(at, right, up2, -look)
end
local CFrameShim = setmetatable({ lookAt = fixedLookAt }, { __index = roblox.CFrame })

local CFrame = CFrameShim
local Vector3 = roblox.Vector3

-- Engine shims -----------------------------------------------------------------------------------------------
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild would hang: " .. self:GetFullName() .. "." .. name)
	return child
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock()
end)
roblox.implementProperty("BasePart", "Position", function(self)
	return self.CFrame.Position
end, function(self, value)
	self.CFrame = CFrame.new(value) * self.CFrame.Rotation
end)

local function pivotOf(model)
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local current = pivotOf(self)
	local delta = target * current:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	local state = math.floor(seed or os.clock() * 1000) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, RandomShim)
end
function RandomShim:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local r = self.state / 2147483647
	if min then
		return min + (max - min) * r
	end
	return r
end
function RandomShim:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1))
end

-- Module loader ----------------------------------------------------------------------------------------------
local game = roblox.deserializePlace(fs.readFile(placePath))
local cache = {}
local function loadModule(module)
	local key = module:GetFullName()
	if cache[key] ~= nil then
		return cache[key]
	end
	local chunk = luau.load(module.Source, {
		debugName = module:GetFullName(),
		environment = {
			script = module,
			game = game,
			workspace = game:GetService("Workspace"),
			require = loadModule,
			task = task,
			Random = RandomShim,
			Instance = roblox.Instance,
			Vector3 = Vector3,
			Vector2 = roblox.Vector2,
			CFrame = CFrame,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			NumberRange = roblox.NumberRange,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			BrickColor = roblox.BrickColor,
		},
	})
	local result = chunk()
	cache[key] = result
	return result
end

local failures = 0
local function check(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name .. "\n    " .. tostring(err))
	end
end

local function countParts(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			local p = d.CFrame.Position
			assert(p.X == p.X and p.Y == p.Y and p.Z == p.Z, "NaN position in " .. d:GetFullName())
			assert(d.Size.X > 0 and d.Size.Y > 0 and d.Size.Z > 0, "zero size part " .. d:GetFullName())
		end
	end
	return n
end

local Workspace = game:GetService("Workspace")
local Server = game:GetService("ServerScriptService").Server
local Shared = game:GetService("ReplicatedStorage").Shared

local mapService
check("MapService builds the world", function()
	mapService = loadModule(Server.Services.MapService)
	mapService.Init()
	local map = Workspace:FindFirstChild("Map")
	assert(map, "no Map folder")
	local n = countParts(map)
	assert(n > 300, "map suspiciously small: " .. n)
	assert(#mapService.LeaderboardAnchors() == 3, "leaderboard anchors")
	print(string.format("    map parts: %d", n))
end)

local BaseBuilder
check("BaseBuilder builds every tier", function()
	BaseBuilder = loadModule(Server.Modules.BaseBuilder)
	local Economy = loadModule(Shared.Config.Economy)
	for tier = 1, 10 do
		local folder = roblox.Instance.new("Folder")
		folder.Name = "Plot" .. tier
		folder.Parent = Workspace:FindFirstChild("Plots")
		local plotCf = mapService.PlotCFrame(((tier - 1) % 8) + 1)
		local parts = BaseBuilder.Build(plotCf, tier, tier - 1, "Tester" .. tier, folder)
		assert(parts.Door.PrimaryPart, "door panel")
		assert(parts.Crystal.PrimaryPart, "crystal core")
		assert(parts.Crystal.PrimaryPart:FindFirstChild("BeamOrigin"), "beam origin")
		local unlocked = 0
		for slot, pedestal in parts.Pedestals do
			if not pedestal.Locked then
				unlocked += 1
			end
		end
		assert(unlocked == Economy.Slots(tier), "unlocked pedestals for tier " .. tier)
		local n = countParts(parts.Model)
		assert(n > 100 and n < 900, "tier " .. tier .. " part count " .. n)
		print(string.format("    tier %d (%s): %d parts", tier, parts.Model:GetAttribute("Theme"), n))
		if tier > 8 then
			parts.Model:Destroy()
		end
	end
	BaseBuilder.BuildEmpty(mapService.PlotCFrame(1), Workspace)
end)

check("Pedestal brainrots fit and spawn on every slot", function()
	local BrainrotBuilder = loadModule(Shared.Modules.BrainrotBuilder)
	local Brainrots = loadModule(Shared.Config.Brainrots)
	local plotCf = mapService.PlotCFrame(1)
	local holder = roblox.Instance.new("Folder")
	holder.Name = "PreviewBrainrots"
	holder.Parent = Workspace
	for slot = 1, BaseBuilder.MaxSlots do
		local def = Brainrots.List[((slot - 1) % #Brainrots.List) + 1]
		local scale = BrainrotBuilder.FitScale(def.Id, 5.2, 4.6)
		local model =
			BrainrotBuilder.Build(def.Id, { Mutation = if slot % 5 == 0 then "Gold" else "None", Scale = scale })
		model:PivotTo(plotCf * BaseBuilder.SlotLocalCFrame(slot) * CFrame.new(0, 0.6, 0))
		model.Parent = holder
	end
	-- A wave walker in front of plot 2 and a giant boss in front of plot 3, as they'd appear on clients.
	local MapGeometry = loadModule(Shared.Modules.MapGeometry)
	for i, spec in
		{ { "tostapane_squalone", 2, 1.3 }, { "vulcano_pollastro", 3, 2.6 * 1.3 }, { "coppa_gattina", 4, 1.3 } }
	do
		local model = BrainrotBuilder.Build(spec[1], { Scale = spec[3] })
		local stop = MapGeometry.StopPosition(spec[2])
		local edge = MapGeometry.PortalEdge(spec[2])
		model:PivotTo(CFrame.lookAt(stop, stop + (stop - edge).Unit))
		model.Parent = holder
		print("    walker " .. i .. " height " .. tostring(model:GetAttribute("Height")))
	end
end)

check("Every ModuleScript in the place requires cleanly", function()
	local roots = {
		game:GetService("ReplicatedStorage"):FindFirstChild("Shared"),
		Server,
		game:GetService("StarterPlayer").StarterPlayerScripts.Client,
	}
	local count = 0
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("ModuleScript") then
				local ok, err = pcall(loadModule, d)
				assert(ok, d:GetFullName() .. ": " .. tostring(err))
				count += 1
			end
		end
	end
	print("    modules loaded: " .. count)
end)

check("Bonk Bat tool builds", function()
	local RaidService = loadModule(Server.Services.RaidService)
	RaidService.Init()
	local tool = game:GetService("ServerStorage"):FindFirstChild("Bonk Bat")
	assert(tool and tool:FindFirstChild("Handle"), "tool with handle")
end)

if dumpPath then
	-- Geometry dump for scripts/render.py
	local out = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local shape = "Block"
			if d:IsA("WedgePart") then
				shape = "Wedge"
			elseif d:IsA("Part") then
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				if mesh and mesh.MeshType == roblox.Enum.MeshType.Sphere then
					shape = "Ellipsoid"
				elseif d.Shape == roblox.Enum.PartType.Cylinder then
					shape = "Cylinder"
				elseif d.Shape == roblox.Enum.PartType.Ball then
					shape = "Ball"
				end
			end
			local cf = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			table.insert(out, {
				s = shape,
				sz = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = { d.Color.R, d.Color.G, d.Color.B },
				t = d.Transparency,
				n = if d.Material == roblox.Enum.Material.Neon then 1 else 0,
			})
		end
	end
	local serde = require("@lune/serde")
	fs.writeFile(dumpPath, serde.encode("json", out))
	print(string.format("    dumped %d parts to %s", #out, dumpPath))
end

if failures > 0 then
	print(string.format("%d runtime check(s) failed", failures))
	process.exit(1)
end
print("runtime checks passed")
