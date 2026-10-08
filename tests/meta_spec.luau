-- Matchmaker + gacha tests
local Matchmaker = requireModule("Shared/Meta/Matchmaker")
local Gacha = requireModule("Shared/Meta/Gacha")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local Modes = requireModule("Shared/Game/Modes")
local Config = requireModule("Shared/Config")
local Rng = requireModule("Shared/Game/Rng")

local cfg = Config.Matchmaking

local function ticket(id, size, created)
	local users = {}
	for i = 1, size do
		table.insert(users, id * 100 + i)
	end
	return { id = "t" .. id, size = size, users = users, created = created or 0 }
end

local function seatsByTeam(match)
	local teams = {}
	for _, s in match.seats do
		teams[s.team] = (teams[s.team] or 0) + 1
	end
	for _, b in match.bots do
		teams[b.team] = (teams[b.team] or 0) + 1
	end
	return teams
end

test("chaos waits for enough players, then matches", function()
	local mode = Modes.get("chaos")
	local m, left = Matchmaker.form(mode, { ticket(1, 1), ticket(2, 1) }, 5, cfg)
	eq(#m, 0, "2 players, short wait: keep waiting")
	eq(#left, 2)
	m = Matchmaker.form(mode, { ticket(1, 1), ticket(2, 1) }, cfg.ChaosWait + 1, cfg)
	eq(#m, 1, "2 players after ChaosWait: go")
	eq(#m[1].seats, 2)
	m = Matchmaker.form(mode, { ticket(1, 2), ticket(2, 1), ticket(3, 1) }, 1, cfg)
	eq(#m, 1, "4 players: instant")
	eq(#m[1].seats, 4)
end)

test("chaos fills with bots after a long wait", function()
	local mode = Modes.get("chaos")
	local m = Matchmaker.form(mode, { ticket(1, 1) }, cfg.BotFillAfter + 1, cfg)
	eq(#m, 1)
	eq(#m[1].seats, 1)
	eq(#m[1].bots, cfg.ChaosTarget - 1)
end)

test("chaos never exceeds 6 and keeps parties whole", function()
	local mode = Modes.get("chaos")
	local m, left = Matchmaker.form(mode, { ticket(1, 4), ticket(2, 3), ticket(3, 2) }, 1, cfg)
	eq(#m[1].seats, 6, "4 + 2")
	eq(#left, 1)
	eq(left[1].id, "t2")
end)

test("team modes pack parties onto the same team", function()
	local mode = Modes.get("ww4") -- 2 teams of 3
	local m = Matchmaker.form(mode, { ticket(1, 2), ticket(2, 2), ticket(3, 1), ticket(4, 1) }, 1, cfg)
	eq(#m, 1)
	local teams = seatsByTeam(m[1])
	eq(teams[1], 3)
	eq(teams[2], 3)
	local teamOf = {}
	for _, s in m[1].seats do
		teamOf[s.userId] = s.team
	end
	eq(teamOf[101], teamOf[102], "party 1 together")
	eq(teamOf[201], teamOf[202], "party 2 together")
end)

test("team modes wait, then bot-fill", function()
	local mode = Modes.get("assist")
	local m = Matchmaker.form(mode, { ticket(1, 2), ticket(2, 1) }, 3, cfg)
	eq(#m, 0, "3 of 4: wait")
	m = Matchmaker.form(mode, { ticket(1, 2), ticket(2, 1) }, cfg.BotFillAfter + 1, cfg)
	eq(#m, 1)
	eq(#m[1].seats, 3)
	eq(#m[1].bots, 1)
	local teams = seatsByTeam(m[1])
	eq(teams[1], 2)
	eq(teams[2], 2)
end)

test("the oldest ticket is never skipped", function()
	local mode = Modes.get("factions") -- 3 teams of 2
	local m = Matchmaker.form(mode, { ticket(1, 2, 0), ticket(2, 2, 1), ticket(3, 2, 2), ticket(4, 2, 3) }, 5, cfg)
	eq(#m, 1)
	local has1 = false
	for _, t in m[1].tickets do
		if t.id == "t1" then
			has1 = true
		end
	end
	truthy(has1)
end)

test("gacha odds sum to 100 and luck boosts the top rarities", function()
	for _, chest in Gacha.chests do
		for _, lucky in { false, true } do
			local total = 0
			for _, pct in Gacha.odds(chest, lucky) do
				total += pct
			end
			truthy(math.abs(total - 100) < 1e-6, chest.id .. " odds sum")
		end
		local base, lucky = Gacha.odds(chest, false), Gacha.odds(chest, true)
		truthy(lucky.mythic > base.mythic, "luck boosts mythic")
	end
end)

test("gacha pity guarantees an epic within 10 explorer chests", function()
	local chest = Gacha.byId.explorer
	local rng = Rng.new(99)
	for trial = 1, 50 do
		local pity = {}
		local gotEpic = false
		for i = 1, 10 do
			local _, rarity = Gacha.roll(chest, pity, {}, rng, false)
			if Gacha.rarityRank(rarity) >= Gacha.rarityRank("epic") then
				gotEpic = true
			end
		end
		truthy(gotEpic, "trial " .. trial .. " had no epic in 10")
	end
end)

test("gacha drop rates roughly match the shown odds", function()
	local chest = Gacha.byId.explorer
	local rng = Rng.new(7)
	local counts = {}
	local n = 20000
	for _ = 1, n do
		local pity = {} -- fresh pity so it never triggers
		local _, rarity = Gacha.roll(chest, pity, {}, rng, false)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	local odds = Gacha.odds(chest, false)
	for rarity, pct in odds do
		local got = (counts[rarity] or 0) / n * 100
		truthy(math.abs(got - pct) < math.max(1.2, pct * 0.25), rarity .. ": expected ~" .. pct .. "% got " .. got .. "%")
	end
end)

test("every chest rarity has items and no exclusive items drop", function()
	local pool = Cosmetics.chestPool()
	for _, chest in Gacha.chests do
		for rarity in chest.odds do
			truthy(#pool[rarity] > 0, chest.id .. " has no " .. rarity .. " items")
		end
	end
	for _, list in pool do
		for _, id in list do
			eq(Cosmetics.get(id).source, nil, id .. " is exclusive")
		end
	end
end)
