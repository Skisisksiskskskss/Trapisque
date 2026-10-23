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
