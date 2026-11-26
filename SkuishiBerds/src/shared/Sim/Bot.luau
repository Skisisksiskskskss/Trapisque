--[[
	Bot: a port of the original bot's lookahead planner.

	Every few ticks it simulates 2^4 flap sequences ~50 ticks ahead, scores each
	path by danger (spike tips, hazards from the current event) plus distance to
	the safest height on the wall it's flying toward, and plays the first move of
	the best path. `skill` (0..1) adds reaction delay and aim noise so bots are
	beatable in Versus.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Spikes = require(script.Parent.Spikes)
local Physics = require(script.Parent.Physics)
local Abilities = require(script.Parent.Abilities)
local MathUtil = require(script.Parent.MathUtil)

local W, H = GameConfig.W, GameConfig.H
local GRAVITY, FLAP, SPEED, MAX_VY = GameConfig.GRAVITY, GameConfig.FLAP, GameConfig.SPEED, GameConfig.MAX_VY

local Bot = {}

local BRANCH = 4 -- decision points per plan
local SPACING = 6 -- ticks between decision points
local LOOKAHEAD = 50

export type Brain = {
	skill: number,
	nextThink: number,
	plan: { boolean },
	planStep: number,
	safeY: number,
	rng: any,
	wantAbility: boolean,
}

function Bot.newBrain(skill: number, rng): Brain
	return {
		skill = math.clamp(skill, 0, 1),
		nextThink = 0,
		plan = {},
		planStep = 0,
		safeY = H / 2,
		rng = rng,
		wantAbility = false,
	}
end

-- Safest height on the wall the bird is heading toward (original algorithm)
local function findSafeY(world, bird): number
	local targetSide = if bird.dir > 0 then 1 else -1
	local bestY, bestDist = H / 2, -1
	local tick = world.tick
	for testY = bird.radius, H - bird.radius, 20 do
		local minDist = math.huge
		for _, s in world.spikes do
			if s.side == targetSide and Spikes.hurtsTeam(s, bird.team) then
				local d = MathUtil.wrapDy(Spikes.yAt(s, tick) - testY, H)
				if d < minDist then
					minDist = d
				end
			end
		end
		if minDist > bestDist then
			bestDist = minDist
			bestY = testY
		end
	end
	return bestY
end

-- Danger from the current event's hazards at a predicted position `k` ticks ahead
local function hazardDanger(world, ev, x: number, y: number, r: number, k: number): number
	if not ev then
		return 0
	end
	local s = ev.s
	local name = ev.name
	local danger = 0
	if name == "ALIEN_SWARM" and s.aliens then
		for _, a in s.aliens do
			if not ev.removed[a.id] then
				local ax, ay = a.x + a.vx * k, a.y + a.vy * k
				local d = MathUtil.hypot(x - ax, y - ay) - (r + a.size)
				if d < 0 then
					danger += 10000
				elseif d < 120 then
					danger += (120 - d) * 80
				end
			end
		end
	elseif name == "METEOR_SHOWER" and s.meteors then
		for _, m in s.meteors do
			if not ev.removed[m.id] then
				local mx, my = m.x + m.vx * k, m.y + m.vy * k
				local d = MathUtil.hypot(x - mx, y - my) - (r + m.size)
				if d < 0 then
					danger += 10000
				elseif d < 90 then
					danger += (90 - d) * 60
				end
			end
		end
	elseif name == "GEAR_GRIND" and s.gears then
		local t = world.tick - ev.startTick + k
		for _, g in s.gears do
			if t >= g.collidableAt and not ev.removed[g.id] then
				local gx, gy = g.x + g.vx * k, g.y + g.vy * k
				local d = MathUtil.hypot(x - gx, y - gy) - (r + g.r * 1.2)
				if d < 8 then
					danger += 12000
				elseif d < 80 then
					danger += (80 - d) * 12
				end
			end
		end
	elseif name == "RAIL_RUSH" and s.trains then
		for _, tr in s.trains do
			local tx = tr.x + tr.vx * k
			if x > tx and x < tx + tr.w and math.abs(y - tr.y) < tr.h / 2 + r then
				danger += 20000
			end
		end
		for _, wn in s.warnings do
			if math.abs(y - wn.y) < 35 + r + 20 then
				danger += 3000
			end
		end
	elseif name == "MAGMA_FLOW" then
		local t = world.tick - ev.startTick + k
		local height = math.min(H, 0.9 * t)
		if height < H * 0.75 then
			local dist = (H - height) - (y + r)
			if dist < 0 then
				danger += 25000
			elseif dist < 120 then
				danger += (120 - dist) * 15
			end
		end
	elseif name == "LASER_BEAMS" and s.lasers then
		local t = world.tick - ev.startTick + k
		if t >= s.warning then
			local dx, dy = x - W / 2, y - H / 2
			local dist = MathUtil.hypot(dx, dy)
			local a = math.atan2(dy, dx)
			for _, l in s.lasers do
				local diff = MathUtil.angleDiff(a, l.angle0 + l.speed * t)
				if dist * math.cos(diff) > 0 then
					local perp = math.abs(dist * math.sin(diff))
					if perp < r + l.width / 2 then
						danger += 15000
					elseif perp < r + l.width / 2 + 80 then
						danger += (r + l.width / 2 + 80 - perp) * 180
					end
				end
			end
		end
	elseif name == "HORIZON_BEAMS" and s.beams then
		local t = world.tick - ev.startTick + k
		for _, b in s.beams do
			local on = b.warnStart + b.warning
			if t >= on - 10 and t < on + b.active then
				local d = math.abs(y - b.y) - (b.width / 2 + r)
				if d < 0 then
					danger += 15000
				elseif d < 50 then
					danger += (50 - d) * 100
				end
			end
		end
	elseif name == "LIGHTNING_STORM" and s.strikes then
		local t = world.tick - ev.startTick + k
		for _, st in s.strikes do
			local age = t - st.born
			if age >= st.warning - 20 and age < st.warning + st.active then
				local d = MathUtil.hypot(x - st.x, y - st.targetY) - (30 + r)
				if d < 0 then
					danger += 15000
				elseif d < 60 then
					danger += (60 - d) * 100
				end
			end
		end
	elseif name == "BONE_ZONE" and s.bones then
		for _, b in s.bones do
			local bx = b.x + b.vx * k
			if x + r > bx - 12 and x - r < bx + b.w + 12 then
				local top, bottom = b.y, b.y + b.h
				if b.kind == "floating" then
					top, bottom = b.y - 12, b.y + 12
				end
				if y + r > top - 10 and y - r < bottom + 10 then
					danger += 12000
				end
			end
		end
	end
	return danger
end

-- Score one flap sequence (lower is better)
local function evaluate(world, bird, ev, m, seq: { boolean }, safeY: number, margin: number): number
	local x, y, vy, dir = bird.x, bird.y, bird.vy, bird.dir
	local r = bird.radius
	local g = GRAVITY * m.gravity
	if bird.gravityShoe then
		g = -g
	end
	local speed = m.speed * m.time * (if bird.speedBoots then 1.45 else 1) * Abilities.speedMult(world, bird)
	local danger = 0
	local tick = world.tick
	for step = 1, LOOKAHEAD do
		local decision = math.ceil(step / SPACING)
		if decision <= BRANCH and (step - 1) % SPACING == 0 and seq[decision] then
			local strength = FLAP * m.flap
			vy = if bird.upside then strength else -strength
		end
		vy *= m.preDrag
		vy += (if bird.upside then -g else g) * m.time
		vy = math.clamp(vy * m.drag, -MAX_VY, MAX_VY)
		y += vy * m.time
		if y < -r then
			y += H + 2 * r
		elseif y > H + r then
			y -= H + 2 * r
		end
		x += SPEED * dir * speed * world.speedMult
		if x <= r or x >= W - r then
			dir = -dir
			x = math.clamp(x, r, W - r)
		end

		-- spikes: only matter near the walls
		if x < 60 or x > W - 60 then
			local futureTick = tick + step
			for _, s in world.spikes do
				if Spikes.hurtsTeam(s, bird.team) and (s.side < 0) == (x < W / 2) then
					local tipX = Spikes.tipX(s)
					local dx = x - tipX
					local dy = MathUtil.wrapDy(y - Spikes.yAt(s, futureTick), H)
					local dist = math.sqrt(dx * dx + dy * dy)
					local dangerR = r + s.size * 0.6 + margin
					if dist < dangerR then
						danger += 10000
					elseif dist < dangerR + 30 then
						danger += (dangerR + 30 - dist) * 300
					elseif dist < dangerR + 100 then
						danger += (dangerR + 100 - dist) * 10
					end
				end
			end
		end

		if step % 2 == 0 then
			danger += hazardDanger(world, ev, x, y, r, step)
		end
	end
	return danger + math.abs(y - safeY) * 5
end

--[[
	Decide this tick's input for a bot bird.
	Returns flap (boolean), ability (boolean)
]]
function Bot.think(world, bird, brain: Brain): (boolean, boolean)
	if bird.dead then
		return false, false
	end
	local tick = world.tick
	local ev = world:eventActive()

	-- Bone gauntlet: aim for the nearest gap center (original special case)
	if ev and ev.name == "BONE_ZONE" and ev.s.bones then
		local best, bestDx = nil, math.huge
		for _, b in ev.s.bones do
			if b.kind == "bone" and b.y == 0 and b.x + b.w > bird.x - 10 then
				local dx = b.x - bird.x
				if dx < bestDx then
					best, bestDx = b, dx
				end
			end
		end
		if best then
			local aim = best.h + 110 + (brain.rng:next() - 0.5) * 40 * (1 - brain.skill)
			local flap = if bird.upside then bird.y < aim - 16 else bird.y > aim + 16
			return flap, false
		end
	end

	-- follow the current plan between thinks
	if tick < brain.nextThink then
		local step = tick - brain.planStep
		if step % SPACING == 0 then
			local decision = step // SPACING + 1
			return brain.plan[decision] == true, false
		end
		return false, false
	end

	local m = Physics.mods(world, bird)
	brain.safeY = findSafeY(world, bird) + (brain.rng:next() - 0.5) * 60 * (1 - brain.skill)
	local margin = 4 * brain.skill

	local bestScore, bestSeq = math.huge, nil
	local seq = {}
	for code = 0, (2 ^ BRANCH) - 1 do
		for i = 1, BRANCH do
			seq[i] = bit32.btest(code, 2 ^ (i - 1))
		end
		local score = evaluate(world, bird, ev, m, seq, brain.safeY, margin)
		if score < bestScore then
			bestScore = score
			bestSeq = table.clone(seq)
		end
	end

	brain.plan = bestSeq or {}
	brain.planStep = tick
	-- lower skill = slower re-planning
	brain.nextThink = tick + SPACING + math.floor((1 - brain.skill) * 4)

	local flap = brain.plan[1] == true
	-- occasional hesitation for weaker bots
	if flap and brain.rng:next() < (1 - brain.skill) * 0.08 then
		flap = false
	end

	-- Abilities: fire when the best available path still looks dangerous
	local useAbility = false
	if Abilities.ready(world, bird) and bestScore > 2500 then
		useAbility = brain.rng:next() < 0.35 + 0.5 * brain.skill
	end
	return flap, useAbility
end

return Bot
