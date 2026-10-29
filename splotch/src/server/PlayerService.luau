--[[
	PlayerService: joining, colors, leaderstats, spawning, and the 10 Hz loop
	that applies paint effects (healing, refills, enemy paint), void and hazard
	deaths.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Zones = require(Shared.Zones)

local CombatService = require(script.Parent.CombatService)
local PaintService = require(script.Parent.PaintService)
local State = require(script.Parent.State)
local World = require(script.Parent.World)

local PlayerService = {}

local TICK = 0.1

local function pickColor(): number
	local used = {}
	for _, st in State.all() do
		used[st.colorId] = true
	end
	for colorId = 1, #Palette do
		if not used[colorId] then
			return colorId
		end
	end
	return math.random(1, #Palette)
end

local function makeLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Splashes", "Streak" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function prop(parent: Instance, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = parent
	return part
end

-- A small back-mounted prop so each character reads at a glance.
local function addKitProp(character: Model, kitName: string, color: Color3)
	-- Weld to the root: unlike torso parts it is never swapped out when the
	-- avatar's appearance loads, and it exists on both R6 and R15 rigs.
	local anchor = character:WaitForChild("HumanoidRootPart", 5)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "KitProp"
	local sideways = CFrame.Angles(0, 0, math.rad(90))
	if kitName == "Plaster" then
		local bucket =
			prop(model, Enum.PartType.Cylinder, Vector3.new(2.2, 2, 2), Color3.fromRGB(70, 74, 86), Enum.Material.Metal)
		weld(bucket, anchor, CFrame.new(0, 0.6, 1.4) * sideways)
		local fill = prop(model, Enum.PartType.Cylinder, Vector3.new(0.3, 1.8, 1.8), color, Enum.Material.SmoothPlastic)
		weld(fill, anchor, CFrame.new(0, 1.65, 1.4) * sideways)
	else
		local can = prop(model, Enum.PartType.Cylinder, Vector3.new(2.1, 1, 1), color, Enum.Material.SmoothPlastic)
		weld(can, anchor, CFrame.new(0.35, 0.7, 0.9) * sideways)
		local cap = prop(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.45, 0.7, 0.7),
			Color3.fromRGB(240, 240, 240),
			Enum.Material.SmoothPlastic
		)
		weld(cap, anchor, CFrame.new(0.35, 1.95, 0.9) * sideways)
	end
	model.Parent = character
end

local function onCharacterAdded(player: Player, character: Model)
	local st = State.get(player)
	if not st then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local kit = Characters.get(st.kit)
	local now = os.clock()

	st.paint = Config.TANK_MAX
	st.form = "Normal"
	st.blocking = false
	st.stunUntil = 0
	st.nextPrimaryAt = 0
	st.skillReadyAt = { 0, 0, 0 }
	st.dashReadyAt = 0
	st.pendingSlamUntil = 0
	st.lastDamagedAt = -math.huge
	st.spawnProtectedUntil = now + Config.SPAWN_PROTECTION

	humanoid.MaxHealth = kit.maxHealth
	humanoid.Health = kit.maxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	character:SetAttribute("Form", "Normal")
	character:SetAttribute("Blocking", false)
	character:SetAttribute("Kit", kit.name)
	character:SetAttribute("ColorId", st.colorId)
	player:SetAttribute("Paint", Config.TANK_MAX)

	local color = Palette.color(st.colorId)
	local outline = Instance.new("Highlight")
	outline.Name = "PaintOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = color
	outline.OutlineTransparency = 0.15
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character

	task.spawn(addKitProp, character, kit.name, color)

	humanoid.Died:Connect(function()
		CombatService.onDied(player)
	end)
end

local function onPlayerAdded(player: Player)
	local colorId = pickColor()
	local st = State.create(player, colorId)
	player:SetAttribute("ColorId", colorId)
	player:SetAttribute("Kit", st.kit)
	player:SetAttribute("Paint", Config.TANK_MAX)
	makeLeaderstats(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local st = State.get(player)
	if st then
		PaintService.clearColor(st.colorId)
	end
	State.remove(player)
end

local function heal(humanoid: Humanoid, amount: number)
	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
end

local function tickPlayer(player: Player, st: State.PlayerState, dt: number, now: number)
	local _, humanoid, root = World.alive(player)
	if not humanoid or not root then
		return
	end

	if root.Position.Y < Config.VOID_Y then
		CombatService.kill(player, "void")
		return
	end
	if Zones.contains(Zones.HAZARD, root.Position, 2.5) then
		CombatService.kill(player, "rinse")
		return
	end

	local down = World.raycastMap(root.Position, Vector3.new(0, -Config.DOWN_PROBE, 0))
	local owner = PaintService.ownerAt(down)
	if st.form == "WallSwim" then
		owner = PaintService.ownerAt(World.raycastMap(root.Position, root.CFrame.LookVector * 3)) or owner
	end
	st.surface = if owner == nil then "none" elseif owner == st.colorId then "own" else "enemy"

	local diving = st.form ~= "Normal"
	if st.surface == "own" and diving then
		st.paint += Config.TANK_REGEN_SWIM * dt
		heal(humanoid, Config.SWIM_HEAL * dt)
	else
		st.paint += Config.TANK_REGEN * dt
	end
	st.paint = math.min(st.paint, Config.TANK_MAX)

	if st.surface == "enemy" and not CombatService.isProtected(player) then
		CombatService.drain(player, Config.ENEMY_PAINT_DAMAGE * dt, Config.ENEMY_PAINT_FLOOR)
	elseif now - st.lastDamagedAt > Config.OUT_OF_COMBAT_DELAY then
		heal(humanoid, Config.OUT_OF_COMBAT_REGEN * dt)
	end

	local shownPaint = math.floor(st.paint)
	if player:GetAttribute("Paint") ~= shownPaint then
		player:SetAttribute("Paint", shownPaint)
	end
end

function PlayerService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		local now = os.clock()
		for player, st in State.all() do
			tickPlayer(player, st, elapsed, now)
		end
		elapsed = 0
	end)
end

return PlayerService
