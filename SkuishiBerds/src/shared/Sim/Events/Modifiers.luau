--[[
	Modifier & screen events: physics tweaks and full-screen looks.
	(Visual-only events still exist here so they appear in the registry; their
	looks live in the client's EventViews.)
]]

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.Parent.MathUtil)
local EventUtil = require(script.Parent.Parent.EventUtil)

local W, H, MID = GameConfig.W, GameConfig.H, GameConfig.MID_X
local SPEED = GameConfig.SPEED

local function slotIn(list: { number }?, slot: number): boolean
	if not list then
		return false
	end
	return table.find(list, slot) ~= nil
end

return {
	{
		name = "SPEED_BOOST",
		mods = function(_w, _ev, _b, m)
			m.speed = 2
		end,
	},
	{
		name = "SLOW_MO",
		mods = function(_w, _ev, _b, m)
			m.speed = 0.5
		end,
	},
	{
		name = "GRAVITY_BOOST",
		mods = function(_w, _ev, _b, m)
			m.gravity *= 2
		end,
	},
	{
		name = "TURBULENCE",
		forces = function(world, _ev, bird, m)
			-- original: vy += sin(Date.now()/200 + x/100) * 0.3
			local turbulence = math.sin(EventUtil.ms(world.tick) / 200 + bird.x / 100) * 0.3
			bird.vy += turbulence * m.time
		end,
	},
	{ name = "RAINBOW_MODE" },
	{
		name = "TINY_MODE",
		applyBird = function(_w, _ev, bird)
			bird.sizeScale = 0.6
		end,
		clearBird = function(_w, _ev, bird)
			bird.sizeScale = 1
		end,
	},
	{
		name = "GIANT_MODE",
		applyBird = function(_w, _ev, bird)
			bird.sizeScale = 1.8
		end,
		clearBird = function(_w, _ev, bird)
			bird.sizeScale = 1
		end,
	},
	{
		-- params.big: slots that grow (x1.5); everyone else shrinks (x0.7)
		name = "SIZE_SWAP",
		applyBird = function(_w, ev, bird)
			bird.sizeScale = if slotIn(ev.params.big, bird.slot) then 1.5 else 0.7
		end,
		clearBird = function(_w, _ev, bird)
			bird.sizeScale = 1
		end,
	},
	{
		-- params.ghosts: the lucky bird(s) that phase through spikes
		name = "GHOST_MODE",
		applyBird = function(_w, ev, bird)
			bird.ghost = slotIn(ev.params.ghosts, bird.slot)
		end,
		clearBird = function(_w, _ev, bird)
			bird.ghost = false
		end,
	},
	{
		name = "GRAVITY_FLIP",
		applyBird = function(_w, _ev, bird)
			bird.upside = not bird.upside
			bird.vy = 0
		end,
	},
	{
		name = "MAGNET",
		forces = function(world, _ev, bird, m)
			local other, dist = EventUtil.nearestOther(world, bird)
			if other and dist > 0 then
				bird.vy += ((other.y - bird.y) / dist) * 0.3 * m.time
			end
		end,
	},
	{
		name = "SOLO_MAGNET",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.mag = {
				x = W / 2,
				y = H / 2,
				vx = rng:spread(4),
				vy = rng:spread(4),
				rot = 0,
				size = 40,
			}
		end,
		step = function(_w, ev)
			local mag = ev.s.mag
			if not mag then
				return
			end
			mag.x += mag.vx
			mag.y += mag.vy
			mag.rot += 0.05
			if mag.x < 50 or mag.x > W - 50 then
				mag.vx = -mag.vx
				mag.x = math.clamp(mag.x, 50, W - 50)
			end
			if mag.y < 50 or mag.y > H - 50 then
				mag.vy = -mag.vy
				mag.y = math.clamp(mag.y, 50, H - 50)
			end
		end,
		forces = function(_w, ev, bird, m)
			local mag = ev.s.mag
			if not mag then
				return
			end
			local dx, dy = mag.x - bird.x, mag.y - bird.y
			local dist = MathUtil.hypot(dx, dy)
			if dist > 0 then
				local pull = 0.4 * (1 - math.min(dist / 300, 1))
				bird.vy += (dy / dist) * pull * m.time
				bird.x += (dx / dist) * pull * 0.5 * m.time
			end
		end,
	},
	{
		name = "SHIELD",
		applyBird = function(_w, _ev, bird)
			bird.shielded = true
		end,
	},
	{
		-- bottom edge bounces everyone; top edge bounces too when two or more birds play
		name = "TRAMPOLINE",
		vertical = function(world, _ev, bird)
			local r = bird.radius
			if bird.y >= H - r then
				bird.vy = -math.abs(bird.vy)
				bird.y = H - r
				world:fx("trampoline", bird)
				return true
			end
			local topBounce = #world.birdList >= 2
			if topBounce then
				if bird.y <= r then
					bird.vy = math.abs(bird.vy)
					bird.y = r
					world:fx("trampoline", bird)
				end
				return true
			end
			if bird.y < -r then
				bird.y = H + r
				bird.lastWrapTick = world.tick
			end
			return true
		end,
	},
	{ name = "MIRROR_WORLD" },
	{
		name = "BUBBLE_BOUNCE",
		mods = function(_w, _ev, _b, m)
			m.gravity = 0.3
		end,
	},
	{
		name = "SPACE",
		mods = function(_w, _ev, _b, m)
			m.gravity = 0
			m.drag *= 0.98
		end,
	},
	{
		name = "BIG_WINGS",
		mods = function(_w, _ev, _b, m)
			m.flap *= 1.4
		end,
	},
	{
		name = "WALL_WRAP",
		walls = function(world, _ev, bird)
			local r = bird.radius
			if bird.x < -r then
				bird.x = W + r
				bird.prevX = bird.x
				bird.lastWrapTick = world.tick
			elseif bird.x > W + r then
				bird.x = -r
				bird.prevX = bird.x
				bird.lastWrapTick = world.tick
			end
			return false
		end,
	},
	{
		name = "COLOR_CHAOS",
		mods = function(world, _ev, _b, m)
			-- random gravity each tick; only affects birds simulated on this machine
			m.gravity = 0.5 + world.fxRng:next() * 1.5
			m.speed = 1.5
		end,
	},
	{ name = "DARKNESS" },
	{
		-- RETRO: collectible glitches worth +2
		name = "CRT_MODE",
		start = function(_w, ev)
			ev.s.glitches = {}
			ev.s.spawned = 0
		end,
		step = function(_w, ev)
			local rng = ev.rng
			if rng:chance(0.016) and ev.s.spawned < 10 then
				ev.s.spawned += 1
				table.insert(ev.s.glitches, {
					id = EventUtil.nextId(ev),
					x = rng:range(0, W),
					y = rng:range(0, H),
					vx = rng:spread(0.8),
					vy = rng:spread(0.8),
					size = rng:range(6, 14),
					hue = rng:int(0, 359),
					wobble = rng:range(0, math.pi * 2),
				})
			end
			for _, g in ev.s.glitches do
				g.wobble += 0.04
				g.x += g.vx + math.sin(g.wobble) * 0.2
				g.y += g.vy + math.cos(g.wobble * 0.9) * 0.15
				if g.x < -20 then
					g.x = W + 20
				elseif g.x > W + 20 then
					g.x = -20
				end
				if g.y < -20 then
					g.y = H + 20
				elseif g.y > H + 20 then
					g.y = -20
				end
			end
		end,
		collect = function(world, ev, bird)
			for _, g in ev.s.glitches or {} do
				if not ev.removed[g.id] and EventUtil.circleHit(bird, g.x, g.y, g.size * 0.6) then
					EventUtil.report(world, ev, g.id, "collect", bird)
				end
			end
		end,
	},
	{ name = "BINARY_MODE" },
	{ name = "GLITCH_MODE" },
	{ name = "KALEIDOSCOPE" },
	{
		-- params.pairs = {a1, b1, a2, b2, ...}: a takes b's place and vice versa
		name = "SWAP_POSITIONS",
		start = function(world, ev)
			local snap = {}
			for _, b in world.birdList do
				snap[b.slot] = { b.x, b.y, b.vy, b.dir }
			end
			ev.s.snap = snap
		end,
		applyBird = function(world, ev, bird)
			local pairs = ev.params.pairs or {}
			local partner
			for i = 1, #pairs - 1, 2 do
				if pairs[i] == bird.slot then
					partner = pairs[i + 1]
				elseif pairs[i + 1] == bird.slot then
					partner = pairs[i]
				end
			end
			local snap = partner and ev.s.snap[partner]
			if snap then
				bird.x, bird.y, bird.vy, bird.dir = snap[1], snap[2], snap[3], snap[4]
				bird.prevX = bird.x
				world:fx("swap", bird)
			end
		end,
	},
	{
		-- The page flips: after the animation the arena is mirrored (birds and spike sides)
		name = "REVERSE_CONTROLS",
		start = function(world, ev)
			world.flip.active = true
			world.flip.progress = 0
			world.flip.doneTick = -1
			ev.s.flipped = false
		end,
		step = function(world, ev)
			if ev.s.flipped then
				return
			end
			local t = EventUtil.t(world, ev)
			world.flip.progress = math.min(1, t * 0.08)
			if world.flip.progress >= 1 then
				ev.s.flipped = true
				world.flip.active = false
				world.flip.progress = 0
				world.flip.doneTick = world.tick
				for _, b in world.birdList do
					if b.sim then
						b.x = W - b.x
						b.prevX = b.x
						b.dir = -b.dir
					end
				end
				for _, s in world.spikes do
					s.side = -s.side
					s.zapFromX = W - s.zapFromX
				end
				world:fx("flipDone", nil)
			end
		end,
		stop = function(world, _ev)
			world.flip.active = false
			world.flip.progress = 0
		end,
	},
	{
		-- The middle line becomes a trampoline: no crossings, no spikes
		name = "BOUNCY",
		applyBird = function(_w, _ev, bird)
			bird.bouncy = true
		end,
		clearBird = function(_w, _ev, bird)
			bird.bouncy = false
		end,
		beforeHorizontal = function(world, _ev, bird, _m, speed)
			local nextX = bird.x + SPEED * bird.dir * speed * world.speedMult
			if (bird.x < MID and nextX >= MID) or (bird.x > MID and nextX <= MID) then
				local bendDir = bird.dir
				bird.dir = -bird.dir
				bird.x = MID + bird.dir * bird.radius
				bird.prevX = bird.x
				bird.vy *= -0.7
				world:fx("lineBend", { bird = bird, y = bird.y, dir = bendDir })
				return true
			end
			return false
		end,
	},
}
