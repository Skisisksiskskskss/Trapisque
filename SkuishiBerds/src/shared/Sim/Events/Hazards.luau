--[[
	Hazard events: things that fly around the arena. Every hazard is created from
	ev.rng in a fixed order so all machines agree; destruction/pickups go through
	the server (ev.removed).
]]

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.Parent.MathUtil)
local EventUtil = require(script.Parent.Parent.EventUtil)

local W, H = GameConfig.W, GameConfig.H
local PI2 = math.pi * 2

local ALIEN_COLORS = { "#ff6b9d", "#4ecdc4", "#ffe66d", "#95e1d3", "#f38181", "#aa96da" }
local BLIMP_COLORS = { "#ffd166", "#ffb3ba", "#bae1ff", "#a8e6cf", "#d4b5ff" }

local function within(x: number, y: number, ex: number, ey: number, r: number): boolean
	local dx, dy = x - ex, y - ey
	return dx * dx + dy * dy < r * r
end

-- Generic "list of round things" helpers for shoot/honk
local function shootList(list, ev, x, y, r, sizeKey: string)
	for _, e in list do
		if not ev.removed[e.id] and within(x, y, e.x, e.y, r + e[sizeKey]) then
			return e.id
		end
	end
	return nil
end

local function honkList(list, ev, x, y, r, out)
	for _, e in list do
		if not ev.removed[e.id] and within(x, y, e.x, e.y, r) then
			table.insert(out, e.id)
		end
	end
	return out
end

------------------------------------------------------------------------------
-- METEOR SHOWER
------------------------------------------------------------------------------
local METEOR_SPAWN_WINDOW = 540 -- 9 s

local function newMeteor(ev, rng, initial: boolean)
	local m = {
		id = EventUtil.nextId(ev),
		x = rng:range(0, W),
		y = -50,
		vx = rng:spread(1.5),
		vy = 3 + rng:next() * 3.5,
		size = 10 + rng:next() * 10,
		rot = rng:next() * PI2,
		rotSpeed = rng:spread(0.12),
	}
	m.x = rng:next() * (W * 0.8) + W * 0.1
	if initial then
		m.vy *= 0.9 + rng:next() * 0.6
		m.size *= 0.8 + rng:next() * 0.6
	else
		m.vy *= 0.85 + rng:next() * 0.06
		m.size *= 0.7 + rng:next() * 0.15
	end
	table.insert(ev.s.meteors, m)
	return m
end

------------------------------------------------------------------------------
-- LIGHTNING
------------------------------------------------------------------------------
local function newStrike(ev, rng, t: number)
	local x = rng:range(50, W - 50)
	local targetY = rng:range(50, H - 50)
	local segments = {}
	local cy = 0
	while cy < targetY do
		table.insert(segments, { x + rng:spread(30), cy })
		cy += 24 + rng:next() * 18
	end
	table.insert(segments, { x, targetY })
	table.insert(ev.s.strikes, {
		x = x,
		targetY = targetY,
		born = t,
		warning = 72,
		active = 18,
		segments = segments,
	})
end

------------------------------------------------------------------------------
-- GEARS
------------------------------------------------------------------------------
local function spawnGear(ev, rng, t: number, onScreen: boolean)
	local size = 15 + rng:next() * 25
	local x, y
	if onScreen then
		x = rng:next() * W
		y = rng:next() * H
	else
		local left = rng:next() > 0.5
		x = if left then -size - 50 else W + size + 50
		y = rng:next() * H
	end
	local targetX = if x < W / 2 then W + 200 else -200
	local speed = 1 + rng:next()
	table.insert(ev.s.gears, {
		id = EventUtil.nextId(ev),
		x = x,
		y = y,
		r = size,
		teeth = 6 + math.floor(rng:next() * 6) * 2,
		angle = rng:next() * PI2,
		spin = rng:spread(0.05),
		vx = MathUtil.sign(targetX - x) * speed,
		vy = rng:spread(0.5),
		color = if rng:next() > 0.5 then "#cd7f32" else "#b87333",
		born = t,
		collidableAt = t + 60,
	})
end

------------------------------------------------------------------------------
-- PHOTON
------------------------------------------------------------------------------
local function newBeam(ev, rng, t: number)
	table.insert(ev.s.beams, {
		id = EventUtil.nextId(ev),
		x = rng:next() * W,
		y = rng:next() * H,
		angle = rng:next() * PI2,
		width = 0.9 + rng:next() * 1.4,
		pulseStart = -1000,
		nextPulse = t + 54 + rng:next() * 72,
		hue = 150 + math.floor(rng:next() * 180),
		hitBy = {},
	})
