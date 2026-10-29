--[[
	MovementController: everything that moves your own character.

	States
		Normal    walking; you face the camera like shift lock
		Swim      diving (hold SHIFT): fast in your own paint, crawling elsewhere
		WallSwim  diving up a wall painted your color (physics state + constraints)
		Dash      Q dash or a dashing skill: short, fixed-speed burst
		Slam      Plaster's Tidal Slam: rise, then crash down
		Flight    launched (knockback, hooks, pads): the humanoid's air control is
		          switched off so the launch carries, but you stay upright
		Tumble    knocked back hard: ragdoll-style physics until you get up

	The client owns its character's physics, so all movement happens here; the
	server is told about form changes (for effects and paint healing) and does
	hit detection from the replicated positions.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local CameraController = require(script.Parent.CameraController)
local PaintRenderer = require(script.Parent.PaintRenderer)
local Sounds = require(script.Parent.Sounds)

local MovementController = {}

local player = Players.LocalPlayer
local controls: any = nil

local state = "Normal"
local form = "Normal"
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local wallVelocity: LinearVelocity? = nil
local dashVelocity: LinearVelocity? = nil
local wallAlign: AlignOrientation? = nil
local windForce: VectorForce? = nil

local diveHeld = false
local diveSuppressedUntil = 0
local rediveAt = 0
local blocking = false
local stunUntil = 0
local tumbleUntil = 0
local flightUntil = 0
local flightStartedAt = 0
local stateUntil = 0
local momentumSpeed: number? = nil
local airDashUsed = false
local dashReadyAt = 0
local wallNormal = Vector3.new(0, 0, 1)
local lastGoodWallAt = 0
local bounceReadyAt = 0
local surface = "none"
local pendingLaunch: Vector3? = nil
local slamPhase = "rise"
local slamParams: { [string]: number } = {}
local onSlamLand: ((Vector3) -> ())? = nil
local jumpEnabled = true

local formListeners: { (string) -> () } = {}

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

-- Helpers -------------------------------------------------------------------

local function now(): number
	return os.clock()
end

local function kit(): Characters.Character
	return Characters.get(player:GetAttribute("Kit"))
end

local function myColor(): number?
	return player:GetAttribute("ColorId")
end

local function raycast(origin: Vector3, direction: Vector3): RaycastResult?
	return workspace:Raycast(origin, direction, mapParams)
end

local function setForm(newForm: string)
	if form == newForm then
		return
	end
	form = newForm
	Remotes.Action:FireServer("Form", newForm)
	for _, listener in formListeners do
		task.spawn(listener, newForm)
	end
end

local function grounded(): boolean
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function disableConstraints()
	if wallVelocity then
		wallVelocity.Enabled = false
	end
	if dashVelocity then
		dashVelocity.Enabled = false
	end
	if wallAlign then
		wallAlign.Enabled = false
	end
end

-- Takes the humanoid out of the Physics state (wall swim, flight) if it is in it.
local function releasePhysics()
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Physics then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function upright(): CFrame
	return CFrame.Angles(0, CameraController.getYaw(), 0)
end

--[[
	Throws the character with `velocity`. Without `flight` the humanoid keeps
	air control (leaps: you steer). With `flight` seconds, air control is off
	for that long so knockback and pulls actually carry.
]]
local function launch(velocity: Vector3, flight: number?)
	if not humanoid or not root then
		return
	end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	momentumSpeed = math.max(horizontal, Config.WALK_SPEED)
	if flight and flight > 0 and wallAlign then
		if dashVelocity then
			dashVelocity.Enabled = false
		end
		state = "Flight"
		flightStartedAt = os.clock()
		flightUntil = flightStartedAt + flight
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		wallAlign.CFrame = upright()
		wallAlign.Enabled = true
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.zero
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = velocity
	-- Re-applied next frame in case the humanoid's ground spring ate it.
	pendingLaunch = velocity
end

local function faceCamera()
	if root then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, CameraController.getYaw(), 0)
	end
end

local function cameraRelative(moveVector: Vector3): Vector3
	local look = CameraController.flatLook()
	local right = Vector3.new(-look.Z, 0, look.X)
	return right * moveVector.X + look * -moveVector.Z
end

local function moveVector(): Vector3
	return if controls then controls:GetMoveVector() else Vector3.zero
end

-- State changes ---------------------------------------------------------------

local function enterNormal(keepHumanoidState: boolean?)
	disableConstraints()
	if not keepHumanoidState then
		releasePhysics()
	end
	state = "Normal"
	setForm("Normal")
end

local function enterSwim()
	state = "Swim"
	setForm("Swim")
	Sounds.play("Dive")
end

local function exitSwim()
	enterNormal()
	Sounds.play("Surface")
end

local function enterWallSwim(normal: Vector3)
	if not humanoid or not wallVelocity or not wallAlign then
		return
	end
	state = "WallSwim"
	wallNormal = normal
	lastGoodWallAt = now()
	setForm("WallSwim")
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	wallVelocity.VectorVelocity = Vector3.zero
	wallVelocity.Enabled = true
	wallAlign.CFrame = CFrame.lookAt(Vector3.zero, -Geometry.flat(normal))
	wallAlign.Enabled = true
end

local function leaveWall(velocity: Vector3)
	enterNormal()
	rediveAt = now() + Config.REDIVE_LOCK
	launch(velocity)
end

local function endTumble()
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root then
		root.AssemblyAngularVelocity = Vector3.zero
	end
	enterNormal(true)
end

local function updateFlight(t: number)
	if not root or not wallAlign then
		return
	end
	wallAlign.CFrame = upright()
	local landed = t - flightStartedAt > 0.15 and raycast(root.Position, Vector3.new(0, -3.4, 0)) ~= nil
	if landed or t >= flightUntil then
		local v = root.AssemblyLinearVelocity
		enterNormal()
		momentumSpeed = math.max(Vector3.new(v.X, 0, v.Z).Magnitude, Config.WALK_SPEED)
	end
end

-- Per-frame updates -------------------------------------------------------------

local function probeWall(direction: Vector3): RaycastResult?
	if not root then
		return nil
	end
	local flatDir = Geometry.flat(direction)
	for _, height in { 0, -1.6 } do
		local hit = raycast(root.Position + Vector3.new(0, height, 0), flatDir * Config.WALL_PROBE_DISTANCE)
		if hit and math.abs(hit.Normal.Y) < 0.4 then
			return hit
		end
	end
	return nil
end

local function updateWallSwim(t: number)
	if not root or not wallVelocity or not wallAlign then
		return
	end
	if not diveHeld or t < stunUntil then
		leaveWall(wallNormal * 8)
		return
	end
	local move = moveVector()
	local inputUp = -move.Z
	local hit = raycast(root.Position, -wallNormal * 3.2)
	if not hit or math.abs(hit.Normal.Y) > 0.6 then
		-- Ran out of wall. Climbing up means we reached the top: pop over it.
		if inputUp > 0.1 then
			leaveWall(Vector3.new(0, Config.CREST_POP_UP, 0) - wallNormal * Config.CREST_POP_FORWARD)
		else
			leaveWall(wallNormal * 6)
		end
		return
	end
	wallNormal = hit.Normal
	-- Paint at chest or knee height both count, so a slightly low splat still works.
	local low = raycast(root.Position - Vector3.new(0, 1.5, 0), -wallNormal * 3.2)
	local color = myColor()
	local mine = PaintRenderer.ownerAt(hit) == color or PaintRenderer.ownerAt(low) == color
	if mine then
		lastGoodWallAt = t
	elseif t - lastGoodWallAt > Config.WALL_GRACE then
		leaveWall(wallNormal * 4)
		return
	end

	local up = Vector3.yAxis - wallNormal * wallNormal.Y
	up = if up.Magnitude > 0.05 then up.Unit else Vector3.yAxis
	local right = up:Cross(wallNormal)
	local distance = (hit.Position - root.Position).Magnitude
	local stick = math.clamp((distance - Config.WALL_HOLD_DISTANCE) * 10, -8, 8)
	local speed = Config.WALL_SWIM_SPEED * kit().swimSpeedMultiplier
	wallVelocity.VectorVelocity = up * inputUp * speed + right * move.X * speed - wallNormal * stick
	wallAlign.CFrame = CFrame.lookAt(Vector3.zero, -Geometry.flat(wallNormal))
	CameraController.setSpeedBoost(if math.abs(inputUp) + math.abs(move.X) > 0.1 then 5 else 0)
end

local function updateSlam(t: number)
	if not root then
		return
	end
	if slamPhase == "rise" then
		if t >= stateUntil then
			slamPhase = "drop"
			stateUntil = t + 1.6
		end
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X * 0.9, -slamParams.dropSpeed, v.Z * 0.9)
	local nearGround = raycast(root.Position, Vector3.new(0, -Config.DOWN_PROBE, 0)) ~= nil
	if nearGround or grounded() then
		local callback = onSlamLand
		onSlamLand = nil
		enterNormal()
		CameraController.shake(0.55)
		if callback then
			callback(root.Position)
		end
	elseif t >= stateUntil then
		onSlamLand = nil
		enterNormal()
	end
