--[[
	Match: one running arena on the server.

	Authority split
	  * each client simulates its own bird(s) (instant controls) and streams
	    their state; it reports strums / hits / pickups / ability uses
	  * the server owns everything shared: spikes, events, scoring, lives,
	    bots, results. It validates reports and broadcasts the outcome.

	Time: tick = floor((serverTime - t0) * 60). Clients use the same clock
	(workspace:GetServerTimeNow()), so ticks line up everywhere.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local Modes = require(Shared.Config.Modes)
local EventMeta = require(Shared.Config.Events)
local Birds = require(Shared.Config.Birds)
local Rng = require(Shared.Sim.Rng)
local World = require(Shared.Sim.World)
local BirdState = require(Shared.Sim.BirdState)
local Spikes = require(Shared.Sim.Spikes)
local Engine = require(Shared.Sim.Engine)
local Physics = require(Shared.Sim.Physics)
local Abilities = require(Shared.Sim.Abilities)
local Bot = require(Shared.Sim.Bot)

local W, H, MID = GameConfig.W, GameConfig.H, GameConfig.MID_X

local Match = {}
Match.__index = Match

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

--[[
	entries: { { player: Player?, couch: boolean?, bot: boolean?, skill: number?, loadouts: {loadout}?, name: string? } }
	opts:    { labEvent: string? }
]]
function Match.new(service, id: number, modeId: string, entries, opts)
	local self = setmetatable({}, Match)
	self.service = service
	self.id = id
	self.mode = Modes[modeId]
	self.opts = opts or {}
	self.seed = Rng.hash(id, os.time(), math.random(1, 1e6))
	self.rng = Rng.new(self.seed)
	self.state = "countdown"
	self.players = {} -- [Player] = { slots = {number} }
	self.slotOwner = {} -- [slot] = Player
	self.brains = {} -- [slot] = Bot brain
	self.lastState = {} -- [slot] = { tick, data }
	self.lastHitTick = {} -- [slot] = tick of last applied damage
	self.pendingForced = {} -- [slot] = tick a spike touch was seen
	self.lastStrumTick = {} -- [slot] = tick
	self.coins = {} -- [Player] = coins earned this match
	self.eliminated = {} -- team ids in elimination order
	self.revived = false
	self.serial = 0
	self.lastSnapshot = -1
	self.practice = self.opts.labEvent ~= nil

	local world = World.new({
		mode = self.mode,
		seed = self.seed,
		isServer = true,
		hooks = self:makeHooks(),
	})
	self.world = world

	self:createBirds(entries)

	local countdown = GameConfig.COUNTDOWN_TICKS / GameConfig.TICK_RATE
	self.t0 = serverNow() + countdown
	self.nextEventTick = if self.practice then 20 else GameConfig.EVENT_FIRST_DELAY
	return self
end

-- Birds ----------------------------------------------------------------------

local function spawnLayout(count: number)
	-- returns list of { x, y, dir, upside }
	if count == 1 then
		return { { W * 0.25, H * 0.75, 1, false } }
	end
	if count == 2 then
		-- original layout: top bird (upside-down) starts top-right flying left,
		-- bottom bird starts bottom-left flying right
		return {
			{ W * 0.75, H * 0.25, -1, true },
			{ W * 0.25, H * 0.75, 1, false },
		}
	end
	local out = {}
	for i = 1, count do
		local t = (i - 1) / (count - 1)
		local x = W * (0.12 + 0.76 * t)
		local upside = i % 2 == 1
		local y = if upside then H * (0.22 + 0.1 * (i % 3)) else H * (0.78 - 0.1 * (i % 3))
		local dir = if x < MID then 1 else -1
		table.insert(out, { x, y, dir, upside })
	end
	return out
end

function Match:createBirds(entries)
	local birdsToMake = {}
	for _, e in entries do
		local nBirds = if e.couch then 2 else 1
		local team = nil
		for k = 1, nBirds do
			table.insert(birdsToMake, { entry = e, index = k, teamOf = team })
			team = team or true
		end
	end

	local layout = spawnLayout(#birdsToMake)
	local lives = self.mode.lives
	local teamBySlotEntry = {}

	for slot, info in birdsToMake do
		local e = info.entry
		local pos = layout[slot]
		local loadout = (e.loadouts and e.loadouts[info.index]) or {}
		local team
		if self.mode.versus then
			team = teamBySlotEntry[e] or slot
			teamBySlotEntry[e] = team
		else
			team = 1
		end
		local name = if e.player then e.player.DisplayName else (e.name or "Bot")
		if e.couch then
			name ..= if info.index == 1 then " (P1)" else " (P2)"
		end
		local bird = BirdState.new(slot, {
			team = team,
			kind = Birds.get(loadout.bird).id,
			name = name,
			userId = if e.player then e.player.UserId else 0,
			isBot = e.bot == true,
			sim = e.bot == true, -- server simulates bots only
			x = pos[1],
			y = pos[2],
			dir = pos[3],
			upside = pos[4],
			lives = lives,
		})
		bird.loadout = loadout
		self.world:addBird(bird)
		if e.player then
			self.slotOwner[slot] = e.player
			local pinfo = self.players[e.player]
			if not pinfo then
				pinfo = { slots = {}, couch = e.couch == true }
				self.players[e.player] = pinfo
				self.coins[e.player] = 0
			end
			table.insert(pinfo.slots, slot)
		elseif e.bot then
			self.brains[slot] = Bot.newBrain(e.skill or 0.8, Rng.new(Rng.hash(self.seed, slot)))
		end
	end
end

function Match:birdInfo()
	local out = {}
	for _, b in self.world.birdList do
		table.insert(out, {
			slot = b.slot,
			team = b.team,
			kind = b.kind,
			name = b.name,
			userId = b.userId,
			isBot = b.isBot,
			upside = b.upside,
			x = b.x,
			y = b.y,
			dir = b.dir,
			lives = b.lives,
			loadout = b.loadout,
		})
	end
	return out
end

-- Messaging ------------------------------------------------------------------

function Match:send(player: Player, msg: string, ...)
	self.service.sendTo(player, msg, ...)
end

function Match:broadcast(msg: string, ...)
	for player in self.players do
		if player.Parent then
			self.service.sendTo(player, msg, ...)
		end
	end
end

function Match:start()
	for player, info in self.players do
		self:send(player, "MatchStart", {
			id = self.id,
			mode = self.mode.id,
			seed = self.seed,
			t0 = self.t0,
			birds = self:birdInfo(),
			yourSlots = info.slots,
			practice = self.practice,
		})
	end
end

-- Hooks the shared sim calls (only bots are simulated here) ---------------------

function Match:makeHooks()
	return {
		onCross = function(world, bird, lineX, y, lineIndex)
			if bird.isBot then
				self:onStrum(bird, world.tick, y, lineIndex, lineX)
			end
		end,
		onHit = function(world, bird, cause, id)
			if bird.isBot then
				self:applyHit(bird, world.tick, cause, id, nil)
			end
		end,
		onEntity = function(_world, ev, entityId, action, bird)
			if bird and bird.isBot then
				self:applyEntity(ev, entityId, action, bird)
			end
		end,
		onSpikeBroken = function(_world, spike, bird, _reason)
			if bird and bird.isBot then
				self:breakSpike(spike.id)
			end
		end,
		onSpikesChanged = function(_world)
			self:syncSpikes()
		end,
		onEventFinished = function(world, ev)
			self:broadcast("EventEnd", ev.id, world.tick)
			local gap = self.rng:range(GameConfig.EVENT_GAP_MIN, GameConfig.EVENT_GAP_MAX)
			gap = gap * self.mode.eventGapMult / math.max(1, world.speedMult)
			self.nextEventTick = world.tick + math.floor(gap)
		end,
		onHonk = function(_world, bird)
			if bird.isBot then
				self:resolveHonk(bird)
			end
		end,
	}
end

-- Spikes -------------------------------------------------------------------------

function Match:addSpike(side: number, y: number, tick: number, opts)
	local world = self.world
	opts = opts or {}
	opts.createdAtStrum = world.arenaStrums
	local spike = Spikes.new(world:newSpikeId(), side, y, tick, opts)
	if self.mode.versus then
		spike.expireTick = tick + GameConfig.VERSUS_SPIKE_LIFETIME
	end
	world:addSpike(spike)
	self:broadcast("SpikeAdd", Spikes.pack(spike))
	return spike
end

function Match:randomSpikeY(): number
	local s = GameConfig.SPIKE_SIZE
	return self.rng:range(s * 2, H - s * 2)
end

function Match:syncSpikes()
	local list = {}
	for _, s in self.world.spikes do
		table.insert(list, Spikes.pack(s))
	end
	self:broadcast("SpikeSync", list, self.world.tick)
end

function Match:breakSpike(id: number)
	if self.world.spikeById[id] then
		self.world:removeSpike(id)
		self:broadcast("SpikeRemove", { id })
	end
end

-- Original rule: in co-op/solo, spikes older than 20 score-strums fade away
function Match:ageSpikes()
	if self.mode.versus then
		return
	end
	local changed = false
	for _, s in self.world.spikes do
		if not s.vanishStart and self.world.arenaStrums - s.createdAtStrum > GameConfig.SPIKE_LIFETIME_STRUMS then
			s.vanishStart = self.world.tick
			changed = true
		end
	end
	if changed then
		self:syncSpikes()
	end
end

-- Strums / scoring ------------------------------------------------------------

function Match:awardAll(coins: number)
	for player in self.players do
		self.coins[player] = (self.coins[player] or 0) + coins
	end
end

function Match:addScore(amount: number)
	local world = self.world
	local before = world.score
	world.score += amount
	world.arenaStrums += amount
	-- original milestone payout: every 10 strums pays 10 * (milestone / 10)
	local m0, m1 = math.floor(before / 10), math.floor(world.score / 10)
	for m = m0 + 1, m1 do
		if not self.practice then
			self:awardAll(GameConfig.COINS_PER_10_STRUMS * m)
		end
	end
	self:ageSpikes()
end

function Match:onStrum(bird, tick: number, y: number, lineIndex: number, lineX: number?)
	local world = self.world
	if bird.dead then
		return
	end
	local ev = world:eventActive()
	bird.strums += 1
	Abilities.addCharge(bird, 1)
	self.lastStrumTick[bird.slot] = tick

	local splitLines = ev and ev.name == "LINE_SPLIT"
	local noSpikes = ev and ev.meta.noSpikes and not splitLines
	local rule = self.mode.spikeRule

	if not noSpikes then
		if rule == "bothWalls" then
			self:addSpike(-1, self:randomSpikeY(), tick)
			self:addSpike(1, self:randomSpikeY(), tick)
		elseif rule == "perBirdWall" then
			local side = if bird.slot == 1 then -1 else 1
			self:addSpike(side, self:randomSpikeY(), tick)
		elseif rule == "aimed" then
			local side = if bird.dir > 0 then 1 else -1
			local yy = math.clamp(y, GameConfig.SPIKE_SIZE * 2, H - GameConfig.SPIKE_SIZE * 2)
			self:addSpike(side, yy, tick, {
				owner = bird.slot,
				team = bird.team,
				zapFromX = lineX or MID,
				zapFromY = yy,
				zapTicks = GameConfig.VERSUS_ZAP_TICKS,
			})
		end
	end

	-- scoring
	local scoring = self.mode.scoring
	if scoring == "solo" or splitLines then
		self:addScore(1)
	elseif scoring == "coop" then
		bird.hasStrummed = true
		local all = true
		for _, b in world.birdList do
			if not b.dead and not b.hasStrummed then
				all = false
			end
		end
		if all then
			for _, b in world.birdList do
				b.hasStrummed = false
			end
			self:addScore(1)
		end
	end

	-- the arena speeds up (scaled so big Versus lobbies don't go ludicrous)
	local scale = 2 / math.max(2, #world.birdList)
	world.speedMult = math.min(GameConfig.MAX_SPEED_MULT, world.speedMult + GameConfig.SPEEDUP_PER_CROSSING * scale)

	self:broadcast("Strum", bird.slot, tick, y, lineIndex)
	self:sendScore()
end

function Match:sendScore()
	local strums = {}
	local charges = {}
	for _, b in self.world.birdList do
		strums[b.slot] = b.strums
		charges[b.slot] = b.charge
	end
	self:broadcast("Score", self.world.score, self.world.speedMult, strums, charges)
end

-- Damage ------------------------------------------------------------------------

function Match:applyHit(bird, tick: number, cause: string, _causeId: number?, claimed: string?)
	if bird.dead then
		return
	end
	local last = self.lastHitTick[bird.slot]
	if last and tick - last < GameConfig.INVULN_TICKS - 10 then
		return -- already took this hit (dedupe client report vs server detection)
	end
	local partner = self.world:partnerOf(bird)
	local result
	if claimed == "shield" then
		-- the owning client used its shield (no life lost)
		bird.shielded = false
		result = "shield"
		local x, y, dir = BirdState.respawnSpot(bird, partner)
		BirdState.placeAt(bird, x, y, dir)
	else
		-- bots may use a shield; client-reported hits already resolved shields locally
		result = BirdState.applyHit(bird, tick, partner, not bird.isBot)
		if result ~= "shield" then
			self.lastHitTick[bird.slot] = tick
		end
	end
	self.pendingForced[bird.slot] = nil
	-- forced = the server detected it; the owning client must apply the respawn itself
	local forced = claimed == nil and not bird.isBot
	self:broadcast("Damage", bird.slot, bird.lives, tick, cause, result, bird.x, bird.y, bird.dir, forced)
	if result == "dead" then
		self:onBirdDied(bird)
	end
end

function Match:onBirdDied(bird)
	local world = self.world
	if self.mode.versus then
		-- team eliminated?
		local teamAlive = false
		for _, b in world.birdList do
			if b.team == bird.team and not b.dead then
				teamAlive = true
			end
		end
		if not teamAlive and not table.find(self.eliminated, bird.team) then
			table.insert(self.eliminated, bird.team)
		end
	end
	local owner = self.slotOwner[bird.slot]
	if owner then
		self.service.recordDeath(owner)
	end
end

-- Server-side safety net: a client bird whose reported position sits on a
-- harmful spike, without the client reporting a hit within ~0.5 s, gets hit.
function Match:checkForcedHits()
	local world = self.world
	for slot, st in self.lastState do
		local bird = world.birds[slot]
		if bird and not bird.dead and not bird.isBot and not bird.ghost then
			local tick = st.tick
			local touching = false
			if tick >= world.testPhaseUntil and Abilities.spikeGuard(world, bird) == nil then
				local last = self.lastHitTick[slot]
				if not last or tick - last > GameConfig.INVULN_TICKS + 10 then
					for _, s in world.spikes do
						if
							Spikes.hurtsTeam(s, bird.team)
							and Spikes.isHarmful(s, tick)
							and Spikes.touches(s, bird.x, bird.y, math.max(1, bird.radius - 4), tick)
						then
							touching = true
							break
						end
					end
				end
			end
			if touching then
				local seen = self.pendingForced[slot]
				if not seen then
					self.pendingForced[slot] = world.tick
				elseif world.tick - seen > 30 then
					self:applyHit(bird, world.tick, "spike", nil, nil)
				end
			else
				self.pendingForced[slot] = nil
			end
		end
	end
end

-- Event entities ----------------------------------------------------------------

function Match:applyEntity(ev, entityId: number, action: string, bird)
	local world = self.world
	if not ev or ev ~= world.event or ev.ended then
		return
	end
	if action == "chop" then
		ev.s.target = (ev.s.target or 100) + 120
		self:broadcast("EventSignal", ev.id, "target", ev.s.target)
		return
	end
	if ev.removed[entityId] and not (bird and bird.isBot) then
		return
	end
	ev.removed[entityId] = true
	self:broadcast("EventEntity", ev.id, entityId, action, if bird then bird.slot else 0)
	if action == "collect" and bird and not bird.dead then
		local amount = if ev.name == "CRT_MODE" then 2 else 1
		if self.mode.versus then
			bird.strums += amount
			self:sendScore()
		else
			self:addScore(amount)
			self:sendScore()
		end
	end
end

-- HONK: pop hazards near the honker, shove rivals in Versus
function Match:resolveHonk(bird)
	local world = self.world
	local r = Abilities.HONK_RADIUS
	local ev = world:eventActive()
	if ev and ev.def.honk then
		local ids = ev.def.honk(world, ev, bird.x, bird.y, r) or {}
		for _, id in ids do
			self:applyEntity(ev, id, "honk", bird)
		end
	end
	if self.mode.versus then
		for _, other in world.birdList do
			if other ~= bird and not other.dead and other.team ~= bird.team then
				local dx, dy = other.x - bird.x, other.y - bird.y
				local d = math.sqrt(dx * dx + dy * dy)
				if d < r then
					local nx, ny = if d > 0 then dx / d else 1, if d > 0 then dy / d else 0
					local push = 28 * (1 - d / r) + 10
					local dazed = world.tick + 40
					if other.isBot then
						other.x = math.clamp(other.x + nx * push, other.radius, W - other.radius)
						other.vy += ny * 7
						other.dazedUntil = dazed
					else
						local owner = self.slotOwner[other.slot]
						if owner then
							self:send(owner, "Knock", self.id, other.slot, nx * push, ny * 7, dazed)
						end
					end
				end
			end
		end
	end
end

-- Client messages -----------------------------------------------------------------

function Match:ownsSlot(player: Player, slot: number): boolean
	return self.slotOwner[slot] == player
end

function Match:onClientState(player: Player, tick: number, slot: number, data)
	if not self:ownsSlot(player, slot) or type(data) ~= "table" then
		return
	end
	local bird = self.world.birds[slot]
	if not bird or bird.dead then
		return
	end
	local prev = self.lastState[slot]
	if prev and tick <= prev.tick then
		return -- out of order
	end
	if tick > self.world.tick + 60 then
		return -- from the future: ignore
	end
	BirdState.unpackInto(bird, data)
	bird.x = math.clamp(bird.x, -40, W + 40)
	bird.y = math.clamp(bird.y, -40, H + 40)
	self.lastState[slot] = { tick = tick }
end

function Match:onClientMessage(player: Player, msg: string, ...)
	local world = self.world
	local args = { ... }
	if msg == "Strum" then
		local slot, tick, y, lineIndex = args[1], args[2], args[3], args[4]
		local bird = world.birds[slot]
		if not bird or not self:ownsSlot(player, slot) or bird.dead or self.state ~= "playing" then
			return
		end
		if type(tick) ~= "number" or type(y) ~= "number" then
			return
		end
		local last = self.lastStrumTick[slot] or -1000
		if tick - last < 8 or tick > world.tick + 60 then
			return
		end
		local ev = world:eventActive()
		local lines = if ev and ev.def.lines then ev.def.lines(world, ev) else { MID }
		local lineX = lines[lineIndex or 1] or MID
		if math.abs(bird.x - lineX) > 90 then
			return -- not plausibly at the line
		end
		self:onStrum(bird, tick, y, lineIndex or 1, lineX)
	elseif msg == "Hit" then
		local slot, tick, cause, causeId, claimed = args[1], args[2], args[3], args[4], args[5]
		local bird = world.birds[slot]
		if bird and self:ownsSlot(player, slot) and type(tick) == "number" then
			self:applyHit(bird, math.min(tick, world.tick), tostring(cause), causeId, claimed)
		end
	elseif msg == "Ability" then
		local slot, tick = args[1], args[2]
		local bird = world.birds[slot]
		if not bird or not self:ownsSlot(player, slot) or bird.dead then
			return
		end
		if bird.charge < Abilities.cost(bird) then
			self:sendScore() -- resync the client's meter
			return
		end
		bird.charge = 0
		bird.abilityUses += 1
		local kind = Abilities.kind(bird)
		bird.abilityUntil = (tonumber(tick) or world.tick) + (Abilities.DURATION[kind] or 10)
		if kind == "PECK" then
			bird.pecking = true
		end
		self:broadcast("Ability", slot, tick, kind)
		if kind == "HONK" then
			self:resolveHonk(bird)
		end
	elseif msg == "Entity" then
		local eventId, entityId, action, slot = args[1], args[2], args[3], args[4]
		local bird = world.birds[slot]
		local ev = world.event
		if bird and self:ownsSlot(player, slot) and ev and ev.id == eventId then
			if action == "collect" or action == "shot" or action == "consume" or action == "chop" then
				self:applyEntity(ev, tonumber(entityId) or 0, action, bird)
			end
		end
	elseif msg == "SpikeBreak" then
		local spikeId, slot, reason = args[1], args[2], args[3]
		local bird = world.birds[slot]
		if bird and self:ownsSlot(player, slot) and world.spikeById[spikeId] then
			local okPeck = reason == "peck" and (bird.pecking or world.tick < bird.abilityUntil + 30)
			local okEgg = reason == "egg"
			if okPeck or okEgg then
				bird.pecking = false
				self:breakSpike(spikeId)
			end
		end
	elseif msg == "Revive" then
		self:tryRevive(player, false)
	end
end

-- Revive -------------------------------------------------------------------------

function Match:allDead(): boolean
	for _, b in self.world.birdList do
		if not b.dead then
			return false
		end
	end
	return true
end

function Match:tryRevive(player: Player, fromPurchase: boolean): boolean
	if self.state ~= "reviveOffer" or not self.players[player] then
		return false
	end
	if not fromPurchase and not self.service.consumeReviveToken(player) then
		return false
	end
	self.revived = true
	local world = self.world
	local layout = spawnLayout(#world.birdList)
	world:clearSpikes()
	if world.event and not world.event.ended then
		Engine.endEvent(world, world.event.id)
		self:broadcast("EventEnd", world.event.id, world.tick)
	end
	for i, b in world.birdList do
		b.dead = false
		b.lives = 2
		local pos = layout[i]
		BirdState.placeAt(b, pos[1], pos[2], pos[3])
		b.invulnUntil = world.tick + 180
		self.lastHitTick[b.slot] = nil
	end
	-- resume the clock from where it paused
	self.t0 = serverNow() - world.tick / GameConfig.TICK_RATE + 1.5
	self.state = "playing"
	self.nextEventTick = world.tick + 240
	self:broadcast("Revived", self.t0, self:birdInfo())
	self:syncSpikes()
	return true
end

-- Event scheduling ----------------------------------------------------------------

function Match:eventParams(name: string)
	local slots = {}
	for _, b in self.world.birdList do
		if not b.dead then
			table.insert(slots, b.slot)
		end
	end
	self.rng:shuffle(slots)
	if name == "SIZE_SWAP" then
		local big = {}
		for i = 1, math.max(1, math.floor(#slots / 2)) do
			table.insert(big, slots[i])
		end
		return { big = big }
	elseif name == "GHOST_MODE" then
		return { ghosts = { slots[1] } }
	elseif name == "SWAP_POSITIONS" then
		local pairs = {}
		for i = 1, #slots - 1, 2 do
			table.insert(pairs, slots[i])
			table.insert(pairs, slots[i + 1])
		end
		return { pairs = pairs }
	end
	return {}
end

function Match:maybeStartEvent()
	local world = self.world
	if world.event and not world.event.ended then
		return
	end
	if world.tick < self.nextEventTick then
		return
	end
	local name
	if self.practice then
		name = self.opts.labEvent
	else
		local pool = EventMeta.poolFor(#world.birdList == 1)
		name = self.rng:pick(pool).name
	end
	self.serial += 1
	local seed = Rng.hash(self.seed, self.serial)
	local startTick = world.tick + GameConfig.EVENT_ANNOUNCE_TICKS
	local params = self:eventParams(name)
	Engine.scheduleEvent(world, name, self.serial, seed, startTick, params)
	self:broadcast("Event", self.serial, name, seed, startTick, params)
	self.nextEventTick = math.huge -- set again when this event finishes
	if not self.practice then
		for player in self.players do
			self.service.discoverEvent(player, name)
		end
	end
end

-- Main loop -------------------------------------------------------------------------

function Match:currentTick(): number
	return math.floor((serverNow() - self.t0) * GameConfig.TICK_RATE)
end

function Match:stepOnce()
	local world = self.world
	-- bots decide
	for slot, brain in self.brains do
		local bird = world.birds[slot]
		if bird and not bird.dead then
			local flap, ability = Bot.think(world, bird, brain)
			if flap then
				Physics.flap(world, bird)
			end
			if ability and Abilities.activate(world, bird) then
				self:broadcast("Ability", slot, world.tick, Abilities.kind(bird))
			end
		end
	end
	self:maybeStartEvent()
	Engine.step(world)
end

function Match:update()
	if self.state == "ended" then
		return
	end
	local target = self:currentTick()

	if self.state == "countdown" then
		if target >= 0 then
			self.state = "playing"
		else
			return
		end
	end

	if self.state == "reviveOffer" then
		if serverNow() > self.reviveDeadline then
			self:finish()
		end
		return
	end

	local steps = 0
	while self.world.tick < target and steps < 8 do
		self:stepOnce()
		steps += 1
		if self.state ~= "playing" then
			break
		end
	end
	if target - self.world.tick > 30 then
		-- server hitch: skip ahead instead of spiralling
		self.world.tick = target
	end

	self:checkForcedHits()

	-- snapshots for remote rendering
	if self.world.tick - self.lastSnapshot >= GameConfig.SNAPSHOT_EVERY then
		self.lastSnapshot = self.world.tick
		local snap = {}
		for _, b in self.world.birdList do
			local packed = BirdState.pack(b)
			table.insert(packed, 1, b.slot)
			table.insert(snap, packed)
		end
		for player in self.players do
			if player.Parent then
				self.service.sendFast(player, self.id, self.world.tick, snap)
			end
		end
	end

	self:checkEnd()
end

function Match:checkEnd()
	local world = self.world
	if self.mode.versus then
		local alive = {}
		for _, b in world.birdList do
			if not b.dead then
				alive[b.team] = true
			end
		end
		local n = 0
		for _ in alive do
			n += 1
		end
		if n == 0 or (n <= 1 and #world.birdList > 1) then
			self:finish()
		end
		if world.tick >= GameConfig.VERSUS_ROUND_TICKS and not world.suddenDeath then
			world.suddenDeath = true
			self:broadcast("SuddenDeath", world.tick)
		end
		return
	end
	if self:allDead() then
		if self.deathSeenTick == nil then
			self.deathSeenTick = world.tick
		elseif world.tick - self.deathSeenTick >= GameConfig.DEATH_GAMEOVER_DELAY then
			if self.mode.allowRevive and not self.revived and not self.practice and world.score >= 3 then
				self.state = "reviveOffer"
				self.reviveDeadline = serverNow() + 8
				self:broadcast("ReviveOffer", self.reviveDeadline)
			else
				self:finish()
			end
		end
	else
		self.deathSeenTick = nil
	end
end

function Match:placements(): { number }
	-- returns team ids, winner first
	local order = {}
	local alive = {}
	for _, b in self.world.birdList do
		if not b.dead and not table.find(alive, b.team) then
			table.insert(alive, b.team)
		end
	end
	for _, t in alive do
		table.insert(order, t)
	end
	for i = #self.eliminated, 1, -1 do
		table.insert(order, self.eliminated[i])
	end
	return order
end

function Match:finish()
	if self.state == "ended" then
		return
	end
	self.state = "ended"
	local world = self.world
	local results = {
		mode = self.mode.id,
		score = world.score,
		practice = self.practice,
		birds = {},
		placements = if self.mode.versus then self:placements() else {},
	}
	for _, b in world.birdList do
		table.insert(results.birds, {
			slot = b.slot,
			team = b.team,
			name = b.name,
			strums = b.strums,
			isBot = b.isBot,
			kind = b.kind,
		})
	end
	self.service.onMatchFinished(self, results)
end

-- A player left: their birds drop out
function Match:removePlayer(player: Player)
	local info = self.players[player]
	if not info then
		return
	end
	for _, slot in info.slots do
		local bird = self.world.birds[slot]
		if bird and not bird.dead then
			bird.dead = true
			bird.lives = 0
			self:broadcast("Damage", slot, 0, self.world.tick, "left", "dead", bird.x, bird.y, bird.dir)
			self:onBirdDied(bird)
		end
		self.slotOwner[slot] = nil
	end
	self.players[player] = nil
	-- nobody human left: end quietly
	if next(self.players) == nil then
		self.state = "ended"
		self.service.onMatchFinished(self, nil)
	end
end

return Match
