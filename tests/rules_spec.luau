-- House rules (private matches), short boards and the map vote
local Engine = requireModule("Shared/Game/Engine")
local HouseRules = requireModule("Shared/Game/HouseRules")
local Voting = requireModule("Shared/Game/Voting")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Items = requireModule("Shared/Game/Items")
local Config = requireModule("Shared/Config")

-- A Random-like source for Voting (NextInteger / NextNumber) from Luau's math.random.
local function fakeRandom(seed)
	math.randomseed(seed)
	return {
		NextInteger = function(_, a, b)
			return math.random(a, b)
		end,
		NextNumber = function()
			return math.random()
		end,
	}
end

local function newGame(rules, chars, map)
	local players = {}
	for i, c in chars or { "mage", "trapper", "fire_starter" } do
		players[i] = { id = "p" .. i, name = "P" .. i, character = c }
	end
	local g = Engine.new({ mode = "chaos", map = map or "blissful", players = players, seed = 3, rules = rules })
	g:start()
	return g
end

test("house rules: anything odd falls back to the standard rules", function()
	local r = HouseRules.clean({ board = "tiny", timer = 7, power = "lots", cards = 9, abilities = "no", twist = "chaos", vote = "loudest", banned = "all" })
	for k, v in HouseRules.defaults do
		if k ~= "banned" then
			eq(r[k], v, "rule " .. k)
		end
	end
	eq(HouseRules.banCount(r), 0)
	falsy(HouseRules.changesPlay(HouseRules.clean(nil)), "the defaults change nothing")
	local custom = HouseRules.clean({ board = "short", timer = "30", cards = "2", abilities = false })
	eq(custom.board, "short")
	eq(custom.timer, 30)
	eq(custom.cards, 2)
	eq(custom.abilities, false)
	truthy(HouseRules.changesPlay(custom))
	local words = table.concat(HouseRules.describe(custom), " / ")
	truthy(string.find(words, "Short board", 1, true), words)
	truthy(string.find(words, "Abilities off", 1, true), words)
	truthy(string.find(words, "30s turns", 1, true), words)
end)

test("house rules: bans are capped, and two traps always stay", function()
	local all = {}
	for _, id in Items.trapIds do
		all[id] = true
	end
	all.coin = true
	all.bkb = true
	all.bridge = true
	local r = HouseRules.clean({ banned = all })
	falsy(r.banned.coin, "coins can't be banned")
	falsy(r.banned.bkb, "the map's counter can't be banned")
	falsy(r.banned.bridge, "the counter card can't be banned")
	local left = 0
	for _, id in Items.trapIds do
		if id ~= "wall" and not r.banned[id] then
			left += 1
		end
	end
	truthy(left >= HouseRules.MinTraps, "traps left: " .. left)
	local many = {}
	for _, id in HouseRules.bannable do
		many[id] = true
	end
	eq(HouseRules.banCount(HouseRules.clean({ banned = many })), HouseRules.MaxBans)
end)

test("a short board keeps the first part of the trail", function()
	for _, def in Maps.list do
		local full = Board.get(def)
		local short = Board.get(Maps.variant(def, "short"))
		truthy(short.count < full.count, def.id .. ": the short board isn't shorter")
		eq(short.fullCount, full.count, def.id .. ": fullCount is the whole trail")
		eq(short.treasure, short.count, def.id .. ": treasure at the end")
		local share = (short.count - 1) / (full.count - 1)
		truthy(math.abs(share - Maps.ShortShare) < 0.05, def.id .. ": keeps " .. share)
		for idx in short.naturalInit do
			truthy(idx < short.treasure, def.id .. ": a hazard past the treasure")
		end
		for _, b in short.branches do
			truthy(b.to < short.treasure, def.id .. ": a shortcut past the treasure")
		end
		-- the full board is untouched (each variant has its own cache entry)
		eq(Board.get(def).count, full.count)
	end
	eq(Maps.variant(Maps.get("blissful"), "full"), Maps.get("blissful"))
end)

