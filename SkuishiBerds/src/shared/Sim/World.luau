--[[
	World: one arena's simulation state, stepped at a fixed 60 ticks/second.

	The same module runs on the server (authoritative: spikes, events, bots,
	scoring) and on every client (renders everything, simulates only its own
	bird(s) for instant controls). Authority-dependent side effects go through
	world.hooks so the sim itself stays network-agnostic.

	hooks (all optional):
	  onFlap(world, bird)
	  onWallBounce(world, bird)
	  onCross(world, bird, lineX, y)            -- a simulated bird strummed a line
	  onHit(world, bird, cause, info)            -- a simulated bird touched something harmful
	  onSpikeBroken(world, spike, bird, reason) -- peck / egg broke a spike (server decides)
	  onEntity(world, ev, entityId, action, bird) -- pickups / destructibles / event interactions
	  onFx(world, kind, data)                    -- purely visual/audio effects (client)
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Modes = require(script.Parent.Parent.Config.Modes)
local Rng = require(script.Parent.Rng)
local Spikes = require(script.Parent.Spikes)
local BirdState = require(script.Parent.BirdState)

local World = {}
World.__index = World

export type World = typeof(setmetatable(
	{} :: {
		mode: Modes.ModeDef,
		seed: number,
		tick: number,
		startTick: number,
		speedMult: number,
		birds: { [number]: BirdState.Bird },
		birdList: { BirdState.Bird },
		spikes: { Spikes.Spike },
		spikeById: { [number]: Spikes.Spike },
		nextSpikeId: number,
		event: any?,
		upcoming: any?,
		eventSerial: number,
		testPhaseUntil: number,
		testPinX: { [number]: number },
		arenaStrums: number,
		score: number,
		isServer: boolean,
		hooks: { [string]: any },
		fxRng: any,
		flip: { progress: number, active: boolean, doneTick: number },
		suddenDeath: boolean,
		paused: boolean,
	},
	World
))

function World.new(opts: { [string]: any })
	local self = setmetatable({}, World)
	self.mode = opts.mode or Modes.SOLO
	self.seed = opts.seed or 1
	self.tick = 0
	self.startTick = opts.startTick or 0
	self.speedMult = 1
	self.birds = {}
	self.birdList = {}
	self.spikes = {}
	self.spikeById = {}
	self.nextSpikeId = 1
	self.event = nil
	self.upcoming = nil
	self.eventSerial = 0
	self.testPhaseUntil = -1
	self.testPinX = {}
	self.arenaStrums = 0
	self.score = 0
	self.isServer = opts.isServer == true
	self.hooks = opts.hooks or {}
	self.fxRng = Rng.new(Rng.hash(self.seed, 777))
	self.flip = { progress = 0, active = false, doneTick = -1 }
	self.suddenDeath = false
	self.paused = false
	return self
end

-- Birds ----------------------------------------------------------------------

function World:addBird(bird: BirdState.Bird)
	self.birds[bird.slot] = bird
	table.insert(self.birdList, bird)
	table.sort(self.birdList, function(a, b)
		return a.slot < b.slot
	end)
end

function World:removeBird(slot: number)
	local bird = self.birds[slot]
	if not bird then
		return
	end
	self.birds[slot] = nil
	local idx = table.find(self.birdList, bird)
	if idx then
		table.remove(self.birdList, idx)
	end
end

function World:aliveBirds(): { BirdState.Bird }
	local out = {}
	for _, b in self.birdList do
		if not b.dead then
			table.insert(out, b)
		end
	end
	return out
end

-- The partner used for mirrored respawns: the other bird of a 2-bird co-op/duel,
-- or a living teammate.
function World:partnerOf(bird: BirdState.Bird): BirdState.Bird?
	if #self.birdList == 2 then
		for _, b in self.birdList do
			if b ~= bird and not b.dead then
				return b
			end
		end
		return nil
	end
	for _, b in self.birdList do
		if b ~= bird and b.team == bird.team and not b.dead then
			return b
		end
	end
	return nil
end

-- Spikes ---------------------------------------------------------------------

function World:addSpike(spike: Spikes.Spike)
	if self.spikeById[spike.id] then
		-- replace (update)
		local old = self.spikeById[spike.id]
		local idx = table.find(self.spikes, old)
		if idx then
			self.spikes[idx] = spike
		end
		self.spikeById[spike.id] = spike
		return
	end
	table.insert(self.spikes, spike)
	self.spikeById[spike.id] = spike
	if spike.id >= self.nextSpikeId then
		self.nextSpikeId = spike.id + 1
	end
end

function World:removeSpike(id: number)
	local s = self.spikeById[id]
	if not s then
		return
	end
	self.spikeById[id] = nil
	local idx = table.find(self.spikes, s)
	if idx then
		table.remove(self.spikes, idx)
	end
end

function World:clearSpikes()
	table.clear(self.spikes)
	table.clear(self.spikeById)
end

function World:newSpikeId(): number
	local id = self.nextSpikeId
	self.nextSpikeId += 1
	return id
end

-- Events ---------------------------------------------------------------------

function World:eventActive(): any?
	local ev = self.event
	if ev and not ev.ended and self.tick >= ev.startTick then
		return ev
	end
	return nil
end

function World:eventName(): string?
	local ev = self:eventActive()
	return ev and ev.name
end

-- Effects --------------------------------------------------------------------

function World:fx(kind: string, data: any?)
	local h = self.hooks.onFx
	if h then
		h(self, kind, data)
	end
end

function World:call(hookName: string, ...: any): any
	local h = self.hooks[hookName]
	if h then
		return h(self, ...)
	end
	return nil
end

-- Pin positions for the "TESTING POWERS" phase
function World:computeTestPins()
	table.clear(self.testPinX)
	local n = #self.birdList
	for i, b in self.birdList do
		local offset
		if n == 1 then
			offset = 0
		elseif n == 2 then
			offset = if i == 1 then -40 else 40
		else
			offset = (i - (n + 1) / 2) * 56
		end
		self.testPinX[b.slot] = GameConfig.MID_X + offset
	end
end

return World
