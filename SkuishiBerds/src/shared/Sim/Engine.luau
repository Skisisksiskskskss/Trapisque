--[[
	Engine: advances a World by one 60 Hz tick.

	  1. event lifecycle (begin at startTick, step, finish at endTick)
	  2. spike housekeeping (finished fades, Versus expiry)
	  3. eggs in flight
	  4. every bird simulated on THIS machine: physics, line crossings,
	     interactions, damage, pickups

	Remote birds are positioned by the network layer before each step.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Spikes = require(script.Parent.Spikes)
local Physics = require(script.Parent.Physics)
local Abilities = require(script.Parent.Abilities)
local Projectiles = require(script.Parent.Projectiles)
local Events = require(script.Parent.Events)

local W, MID = GameConfig.W, GameConfig.MID_X
local DEFAULT_LINES = { MID }

local Engine = {}

local function updateRadius(world, bird)
	bird.radius = bird.baseRadius * bird.sizeScale * Abilities.sizeScale(world, bird)
end

local function checkSpikes(world, bird): boolean
	if bird.ghost then
		return false
	end
	local tick = world.tick
	for _, s in world.spikes do
		if
			Spikes.hurtsTeam(s, bird.team)
			and Spikes.isHarmful(s, tick)
			and Spikes.touches(s, bird.x, bird.y, bird.radius, tick)
		then
			local guard = Abilities.spikeGuard(world, bird)
			if guard == "puff" then
				if tick - (bird.lastPuffTick or -100) > 10 then
					world:fx("puffBounce", bird)
				end
				bird.lastPuffTick = tick
				return false
			elseif guard == "peck" then
				bird.pecking = false
				bird.abilityUntil = tick
				world:fx("spikeShatter", s)
				world:call("onSpikeBroken", s, bird, "peck")
				world:removeSpike(s.id) -- predicted; server confirms for everyone
				return false
			end
			world:call("onHit", bird, "spike", s.id)
			return true
		end
	end
	return false
end

local function checkCrossings(world, bird, ev)
	if math.abs(bird.x - bird.prevX) >= W / 2 then
		return -- wrapped/teleported, not a real crossing
	end
	local lines = DEFAULT_LINES
	if ev and ev.def.lines then
		lines = ev.def.lines(world, ev) or DEFAULT_LINES
	end
	local tick = world.tick
	for i, lx in lines do
		if (bird.prevX < lx and bird.x >= lx) or (bird.prevX > lx and bird.x <= lx) then
			bird.lineCross = bird.lineCross or {}
			if #lines == 1 or tick - (bird.lineCross[i] or -1000) >= 18 then
				bird.lineCross[i] = tick
				bird.lastCrossTick = tick
				world:call("onCross", bird, lx, bird.y, i)
				if ev and ev.def.onCross then
					ev.def.onCross(world, ev, bird, lx, true)
				end
			end
		end
	end
end

function Engine.stepBird(world, bird)
	if bird.dead then
		return
	end
	local ev = world:eventActive()
	Abilities.tick(world, bird)
	updateRadius(world, bird)
	Physics.step(world, bird)
	checkCrossings(world, bird, ev)

	if ev and ev.def.touch then
		ev.def.touch(world, ev, bird)
	end

	local tick = world.tick
	if tick >= bird.invulnUntil and tick >= world.testPhaseUntil and not bird.dead then
		local hurt = checkSpikes(world, bird)
		if not hurt and ev and ev.def.hit and not Abilities.ignoresHazards(world, bird) then
			local cause, id = ev.def.hit(world, ev, bird)
			if cause then
				world:call("onHit", bird, cause, id)
			end
		end
	end

	if ev and ev.def.collect and not bird.dead then
		ev.def.collect(world, ev, bird)
	end
end

function Engine.step(world)
	world.tick += 1
	local tick = world.tick

	-- 1. events
	local ev = world.event
	if ev and not ev.ended then
		if not ev.started and tick >= ev.startTick then
			Events.begin(world, ev)
		end
		if ev.started then
			Events.step(world, ev)
			local timeUp = tick >= ev.endTick
			local selfDone = world.isServer and ev.meta.openEnded and ev.def.isDone and ev.def.isDone(world, ev)
			if timeUp or selfDone then
				Events.finish(world, ev)
				world:call("onEventFinished", ev)
			end
		end
	end

	-- 2. spikes: Versus lifetime + finished fades (deterministic on every machine)
	for i = #world.spikes, 1, -1 do
		local s = world.spikes[i]
		if s.expireTick and tick >= s.expireTick and not s.vanishStart and not world.suddenDeath then
			s.vanishStart = s.expireTick
		end
		if Spikes.isFinished(s, tick) then
			world.spikeById[s.id] = nil
			table.remove(world.spikes, i)
		end
	end

	-- 3. eggs
	Projectiles.step(world)

	-- 4. birds we simulate
	for _, bird in world.birdList do
		if bird.sim then
			Engine.stepBird(world, bird)
		end
	end
end

-- Start an event instance on this world (server: after announcing; client: on message)
function Engine.scheduleEvent(world, name: string, id: number, seed: number, startTick: number, params)
	if world.event and not world.event.ended then
		Events.finish(world, world.event)
	end
	world.event = Events.create(name, id, seed, startTick, params)
	return world.event
end

function Engine.endEvent(world, id: number)
	local ev = world.event
	if ev and ev.id == id and not ev.ended then
		Events.finish(world, ev)
	end
end

return Engine
