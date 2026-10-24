-- The three newest maps: Frostbite Floes' thin ice, Kraken's Reach's tentacle, and
-- Clockwork Cove's drawbridge and cogs (scripted dice, white-box setups)
local Engine = requireModule("Shared/Game/Engine")
local Config = requireModule("Shared/Config")

local R = Config.Rules

-- (the Mage is never Frozen, so the ice tests leave him out)
local function newGame(map: string, chars: { string }?)
	local players = {}
	for i, c in chars or { "trapper", "fire_starter" } do
		players[i] = { id = "p" .. i, name = "P" .. i, character = c }
	end
	local g = Engine.new({ mode = "chaos", map = map, players = players, seed = 1 })
	g.rng = scriptedRng({})
	g:start()
	g.tokens = {}
	for _, p in g.players do
		p.hand = {}
	end
	return g
end

local function setTile(g, seat: number, tile: number)
	local p = g.players[seat]
	p.tile = tile
	p.trail = table.clone(g.board.pathFromStart[tile])
end

-- The current player moves `n` with their only die.
local function move(g, seat: number, n: number)
	g.turn.dice = { n }
	local ok, err, events = g:command(seat, { type = "move", die = 1 })
	truthy(ok, "move failed: " .. tostring(err))
	return events
end

local function find(events, t: string, pred: ((any) -> boolean)?)
	for _, e in events do
		if e.t == t and (pred == nil or pred(e)) then
			return e
		end
	end
	return nil
end

-- Frostbite Floes -------------------------------------------------------------

