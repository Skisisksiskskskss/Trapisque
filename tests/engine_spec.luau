-- Rules engine unit tests (scripted dice, white-box setups)
local Engine = requireModule("Shared/Game/Engine")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Config = requireModule("Shared/Config")

local function newGame(opts)
	opts = opts or {}
	local chars = opts.characters or { "mage", "trapper" }
	local players = {}
	for i, c in chars do
		players[i] = { id = "p" .. i, name = "P" .. i, character = c, team = opts.teams and opts.teams[i] or nil }
	end
	local g = Engine.new({
		mode = opts.mode or "chaos",
		map = opts.map or "blissful",
		players = players,
		seed = 1,
		target = opts.target,
		teamsPreset = opts.teams ~= nil,
	})
	g.rng = scriptedRng({})
	g:start()
	if not opts.keepTokens then
		g.tokens = {}
	end
	-- clean hands so starting cards don't interfere unless a test wants them
	if not opts.keepHands then
		for _, p in g.players do
			p.hand = {}
		end
	end
	return g
end

local function setTile(g, seat, tile)
	local p = g.players[seat]
	p.tile = tile
	p.trail = table.clone(g.board.pathFromStart[tile])
end

local function roll(g, seat, die)
	g.rng:push(die)
	local ok, err, events = g:command(seat, { type = "roll" })
	truthy(ok, "roll failed: " .. tostring(err))
	return events
end

-- boards ------------------------------------------------------------------

test("boards build with the designed tile counts", function()
	local b = Board.get(Maps.get("blissful"))
	eq(b.count, 36, "blissful main tiles")
	eq(b.totalTiles, 36)
	local j = Board.get(Maps.get("junction"))
	eq(j.count, 47, "junction main tiles")
	eq(j.totalTiles, 51, "junction tiles incl. shortcuts")
	local s = Board.get(Maps.get("slimy"))
	eq(s.count, 44, "slimy main tiles")
	for _, def in Maps.list do
		local board = Board.get(def)
		for id = 1, board.totalTiles do
			truthy(board.dist[id] ~= nil, def.id .. ": tile " .. id .. " can't reach the treasure")
			eq(board.pathFromStart[id][1], board.start, def.id .. ": tile " .. id .. " unreachable from start")
		end
		for _, spot in board.tokenSpots do
			falsy(board.naturalInit[spot], def.id .. ": token on a natural trap")
			truthy(spot ~= board.start and spot ~= board.treasure)
		end
		for tile in def.startingPlaced or {} do
			falsy(table.find(board.tokenSpots, tile), def.id .. ": starting trap on a token spot")
			falsy(board.naturalInit[tile], def.id .. ": starting trap on a natural tile")
		end
	end
	truthy(j.dist[j.start] < j.routeLength, "junction shortcuts should be shorter")
end)

test("chill: even halves, odd loses one", function()
	eq(Engine.chill(6), 3)
	eq(Engine.chill(4), 2)
	eq(Engine.chill(2), 1)
	eq(Engine.chill(5), 4)
	eq(Engine.chill(3), 2)
	eq(Engine.chill(1), 0)
end)

-- basic movement ------------------------------------------------------------

test("rolling moves forward and passes the turn", function()
	local g = newGame()
	eq(g.current, 1)
	roll(g, 1, 4)
	eq(g.players[1].tile, 5)
	eq(g.current, 2)
	local ok, err = g:command(1, { type = "roll" })
	falsy(ok, "out-of-turn roll accepted")
	truthy(err)
end)

test("reaching the treasure scores, pays a coin and returns home", function()
	local g = newGame()
	local t = g.board.treasure
	setTile(g, 1, t - 2)
	local events = roll(g, 1, 6) -- overshoot still counts
	eq(g.players[1].treasures, 1)
	eq(g.players[1].coins, Config.Rules.StartingCoins + Config.Rules.CoinsPerTreasure)
	eq(g.players[1].tile, g.board.start)
	truthy(findEvent(events, "treasure"))
end)

test("first to the target wins in Chaos", function()
	local g = newGame({ target = 1 })
	setTile(g, 1, g.board.treasure - 1)
	local events = roll(g, 1, 3)
	eq(g.phase, "over")
	eq(g.winnerTeam, g.players[1].team)
	eq(g.ranking[1], 1)
	truthy(findEvent(events, "gameover"))
	local ok = g:command(2, { type = "roll" })
	falsy(ok, "commands after game over")
end)