end

local function updateWind()
	if not root or not windForce then
		return
	end
	local stormy = workspace:GetAttribute("Phase") == "Storm"
	if stormy and not Zones.contains(Zones.SHELTER, root.Position) then
		local wind = workspace:GetAttribute("Wind")
		if typeof(wind) == "Vector3" then
			-- Gusty: the strength wobbles over time.
			local gust = 0.7 + 0.5 * math.noise(os.clock() * 0.7, 3.1)
			windForce.Force = wind * Config.STORM_WIND_ACCEL * gust * root.AssemblyMass
			return
		end
	end
	windForce.Force = Vector3.zero
end

local function update()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local t = now()

	if pendingLaunch then
		local wanted = pendingLaunch
		pendingLaunch = nil
		if root.AssemblyLinearVelocity.Y < wanted.Y * 0.8 then
			root.AssemblyLinearVelocity = wanted
		end
	end

	updateWind()

	local down = raycast(root.Position, Vector3.new(0, -Config.DOWN_PROBE, 0))
	local downOwner = PaintRenderer.ownerAt(down)
	local color = myColor()
	surface = if downOwner == nil then "none" elseif downOwner == color then "own" else "enemy"
	local onGround = grounded()
	if onGround then
		airDashUsed = false
	end

	if state == "Tumble" then
		if t >= tumbleUntil then
			endTumble()
		end
		return
	elseif state == "WallSwim" then
		updateWallSwim(t)
		return
	elseif state == "Dash" then
		faceCamera()
		if t >= stateUntil then
			enterNormal()
			momentumSpeed = Config.WALK_SPEED * 1.4
		end
		return
	elseif state == "Slam" then
		updateSlam(t)
		return
	elseif state == "Flight" then
		updateFlight(t)
		return
	end

	-- Bounce pads.
	if
		down
		and t >= bounceReadyAt
		and down.Instance:HasTag("BouncePad")
		and (root.Position - down.Position).Magnitude < 3.8
	then
		bounceReadyAt = t + 0.4
		local pad = down.Instance :: BasePart
		local power = pad:GetAttribute("Power") or 90
		local forward = pad:GetAttribute("Forward") or 0
		if state == "Swim" then
			enterNormal()
		end
		launch(Vector3.new(0, power, 0) + pad.CFrame.LookVector * forward, if forward > 0 then 0.6 else nil)
		Sounds.play("Bounce")
		return
	end

	local stunned = t < stunUntil
	local canDive = not stunned and not blocking and t >= diveSuppressedUntil and t >= rediveAt
	if state == "Normal" and diveHeld and canDive then
		enterSwim()
	elseif state == "Swim" and (not diveHeld or not canDive) then
		exitSwim()
	end

	if onGround and t > rediveAt then
		momentumSpeed = nil
	end

	local speed
	if stunned then
		speed = Config.STUN_WALK_SPEED
	elseif blocking then
		speed = Config.BLOCK_WALK_SPEED
	elseif state == "Swim" then
		if surface == "own" then
			speed = Config.SWIM_SPEED * kit().swimSpeedMultiplier
		elseif onGround then
			speed = Config.FLOP_SPEED
		else
			speed = Config.SWIM_SPEED
		end
	elseif surface == "enemy" and onGround then
		speed = Config.ENEMY_PAINT_SPEED
	else
		speed = Config.WALK_SPEED
	end
	if momentumSpeed and not onGround then
		speed = math.max(speed, momentumSpeed)
	end
	humanoid.WalkSpeed = speed
	-- While diving SPACE means leap (see leap()), and stunned or blocking
	-- players can't jump, so the default Roblox jump is switched off then.
	local canJump = state == "Normal" and not stunned and not blocking
	if canJump ~= jumpEnabled then
		jumpEnabled = canJump
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, canJump)
	end
	CameraController.setSpeedBoost(if state == "Swim" and speed > Config.WALK_SPEED * 1.5 then 7 else 0)

	-- Diving into a wall painted your color starts a wall swim.
	if state == "Swim" and humanoid.MoveDirection.Magnitude > 0.1 then
		local wall = probeWall(humanoid.MoveDirection)
		if wall and PaintRenderer.ownerAt(wall) == color then
			enterWallSwim(wall.Normal)
			return
		end
	end

	faceCamera()