end

local function photonPulseT(beam, t: number): number
	return math.max(0, 1 - (t - beam.pulseStart) / 25)
end

------------------------------------------------------------------------------
-- COLOR RIFT shards
------------------------------------------------------------------------------
local function newShard(ev, rng, small: boolean)
	table.insert(ev.s.shards, {
		id = EventUtil.nextId(ev),
		x = rng:next() * W,
		y = rng:next() * H,
		vx = rng:spread(1.2),
		vy = rng:spread(1.2),
		size = if small then 6 + rng:next() * 8 else 8 + rng:next() * 10,
		hue = rng:int(0, 359),
		wobble = rng:next() * PI2,
	})
end

------------------------------------------------------------------------------
return {
	{
		name = "ALIEN_SWARM",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.aliens = {}
			for _ = 1, rng:int(3, 5) do
				table.insert(ev.s.aliens, {
					id = EventUtil.nextId(ev),
					x = rng:range(50, W - 50),
					y = rng:range(50, H - 50),
					vx = rng:spread(3),
					vy = rng:spread(3),
					size = 20 + rng:next() * 15,
					design = rng:int(0, 2),
					color1 = rng:pick(ALIEN_COLORS),
					color2 = rng:pick(ALIEN_COLORS),
					rot = rng:next() * PI2,
					rotSpeed = rng:spread(0.1),
				})
			end
		end,
		step = function(_w, ev)
			for _, a in ev.s.aliens do
				a.x += a.vx
				a.y += a.vy
				a.rot += a.rotSpeed
				if a.x < a.size or a.x > W - a.size then
					a.vx = -a.vx
					a.x = math.clamp(a.x, a.size, W - a.size)
				end
				if a.y < a.size or a.y > H - a.size then
					a.vy = -a.vy
					a.y = math.clamp(a.y, a.size, H - a.size)
				end
			end
		end,
		hit = function(_w, ev, bird)
			for _, a in ev.s.aliens do
				if not ev.removed[a.id] and EventUtil.circleHit(bird, a.x, a.y, a.size) then
					return "alien", a.id
				end
			end
			return nil
		end,
		shoot = function(_w, ev, x, y, r)
			return shootList(ev.s.aliens, ev, x, y, r, "size")
		end,
		honk = function(_w, ev, x, y, r)
			return honkList(ev.s.aliens, ev, x, y, r, {})
		end,
	},
	{
		name = "METEOR_SHOWER",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.meteors = {}
			ev.s.pending = {}
			for i = 0, 2 do
				table.insert(ev.s.pending, math.floor(i * 11 + rng:next() * 13))
			end
			ev.s.cooldown = 9
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local rng = ev.rng
			local s = ev.s
			-- staggered opening burst
			for i = #s.pending, 1, -1 do
				if t >= s.pending[i] then
					table.remove(s.pending, i)
					newMeteor(ev, rng, true)
					world:fx("meteor", nil)
				end
			end
			-- steady spawns while the window is open (cap of 8 on screen)
			local live = 0
			for _, m in s.meteors do
				if m.y < H + 80 then
					live += 1
				end
			end
			if t >= s.cooldown and live < 8 and t < METEOR_SPAWN_WINDOW then
				newMeteor(ev, rng, false)
				s.cooldown = t + 12 + rng:next() * 54
				world:fx("meteor", nil)
			end
			for i = #s.meteors, 1, -1 do
				local m = s.meteors[i]
				m.x += m.vx
				m.y += m.vy
				m.rot += m.rotSpeed
				if m.y >= H + 80 then
					table.remove(s.meteors, i)
				end
			end
		end,
		isDone = function(world, ev)
			if EventUtil.t(world, ev) < METEOR_SPAWN_WINDOW or #ev.s.pending > 0 then
				return false
			end
			for _, m in ev.s.meteors do
				if not ev.removed[m.id] then
					return false
				end
			end
			return true
		end,
		hit = function(_w, ev, bird)
			for _, m in ev.s.meteors do
				if not ev.removed[m.id] and EventUtil.circleHit(bird, m.x, m.y, m.size) then
					return "meteor", m.id
				end
			end
			return nil
		end,
		shoot = function(_w, ev, x, y, r)
			return shootList(ev.s.meteors, ev, x, y, r, "size")
		end,
		honk = function(_w, ev, x, y, r)
			return honkList(ev.s.meteors, ev, x, y, r, {})
		end,
	},
	{
		name = "LIGHTNING_STORM",
		start = function(_w, ev)
			ev.s.strikes = {}
			ev.s.spawnTimes = { 0, 54 }
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local times = ev.s.spawnTimes
			for i = #times, 1, -1 do
				if t >= times[i] then
					table.remove(times, i)
					newStrike(ev, ev.rng, t)
				end
			end
			for _, st in ev.s.strikes do
				if t == st.born + st.warning then
					world:fx("thunder", st)
				end
			end
		end,
		hit = function(world, ev, bird)
			local t = EventUtil.t(world, ev)
			for _, st in ev.s.strikes do
				local age = t - st.born
				if age >= st.warning and age < st.warning + st.active then
					if EventUtil.circleHit(bird, st.x, st.targetY, 30) then
						return "lightning", nil
					end
				end
			end
			return nil
		end,
	},
	{
		-- two lasers sweep around the center after a 1.5 s warning
		name = "LASER_BEAMS",
		start = function(_w, ev)
			ev.s.lasers = {
				{ angle0 = 0, speed = 0.01, width = 15 },
				{ angle0 = math.pi, speed = 0.01, width = 15 },
			}
			ev.s.warning = 90
			ev.s.length = math.max(W, H)
		end,
		hit = function(world, ev, bird)
			local t = EventUtil.t(world, ev)
			if t < ev.s.warning then
				return nil
			end
			local dx, dy = bird.x - W / 2, bird.y - H / 2
			local dist = MathUtil.hypot(dx, dy)
			local birdAngle = math.atan2(dy, dx)
			for _, l in ev.s.lasers do
				local angle = l.angle0 + l.speed * t
				local diff = MathUtil.angleDiff(birdAngle, angle)
				local perp = dist * math.sin(diff)
				if math.abs(perp) < bird.radius + l.width / 2 and dist * math.cos(diff) > 0 then
					return "laser", nil
				end
			end
			return nil
		end,
	},
	{
		name = "HORIZON_BEAMS",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.beams = {}
			for i = 0, rng:int(3, 5) - 1 do
				table.insert(ev.s.beams, {
					y = rng:range(75, H - 75),
					warnStart = i * 36,
					warning = 90,
					active = 120,
					width = 20,
				})
			end
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			for _, b in ev.s.beams do
				if t == b.warnStart + b.warning then
					world:fx("beamFire", b)
				end
			end
		end,
		hit = function(world, ev, bird)
			local t = EventUtil.t(world, ev)
			for _, b in ev.s.beams do
				local on = b.warnStart + b.warning
				if t >= on and t < on + b.active and math.abs(bird.y - b.y) < b.width / 2 + bird.radius then
					return "beam", nil
				end
			end
			return nil
		end,
	},
	{
		name = "BLACK_HOLE",
		start = function(_w, ev)
			ev.s.hole = { x = W / 2, y = H / 2, r = 40, strength = 0.8 }
		end,
		forces = function(_w, ev, bird, m)
			local hole = ev.s.hole
			local dx, dy = hole.x - bird.x, hole.y - bird.y
			local dist = MathUtil.hypot(dx, dy)
			if dist > 0 and dist < 300 then
				local pull = hole.strength * (1 - dist / 300)
				bird.vy += (dy / dist) * pull * 2 * m.time
				bird.x += (dx / dist) * pull * m.time
			end
		end,
	},
	{
		name = "WORMHOLES",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.pairs = {}
			for _ = 1, 2 do
				table.insert(ev.s.pairs, {
					a = { x = rng:range(100, W - 100), y = rng:range(100, H - 100), r = 30 },
					b = { x = rng:range(100, W - 100), y = rng:range(100, H - 100), r = 30 },
				})
			end
		end,
		afterVertical = function(world, ev, bird, _m)
			if world.tick - bird.lastWormholeTick < 12 then
				return 0
			end
			for _, p in ev.s.pairs do
				local dest
				if within(bird.x, bird.y, p.a.x, p.a.y, p.a.r) then
					dest = p.b
				elseif within(bird.x, bird.y, p.b.x, p.b.y, p.b.r) then
					dest = p.a
				end
				if dest then
					bird.x, bird.y = dest.x, dest.y
					bird.prevX = bird.x
					bird.lastWormholeTick = world.tick
					bird.lastWrapTick = world.tick
					world:fx("wormhole", bird)
					break
				end
			end
			return 0
		end,
	},
	{
		name = "TORNADO",
		start = function(_w, ev)
			ev.s.x = W / 2
			ev.s.y = H / 2
			ev.s.phase = ev.rng:next() * 10000
		end,
		step = function(world, ev)
			local ms = EventUtil.ms(EventUtil.t(world, ev)) + ev.s.phase
			ev.s.x = math.clamp(ev.s.x + math.sin(ms / 1000) * 2, 100, W - 100)
			ev.s.y = math.clamp(ev.s.y + math.cos(ms / 800) * 1.5, 100, H - 100)
		end,
		forces = function(_w, ev, bird, m)
			local dx, dy = ev.s.x - bird.x, ev.s.y - bird.y
			local dist = MathUtil.hypot(dx, dy)
			if dist > 0 and dist < 500 then
				local pull = (1 - dist / 500) * 2.8
				bird.vy += (dy / dist) * pull * m.time
				bird.x += (dx / dist) * pull * 0.5
			end
		end,
	},
	{
		name = "PORTAL_SPIN",
		start = function(_w, ev)
			ev.s.radius = math.min(W, H) * 0.3
		end,
		forces = function(_w, ev, bird, _m)
			local cx, cy = W / 2, H / 2
			local dx, dy = bird.x - cx, bird.y - cy
			local dist = MathUtil.hypot(dx, dy)
			if dist > 0 then
				local pull = (dist - ev.s.radius) * 0.05
				bird.x -= (dx / dist) * pull
				bird.y -= (dy / dist) * pull
				local orbit = 0.05 * dist * 0.1
				bird.x += (-dy / dist) * orbit
				bird.y += (dx / dist) * orbit
			end
		end,
	},
	{
		name = "GEAR_GRIND",
		start = function(_w, ev)
			ev.s.gears = {}
			for _ = 1, 4 do
				spawnGear(ev, ev.rng, 0, true)
			end
			ev.s.spawnAt = 0
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local s = ev.s
			if t >= s.spawnAt then
				spawnGear(ev, ev.rng, t, false)
				s.spawnAt = t + 72 + ev.rng:next() * 48
			end
			for i = #s.gears, 1, -1 do
				local g = s.gears[i]
				g.x += g.vx
				g.y += g.vy
				g.angle += g.spin
				if g.x < -200 or g.x > W + 200 or g.y < -200 or g.y > H + 200 then
					table.remove(s.gears, i)
				end
			end
		end,
		hit = function(world, ev, bird)
			local t = EventUtil.t(world, ev)
			for _, g in ev.s.gears do
				if t >= g.collidableAt and not ev.removed[g.id] and EventUtil.circleHit(bird, g.x, g.y, g.r * 1.2) then
					return "gear", g.id
				end
			end
			return nil
		end,
		honk = function(_w, ev, x, y, r)
			return honkList(ev.s.gears, ev, x, y, r, {})
		end,
	},
	{
		-- long thin beams that pulse and SHOVE birds (no damage)
		name = "PHOTON_SHIFT",
		start = function(_w, ev)
			ev.s.beams = {}
			for _ = 1, ev.rng:int(1, 3) do
				newBeam(ev, ev.rng, 0)
			end
			ev.s.spawnAt = 18
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local rng = ev.rng
			local s = ev.s
			if t >= s.spawnAt then
				if rng:chance(0.25) and #s.beams < 5 then
					newBeam(ev, rng, t)
				end
				s.spawnAt = t + 42 + rng:next() * 72
			end
			for _, b in s.beams do
				if t >= b.nextPulse then
					b.pulseStart = t
					b.nextPulse = t + 54 + rng:next() * 72
					world:fx("photonPulse", b)
				end
			end
		end,
		touch = function(world, ev, bird)
			local t = EventUtil.t(world, ev)
			for _, b in ev.s.beams do
				local p = photonPulseT(b, t)
				if p > 0.2 and b.hitBy[bird.slot] ~= b.pulseStart then
					local dx, dy = math.cos(b.angle), math.sin(b.angle)
					local vx, vy = bird.x - b.x, bird.y - b.y
					local cross = vx * -dy + vy * dx
					if math.abs(cross) < bird.radius + math.max(6, b.width * 6) then
						b.hitBy[bird.slot] = b.pulseStart
						if bird.shielded then
							bird.shielded = false
							world:fx("shieldPop", bird)
						else
							local side = if cross >= 0 then 1 else -1
							bird.x += side * (10 + p * 20)
							bird.vy = if bird.upside then -6 else 6
							bird.hitGlowUntil = world.tick + 30
							world:fx("photonHit", { bird = bird, hue = b.hue })
						end
					end
				end
			end
		end,
	},
	{
		-- expanding sound rings knock birds around
		name = "ECHO_CHAMBER",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.orbs = {}
			for i = 0, 2 do
				table.insert(ev.s.orbs, {
					x = rng:next() * W,
					y = rng:next() * H,
					born = i * 23,
					life = 120,
					maxR = 150 + rng:next() * 100,
				})
			end
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local rng = ev.rng
			if rng:chance(0.05) then
				table.insert(ev.s.orbs, {
					x = rng:next() * W,
					y = rng:next() * H,
					born = t,
					life = 150,
					maxR = 200 + rng:next() * 100,
				})
			end
			for i = #ev.s.orbs, 1, -1 do
				local o = ev.s.orbs[i]
				if t - o.born >= o.life then
					table.remove(ev.s.orbs, i)
				end
			end
		end,
		touch = function(world, ev, bird)
			if world.tick < bird.echoStunUntil then
				return
			end
			local t = EventUtil.t(world, ev)
			for _, o in ev.s.orbs do
				local age = t - o.born
				if age >= 0 then
					local radius = (age / o.life) * o.maxR
					local dx, dy = bird.x - o.x, bird.y - o.y
					local d = MathUtil.hypot(dx, dy)
					if math.abs(d - radius) < 30 then
						bird.echoStunUntil = world.tick + 30
						local angle = math.atan2(dy, dx)
						bird.vy += math.sin(angle) * 8
						bird.x += math.cos(angle) * 8
						world:fx("echoHit", bird)
						return
					end
				end
			end
		end,
	},
	{
		-- collectible shards: +1 strum each
		name = "COLOR_RIFT",
		start = function(_w, ev)
			ev.s.shards = {}
			for _ = 1, ev.rng:int(10, 17) do
				newShard(ev, ev.rng, false)
			end
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			if t > 0 and t % 150 == 0 then
				for _ = 1, 3 do
					newShard(ev, ev.rng, true)
				end
			end
			for _, s in ev.s.shards do
				s.wobble += 0.06
				s.x += s.vx + math.sin(s.wobble) * 0.3
				s.y += s.vy + math.cos(s.wobble * 0.9) * 0.25
				if s.x < -20 then
					s.x = W + 20
				elseif s.x > W + 20 then
					s.x = -20
				end
				if s.y < -20 then
					s.y = H + 20
				elseif s.y > H + 20 then
					s.y = -20
				end
			end
		end,
		collect = function(world, ev, bird)
			for _, s in ev.s.shards do
				if not ev.removed[s.id] and EventUtil.circleHit(bird, s.x, s.y, s.size * 0.6) then
					EventUtil.report(world, ev, s.id, "collect", bird)
				end
			end
		end,
	},
	{
		-- floating balloons you can bounce on
		name = "BLIMP_CANOPY",
		start = function(_w, ev)
			local rng = ev.rng
			local count = 4 + rng:int(0, 2)
			local sides = {}
			local top = math.floor(count / 2)
			for i = 1, count do
				sides[i] = i <= count - top
			end
			rng:shuffle(sides)
			ev.s.blimps = {}
			for i = 1, count do
				local size = 40 + rng:next() * 60
				local fromBottom = sides[i]
				local x = math.clamp(rng:next() * (W - size * 2) + size, 40, W - 40)
				local y = if fromBottom then H + rng:next() * 120 + 40 else -rng:next() * 120 - 40
				local rise = 0.6 + rng:next() * 1.2
				table.insert(ev.s.blimps, {
					x = x,
					y = y,
					size = size,
					rise = if fromBottom then rise else -rise,
					fromBottom = fromBottom,
					color = rng:pick(BLIMP_COLORS),
					width = math.max(math.min(size * 2, W - 80), size * 1.2),
					height = size,
				})
			end
		end,
		step = function(world, ev)
			local ms = EventUtil.ms(EventUtil.t(world, ev))
			for _, b in ev.s.blimps do
				b.y -= b.rise
				b.x += math.sin((ms + b.x) / 200) * 0.3
			end
		end,
		touch = function(world, ev, bird)
			for _, b in ev.s.blimps do
				local topY = b.y - b.height / 2
				local bottomY = b.y + b.height / 2
				local left, right = b.x - b.width / 2 + 6, b.x + b.width / 2 - 6
				if bird.x > left and bird.x < right then
					if b.fromBottom then
						local bottom = bird.y + bird.radius
						if bird.vy > 0 and bottom >= topY - 1 and bottom - bird.vy <= topY + 4 then
							bird.y = topY - bird.radius - 0.5
							bird.vy = -bird.vy
							world:fx("bounceBlimp", bird)
						end
					else
						local topB = bird.y - bird.radius
						if bird.vy < 0 and topB <= bottomY + 1 and topB - bird.vy >= bottomY - 4 then
							bird.y = bottomY + bird.radius + 0.5
							bird.vy = -bird.vy
							world:fx("bounceBlimp", bird)
						end
					end
				end
			end
		end,
	},
}
