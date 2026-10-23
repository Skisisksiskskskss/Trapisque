--[[
	Progress
	The reasons to come back, as plain rules (no Roblox APIs, so they're tested offline):

		Mastery   every character levels up as you play them (titles and Gems on the way)
		Quests    three daily goals ("Bonk 5 rivals"), new every day, one free reroll
		Streak    log in on consecutive days for a bigger reward each day (a chest on day 7)
		Trophies  Quick Play results move your trophy count; trophies set your rank
		Seasons   ranked play runs in four-week seasons: the best rank you reach pays
		          out (and leaves you a title), then trophies carry over at half
		Events    a weekly twist on the rules, with its own Quick Play queue

	DataService applies these to profiles; the lobby shows them.
]]

local Progress = {}

local DAY = 86400

function Progress.today(now: number?): number
	return (now or os.time()) // DAY
end

-- A small deterministic shuffle so a player's daily quests don't change on rejoin.
local function lcg(seed: number)
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(n: number): number
		state = (state * 48271) % 2147483647
		return 1 + state % n
	end
end

---------------------------------------------------------------------------
-- Character mastery
---------------------------------------------------------------------------

-- XP needed to reach each mastery level (level 1 is where everyone starts).
Progress.masteryLevels = { 0, 120, 300, 550, 900, 1350, 1900, 2600, 3450, 4500 }
Progress.masteryMax = #Progress.masteryLevels

-- Rewards for reaching a mastery level: gems, and a title at 3, 6 and 10.
Progress.masteryTitles = { [3] = "fan", [6] = "pro", [10] = "legend" }
Progress.masteryTitleName = { fan = "Fan", pro = "Pro", legend = "Legend" }
-- The mastery level that dresses a character in their Gilded outfit (Cosmetics).
Progress.OutfitMastery = 8

-- Each character's own base (the stand under them on the board): it appears at
-- mastery 5 and turns gold at mastery 10. 0 = none yet, 1 = the base, 2 = gilded.
Progress.baseLevels = { 5, 10 }
function Progress.baseTier(level: number): number
	if level >= Progress.baseLevels[2] then
		return 2
	elseif level >= Progress.baseLevels[1] then
		return 1
	end
	return 0
end

function Progress.masteryGems(level: number): number
	return 20 + level * 10
end

-- Title cosmetic id for a character's mastery title.
function Progress.masteryTitleId(characterId: string, tier: string): string
	return "title_" .. characterId .. "_" .. tier
end

function Progress.masteryLevel(xp: number): number
	local level = 1
	for i, need in Progress.masteryLevels do
		if xp >= need then
			level = i
		end
	end
	return level
end

-- Progress through the current level: (xp into it, xp the level needs) or nil at max.
function Progress.masteryProgress(xp: number): (number, number?)
	local level = Progress.masteryLevel(xp)
	local here = Progress.masteryLevels[level]
	local nextNeed = Progress.masteryLevels[level + 1]
	if not nextNeed then
		return xp - here, nil
	end
	return xp - here, nextNeed - here
end

-- Mastery XP for one match with a character.
function Progress.masteryXp(result): number
	local s = result.stats or {}
	local xp = 30 + 15 * (result.treasures or 0) + (if result.won then 40 else 0)
	xp += 3 * math.min(10, (s.bonks or 0) + (s.gotchas or 0) + (s.abilities or 0))
	if result.practice then
		xp = math.floor(xp * 0.5)
	end
	return xp
end

---------------------------------------------------------------------------
-- Daily quests
---------------------------------------------------------------------------

--[[
	stat: which match stat counts (see Engine stats), "games", "wins", "treasures" or
	"char:<id>" (a match played as that character). goal, gems: the reward.
]]
Progress.questPool = {
	{ id = "games", text = "Play %d matches", stat = "games", goal = 3, gems = 40 },
	{ id = "win", text = "Win a match", stat = "wins", goal = 1, gems = 60 },
	{ id = "treasures", text = "Grab %d treasures", stat = "treasures", goal = 4, gems = 50 },
	{ id = "bonks", text = "Bonk %d rivals", stat = "bonks", goal = 5, gems = 45 },
	{ id = "gotchas", text = "Catch %d rivals with hidden traps", stat = "gotchas", goal = 3, gems = 55 },
	{ id = "kos", text = "Send a rival back to the Start with a trap", stat = "kos", goal = 1, gems = 60 },
	{ id = "abilities", text = "Use your ability %d times", stat = "abilities", goal = 6, gems = 40 },
	{ id = "played", text = "Play %d cards", stat = "played", goal = 10, gems = 40 },
	{ id = "spins", text = "Spin %d token wheels", stat = "spins", goal = 6, gems = 35 },
	{ id = "doubles", text = "Roll doubles %d times", stat = "doubles", goal = 3, gems = 35 },
	{ id = "bought", text = "Buy %d potions", stat = "bought", goal = 2, gems = 40 },
	-- (only for players who've played with friends)
	{ id = "friend", text = "Finish ahead of a friend in a match", stat = "friendsBeaten", goal = 1, gems = 50, friends = true },
	{ id = "char_mage", text = "Play a match as the Mage", stat = "char:mage", goal = 1, gems = 35 },
	{ id = "char_trapper", text = "Play a match as the Trapper", stat = "char:trapper", goal = 1, gems = 35 },
	{ id = "char_fire_starter", text = "Play a match as the Fire Starter", stat = "char:fire_starter", goal = 1, gems = 35 },
	{ id = "char_naturalist", text = "Play a match as the Naturalist", stat = "char:naturalist", goal = 1, gems = 35 },
	{ id = "char_warper", text = "Play a match as the Warper", stat = "char:warper", goal = 1, gems = 35 },
	{ id = "char_overseer", text = "Play a match as the Overseer", stat = "char:overseer", goal = 1, gems = 35 },
	{ id = "char_gambler", text = "Play a match as the Gambler", stat = "char:gambler", goal = 1, gems = 35 },
	{ id = "char_cannoneer", text = "Play a match as the Cannoneer", stat = "char:cannoneer", goal = 1, gems = 35 },
}
Progress.questById = {}
for _, q in Progress.questPool do
	Progress.questById[q.id] = q
end
Progress.QuestsPerDay = 3
Progress.QuestBonusChests = 1 -- finishing all of a day's quests: a free Explorer Chest

function Progress.questText(q): string
	return string.format(q.text, q.goal)
end

-- Today's quests for a player: three different ones, at most one "play as" quest, and
-- only for a character they can pick (`canPlay(characterId)`, if given). Quests about
-- friends only come up for players who play with friends (`withFriends`).
function Progress.dailyQuests(userId: number, day: number, canPlay: ((string) -> boolean)?, withFriends: boolean?): { any }
	local rand = lcg(userId * 7919 + day * 104729 + 17)
	local picked, out = {}, {}
	local charQuest = false
	local guard = 0
	while #out < Progress.QuestsPerDay and guard < 200 do
		guard += 1
		local q = Progress.questPool[rand(#Progress.questPool)]
		local isChar = string.sub(q.stat, 1, 5) == "char:"
		local playable = (not isChar or canPlay == nil or canPlay(string.sub(q.stat, 6))) and (not q.friends or withFriends == true)
		if not picked[q.id] and not (isChar and charQuest) and playable then
			picked[q.id] = true
			charQuest = charQuest or isChar
			table.insert(out, { id = q.id, progress = 0, done = false })
		end
	end
	return out
end

-- A replacement for quest slot `index` that isn't one of today's.
function Progress.rerollQuest(list, index: number, seed: number, canPlay: ((string) -> boolean)?, withFriends: boolean?)
	local rand = lcg(seed)
	local have = {}
	for _, q in list do
		have[q.id] = true
	end
	for _ = 1, 100 do
		local q = Progress.questPool[rand(#Progress.questPool)]
		local isChar = string.sub(q.stat, 1, 5) == "char:"
		if not have[q.id] and (not isChar or canPlay == nil or canPlay(string.sub(q.stat, 6))) and (not q.friends or withFriends == true) then
			return { id = q.id, progress = 0, done = false }
		end
	end
	return nil
end

-- How much a match moves a quest along.
function Progress.questGain(q, result): number
	local s = result.stats or {}
	local stat = q.stat
	if stat == "games" then
		return 1
	elseif stat == "wins" then
		return if result.won then 1 else 0
	elseif stat == "treasures" then
		return result.treasures or 0
	elseif string.sub(stat, 1, 5) == "char:" then
		return if result.character == string.sub(stat, 6) then 1 else 0
	end
	return s[stat] or 0
end

---------------------------------------------------------------------------
-- Login streak
---------------------------------------------------------------------------

-- Gems for each day of a streak (day 7 also gives a free chest), then it starts over.
Progress.streakGems = { 30, 40, 50, 60, 80, 100, 150 }
Progress.StreakChestDay = 7

-- The streak after logging in on `today`: (new count, reward day or nil if already paid).
function Progress.nextStreak(streak, today: number): (number, number?)
	local last = streak and streak.day or -10
	local count = streak and streak.count or 0
	if last == today then
		return count, nil
	end
	if last == today - 1 then
		count += 1
	else
		count = 1
	end
	local day = ((count - 1) % #Progress.streakGems) + 1
	return count, day
end

---------------------------------------------------------------------------
-- Trophies and ranks
---------------------------------------------------------------------------

Progress.ranks = {
	{ id = "wood", name = "Wood", min = 0, color = "#C98A4B" },
	{ id = "bronze", name = "Bronze", min = 100, color = "#E0874A" },
	{ id = "silver", name = "Silver", min = 300, color = "#C9D3E6" },
	{ id = "gold", name = "Gold", min = 600, color = "#FFD23F" },
	{ id = "diamond", name = "Diamond", min = 1000, color = "#45C3FF" },
	{ id = "legend", name = "Legend", min = 1600, color = "#FF6FB8" },
}

function Progress.rank(trophies: number)
	local best = Progress.ranks[1]
	for _, r in Progress.ranks do
		if trophies >= r.min then
			best = r
		end
	end
	return best
end

--[[
	Trophies won or lost in a Quick Play match. Free-for-all: by finishing place (the
	winner gains the most, last place loses a few). Teams: win or lose. Nobody drops
	below zero, and low ranks lose less so new players aren't punished.
]]
function Progress.trophyDelta(place: number, players: number, won: boolean, team: boolean, trophies: number): number
	local delta
	if team then
		delta = if won then 8 else -3
	elseif players <= 1 then
		delta = 0
	else
		local t = (place - 1) / (players - 1) -- 0 for the winner, 1 for last
		delta = math.floor(10 - 15 * t + 0.5)
	end
	if delta < 0 and trophies < 100 then
		delta = math.ceil(delta / 2)
	end
	return math.max(delta, -trophies)
end

-- The friend just ahead of you on the trophies board is your rival for the week (weeks
-- start on Thursday): pass them for this many Gems, once a week.
Progress.RivalGems = 100

function Progress.week(now: number?): number
	return (now or os.time()) // (7 * DAY)
end

---------------------------------------------------------------------------
-- Ranked seasons
---------------------------------------------------------------------------

--[[
	Ranked Quick Play runs in seasons of four weeks, Thursday to Thursday. When one ends,
	the best rank you reached in it pays out: Gems, a free chest from Gold up, and a
	title to wear ("Season 2 Gold"). Your trophies drop to half for the next one.
]]
Progress.SeasonDays = 28
-- The 28-day block (counted from 1 January 1970, a Thursday) that is Season 1.
Progress.FirstSeasonBlock = 741
-- Seasons with titles made for them (Cosmetics: title_s<season>_<rank>).
Progress.SeasonTitles = 24
Progress.seasonGems = { wood = 0, bronze = 50, silver = 100, gold = 200, diamond = 350, legend = 500 }
Progress.seasonChest = { gold = "explorer", diamond = "explorer", legend = "royal" }

function Progress.season(now: number?): number
	local block = (now or os.time()) // (Progress.SeasonDays * DAY)
	return math.max(1, block - Progress.FirstSeasonBlock + 1)
end

-- When season `n` ends (Unix time).
function Progress.seasonEnds(n: number): number
	return (Progress.FirstSeasonBlock + n) * Progress.SeasonDays * DAY
end

function Progress.seasonTitleId(n: number, rankId: string): string
	return "title_s" .. n .. "_" .. rankId
end

-- The trophies you take into the next season.
function Progress.seasonCarry(trophies: number): number
	return math.floor(trophies / 2)
end

---------------------------------------------------------------------------
-- Weekly events
---------------------------------------------------------------------------

--[[
	Each week Quick Play has an event queue with a twist on the rules. The engine reads
	the twist from `mutator` (Engine.new opts.mutator).
]]
Progress.events = {
	{
		id = "trap_frenzy",
		name = "Trap Frenzy",
		blurb = "Everyone starts with two hidden traps, and traps reach twice as far.",
		mutator = { startTraps = 2, trapRange = 10 },
		color = "#FF4F5E",
	},
	{
		id = "bonk_bonanza",
		name = "Bonk Bonanza",
		blurb = "Bonks knock rivals back 4 tiles!",
		mutator = { bonkBack = 4 },
		color = "#FF9A3C",
	},
	{
		id = "power_surge",
		name = "Power Surge",
		blurb = "Power charges twice as fast. Abilities everywhere!",
		mutator = { powerMult = 2 },
		color = "#FFD23F",
	},
	{
		id = "triple_dice",
		name = "Triple Dice",
		blurb = "Roll three dice and pick one. The highest leftover charges your Power.",
		mutator = { diceCount = 3 },
		color = "#45C3FF",
	},
}

-- This week's event (weeks start on Thursday, Unix epoch week).
-- The owner can switch this week's event (staff panel); every server and client sets this.
Progress.eventOverride = nil :: string?

function Progress.currentEvent(now: number?)
	if Progress.eventOverride then
		for _, e in Progress.events do
			if e.id == Progress.eventOverride then
				return e
			end
		end
	end
	local week = (now or os.time()) // (7 * DAY)
	return Progress.events[(week % #Progress.events) + 1]
end

function Progress.eventById(id: string?)
	for _, e in Progress.events do
		if e.id == id then
			return e
		end
	end
	return nil
end

return Progress
