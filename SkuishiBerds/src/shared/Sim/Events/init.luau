--[[
	Event framework + registry.

	An event instance is created from (name, seed, startTick, params). Because
	every hazard is generated from ev.rng (seeded) and advanced one tick at a
	time, the server and every client run the exact same hazards without
	streaming them. Things birds change (picking up a shard, breaking a meteor,
	chopping the tree) go through world hooks to the server, which confirms them
	for everyone via ev.removed / ev.s overrides.

	Behaviour hooks a definition may provide (all optional):
	  start(world, ev)                    init ev.s using ev.rng (all machines)
	  serverStart(world, ev)              server-only (spike transforms)
	  applyBird(world, ev, bird)          start effect on each simulated bird
	  step(world, ev)                     advance hazards one tick (all machines)
	  stop(world, ev) / serverStop(world, ev)
	  clearBird(world, ev, bird)          end effect on each simulated bird
	  isDone(world, ev) -> bool           open-ended events (server decides)
	  mods(world, ev, bird, m)            physics multipliers
	  forces(world, ev, bird, m)          per-tick forces
	  afterVertical(world, ev, bird, m)   -> horizontal carry
	  beforeHorizontal(world, ev, bird, m, speed) -> true to skip the rest of the tick
	  walls(world, ev, bird) -> hitWall   replaces wall bounce
	  vertical(world, ev, bird) -> true   replaces vertical wrap
	  onFlap(world, ev, bird)
	  lines(world, ev) -> {x}             middle line(s) that count as strums
	  onCross(world, ev, bird, lineX, ownBird)
	  hit(world, ev, bird) -> cause, id   damaging collisions
	  touch(world, ev, bird)              non-damaging interactions
	  collect(world, ev, bird)            pickups (calls world hook)
	  shoot(world, ev, x, y, r) -> id?    egg hit test against event entities
	  honk(world, ev, x, y, r) -> {ids}   honk shockwave hit test
	  signal(world, ev, key, value)       authoritative state update from server
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local EventMeta = require(script.Parent.Parent.Config.Events)
local Rng = require(script.Parent.Rng)

local Events = {}
Events.defs = {} :: { [string]: any }

local GROUPS = {
	script.Modifiers,
	script.Items,
	script.SpikeEvents,
	script.Lines,
	script.Hazards,
	script.Scenes,
}

for _, mod in GROUPS do
	local list = require(mod)
	for _, def in list do
		local meta = EventMeta.ByName[def.name]
		if not meta then
			warn("[Events] no metadata for " .. tostring(def.name))
			continue
		end
		def.meta = meta
		Events.defs[def.name] = def
	end
end

for _, meta in EventMeta.List do
	if not Events.defs[meta.name] then
		-- every listed event must have a definition; fall back to a no-op so a
		-- missing behaviour never breaks a match
		warn("[Events] missing behaviour for " .. meta.name)
		Events.defs[meta.name] = { name = meta.name, meta = meta }
	end
end

export type EventInstance = {
	def: any,
	meta: any,
	name: string,
	id: number,
	seed: number,
	rng: any,
	startTick: number,
	endTick: number,
	params: { [string]: any },
	s: { [string]: any },
	removed: { [number]: boolean },
	started: boolean,
	ended: boolean,
}

function Events.create(
	name: string,
	id: number,
	seed: number,
	startTick: number,
	params: { [string]: any }?
): EventInstance
	local def = Events.defs[name]
	assert(def, "unknown event " .. tostring(name))
	local meta = def.meta
	return {
		def = def,
		meta = meta,
		name = name,
		id = id,
		seed = seed,
		rng = Rng.new(seed),
		startTick = startTick,
		endTick = startTick + (meta.duration or GameConfig.EVENT_DEFAULT_TICKS),
		params = params or {},
		s = {},
		removed = {},
		started = false,
		ended = false,
	}
end

-- ticks since the event started
function Events.t(world, ev): number
	return world.tick - ev.startTick
end

function Events.begin(world, ev: EventInstance)
	if ev.started then
		return
	end
	ev.started = true
	local def = ev.def
	if ev.meta.testPhase then
		world.testPhaseUntil = ev.startTick + GameConfig.TEST_PHASE_TICKS
		world:computeTestPins()
		for _, b in world.birdList do
			if b.sim then
				b.vy = 0
			end
		end
	end
	if def.start then
		def.start(world, ev)
	end
	if world.isServer and def.serverStart then
		def.serverStart(world, ev)
	end
	if def.applyBird then
		for _, b in world.birdList do
			if b.sim and not b.dead then
				def.applyBird(world, ev, b)
			end
		end
	end
	world:fx("eventStart", ev)
end

function Events.step(world, ev: EventInstance)
	if ev.def.step then
		ev.def.step(world, ev)
	end
end

function Events.finish(world, ev: EventInstance)
	if ev.ended then
		return
	end
	ev.ended = true
	local def = ev.def
	if ev.started then
		if def.stop then
			def.stop(world, ev)
		end
		if world.isServer and def.serverStop then
			def.serverStop(world, ev)
		end
		if def.clearBird then
			for _, b in world.birdList do
				if b.sim then
					def.clearBird(world, ev, b)
				end
			end
		end
	end
	world:fx("eventEnd", ev)
end

-- Mark an entity removed (pickup taken / hazard destroyed). Idempotent.
function Events.remove(ev: EventInstance, entityId: number)
	ev.removed[entityId] = true
end

function Events.isRemoved(ev: EventInstance, entityId: number): boolean
	return ev.removed[entityId] == true
end

-- Authoritative state update from the server (e.g. TIMBER chop progress)
function Events.signal(world, ev: EventInstance, key: string, value: any)
	if ev.def.signal then
		ev.def.signal(world, ev, key, value)
	else
		ev.s[key] = value
	end
end

return Events
