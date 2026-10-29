--[[
	Fx: everything cosmetic that the server announces, plus local predictions.

	* Projectiles are drawn on the same arc the server simulates. Your own
	  primary shots are drawn the instant you fire (predicted) and matched to
	  the server's impact by shotId.
	* Hits get damage numbers, a white flash, a colored burst and a sound.
	* Skills get their own shapes: shockwave rings, bursts, traps, tethers.
	Every visual is built from plain parts, particles, trails and beams, so no
	uploaded assets are needed.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(Shared.Geometry)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local CameraController = require(script.Parent.CameraController)
local CharacterVisuals = require(script.Parent.CharacterVisuals)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)

local Fx = {}

local localPlayer = Players.LocalPlayer

local PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PROJECTILE_GRACE = 0.4 -- keep drawing this long past lifetime awaiting the server

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
	e.Color = ColorSequence.new(Palette.color(colorId))
	e.LightEmission = 0.05
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	if kind == "spark" then
		e.Texture = SPARK_TEXTURE
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.15, 0.3)
		e.Drag = 6
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

-- A burst of paint droplets (and optional sparks) at a point.
local function burst(position: Vector3, colorId: number, count: number, speed: number, sparks: boolean?)
	local droplets = emitter("drop", colorId)
	local attachment = droplets.Parent :: Attachment
	attachment.WorldPosition = position
	droplets.Speed = NumberRange.new(speed * 0.4, speed)
	droplets:Emit(count)
	if sparks then
		local spark = emitter("spark", colorId)
		local sparkAttachment = spark.Parent :: Attachment
		sparkAttachment.WorldPosition = position
		spark.Speed = NumberRange.new(speed * 0.6, speed * 1.4)
		spark:Emit(math.ceil(count / 2))
	end
end

-- A flat disc that expands and fades (shockwaves, splats).
local function ring(position: Vector3, normal: Vector3, radius: number, colorId: number, seconds: number)
	local disc = fxPart(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), Palette.color(colorId), Enum.Material.Neon)
	disc.Transparency = 0.2
	-- A cylinder's axis is its X axis; point it along the surface normal.
	local axis = if normal.Magnitude > 0.1 then normal.Unit else Vector3.yAxis
	local reference = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	disc.CFrame = CFrame.fromMatrix(position + axis * 0.15, axis, axis:Cross(reference).Unit)
	tween(disc, seconds, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(disc, seconds + 0.05)
end

-- A translucent sphere that swells and fades (explosions).
local function swell(position: Vector3, radius: number, colorId: number, seconds: number)
	local ball = fxPart(Enum.PartType.Ball, Vector3.one * 2, Palette.color(colorId), Enum.Material.ForceField)
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
	trail.Color = ColorSequence.new(Palette.color(colorId))
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

-- Projectiles ------------------------------------------------------------------------

local function projectileVisual(style: string, size: number, colorId: number): BasePart
	local color = Palette.color(colorId)
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
			beam.Color = ColorSequence.new(Palette.color(colorId))
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

function handlers.Projectile(
	id: number,
	ownerId: number,
	shotId: number,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	style: string,
	size: number,
	colorId: number
)
	if ownerId == localPlayer.UserId and shotId ~= 0 then
		return -- already drawn by prediction
	end
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
	if style ~= "Paint" then
		Sounds.playAt("Skill", origin, 0.8)
	end
end

function handlers.ProjectileEnd(
	id: number,
	ownerId: number,
	shotId: number,
	position: Vector3,
	normal: Vector3,
	style: string,
	colorId: number,
	hitCharacter: boolean
)
	if ownerId == localPlayer.UserId and shotId ~= 0 then
		removeProjectile("l" .. shotId)
	else
		removeProjectile("s" .. id)
	end
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
	streakTrail(character, colorId, 0.4, 3)
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

function handlers.TrapPlaced(id: number, position: Vector3, colorId: number)
	local pad = fxPart(Enum.PartType.Cylinder, Vector3.new(0.3, 9, 9), Palette.color(colorId), Enum.Material.Neon)
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
	local color = Palette.color(colorId)
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

-- Damage numbers -------------------------------------------------------------------

local function damageNumber(position: Vector3, damage: number, heavy: boolean, blocked: boolean)
	local anchor = fxPart(Enum.PartType.Block, Vector3.one * 0.1, Color3.new(), nil)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random(-10, 10) / 10, 1.5, math.random(-10, 10) / 10))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 46)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = if blocked then "BLOCKED " .. damage else tostring(damage)
	label.TextColor3 = if blocked
		then Color3.fromRGB(150, 200, 255)
		elseif damage >= 18 then Color3.fromRGB(255, 70, 60)
		elseif damage >= 10 then Color3.fromRGB(255, 170, 40)
		else Color3.fromRGB(255, 255, 255)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 24)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = if heavy then 1.9 else 1.5
	scale.Parent = label

	tween(scale, 0.12, { Scale = if heavy then 1.25 else 1 }, Enum.EasingStyle.Back)
	tween(gui, 0.75, { StudsOffset = Vector3.new(0, 2.6, 0) })
	task.delay(0.35, function()
		tween(label, 0.4, { TextTransparency = 1 })
		tween(stroke, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 0.8)
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
	if damage > 0 then
		damageNumber(position, damage, heavy, blocked)
	end
	burst(
		position,
		if attackerColorId > 0 then attackerColorId else 1,
		if heavy then 18 else 8,
		if heavy then 40 else 24,
		heavy
	)

	if victim and victim == localPlayer.Character then
		Sounds.play(if blocked then "Blocked" else "Hurt")
		Hud.hurt(damage, heavy)
		CameraController.shake(if heavy then 0.55 else 0.22)
	else
		local sound = if blocked then "Blocked" elseif heavy then "HeavyHit" else "Hit"
		Sounds.playAt(sound, position)
	end
end

-- Local predictions -----------------------------------------------------------------

-- Draws your own primary shot the moment you fire.
function Fx.predictShot(
	shotId: number,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	size: number,
	colorId: number
)
	spawnProjectile("l" .. shotId, origin, velocity, gravity, lifetime, "Paint", size, colorId, localPlayer)
end

-- Your own dash trail, drawn instantly.
function Fx.localDash(colorId: number)
	streakTrail(localPlayer.Character, colorId, 0.22, 2.4)
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	mapParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

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