end

-- Public API ----------------------------------------------------------------------

function MovementController.onFormChanged(listener: (string) -> ())
	table.insert(formListeners, listener)
end

function MovementController.getForm(): string
	return form
end

function MovementController.getState(): string
	return state
end

function MovementController.getSurface(): string
	return surface
end

function MovementController.isStunned(): boolean
	return now() < stunUntil or state == "Tumble"
end

-- True when the character can start an attack or skill right now.
function MovementController.canAct(): boolean
	return humanoid ~= nil
		and humanoid.Health > 0
		and not MovementController.isStunned()
		and state ~= "WallSwim"
		and state ~= "Slam"
end

function MovementController.setDiveHeld(held: boolean)
	diveHeld = held
end

-- Keeps you surfaced for a moment (firing while holding SHIFT).
function MovementController.suppressDive(seconds: number)
	diveSuppressedUntil = math.max(diveSuppressedUntil, now() + seconds)
	if state == "Swim" then
		exitSwim()
	end
end

function MovementController.setBlocking(isBlocking: boolean)
	blocking = isBlocking
	if isBlocking and state == "Swim" then
		exitSwim()
	end
end

function MovementController.getDashCooldown(): (number, number)
	return math.max(dashReadyAt - now(), 0), Config.DASH_COOLDOWN
