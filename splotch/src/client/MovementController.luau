--[[
	MovementController: everything that moves your own character.

	States
		Normal    walking / running (double-tap W, or Auto Run)
		Swim      diving (hold the Dive key): fast in your own paint, crawling elsewhere
		WallSwim  diving up a wall painted your color (physics state + constraints)
		Dash      Q dashes and dashing skills: fixed-speed bursts, steerable with the camera
		Slam      Plaster's Tidal Slam: rise, then crash down
		Flight    launched (knockback, hooks, pads): the humanoid's air control is
		          switched off so the launch carries, but you stay upright
		Ragdoll   knocked down: real ragdoll physics until the server says get up

	JJS rules: front dash 25 studs (6s) with a jab, side/back dash 17.5 studs (2s),
	wall jumps 3/2/1 by health, run speed scales with health, dash while ragdolled
	or stunned with a full evasive bar to break out.

	The client owns its character's physics, so all movement happens here; the
	server is told about form changes and validates attacks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local Animator = require(script.Parent.Animator)
local CameraController = require(script.Parent.CameraController)
local PaintRenderer = require(script.Parent.PaintRenderer)
local Settings = require(script.Parent.Settings)
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
local swingUntil = 0
local ragdollUntil = 0
local flightUntil = 0
local flightStartedAt = 0
local stateUntil = 0
local momentumSpeed: number? = nil
local airDashUsed = false
local frontDashReadyAt = 0
local sideDashReadyAt = 0
local dashKind = "Side"
local dashLocal = Vector3.new(0, 0, -1) -- dash direction in camera space
local dashSpeed = 0
local dashStartedAt = 0
local dashJabbed = false
local running = false
local lastForwardTap = 0
local wallJumpsLeft = 3
local lastJumpAction = 0
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

local JUMP_ACTION_DEBOUNCE = 0.22
local JAB_REACH = 2.5
local JAB_BOX = Vector3.new(6, 7, 5)
local RAGDOLL_FALLBACK = 1.5 -- get up on our own if the server's word never arrives
local RAGDOLL_INFLUENCE = 20 -- studs/s^2 of steering while ragdolled

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

local function healthFraction(): number
	if not humanoid then
		return 1
	end
	return math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
end

local function moveVector(): Vector3
	return if controls then controls:GetMoveVector() else Vector3.zero
end

-- Camera-space direction -> world direction on the ground plane.
local function cameraToWorld(localDirection: Vector3): Vector3
	local look = CameraController.flatLook()
	local right = CameraController.flatRight()
	local world = right * localDirection.X + look * -localDirection.Z
	return if world.Magnitude > 1e-3 then world.Unit else look
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

local function facingYaw(): CFrame
	if not root then
		return CFrame.identity
	end
	local look = Geometry.flat(root.CFrame.LookVector)
	return CFrame.lookAt(Vector3.zero, look)
end

local function faceDirection(direction: Vector3)
	if root then
		local flat = Geometry.flat(direction)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
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
		flightStartedAt = now()
		flightUntil = flightStartedAt + flight
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		wallAlign.CFrame = facingYaw()
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

-- State changes ---------------------------------------------------------------

local function enterNormal(keepHumanoidState: boolean?)
	disableConstraints()
	if not keepHumanoidState then
		releasePhysics()
	end
	if humanoid then
		humanoid.AutoRotate = true
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
	humanoid.AutoRotate = false
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

local function updateFlight(t: number)
	if not root or not wallAlign then
		return
	end
	local landed = t - flightStartedAt > 0.15 and raycast(root.Position, Vector3.new(0, -3.4, 0)) ~= nil
	if landed or t >= flightUntil then
		local v = root.AssemblyLinearVelocity
		enterNormal()
		momentumSpeed = math.max(Vector3.new(v.X, 0, v.Z).Magnitude, Config.WALK_SPEED)
	end
end

-- Dashing ------------------------------------------------------------------------

local function startDash(kind: string, localDirection: Vector3, speed: number, duration: number)
	if not dashVelocity or not humanoid then
		return
	end
	if state == "Swim" then
		exitSwim()
	elseif state == "Flight" or state == "WallSwim" then
		enterNormal()
	end
	state = "Dash"
	dashKind = kind
	dashLocal = localDirection
	dashSpeed = speed
	dashStartedAt = now()
	dashJabbed = false
	stateUntil = dashStartedAt + duration
	humanoid.AutoRotate = false
	local world = cameraToWorld(localDirection)
	if kind ~= "Side" then
		faceDirection(world)
	end
	dashVelocity.PlaneVelocity = Vector2.new(world.X, world.Z) * speed
	dashVelocity.Enabled = true
	CameraController.setSpeedBoost(8)
end

-- Looks for an enemy in front during a front dash (the jab).
local function checkJab(t: number)
	if dashKind ~= "Front" or dashJabbed or not root then
		return
	end
	local origin = root.CFrame
	for _, other in workspace:GetChildren() do
		if other:IsA("Model") and other ~= character then
			local otherRoot = other:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = other:FindFirstChildOfClass("Humanoid")
			if
				otherRoot
				and otherRoot:IsA("BasePart")
				and otherHumanoid
				and otherHumanoid.Health > 0
				and not other:GetAttribute("Ragdolled")
				and Geometry.inFrontBox(origin, JAB_REACH, JAB_BOX, otherRoot.Position)
			then
				dashJabbed = true
				local early = t - dashStartedAt < Config.FRONT_DASH_TIME / 2
				Remotes.Action:FireServer("DashHit", other, early)
				Sounds.play("Swing")
				-- The jab ends the dash.
				stateUntil = t
				return
			end
		end
	end
end

local function updateDash(t: number)
	if not dashVelocity or not humanoid then
		return
	end
	-- Steerable: the dash keeps its direction relative to the camera.
	local world = cameraToWorld(dashLocal)
	dashVelocity.PlaneVelocity = Vector2.new(world.X, world.Z) * dashSpeed
	if dashKind ~= "Side" then
		faceDirection(world)
	end
	checkJab(t)
	if t >= stateUntil then
		enterNormal()
		momentumSpeed = Config.WALK_SPEED * 1.3
	end
end

-- Ragdolls ------------------------------------------------------------------------

local function endRagdoll()
	if state ~= "Ragdoll" then
		return
	end
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root then
		root.AssemblyAngularVelocity = Vector3.zero
	end
	enterNormal(true)
end

local function updateRagdoll(t: number, dt: number)
	if not root then
		return
	end
	if t >= ragdollUntil + RAGDOLL_FALLBACK then
		endRagdoll()
		return
	end
	-- JJS ragdoll influence: holding a direction nudges where you land.
	local input = moveVector()
	if input.Magnitude > 0.1 then
		local push = cameraToWorld(input) * RAGDOLL_INFLUENCE * dt
		root.AssemblyLinearVelocity += push
	end
end

-- Other per-frame updates ---------------------------------------------------------

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
			local gust = 0.7 + 0.5 * math.noise(now() * 0.7, 3.1)
			windForce.Force = wind * Config.STORM_WIND_ACCEL * gust * root.AssemblyMass
			return
		end
	end
	windForce.Force = Vector3.zero
end

local function wallJumpsForHealth(): number
	local fraction = healthFraction()
	if fraction > 0.66 then
		return Config.WALL_JUMPS[1]
	elseif fraction > 0.33 then
		return Config.WALL_JUMPS[2]
	end
	return Config.WALL_JUMPS[3]
end

local function updateSpeed(t: number, onGround: boolean)
	if not humanoid then
		return
	end
	local stunned = t < stunUntil
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	if Settings.get("autoRun") then
		running = moving
	elseif not moving then
		running = false
	end

	local speed
	if stunned then
		speed = Config.STUN_WALK_SPEED
	elseif blocking then
		speed = Config.BLOCK_WALK_SPEED
	elseif t < swingUntil then
		speed = Config.SWING_WALK_SPEED
	elseif state == "Swim" then
		if surface == "own" then
			speed = Config.SWIM_SPEED * kit().swimSpeedMultiplier
		elseif onGround then
			speed = Config.FLOP_SPEED
		else
			speed = Config.SWIM_SPEED
		end
	else
		local base = if running then Config.RUN_SPEED else Config.WALK_SPEED
		-- JJS: you slow down as you get hurt.
		base *= Config.LOW_HP_SPEED + (1 - Config.LOW_HP_SPEED) * healthFraction()
		if surface == "enemy" and onGround then
			base = math.min(base, Config.ENEMY_PAINT_SPEED)
		end
		speed = base
	end
	if momentumSpeed and not onGround then
		speed = math.max(speed, momentumSpeed)
	end
	humanoid.WalkSpeed = speed

	-- While diving the jump input means leap, and stunned or blocking players
	-- can't jump, so the default Roblox jump is switched off then.
	local canJump = state == "Normal" and not stunned and not blocking
	if canJump ~= jumpEnabled then
		jumpEnabled = canJump
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, canJump)
	end

	local boost = 0
	if state == "Swim" and speed > Config.WALK_SPEED * 1.5 then
		boost = 7
	elseif running and moving then
		boost = 4
	end
	CameraController.setSpeedBoost(boost)
end

local function update(dt: number)
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
	if onGround and state ~= "Ragdoll" then
		airDashUsed = false
		wallJumpsLeft = wallJumpsForHealth()
	end

	if state == "Ragdoll" then
		updateRagdoll(t, dt)
		return
	elseif state == "WallSwim" then
		updateWallSwim(t)
		return
	elseif state == "Dash" then
		updateDash(t)
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
	updateSpeed(t, onGround)

	-- Diving into a wall painted your color starts a wall swim.
	if state == "Swim" and humanoid.MoveDirection.Magnitude > 0.1 then
		local wall = probeWall(humanoid.MoveDirection)
		if wall and PaintRenderer.ownerAt(wall) == color then
			enterWallSwim(wall.Normal)
		end
	end
end

-- Jumping: leaps out of paint and wall jumps ------------------------------------------

-- Leap out of paint. Returns true if the jump input was used for it.
local function leap(): boolean
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

local function wallJump(): boolean
	if not humanoid or not root or state ~= "Normal" or grounded() or wallJumpsLeft <= 0 then
		return false
	end
	if now() < stunUntil or blocking then
		return false
	end
	local candidates = {
		humanoid.MoveDirection,
		root.CFrame.LookVector,
		CameraController.flatRight(),
		-CameraController.flatRight(),
	}
	local best: RaycastResult? = nil
	for _, direction in candidates do
		if direction.Magnitude > 0.1 then
			local hit = probeWall(direction)
			if hit and (not best or hit.Distance < best.Distance) then
				best = hit
			end
		end
	end
	if not best then
		return false
	end
	wallJumpsLeft -= 1
	local normal = Geometry.flat(best.Normal)
	launch(normal * Config.WALL_JUMP_OUT + Vector3.new(0, Config.WALL_JUMP_UP, 0))
	faceDirection(normal)
	Animator.play(character, "DashBack")
	Sounds.play("Leap")
	return true
end

local function onJumpRequest()
	local t = now()
	if t - lastJumpAction < JUMP_ACTION_DEBOUNCE then
		return
	end
	if leap() or wallJump() then
		lastJumpAction = t
	end
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

function MovementController.isRagdolled(): boolean
	return state == "Ragdoll"
end

function MovementController.isStunned(): boolean
	return now() < stunUntil or state == "Ragdoll"
end

function MovementController.isAirborne(): boolean
	return not grounded()
end

function MovementController.verticalSpeed(): number
	return if root then root.AssemblyLinearVelocity.Y else 0
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

-- Keeps you surfaced for a moment (attacking while holding the Dive key).
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

-- Slows you while an M1 winds up.
function MovementController.swing(seconds: number)
	swingUntil = math.max(swingUntil, now() + seconds)
end

-- Steps toward the target when an M1 lands (JJS pulls the attacker 1 stud).
function MovementController.pull(distance: number)
	if root and state == "Normal" then
		local look = Geometry.flat(root.CFrame.LookVector)
		if not raycast(root.Position, look * (distance + 1)) then
			root.CFrame += look * distance
		end
	end
end

-- Remaining and total cooldowns: front dash, then side dash.
function MovementController.getDashCooldowns(): (number, number, number, number)
	local t = now()
	return math.max(frontDashReadyAt - t, 0),
		Config.FRONT_DASH_COOLDOWN,
		math.max(sideDashReadyAt - t, 0),
		Config.SIDE_DASH_COOLDOWN
end

--[[
	The Dash key. Normally a front dash (holding forward or nothing) or a side
	dash (holding A, D or S). While ragdolled or stunned it asks the server for
	an evasive instead, which needs a full bar.
]]
function MovementController.dash(): boolean
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local t = now()
	if MovementController.isStunned() then
		if (player:GetAttribute("Evasive") or 0) >= 100 then
			Remotes.Action:FireServer("Evasive")
		end
		return false
	end
	if blocking or state == "Dash" or state == "WallSwim" or state == "Slam" then
		return false
	end
	if not grounded() then
		if airDashUsed then
			return false
		end
	end

	local input = moveVector()
	local kind, localDirection, animation
	if input.Magnitude < 0.2 or input.Z < -0.35 then
		kind, localDirection, animation = "Front", Vector3.new(0, 0, -1), "DashFront"
	elseif math.abs(input.X) >= math.abs(input.Z) then
		kind = "Side"
		localDirection = Vector3.new(math.sign(input.X), 0, 0)
		animation = if input.X > 0 then "DashRight" else "DashLeft"
	else
		kind, localDirection, animation = "Side", Vector3.new(0, 0, 1), "DashBack"
	end

	if kind == "Front" then
		if t < frontDashReadyAt then
			return false
		end
		frontDashReadyAt = t + Config.FRONT_DASH_COOLDOWN
		startDash("Front", localDirection, Config.FRONT_DASH_DISTANCE / Config.FRONT_DASH_TIME, Config.FRONT_DASH_TIME)
	else
		if t < sideDashReadyAt then
			return false
		end
		sideDashReadyAt = t + Config.SIDE_DASH_COOLDOWN
		startDash("Side", localDirection, Config.SIDE_DASH_DISTANCE / Config.SIDE_DASH_TIME, Config.SIDE_DASH_TIME)
	end
	if not grounded() then
		airDashUsed = true
	end
	Animator.play(character, animation)
	Remotes.Action:FireServer("Dash", kind, animation)
	Sounds.play("Dash")
	return true
end

-- The server granted an evasive: get up and quick-step away.
function MovementController.evasiveStep()
	if not humanoid or not root then
		return
	end
	stunUntil = 0
	if state == "Ragdoll" then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		root.AssemblyAngularVelocity = Vector3.zero
		enterNormal(true)
	end
	local input = moveVector()
	local localDirection = if input.Magnitude > 0.2 then input.Unit else Vector3.new(0, 0, 1)
	startDash("Side", localDirection, Config.EVASIVE_DISTANCE / Config.SIDE_DASH_TIME, Config.SIDE_DASH_TIME)
	Animator.play(character, "Evasive")
end

-- Dashing skills (Streak, Roller Rush).
function MovementController.skillDash(direction: Vector3, speed: number, duration: number)
	-- Express the world direction in camera space so it stays steerable.
	local look = CameraController.flatLook()
	local right = CameraController.flatRight()
	local localDirection = Vector3.new(direction:Dot(right), 0, -direction:Dot(look))
	startDash("Skill", localDirection, speed, duration)
end

-- Plaster's Tidal Slam. `onLand` gets the landing position.
function MovementController.slam(params: { [string]: number }, onLand: (Vector3) -> ())
	if not root then
		return
	end
	if state == "Swim" then
		exitSwim()
	elseif state == "Flight" or state == "Dash" then
		enterNormal()
	end
	slamParams = params
	slamPhase = "rise"
	onSlamLand = onLand
	launch(CameraController.flatLook() * params.forward + Vector3.new(0, params.up, 0))
	state = "Slam"
	stateUntil = now() + params.rise
end

-- Server-sent knockback. Ragdoll > 0 knocks you down; stun stops you acting.
function MovementController.applyKnockback(velocity: Vector3, ragdoll: number, stun: number)
	if not humanoid or not root then
		return
	end
	local t = now()
	stunUntil = math.max(stunUntil, t + stun)
	if state == "Slam" then
		onSlamLand = nil
	end
	if ragdoll > 0 then
		disableConstraints()
		if form ~= "Normal" then
			setForm("Normal")
		end
		state = "Ragdoll"
		ragdollUntil = t + ragdoll
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		root.AssemblyLinearVelocity = velocity
		local random = Random.new()
		root.AssemblyAngularVelocity =
			Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-3, 3), random:NextNumber(-6, 6))
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

-- The server ended our ragdoll (timer or evasive).
function MovementController.endRagdoll()
	endRagdoll()
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
	swingUntil = 0
	momentumSpeed = nil
	pendingLaunch = nil
	onSlamLand = nil
	jumpEnabled = true
	running = false
	frontDashReadyAt = 0
	sideDashReadyAt = 0
	h.AutoRotate = true
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

	-- Double-tap W to run (JJS).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.W then
			return
		end
		local t = now()
		if t - lastForwardTap <= Config.RUN_DOUBLE_TAP then
			running = true
		end
		lastForwardTap = t
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.W and not Settings.get("autoRun") then
			running = false
		end
	end)
	UserInputService.JumpRequest:Connect(onJumpRequest)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(update)
end

return MovementController
