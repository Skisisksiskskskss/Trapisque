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

---------------------------------------------------------------------------
-- Progress: mastery, quests, streak, trophies, events
---------------------------------------------------------------------------

local Progress = requireModule("Shared/Meta/Progress")
local Characters = requireModule("Shared/Game/Characters")

test("mastery levels climb with XP and every title exists", function()
	eq(Progress.masteryLevel(0), 1)
	eq(Progress.masteryLevel(119), 1)
	eq(Progress.masteryLevel(120), 2)
	eq(Progress.masteryLevel(10 ^ 6), Progress.masteryMax)
	local into, need = Progress.masteryProgress(150)
	eq(into, 30)
	eq(need, 180)
	local _, none = Progress.masteryProgress(10 ^ 6)
	eq(none, nil, "no next level at max")
	for _, c in Characters.ids do
		for _, tier in Progress.masteryTitles do
			local def = Cosmetics.get(Progress.masteryTitleId(c, tier))
			truthy(def, "missing mastery title " .. c .. " " .. tier)
			eq(def.source, "mastery")
		end
	end
	-- a win pays more than a loss; practice pays half
	local win = Progress.masteryXp({ treasures = 2, won = true, stats = { bonks = 3 } })
	local loss = Progress.masteryXp({ treasures = 0, won = false, stats = {} })
	truthy(win > loss)
	eq(Progress.masteryXp({ treasures = 0, won = false, practice = true, stats = {} }), math.floor(loss * 0.5))
end)

test("daily quests: three different ones, stable per day, one character quest at most", function()
	for user = 1, 60 do
		for day = 20000, 20006 do
			local list = Progress.dailyQuests(user, day)
			eq(#list, Progress.QuestsPerDay)
			local seen, chars = {}, 0
			for _, q in list do
				falsy(seen[q.id], "duplicate quest")
				seen[q.id] = true
				local def = Progress.questById[q.id]
				truthy(def, "unknown quest " .. q.id)
				if string.sub(def.stat, 1, 5) == "char:" then
					chars += 1
				end
			end
			truthy(chars <= 1, "two character quests")
			local again = Progress.dailyQuests(user, day)
			for i, q in list do
				eq(again[i].id, q.id, "quests change on rejoin")
			end
		end
	end
	-- a reroll swaps in a quest that isn't already there
	local list = Progress.dailyQuests(7, 20001)
	local fresh = Progress.rerollQuest(list, 2, 99)
	truthy(fresh)
	for _, q in list do
		truthy(q.id ~= fresh.id, "reroll gave a duplicate")
	end
end)

test("quest progress counts the right match stats", function()
	local result = { treasures = 2, won = true, character = "mage", stats = { bonks = 4, gotchas = 1 } }
	eq(Progress.questGain(Progress.questById.games, result), 1)
	eq(Progress.questGain(Progress.questById.win, result), 1)
	eq(Progress.questGain(Progress.questById.treasures, result), 2)
	eq(Progress.questGain(Progress.questById.bonks, result), 4)
	eq(Progress.questGain(Progress.questById.gotchas, result), 1)
	eq(Progress.questGain(Progress.questById.char_mage, result), 1)
	eq(Progress.questGain(Progress.questById.char_warper, result), 0)
	eq(Progress.questGain(Progress.questById.spins, result), 0)
end)

test("login streak grows on consecutive days and resets after a gap", function()
	local count, day = Progress.nextStreak(nil, 100)
	eq(count, 1)
	eq(day, 1)
	count, day = Progress.nextStreak({ day = 100, count = 1 }, 100)
	eq(count, 1)
	eq(day, nil, "paid twice in a day")
	count, day = Progress.nextStreak({ day = 100, count = 1 }, 101)
	eq(count, 2)
	eq(day, 2)
	count, day = Progress.nextStreak({ day = 106, count = 7 }, 107)
	eq(count, 8)
	eq(day, 1, "the week of rewards starts over after day 7")
	count = Progress.nextStreak({ day = 100, count = 5 }, 103)
	eq(count, 1, "a missed day resets the streak")
end)

test("trophies: winners gain, last place loses a little, never below zero", function()
	truthy(Progress.trophyDelta(1, 4, true, false, 500) > 0)
	truthy(Progress.trophyDelta(4, 4, false, false, 500) < 0)
	local mid = Progress.trophyDelta(2, 4, false, false, 500)
	truthy(mid < Progress.trophyDelta(1, 4, true, false, 500))
	eq(Progress.trophyDelta(4, 4, false, false, 0), 0, "nothing to lose")
	truthy(Progress.trophyDelta(4, 4, false, false, 50) > Progress.trophyDelta(4, 4, false, false, 500), "new players lose less")
	eq(Progress.rank(0).id, "wood")
	eq(Progress.rank(650).id, "gold")
	eq(Progress.rank(99999).id, "legend")
end)

test("weekly events rotate and every event mode game finishes", function()
	local seen = {}
	for week = 0, 7 do
		seen[Progress.currentEvent(week * 7 * 86400 + 1).id] = true
	end
	for _, e in Progress.events do
		truthy(seen[e.id], "event never comes up: " .. e.id)
		eq(Progress.eventById(e.id), e)
	end
	truthy(Modes.get("event") and Modes.get("event").isEvent, "event queue mode")
	local Engine = requireModule("Shared/Game/Engine")
	local Bot = requireModule("Shared/Game/Bot")
	for i, e in Progress.events do
		for seed = 1, 4 do
			local players = {}
			for s = 1, 4 do
				players[s] = { id = "b" .. s, name = "B" .. s, isBot = true }
			end
			local g = Engine.new({ mode = "event", map = "blissful", players = players, seed = seed * 31 + i, target = 2, mutator = e.mutator })
			g:start()
			local guard = 0
			while g.phase ~= "over" do
				guard += 1
				assert(guard < 20000, "event game stuck: " .. e.id)
				local cmd = Bot.decide(g, g.current)
				local ok = cmd ~= nil and g:command(g.current, cmd)
				if not ok then
					g:autoAct()
				end
			end
		end
	end
end)