-- traps ---------------------------------------------------------------------

test("spike kills and sends you home", function()
	local g = newGame()
	g:_addPlaced(5, "spike", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 1)
	eq(g.players[1].stats.deaths, 1)
	eq(g.placed[5], nil, "spike should be used up")
end)

test("phoenix potion survives a death", function()
	local g = newGame()
	g.players[1].hand = { "phoenix_potion" }
	g:_addPlaced(5, "spike", 2)
	local events = roll(g, 1, 4)
	eq(g.players[1].tile, 5)
	eq(#g.players[1].hand, 0)
	truthy(findEvent(events, "phoenix"))
end)

test("shield blocks a trap", function()
	local g = newGame()
	g.players[1].hand = { "shield" }
	g:_addPlaced(5, "spike", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 5)
	eq(#g.players[1].hand, 0)
	eq(g.placed[5], nil)
end)

test("dying while burning also costs a treasure", function()
	local g = newGame()
	local p = g.players[1]
	p.treasures = 2
	p.status.burning = true
	g:_addPlaced(5, "spike", 2)
	local events = roll(g, 1, 4)
	eq(p.treasures, 1)
	eq(p.status.burning, false, "death clears burning")
	truthy(findEvent(events, "death", function(e)
		return e.lost
	end))
end)

test("mud and mudslide push back, doubled when burning", function()
	local g = newGame()
	g:_addPlaced(5, "mud", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 4)
	roll(g, 2, 1)

	g = newGame()
	g:_addPlaced(5, "mudslide", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 3)

	g = newGame()
	g.players[1].status.burning = true
	g:_addPlaced(5, "mudslide", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 1)
end)

test("naturalist takes double trap penalties", function()
	local g = newGame({ characters = { "naturalist", "mage" } })
	g:_addPlaced(5, "mud", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 3)
end)

test("walls block moves under 5 and crumble when cleared", function()
	local g = newGame()
	g:_addPlaced(4, "wall", 2)
	local events = roll(g, 1, 4)
	eq(g.players[1].tile, 3, "stopped before the wall")
	truthy(findEvent(events, "blocked"))
	truthy(g.placed[4], "wall still standing")

	g = newGame()
	g:_addPlaced(4, "wall", 2)
	roll(g, 1, 5)
	eq(g.players[1].tile, 6, "5+ jumps the wall")
	eq(g.placed[4], nil, "wall crumbled")

	g = newGame()
	g:_addPlaced(4, "wall", 2)
	roll(g, 1, 3)
	eq(g.players[1].tile, 4, "landing exactly on a wall is allowed")
	eq(g.placed[4], nil)
end)

test("snare skips the next turn", function()
	local g = newGame()
	g:_addPlaced(5, "snare", 2)
	roll(g, 1, 4)
	eq(g.players[1].status.skip, 1)
	local events = roll(g, 2, 1)
	-- player 1's turn is skipped straight back to player 2
	eq(g.current, 2)
	truthy(findEvent(events, "skip", function(e)
		return e.p == 1
	end))
end)

test("grog eats you unless you roll 4+", function()
	local g = newGame()
	g:_addPlaced(5, "grog", 2)
	g.rng:push(4, 2) -- move 4, grog roll 2
	g:command(1, { type = "roll" })
	eq(g.players[1].tile, 1)

	g = newGame()
	g:_addPlaced(5, "grog", 2)
	g.rng:push(4, 5)
	g:command(1, { type = "roll" })
	eq(g.players[1].tile, 5)
end)

test("ice freezes rolls; mages are immune", function()
	local g = newGame({ characters = { "trapper", "mage" } })
	g:_addPlaced(5, "ice", 2)
	roll(g, 1, 4)
	truthy(g.players[1].status.frozen)
	roll(g, 2, 1)
	local events = roll(g, 1, 5)
	eq(findEvent(events, "roll").move, 4)
	eq(g.players[1].tile, 9)

	g = newGame({ characters = { "mage", "trapper" } })
	g:_addPlaced(5, "ice", 2)
	roll(g, 1, 4)
	falsy(g.players[1].status.frozen)
end)

-- natural traps ---------------------------------------------------------------

test("rivers end your move; bridges and naturalists cross", function()
	local g = newGame()
	setTile(g, 1, 6)
	roll(g, 1, 4)
	eq(g.players[1].tile, 9, "fell in the river")
	eq(g.players[1].status.skip, 0)

	g = newGame()
	setTile(g, 1, 6)
	g.players[1].hand = { "bridge" }
	roll(g, 1, 4)
	eq(g.players[1].tile, 10)
	eq(#g.players[1].hand, 0)

	g = newGame({ characters = { "naturalist", "mage" } })
	setTile(g, 1, 6)
	roll(g, 1, 4)
	eq(g.players[1].tile, 10)
end)

test("locked gates hold you until you roll 4+", function()
	local g = newGame({ map = "junction" })
	setTile(g, 1, 10)
	roll(g, 1, 4)
	eq(g.players[1].tile, 13)
	truthy(g.players[1].status.held)
	roll(g, 2, 1)
	roll(g, 1, 2)
	eq(g.players[1].tile, 13, "still stuck")
	roll(g, 2, 1)
	roll(g, 1, 4)
	eq(g.players[1].tile, 17, "broke free and moved")
	falsy(g.players[1].status.held)
end)

test("slime chills moves unless you have boots", function()
	local g = newGame({ map = "slimy" })
	setTile(g, 1, 5)
	local events = roll(g, 1, 6)
	eq(findEvent(events, "roll").move, 3)
	eq(g.players[1].tile, 8)

	g = newGame({ map = "slimy" })
	setTile(g, 1, 5)
	g.players[1].hand = { "boots" }
	roll(g, 1, 6)
	eq(g.players[1].tile, 11)
	truthy(g.players[1].status.boots)
	roll(g, 2, 1)
	setTile(g, 1, 16)
	roll(g, 1, 6) -- crosses slime at 19 with boots on
	eq(g.players[1].tile, 22)
end)

test("keys open gated shortcuts", function()
	local g = newGame({ map = "junction" })
	setTile(g, 1, 5)
	g.players[1].hand = { "key" }
	roll(g, 1, 3)
	eq(g.players[1].tile, 49, "took the shortcut")
	eq(#g.players[1].hand, 0)

	g = newGame({ map = "junction" })
	setTile(g, 1, 5)
	roll(g, 1, 3)
	eq(g.players[1].tile, 8, "no key: main corridor")

	g = newGame({ map = "junction", characters = { "naturalist", "mage" } })
	setTile(g, 1, 5)
	roll(g, 1, 3)
	eq(g.players[1].tile, 49, "naturalists know the way")
end)

-- neutral cards ---------------------------------------------------------------

test("teleporters work in pairs", function()
	local g = newGame()
	g:_addPlaced(5, "teleporter", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 5, "a lone teleporter fizzles")
	roll(g, 2, 1)
	g:_addPlaced(20, "teleporter", 2)
	setTile(g, 1, 1)
	roll(g, 1, 4)
	eq(g.players[1].tile, 20)
	eq(g.players[1].trail[#g.players[1].trail], 20)
end)

test("conveyor belts carry you off the end", function()
	local g = newGame()
	local ok = g:canPlace("conveyor", 11, "fwd")
	truthy(ok, "conveyor placement")
	g:_addPlaced(11, "conveyor", 2, "fwd")
	setTile(g, 1, 9)
	roll(g, 1, 3)
	eq(g.players[1].tile, 14)

	g = newGame()
	g:_addPlaced(11, "conveyor", 2, "back")
	setTile(g, 1, 9)
	roll(g, 1, 3)
	eq(g.players[1].tile, 10)
end)

test("spore warper swaps with the nearest player; warpers are immune", function()
	local g = newGame({ characters = { "mage", "trapper", "overseer" } })
	-- overseer goes first
	eq(g.current, 3)
	roll(g, 3, 1)
	eq(g.current, 1)
	g:_addPlaced(5, "spore_warper", 2)
	setTile(g, 2, 3)
	setTile(g, 3, 12)
	roll(g, 1, 4)
	eq(g.players[1].tile, 3)
	eq(g.players[2].tile, 5)

	g = newGame({ characters = { "warper", "trapper" } })
	g:_addPlaced(5, "spore_warper", 2)
	setTile(g, 2, 3)
	roll(g, 1, 4)
	eq(g.players[1].tile, 5)
	eq(g.players[2].tile, 3)
end)

test("shifting sands move by treasures: forward on even cycles, back on odd", function()
	local g = newGame()
	g.players[1].treasures = 1
	g:_addPlaced(5, "shifting_sands", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 6)

	g = newGame()
	g.players[1].treasures = 2
	g:_addPlaced(5, "shifting_sands", 2)
	roll(g, 1, 4)
	eq(g.players[1].tile, 3)
end)

-- abilities -------------------------------------------------------------------

test("mage hex freezes or burns once, then recharges after 2 cycles", function()
	local g = newGame({ characters = { "mage", "trapper" } })
	eq(g.rechargeCycles, 2)
	local ok, err = g:command(1, { type = "ability", target = 2, option = "freeze" })
	truthy(ok, err)
	truthy(g.players[2].status.frozen)
	falsy(g.players[1].ability.ready)
	ok = g:command(1, { type = "ability", target = 2, option = "burn" })
	falsy(ok, "second hex in one turn")
	-- two treasure laps recharge it
	setTile(g, 1, g.board.treasure - 1)
	roll(g, 1, 1)
	roll(g, 2, 1)
	setTile(g, 1, g.board.treasure - 1)
	roll(g, 1, 1)
	truthy(g.players[1].ability.ready, "recharged after 2 cycles")
end)

test("mages can't be frozen by a hex", function()
	local g = newGame({ characters = { "mage", "mage" } })
	local ok = g:command(1, { type = "ability", target = 2, option = "freeze" })
	falsy(ok)
end)

test("overseer nudges and recharges every 2 rounds", function()
	local g = newGame({ characters = { "mage", "overseer" } })
	eq(g.current, 2, "overseer first")
	setTile(g, 1, 6)
	local ok, err = g:command(2, { type = "ability", target = 1, option = "back" })
	truthy(ok, err)
	eq(g.players[1].tile, 5)
	falsy(g.players[2].ability.ready)
	roll(g, 2, 1)
	roll(g, 1, 1)
	roll(g, 2, 1)
	roll(g, 1, 1)
	truthy(g.players[2].ability.ready, "ready after 2 rounds")
end)

test("warper swaps places once per game; regeneration restores it", function()
	local g = newGame({ characters = { "warper", "trapper" } })
	setTile(g, 2, 20)
	local ok, err = g:command(1, { type = "ability", target = 2 })
	truthy(ok, err)
	eq(g.players[1].tile, 20)
	eq(g.players[2].tile, 1)
	g.players[1].hand = { "regeneration" }
	roll(g, 1, 1)
	roll(g, 2, 1)
	ok, err = g:command(1, { type = "use", item = "regeneration" })
	truthy(ok, err)
	truthy(g.players[1].ability.ready)
end)

test("fire starter ignites players on the same tile", function()
	local g = newGame({ characters = { "fire_starter", "trapper" } })
	setTile(g, 2, 5)
	local ok = g:command(1, { type = "ability", target = 2 })
	falsy(ok, "must share a tile")
	setTile(g, 1, 5)
	local err
	ok, err = g:command(1, { type = "ability", target = 2 })
	truthy(ok, err)
	truthy(g.players[2].status.burning)
end)

test("trapper scavenges a trap card", function()
	local g = newGame({ characters = { "trapper", "mage" } })
	g.rng:push(1) -- spike segment
	local ok, err = g:command(1, { type = "ability" })
	truthy(ok, err)
	eq(g.players[1].hand[1], "spike")
end)

test("starting cards are dealt", function()
	local g = newGame({ characters = { "trapper", "fire_starter" }, keepHands = true })
	eq(#g.players[1].hand, Config.Rules.TrapperStartingTraps)
	eq(#g.players[2].hand, Config.Rules.FireStarterStartingFires)
	eq(g.players[2].hand[1], "fire")
end)

-- cards -------------------------------------------------------------------------

test("placing a trap uses your turn", function()
	local g = newGame()
	g.players[1].hand = { "spike" }
	local ok, err = g:command(1, { type = "use", item = "spike", tile = 1 })
	falsy(ok, "can't place on start")
	ok, err = g:command(1, { type = "use", item = "spike", tile = 10 })
	truthy(ok, err)
	eq(g.placed[10].item, "spike")
	eq(g.current, 2)
end)

test("placement rules", function()
	local g = newGame({ keepTokens = true })
	local tokenTile = g.board.tokenSpots[1]
	falsy(g:canPlace("spike", tokenTile), "token tile")
	falsy(g:canPlace("spike", 9), "river tile")
	falsy(g:canPlace("spike", g.board.treasure), "treasure")
	truthy(g:canPlace("spike", 2))
	g:_addPlaced(2, "mud", 1)
	falsy(g:canPlace("spike", 2), "occupied")
	falsy(g:canPlace("teleporter", g.board.treasure - 3), "teleporter too close to treasure")
	falsy(g:canPlace("conveyor", g.board.treasure - 1, "fwd"), "belt runs into the treasure")
	falsy(g:canPlace("conveyor", 2, nil), "belt needs a direction")
end)

test("boosts change this turn's roll", function()
	local g = newGame()
	g.players[1].hand = { "speed_boost", "bounce_pad", "speed_potion" }
	truthy((g:command(1, { type = "arm", item = "speed_boost" })))
	truthy((g:command(1, { type = "arm", item = "bounce_pad" })))
	truthy((g:command(1, { type = "arm", item = "speed_potion" })))
	local events = roll(g, 1, 3)
	eq(findEvent(events, "roll").move, 3 * 2 + 1 + 2)
	eq(#g.players[1].hand, 0)
end)

test("burning halves assist cards", function()
	local g = newGame()
	g.players[1].status.burning = true
	g.players[1].hand = { "speed_boost", "bounce_pad" }
	g:command(1, { type = "arm", item = "speed_boost" })
	g:command(1, { type = "arm", item = "bounce_pad" })
	local events = roll(g, 1, 3)
	eq(findEvent(events, "roll").move, 4 + 1)
end)

test("disarmed boosts stay in your hand", function()
	local g = newGame()
	g.players[1].hand = { "speed_boost" }
	g:command(1, { type = "arm", item = "speed_boost" })
	g:command(1, { type = "arm", item = "speed_boost" })
	roll(g, 1, 3)
	eq(g.players[1].tile, 4)
	eq(#g.players[1].hand, 1)
end)

test("moonwalk steps back and lands", function()
	local g = newGame()
	setTile(g, 1, 8)
	g.players[1].hand = { "moonwalk" }
	g.tokens[6] = "assist"
	g.rng:push(1) -- regeneration segment
	local ok, err = g:command(1, { type = "use", item = "moonwalk", steps = 2 })
	truthy(ok, err)
	eq(g.players[1].tile, 6)
	eq(g.players[1].hand[1], "regeneration")
end)

test("time travel anchor and recall", function()
	local g = newGame()
	setTile(g, 1, 20)
	g.players[1].hand = { "time_potion" }
	local ok, err = g:command(1, { type = "use", item = "time_potion" })
	truthy(ok, err)
	eq(g.players[1].anchor.tile, 20)
	eq(g.current, 1, "anchoring is free")
	roll(g, 1, 2)
	roll(g, 2, 1)
	ok, err = g:command(1, { type = "recall" })
	truthy(ok, err)
	eq(g.players[1].tile, 20)
	eq(g.players[1].anchor, nil)
	eq(g.current, 2)
end)

test("telepathy moves another player", function()
	local g = newGame()
	setTile(g, 2, 10)
	g.players[1].hand = { "telepathy_potion" }
	local ok, err = g:command(1, { type = "use", item = "telepathy_potion", target = 2, steps = -3 })
	truthy(ok, err)
	eq(g.players[2].tile, 7)
end)

test("double jeopardy swaps hands and moves both players", function()
	local g = newGame()
	setTile(g, 2, 15)
	g.players[1].hand = { "jeopardy_potion", "mud" }
	g.players[2].hand = { "shield" }
	local ok, err = g:command(1, { type = "use", item = "jeopardy_potion", target = 2 })
	truthy(ok, err)
	eq(g.players[1].hand[1], "shield")
	eq(g.players[2].hand[1], "mud")
	eq(g.players[2].tile, 9)
	eq(g.players[1].tile, 7)
end)

test("the potion seller sells for coins", function()
	local g = newGame()
	g.tokens[5] = "potion"
	g.players[1].coins = 3
	roll(g, 1, 4)
	eq(g.phase, "shop")
	local ok, err = g:command(1, { type = "roll" })
	falsy(ok, "can't roll while shopping")
	ok, err = g:command(1, { type = "buy", item = "phoenix_potion" })
	truthy(ok, err)
	eq(g.players[1].coins, 1)
	eq(g.stock.phoenix_potion, Config.Rules.PotionStock - 1)
	ok = g:command(1, { type = "buy", item = "jeopardy_potion" })
	falsy(ok, "too expensive")
	ok, err = g:command(1, { type = "shopDone" })
	truthy(ok, err)
	eq(g.current, 2)
end)

test("spinning a wheel gives a card or a coin", function()
	local g = newGame()
	g.tokens[5] = "neutral"
	g.rng:push(4, 5) -- move 4, coin segment
	g:command(1, { type = "roll" })
	eq(g.players[1].coins, Config.Rules.StartingCoins + 1)

	g = newGame()
	g.tokens[5] = "assist"
	g.rng:push(4, 4) -- bkb segment -> bridge on blissful
	g:command(1, { type = "roll" })
	eq(g.players[1].hand[1], "bridge")

	g = newGame({ characters = { "naturalist", "mage" } })
	g.tokens[5] = "assist"
	g.rng:push(4, 4)
	g:command(1, { type = "roll" })
	eq(g.players[1].hand[1], "river_trap")
end)

test("naturalists can place natural traps", function()
	local g = newGame({ characters = { "naturalist", "mage" } })
	g.players[1].hand = { "river_trap" }
	local ok, err = g:command(1, { type = "use", item = "river_trap", tile = 12 })
	truthy(ok, err)
	eq(g.natural[12], "river")
end)

test("hand limits are enforced", function()
	local g = newGame()
	local p = g.players[1]
	for _ = 1, Config.Rules.HandLimit do
		table.insert(p.hand, "mud")
	end
	g:_giveCard(p, "spike")
	eq(#p.hand, Config.Rules.HandLimit)
end)

-- teams -------------------------------------------------------------------------

test("team modes: a team wins when every teammate is finished", function()
	local g = newGame({
		mode = "assist",
		characters = { "mage", "trapper", "warper", "naturalist" },
		target = 1,
	})
	eq(g.players[1].team, 1)
	eq(g.players[2].team, 1)
	eq(g.players[3].team, 2)
	setTile(g, 1, g.board.treasure - 1)
	roll(g, 1, 1)
	truthy(g.players[1].finished)
	eq(g.phase, "action", "teammate still needs a treasure")
	-- finished players keep playing and can hand cards over
	roll(g, 2, 1)
	roll(g, 3, 1)
	roll(g, 4, 1)
	g.players[1].hand = { "shield" }
	local ok, err = g:command(1, { type = "give", item = "shield", target = 2 })
	truthy(ok, err)
	eq(g.players[2].hand[1], "shield")
	ok = g:command(1, { type = "give", item = "shield", target = 3 })
	falsy(ok, "can't give to opponents")
	roll(g, 1, 1)
	setTile(g, 2, g.board.treasure - 1)
	roll(g, 2, 1)
	eq(g.phase, "over")
	eq(g.winnerTeam, 1)
end)

test("a finished player's laps don't count for anyone", function()
	local g = newGame({ mode = "assist", characters = { "mage", "trapper", "warper", "naturalist" }, target = 2 })
	g.players[1].finished = true
	g.players[1].treasures = 2
	local coins = g.players[1].coins
	setTile(g, 1, g.board.treasure - 1)
	local events = roll(g, 1, 1)
	eq(g.players[1].treasures, 2, "finished count stays put")
	eq(g.players[2].treasures, 0, "teammate gets nothing either")
	eq(g.players[1].coins, coins, "no coins for a finished lap")
	truthy(findEvent(events, "lap"))
	falsy(findEvent(events, "treasure"))
	eq(g.players[1].tile, g.board.start, "back to the start for another lap")
end)

test("round limit ends the game on score", function()
	local g = newGame()
	g.maxRounds = 2
	setTile(g, 2, 20)
	roll(g, 1, 1)
	roll(g, 2, 1)
	roll(g, 1, 1)
	roll(g, 2, 1)
	eq(g.phase, "over")
	eq(g.endReason, "rounds")
	eq(g.ranking[1], 2)
end)

test("snapshots only contain arrays and string keys", function()
	local g = newGame({ keepTokens = true })
	g:_addPlaced(11, "conveyor", 2, "fwd")
	local snap = g:snapshot(1)
	local function check(v, path)
		if type(v) ~= "table" then
			return
		end
		local n = #v
		for k, x in pairs(v) do
			if type(k) == "number" then
				truthy(k >= 1 and k <= n and k == math.floor(k), "sparse numeric key at " .. path .. "[" .. k .. "]")
			else
				eq(type(k), "string", "key type at " .. path)
				truthy(n == 0, "mixed table at " .. path)
			end
			check(x, path .. "." .. tostring(k))
		end
	end
	check(snap, "snap")
	truthy(#snap.tokens > 0)
	eq(type(snap.hand), "table")
end)
