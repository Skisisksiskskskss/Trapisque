--!nocheck
-- End-to-end server simulation. Boots the REAL server scripts from the built place inside Lune with mocked
-- Players / RunService / Net, fakes players and characters, and plays scripted scenarios: join, welcome wave,
-- capture, income + pad collect, upgrades, boss/door break, steal + carry home, bonk drop, owner-leave cancel,
-- rebirth, save + rejoin. Timings are shortened so the whole run takes a few seconds of real time.
-- Usage: lune run tests/sim <place.rbxlx>

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local placePath = process.args[1] or "builds/BeamABrainrot.rbxlx"

-- Signals ----------------------------------------------------------------------------------------------------
local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local entry = { fn = fn, connected = true }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				entry.connected = false
			end,
			Connected = true,
		}
	end
	function signal:Once(fn)
		local conn
		conn = signal:Connect(function(...)
			conn.Disconnect()
			fn(...)
		end)
		return conn
	end
	function signal:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.connected then
				task.spawn(entry.fn, ...)
			end
		end
	end
	function signal:Wait()
		local thread = coroutine.running()
		signal:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	return signal
end

-- Engine shims (same as runtime.luau, plus events) -----------------------------------------------------------
local function fixedLookAt(at, target, upVector)
	local look = (target - at).Unit
	local up = upVector or roblox.Vector3.new(0, 1, 0)
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(roblox.Vector3.new(0, 0, 1))
	end
	right = right.Unit
	return roblox.CFrame.fromMatrix(at, right, right:Cross(look).Unit, -look)
end
local CFrame = setmetatable({ lookAt = fixedLookAt }, { __index = roblox.CFrame })
local Vector3 = roblox.Vector3

-- Lune returns a new wrapper object per access, so look instances up by equality rather than table identity.
local signalRegistry = {}
local function instanceSignal(instance, name)
	for _, entry in signalRegistry do
		if entry.instance == instance then
			if not entry.signals[name] then
				entry.signals[name] = newSignal()
			end
			return entry.signals[name]
		end
	end
	local entry = { instance = instance, signals = { [name] = newSignal() } }
	table.insert(signalRegistry, entry)
	return entry.signals[name]
end

roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	local waited = 0
	while not child and waited < 5 do
		task.wait(0.05)
		waited += 0.05
		child = self:FindFirstChild(name)
	end
	return child
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock()
end)
roblox.implementMethod("DataModel", "BindToClose", function() end)
local guidCounter = 0
roblox.implementMethod("HttpService", "GenerateGUID", function()
	guidCounter += 1
	return "guid-" .. guidCounter
end)
roblox.implementProperty("BasePart", "Position", function(self)
	return self.CFrame.Position
end, function(self, value)
	self.CFrame = CFrame.new(value) * self.CFrame.Rotation
end)
roblox.implementProperty("BasePart", "Touched", function(self)
	return instanceSignal(self, "Touched")
end)
roblox.implementProperty("Tool", "Activated", function(self)
	return instanceSignal(self, "Activated")
end)
roblox.implementProperty("Humanoid", "Died", function(self)
	return instanceSignal(self, "Died")
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
	return instanceSignal(self, "Attr:" .. name)
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
	local delta = target * pivotOf(self):Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ state = math.floor(seed or 12345) % 2147483647 + 1 }, RandomShim)
end
function RandomShim:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local r = self.state / 2147483647
	return if min then min + (max - min) * r else r
end
function RandomShim:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1))
end

-- Mocked services --------------------------------------------------------------------------------------------
local game = roblox.deserializePlace(fs.readFile(placePath))
local Workspace = game:GetService("Workspace")

local log = {} -- remote traffic: { kind, name, target, args }
local function record(kind, name, target, ...)
	table.insert(log, { kind = kind, name = name, target = target, args = table.pack(...) })
end

local remotes = {}
local NetMock = { EventNames = {}, FunctionNames = {} }
function NetMock.Setup() end
function NetMock.Event(name)
	if not remotes[name] then
		remotes[name] = {
			OnServerEvent = newSignal(),
			FireClient = function(_, player, ...)
				record("client", name, player, ...)
			end,
			FireAllClients = function(_, ...)
				record("all", name, nil, ...)
			end,
		}
	end
	return remotes[name]