end

-- Leap out of paint. Returns true if SPACE was used for it.
function MovementController.leap(): boolean
	if not humanoid or not root then
		return false
	end
	if state == "WallSwim" then
		leaveWall(wallNormal * Config.WALL_LEAP_OUT + Vector3.new(0, Config.WALL_LEAP_UP, 0))
		Sounds.play("Leap")
		return true
	end
	if state ~= "Swim" then
		return false
	end
	exitSwim()
	rediveAt = now() + Config.REDIVE_LOCK
	if surface ~= "own" then
		-- No paint under you: just a normal hop.
		jumpEnabled = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		return true
	end
	local v = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(v.X, 0, v.Z)
	local direction = humanoid.MoveDirection
	if direction.Magnitude > 0.1 then
		horizontal = direction.Unit * math.max(horizontal.Magnitude, Config.LEAP_FORWARD)
	end
	launch(horizontal + Vector3.new(0, Config.LEAP_UP, 0))
	Sounds.play("Leap")
	return true
end

local function startDash(direction: Vector3, speed: number, duration: number)
	if not dashVelocity then
		return
	end
	if state == "Swim" then
		exitSwim()
	elseif state == "Flight" then
		enterNormal()
	end
	state = "Dash"
	stateUntil = now() + duration
	dashVelocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
	dashVelocity.Enabled = true
	CameraController.setSpeedBoost(10)
end

-- Q dash in the direction you are holding (forward if none). Returns success.
function MovementController.dash(): boolean
	local t = now()
	if not MovementController.canAct() or blocking or t < dashReadyAt or state == "Dash" then
		return false
	end
	if not grounded() then
		if airDashUsed then
			return false
		end
		airDashUsed = true
	end
	local direction = cameraRelative(moveVector())
	if direction.Magnitude < 0.1 then
		direction = CameraController.flatLook()
	end
	dashReadyAt = t + Config.DASH_COOLDOWN
	startDash(direction.Unit, Config.DASH_SPEED, Config.DASH_TIME)
	Remotes.Action:FireServer("Dash")
	Sounds.play("Dash")
	return true
