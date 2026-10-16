-- Rules engine unit tests (scripted dice, white-box setups)
local Engine = requireModule("Shared/Game/Engine")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Config = requireModule("Shared/Config")

local R = Config.Rules
local CC = Config.Characters

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

local function dice(g, a, b)
	g.turn.dice = if b then { a, b } else { a }
end

-- The current player rolls `a` (and `b`) and moves with die `die`.
local function move(g, seat, die, a, b)
	if a then
		dice(g, a, b)
	end
	local ok, err, events = g:command(seat, { type = "move", die = die })
	truthy(ok, "move failed: " .. tostring(err))
	return events
end

local function cmd(g, seat, c)
	local ok, err, events = g:command(seat, c)
	truthy(ok, c.type .. " failed: " .. tostring(err))
	return events
end

-- boards ------------------------------------------------------------------

test("boards build with the designed tile counts", function()
	local b = Board.get(Maps.get("blissful"))
	eq(b.count, 36, "blissful main tiles")
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
			falsy(board.naturalInit[spot], def.id .. ": token on a hazard")
			truthy(spot ~= board.start and spot ~= board.treasure)
		end
		for tile in def.startingPlaced or {} do
			falsy(table.find(board.tokenSpots, tile), def.id .. ": starting trap on a token spot")
			falsy(board.naturalInit[tile], def.id .. ": starting trap on a hazard")
		end
	end
	truthy(j.dist[j.start] < j.routeLength, "junction shortcuts should be shorter")
end)

-- the dice ------------------------------------------------------------------

