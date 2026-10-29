--[[
	Tagger: fast, low damage, all about laying paint and setting people up.
		1 Streak        dash that paints a lane and knocks people aside
		2 Stencil Trap  sticky trap that roots, then pops the victim into the air
		3 Burst Can     lobbed can that bursts into a big splat (rocket-jumpable)
]]

local RunService = game:GetService("RunService")

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

local SKILLS = Characters.DEFS.Tagger.skills
local STREAK = SKILLS[1].params
local TRAP = SKILLS[2].params
local CAN = SKILLS[3].params

-- The server sees the dasher's position slightly late, so keep checking a bit
-- past the dash itself.
local STREAK_LAG_GRACE = 0.2

type Trap = { id: number, owner: Player, colorId: number, position: Vector3, expiresAt: number }

local Tagger = {}

local traps: { Trap } = {}
local nextTrapId = 0

local function removeTrap(index: number)
	local trap = table.remove(traps, index)
	if trap then
		Remotes.Fx:FireAllClients("TrapGone", trap.id)
	end
end

local function springTrap(trap: Trap, victim: Player)
	Remotes.Fx:FireAllClients("TrapSnap", trap.position, trap.colorId)
	local landed = CombatService.applyHit(trap.owner, victim, {
		damage = TRAP.damage,
		stun = TRAP.stickTime + 0.15,
		position = trap.position,
	})
	if not landed then
		return
	end
	task.delay(TRAP.stickTime, function()
		local _, _, root = World.alive(victim)
		if root then
			CombatService.applyHit(trap.owner, victim, {
				damage = TRAP.popDamage,
				knockback = Vector3.new(0, TRAP.popUp, 0),
				ragdoll = 0.7,
				heavy = true,
				position = root.Position,
			})
		end
	end)
end

local function placeTrap(ctx: Common.Context, position: Vector3)
	local mine = 0
	for _, trap in traps do
		if trap.owner == ctx.player then
			mine += 1
		end
	end
	if mine >= TRAP.maxTraps then
		for index, trap in traps do
			if trap.owner == ctx.player then
				removeTrap(index)
				break
			end
		end
	end
	nextTrapId += 1
	local trap = {
		id = nextTrapId,
		owner = ctx.player,
		colorId = ctx.colorId,
		position = position,
		expiresAt = os.clock() + TRAP.duration,
	}
	table.insert(traps, trap)
	Remotes.Fx:FireAllClients("TrapPlaced", trap.id, position, ctx.colorId)
end

local function checkTraps()
	local now = os.clock()
	for index = #traps, 1, -1 do
		local trap = traps[index]
		if now >= trap.expiresAt then
			removeTrap(index)
		else
			for _, target in World.livingPlayers(trap.owner) do
				local offset = target.root.Position - trap.position
				local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if flatDistance <= TRAP.triggerRadius and offset.Y > -2 and offset.Y < 6 then
					removeTrap(index)
					springTrap(trap, target.player)
					break
				end
			end
		end
	end
end

local trapClock = 0
RunService.Heartbeat:Connect(function(dt)
	trapClock += dt
	if trapClock >= 0.1 then
		trapClock = 0
		checkTraps()
	end
end)

-- 1: Streak ------------------------------------------------------------------
Tagger[1] = function(ctx: Common.Context, payload: { [string]: any })
	local direction = Common.flatDirection(ctx, payload.dir)
	local player = ctx.player
	local colorId = ctx.colorId
	Remotes.Fx:FireAllClients("Streak", ctx.character, direction, colorId)

	local alreadyHit: { [Player]: boolean } = {}
	local started = os.clock()
	local lastPaint = 0
	task.spawn(function()
		while os.clock() - started < STREAK.time + STREAK_LAG_GRACE do
			local _, _, root = World.alive(player)
			if not root then
				return
			end
			local now = os.clock()
			if now - lastPaint >= 0.05 then
				lastPaint = now
				PaintService.splatGround(colorId, root.Position, 3.4, 6)
			end
			for _, target in Hitbox.sphere(player, root.Position, STREAK.radius) do
				if not alreadyHit[target.player] then
					alreadyHit[target.player] = true
					local offset = target.root.Position - root.Position
					local side = Geometry.flat(offset - direction * offset:Dot(direction), direction:Cross(Vector3.yAxis))
					CombatService.applyHit(player, target.player, {
						damage = STREAK.damage,
						knockback = side * STREAK.knockback + direction * 18 + Vector3.new(0, 28, 0),
						ragdoll = 0.35,
						stun = 0.1,
						position = target.root.Position,
					})
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- 2: Stencil Trap ------------------------------------------------------------
Tagger[2] = function(ctx: Common.Context, payload: { [string]: any })
	local origin = Common.origin(ctx, payload.origin)
	local direction = Common.direction(ctx, payload.direction)
	ProjectileService.launch({
		owner = ctx.player,
		origin = origin,
		velocity = direction * TRAP.speed,
		gravity = TRAP.gravity,
		lifetime = 2.5,
		hitRadius = 0.8,
		style = "Stencil",
		size = 1.4,
		colorId = ctx.colorId,
		onHitCharacter = function(target, position)
			-- A direct hit springs the trap immediately.
			nextTrapId += 1
			springTrap({
				id = nextTrapId,
				owner = ctx.player,
				colorId = ctx.colorId,
				position = position,
				expiresAt = 0,
			}, target.player)
		end,
		onHitSurface = function(result)
			PaintService.splat(ctx.colorId, result.Position, result.Normal, 5, result.Instance :: BasePart)
			placeTrap(ctx, result.Position)
		end,
	})
end

-- 3: Burst Can ---------------------------------------------------------------
local function burst(ctx: Common.Context, position: Vector3, normal: Vector3?)
	local player = ctx.player
	PaintService.splat(ctx.colorId, position, normal, CAN.radius)
	Remotes.Fx:FireAllClients("Burst", position, CAN.radius, ctx.colorId)
	for _, target in Hitbox.sphere(player, position, CAN.radius) do
		local offset = target.root.Position - position
		local falloff = 1 - 0.5 * math.clamp(offset.Magnitude / CAN.radius, 0, 1)
		CombatService.applyHit(player, target.player, {
			damage = CAN.damage * falloff,
			knockback = Geometry.flat(offset) * CAN.knockback * falloff + Vector3.new(0, CAN.up, 0),
			ragdoll = 0.6,
			heavy = true,
			position = target.root.Position,
		})
	end
	-- Rocket jump: the blast throws its owner but never hurts them.
	local _, _, root = World.alive(player)
	if root and (root.Position - position).Magnitude <= CAN.radius * 0.8 then
		local away = Geometry.flat(root.Position - position, Vector3.zero)
		Remotes.Knockback:FireClient(player, away * 30 + Vector3.new(0, CAN.selfLaunch, 0), 0, 0)
	end
end

Tagger[3] = function(ctx: Common.Context, payload: { [string]: any })
	local origin = Common.origin(ctx, payload.origin)
	local direction = Common.direction(ctx, payload.direction)
	ProjectileService.launch({
		owner = ctx.player,
		origin = origin,
		velocity = direction * CAN.speed,
		gravity = CAN.gravity,
		lifetime = 2.5,
		hitRadius = 0.9,
		style = "Can",
		size = 1.3,
		colorId = ctx.colorId,
		onHitCharacter = function(_, position)
			burst(ctx, position, nil)
		end,
		onHitSurface = function(result)
			burst(ctx, result.Position, result.Normal)
		end,
		onExpire = function(position)
			burst(ctx, position, nil)
		end,
	})
end

return Tagger