end

-- Dashing skills (Tagger's Streak).
function MovementController.skillDash(direction: Vector3, speed: number, duration: number)
	startDash(direction, speed, duration)
end

-- Plaster's Tidal Slam. `onLand` gets the landing position.
function MovementController.slam(params: { [string]: number }, onLand: (Vector3) -> ())
	if not root then
		return
	end
	if state == "Swim" then
		exitSwim()
	elseif state == "Flight" then
		enterNormal()
	end
	slamParams = params
	slamPhase = "rise"
	onSlamLand = onLand
	launch(CameraController.flatLook() * params.forward + Vector3.new(0, params.up, 0))
	state = "Slam"
	stateUntil = now() + params.rise
end

-- Server-sent knockback. Ragdoll > 0 tumbles you; stun stops you acting.
function MovementController.applyKnockback(velocity: Vector3, ragdoll: number, stun: number)
	if not humanoid or not root then
		return
	end
	local t = now()
	stunUntil = math.max(stunUntil, t + stun + ragdoll)
	if state == "Slam" then
		onSlamLand = nil
	end
	if ragdoll > 0 then
		disableConstraints()
		if form ~= "Normal" then
			setForm("Normal")
		end
		state = "Tumble"
		tumbleUntil = t + ragdoll
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		root.AssemblyLinearVelocity = velocity
		local random = Random.new()
		root.AssemblyAngularVelocity =
			Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-5, 5), random:NextNumber(-8, 8))
		return
	end
	if velocity.Magnitude < 1 then
		return
	end
	if velocity.Magnitude < 25 and velocity.Y < 10 then
		-- A nudge: no launch and no interruption, just a shove.
		root.AssemblyLinearVelocity += velocity
		return
	end
	-- A real launch always surfaces you and cancels dashes, slams and wall swims.
	if state ~= "Normal" then
		enterNormal()
	end
	local flight = math.clamp(0.25 + velocity.Magnitude / 400, 0.25, 0.6)
	launch(Vector3.new(velocity.X, math.max(velocity.Y, Config.MIN_LAUNCH_UP), velocity.Z), flight)
end

-- Setup -----------------------------------------------------------------------------

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local h = humanoid :: Humanoid
	local r = root :: BasePart

	state = "Normal"
	form = "Normal"
	stunUntil = 0
	momentumSpeed = nil
	pendingLaunch = nil
	onSlamLand = nil
	jumpEnabled = true
	h.AutoRotate = false
	h.WalkSpeed = Config.WALK_SPEED
	h.UseJumpPower = true
	h.JumpPower = Config.JUMP_POWER

	local attachment = Instance.new("Attachment")
	attachment.Name = "MoveAttachment"
	attachment.Parent = r

	local lv = Instance.new("LinearVelocity")
	lv.Name = "WallVelocity"
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.Enabled = false
	lv.Parent = r
	wallVelocity = lv

	local dv = Instance.new("LinearVelocity")
	dv.Name = "DashVelocity"
	dv.Attachment0 = attachment
	dv.RelativeTo = Enum.ActuatorRelativeTo.World
	dv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	dv.PrimaryTangentAxis = Vector3.xAxis
	dv.SecondaryTangentAxis = Vector3.zAxis
	dv.MaxForce = math.huge
	dv.Enabled = false
	dv.Parent = r
	dashVelocity = dv

	local align = Instance.new("AlignOrientation")
	align.Name = "WallAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.Enabled = false
	align.Parent = r
	wallAlign = align

	local wind = Instance.new("VectorForce")
	wind.Name = "WindForce"
	wind.Attachment0 = attachment
	wind.RelativeTo = Enum.ActuatorRelativeTo.World
	wind.ApplyAtCenterOfMass = true
	wind.Force = Vector3.zero
	wind.Parent = r
	windForce = wind

	h.Died:Connect(function()
		if character == newCharacter then
			disableConstraints()
			state = "Normal"
			form = "Normal"
		end
	end)
end

function MovementController.init()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) :: any
	controls = playerModule:GetControls()

	local map = workspace:WaitForChild("Map")
	mapParams.FilterDescendantsInstances = { map }

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(update)
end

return MovementController