test("your two dice roll by themselves when your turn starts", function()
	local g = newGame()
	eq(g.current, 1)
	eq(#g.turn.dice, 2)
	local snap = g:snapshot(1)
	eq(#snap.dice, 2)
	falsy(g:command(1, { type = "roll" }), "there is no roll command any more")
end)

test("move with one die, the other charges your Power", function()
	local g = newGame()
	move(g, 1, 1, 3, 5)
	eq(g.players[1].tile, 4)
	eq(g.players[1].power, 5)
	eq(g.current, 2)
	local ok, err = g:command(1, { type = "move", die = 1 })
	falsy(ok, "out-of-turn move accepted")
	truthy(err)
end)

test("Power stops at the length of your bar", function()
	local g = newGame({ characters = { "overseer", "mage" } })
	move(g, 1, 1, 1, 6)
	eq(g.players[1].power, CC.overseer.cost)
end)

test("doubles: the second die moves you backwards, and the other still charges Power", function()
	local g = newGame()
	setTile(g, 1, 8)
	local events = move(g, 1, 2, 3, 3)
	eq(g.players[1].tile, 5, "back 3 along the way you came")
	eq(g.players[1].power, 3, "the first die charged Power")
	local back = false
	for _, e in events do
		if e.t == "choose" and e.back then
			back = true
		end
	end
	truthy(back, "the choice says it went backwards")
	-- the first die of the pair goes forwards as usual
	local g2 = newGame()
	setTile(g2, 1, 8)
	move(g2, 1, 1, 3, 3)
	eq(g2.players[1].tile, 11)
	-- no pair, no backwards die
	eq(select(3, Engine.dieOption({ 2, 5 }, 2)), false)
	eq(select(3, Engine.dieOption({ 4, 2, 4 }, 3)), true, "a pair among three dice")
end)

test("doubles can also move the total, without charging Power", function()
	local g = newGame()
	local ok = g:command(1, { type = "move", die = "sum" })
	-- the scripted start rolls 1 and 1: doubles
	truthy(ok)
	eq(g.players[1].tile, 3)
	eq(g.players[1].power, 0)
	local g2 = newGame()
	dice(g2, 2, 5)
	falsy(g2:command(1, { type = "move", die = "sum" }), "the total needs doubles")
end)

test("one of each character per match: a clash goes to one of them, the other is told", function()
	local players = {}
	for i = 1, 6 do
		players[i] = { id = "p" .. i, name = "P" .. i, character = if i <= 3 then "mage" else nil }
	end
	local g = Engine.new({ mode = "chaos", map = "blissful", players = players, seed = 3 })
	local events = g:start()
	local seen, mages, told = {}, 0, 0
	for _, p in g.players do
		falsy(seen[p.character], "two players are the " .. tostring(p.character))
		seen[p.character] = true
		if p.character == "mage" then
			mages += 1
		end
	end
	eq(mages, 1)
	for _, e in events do
		if e.t == "setup" then
			for _, sp in e.players do
				if sp.wanted == "mage" then
					told += 1
				end
			end
		end
	end
	eq(told, 2, "the two who didn't get the Mage are told")
end)

test("the underdog: clearly last (laps count) rolls an extra die", function()
	local g = newGame({ characters = { "mage", "trapper", "warper" } })
	local board = g.board
	local lap = board.dist[board.start]
	-- everyone else is 10 tiles in: player 1, still at the Start, is the underdog
	setTile(g, 2, board.pathFromStart[board.start][1])
	for seat = 2, 3 do
		local tile = board.start
		for _ = 1, 10 do
			tile = board.forward[tile][1]
		end
		setTile(g, seat, tile)
	end
	eq(g:progress(g.players[1]), 0)
	eq(g:progress(g.players[2]), 10)
	eq(g:underdogSeat(), 1)
	g:_roll(g.players[1], false)
	eq(#g.turn.dice, 3, "an extra die")
	eq(g.turn.gold, 3, "the extra one is the gold die")
	eq(g.players[1].stats.underdog, 1)
	-- the gold die moves you but never charges Power, and never makes doubles
	eq(select(2, Engine.dieOption({ 2, 3, 6 }, 1, 3)), 3, "Power from the other plain die, not the gold 6")
	eq(select(2, Engine.dieOption({ 2, 3, 6 }, 3, 3)), 3, "moving with gold: the best plain die charges")
	eq(select(3, Engine.dieOption({ 4, 1, 4 }, 3, 3)), false, "gold doesn't pair up")
	eq(Engine.dieOption({ 5, 5, 2 }, "sum", 3), 10, "a plain pair can still move the total")
	-- a treasure counts as a whole lap: back at the Start after banking one isn't last
	g.players[1].treasures = 1
	eq(g:progress(g.players[1]), lap)
	truthy(g:underdogSeat() ~= 1)
	-- close behind isn't clearly last
	g.players[1].treasures = 0
	local near = board.start
	for _ = 1, 10 - R.UnderdogGap + 1 do
		near = board.forward[near][1]
	end
	setTile(g, 1, near)
	eq(g:underdogSeat(), nil)
	-- a tie for last: nobody
	setTile(g, 1, board.start)
	setTile(g, 2, board.start)
	eq(g:underdogSeat(), nil)
	-- a frozen underdog still rolls the one frozen die
	setTile(g, 2, g.players[3].tile)
	g.players[1].status.frozen = 1
	g:_roll(g.players[1], false)
	eq(#g.turn.dice, 1)
end)

test("backwards from the start goes nowhere but still ends the turn", function()
	local g = newGame()
	local before = g.players[1].tile
	move(g, 1, 2, 5, 5)
	eq(g.players[1].tile, before)
	eq(g.current, 2)
end)

test("Frozen: one die, at half speed, and no Power", function()
	local g = newGame()
	g.players[2].status.frozen = 2
	g.rng:push(5)
	move(g, 1, 1, 1, 2)
	eq(#g.turn.dice, 1, "frozen players roll one die")
	eq(g.turn.dice[1], 3, "half of 5, rounded up")
	move(g, 2, 1)
	eq(g.players[2].tile, 4)
	eq(g.players[2].power, 0)
	eq(g.players[2].status.frozen, 1)
end)

-- cards ---------------------------------------------------------------------

test("one card per turn; passive cards work by themselves", function()
	local g = newGame()
	local p = g.players[1]
	p.hand = { "speed_boost", "bounce_pad", "shield" }
	falsy(g:command(1, { type = "play", item = "shield" }), "shields can't be played")
	cmd(g, 1, { type = "play", item = "speed_boost" })
	local ok, err = g:command(1, { type = "play", item = "bounce_pad" })
	falsy(ok, "a second card in one turn")
	truthy(string.find(err, "already"))
end)

test("boosts change the move you make", function()
	local g = newGame()
	g.players[1].hand = { "speed_boost" }
	cmd(g, 1, { type = "play", item = "speed_boost" })
	move(g, 1, 1, 3, 4)
	eq(g.players[1].tile, 7, "3 doubled")
	g.players[2].hand = { "bounce_pad" }
	cmd(g, 2, { type = "play", item = "bounce_pad" })
	move(g, 2, 2, 1, 2)
	eq(g.players[2].tile, 6, "2 + 3")
end)

test("moonwalk moves you backwards", function()
	local g = newGame()
	setTile(g, 1, 10)
	g.players[1].hand = { "moonwalk" }
	cmd(g, 1, { type = "play", item = "moonwalk" })
	move(g, 1, 1, 3, 1)
	eq(g.players[1].tile, 7)
	eq(g.players[1].trail[#g.players[1].trail], 7)
end)

test("lucky clover rerolls your dice", function()
	local g = newGame()
	g.players[1].hand = { "clover" }
	g.rng:push(6, 4)
	cmd(g, 1, { type = "play", item = "clover" })
	eq(g.turn.dice[1], 6)
	eq(g.turn.dice[2], 4)
end)

test("juice box fills your Power bar", function()
	local g = newGame()
	g.players[1].hand = { "juice" }
	cmd(g, 1, { type = "play", item = "juice" })
	eq(g.players[1].power, CC.mage.cost)
	g.players[1].hand = { "juice" }
	falsy(g:command(1, { type = "play", item = "juice" }), "already full (and already played)")
end)

test("hand limit: extra cards are lost", function()
	local g = newGame()
	local p = g.players[1]
	p.hand = { "spike", "spike", "fire", "ice", "snare" }
	eq(#p.hand, R.HandLimit)
	g:_giveCard(p, "wall", "test")
	eq(#p.hand, R.HandLimit)
end)

-- hidden traps ----------------------------------------------------------------

test("traps are hidden from rivals, seen by your team and the Overseer", function()
	local g = newGame({ characters = { "mage", "warper", "overseer" } })
	g.players[1].hand = { "spike" }
	local events = cmd(g, 1, { type = "play", item = "spike", tile = 5 })
	local mine = g:eventsFor(1, events)
	truthy(findEvent(mine, "place", function(e)
		return e.tile == 5 and e.item == "spike"
	end))
	local rival = g:eventsFor(2, events)
	falsy(findEvent(rival, "place"), "a rival saw where the trap went")
	truthy(findEvent(rival, "hide"), "a rival should see that a trap was hidden")
	truthy(findEvent(g:eventsFor(3, events), "place"), "the Overseer sees it")
	eq(#g:snapshot(1).traps, 1)
	eq(#g:snapshot(2).traps, 0)
	eq(#g:snapshot(3).traps, 1)
	for _, e in rival do
		falsy(e.secret, "secret field leaked")
	end
end)

test("traps go within reach of you; the Trapper reaches anywhere", function()
	local g = newGame({ characters = { "mage", "trapper" } })
	g.players[1].hand = { "spike" }
	local ok, err = g:command(1, { type = "play", item = "spike", tile = 1 + R.TrapRange + 3 })
	falsy(ok, "placed too far away")
	truthy(string.find(err, "Too far"))
	falsy(g:command(1, { type = "play", item = "spike", tile = g.board.treasure }), "on the treasure")
	cmd(g, 1, { type = "play", item = "spike", tile = 1 + R.TrapRange })
	move(g, 1, 1, 1, 1)
	g.players[2].hand = { "spike" }
	cmd(g, 2, { type = "play", item = "spike", tile = 30 })
end)

test("a hidden trap catches a rival; its owner gets a coin and Power", function()
	local g = newGame()
	g.players[1].hand = { "spike" }
	cmd(g, 1, { type = "play", item = "spike", tile = 5 })
	move(g, 1, 1, 1, 1)
	local coins = g.players[1].coins
	local power = g.players[1].power
	local events = move(g, 2, 1, 4, 1)
	eq(g.players[2].tile, 1, "knocked out back to the Start")
	eq(g.players[2].stats.deaths, 1)
	eq(g.players[1].coins, coins + R.CoinsPerGotcha)
	eq(g.players[1].power, math.min(CC.mage.cost, power + R.PowerPerGotcha))
	truthy(findEvent(events, "gotcha"))
	truthy(findEvent(events, "trigger", function(e)
		return e.item == "spike" and e.tile == 5
	end), "the trap is revealed when it goes off")
	eq(g.traps[5], nil, "used up")
end)

test("your own and your team's traps never catch you", function()
	local g = newGame({ mode = "assist", characters = { "mage", "warper", "trapper", "overseer" }, teams = { 1, 1, 2, 2 } })
	g.players[1].hand = { "spike" }
	cmd(g, 1, { type = "play", item = "spike", tile = 5 })
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 5, "walked onto my own trap")
	move(g, 2, 1, 4, 1)
	eq(g.players[2].tile, 5, "teammate is safe")
	truthy(g.traps[5])
	eq(#g:snapshot(2).traps, 1, "teammates see each other's traps")
end)

test("a shield blocks a trap", function()
	local g = newGame()
	g:_addTrap(5, "spike", 2, g.players[2].team)
	g.players[1].hand = { "shield" }
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 5)
	eq(#g.players[1].hand, 0)
	eq(g.traps[5], nil)
end)

test("placing more traps than you may keep removes your oldest", function()
	local g = newGame({ characters = { "mage", "warper" } })
	for i = 1, R.TrapCap do
		g:_addTrap(i + 1, "mudslide", 1, g.players[1].team)
	end
	g.players[1].hand = { "spike" }
	local events = cmd(g, 1, { type = "play", item = "spike", tile = 6 })
	eq(#g:trapsOf(1), R.TrapCap)
	eq(g.traps[2], nil, "the oldest went")
	falsy(findEvent(g:eventsFor(2, events), "removed"), "rivals don't learn where it was")
end)

test("hidden traps can share a tile, and only the placer's own traps block it", function()
	local g = newGame()
	g:_addTrap(5, "spike", 2, g.players[2].team)
	g.players[1].hand = { "mudslide" }
	cmd(g, 1, { type = "play", item = "mudslide", tile = 5 })
	eq(#g.traps[5], 2)
end)

test("every trap does what it says", function()
	local function caught(item, setup)
		local g = newGame()
		setTile(g, 1, 2)
		g:_addTrap(6, item, 2, g.players[2].team)
		if setup then
			setup(g)
		end
		local events = move(g, 1, 1, 4, 1)
		return g, g.players[1], events
	end
	local _, p = caught("mudslide")
	eq(p.tile, 6 - R.MudslideBack)
	_, p = caught("fire")
	eq(p.status.burning, R.BurningTurns)
	_, p = caught("ice")
	eq(p.status.frozen, 0, "mages can't be frozen")
	local g0 = newGame({ characters = { "warper", "mage" } })
	setTile(g0, 1, 2)
	g0:_addTrap(6, "ice", 2, g0.players[2].team)
	move(g0, 1, 1, 4, 1)
	eq(g0.players[1].status.frozen, R.FrozenTurns)
	_, p = caught("snare")
	eq(p.status.skip, 1)
	_, p = caught("banana", function(g)
		g.players[1].hand = { "bounce_pad" }
	end)
	eq(p.tile, 6 - R.BananaBack)
	eq(#p.hand, 0, "dropped a card")
	local g = newGame()
	setTile(g, 1, 2)
	g:_addTrap(6, "grog", 2, g.players[2].team)
	g.rng:push(2)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 1, "eaten on a 2")
	g = newGame()
	setTile(g, 1, 2)
	g:_addTrap(6, "grog", 2, g.players[2].team)
	g.rng:push(5)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 6, "escaped on a 5")
end)

test("burning hops you back at the start of your turn", function()
	local g = newGame()
	setTile(g, 2, 10)
	g.players[2].status.burning = 2
	move(g, 1, 1, 1, 1)
	eq(g.players[2].tile, 9)
	eq(g.players[2].status.burning, 1)
end)

test("a snare skips your next turn", function()
	local g = newGame({ characters = { "mage", "warper", "overseer" } })
	g.players[2].status.skip = 1
	move(g, 1, 1, 1, 1)
	eq(g.current, 3, "seat 2 was skipped")
end)

test("the phoenix potion survives a knockout", function()
	local g = newGame()
	g:_addTrap(5, "spike", 2, g.players[2].team)
	g.players[1].hand = { "phoenix_potion" }
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 5)
	eq(#g.players[1].hand, 0)
end)

-- walls ---------------------------------------------------------------------

test("walls block moves under 5 and crumble when cleared", function()
	local g = newGame()
	g:_addPlaced(5, "wall", 2)
	setTile(g, 1, 2)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 4, "stopped before the wall")
	truthy(g.placed[5], "wall still up")
	setTile(g, 2, 1)
	move(g, 2, 1, 6, 1)
	eq(g.players[2].tile, 7, "moved 6: over the wall")
	eq(g.placed[5], nil, "crumbled")
end)

-- bonks ---------------------------------------------------------------------

test("landing on a rival bonks them back and bounces you on", function()
	local g = newGame()
	setTile(g, 2, 5)
	local events = move(g, 1, 1, 4, 1)
	truthy(findEvent(events, "bonk"))
	eq(g.players[2].tile, 5 - R.BonkBack)
	eq(g.players[1].tile, 5 + R.BonkBounce)
	eq(g.players[1].stats.bonks, 1)
	eq(g.players[2].stats.bonked, 1)
end)

test("a shield blocks a bonk; teammates and the Start are safe", function()
	local g = newGame()
	setTile(g, 2, 5)
	g.players[2].hand = { "shield" }
	move(g, 1, 1, 4, 1)
	eq(g.players[2].tile, 5)
	eq(g.players[1].tile, 5)
	local t = newGame({ mode = "assist", characters = { "mage", "warper", "trapper", "overseer" }, teams = { 1, 1, 2, 2 } })
	setTile(t, 2, 5)
	move(t, 1, 1, 4, 1)
	eq(t.players[2].tile, 5, "teammates don't bonk")
end)

test("only your own move bonks", function()
	local g = newGame({ characters = { "overseer", "mage" } })
	setTile(g, 2, 6)
	setTile(g, 1, 4)
	g.players[1].power = CC.overseer.cost
	cmd(g, 1, { type = "ability", target = 1, option = "fwd" })
	eq(g.players[1].tile, 6)
	eq(g.players[2].tile, 6, "a nudge doesn't bonk")
end)

test("fire starters' bonks burn", function()
	local g = newGame({ characters = { "fire_starter", "mage" } })
	setTile(g, 2, 5)
	local events = move(g, 1, 1, 4, 1)
	truthy(findEvent(events, "status", function(e)
		return e.p == 2 and e.status == "burning" and e.on
	end))
	eq(g.players[2].status.burning, R.BurningTurns - 1, "and it already hopped them back once")
end)

-- hazards -------------------------------------------------------------------

test("rivers stop you; bridges and naturalists cross", function()
	local river = 12
	local g = newGame()
	setTile(g, 1, river - 2)
	move(g, 1, 1, 5, 1)
	eq(g.players[1].tile, river)
	g = newGame()
	setTile(g, 1, river - 2)
	g.players[1].hand = { "bridge" }
	move(g, 1, 1, 5, 1)
	eq(g.players[1].tile, river + 3)
	eq(#g.players[1].hand, 0)
	g = newGame({ characters = { "naturalist", "mage" } })
	setTile(g, 1, river - 2)
	move(g, 1, 1, 5, 1)
	eq(g.players[1].tile, river + 3)
end)

test("locked gates stop you unless you have a Key", function()
	local g = newGame({ map = "junction" })
	setTile(g, 1, 11)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 13)
	g = newGame({ map = "junction" })
	setTile(g, 1, 11)
	g.players[1].hand = { "key" }
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 15)
end)

test("slime stops you unless you have Boots", function()
	local g = newGame({ map = "slimy" })
	setTile(g, 1, 6)
	move(g, 1, 1, 5, 1)
	eq(g.players[1].tile, 8)
	g = newGame({ map = "slimy" })
	setTile(g, 1, 6)
	g.players[1].hand = { "boots" }
	move(g, 1, 1, 5, 1)
	eq(g.players[1].tile, 11)
end)

test("a big move wades through slime but the slime eats some steps", function()
	-- 12 steps from tile 6: the pool on tile 8 eats SlimeDrag of the 10 left
	local g = newGame({ map = "slimy" })
	setTile(g, 1, 6)
	g.turn.boost = "speed_boost"
	local events = move(g, 1, 1, 6, 1)
	eq(g.players[1].tile, 8 + (10 - R.SlimeDrag))
	local slimed = false
	for _, e in events do
		if e.t == "natural" and e.kind == "slime" and e.drag == R.SlimeDrag then
			slimed = true
		end
	end
	truthy(slimed, "a slime event with the steps it ate")
	-- the Naturalist wades through for free
	g = newGame({ map = "slimy", characters = { "naturalist", "mage" } })
	setTile(g, 1, 6)
	g.turn.boost = "speed_boost"
	move(g, 1, 1, 6, 1)
	eq(g.players[1].tile, 18)
end)

test("keys open gated shortcuts", function()
	local g = newGame({ map = "junction" })
	local board = g.board
	local fork
	for from in board.shortcut do
		fork = from
		break
	end
	setTile(g, 1, fork)
	g.players[1].hand = { "key" }
	move(g, 1, 1, 1, 1)
	eq(g.players[1].tile, board.shortcut[fork])
end)

-- treasure and winning --------------------------------------------------------

test("reaching the treasure banks it, pays coins and sends you home", function()
	local g = newGame()
	local t = g.board.treasure
	setTile(g, 1, t - 2)
	local events = move(g, 1, 1, 6, 1)
	eq(g.players[1].treasures, 1)
	eq(g.players[1].coins, R.StartingCoins + R.CoinsPerTreasure)
	eq(g.players[1].tile, g.board.start)
	truthy(findEvent(events, "treasure"))
end)

test("first to the target wins in Chaos", function()
	local g = newGame({ target = 1 })
	setTile(g, 1, g.board.treasure - 1)
	local events = move(g, 1, 1, 3, 1)
	eq(g.phase, "over")
	eq(g.winnerTeam, g.players[1].team)
	eq(g.ranking[1], 1)
	truthy(findEvent(events, "gameover"))
	falsy(g:command(2, { type = "move", die = 1 }), "commands after game over")
end)

test("teammates pool their treasures", function()
	local g = newGame({ mode = "assist", target = 1, characters = { "mage", "warper", "trapper", "overseer" }, teams = { 1, 1, 2, 2 } })
	eq(g.teamTarget, 2)
	setTile(g, 1, g.board.treasure - 1)
	move(g, 1, 1, 1, 1)
	eq(g.phase, "action", "one treasure isn't enough for a team of two")
	setTile(g, 2, g.board.treasure - 1)
	move(g, 2, 1, 1, 1)
	eq(g.phase, "over")
	eq(g.winnerTeam, 1)
end)

test("round limit ends the game on score", function()
	local g = newGame()
	g.maxRounds = 1
	setTile(g, 2, 9)
	move(g, 1, 1, 1, 1)
	move(g, 2, 1, 1, 1)
	eq(g.phase, "over")
	eq(g.endReason, "rounds")
	eq(g.winnerTeam, g.players[2].team)
end)

-- abilities -------------------------------------------------------------------

test("abilities need a full Power bar, once a turn", function()
	local g = newGame({ characters = { "overseer", "mage" } })
	falsy(g:command(1, { type = "ability", target = 2, option = "back" }), "empty bar")
	g.players[1].power = CC.overseer.cost
	setTile(g, 2, 8)
	cmd(g, 1, { type = "ability", target = 2, option = "back" })
	eq(g.players[2].tile, 8 - CC.overseer.steps)
	eq(g.players[1].power, 0)
	g.players[1].power = CC.overseer.cost
	falsy(g:command(1, { type = "ability", target = 2, option = "back" }), "twice in a turn")
end)

test("mage: Blizzard freezes every rival", function()
	local g = newGame({ characters = { "mage", "warper", "trapper" } })
	setTile(g, 2, 6)
	setTile(g, 3, 30)
	g.players[1].power = CC.mage.cost
	cmd(g, 1, { type = "ability" })
	eq(g.players[2].status.frozen, CC.mage.turns)
	eq(g.players[3].status.frozen, CC.mage.turns, "however far away")
	eq(g.players[1].status.frozen, 0, "not the Mage")
	eq(g.players[1].tile, 1 + CC.mage.skate, "and the Mage skates ahead")
end)

test("trapper: Scavenge offers two traps; Bounty Hunter hops forward on a catch", function()
	local g = newGame({ characters = { "trapper", "mage" } })
	g.players[1].power = CC.trapper.cost
	cmd(g, 1, { type = "ability" })
	eq(g.phase, "pick")
	local snap = g:snapshot(1)
	eq(#snap.pick, 2)
	eq(g:snapshot(2).pick, nil, "rivals don't see the offer")
	falsy(g:command(1, { type = "move", die = 1 }), "pick first")
	cmd(g, 1, { type = "pick", index = 2 })
	eq(#g.players[1].hand, 1)
	eq(g.players[1].hand[1], snap.pick[2])
	-- a catch hops the Trapper forward
	g:_addTrap(5, "mudslide", 1, g.players[1].team)
	move(g, 1, 1, 2, 1)
	local before = g.players[1].tile
	move(g, 2, 1, 4, 1)
	eq(g.players[1].tile, before + CC.trapper.bounty)
end)

test("fire starter: Blast Off rockets forward and leaves burning tiles", function()
	local g = newGame({ characters = { "fire_starter", "mage" } })
	g.players[1].power = CC.fire_starter.cost
	local events = cmd(g, 1, { type = "ability" })
	eq(g.players[1].tile, 1 + CC.fire_starter.blast)
	truthy(findEvent(events, "embers"))
	truthy(g.embers[3])
	move(g, 1, 1, 1, 1)
	move(g, 2, 1, 2, 1)
	eq(g.players[2].tile, 3)
	eq(g.players[2].status.burning, R.BurningTurns, "landed on embers")
	eq(g.embers[3], nil, "the embers die down at the Fire Starter's next turn")
end)

test("naturalist: Stampede charges ahead and tramples rivals in the way", function()
	local g = newGame({ characters = { "naturalist", "mage", "trapper" } })
	setTile(g, 1, 4)
	setTile(g, 2, 5) -- run over
	setTile(g, 3, 9) -- out of the way
	g.players[1].power = CC.naturalist.cost
	cmd(g, 1, { type = "ability" })
	eq(g.players[1].tile, 4 + CC.naturalist.charge, "charged ahead")
	eq(g.players[2].tile, 5 - CC.naturalist.trample, "trampled back")
	eq(g.players[3].tile, 9, "the one out of the way is fine")
	eq(g.players[1].power, 0, "it costs the whole bar")
	-- a rival on the tile the herd stops on is trampled too
	g = newGame({ characters = { "naturalist", "mage" } })
	setTile(g, 1, 4)
	setTile(g, 2, 4 + CC.naturalist.charge)
	g.players[1].power = CC.naturalist.cost
	cmd(g, 1, { type = "ability" })
	eq(g.players[2].tile, 4 + CC.naturalist.charge - CC.naturalist.trample, "trampled where the herd stops")
	eq(g.players[1].tile, 4 + CC.naturalist.charge, "no bounce")
	-- not without the Power
	g = newGame({ characters = { "naturalist", "mage" } })
	falsy(g:command(1, { type = "ability" }), "the bar isn't full")
end)

test("warper: Warp swaps with a player in reach; nobody else can swap a Warper", function()
	local g = newGame({ characters = { "warper", "mage" } })
	setTile(g, 2, 6)
	g.players[1].power = CC.warper.cost
	cmd(g, 1, { type = "ability", target = 2 })
	eq(g.players[1].tile, 6)
	eq(g.players[2].tile, 1)
	g = newGame({ characters = { "warper", "mage" } })
	setTile(g, 2, 30)
	g.players[1].power = CC.warper.cost
	falsy(g:command(1, { type = "ability", target = 2 }), "too far")
	g = newGame({ characters = { "mage", "warper" } })
	setTile(g, 2, 3)
	g:_addPlaced(5, "spore_warper", 2)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 5, "the spore can't swap a Warper (the only other player)")
end)

-- potions and other cards ----------------------------------------------------------

test("telepathy moves anyone 1-3 tiles", function()
	local g = newGame()
	setTile(g, 2, 10)
	g.players[1].hand = { "telepathy_potion" }
	cmd(g, 1, { type = "play", item = "telepathy_potion", target = 2, steps = -3 })
	eq(g.players[2].tile, 7)
end)

test("double jeopardy swaps hands, and only the two of them see the new hands", function()
	local g = newGame({ characters = { "mage", "warper", "overseer" } })
	setTile(g, 2, 15)
	g.players[1].hand = { "jeopardy_potion", "spike" }
	g.players[2].hand = { "fire", "ice" }
	local events = cmd(g, 1, { type = "play", item = "jeopardy_potion", target = 2 })
	eq(#g.players[1].hand, 2)
	eq(g.players[2].hand[1], "spike")
	eq(g.players[2].tile, 15 - R.JeopardySteps)
	eq(g.players[1].tile, 1 + R.JeopardySteps)
	local swap3 = findEvent(g:eventsFor(3, events), "handSwap")
	truthy(swap3)
	eq(swap3.handA, nil, "a bystander saw the hands")
	local swap2 = findEvent(g:eventsFor(2, events), "handSwap")
	truthy(swap2 and swap2.handB)
end)

test("x-ray shows you every hidden trap", function()
	local g = newGame({ characters = { "mage", "warper" } })
	g:_addTrap(20, "spike", 2, g.players[2].team)
	eq(#g:snapshot(1).traps, 0)
	g.players[1].hand = { "xray_potion" }
	local events = cmd(g, 1, { type = "play", item = "xray_potion" })
	eq(#g:snapshot(1).traps, 1)
	local mine = findEvent(g:eventsFor(1, events), "xray")
	truthy(mine and #mine.traps == 1)
	falsy(findEvent(g:eventsFor(2, events), "xray"), "rivals don't see what you saw")
end)

test("time travel: drop an anchor, warp back later instead of moving", function()
	local g = newGame()
	setTile(g, 1, 20)
	g.players[1].hand = { "time_potion" }
	cmd(g, 1, { type = "play", item = "time_potion" })
	move(g, 1, 1, 3, 1)
	move(g, 2, 1, 1, 1)
	setTile(g, 1, 2)
	cmd(g, 1, { type = "recall" })
	eq(g.players[1].tile, 20)
	eq(g.players[1].anchor, nil)
	eq(g.current, 2)
end)

-- board pieces -------------------------------------------------------------------

test("teleporters work in pairs", function()
	local g = newGame()
	g:_addPlaced(5, "teleporter", 2)
	g:_addPlaced(20, "teleporter", 2)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 20)
end)

test("conveyor belts carry you off the end", function()
	local g = newGame()
	g:_addPlaced(5, "conveyor", 2, "fwd")
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 8)
end)

test("trampolines bounce you ahead", function()
	local g = newGame()
	g:_addPlaced(5, "trampoline", 2)
	move(g, 1, 1, 4, 1)
	eq(g.players[1].tile, 5 + R.TrampolineForward)
end)

-- tokens and the shop -----------------------------------------------------------

test("a token spins its wheel and then jumps to a free tile", function()
	local g = newGame()
	g.tokens[5] = "assist"
	local events = move(g, 1, 1, 4, 1)
	truthy(findEvent(events, "spin"))
	eq(g.tokens[5], nil)
	truthy(findEvent(events, "tokenMove"))
end)

test("the potion seller opens on your own move, and sells for coins", function()
	local g = newGame()
	g.tokens[5] = "potion"
	g.players[1].coins = 3
	move(g, 1, 1, 4, 1)
	eq(g.phase, "shop")
	cmd(g, 1, { type = "buy", item = "speed_potion" })
	eq(g.players[1].coins, 2)
	falsy(g:command(1, { type = "move", die = 1 }), "finish shopping first")
	cmd(g, 1, { type = "shopDone" })
	eq(g.current, 2)
	-- pushed onto it during someone else's turn: no shop
	g.tokens[7] = "potion"
	setTile(g, 1, 9)
	g.players[2].hand = { "telepathy_potion" }
	cmd(g, 2, { type = "play", item = "telepathy_potion", target = 1, steps = -2 })
	eq(g.phase, "action")
end)

test("snapshots only contain arrays and string keys", function()
	local g = newGame({ keepTokens = true, keepHands = true })
	local snap = g:snapshot(1)
	local function check(t, path)
		local n = #t
		for k, v in t do
			if type(k) == "number" then
				truthy(k >= 1 and k <= n, path .. ": sparse array key " .. k)
			else
				eq(type(k), "string", path .. ": odd key type")
			end
			if type(v) == "table" then
				check(v, path .. "." .. tostring(k))
			end
		end
	end
	check(snap, "snapshot")
end)
