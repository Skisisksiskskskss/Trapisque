--[[
	Simulation test suite (pure Luau, runs under Lune):
	  lune run tests/run
]]

local process = require("@lune/process")
local Harness = require("./harness")

local env = Harness.load(process.cwd)
local R = env.require
local Shared = env.Shared

local GameConfig = R(Shared.Config.GameConfig)
local Modes = R(Shared.Config.Modes)
local EventMeta = R(Shared.Config.Events)
local Birds = R(Shared.Config.Birds)
local Rng = R(Shared.Sim.Rng)
local World = R(Shared.Sim.World)
local BirdState = R(Shared.Sim.BirdState)
local Spikes = R(Shared.Sim.Spikes)
local Engine = R(Shared.Sim.Engine)
local Events = R(Shared.Sim.Events)
local Physics = R(Shared.Sim.Physics)
local Bot = R(Shared.Sim.Bot)
local Abilities = R(Shared.Sim.Abilities)

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

local function assertEq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "assert", tostring(b), tostring(a)), 2)
	end
end

-- A small "match layer" stand-in: applies hits/strums like the server would.
local function makeWorld(modeId: string, nBirds: number, seed: number, isServer: boolean)
	local stats = { hits = 0, strums = 0, entities = 0, spikesChanged = 0, fx = 0 }
	local world
	world = World.new({
		mode = Modes[modeId],
		seed = seed,
		isServer = isServer,
		hooks = {
			onHit = function(w, bird, cause, id)
				stats.hits += 1
				BirdState.applyHit(bird, w.tick, w:partnerOf(bird))
			end,
			onCross = function(w, bird, lineX, y)
				stats.strums += 1
				Abilities.addCharge(bird, 1)
				-- spawn a spike like the server would (perBirdWall-ish)
				local side = if bird.slot % 2 == 1 then -1 else 1
				local spike = Spikes.new(w:newSpikeId(), side, w.fxRng:range(20, GameConfig.H - 20), w.tick, {
					createdAtStrum = w.arenaStrums,
				})
				w:addSpike(spike)
			end,
			onEntity = function()
				stats.entities += 1
			end,
			onSpikeBroken = function(w, spike)
				w:removeSpike(spike.id)
			end,
			onSpikesChanged = function()
				stats.spikesChanged += 1
			end,
			onFx = function()
				stats.fx += 1
			end,
		},
	})
	local kinds = {}
	for _, d in Birds.List do
		table.insert(kinds, d.id)
	end
	for i = 1, nBirds do
		local b = BirdState.new(i, {
			sim = true,
			upside = i % 2 == 1 and nBirds > 1,
			x = if i % 2 == 1 then GameConfig.W * 0.75 else GameConfig.W * 0.25,
			y = if i % 2 == 1 then GameConfig.H * 0.25 else GameConfig.H * 0.75,
			dir = if i % 2 == 1 then -1 else 1,
			kind = kinds[(i - 1) % #kinds + 1],
			lives = 99,
		})
		world:addBird(b)
	end
	return world, stats
end

local function runBots(world, ticks: number, skill: number)
	local brains = {}
	for _, b in world.birdList do
		brains[b.slot] = Bot.newBrain(skill, Rng.new(b.slot * 13))
	end
	for _ = 1, ticks do
		for _, b in world.birdList do
			local flap, ability = Bot.think(world, b, brains[b.slot])
			if flap then
				Physics.flap(world, b)
			end
			if ability then
				Abilities.activate(world, b)
			end
		end
		Engine.step(world)
	end
end

print("Skuishi Berds simulation tests")

test("event metadata lists all 69 original events", function()
	assertEq(EventMeta.Count, 69, "event count")
end)

test("every event has a behaviour definition", function()
	for _, meta in EventMeta.List do
		assert(Events.defs[meta.name], "missing def " .. meta.name)
	end
end)

test("rng is deterministic per seed", function()
	local a, b = Rng.new(42), Rng.new(42)
	for _ = 1, 100 do
		assertEq(a:next(), b:next(), "sequence")
	end
	assert(Rng.hash(1, 2, 3) ~= Rng.hash(1, 2, 4), "hash should differ")
end)

test("flap sets vertical speed like the original", function()
	local world = makeWorld("SOLO", 1, 1, true)
	local b = world.birdList[1]
	b.upside = false
	Physics.flap(world, b)
	assertEq(b.vy, -GameConfig.FLAP, "upright flap")
	b.upside = true
	Physics.flap(world, b)
	assertEq(b.vy, GameConfig.FLAP, "upside flap")
end)

test("bird bounces off walls and wraps vertically", function()
	local world = makeWorld("SOLO", 1, 1, true)
	local b = world.birdList[1]
	b.x = GameConfig.W - b.radius - 1
	b.dir = 1
	Engine.step(world)
	assertEq(b.dir, -1, "dir after right wall")
	b.y = GameConfig.H + 40
	b.vy = 1
	Engine.step(world)
	assert(b.y < 0, "wrapped to top")
end)

test("crossing the middle line strums", function()
	local world, stats = makeWorld("SOLO", 1, 1, true)
	local b = world.birdList[1]
	b.x = GameConfig.MID_X - 2
	b.dir = 1
	Engine.step(world)
	assertEq(stats.strums, 1, "strums")
end)

test("spike tip collision hurts and respawns", function()
	local world, stats = makeWorld("SOLO", 1, 1, true)
	local b = world.birdList[1]
	local s = Spikes.new(world:newSpikeId(), -1, 400, -100, {})
	world:addSpike(s)
	b.x = GameConfig.RADIUS + 1
	b.y = 400
	b.dir = -1
	b.vy = 0
	b.lives = 4
	Engine.step(world)
	assertEq(stats.hits, 1, "hit count")
	assertEq(b.lives, 3, "lives")
end)

test("walking spikes stay inside the wall", function()
	local s = Spikes.new(1, 1, 30, 0, {})
	s.walkVy = -0.7
	s.walkStart = 0
	s.walkEnd = 5000
	for t = 0, 5000, 37 do
		local y = Spikes.yAt(s, t)
		assert(y >= 20 - 1e-6 and y <= GameConfig.H - 20 + 1e-6, "y out of range " .. y)
	end
end)

test("every event runs 15s with 4 bot birds without errors", function()
	for _, meta in EventMeta.List do
		local world = makeWorld(if meta.soloOnly then "SOLO" else "VERSUS", if meta.soloOnly then 1 else 4, 7, true)
		for i = 1, 6 do
			world:addSpike(Spikes.new(world:newSpikeId(), if i % 2 == 0 then -1 else 1, 100 * i, -100, {}))
		end
		Engine.scheduleEvent(
			world,
			meta.name,
			1,
			Rng.hash(7, meta.index),
			5,
			{ big = { 1 }, ghosts = { 2 }, pairs = { 1, 2, 3, 4 } }
		)
		local ok, err = pcall(runBots, world, 900, 0.8)
		if not ok then
			error(meta.name .. ": " .. tostring(err))
		end
	end
end)

test("event hazards are identical on two machines (determinism)", function()
	for _, name in
		{
			"METEOR_SHOWER",
			"ALIEN_SWARM",
			"RAIL_RUSH",
			"BONE_ZONE",
			"GEAR_GRIND",
			"PHOTON_SHIFT",
			"ICE_FIELD",
			"LOG_JAM",
			"COLOR_RIFT",
		}
	do
		local wa = makeWorld("VERSUS", 2, 3, true)
		local wb = makeWorld("VERSUS", 2, 3, false)
		Engine.scheduleEvent(wa, name, 1, 999, 5, {})
		Engine.scheduleEvent(wb, name, 1, 999, 5, {})
		for _ = 1, 400 do
			Engine.step(wa)
			Engine.step(wb)
		end
		local function digest(ev)
			local total = 0
			for _, list in ev.s do
				if type(list) == "table" then
					for _, e in list do
						if type(e) == "table" and type(e.x) == "number" then
							total += e.x * 3 + (e.y or 0) * 7
						end
					end
				end
			end
			return math.floor(total * 1000)
		end
		assertEq(digest(wa.event), digest(wb.event), name .. " digest")
	end
end)

test("bot survives a while in solo (no events)", function()
	local world, stats = makeWorld("SOLO", 1, 11, true)
	for i = 1, 10 do
		world:addSpike(Spikes.new(world:newSpikeId(), if i % 2 == 0 then -1 else 1, 70 * i, -100, {}))
	end
	runBots(world, 60 * 30, 1)
	print(string.format("       hits in 30s: %d, strums: %d", stats.hits, stats.strums))
	assert(stats.strums > 10, "bot should keep crossing")
end)

test("abilities fire and behave", function()
	for _, def in Birds.List do
		local world = makeWorld("SOLO", 1, 5, true)
		local b = world.birdList[1]
		b.kind = def.id
		b.charge = def.cost
		local dir0, up0 = b.dir, b.upside
		assert(Abilities.activate(world, b), def.id .. " should fire")
		assertEq(b.charge, 0, "charge consumed")
		if def.ability == "UTURN" then
			assertEq(b.dir, -dir0, "uturn flips dir")
		elseif def.ability == "FLIP" then
			assertEq(b.upside, not up0, "flip toggles gravity")
		end
		for _ = 1, 200 do
			Engine.step(world)
		end
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
