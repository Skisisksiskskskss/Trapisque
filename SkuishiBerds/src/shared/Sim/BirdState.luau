--[[
	BirdState: the data for one bird plus damage/respawn rules.

	A bird is "simulated" on exactly one machine: the owning client simulates its
	own bird(s) (instant, lag-free flaps); the server simulates bots. Everyone else
	only renders an interpolated copy.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local BirdState = {}

export type Bird = {
	slot: number,
	team: number,
	kind: string,
	name: string,
	userId: number,
	isBot: boolean,
	sim: boolean,

	x: number,
	y: number,
	vy: number,
	dir: number,
	prevX: number,
	radius: number,
	baseRadius: number,
	sizeScale: number,
	upside: boolean,

	lives: number,
	maxLives: number,
	dead: boolean,
	deadTick: number,
	invulnUntil: number,
	respawnTick: number,

	-- event items / statuses
	ghost: boolean,
	bouncy: boolean,
	shielded: boolean,
	rocketBoots: boolean,
	thrusting: boolean,
	rocketCharge: number,
	speedBoots: boolean,
	boostUntil: number,
	dashFlashUntil: number,
	hoverDrone: boolean,
	gravityShoe: boolean,
	glideCanopy: boolean,
	gun: boolean,
	lastShotTick: number,
	drill: boolean,
	pendingDrill: boolean,
	frozenUntil: number,
	freezeAt: number,
	echoStunUntil: number,
	hitGlowUntil: number,
	lastWrapTick: number,
	lastWormholeTick: number,
	dazedUntil: number,

	-- ability
	charge: number,
	abilityUntil: number,
	abilityUses: number,
	pecking: boolean,

	-- scoring / bookkeeping
	strums: number,
	hasStrummed: boolean,
	flapTick: number,
	flapCount: number,
	bounceTick: number,
	lastCrossTick: number,
}

function BirdState.new(slot: number, opts: { [string]: any }): Bird
	local x = opts.x or GameConfig.MID_X
	local bird: Bird = {
		slot = slot,
		team = opts.team or slot,
		kind = opts.kind or "berd",
		name = opts.name or ("Bird " .. slot),
		userId = opts.userId or 0,
		isBot = opts.isBot == true,
		sim = opts.sim == true,

		x = x,
		y = opts.y or GameConfig.H / 2,
		vy = 0,
		dir = opts.dir or 1,
		prevX = x,
		radius = GameConfig.RADIUS,
		baseRadius = GameConfig.RADIUS,
		sizeScale = 1,
		upside = opts.upside == true,

		lives = opts.lives or GameConfig.LIVES,
		maxLives = opts.lives or GameConfig.LIVES,
		dead = false,
		deadTick = -1,
		invulnUntil = 0,
		respawnTick = -1000,

		ghost = false,
		bouncy = false,
		shielded = false,
		rocketBoots = false,
		thrusting = false,
		rocketCharge = 0,
		speedBoots = false,
		boostUntil = 0,
		dashFlashUntil = 0,
		hoverDrone = false,
		gravityShoe = false,
		glideCanopy = false,
		gun = false,
		lastShotTick = -1000,
		drill = false,
		pendingDrill = false,
		frozenUntil = 0,
		freezeAt = -1,
		echoStunUntil = 0,
		hitGlowUntil = 0,
		lastWrapTick = -1000,
		lastWormholeTick = -1000,
		dazedUntil = 0,

		charge = 0,
		abilityUntil = 0,
		abilityUses = 0,
		pecking = false,

		strums = 0,
		hasStrummed = false,
		flapTick = -1000,
		flapCount = 0,
		bounceTick = -1000,
		lastCrossTick = -1000,
	}
	return bird
end

-- Items granted by events are lost when you take damage (original rule).
function BirdState.clearItems(bird: Bird)
	bird.gun = false
	bird.rocketBoots = false
	bird.thrusting = false
	bird.rocketCharge = 0
	bird.speedBoots = false
	bird.hoverDrone = false
	bird.gravityShoe = false
	bird.glideCanopy = false
end

function BirdState.isInvulnerable(bird: Bird, tick: number): boolean
	return tick < bird.invulnUntil
end

--[[
	Where a bird reappears after a hit. Co-op: mirrored across the middle line
	from its partner (original behaviour, keeps both birds symmetric).
	Otherwise: the middle column at its current height.
	Returns x, y, dir.
]]
function BirdState.respawnSpot(bird: Bird, partner: Bird?): (number, number, number)
	if partner and not partner.dead then
		local mid = GameConfig.MID_X
		local x = mid - (partner.x - mid)
		return x, partner.y, -partner.dir
	end
	return GameConfig.MID_X, math.clamp(bird.y, 60, GameConfig.H - 60), bird.dir
end

function BirdState.placeAt(bird: Bird, x: number, y: number, dir: number)
	bird.x = math.clamp(x, bird.radius, GameConfig.W - bird.radius)
	bird.prevX = bird.x
	bird.y = y
	bird.vy = 0
	bird.dir = if dir >= 0 then 1 else -1
end

--[[
	Apply one hit. Returns "shield" | "hurt" | "dead".
	(The caller decides authority: clients predict for their own birds, the server confirms.)
]]
function BirdState.applyHit(bird: Bird, tick: number, partner: Bird?, ignoreShield: boolean?): string
	if bird.shielded and not ignoreShield then
		bird.shielded = false
		local x, y, dir = BirdState.respawnSpot(bird, partner)
		BirdState.placeAt(bird, x, y, dir)
		bird.invulnUntil = tick + 30
		bird.respawnTick = tick
		return "shield"
	end
	bird.lives -= 1
	if bird.lives <= 0 then
		bird.lives = 0
		bird.dead = true
		bird.deadTick = tick
		return "dead"
	end
	bird.invulnUntil = tick + GameConfig.INVULN_TICKS
	bird.hitGlowUntil = tick + 30
	BirdState.clearItems(bird)
	local x, y, dir = BirdState.respawnSpot(bird, partner)
	BirdState.placeAt(bird, x, y, dir)
	bird.respawnTick = tick
	return "hurt"
end

-- Compact network form of the movement state (sent ~30x/s).
function BirdState.pack(bird: Bird): { number }
	local flags = 0
	if bird.upside then
		flags += 1
	end
	if bird.thrusting then
		flags += 2
	end
	if bird.ghost then
		flags += 4
	end
	if bird.shielded then
		flags += 8
	end
	if bird.drill then
		flags += 16
	end
	if bird.gun then
		flags += 32
	end
	if bird.rocketBoots then
		flags += 64
	end
	if bird.speedBoots then
		flags += 128
	end
	if bird.hoverDrone then
		flags += 256
	end
	if bird.gravityShoe then
		flags += 512
	end
	if bird.pecking then
		flags += 1024
	end
	return {
		math.floor(bird.x * 10 + 0.5) / 10,
		math.floor(bird.y * 10 + 0.5) / 10,
		math.floor(bird.vy * 100 + 0.5) / 100,
		bird.dir,
		bird.radius,
		flags,
		bird.flapCount,
		bird.abilityUntil,
	}
end

function BirdState.unpackInto(bird: Bird, data: { number })
	bird.x = data[1] or bird.x
	bird.y = data[2] or bird.y
	bird.vy = data[3] or bird.vy
	bird.dir = data[4] or bird.dir
	bird.radius = data[5] or bird.radius
	local flags = data[6] or 0
	bird.upside = bit32.btest(flags, 1)
	bird.thrusting = bit32.btest(flags, 2)
	bird.ghost = bit32.btest(flags, 4)
	bird.shielded = bit32.btest(flags, 8)
	bird.drill = bit32.btest(flags, 16)
	bird.gun = bit32.btest(flags, 32)
	bird.rocketBoots = bit32.btest(flags, 64)
	bird.speedBoots = bit32.btest(flags, 128)
	bird.hoverDrone = bit32.btest(flags, 256)
	bird.gravityShoe = bit32.btest(flags, 512)
	bird.pecking = bit32.btest(flags, 1024)
	bird.flapCount = data[7] or bird.flapCount
	bird.abilityUntil = data[8] or bird.abilityUntil
end

return BirdState
