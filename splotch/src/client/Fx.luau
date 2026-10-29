--[[
	Fx: everything cosmetic that the server announces, plus your own instant
	feedback.

	* Hits: a white flash on the target, a hit reaction animation, a burst in
	  the attacker's color, optional damage numbers, sounds and, for big ones,
	  an impact frame.
	* Swings: a ribbon trail along the weapon and a whoosh.
	* Projectiles are drawn on the same arc the server simulates.
	* Skills, evasives, awakenings and guard breaks get their own shapes.
	Every visual is built from plain parts, particles, trails and beams, so no
	uploaded assets are needed.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(Shared.Geometry)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local Animator = require(script.Parent.Animator)
local CameraController = require(script.Parent.CameraController)
local CharacterVisuals = require(script.Parent.CharacterVisuals)
local Hud = require(script.Parent.Hud)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)

local Fx = {}

local localPlayer = Players.LocalPlayer

local PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PROJECTILE_GRACE = 0.4 -- keep drawing this long past lifetime awaiting the server
local SWING_TRAIL_TIME = 0.22

type Projectile = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	born: number,
	style: string,
	stopped: boolean,
	last: Vector3,
}

local folder: Folder
local projectiles: { [string]: Projectile } = {}
local traps: { [number]: BasePart } = {}
local emitters: { [string]: ParticleEmitter } = {}
local swingTrails: { [Model]: Trail } = {}
local impactEffect: ColorCorrectionEffect
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

-- Small building blocks ----------------------------------------------------------

local function fxPart(shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, goals):Play()
end

local function colorFor(colorId: number): Color3
	return if colorId > 0 then Palette.color(colorId) else Color3.fromRGB(255, 255, 255)
end

local function emitter(kind: string, colorId: number): ParticleEmitter
	local key = kind .. colorId
	local existing = emitters[key]
	if existing then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Fx" .. key
	attachment.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.Color = ColorSequence.new(colorFor(colorId))
	e.LightEmission = 0.05
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	if kind == "spark" then
		e.Texture = SPARK_TEXTURE
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.15, 0.3)
		e.Drag = 6
	elseif kind == "gust" then
		e.Texture = PARTICLE_TEXTURE
		e.LightEmission = 0.3
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.3, 0.5)
		e.Drag = 4
	else
		e.Texture = PARTICLE_TEXTURE
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Acceleration = Vector3.new(0, -70, 0)
		e.Drag = 2
	end
	e.Parent = attachment
	emitters[key] = e
	return e
end

local function emit(kind: string, position: Vector3, colorId: number, count: number, speed: number)
	local e = emitter(kind, colorId)
	local attachment = e.Parent :: Attachment
	attachment.WorldPosition = position
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e:Emit(count)
end

-- A burst of paint droplets (and optional sparks) at a point.
local function burst(position: Vector3, colorId: number, count: number, speed: number, sparks: boolean?)
	emit("drop", position, colorId, count, speed)
	if sparks then
		emit("spark", position, colorId, math.ceil(count / 2), speed * 1.4)
	end
end

