--[[
	Plaster: slow and sturdy, big knockback, controls space.
		1 Tidal Slam   leap and crash down; the client reports the landing
		2 Hook Line    hook an enemy and yank them in, or zip yourself to a surface
		3 Drench Wave  cone of paint that soaks the ground and shoves enemies back
		4 Roller Rush  charge that flattens and launches the first enemy hit
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.Parent.CombatService)
local Hitbox = require(script.Parent.Parent.Hitbox)
local PaintService = require(script.Parent.Parent.PaintService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local World = require(script.Parent.Parent.World)
local Common = require(script.Parent.Common)

local SKILLS = Characters.DEFS.Plaster.skills
local SLAM = SKILLS[1].params
local HOOK = SKILLS[2].params
local WAVE = SKILLS[3].params
local RUSH = SKILLS[4].params

-- How long the server waits for the client to report a slam landing.
local SLAM_WINDOW = 2.2
-- How far a reported landing may be from where the server thinks you are.
local SLAM_MAX_DRIFT = 30

local Plaster = {}
Plaster.events = {}

-- 1: Tidal Slam --------------------------------------------------------------
Plaster[1] = function(ctx: Common.Context)
	ctx.state.pendingSlamUntil = os.clock() + SLAM_WINDOW
	Remotes.Fx:FireAllClients("SlamStart", ctx.character, ctx.colorId)
end

function Plaster.events.land(ctx: Common.Context, data: any)
	local st = ctx.state
	if os.clock() > st.pendingSlamUntil then
		return
	end
	st.pendingSlamUntil = 0

	local reported = Common.vector(data)
	local position = if reported and (reported - ctx.root.Position).Magnitude <= SLAM_MAX_DRIFT
		then reported
		else ctx.root.Position
	local ground = World.groundBelow(position, 8)
	local impact = if ground then ground.Position else position - Vector3.new(0, 3, 0)

	PaintService.splat(ctx.colorId, impact, if ground then ground.Normal else nil, SLAM.radius)
	Remotes.Fx:FireAllClients("Slam", impact, SLAM.radius, ctx.colorId)
	for _, target in Hitbox.sphere(ctx.player, impact + Vector3.new(0, 2, 0), SLAM.radius) do
		local offset = target.root.Position - impact
		local falloff = 1 - 0.4 * math.clamp(offset.Magnitude / SLAM.radius, 0, 1)
		CombatService.applyHit(ctx.player, target.key, {
			damage = SLAM.damage * falloff,
			knockback = Geometry.flat(offset) * SLAM.knockback * falloff + Vector3.new(0, SLAM.launchUp, 0),
			ragdoll = 0.9,
			guardBreak = true,
			heavy = true,
			position = target.root.Position,
		})
	end
end

-- 2: Hook Line ---------------------------------------------------------------
Plaster[2] = function(ctx: Common.Context, payload: { [string]: any })
	local player = ctx.player
	local origin = Common.origin(ctx, payload.origin)
	local direction = Common.direction(ctx, payload.direction)
	ProjectileService.launch({
		owner = player,
		origin = origin,
		velocity = direction * HOOK.speed,
		gravity = 0,
		lifetime = HOOK.lifetime,
		hitRadius = 0.9,
		style = "Hook",
		size = 0.6,
		colorId = ctx.colorId,
		onHitCharacter = function(target)
			local _, _, root = World.alive(player)
			if not root then
				return
			end
			-- Yank the victim to just in front of Plaster.
			local toOwner = root.Position - target.root.Position
			local distance = toOwner.Magnitude
			local pull = Geometry.flat(toOwner) * math.clamp(distance * 2.6, 40, 135)
			CombatService.applyHit(player, target.key, {
				damage = HOOK.damage,
				knockback = pull + Vector3.new(0, 16 + distance * 0.3, 0),
				stun = HOOK.stun,
				noScaling = true,
				position = target.root.Position,
			})
		end,
		onHitSurface = function(result)
			PaintService.splat(ctx.colorId, result.Position, result.Normal, 3.5, result.Instance :: BasePart)
			-- Zip: pull Plaster toward the anchor point.
			local _, _, root = World.alive(player)
			local toAnchor = if root then result.Position - root.Position else Vector3.zero
			if toAnchor.Magnitude > 2 then
				local speed = math.clamp(toAnchor.Magnitude * 2.4, 50, 130)
				Remotes.Knockback:FireClient(player, toAnchor.Unit * speed + Vector3.new(0, 22, 0), 0, 0)
			end
		end,
	})
end

-- 3: Drench Wave -------------------------------------------------------------
local WAVE_ROWS = { 5, 10, 15, 20 }
local WAVE_ANGLES = { -24, -8, 8, 24 }

Plaster[3] = function(ctx: Common.Context, payload: { [string]: any })
	local direction = Common.flatDirection(ctx, payload.dir)
	local origin = ctx.root.Position
	Remotes.Fx:FireAllClients("Wave", origin, direction, WAVE.range, ctx.colorId)

	for _, target in Hitbox.cone(ctx.player, origin, direction, WAVE.range, WAVE.halfAngle) do
		CombatService.applyHit(ctx.player, target.key, {
			damage = WAVE.damage,
			knockback = direction * WAVE.knockback + Vector3.new(0, WAVE.up, 0),
			ragdoll = 0.7,
			heavy = true,
			position = target.root.Position,
		})
	end
	for _, distance in WAVE_ROWS do
		for _, angle in WAVE_ANGLES do
			local rowDirection = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(direction)
			PaintService.splatGround(ctx.colorId, origin + rowDirection * distance, 3.8, 9)
		end
	end
end

-- 4: Roller Rush -------------------------------------------------------------
Plaster[4] = function(ctx: Common.Context, payload: { [string]: any })
	local direction = Common.flatDirection(ctx, payload.dir)
	Remotes.Fx:FireAllClients("Streak", ctx.character, direction, ctx.colorId)
	Common.lane(ctx, RUSH.time, RUSH.radius, 4.6, function(target)
		CombatService.applyHit(ctx.player, target.key, {
			damage = RUSH.damage,
			knockback = direction * RUSH.knockback + Vector3.new(0, RUSH.up, 0),
			ragdoll = 1,
			heavy = true,
			position = target.root.Position,
		})
		Remotes.Fx:FireAllClients("Slam", target.root.Position - Vector3.new(0, 2.5, 0), 6, ctx.colorId)
		-- Only the first enemy gets flattened.
		return true
	end)
end

return Plaster