end
function NetMock.Function(name)
	if not remotes[name] then
		remotes[name] = { OnServerInvoke = nil }
	end
	return remotes[name]
end

local players = {}
local PlayersMock = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
}
function PlayersMock:GetPlayers()
	local list = {}
	for _, p in players do
		if p.Parent ~= nil then
			table.insert(list, p)
		end
	end
	return list
end
function PlayersMock:GetPlayerByUserId(id)
	for _, p in players do
		if p.UserId == id and p.Parent ~= nil then
			return p
		end
	end
	return nil
end

local RunServiceMock = { Heartbeat = newSignal(), Stepped = newSignal() }
function RunServiceMock:IsStudio()
	return true
end
function RunServiceMock:IsServer()
	return true
end
task.spawn(function()
	while true do
		task.wait(1 / 30)
		RunServiceMock.Heartbeat:Fire(1 / 30)
	end
end)

local overrides = {
	Players = PlayersMock,
	RunService = RunServiceMock,
}
local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return overrides[name] or game:GetService(name)
			end
		elseif key == "JobId" then
			return "sim-job"
		elseif key == "BindToClose" then
			return function() end
		end
		local value = game[key]
		if type(value) == "function" then
			return function(_, ...)
				return value(game, ...)
			end
		end
		return value
	end,
})

-- Fake players -----------------------------------------------------------------------------------------------
local realPlayers = game:GetService("Players")
roblox.implementMethod("Player", "Kick", function(self, message)
	self:SetAttribute("Kicked", message or "kicked")
end)
roblox.implementMethod("Player", "IsInGroup", function()
	return false
end)
roblox.implementProperty("Player", "CharacterAdded", function(self)
	return instanceSignal(self, "CharacterAdded")
end)
local function newPlayer(userId, name)
	local player = roblox.Instance.new("Player")
	player.Name = name
	player.UserId = userId
	player.DisplayName = name
	local backpack = roblox.Instance.new("Backpack")
	backpack.Parent = player
	player.Parent = realPlayers
	return player
end

local function spawnCharacter(player)
	local character = roblox.Instance.new("Model")
	character.Name = player.Name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 5, 0)
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.MaxHealth = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

-- Leaderstats: SyncService parents a Folder to the player. Our fake player isn't an Instance, so capture it.
local InstanceProxy = setmetatable({}, { __index = roblox.Instance })
function InstanceProxy.new(className)
	return roblox.Instance.new(className)
end

-- Module loader ----------------------------------------------------------------------------------------------
local cache = {}
local netModule = game:GetService("ReplicatedStorage").Shared.Modules.Net
local env
local function loadModule(module)
	if module:GetFullName() == netModule:GetFullName() then
		return NetMock
	end
	local key = module:GetFullName()
	if cache[key] ~= nil then
		return cache[key]
	end
	-- Lune can't derive BasePart.Position from CFrame, so rewrite part-position reads (harness only).
	local source = module.Source
	source = string.gsub(source, "(%w*[Rr]oot)%.Position([^%w=])", "%1.CFrame.Position%2")
	source = string.gsub(source, "PrimaryPart%.Position", "PrimaryPart.CFrame.Position")
	local chunk = luau.load(source, { debugName = module:GetFullName(), environment = env(module) })
	local result = chunk()
	cache[key] = result
	return result
end
function env(script)
	return {
		script = script,
		game = gameProxy,
		workspace = Workspace,
		require = loadModule,
		task = task,
		Random = RandomShim,
		Instance = InstanceProxy,
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
		warn = function(...)
			print("WARN", ...)
		end,
		print = print,
	}
end

-- Speed everything up before services read the config.
local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = loadModule(Shared.Config.GameConfig)
GameConfig.WaveInterval = 4
GameConfig.FirstWaveDelay = 0.3
GameConfig.EmergeTime = 0.1
GameConfig.WalkSpeed = 400
GameConfig.ShowdownTime = 0.2
GameConfig.EscapeSpeed = 2000
GameConfig.CarryTimeout = 60

-- The server bootstrap waits for "Server.Services" children and requires DataService again: reuse the cache.
local serverScript = game:GetService("ServerScriptService").Server
local boot = luau.load(serverScript.Source, { debugName = "Server", environment = env(serverScript) })