-- A flat disc that expands and fades (shockwaves, splats).
local function ring(position: Vector3, normal: Vector3, radius: number, colorId: number, seconds: number)
	local disc = fxPart(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), colorFor(colorId), Enum.Material.Neon)
	disc.Transparency = 0.2
	-- A cylinder's axis is its X axis; point it along the surface normal.
	local axis = if normal.Magnitude > 0.1 then normal.Unit else Vector3.yAxis
	local reference = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	disc.CFrame = CFrame.fromMatrix(position + axis * 0.15, axis, axis:Cross(reference).Unit)
	tween(disc, seconds, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(disc, seconds + 0.05)
end

-- A translucent sphere that swells and fades (explosions, awakenings).
local function swell(position: Vector3, radius: number, colorId: number, seconds: number)
	local ball = fxPart(Enum.PartType.Ball, Vector3.one * 2, colorFor(colorId), Enum.Material.ForceField)
	ball.CFrame = CFrame.new(position)
	tween(ball, seconds, { Size = Vector3.one * radius * 2, Transparency = 1 })
	Debris:AddItem(ball, seconds + 0.05)
end

local function shakeByDistance(position: Vector3, strength: number, range: number)
	local camera = workspace.CurrentCamera
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < range then
		CameraController.shake(strength * (1 - distance / range))
	end
end

local function rootOf(character: Instance?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A colored ribbon that follows a character for a moment (dashes, Streak).
local function streakTrail(character: Model?, colorId: number, seconds: number, width: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, width / 2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -width / 2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(colorFor(colorId))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.25
	trail.LightEmission = 0.3
	trail.FaceCamera = true
	trail.Parent = root
	task.delay(seconds, function()
		trail.Enabled = false
		Debris:AddItem(trail, 0.3)
		Debris:AddItem(top, 0.3)
		Debris:AddItem(bottom, 0.3)
	end)
end

-- The weapon's swing ribbon: from the hand to the paint end, on the right arm.
local function weaponTrail(character: Model, colorId: number): Trail?
	local existing = swingTrails[character]
	if existing and existing.Parent then
		return existing
	end
	local arm = character:FindFirstChild("Right Arm")
	if not arm or not arm:IsA("BasePart") then
		return nil
	end
	local hand = Instance.new("Attachment")
	hand.Name = "SwingHand"
	hand.Position = Vector3.new(0, -1, -0.8)
	hand.Parent = arm
	local tip = Instance.new("Attachment")
	tip.Name = "SwingTip"
	tip.Position = Vector3.new(0, -1, -3.1)
	tip.Parent = arm
	local trail = Instance.new("Trail")
	trail.Attachment0 = hand
	trail.Attachment1 = tip
	trail.Color = ColorSequence.new(colorFor(colorId), Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.16
	trail.LightEmission = 0.5
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = arm
	swingTrails[character] = trail
	character.Destroying:Connect(function()
		swingTrails[character] = nil
	end)
	return trail
end

-- Projectiles ------------------------------------------------------------------------

local function projectileVisual(style: string, size: number, colorId: number): BasePart
	local color = colorFor(colorId)
	local part
	if style == "Can" then
		part = fxPart(Enum.PartType.Cylinder, Vector3.new(size, size * 0.6, size * 0.6), color)
	elseif style == "Stencil" then
		part = fxPart(Enum.PartType.Cylinder, Vector3.new(0.25, size * 1.6, size * 1.6), color, Enum.Material.Neon)
	else
		part = fxPart(Enum.PartType.Ball, Vector3.one * size, color)
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.35, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.35, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.14
	trail.FaceCamera = true
	trail.Parent = part
	return part
end

local function spawnProjectile(
	key: string,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	style: string,
	size: number,
	colorId: number,
	owner: Player?
)
	local part = projectileVisual(style, size, colorId)
	part.CFrame = CFrame.new(origin)
	if style == "Hook" then
		-- A paint line from the thrower to the hook head.
		local ownerRoot = rootOf(owner and owner.Character)
		if ownerRoot then
			local from = Instance.new("Attachment")
			from.Name = "HookFrom"
			from.Parent = ownerRoot
			local to = Instance.new("Attachment")
			to.Parent = part
			local beam = Instance.new("Beam")
			beam.Attachment0 = from
			beam.Attachment1 = to
			beam.Color = ColorSequence.new(colorFor(colorId))
			beam.Width0 = 0.35
			beam.Width1 = 0.35
			beam.FaceCamera = true
			beam.LightEmission = 0.4
			beam.Parent = part
			part.Destroying:Connect(function()
				from:Destroy()
			end)
		end
	end
	projectiles[key] = {
		part = part,
		origin = origin,
		velocity = velocity,
		gravity = gravity,
		lifetime = lifetime,
		born = os.clock(),
		style = style,
		stopped = false,
		last = origin,
	}
end

local function removeProjectile(key: string)
	local p = projectiles[key]
	if p then
		projectiles[key] = nil
		p.part:Destroy()
	end
end

local function updateProjectiles()
	local now = os.clock()
	for key, p in projectiles do
		local age = now - p.born
		if age > p.lifetime + PROJECTILE_GRACE then
			removeProjectile(key)
		elseif not p.stopped then
			local position = Geometry.ballisticPosition(p.origin, p.velocity, p.gravity, math.min(age, p.lifetime))
			local hit = workspace:Raycast(p.last, position - p.last, mapParams)
			if hit then
				-- Stop at the wall and wait for the server's impact.
				p.stopped = true
				p.part.CFrame = CFrame.new(hit.Position)
				p.part.Transparency = 1
			else
				local spin = if p.style == "Can" or p.style == "Stencil"
					then CFrame.Angles(age * 14, age * 9, 0)
					else CFrame.identity
				p.part.CFrame = CFrame.new(position) * spin
				p.last = position
			end
		end
	end
end

-- Server events -------------------------------------------------------------------

local handlers: { [string]: (...any) -> () } = {}

-- Someone else's animation (yours already played the moment you pressed).
function handlers.Anim(character: Model, name: string, userId: number)
	if userId ~= localPlayer.UserId then
		Animator.play(character, name)
	end
end

function handlers.Swing(character: Model, _weapon: string, step: number, colorId: number)
	if character == localPlayer.Character then
		return
	end
	Fx.swingTrail(character, colorId, step == 4)
	local root = rootOf(character)
	if root then
		Sounds.playAt(if step == 4 then "SwingHeavy" else "Swing", root.Position, 0.8)
	end
end

function handlers.Projectile(
	id: number,
	ownerId: number,
	_shotId: number,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	style: string,
	size: number,
	colorId: number
)
	spawnProjectile(
		"s" .. id,
		origin,
		velocity,
		gravity,
		lifetime,
		style,
		size,
		colorId,
		Players:GetPlayerByUserId(ownerId)
	)
	Sounds.playAt(if style == "Paint" then "Shoot" else "Skill", origin, 0.8)
end

function handlers.ProjectileEnd(
	id: number,
	_ownerId: number,
	_shotId: number,
	position: Vector3,
	normal: Vector3,
	style: string,
	colorId: number,
	hitCharacter: boolean
)
	removeProjectile("s" .. id)
	if style == "Paint" then
		burst(position, colorId, if hitCharacter then 10 else 6, 22)
		if not hitCharacter then
			ring(position, normal, 2.2, colorId, 0.18)
			Sounds.playAt("Splat", position, 0.8)
		end
	elseif style == "Hook" then
		burst(position, colorId, 6, 18)
		Sounds.playAt("Hook", position)
	end
end

function handlers.Streak(character: Model, _direction: Vector3, colorId: number)
	streakTrail(character, colorId, 0.45, 3)
	local root = rootOf(character)
	if root then
		Sounds.playAt("Dash", root.Position)
	end
end

function handlers.Dash(character: Model, colorId: number)
	if character == localPlayer.Character then
		return -- drawn locally the moment you pressed Q
	end
	streakTrail(character, colorId, 0.22, 2.4)
	local root = rootOf(character)
	if root then
		Sounds.playAt("Dash", root.Position, 0.7)
	end
end

function handlers.Evasive(character: Model, _colorId: number)
	local root = rootOf(character)
	if not root then
		return
	end
	ring(root.Position - Vector3.new(0, 2.8, 0), Vector3.yAxis, 9, 0, 0.35)
	emit("gust", root.Position, 0, 14, 30)
	if character ~= localPlayer.Character then
		Sounds.playAt("Evasive", root.Position)
	end
end

function handlers.Awaken(character: Model, colorId: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local position = root.Position
	for index = 1, 3 do
		task.delay((index - 1) * 0.12, function()
			ring(position - Vector3.new(0, 2.8, 0), Vector3.yAxis, 10 + index * 6, colorId, 0.5)
		end)
	end
	swell(position, 14, colorId, 0.6)
	burst(position, colorId, 40, 70, true)
	Sounds.playAt("Awaken", position)
	shakeByDistance(position, 0.8, 90)
	if character == localPlayer.Character then
		Fx.impactFrame()
	end
end

function handlers.GuardBreak(character: Model, position: Vector3)
	for _ = 1, 8 do
		local shard =
			fxPart(Enum.PartType.Block, Vector3.new(0.3, 0.6, 0.1), Color3.fromRGB(190, 220, 255), Enum.Material.Glass)
		shard.Transparency = 0.2
		shard.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		local offset = Vector3.new(math.random(-40, 40), math.random(5, 40), math.random(-40, 40)) / 10
		tween(shard, 0.4, { CFrame = shard.CFrame + offset, Transparency = 1 })
		Debris:AddItem(shard, 0.45)
	end
	if character ~= localPlayer.Character then
		Sounds.playAt("GuardBreak", position)
	end
end

function handlers.TrapPlaced(id: number, position: Vector3, colorId: number)
	local pad = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 9, 9), colorFor(colorId), Enum.Material.Neon)
	pad.Transparency = 0.45
	pad.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	traps[id] = pad
	ring(position, Vector3.yAxis, 5, colorId, 0.3)
	Sounds.playAt("Trap", position, 0.6)
end

function handlers.TrapGone(id: number)
	local pad = traps[id]
	if pad then
		traps[id] = nil
		tween(pad, 0.25, { Transparency = 1 })
		Debris:AddItem(pad, 0.3)
	end
end

function handlers.TrapSnap(position: Vector3, colorId: number)
	ring(position, Vector3.yAxis, 7, colorId, 0.3)
	burst(position, colorId, 16, 30, true)
	Sounds.playAt("Trap", position)
end

function handlers.Burst(position: Vector3, radius: number, colorId: number)
	swell(position, radius, colorId, 0.35)
	ring(position, Vector3.yAxis, radius * 1.2, colorId, 0.45)
	burst(position, colorId, 40, 60, true)
	Sounds.playAt("Burst", position)
	shakeByDistance(position, 0.6, 70)
end

function handlers.SlamStart(character: Model, _colorId: number)
	local root = rootOf(character)
	if root then
		Sounds.playAt("Leap", root.Position)
	end
end

function handlers.Slam(position: Vector3, radius: number, colorId: number)
	ring(position, Vector3.yAxis, radius, colorId, 0.4)
	ring(position, Vector3.yAxis, radius * 0.6, colorId, 0.25)
	burst(position, colorId, 36, 55, true)
	Sounds.playAt("Slam", position)
	shakeByDistance(position, 0.7, 80)
end

function handlers.Wave(origin: Vector3, direction: Vector3, range: number, colorId: number)
	Sounds.playAt("Skill", origin)
	local color = colorFor(colorId)
	for index = -3, 3 do
		local angle = math.rad(index * 10)
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
		local blob = fxPart(Enum.PartType.Ball, Vector3.one * 2.4, color)
		blob.CFrame = CFrame.new(origin + dir * 2)
		tween(blob, 0.3, { CFrame = CFrame.new(origin + dir * range - Vector3.new(0, 2, 0)), Size = Vector3.one * 0.6 })
		Debris:AddItem(blob, 0.32)
	end
	burst(origin + direction * range * 0.5, colorId, 20, 30)
end

-- Hits -----------------------------------------------------------------------------

local function damageNumber(position: Vector3, damage: number, heavy: boolean, blocked: boolean)
	local anchor = fxPart(Enum.PartType.Block, Vector3.one * 0.1, Color3.new(), nil)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random(-10, 10) / 10, 1.5, math.random(-10, 10) / 10))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(100, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = if blocked then "BLOCK" else tostring(damage)
	label.TextColor3 = if blocked
		then Color3.fromRGB(150, 200, 255)
		elseif heavy then Color3.fromRGB(255, 90, 70)
		else Color3.fromRGB(255, 255, 255)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(15, 15, 20)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = if heavy then 1.8 else 1.4
	scale.Parent = label

	tween(scale, 0.12, { Scale = if heavy then 1.2 else 0.95 }, Enum.EasingStyle.Back)
	tween(gui, 0.7, { StudsOffset = Vector3.new(0, 2.2, 0) })
	task.delay(0.3, function()
		tween(label, 0.35, { TextTransparency = 1 })
		tween(stroke, 0.35, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 0.75)
end

local function onHit(
	victim: Model?,
	position: Vector3,
	damage: number,
	attackerColorId: number,
	heavy: boolean,
	blocked: boolean
)
	CharacterVisuals.flash(victim, heavy)
	if victim and not blocked then
		Animator.play(victim, "HitReact")
		if victim ~= localPlayer.Character then
			Animator.stun(victim, 0.35)
		end
	end
	if (damage > 0 or blocked) and Settings.get("damageNumbers") then
		damageNumber(position, damage, heavy, blocked)
	end
	if blocked then
		emit("spark", position, 0, 10, 30)
	else
		burst(
			position,
			if attackerColorId > 0 then attackerColorId else 1,
			if heavy then 18 else 9,
			if heavy then 40 else 26,
			heavy
		)
	end

	if victim and victim == localPlayer.Character then
		Sounds.play(if blocked then "Blocked" else "Hurt")
		Hud.hurt(damage, heavy)
		CameraController.shake(if heavy then 0.55 else 0.22)
	else
		local sound = if blocked then "Blocked" elseif heavy then "HeavyHit" else "Hit"
		Sounds.playAt(sound, position)
	end
end

-- Local feedback --------------------------------------------------------------------

-- Your own dash trail, drawn instantly.
function Fx.localDash(colorId: number)
	streakTrail(localPlayer.Character, colorId, 0.22, 2.4)
end

-- Shows the weapon's swing ribbon for one swing.
function Fx.swingTrail(character: Model?, colorId: number, heavy: boolean)
	if not character then
		return
	end
	local trail = weaponTrail(character, colorId)
	if not trail then
		return
	end
	trail.Enabled = true
	trail.Lifetime = if heavy then 0.24 else 0.16
	task.delay(SWING_TRAIL_TIME + (if heavy then 0.12 else 0), function()
		trail.Enabled = false
	end)
end

-- A one-frame "impact frame" (contrast spike), skipped if Flashing Lights is off.
function Fx.impactFrame()
	if not Settings.get("flashingLights") or not impactEffect then
		return
	end
	impactEffect.Enabled = true
	task.delay(0.07, function()
		impactEffect.Enabled = false
	end)
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	mapParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

	impactEffect = Instance.new("ColorCorrectionEffect")
	impactEffect.Name = "ImpactFrame"
	impactEffect.Saturation = -1
	impactEffect.Contrast = 1.2
	impactEffect.Brightness = 0.05
	impactEffect.Enabled = false
	impactEffect.Parent = Lighting

	Remotes.Fx.OnClientEvent:Connect(function(kind: string, ...)
		local handler = handlers[kind]
		if handler then
			handler(...)
		end
	end)
	Remotes.Hit.OnClientEvent:Connect(onHit)
	RunService.RenderStepped:Connect(updateProjectiles)

	-- The sweeper's angle comes from the shared clock (see HazardService), so
	-- spin it here every frame instead of waiting for replicated movement.
	task.spawn(function()
		local bar = workspace:WaitForChild("Map"):WaitForChild("SweeperBar", 15)
		if bar and bar:IsA("BasePart") then
			local pivot = bar.Position
			local speed = bar:GetAttribute("Speed") or 1
			RunService.RenderStepped:Connect(function()
				local angle = (workspace:GetServerTimeNow() * speed) % (math.pi * 2)
				bar.CFrame = CFrame.new(pivot) * CFrame.Angles(0, angle, 0)
			end)
		end
	end)
end

return Fx
