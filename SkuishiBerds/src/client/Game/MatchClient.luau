--[[
	MatchClient: runs one match on this device.

	* simulates the bird(s) this player controls at a fixed 60 Hz, locked to the
	  server clock, so flaps are instant
	* streams those birds' state to the server (30 Hz) and reports strums, hits,
	  pickups and ability uses
	* renders everyone else ~115 ms in the past, interpolated between snapshots
	* applies server-authoritative results: spikes, events, score, lives
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Modes = require(Shared.Config.Modes)
local World = require(Shared.Sim.World)
local BirdState = require(Shared.Sim.BirdState)
local Spikes = require(Shared.Sim.Spikes)
local Engine = require(Shared.Sim.Engine)
local Events = require(Shared.Sim.Events)
local Physics = require(Shared.Sim.Physics)
local Abilities = require(Shared.Sim.Abilities)
local Projectiles = require(Shared.Sim.Projectiles)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Net = require(Client.Core.Net)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local ArenaView = require(Client.Render.ArenaView)

local W, H = GameConfig.W, GameConfig.H
local INTERP = GameConfig.INTERP_DELAY_TICKS -- starting delay before a bird's latency is measured
local EXTRAPOLATE_MAX = 4 -- ticks a remote bird may run past its newest state when data is late

local MatchClient = {}
MatchClient.__index = MatchClient

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

--[[
	info: MatchStart payload
	holder: frame the arena goes into
	opts: { settings }
]]
function MatchClient.new(info, holder: Instance, opts)
	local self = setmetatable({}, MatchClient)
	opts = opts or {}
	self.info = info
	self.id = info.id
	self.mode = Modes[info.mode]
	self.t0 = info.t0
	self.practice = info.practice == true
	self.localSlots = info.yourSlots or {}
	self.loadouts = {}
	self.snaps = {}
	-- per remote bird: adaptive interpolation delay (ticks), from how old its states are on arrival
	self.delay = {}
	self.ageMean = {}
	self.ageDev = {}
	self.prevPos = {}
	self.pendingInput = {}
	self.ended = false
	self.paused = false
	self.conns = {}
	self.lastSentTick = -1
	self.scoreValue = 0
	self.strums = {}
	self.charges = {}
	self.suddenDeath = false
	self.revive = nil
	self.Ended = Signal.new()
	self.Changed = Signal.new() -- HUD refresh hint
	self.settings = opts.settings or {}

	local world = World.new({
		mode = self.mode,
		seed = info.seed,
		isServer = false,
		hooks = self:makeHooks(),
	})
	self.world = world

	local couch = self.mode.couch or #self.localSlots >= 2
	self.couch = couch
	self.view = ArenaView.new(holder, { couch = couch, versus = self.mode.versus })
	self.view.showEventText = self.settings.eventText ~= false

	for _, b in info.birds do
		local isLocal = table.find(self.localSlots, b.slot) ~= nil
		local bird = BirdState.new(b.slot, {
			team = b.team,
			kind = b.kind,
			name = b.name,
			userId = b.userId,
			isBot = b.isBot,
			sim = isLocal,
			x = b.x,
			y = b.y,
			dir = b.dir,
			upside = b.upside,
			lives = b.lives,
		})
		world:addBird(bird)
		self.loadouts[b.slot] = b.loadout or {}
		local showName = (not isLocal) and (self.mode.online or b.isBot)
		self.view:addBird(bird, b.loadout or {}, {
			name = if showName then b.name else nil,
			seed = (b.userId % 9973) + b.slot,
		})
	end

	self.input = Input.new(couch)
	table.insert(
		self.conns,
		self.input.Flap:Connect(function(player, down)
			self:queueInput(player, if down then "flap" else "release")
		end)
	)
	table.insert(
		self.conns,
		self.input.Ability:Connect(function(player)
			self:queueInput(player, "ability")
		end)
	)

	self:listen()
	Audio.resetMelody()
	Audio.music("ingame_music")
	table.insert(
		self.conns,
		RunService.RenderStepped:Connect(function(dt)
			local ok, err = pcall(self.frame, self, dt)
			if not ok and not self.frameWarned then
				self.frameWarned = true
				warn("[MatchClient] frame error: " .. tostring(err))
			end
		end)
	)
	return self
end

function MatchClient:localBird(player: number)
	local slot = self.localSlots[player]
	return slot and self.world.birds[slot]
end

function MatchClient:queueInput(player: number, kind: string)
	-- in non-couch modes every input drives the single local bird
	if not self.couch then
		player = 1
	end
	table.insert(self.pendingInput, { player = player, kind = kind })
end

function MatchClient:applyInputs()
	local world = self.world
	for _, inp in self.pendingInput do
		local bird = self:localBird(inp.player)
		if bird and not bird.dead then
			if inp.kind == "flap" then
				Physics.flap(world, bird)
			elseif inp.kind == "release" then
				Physics.release(world, bird)
			elseif inp.kind == "ability" then
				if Abilities.activate(world, bird) then
					Net.send("Ability", self.id, bird.slot, world.tick)
				end
			end
		end
	end
	table.clear(self.pendingInput)
end

-- Hooks from the shared sim (only our own birds are simulated here) ---------------------

function MatchClient:makeHooks()
	return {
		onFlap = function(_world, bird)
			self.view:flapFx(bird)
			Audio.flap()
		end,
		onWallBounce = function(_world, bird)
			self.view:bounceFx(bird)
			Audio.bounce()
		end,
		onCross = function(world, bird, _lineX, y, lineIndex)
			self:strumFx(bird, y)
			Abilities.addCharge(bird, 1)
			Net.send("Strum", self.id, bird.slot, world.tick, y, lineIndex)
		end,
		onHit = function(world, bird, cause, id)
			local result = BirdState.applyHit(bird, world.tick, world:partnerOf(bird))
			self:damageFx(bird, result)
			Net.send("Hit", self.id, bird.slot, world.tick, cause, id, result)
		end,
		onEntity = function(_world, ev, entityId, action, bird)
			if bird then
				Net.send("Entity", self.id, ev.id, entityId, action, bird.slot)
				if action == "collect" then
					self.view.particles:burst(bird.x, bird.y, Color3.fromHSV(math.random(), 0.7, 1), 12)
					Audio.play("strum", 1 + math.random() * 0.06, 0.8)
				end
			end
		end,
		onSpikeBroken = function(_world, spike, bird, reason)
			if bird then
				Net.send("SpikeBreak", self.id, spike.id, bird.slot, reason)
			end
			Audio.play("glass", 1.1, 0.6)
		end,
		onHonk = function(_world, bird)
			self.view.particles:ring(bird.x, bird.y, Color3.fromHex("#fff5e1"), 24, 7, { decay = 0.04 })
			Audio.play("honk", 0.7, 1)
		end,
		onFx = function(world, kind, data)
			self:onFx(world, kind, data)
		end,
	}
end

function MatchClient:strumFx(bird, y: number)
	local bv = self.view.birdViews[bird.slot]
	local hue = if bird.upside then 200 else 160
	self.view:strumFx(y, hue, bv and bv.color)
	if bv then
		bv.strumBoost = 0.5
	end
	Audio.strum(bird.slot, bird.slot == 1 and #self.world.birdList == 2)
end

function MatchClient:damageFx(bird, result: string)
	if result == "dead" then
		local lo = self.loadouts[bird.slot] or {}
		self.view:deathFx(bird, lo.death, lo.hat)
		Audio.play("splat", 0.9 + math.random() * 0.2, 0.9)
	elseif result == "hurt" then
		self.view:hurtFx(bird)
		Audio.play("lose_life", 1 + math.random() * 0.1, 0.8)
	elseif result == "shield" then
		self.view.particles:burst(bird.x, bird.y, Color3.fromHex("#3498db"), 20)
		Audio.play("shield", 1, 0.8)
	end
end

local FX_SOUNDS = {
	trampoline = { "bounce", 0.5 },
	logBump = { "bounce", 0.95 },
	canopyBounce = { "bounce", 0.8 },
	bounceBlimp = { "bounce", 0.9 },
	chop = { "bounce", 1.2 },
	meteor = { "comet", 1 },
	thunder = { "thunder", 0.98 },
	beamFire = { "zap", 0.8 },
	photonPulse = { "zap", 0.98 },
	photonHit = { "zap", 1 },
	train = { "train_pass", 0.95 },
	snowHit = { "zap", 1.1 },
	frozen = { "zap", 0.95 },
	echoHit = { "zap", 1.2 },
	neonHit = { "zap", 1 },
	teleport = { "ambient_wormhole", 1 },
	wormhole = { "ambient_wormhole", 1 },
	shoot = { "gun_fire", 1 },
	eggHit = { "pop", 1.2 },
	spikeShatter = { "glass", 1 },
	puffBounce = { "bounce", 0.6 },
	gravityShoeFlip = { "strum", 0.85 },
	timberCreak = { "strum", 0.5 },
	timberLand = { "thunder", 1 },
	drillFilled = { "splat", 1 },
	shieldPop = { "shield", 0.95 },
}

function MatchClient:onFx(world, kind: string, data)
	local view = self.view
	if kind == "eventStart" then
		local meta = data.meta
		if meta.cue then
			Audio.play(meta.cue, meta.cueRate or 1, 0.9)
		end
		Audio.ambient(meta.ambient, meta.ambientVolume)
		return
	elseif kind == "eventEnd" then
		Audio.ambient(nil)
		return
	elseif kind == "lineBend" then
		view:addBend(data.y, data.dir)
		Audio.strum(data.bird.slot)
		return
	elseif kind == "swap" then
		view.particles:burst(data.x, data.y, Color3.fromHex("#a29bfe"), 20)
	elseif kind == "teleport" or kind == "wormhole" then
		view.particles:burst(data.x, data.y, Color3.fromHex("#8e44ad"), 18)
	elseif kind == "ability" then
		self:abilityFx(data.bird, data.kind)
		return
	elseif kind == "drillFilled" then
		view.shake = math.max(view.shake, 20)
		Audio.play("thunder", 0.95, 0.9)
	elseif kind == "timberLand" then
		view.shake = math.max(view.shake, 20)
		view.particles:burst(W / 2, H, Color3.fromHex("#8d6e63"), 40, { speed = 4 })
	elseif kind == "chop" then
		view.shake = math.max(view.shake, 5)
		view.particles:burst(data.x, data.y, Color3.fromHex("#795548"), 10)
	elseif kind == "canopyBounce" then
		view:squish(data.slot, 1.5, 0.6)
		view.particles:burst(data.x, data.y, Color3.fromHex("#4caf50"), 5)
	elseif kind == "bounceBlimp" or kind == "trampoline" then
		view:squish(data.slot, 0.6, 1.6)
		view.particles:burst(data.x, data.y, Color3.fromHex("#ffffff"), 8)
	elseif kind == "snowHit" or kind == "frozen" then
		view.particles:burst(data.x, data.y, Color3.fromHex("#88d9ff"), 12)
	elseif kind == "photonHit" then
		view.particles:burst(data.bird.x, data.bird.y, Color3.fromHSV((data.hue % 360) / 360, 0.75, 1), 18)
	elseif kind == "neonHit" or kind == "echoHit" then
		local b = data.bird or data
		view:squish(b.slot, 0.5, 0.5)
		view.particles:burst(b.x, b.y, Color3.fromHex("#ffffff"), 8)
	elseif kind == "spikeShatter" then
		view:shatterSpike(data, world.tick)
	elseif kind == "eggHit" then
		view.particles:burst(data.x, data.y, Color3.fromHex("#fff8e7"), 10)
	elseif kind == "puffBounce" then
		view:squish(data.slot, 0.7, 1.3)
	end
	local snd = FX_SOUNDS[kind]
	if snd then
		Audio.play(snd[1], snd[2], 0.8)
	end
end

function MatchClient:abilityFx(bird, kind: string)
	local view = self.view
	local bv = view.birdViews[bird.slot]
	local color = if bv then bv.color else Color3.new(1, 1, 1)
	if kind == "UTURN" then
		view:squish(bird.slot, 0.6, 1.4)
		view.particles:burst(bird.x, bird.y, color, 10)
		Audio.play("bounce", 1.3, 0.9)
	elseif kind == "DASH" then
		view.particles:burst(bird.x, bird.y, Color3.fromHex("#84fab0"), 14, { speed = 1, up = 0, vx = -bird.dir * 4 })
		Audio.play("flap", 1.6, 1)
	elseif kind == "BLINK" then
		view.particles:ring(bird.x, bird.y, Color3.fromHex("#c9b6e4"), 14, 3)
		Audio.play("zap", 1.4, 0.8)
	elseif kind == "PUFF" then
		view:squish(bird.slot, 1.5, 1.5)
		Audio.play("bounce", 0.6, 1)
	elseif kind == "PECK" then
		view.particles:burst(bird.x + bird.dir * 20, bird.y, Color3.fromHex("#e74c3c"), 8)
		Audio.play("strum", 1.5, 0.6)
	elseif kind == "FOCUS" then
		view.particles:ring(bird.x, bird.y, Color3.fromHex("#9b59b6"), 16, 2)
		Audio.play("ambient_portal", 1.3, 0.5)
	elseif kind == "FLIP" then
		view:squish(bird.slot, 1.4, 0.6)
		view.particles:burst(bird.x, bird.y, Color3.fromHex("#ff77ff"), 12)
		Audio.play("strum", 0.8, 0.8)
	elseif kind == "HONK" then
		view.particles:ring(bird.x, bird.y, Color3.fromHex("#fff5e1"), 24, 7, { decay = 0.04 })
		view.shake = math.max(view.shake, 6)
		Audio.play("honk", 0.7, 1)
	end
end

-- Network ---------------------------------------------------------------------------------

function MatchClient:listen()
	local world = self.world
	local function mine(fn)
		return function(...)
			if not self.ended then
				fn(...)
			end
		end
	end
	local function on(msg, fn)
		table.insert(self.conns, Net.on(msg, mine(fn)))
	end

	-- snapshot entries: { slot, sourceTick, ...BirdState.pack } where sourceTick is the
	-- tick the bird's owner recorded that state at, so motion is replayed on its own timeline
	Net.onFast(function(matchId, _tick, snap)
		if matchId ~= self.id or self.ended or type(snap) ~= "table" then
			return
		end
		local nowTick = (serverNow() - self.t0) * GameConfig.TICK_RATE
		for _, entry in snap do
			local slot, sourceTick = entry[1], entry[2]
			if type(sourceTick) == "number" and not table.find(self.localSlots, slot) then
				local list = self.snaps[slot]
				if not list then
					list = {}
					self.snaps[slot] = list
				end
				local last = list[#list]
				if not last or sourceTick > last.tick then
					table.insert(list, { tick = sourceTick, data = table.move(entry, 3, #entry, 1, {}) })
					if #list > 40 then
						table.remove(list, 1)
					end
					-- how old states are when they reach us (network both ways + relay)
					local age = nowTick - sourceTick
					local mean = self.ageMean[slot]
					if not mean then
						self.ageMean[slot] = age
						self.ageDev[slot] = 1
					else
						self.ageMean[slot] = mean + (age - mean) * 0.08
						self.ageDev[slot] += (math.abs(age - mean) - self.ageDev[slot]) * 0.08
					end
				end
			end
		end
	end)

	on("Event", function(id, name, seed, startTick, params)
		Engine.scheduleEvent(world, name, id, seed, startTick, params or {})
	end)
	on("EventEnd", function(id)
		Engine.endEvent(world, id)
	end)
	on("EventEntity", function(eventId, entityId, action, slot)
		local ev = world.event
		if ev and ev.id == eventId then
			ev.removed[entityId] = true
			local bird = world.birds[slot]
			if bird and not bird.sim and action == "collect" then
				self.view.particles:burst(bird.x, bird.y, Color3.fromHSV(math.random(), 0.7, 1), 10)
			end
		end
	end)
	on("EventSignal", function(eventId, key, value)
		local ev = world.event
		if ev and ev.id == eventId then
			Events.signal(world, ev, key, value)
		end
	end)
	on("SpikeAdd", function(packed)
		world:addSpike(Spikes.unpack(packed))
	end)
	on("SpikeSync", function(list)
		world:clearSpikes()
		for _, packed in list do
			world:addSpike(Spikes.unpack(packed))
		end
	end)
	on("SpikeRemove", function(ids)
		for _, id in ids do
			local s = world.spikeById[id]
			if s then
				self.view:shatterSpike(s, world.tick)
			end
			world:removeSpike(id)
		end
	end)
	on("Strum", function(slot, _tick, y, lineIndex)
		local bird = world.birds[slot]
		if bird and not bird.sim then
			self:strumFx(bird, y)
			local ev = world:eventActive()
			if ev and ev.def.onCross then
				local lines = if ev.def.lines then ev.def.lines(world, ev) else { W / 2 }
				ev.def.onCross(world, ev, bird, lines[lineIndex or 1] or W / 2, false)
			end
		end
	end)
	on("Score", function(score, speedMult, strums, charges)
		world.score = score
		world.speedMult = speedMult
		self.scoreValue = score
		for slot, n in strums do
			local b = world.birds[tonumber(slot) or slot]
			if b then
				b.strums = n
			end
		end
		for slot, c in charges do
			local b = world.birds[tonumber(slot) or slot]
			if b and not b.sim then
				b.charge = c
			end
		end
		self.Changed:Fire()
	end)
	on("Damage", function(slot, lives, tick, _cause, result, x, y, dir, forced)
		local bird = world.birds[slot]
		if not bird then
			return
		end
		if bird.sim then
			if forced and not bird.dead then
				-- the server caught a hit we missed: apply it like we would have
				bird.lives = lives
				if result == "dead" then
					bird.dead = true
					bird.deadTick = world.tick
				else
					BirdState.placeAt(bird, x, y, dir)
					bird.invulnUntil = world.tick + GameConfig.INVULN_TICKS
					BirdState.clearItems(bird)
				end
				self:damageFx(bird, result)
			else
				bird.lives = lives
				if result == "dead" and not bird.dead then
					bird.dead = true
					bird.deadTick = world.tick
					self:damageFx(bird, "dead")
				end
			end
		else
			local wasDead = bird.dead
			bird.lives = lives
			bird.invulnUntil = tick + (if result == "shield" then 30 else GameConfig.INVULN_TICKS)
			if result == "dead" then
				bird.dead = true
				if not wasDead then
					self:damageFx(bird, "dead")
				end
			else
				self:damageFx(bird, result)
			end
		end
		self.Changed:Fire()
	end)
	on("Ability", function(slot, tick, kind)
		local bird = world.birds[slot]
		if bird and not bird.sim then
			bird.abilityUntil = tick + (Abilities.DURATION[kind] or 10)
			self:abilityFx(bird, kind)
		end
	end)
	on("Knock", function(matchId, slot, dx, dvy, dazedUntil)
		if matchId ~= self.id then
			return
		end
		local bird = world.birds[slot]
		if bird and bird.sim and not bird.dead then
			bird.x = math.clamp(bird.x + dx, bird.radius, W - bird.radius)
			bird.vy += dvy
			bird.dazedUntil = dazedUntil
			self.view:squish(slot, 0.5, 1.4)
			Audio.play("honk", 0.8, 0.7)
		end
	end)
	on("ReviveOffer", function(deadline)
		self.paused = true
		self.revive = { deadline = deadline }
		self.Changed:Fire()
	end)
	on("Revived", function(t0, birds)
		self.t0 = t0
		self.paused = false
		self.revive = nil
		world:clearSpikes()
		for _, b in birds do
			local bird = world.birds[b.slot]
			if bird then
				bird.dead = false
				bird.lives = b.lives
				BirdState.placeAt(bird, b.x, b.y, b.dir)
				bird.invulnUntil = world.tick + 180
				self.view.particles:burst(b.x, b.y, Color3.fromHex("#ffd700"), 30)
			end
		end
		Audio.play("ui_win", 1.2, 0.7)
		self.Changed:Fire()
	end)
	on("SuddenDeath", function()
		world.suddenDeath = true
		self.suddenDeath = true
		self.Changed:Fire()
	end)
	on("MatchEnd", function(matchId, summary)
		if matchId == self.id then
			self:finish(summary)
		end
	end)
end

-- Remote birds ------------------------------------------------------------------------------

local function sampleSnap(list, t: number)
	if not list or #list == 0 then
		return nil
	end
	if t <= list[1].tick then
		return list[1].data, nil, 0
	end
	local n = #list
	local newest = list[n]
	if t >= newest.tick then
		-- data is late: keep the bird moving along its last motion for a moment
		local prev = list[n - 1]
		if prev and t - newest.tick <= EXTRAPOLATE_MAX then
			return prev.data, newest.data, (t - prev.tick) / math.max(1, newest.tick - prev.tick)
		end
		return newest.data, nil, 0
	end
	for i = n - 1, 1, -1 do
		local a = list[i]
		if a.tick <= t then
			local b = list[i + 1]
			return a.data, b.data, (t - a.tick) / math.max(1, b.tick - a.tick)
		end
	end
	return newest.data, nil, 0
end

-- Interpolation delay for a remote bird: enough to stay behind its newest state
-- (arrival age + jitter + the gap until the next state), eased so time never jumps.
function MatchClient:updateDelays(frames: number)
	for slot, mean in self.ageMean do
		local target = math.clamp(mean + 2 * (self.ageDev[slot] or 1) + 4, 3, 30)
		local cur = self.delay[slot] or INTERP
		if math.abs(target - cur) > 8 then
			cur = target
		else
			local step = 0.04 * frames
			cur += math.clamp(target - cur, -step, step)
		end
		self.delay[slot] = cur
	end
end

function MatchClient:delayOf(slot: number): number
	return self.delay[slot] or INTERP
end

-- returns x, y for a remote bird at (fractional) tick t, updating the bird's other state
function MatchClient:remoteAt(bird, t: number): (number, number)
	local a, b, k = sampleSnap(self.snaps[bird.slot], t)
	if not a then
		return bird.x, bird.y
	end
	local flaps = bird.flapCount
	local dirBefore = bird.dir
	BirdState.unpackInto(bird, a)
	local x, y = a[1], a[2]
	if b then
		local bx, by = b[1], b[2]
		if math.abs(bx - x) < W / 2 and math.abs(by - y) < H / 2 then
			x += (bx - x) * k
			y += (by - y) * k
		end
	end
	if bird.flapCount > flaps then
		self.view:flapFx(bird)
		if bird.gun then
			Projectiles.spawn(self.world, bird, false)
		end
	end
	if bird.dir ~= dirBefore and (x < 60 or x > W - 60) then
		self.view:bounceFx(bird)
	end
	return x, y
end

-- t: the tick being simulated; each remote bird is placed at its own delayed time
function MatchClient:positionRemoteBirds(t: number)
	for _, bird in self.world.birdList do
		if not bird.sim and not bird.dead then
			local x, y = self:remoteAt(bird, t - self:delayOf(bird.slot))
			bird.x, bird.y = x, y
		end
	end
end

-- Frame -------------------------------------------------------------------------------------

function MatchClient:sendState()
	local states = {}
	for _, slot in self.localSlots do
		local bird = self.world.birds[slot]
		if bird and not bird.dead then
			local packed = BirdState.pack(bird)
			table.insert(packed, 1, slot)
			table.insert(states, packed)
		end
	end
	if #states > 0 then
		Net.sendFast(self.id, self.world.tick, states)
	end
end

function MatchClient:frame(dt: number)
	if self.ended then
		return
	end
	local world = self.world
	local now = os.clock()
	local exact = (serverNow() - self.t0) * GameConfig.TICK_RATE
	local target = math.floor(exact)
	local frames = math.clamp(dt * 60, 0, 4)

	if self.paused then
		self.view:render(world, {}, now, 0)
		return
	end

	if target < 0 then
		-- countdown
		local secs = math.ceil(-exact / 60)
		self.view:setCenter(tostring(secs), if self.practice then "EVENT LAB" else self.mode.name)
		if secs ~= self.lastCount then
			self.lastCount = secs
			Audio.play("ui_countdown", 1, 0.8)
		end
		table.clear(self.pendingInput)
		self.view:setScore("", false) -- the countdown owns the middle of the screen
		self.view:render(world, {}, now, frames)
		return
	elseif self.lastCount then
		self.lastCount = nil
		self.view:setCenter("GO!", nil)
		task.delay(0.6, function()
			if not self.ended then
				self.view:setCenter("", nil)
			end
		end)
	end

	if target - world.tick > 30 then
		world.tick = target - 1 -- long hitch: skip ahead
	end
	local steps = 0
	while world.tick < target and steps < 8 do
		self:applyInputs()
		self:positionRemoteBirds(world.tick + 1)
		for _, slot in self.localSlots do
			local b = world.birds[slot]
			if b then
				self.prevPos[slot] = { b.x, b.y }
			end
		end
		Engine.step(world)
		steps += 1
		if world.tick - self.lastSentTick >= GameConfig.CLIENT_STATE_EVERY then
			self.lastSentTick = world.tick
			self:sendState()
		end
	end

	-- render positions: local birds interpolated between ticks, remote birds in the past
	self:updateDelays(frames)
	local alpha = math.clamp(exact - world.tick, 0, 1)
	local positions = {}
	for _, bird in world.birdList do
		if bird.sim then
			local p = self.prevPos[bird.slot]
			if p and math.abs(p[1] - bird.x) < 40 and math.abs(p[2] - bird.y) < 40 then
				positions[bird.slot] = { p[1] + (bird.x - p[1]) * alpha, p[2] + (bird.y - p[2]) * alpha }
			end
		elseif not bird.dead then
			local x, y = self:remoteAt(bird, exact - self:delayOf(bird.slot))
			positions[bird.slot] = { x, y }
		end
	end

	local twin = self.couch and self.mode.scoring == "coop"
	if self.mode.versus then
		self.view:setScore("", false)
	else
		self.view:setScore(tostring(world.score), twin)
	end
	self.view:render(world, positions, now, frames)
end

-- End -----------------------------------------------------------------------------------------

function MatchClient:requestRevive()
	Net.send("Revive", self.id)
end

function MatchClient:leave()
	Net.send("Leave")
	self:finish(nil)
end

function MatchClient:finish(summary)
	if self.ended then
		return
	end
	self.ended = true
	Audio.ambient(nil)
	for _, c in self.conns do
		c:Disconnect()
	end
	Net.onFast(nil)
	self.input:destroy()
	self.Ended:Fire(summary)
end

function MatchClient:destroy()
	if not self.ended then
		self:finish(nil)
	end
	self.view:destroy()
end

return MatchClient