local failures = 0
local function check(name, condition, detail)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name .. (if detail then " :: " .. tostring(detail) else ""))
	end
end
local function waitFor(predicate, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

local ok, err = pcall(boot)
check("server bootstrap runs", ok, err)
local Services = serverScript.Services
local DataService = loadModule(Services.DataService)
local PlotService = loadModule(Services.PlotService)
local BrainrotService = loadModule(Services.BrainrotService)
local WaveService = loadModule(Services.WaveService)
local Economy = loadModule(Shared.Config.Economy)

local scenarioOk, scenarioErr = pcall(function()
	-- Scenario 1: a new player joins and gets the welcome wave ---------------------------------------------------
	local alice = newPlayer(101, "Alice")
	table.insert(players, alice)
	PlayersMock.PlayerAdded:Fire(alice)
	spawnCharacter(alice)
	check(
		"alice's data loads and she gets a plot",
		waitFor(function()
			return alice:GetAttribute("Plot") ~= nil
		end),
		alice:GetAttribute("Kicked")
	)
	local alicePlot = PlotService.ForPlayer(alice)
	check("alice's base is built", alicePlot and alicePlot.Parts and alicePlot.Parts.Model.Parent ~= nil)
	check(
		"welcome wave beams her first brainrot",
		waitFor(function()
			local data = DataService.Get(alice)
			return data and next(data.Brainrots) ~= nil
		end, 4)
	)
	local aliceData = DataService.Get(alice)
	check("first brainrot is placed on slot 1", aliceData.Slots["1"] ~= nil)
	check("pedestal model spawned", BrainrotService.ModelAt(alice, 1) ~= nil)

	-- Income and collecting ----------------------------------------------------------------------------------------
	task.wait(2.2)
	local session = DataService.GetSession(alice)
	check("income accrues on the pad", (session.Pending[1] or 0) > 0, session.Pending[1])
	local pad = alicePlot.Parts.Pedestals[1].Pad
	local before = aliceData.Cash
	pad.Touched:Fire(alice.Character.HumanoidRootPart)
	task.wait(0.1)
	check("touching the pad collects cash", aliceData.Cash > before, aliceData.Cash)

	-- Upgrades ----------------------------------------------------------------------------------------------------
	aliceData.Cash = 1e6
	local upgrade = NetMock.Function("Upgrade").OnServerInvoke
	local okUp, msg = upgrade(alice, "Crystal")
	check("crystal upgrade works", okUp and aliceData.CrystalLevel == 2, msg)
	task.wait(0.1)
	local okDoor = upgrade(alice, "Door")
	check("door upgrade works", okDoor and aliceData.DoorLevel == 2)
	local okTier, tierMsg = upgrade(alice, "Tier")
	check("tier upgrade is gated on a maxed crystal", not okTier, tierMsg)
	aliceData.CrystalLevel = 10
	task.wait(0.1)
	okTier = upgrade(alice, "Tier")
	check("tier upgrade works once the crystal is maxed", okTier and aliceData.Tier == 2)
	check("base rebuilt in the new theme", alicePlot.Parts.Model:GetAttribute("Tier") == 2)
	check("brainrot respawned after rebuild", BrainrotService.ModelAt(alice, 1) ~= nil)
	local badUpgrade = upgrade(alice, 12345)
	check("bad upgrade payload is rejected", badUpgrade == false)

	-- Global waves keep coming --------------------------------------------------------------------------------------
	local countBefore = 0
	for _ in aliceData.Brainrots do
		countBefore += 1
	end
	waitFor(function()
		local n = 0
		for _ in aliceData.Brainrots do
			n += 1
		end
		return n > countBefore
	end, 10)
	local countAfter = 0
	for _ in aliceData.Brainrots do
		countAfter += 1
	end
	check("global waves deliver more brainrots", countAfter > countBefore, countAfter)

	-- A second player joins and raids ------------------------------------------------------------------------------
	local bob = newPlayer(202, "Bob")
	table.insert(players, bob)
	PlayersMock.PlayerAdded:Fire(bob)
	spawnCharacter(bob)
	check(
		"bob gets his own plot",
		waitFor(function()
			return bob:GetAttribute("Plot") ~= nil and bob:GetAttribute("Plot") ~= alice:GetAttribute("Plot")
		end)
	)
	local bobPlot = PlotService.ForPlayer(bob)
	waitFor(function()
		return DataService.Get(bob) ~= nil
	end)
	local bobData = DataService.Get(bob)

	local stealRemote = NetMock.Event("Steal").OnServerEvent
	local aliceSlotModel = BrainrotService.ModelAt(alice, 1)
	local function moveTo(player, position)
		player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
	end
	moveTo(bob, aliceSlotModel.PrimaryPart.CFrame.Position + Vector3.new(2, 0, 0))
	stealRemote:Fire(bob, alicePlot.Index, 1)
	task.wait(0.2)
	check("steal is refused while alice's door is intact", bob:GetAttribute("Carrying") ~= true)

	aliceData.Stats.Playtime = 99999 -- past the newbie shield
	PlotService.BreakDoor(alicePlot, 30)
	check("broken door makes alice's base raidable", PlotService.IsRaidable(alicePlot))
	moveTo(bob, aliceSlotModel.PrimaryPart.CFrame.Position + Vector3.new(2, 0, 0))
	task.wait(0.6)
	stealRemote:Fire(bob, alicePlot.Index, 1)
	check(
		"bob grabs alice's brainrot",
		waitFor(function()
			return bob:GetAttribute("Carrying") == true
		end, 2)
	)
	local stolenUid = aliceData.Slots["1"]

	-- Walk (not teleport) home in small steps so the speed check passes.
	local from = bob.Character.HumanoidRootPart.CFrame.Position
	local to = PlotService.SpawnCFrame(bobPlot).Position
	local steps = math.ceil((to - from).Magnitude / 2.5)
	for i = 1, steps do
		moveTo(bob, from:Lerp(to, i / steps))
		task.wait(0.21)
	end
	task.wait(0.4)
	check("stolen brainrot left alice", aliceData.Brainrots[stolenUid] == nil)
	local bobHasOne = next(bobData.Brainrots) ~= nil
	check("bob keeps the stolen brainrot", bobHasOne)
	check("steal stats recorded", (bobData.Stats.Steals or 0) == 1 and (aliceData.Stats.Stolen or 0) == 1)
	check("bob is no longer carrying", bob:GetAttribute("Carrying") ~= true)

	-- Teleport exploit cancels a steal -------------------------------------------------------------------------------
	local giveUid = BrainrotService.Add(alice, "coppa_gattina", "None", "Normal", "Test")
	local giveSlot = BrainrotService.SlotOf(aliceData, giveUid)
	PlotService.BreakDoor(alicePlot, 30)
	local target = BrainrotService.ModelAt(alice, giveSlot)
	moveTo(bob, target.PrimaryPart.CFrame.Position + Vector3.new(1, 0, 0))
	task.wait(0.6)
	stealRemote:Fire(bob, alicePlot.Index, giveSlot)
	waitFor(function()
		return bob:GetAttribute("Carrying") == true
	end, 2)
	moveTo(bob, to)
	task.wait(0.5)
	check(
		"teleporting home with a brainrot cancels the steal",
		aliceData.Brainrots[giveUid] ~= nil and bob:GetAttribute("Carrying") ~= true
	)

	-- Bonk makes a thief drop it -----------------------------------------------------------------------------------
	moveTo(bob, target.PrimaryPart.CFrame.Position + Vector3.new(1, 0, 0))
	task.wait(0.6)
	stealRemote:Fire(bob, alicePlot.Index, giveSlot)
	waitFor(function()
		return bob:GetAttribute("Carrying") == true
	end, 2)
	local aliceTool
	waitFor(function()
		aliceTool = alice:FindFirstChildOfClass("Backpack"):FindFirstChild("Bonk Bat")
		return aliceTool ~= nil
	end, 2)
	check("players get a Bonk Bat", aliceTool ~= nil)
	moveTo(alice, bob.Character.HumanoidRootPart.CFrame.Position + Vector3.new(0, 0, 3))
	alice.Character.HumanoidRootPart.CFrame =
		CFrame.lookAt(alice.Character.HumanoidRootPart.CFrame.Position, bob.Character.HumanoidRootPart.CFrame.Position)
	if aliceTool then
		aliceTool.Activated:Fire()
	end
	task.wait(0.3)
	check(
		"bonk drops the brainrot back home",
		aliceData.Brainrots[giveUid] ~= nil and bob:GetAttribute("Carrying") ~= true
	)
	local knocked = false
	for _, entry in log do
		if entry.name == "Knockback" and entry.target == bob then
			knocked = true
		end
	end
	check("bonked thief receives knockback", knocked)

	-- Owner leaving mid-steal cancels it (no duplication) ----------------------------------------------------------
	moveTo(bob, target.PrimaryPart.CFrame.Position + Vector3.new(1, 0, 0))
	task.wait(1.0)
	stealRemote:Fire(bob, alicePlot.Index, giveSlot)
	waitFor(function()
		return bob:GetAttribute("Carrying") == true
	end, 2)
	local bobCountBefore = 0
	for _ in bobData.Brainrots do
		bobCountBefore += 1
	end
	alice.Parent = nil
	PlayersMock.PlayerRemoving:Fire(alice)
	task.wait(0.5)
	local bobCountAfter = 0
	for _ in bobData.Brainrots do
		bobCountAfter += 1
	end
	check(
		"thief loses the carry when the owner leaves",
		bob:GetAttribute("Carrying") ~= true and bobCountAfter == bobCountBefore
	)
	check("alice's plot is freed", alicePlot.Owner == nil)

	-- Rejoin restores the save ---------------------------------------------------------------------------------------
	local alice2 = newPlayer(101, "Alice")
	table.insert(players, alice2)
	PlayersMock.PlayerAdded:Fire(alice2)
	spawnCharacter(alice2)
	check(
		"alice rejoins",
		waitFor(function()
			return DataService.Get(alice2) ~= nil
		end, 5),
		alice2:GetAttribute("Kicked")
	)
	local reloaded = DataService.Get(alice2)
	check("save kept her tier and brainrots", reloaded and reloaded.Tier == 2 and reloaded.Brainrots[giveUid] ~= nil)

	-- Rebirth ---------------------------------------------------------------------------------------------------------
	reloaded.Tier = Economy.MaxTier
	reloaded.CrystalLevel = Economy.MaxLevelForTier(Economy.MaxTier)
	reloaded.Cash = Economy.RebirthCost(0) + 5
	local rebirth = NetMock.Function("Rebirth").OnServerInvoke
	local okRebirth, rebirthMsg = rebirth(alice2)
	check("rebirth succeeds when eligible", okRebirth, rebirthMsg)
	check(
		"rebirth resets tier/cash and keeps brainrots",
		reloaded.Tier == 1 and reloaded.Cash == 0 and reloaded.Rebirths == 1 and reloaded.Brainrots[giveUid] ~= nil
	)
	local okAgain = rebirth(alice2)
	check("rebirth refused when not eligible", not okAgain)

	-- Inventory remote validation ---------------------------------------------------------------------------------------
	local inventory = NetMock.Function("Inventory").OnServerInvoke
	local okSell = inventory(alice2, "Sell", "does-not-exist")
	check("selling a missing brainrot is refused", okSell == false)
	task.wait(0.2)
	local okBest = inventory(alice2, "PlaceBest")
	check("place best works", okBest)

	-- Boosts --------------------------------------------------------------------------------------------------------------
	local useBoost = NetMock.Function("UseBoost").OnServerInvoke
	local okBoost = useBoost(alice2, "Overcharge")
	check("using a boost you don't own is refused", okBoost == false)
	reloaded.Boosts.Overcharge = 1
	task.wait(0.35)
	okBoost = useBoost(alice2, "Overcharge")
	check(
		"using an owned boost works and consumes it",
		okBoost and reloaded.Boosts.Overcharge == 0 and DataService.GetSession(alice2).Overcharge
	)
end)
if not scenarioOk then
	failures += 1
	print("FAIL scenario crashed :: " .. tostring(scenarioErr))
end
print(string.format("simulation finished: %d failure(s)", failures))
process.exit(if failures > 0 then 1 else 0)
