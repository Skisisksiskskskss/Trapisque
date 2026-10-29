--[[
	PlayerService: joining, colors, leaderstats, R6 spawning and respawning, and
	the 10 Hz loop that applies regen, paint effects, void and hazard deaths.

	Characters are always R6: CharacterAutoLoads is off and every spawn builds
	an R6 rig from the player's own avatar description. There is no default
	Animate script; client/Animator animates every character procedurally.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Zones = require(Shared.Zones)

local CombatService = require(script.Parent.CombatService)
local PaintService = require(script.Parent.PaintService)
local Ragdoll = require(script.Parent.Ragdoll)
local State = require(script.Parent.State)
local Weapons = require(script.Parent.Weapons)
local World = require(script.Parent.World)

local PlayerService = {}

local TICK = 0.1
local SPAWN_TAG = "SpawnPad"

local descriptions: { [Player]: HumanoidDescription } = {}
local spawning: { [Player]: boolean } = {}

local function pickColor(): number
	local used = {}
	for key, st in State.all() do
		if World.isPlayer(key) then
			used[st.colorId] = true
		end
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
	for _, name in { "Kills", "Streak" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

local function descriptionFor(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if not cached then
		if player.UserId > 0 then
			local ok, result = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(player.UserId)
			end)
			if ok and result then
				cached = result
			end
		end
		-- Studio test players (negative ids) and failed lookups get a default look.
		cached = cached or Instance.new("HumanoidDescription")
		descriptions[player] = cached
	end
	return cached:Clone()
end

-- Builds an R6 rig from a description, falling back to a default look.
function PlayerService.buildR6(description: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R6
			)
		end)
	end
	if not ok or not model then
		warn("Splotch: could not build an R6 character:", model)
		return nil
	end
	-- Our own animator drives every character.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	return model
end

local function spawnCFrame(): CFrame
	local pads = CollectionService:GetTagged(SPAWN_TAG)
	local pad = pads[math.random(1, math.max(#pads, 1))]
	if pad and pad:IsA("BasePart") then
		-- Face the middle of the map.
		local position = pad.Position + Vector3.new(0, 3.3, 0)
		local look = Vector3.new(-position.X, 0, -position.Z)
		return CFrame.lookAt(position, position + (if look.Magnitude > 1 then look.Unit else Vector3.zAxis))
	end
	return CFrame.new(0, 10, 0)
end

-- Shared character setup for players and dummies.
function PlayerService.prepareCharacter(model: Model, colorId: number, kitName: string)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local kit = Characters.get(kitName)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = kit.maxHealth
	humanoid.Health = kit.maxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JUMP_POWER
	humanoid.WalkSpeed = Config.WALK_SPEED
	model:SetAttribute("Form", "Normal")
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Ragdolled", false)
	model:SetAttribute("Awakened", false)
	model:SetAttribute("Kit", kit.name)
	model:SetAttribute("ColorId", colorId)

	local color = Palette.color(colorId)
	local outline = Instance.new("Highlight")
	outline.Name = "PaintOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = color
	outline.OutlineTransparency = 0.35
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model

	Ragdoll.setup(model)
	Weapons.attach(model, kit.weapon, color)
end

local function spawnPlayer(player: Player)
	local st = State.get(player)
	if not st or spawning[player] or player.Parent ~= Players then
		return
	end
	spawning[player] = true
	local model = PlayerService.buildR6(descriptionFor(player))
	spawning[player] = nil
	if not model or player.Parent ~= Players then
		return
	end
	model.Name = player.Name

	State.resetForSpawn(st)
	st.spawnProtectedUntil = os.clock() + Config.SPAWN_PROTECTION
	PlayerService.prepareCharacter(model, st.colorId, st.kit)
	CombatService.syncMeters(st)
	player:SetAttribute("AwakenEnds", 0)

	local old = player.Character
	model:PivotTo(spawnCFrame())
	player.Character = model
	model.Parent = workspace
	if old and old ~= model then
		old:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		CombatService.onDied(player)
		task.delay(Config.RESPAWN_TIME, function()
			if player.Character == model then
				spawnPlayer(player)
			end
		end)
	end)
end

-- Respawns a player right now (used when they switch characters).
function PlayerService.respawn(player: Player)
	task.spawn(spawnPlayer, player)
end

local function onPlayerAdded(player: Player)
	local colorId = pickColor()
	local st = State.create(player, colorId)
	player:SetAttribute("ColorId", colorId)
	player:SetAttribute("Kit", st.kit)
	makeLeaderstats(player)
	spawnPlayer(player)
end

local function onPlayerRemoving(player: Player)
	local st = State.get(player)
	if st then
		PaintService.clearColor(st.colorId)
	end
	State.remove(player)
	descriptions[player] = nil
end

local function tick(key: World.Combatant, st: State.PlayerState, dt: number, now: number)
	local _, humanoid, root = World.alive(key)
	if not humanoid or not root then
		return
	end

	if root.Position.Y < Config.VOID_Y then
		CombatService.kill(key, "void")
		return
	end
	if Zones.contains(Zones.HAZARD, root.Position, 2.5) then
		CombatService.kill(key, "rinse")
		return
	end

	if not World.isPlayer(key) then
		-- Training dummies heal back to full when left alone.
		if now - st.lastDamagedAt > 3 then
			humanoid.Health = humanoid.MaxHealth
		end
		return
	end

	local down = World.raycastMap(root.Position, Vector3.new(0, -Config.DOWN_PROBE, 0))
	local owner = PaintService.ownerAt(down)
	if st.form == "WallSwim" then
		owner = PaintService.ownerAt(World.raycastMap(root.Position, root.CFrame.LookVector * 3)) or owner
	end
	st.surface = if owner == nil then "none" elseif owner == st.colorId then "own" else "enemy"

	if now - st.lastDamagedAt > Config.REGEN_DELAY then
		CombatService.heal(key, Config.REGEN * dt)
	end
	if st.surface == "own" and st.form ~= "Normal" then
		CombatService.heal(key, Config.SWIM_HEAL * dt)
	elseif st.surface == "enemy" and not CombatService.isProtected(key) then
		CombatService.drain(key, Config.ENEMY_PAINT_DAMAGE * dt, Config.ENEMY_PAINT_FLOOR)
	end

	if st.awakenedUntil > 0 and now >= st.awakenedUntil then
		st.awakenedUntil = 0
		(key :: Player):SetAttribute("AwakenEnds", 0)
	end
end

function PlayerService.init()
	Players.CharacterAutoLoads = false
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
		for key, st in State.all() do
			tick(key, st, elapsed, now)
		end
		elapsed = 0
	end)
end

return PlayerService
