-- Matchmaker + gacha tests
local Matchmaker = requireModule("Shared/Meta/Matchmaker")
local Gacha = requireModule("Shared/Meta/Gacha")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local Modes = requireModule("Shared/Game/Modes")
local Config = requireModule("Shared/Config")
local Rng = requireModule("Shared/Game/Rng")
local Speech = requireModule("Shared/Meta/Speech")

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

test("accessory packs become finishes, and a second pack of one finish pays Gems", function()
	local owned = { acc_none = true, fin_paint = true, acc_gentleman = true, acc_cook = true, acc_kraken = true, dice_ivory = true }
	local equipped = { accessory = "acc_cook", dice = "dice_ivory" }
	local gems = Cosmetics.migratePacks(owned, equipped, Gacha.dupeRefund)
	truthy(owned.fin_oak and owned.fin_crystal and owned.fin_paint and owned.dice_ivory, "the finishes (and the rest) are owned")
	eq(owned.acc_gentleman or owned.acc_cook or owned.acc_kraken or owned.acc_none, nil, "no packs left")
	eq(gems, Gacha.dupeRefund.common, "the Cook's pack, a second Oak, is paid back as a common")
	eq(equipped.finish, "fin_oak", "the worn pack's finish is worn")
	eq(equipped.accessory, nil, "no accessory slot left")
	for id, to in Cosmetics.retiredPacks do
		local def = Cosmetics.get(to[1])
		truthy(def and def.category == "finish", id .. " becomes a finish")
		truthy(to[2] == nil or Cosmetics.rarityById[to[2]] ~= nil, id .. "'s rarity")
	end
end)