test("house rules: starting cards, starting Power, abilities and the underdog die", function()
	local g = newGame(HouseRules.clean({ cards = 3, power = "full" }))
	for _, p in g.players do
		local extra = if p.character == "trapper" or p.character == "fire_starter" then 1 else 0
		eq(#p.hand, math.min(3 + extra, Config.Rules.HandLimit), p.character .. "'s hand")
		eq(p.power, Engine.powerCap(p), p.character .. " starts with full Power")
	end
	local half = newGame(HouseRules.clean({ power = "half" }))
	for _, p in half.players do
		eq(half.players[p.index].power, math.floor(Engine.powerCap(p) / 2))
	end
	local off = newGame(HouseRules.clean({ abilities = false, power = "full", underdog = false }))
	for _, p in off.players do
		eq(p.power, 0, "no Power with abilities off")
	end
	local ok, err = off:command(off.current, { type = "ability" })
	falsy(ok)
	truthy(string.find(tostring(err), "Abilities are off", 1, true), tostring(err))
	eq(off:snapshot(1).players[1].powerCap, 0)
	-- the clear last place gets no gold die
	off.players[1].tile = off.board.start
	off.players[2].tile = off.board.treasure - 2
	off.players[3].tile = off.board.treasure - 2
	eq(off:underdogSeat(), nil)
end)

test("house rules: a banned card never comes off a wheel or out of the shop", function()
	local rules = HouseRules.clean({ banned = { spike = true, grog = true, fire = true, ice = true, snare = true, mudslide = true, xray_potion = true } })
	-- (one of the six traps comes back: two have to stay)
	eq(HouseRules.banCount(rules), 6)
	local banned = rules.banned
	local g = newGame(rules)
	for _, p in g.players do
		for _, item in p.hand do
			falsy(banned[item], "dealt a banned " .. item)
		end
	end
	eq(g.stock.xray_potion, 0, "a banned potion is sold out")
	local p = g.players[1]
	for _ = 1, 300 do
		p.hand = {}
		g:_spin(p, "trap")
		for _, item in p.hand do
			falsy(banned[item], "the trap wheel gave a banned " .. item)
		end
	end
	eq(g:snapshot(1).rules.banned.grog, true)
end)

test("the map vote's cards", function()
	local mapIds = {}
	for _, m in Maps.list do
		table.insert(mapIds, m.id)
	end
	local eventIds = { "trap_frenzy", "bonk_bonanza", "power_surge", "triple_dice" }
	for seed = 1, 40 do
		local rng = fakeRandom(seed)
		local cards, mystery = Voting.cards({ mystery = true, wildcard = true }, mapIds, eventIds, "power_surge", rng)
		eq(#cards, 4)
		eq(cards[3].kind, "mystery")
		eq(cards[4].kind, "twist")
		truthy(cards[4].event ~= "power_surge", "the twist the match already has")
		truthy(Maps.get(mystery), "a real map under the Mystery card")
		local seen = { [cards[1].map] = true }
		truthy(not seen[cards[2].map], "two cards with the same map")
		seen[cards[2].map] = true
		truthy(not seen[mystery] and not seen[cards[4].map], "the Mystery map shows on another card")
		local plain = Voting.cards({}, mapIds, eventIds, nil, rng)
		eq(#plain, 3)
		for _, c in plain do
			eq(c.kind, "map")
		end
	end
end)

test("the map vote: most votes, ties, and the roulette wheel", function()
	local cards = { { kind = "map", map = "blissful" }, { kind = "map", map = "slimy" }, { kind = "mystery" } }
	local rng = fakeRandom(7)
	eq(Voting.tally(cards, { [1] = 2, [2] = 2, [3] = 1 }, "majority", rng), 2)
	local picked = {}
	for _ = 1, 200 do
		picked[Voting.tally(cards, { [1] = 1, [2] = 2 }, "majority", rng)] = true
	end
	truthy(picked[1] and picked[2] and not picked[3], "a tie is settled between the leaders only")
	local w = Voting.weights(cards, { ["1"] = 3, ["2"] = 3, ["3"] = 1 })
	eq(w[1], 1 + Voting.Sliver)
	eq(w[2], Voting.Sliver)
	eq(w[3], 2 + Voting.Sliver)
	local wins = { 0, 0, 0 }
	for _ = 1, 3000 do
		local i, weights = Voting.tally(cards, { [1] = 1, [2] = 1, [3] = 1, [4] = 1 }, "roulette", rng)
		truthy(weights ~= nil, "the wheel's slices")
		wins[i] += 1
	end
	-- card 1 has 4.35 of 5.05 of the wheel; the others a sliver each
	truthy(wins[1] > 2400 and wins[2] > 80 and wins[3] > 80, table.concat(wins, " "))
end)

---------------------------------------------------------------------------
-- Wanted: a price on the leader's head
---------------------------------------------------------------------------

local R = Config.Rules

local function place(g, seat, tile)
	local p = g.players[seat]
	p.tile = tile
	p.trail = table.clone(g.board.pathFromStart[tile])
end

-- Three players with seat 1 far ahead, at the end of round 2.
local function chase(rules)
	local g = newGame(rules, { "mage", "trapper", "naturalist" })
	g.events = {}
	g.tokens = {}
	place(g, 1, 20)
	place(g, 2, 5)
	place(g, 3, 6)
	g.round = R.WantedFrom
	return g
end

test("wanted: the clear leader gets a price on their head, and it rises", function()
	local g = chase(nil)
	g:_endRound()
	truthy(g.wanted ~= nil, "no poster")
	eq(g.wanted.seat, 1)
	eq(g.wanted.pot, R.WantedStart)
	truthy(findEvent(g.events, "wanted"), "no wanted event")
	eq(g:snapshot(2).wanted.seat, 1)
	g:_endRound()
	eq(g.wanted.pot, R.WantedStart + 1, "a round in the lead")
	-- no clear leader: the poster stays where it is
	place(g, 2, 19)
	g:_endRound()
	eq(g.wanted.seat, 1)
	eq(g.wanted.pot, R.WantedStart + 1)
	-- a new clear leader takes it over at the starting price
	place(g, 2, 30)
	g:_endRound()
	eq(g.wanted.seat, 2)
	eq(g.wanted.pot, R.WantedStart)
end)

test("wanted: not before its round, not without a clear lead, not when the host says no", function()
	local early = chase(nil)
	early.round = R.WantedFrom - 1
	early:_endRound()
	eq(early.wanted, nil)
	local close = chase(nil)
	place(close, 2, 18)
	close:_endRound()
	eq(close.wanted, nil)
	local off = chase(HouseRules.clean({ wanted = false }))
	off:_endRound()
	eq(off.wanted, nil)
end)

test("wanted: bonk them to claim the coins and one of their cards", function()
	local g = chase(nil)
	g:_endRound()
	local outlaw, hunter = g.players[1], g.players[2]
	outlaw.hand = { "clover" }
	hunter.hand = {}
	local coins = hunter.coins
	g.events = {}
	g:_bonk(hunter, outlaw)
	eq(g.wanted, nil, "the poster comes down")
	eq(hunter.coins, coins + R.WantedStart)
	eq(hunter.stats.bounties, 1)
	eq(#outlaw.hand, 0)
	eq(hunter.hand[1], "clover")
	local claim = findEvent(g.events, "wantedClaim")
	truthy(claim and claim.how == "bonk" and claim.pot == R.WantedStart, "no claim event")
	-- only the two of them see which card changed hands
	local theirs = findEvent(g:eventsFor(2, g.events), "loot")
	eq(theirs.item, "clover")
	local others = findEvent(g:eventsFor(3, g.events), "loot")
	truthy(others ~= nil and others.item == nil, "the loot leaked to a third player")
end)

test("wanted: a trap claims it too, and the Wanted's own crimes raise the price", function()
	local g = chase(nil)
	g:_endRound()
	local outlaw, trapper, third = g.players[1], g.players[2], g.players[3]
	-- (no Shields in the way)
	outlaw.hand = {}
	third.hand = {}
	-- the outlaw bonks someone: the price goes up
	g:_bonk(outlaw, third)
	eq(g.wanted.pot, R.WantedStart + 1)
	-- caught in the Trapper's trap
	local tile = outlaw.tile
	local trap = g:_addTrap(tile, "ice", trapper.index, trapper.team)
	local coins = trapper.coins
	g:_triggerTrap(outlaw, tile, trap)
	eq(g.wanted, nil)
	eq(trapper.coins, coins + R.CoinsPerGotcha + R.WantedStart + 1)
end)

test("wanted: Most Wanted shows their traps; reaching the treasure cashes the poster in", function()
	local g = chase(nil)
	g:_endRound()
	local outlaw = g.players[1]
	local hidden = g:_addTrap(30, "spike", outlaw.index, outlaw.team)
	falsy(g:canSee(2, hidden))
	for _ = 1, R.WantedMax do
		g:_endRound()
	end
	eq(g.wanted.pot, R.WantedMax, "the price stops at the top")
	truthy(g.wanted.most, "not Most Wanted")
	truthy(g:canSee(2, hidden), "the Most Wanted's trap is still hidden")
	local mw = findEvent(g.events, "mostWanted")
	truthy(mw and #mw.traps == 1, "the exposed traps")
	-- a trap they hide now is out in the open at once
	outlaw.hand = { "snare" }
	g.current = outlaw.index
	g.phase = "action"
	g.turn.cardsPlayed = 0
	local spot = nil
	for tile = outlaw.tile + 1, outlaw.tile + R.TrapRange do
		if g:canPlace(outlaw, "snare", tile) then
			spot = tile
			break
		end
	end
	truthy(spot, "nowhere to hide a snare")
	local ok, err = g:command(outlaw.index, { type = "play", item = "snare", tile = spot })
	truthy(ok, tostring(err))
	truthy(g.traps[spot][1].public, "the Most Wanted hid a trap")
	-- and the getaway: the treasure, with the price on their head
	local coins = outlaw.coins
	g:_reachTreasure(outlaw)
	eq(outlaw.coins, coins + R.CoinsPerTreasure + R.WantedMax)
	eq(g.wanted, nil)
	truthy(findEvent(g.events, "wantedCashIn"), "no cash-in event")
end)

---------------------------------------------------------------------------
-- End-of-match awards
---------------------------------------------------------------------------

test("awards: everyone gets one, for what they did the most of", function()
	local Awards = requireModule("Shared/Game/Awards")
	local function player(i, stats, treasures)
		local st = { bounties = 0, gotchas = 0, bonks = 0, wantedRounds = 0, bonked = 0, deaths = 0, rolled = 0, rolls = 0, played = 0, abilities = 0, bought = 0, doubles = 0, underdog = 0, tiles = 0 }
		for k, v in stats do
			st[k] = v
		end
		return { index = i, stats = st, treasures = treasures or 0 }
	end
	local players = {
		player(1, { gotchas = 4, bonks = 3, tiles = 60 }, 2),
		player(2, { bonks = 3, bonked = 1, tiles = 40 }, 1),
		player(3, { bonked = 5, tiles = 30, rolled = 20, rolls = 10 }),
		player(4, { tiles = 10 }),
		player(5, { tiles = 12, bonks = 1 }, 1),
	}
	local got = Awards.pick(players)
	eq(got[1].id, "trap_master", "the most gotchas")
	eq(got[2].id, "bonk_champ", "a tie for bonks goes to whoever has no award yet")
	eq(got[3].id, "punching_bag")
	eq(got[4].id, "pacifist", "nobody topped nothing they did")
	eq(got[5].id, "good_sport")
	for i = 1, 5 do
		truthy(got[i].name and got[i].text and got[i].icon, "award " .. i .. " is missing a field")
	end
	-- the unluckiest roller: a low average over enough dice
	local unlucky = Awards.pick({ player(1, { rolled = 20, rolls = 10 }), player(2, { rolled = 40, rolls = 10, tiles = 5 }) })
	eq(unlucky[1].id, "unlucky")
	truthy(string.find(unlucky[1].text, "2.0", 1, true), unlucky[1].text)
end)
