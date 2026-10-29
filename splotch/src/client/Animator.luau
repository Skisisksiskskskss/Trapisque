--[[
	Animator: procedural R6 animation for every character on this client
	(players and dummies), driven by Motor6D C0 offsets, so no uploaded
	animation assets are needed.

	Each frame, per character:
		1. locomotion (idle / walk / run / jump / fall) from its velocity
		2. stances blended on top (block, stunned)
		3. the current action clip (swings, dashes, skills) over the joints it uses
	then the six R6 joints are written (maths in shared/R6Pose). Your own
	actions are played instantly by the controllers; everyone else's arrive as
	"Anim" Fx events.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Animations = require(Shared.Animations)
local Characters = require(Shared.Characters)
local R6Pose = require(Shared.R6Pose)

local Animator = {}

type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	motors: { [string]: Motor6D },
	base: { [string]: CFrame },
	clip: Animations.Clip?,
	clipStart: number,
	clipSpeed: number,
	phase: number,
	loco: R6Pose.FullPose,
	blockWeight: number,
	stunWeight: number,
	stunUntil: number,
}

local MOTORS = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RArm = { "Torso", "Right Shoulder" },
	LArm = { "Torso", "Left Shoulder" },
	RLeg = { "Torso", "Right Hip" },
	LLeg = { "Torso", "Left Hip" },
}
local FADE_IN = 0.04
local FADE_OUT = 0.1
local RUN_THRESHOLD = 21

local rigs: { [Model]: Rig } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function locomotion(rig: Rig, dt: number, now: number): Animations.Pose
	local velocity = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local ground = workspace:Raycast(rig.root.Position, Vector3.new(0, -3.9, 0), groundParams)
	if not ground then
		return if velocity.Y > 4 then Animations.jump() else Animations.fall(now)
	end
	if speed < 0.8 then
		return Animations.idle(now)
	end
	if speed < RUN_THRESHOLD then
		rig.phase += dt * speed * 0.62
		return Animations.walk(rig.phase)
	end
	rig.phase += dt * speed * 0.45
	return Animations.run(rig.phase)
end

local function update(rig: Rig, dt: number, now: number)
	local character = rig.character
	if character:GetAttribute("Ragdolled") or rig.humanoid.Health <= 0 then
		rig.clip = nil
		return
	end

	-- 1. Locomotion, smoothed so state changes never snap.
	local target = R6Pose.empty()
	R6Pose.blend(target, locomotion(rig, dt, now), 1)
	local weapon = Characters.get(character:GetAttribute("Kit")).weapon
	R6Pose.add(target, Animations.HOLD[weapon] or {})
	R6Pose.blend(rig.loco, target, math.min(dt * 12, 1))
	local pose = R6Pose.empty()
	R6Pose.blend(pose, rig.loco, 1)

	-- 2. Stances.
	local blocking = character:GetAttribute("Blocking") == true
	rig.blockWeight += ((if blocking then 1 else 0) - rig.blockWeight) * math.min(dt * 16, 1)
	if rig.blockWeight > 0.01 then
		R6Pose.blend(pose, Animations.BLOCK, rig.blockWeight)
	end
	local stunned = now < rig.stunUntil
	rig.stunWeight += ((if stunned then 1 else 0) - rig.stunWeight) * math.min(dt * 14, 1)
	if rig.stunWeight > 0.01 then
		R6Pose.blend(pose, Animations.STUNNED, rig.stunWeight)
	end

	-- 3. Action clip over the joints it uses.
	local clip = rig.clip
	if clip then
		local t = (now - rig.clipStart) * rig.clipSpeed
		local weight = math.min(t / FADE_IN, 1)
		if t > clip.duration then
			weight = 1 - (t - clip.duration) / FADE_OUT
		end
		if weight <= 0 then
			rig.clip = nil
		else
			R6Pose.blend(pose, R6Pose.sample(clip, math.min(t, clip.duration)), weight, clip.joints)
		end
	end

	R6Pose.plantLegs(pose)
	local c0s = R6Pose.c0s(rig.base, pose)
	for joint, motor in rig.motors do
		motor.C0 = c0s[joint]
	end
end

local function track(character: Model)
	if rigs[character] then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then
		return
	end
	local motors, base = {}, {}
	for joint, path in MOTORS do
		local holder = character:WaitForChild(path[1], 5)
		local motor = holder and holder:WaitForChild(path[2], 5)
		if not motor or not motor:IsA("Motor6D") then
			return -- not an R6 rig
		end
		motors[joint] = motor
		base[joint] = motor.C0
	end
	rigs[character] = {
		character = character,
		humanoid = humanoid,
		root = root,
		motors = motors,
		base = base,
		clip = nil,
		clipStart = 0,
		clipSpeed = 1,
		phase = 0,
		loco = R6Pose.empty(),
		blockWeight = 0,
		stunWeight = 0,
		stunUntil = 0,
	}
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			rigs[character] = nil
		end
	end)
end

-- Plays a clip from Animations.CLIPS on a character (ignored if unknown).
function Animator.play(character: Model?, name: string, speed: number?)
	local rig = if character then rigs[character] else nil
	local clip = Animations.CLIPS[name]
	if rig and clip then
		rig.clip = clip
		rig.clipStart = os.clock()
		rig.clipSpeed = speed or 1
	end
end

-- Shows the stunned stance for `seconds` (on top of whatever else is playing).
function Animator.stun(character: Model?, seconds: number)
	local rig = if character then rigs[character] else nil
	if rig then
		rig.stunUntil = math.max(rig.stunUntil, os.clock() + seconds)
	end
end

function Animator.init()
	groundParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(track, character)
		end)
		if player.Character then
			task.spawn(track, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	for _, dummy in CollectionService:GetTagged("Dummy") do
		task.spawn(track, dummy)
	end
	CollectionService:GetInstanceAddedSignal("Dummy"):Connect(function(dummy)
		task.spawn(track, dummy)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for _, rig in rigs do
			update(rig, dt, now)
		end
	end)
end

return Animator