test("portrait outfits become the emblems of their sets, worn the same way", function()
	local owned = { outfit_mage_classic = true, outfit_mage_ghost = true, outfit_trapper_gilded = true, fin_paint = true }
	local equipped = { outfits = { mage = "outfit_mage_ghost", trapper = "outfit_trapper_gilded" }, emblems = {} }
	Cosmetics.migrateOutfits(owned, equipped)
	truthy(owned.emblem_mage_classic and owned.emblem_mage_ghost and owned.emblem_trapper_gilded and owned.fin_paint, "the emblems (and the rest) are owned")
	eq(owned.outfit_mage_ghost or owned.outfit_trapper_gilded or owned.outfit_mage_classic, nil, "no outfits left")
	eq(equipped.emblems.mage, "emblem_mage_ghost", "the Mage wears the Ghost Crew emblem")
	eq(equipped.emblems.trapper, "emblem_trapper_gilded", "the Trapper wears the Gilded one")
	eq(equipped.outfits, nil, "no outfit slot left")
	-- every character has three, each its own design: the classic one, the Ghost Crew's
	-- and the Gilded one
	for _, id in requireModule("Shared/Game/Characters").ids do
		for _, set in Cosmetics.emblemSets do
			local def = Cosmetics.get("emblem_" .. id .. "_" .. set.id)
			truthy(def and def.category == "emblem" and def.character == id, "no " .. set.id .. " emblem for the " .. id)
		end
		eq(Cosmetics.emblemOf(nil, id), "emblem_" .. id .. "_classic", "the classic one by default")
		eq(Cosmetics.emblemOf({ [id] = "emblem_" .. id .. "_gilded" }, id), "emblem_" .. id .. "_gilded")
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

test("chat lines are made speakable: numbers, slang and letter-words", function()
	eq(Speech.normalize("GG EZ"), "gee gee ee zee")
	eq(Speech.normalize("gg wp, 12 treasures!!!"), "gee gee well played, twelve treasures!")
	eq(Speech.normalize("I came 3rd of 6"), "I came third of six")
	eq(Speech.normalize("21st"), "twenty-first")
	eq(Speech.normalize("50% chance"), "fifty percent chance")
	eq(Speech.normalize("2v2 me"), "two versus two me")
	eq(Speech.normalize("u r 1,250 gems richer"), "you are one thousand two hundred fifty gems richer")
	eq(Speech.normalize("noooooo :("), "noo")
	eq(Speech.normalize("NPC lol"), "en pee see el oh el")
	eq(Speech.normalize("hmm"), "hmm")
	eq(Speech.normalize("HMM ok"), "HMM okay")
	eq(Speech.normalize("3.5 x2"), "three point five times two")
	eq(Speech.number(0), "zero")
	eq(Speech.number(1000000), "one million")
end)

-- fishing -------------------------------------------------------------------------

local Fishing = requireModule("Shared/Meta/Fishing")
local Maps = requireModule("Shared/Game/Maps")

test("every map has its own fish, and a few turn up anywhere", function()
	for _, def in Maps.list do
		local map = def.id
		local seen, local_ = {}, 0
		for i = 0, 999 do
			local id = Fishing.roll(map, (i + 0.5) / 1000, 0.5, true)
			seen[id] = true
			truthy(Fishing.livesIn(id, map), id .. " doesn't live in " .. map)
		end
		for id in seen do
			if Fishing.byId[id].where ~= "any" then
				local_ += 1
			end
		end
		truthy(local_ >= 3, map .. " should have at least 3 fish of its own, has " .. local_)
		truthy(seen.sardine and seen.coin, map .. ": the shared catches bite too")
	end
	falsy(Fishing.livesIn("snapper", "slimy"), "a reef fish in the swamp")
end)

test("fishing: at most one coin a round, sizes in range, rarer fish bite faster", function()
	for i = 0, 199 do
		local id = Fishing.roll("blissful", (i + 0.5) / 200, (i * 7 % 200 + 0.5) / 200, false)
		truthy(id ~= "coin", "a second coin in a round")
	end
	for _, c in Fishing.catches do
		if c.size then
			for _, r in { 0, 0.5, 0.999 } do
				local cm = Fishing.sizeOf(c.id, r)
				truthy(cm >= c.size[1] and cm <= c.size[2], c.id .. " size " .. cm)
			end
		else
			eq(Fishing.sizeOf(c.id, 0.5), 0)
		end
	end
	truthy(Fishing.window("golden") < Fishing.window("swordfish"))
	truthy(Fishing.window("swordfish") < Fishing.window("sardine"))
	eq(Fishing.shadow("gar"), "large")
	eq(Fishing.sizeText(54), "54 cm")
	eq(Fishing.sizeText(150), "1.5 m")
end)

test("fishing: rarer fish fight harder, and the needle sweeps the whole meter", function()
	local common, rare, legend = Fishing.fight("sardine"), Fishing.fight("swordfish"), Fishing.fight("golden")
	truthy(common.reels <= rare.reels and rare.reels <= legend.reels, "rarer fish should take as many notches or more")
	truthy(common.zone > rare.zone and rare.zone > legend.zone, "rarer fish should have a smaller green")
	truthy(common.speed < rare.speed and rare.speed < legend.speed, "rarer fish should sweep faster")
	for _, c in Fishing.catches do
		local f = Fishing.fight(c.id)
		truthy(f.reels >= 1 and f.zone > 0 and f.zone < 1 and f.speed > 0, c.id .. " fights oddly")
		-- a whole fight fits in the time it's given, with room to spare
		truthy(f.reels * Fishing.ReelGap * 4 < Fishing.FightTime, c.id .. "'s fight can't be won in time")
	end
	local lo, hi = 1, 0
	for i = 0, 400 do
		local x = Fishing.needle(1.3, i / 100)
		lo, hi = math.min(lo, x), math.max(hi, x)
	end
	truthy(lo < 0.01 and hi > 0.99, "the needle doesn't reach both ends")
end)

test("fishing: filling the log earns the Fish School trail, then Master Angler", function()
	local half = math.ceil(#Fishing.logged / 2)
	eq(#Fishing.rewardsFor(half - 1), 0)
	eq(Fishing.rewardsFor(half)[1], "trail_school")
	local all = Fishing.rewardsFor(#Fishing.logged)
	eq(#all, 2)
	eq(all[2], "title_angler")
	for _, r in Fishing.Rewards do
		local def = Cosmetics.get(r.item)
		truthy(def and def.source == "fishing", r.item .. " should be a fishing reward")
	end
	-- the rewards aren't in Treasure Chests, the new trails are
	local pool = Cosmetics.chestPool()
	local inChests = {}
	for _, list in pool do
		for _, id in list do
			inChests[id] = true
		end
	end
	falsy(inChests.trail_school or inChests.title_angler, "a fishing reward in the chests")
	for _, id in { "trail_shells", "trail_confetti", "trail_feathers", "trail_snow", "trail_blossom", "trail_ink", "trail_paws", "trail_fireflies", "trail_shanty", "trail_wisps", "trail_doubloons", "trail_jewels", "trail_thunder" } do
		truthy(inChests[id], id .. " isn't in the chests")
	end
end)

test("ranked seasons: four weeks each, half the trophies carry over, a title for every rank", function()
	local Progress = requireModule("Shared/Meta/Progress")
	-- 23 October 2026 (Season 1 runs 22 October to 19 November)
	local launch = 20749 * 86400 + 12 * 3600
	eq(Progress.season(launch), 1)
	local ends = Progress.seasonEnds(1)
	eq(ends, 20776 * 86400, "Season 1 ends on 19 November")
	eq(Progress.season(ends - 1), 1)
	eq(Progress.season(ends), 2)
	eq(Progress.seasonEnds(2) - Progress.seasonEnds(1), 28 * 86400)
	eq(Progress.seasonCarry(1201), 600)
	eq(Progress.seasonCarry(0), 0)
	local pools = Cosmetics.chestPool()
	local inChests = {}
	for _, ids in pools do
		for _, id in ids do
			inChests[id] = true
		end
	end
	for season = 1, Progress.SeasonTitles do
		for _, r in Progress.ranks do
			local def = Cosmetics.get(Progress.seasonTitleId(season, r.id))
			if r.id == "wood" then
				eq(def, nil, "no title for Wood")
			else
				truthy(def ~= nil and def.category == "title" and def.hidden, "season " .. season .. " " .. r.id .. " title")
				falsy(inChests[def.id], "a season title in a chest")
				eq(Progress.seasonGems[r.id] > 0, true)
			end
		end
	end
end)

test("the beat-a-friend quest only comes up for players who play with friends", function()
	local Progress = requireModule("Shared/Meta/Progress")
	local sawFriend = false
	for day = 1, 400 do
		for _, q in Progress.dailyQuests(77, day, nil, false) do
			truthy(q.id ~= "friend", "a friend quest for someone who plays alone")
		end
		for _, q in Progress.dailyQuests(77, day, nil, true) do
			sawFriend = sawFriend or q.id == "friend"
		end
	end
	truthy(sawFriend, "the friend quest never came up")
	local q = Progress.questById.friend
	eq(Progress.questGain(q, { stats = { friendsBeaten = 2 } }), 2)
end)
