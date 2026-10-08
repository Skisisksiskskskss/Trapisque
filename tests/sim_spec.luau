-- Full-game simulations: bots play many games on every map/mode to catch crashes,
-- soft-locks, broken invariants and runaway game lengths.
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local Maps = requireModule("Shared/Game/Maps")
local Modes = requireModule("Shared/Game/Modes")
local Items = requireModule("Shared/Game/Items")
local Config = requireModule("Shared/Config")

local function checkInvariants(g, label)
	local board = g.board
	for _, p in g.players do
		truthy(board.tiles[p.tile], label .. ": invalid tile " .. tostring(p.tile))
		eq(p.trail[#p.trail], p.tile, label .. ": trail out of sync for P" .. p.index)
		eq(p.trail[1], board.start, label .. ": trail must start at Start")
		truthy(p.tile ~= board.treasure, label .. ": parked on the treasure")
		truthy(#p.hand <= Config.Rules.HandLimit, label .. ": hand over limit")
		truthy(p.coins >= 0, label .. ": negative coins")
		truthy(p.treasures >= 0 and p.treasures <= g.target, label .. ": treasure count out of range")
		truthy(p.status.skip >= 0 and p.status.skip <= 3, label .. ": odd skip count")
		for _, item in p.hand do
			truthy(Items.get(item) and item ~= "coin", label .. ": bad card " .. tostring(item))
		end
		if p.finished then
			eq(p.treasures, g.target, label .. ": finished without the target")
		end
		-- every consecutive pair in the trail must be a forward edge
		for i = 1, #p.trail - 1 do
			local a, b = p.trail[i], p.trail[i + 1]
			truthy(table.find(board.forward[a], b), label .. ": broken trail " .. a .. "->" .. b)
		end
	end
	for tile, e in g.placed do
		truthy(not board:isSpecial(tile), label .. ": item on special tile")
		truthy(Items.get(e.item), label .. ": unknown placed item")
	end
	for tile, origin in g.cover do
		truthy(g.placed[origin] and g.placed[origin].item == "conveyor", label .. ": dangling conveyor cover at " .. tile)
	end
	for _, item in Items.potions do
		truthy(g.stock[item] >= 0, label .. ": negative stock")
	end
	if g.phase ~= "over" then
		truthy(g.current >= 1 and g.current <= #g.players, label .. ": bad current seat")
	end
end

local function randomGarbage(rng)
	local kinds = { "roll", "use", "arm", "ability", "recall", "give", "buy", "shopDone", "nope" }
	local items = {}
	for _, def in Items.list do
		table.insert(items, def.id)
	end
	table.insert(items, "not_an_item")
	return {
		type = kinds[rng:int(1, #kinds)],
		item = items[rng:int(1, #items)],
		tile = rng:int(-2, 80),
		target = rng:int(0, 7),
		steps = rng:int(-5, 5),
		option = ({ "freeze", "burn", "fwd", "back", "x" })[rng:int(1, 5)],
		dir = ({ "fwd", "back", "up" })[rng:int(1, 3)],
	}
end

local function simulate(seed, modeId, mapId, length, fuzz)
	local mode = Modes.get(modeId)
	local Rng = requireModule("Shared/Game/Rng")
	local meta = Rng.new(seed * 7919)
	local n = if mode.isTeam then mode.maxPlayers else meta:int(mode.minPlayers, mode.maxPlayers)
	local players = {}
	for i = 1, n do
		players[i] = { id = "bot" .. i, name = "Bot " .. i, isBot = true }
	end
	local g = Engine.new({
		mode = modeId,
		map = mapId,
		players = players,
		seed = seed,
		target = Modes.targetFor(mode, length),
		length = length,
	})
	g:start()
	local label = string.format("seed=%d %s/%s/%s", seed, modeId, mapId, length)
	checkInvariants(g, label)
	local commands, stuck = 0, 0
	local lastTurn = g.turnCount
	while g.phase ~= "over" do
		commands += 1
		if commands > 60000 then
			error(label .. ": game never ended")
		end
		if fuzz and meta:float() < 0.15 then
			-- garbage from anyone must never break the game
			local seat = meta:int(1, n)
			local before = g.turnCount
			local ok = pcall(function()
				g:command(seat, randomGarbage(meta))
			end)
			truthy(ok, label .. ": command threw an error")
			if g.turnCount ~= before then
				lastTurn = g.turnCount
			end
			checkInvariants(g, label .. " (fuzz)")
		else
			local cmd = Bot.decide(g, g.current)
			local ok, err = false, nil
			if cmd then
				ok, err = g:command(g.current, cmd)
			end
			if not ok then
				ok, err = g:autoAct()
				truthy(ok, label .. ": autoAct failed: " .. tostring(err))
			end
			checkInvariants(g, label)
		end
		if g.turnCount == lastTurn then
			stuck += 1
			if stuck > 40 then
				error(label .. ": a turn took more than 40 commands")
			end
		else
			stuck = 0
			lastTurn = g.turnCount
		end
	end
	return g
end

local SIM_GAMES = 60

test("bots finish full games on every map and mode", function()
	local totals = {}
	local seed = 1
	for _, mapDef in Maps.list do
		for _, mode in Modes.list do
			for _, length in { "quick", "standard", "classic" } do
				local rounds, byLimit, turns = 0, 0, 0
				local games = if length == "quick" then SIM_GAMES else SIM_GAMES // 3
				for _ = 1, games do
					seed += 1
					local g = simulate(seed, mode.id, mapDef.id, length, false)
					rounds += g.round
					turns += g.turnCount
					if g.endReason == "rounds" then
						byLimit += 1
					end
				end
				table.insert(totals, string.format("  %-9s %-8s %-7s avg rounds %5.1f  avg turns %6.1f  hit round limit %d/%d", mapDef.id, mode.id, length, rounds / games, turns / games, byLimit, games))
			end
		end
	end
	print("\nSimulation summary:")
	for _, line in totals do
		print(line)
	end
end)

test("garbage commands never corrupt a game", function()
	for seed = 5000, 5040 do
		local modes = { "chaos", "assist", "factions", "ww4" }
		local maps = { "blissful", "junction", "slimy" }
		simulate(seed, modes[(seed % 4) + 1], maps[(seed % 3) + 1], "quick", true)
	end
end)
