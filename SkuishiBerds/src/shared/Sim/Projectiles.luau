--[[
	Projectiles: eggs fired by birds holding BLASTERS (flap = shoot, max 5/s).

	Every machine flies every egg for visuals, but only the machine that
	simulates the shooter resolves hits (breaking spikes / meteors / aliens) and
	reports them; the server confirms for everyone.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Spikes = require(script.Parent.Spikes)

local W, H = GameConfig.W, GameConfig.H

local Projectiles = {}

Projectiles.FIRE_COOLDOWN = 12 -- 200 ms
Projectiles.LIFE = 72 -- 1.2 s
Projectiles.SPEED = 10
Projectiles.SIZE = 3

function Projectiles.spawn(world, bird, resolvesHits: boolean)
	world.bullets = world.bullets or {}
	local dir = bird.dir
	table.insert(world.bullets, {
		x = bird.x + dir * (bird.radius + 6),
		y = bird.y - bird.radius * 0.35 * (if bird.upside then -1 else 1),
		vx = dir * Projectiles.SPEED,
		owner = bird.slot,
		sim = resolvesHits,
		born = world.tick,
	})
	world:fx("shoot", bird)
end

-- Fire if the cooldown allows (called on flap for simulated birds)
function Projectiles.tryFire(world, bird): boolean
	if not bird.gun then
		return false
	end
	if world.tick - bird.lastShotTick < Projectiles.FIRE_COOLDOWN then
		return false
	end
	bird.lastShotTick = world.tick
	Projectiles.spawn(world, bird, true)
	return true
end

function Projectiles.step(world)
	local list = world.bullets
	if not list or #list == 0 then
		return
	end
	local ev = world:eventActive()
	for i = #list, 1, -1 do
		local b = list[i]
		b.x += b.vx
		local dead = b.x < -50 or b.x > W + 50 or b.y < -50 or b.y > H + 50 or world.tick - b.born > Projectiles.LIFE
		if not dead and b.sim then
			local shooter = world.birds[b.owner]
			-- spikes
			for _, s in world.spikes do
				if Spikes.isSolid(s, world.tick) then
					local dx = b.x - Spikes.tipX(s)
					local dy = b.y - Spikes.yAt(s, world.tick)
					local r = Projectiles.SIZE + s.size * 0.6
					if dx * dx + dy * dy < r * r then
						world:call("onSpikeBroken", s, shooter, "egg")
						world:fx("spikeShatter", s)
						dead = true
						break
					end
				end
			end
			-- event entities (meteors, aliens, gears...)
			if not dead and ev and ev.def.shoot then
				local id = ev.def.shoot(world, ev, b.x, b.y, Projectiles.SIZE)
				if id then
					if not ev.removed[id] then
						ev.removed[id] = true
						world:call("onEntity", ev, id, "shot", shooter)
					end
					world:fx("eggHit", { x = b.x, y = b.y })
					dead = true
				end
			end
		end
		if dead then
			table.remove(list, i)
		end
	end
end

return Projectiles
