--[[
	Physics: per-tick bird movement, ported 1:1 from the original Bird.update()
	and Bird.flap(), with the event-specific branches moved into event hooks.

	Order (same as the original):
	  frozen? -> rocket thrust -> gravity (+event/ability multipliers) -> hover cap
	  -> clamp -> event forces -> bouncy damping -> y += vy
	  -> afterVertical (wormholes, logs) -> horizontal speed -> walls -> vertical wrap
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Abilities = require(script.Parent.Abilities)
local Projectiles = require(script.Parent.Projectiles)

local W, H, R = GameConfig.W, GameConfig.H, GameConfig.RADIUS
local GRAVITY, FLAP, SPEED, MAX_VY = GameConfig.GRAVITY, GameConfig.FLAP, GameConfig.SPEED, GameConfig.MAX_VY

local Physics = {}

export type Mods = {
	gravity: number,
	time: number,
	speed: number,
	flap: number,
	drag: number,
	preDrag: number,
	lockCenter: boolean,
}

local function newMods(): Mods
	return { gravity = 1, time = 1, speed = 1, flap = 1, drag = 1, preDrag = 1, lockCenter = false }
end

-- Gather all multipliers that apply to this bird right now.
function Physics.mods(world, bird): Mods
	local m = newMods()
	local ev = world:eventActive()
	if ev and ev.def.mods then
		ev.def.mods(world, ev, bird, m)
	end
	Abilities.mods(world, bird, m)
	return m
end

-- Returns true if the flap happened.
function Physics.flap(world, bird): boolean
	local tick = world.tick
	if bird.dead or tick < bird.frozenUntil then
		return false
	end
	local m = Physics.mods(world, bird)
	local ev = world:eventActive()

	if bird.gravityShoe then
		-- Gravity shoe: tapping flips your gravity instead of flapping
		bird.upside = not bird.upside
		bird.vy *= 0.7
		bird.flapTick = tick
		bird.flapCount += 1
		world:fx("gravityShoeFlip", bird)
		world:call("onFlap", bird)
		return true
	end

	if bird.rocketBoots then
		bird.thrusting = true
		local impulse = FLAP * 0.4
		if bird.upside then
			bird.vy += impulse
		else
			bird.vy -= impulse
		end
	else
		local strength = FLAP * m.flap
		if tick < bird.dazedUntil then
			strength *= 0.5
		end
		bird.vy = if bird.upside then strength else -strength
	end

	if bird.speedBoots then
		bird.boostUntil = tick + 11
		bird.dashFlashUntil = tick + 13
	end

	if ev and ev.def.onFlap then
		ev.def.onFlap(world, ev, bird)
	end

	-- Blasters: every flap fires an egg (rate-limited)
	Projectiles.tryFire(world, bird)

	bird.flapTick = tick
	bird.flapCount += 1
	world:call("onFlap", bird)
	return true
end

function Physics.release(_world, bird)
	-- releasing the flap button stops rocket thrust
	bird.thrusting = false
end

--[[
	Step one bird by one tick. Returns true if it bounced off a wall this tick.
]]
function Physics.step(world, bird): boolean
	if bird.dead then
		return false
	end
	local tick = world.tick
	bird.prevX = bird.x

	-- Delayed freeze from snowflakes (knock first, freeze 110 ms later)
	if bird.freezeAt >= 0 and tick >= bird.freezeAt then
		bird.freezeAt = -1
		bird.frozenUntil = tick + 60
		world:fx("frozen", bird)
	end
	if tick < bird.frozenUntil then
		bird.vy = 0
		bird.thrusting = false
		bird.rocketCharge = 0
		return false
	end

	local ev = world:eventActive()
	local def = ev and ev.def
	local m = Physics.mods(world, bird)

	-- Rocket boots: hold-to-thrust with charge build-up
	if bird.rocketBoots and bird.thrusting then
		bird.rocketCharge = math.min(1, bird.rocketCharge + 0.02)
		local thrust = 0.6 + bird.rocketCharge * 1.4
		if bird.upside then
			bird.vy += thrust
		else
			bird.vy -= thrust
		end
	else
		bird.rocketCharge *= 0.85
		if bird.rocketCharge < 0.001 then
			bird.rocketCharge = 0
		end
	end
	if not bird.rocketBoots then
		bird.thrusting = false
		bird.rocketCharge = 0
	end

	-- Pre-gravity damping (DRILL dampens velocity before gravity is added, as in the original)
	if m.preDrag ~= 1 then
		bird.vy *= m.preDrag
	end

	-- Gravity
	local g = GRAVITY * m.gravity
	if bird.gravityShoe then
		g = -g
	end
	if bird.glideCanopy then
		g *= 0.72
	end
	bird.vy += (if bird.upside then -g else g) * m.time
	if m.drag ~= 1 then
		bird.vy *= m.drag
	end

	-- Hover drone caps fall speed only
	if bird.hoverDrone then
		if bird.upside then
			if bird.vy < -3.5 then
				bird.vy = -3.5
			end
		elseif bird.vy > 3.5 then
			bird.vy = 3.5
		end
	end

	bird.vy = math.clamp(bird.vy, -MAX_VY, MAX_VY)

	-- Event forces (magnet, tornado, black hole, portal spin, turbulence, ...)
	if def and def.forces then
		def.forces(world, ev, bird, m)
	end
	if bird.bouncy then
		bird.vy *= 0.95
	end

	bird.y += bird.vy * m.time

	-- Wormholes / logs / anything that reacts to the new vertical position
	local carry = 0
	if def and def.afterVertical then
		carry = def.afterVertical(world, ev, bird, m) or 0
	end

	-- Horizontal movement
	local speed = m.speed * m.time
	if bird.speedBoots then
		speed *= 1.45
	end
	speed *= Abilities.speedMult(world, bird)

	if tick < bird.boostUntil then
		bird.x += SPEED * bird.dir * 0.8
		world:fx("boostTrail", bird)
	end

	if def and def.beforeHorizontal then
		if def.beforeHorizontal(world, ev, bird, m, speed) then
			return false
		end
	end

	local pinX = if tick < world.testPhaseUntil then world.testPinX[bird.slot] else nil
	if pinX then
		bird.x = pinX
	elseif m.lockCenter then
		bird.x += (GameConfig.MID_X - bird.x) * 0.2
	else
		bird.x += SPEED * bird.dir * speed * world.speedMult + carry
	end

	-- Walls
	local hitWall = false
	if def and def.walls then
		hitWall = def.walls(world, ev, bird) == true
	elseif not pinX then
		local r = bird.radius
		if bird.x <= r or bird.x >= W - r then
			bird.dir = if bird.x <= r then 1 else -1
			bird.x = math.clamp(bird.x, r, W - r)
			if bird.bouncy then
				bird.vy *= -0.8
			end
			bird.bounceTick = tick
			hitWall = true
			world:call("onWallBounce", bird)
		end
	end

	-- Vertical wrap-around (or event override, e.g. trampoline)
	local handled = false
	if def and def.vertical then
		handled = def.vertical(world, ev, bird) == true
	end
	if not handled then
		local r = bird.radius
		if bird.y > H + r then
			bird.y = -r
			bird.lastWrapTick = tick
		elseif bird.y < -r then
			bird.y = H + r
			bird.lastWrapTick = tick
		end
	end

	return hitWall
end

-- Simulate a ballistic path (used by Hoot's Focus preview and the bot).
-- Returns a list of {x, y} points, no flaps, ignoring events except gravity mods.
function Physics.predictPath(world, bird, steps: number, every: number): { { number } }
	local m = Physics.mods(world, bird)
	local x, y, vy, dir = bird.x, bird.y, bird.vy, bird.dir
	local g = GRAVITY * m.gravity
	if bird.gravityShoe then
		g = -g
	end
	local out = {}
	local speed = m.speed * m.time * Abilities.speedMult(world, bird) * (if bird.speedBoots then 1.45 else 1)
	for i = 1, steps do
		vy += (if bird.upside then -g else g) * m.time
		vy = math.clamp(vy * m.drag, -MAX_VY, MAX_VY)
		y += vy * m.time
		x += SPEED * dir * speed * world.speedMult
		if x <= bird.radius or x >= W - bird.radius then
			dir = -dir
			x = math.clamp(x, bird.radius, W - bird.radius)
		end
		if y > H + R then
			y = -R
		elseif y < -R then
			y = H + R
		end
		if i % every == 0 then
			table.insert(out, { x, y })
		end
	end
	return out
end

return Physics