test("frostbite: thin ice cracks under the first, and gives way under the next", function()
	-- (three of them, so the round doesn't end, and freeze it over, after the second)
	local g = newGame("frostbite", { "trapper", "fire_starter", "warper" })
	eq(g.natural[5], "thinice")
	local events = move(g, 1, 4)
	eq(g.players[1].tile, 5)
	truthy(g.cracks[5], "the ice cracked")
	truthy(find(events, "ice", function(e)
		return e.state == "cracked"
	end), "no crack")
	eq(g.players[1].status.frozen, 0, "a crack doesn't freeze you")
	setTile(g, 1, 2)
	events = move(g, 2, 4)
	eq(g.players[2].tile, 5 - R.IceSlip, "carried back under the ice")
	eq(g.natural[5], "hole", "it gave way")
	falsy(g.cracks[5])
	eq(g.players[2].status.frozen, R.IceFrozen, "in the water: Frozen")
	truthy(find(events, "ice", function(e)
		return e.state == "broken"
	end), "no splash")
end)

test("frostbite: a crack freezes over by the end of the round after it appeared", function()
	local g = newGame("frostbite")
	move(g, 1, 4)
	eq(g.cracks[5], 1, "cracked in round 1")
	move(g, 2, 1)
	eq(g.cracks[5], 1, "still cracked into round 2")
	move(g, 1, 1)
	local events = move(g, 2, 1)
	falsy(g.cracks[5], "frozen over at the end of round 2")
	truthy(find(events, "refreeze", function(e)
		return table.find(e.tiles, 5) ~= nil
	end))
end)

test("frostbite: Ice Skates glide you off cracked ice; the Naturalist never cracks it", function()
	local g = newGame("frostbite")
	g.cracks[5] = 1
	g.players[1].hand = { "skates" }
	local events = move(g, 1, 4)
	eq(g.players[1].status.frozen, 0)
	eq(#g.players[1].hand, 0, "the Skates are used")
	truthy(find(events, "useCard", function(e)
		return e.item == "skates" and e.why == "ice"
	end))
	truthy(g.cracks[5], "still cracked")
	g = newGame("frostbite", { "naturalist", "trapper" })
	move(g, 1, 4)
	falsy(g.cracks[5], "too light to crack it")
end)

test("frostbite: thin ice holds a walk, cracked ice and open water don't, and it freezes over at the round's end", function()
	local g = newGame("frostbite")
	move(g, 1, 6)
	eq(g.players[1].tile, 7, "walked over the thin ice")
	falsy(g.cracks[5], "only a landing cracks it")
	g = newGame("frostbite")
	g.cracks[5] = 1
	local events = move(g, 1, 6)
	eq(g.natural[5], "hole", "cracked ice gives way under a walk")
	eq(g.players[1].tile, 5 - R.IceSlip, "in you go, and back a little")
	eq(g.players[1].status.frozen, R.IceFrozen)
	truthy(find(events, "ice", function(e)
		return e.state == "broken"
	end))
	g = newGame("frostbite")
	g.cracks[5] = 1
	g.players[1].hand = { "skates" }
	move(g, 1, 6)
	eq(g.players[1].tile, 7, "Skates glide over it")
	eq(#g.players[1].hand, 0)
	g = newGame("frostbite")
	g.natural[5] = "hole"
	move(g, 1, 6)
	eq(g.players[1].tile, 5 - R.IceSlip, "the open water stops you, and in you go")
	eq(g.players[1].status.frozen, R.IceFrozen)
	events = move(g, 2, 2)
	eq(g.natural[5], "thinice", "frozen over again")
	truthy(find(events, "refreeze"))
end)

-- Kraken's Reach --------------------------------------------------------------

test("kraken: the tentacle rises ahead of the leader, and slams whoever is in its reach", function()
	local g = newGame("kraken")
	local mark = g.kraken
	truthy(mark ~= nil, "no mark at the start")
	truthy(mark - g.board.start >= R.KrakenAhead[1] and mark - g.board.start <= R.KrakenAhead[2], "the mark is 3 to 6 ahead")
	local zone = g:krakenZone()
	eq(#zone, 3, "its mark and the tiles either side")
	-- one player steps clear of it, the other right onto the mark
	move(g, 1, zone[#zone] + 1 - g.board.start)
	local events = move(g, 2, mark - g.board.start)
	local slam = find(events, "krakenSlam")
	truthy(slam ~= nil, "no slam at the round's end")
	eq(#slam.hit, 1)
	eq(slam.hit[1], 2)
	truthy(find(events, "grabbed", function(e)
		return e.p == 2
	end))
	eq(g.players[2].tile, mark - R.KrakenDrag, "dragged back")
	eq(g.players[1].tile, zone[#zone] + 1, "out of reach")
	truthy(g.kraken ~= nil, "it rises again")
	truthy(find(events, "krakenMark"), "...somewhere new")
end)

test("kraken: a Harpoon fends it off", function()
	local g = newGame("kraken")
	local mark = g.kraken
	local zone = g:krakenZone()
	move(g, 1, zone[#zone] + 1 - g.board.start)
	g.players[2].hand = { "harpoon" }
	local events = move(g, 2, mark - g.board.start)
	eq(g.players[2].tile, mark, "not dragged")
	eq(#g.players[2].hand, 0, "the Harpoon is used")
	truthy(find(events, "useCard", function(e)
		return e.item == "harpoon" and e.why == "kraken"
	end))
end)

-- Clockwork Cove --------------------------------------------------------------

test("clockwork: the two drawbridges go up in turns", function()
	falsy(Engine.bridgeUp(1, 0))
	truthy(Engine.bridgeUp(2, 0))
	truthy(Engine.bridgeUp(1, 1))
	local g = newGame("clockwork")
	eq(#g.bridges, 2)
	falsy(g.raised[19] or g.raised[20], "the first is down to start with")
	truthy(g.raised[32] and g.raised[33], "the second is up")
	local snap = g:snapshot(1)
	eq(#snap.bridges, 2)
	eq(#snap.bridges[1].tiles, 2)
	falsy(snap.bridges[1].up)
	truthy(snap.bridges[2].up)
	eq(snap.gears[1], 12)
	eq(snap.gears[2], 22)
end)

test("clockwork: a raised drawbridge stops you, unless a Grappling Hook swings you over", function()
	local g = newGame("clockwork")
	g:_setBridges(2)
	setTile(g, 1, 17)
	local events = move(g, 1, 4)
	eq(g.players[1].tile, 18, "stopped at the gap")
	truthy(find(events, "blocked", function(e)
		return e.why == "drawbridge"
	end))
	g = newGame("clockwork")
	g:_setBridges(2)
	setTile(g, 1, 17)
	g.players[1].hand = { "grapple" }
	events = move(g, 1, 4)
	eq(g.players[1].tile, 23, "swung over: the span costs no steps")
	truthy(find(events, "useCard", function(e)
		return e.item == "grapple" and e.why == "bridge"
	end))
	g = newGame("clockwork", { "naturalist", "trapper" })
	g:_setBridges(2)
	setTile(g, 1, 17)
	move(g, 1, 4)
	eq(g.players[1].tile, 21, "the Naturalist swims the gap")
end)

test("clockwork: whoever is on the drawbridge when it rises is tipped back", function()
	local g = newGame("clockwork")
	setTile(g, 1, 17)
	move(g, 1, 2)
	eq(g.players[1].tile, 19)
	local events = move(g, 2, 1)
	local bridge = find(events, "bridge")
	truthy(bridge ~= nil and bridge.bridges[1].up and not bridge.bridges[2].up, "they swap")
	eq(bridge.tipped[1], 1)
	eq(g.players[1].tile, 19 - R.BridgeTip, "tipped off it")
	truthy(g.raised[19], "the first is up now")
	falsy(g.raised[32], "and the second down")
end)

test("clockwork: end a round on a cog and the gears carry you to the other one", function()
	local g = newGame("clockwork")
	setTile(g, 1, 10)
	move(g, 1, 2)
	setTile(g, 2, 20)
	local events = move(g, 2, 2)
	local gears = find(events, "gears")
	truthy(gears ~= nil, "the gears didn't turn")
	eq(#gears.moves, 2)
	eq(g.players[1].tile, 22, "forward from the first cog")
	eq(g.players[2].tile, 12, "back from the second")
end)
