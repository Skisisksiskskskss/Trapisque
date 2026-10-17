--[[
	DataService
	Player profiles (Gems, levels, stats, cosmetics, settings), gamepass ownership and
	the paid-random-items policy check.

	It also runs the reasons to come back (rules in Shared/Meta/Progress): the character
	you play, character mastery, daily quests, the login streak and trophies.

	Profiles are saved with a lightweight session lock so a player who teleports between
	servers can't be loaded in two places at once (which would lose progress).
	In Studio without API access, profiles live in memory only.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Gacha = require(Shared.Meta.Gacha)
local Voices = require(Shared.Meta.Voices)
local Passes = require(Shared.Meta.Passes)
local Progress = require(Shared.Meta.Progress)
local DailyShop = require(Shared.Meta.DailyShop)
local Tutorial = require(Shared.Meta.Tutorial)
local Characters = require(Shared.Game.Characters)

local ServerInfo = require(script.Parent.ServerInfo)
local Net = require(script.Parent.Net)

local DataService = {}

local store: DataStore? = nil
local profiles = {} -- [Player] = { data, temp, loaded }
local loadedSignal = Instance.new("BindableEvent")

---------------------------------------------------------------------------
-- profile shape
---------------------------------------------------------------------------

local function newProfile()
	local owned = {}
	for _, id in Cosmetics.fromSource("default") do
		owned[id] = true
	end
	return {
		v = 1,
		gems = Config.Rewards.StartingGems,
		xp = 0,
		level = 1,
		stats = { games = 0, wins = 0, treasures = 0, deaths = 0, placed = 0, practice = 0, bonks = 0, gotchas = 0 },
		character = Characters.ids[1], -- the character you play in matches
		mastery = {}, -- [characterId] = mastery XP
		quests = { day = -1, list = {}, rerolled = false, bonus = false },
		streak = { day = -10, count = 0 },
		trophies = 0,
		bestTrophies = 0,
		owned = owned,
		equipped = {
			accessory = Cosmetics.defaults.accessory,
			dice = Cosmetics.defaults.dice,
			trail = Cosmetics.defaults.trail,
			title = Cosmetics.defaults.title,
			emotes = table.clone(Cosmetics.defaults.emotes),
		},
		pity = { explorer = {}, royal = {} },
		granted = {}, -- [passKey] = true: passes the owner gave this player
		freeChests = { explorer = Config.Rewards.StartingFreeChests },
		chestsOpened = 0,
		lastDaily = 0,
		settings = { sfx = true, music = true, sfxVolume = 1, musicVolume = 0.7, autoRoll = false, fastAnim = false, voices = true, bubbles = true, voice = "auto" },
		badges = {}, -- [badge key] = when it was earned (Meta/Badges)
		fish = {}, -- [catch id] = how many (the fish log, Meta/Fishing)
		tutorialDone = false, -- finished (or skipped) the guided first match
		groupReward = false, -- claimed the join-the-group Gems
		deals = { day = -1, bought = {} }, -- today's daily deals already bought
	}
end

-- Fill in anything missing from older saves.
local function reconcile(data)
	local fresh = newProfile()
	for k, v in fresh do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "owned" and k ~= "emotes" then
			for k2, v2 in v do
				if data[k][k2] == nil then
					data[k][k2] = v2
				end
			end
		end
	end
	for _, id in Cosmetics.fromSource("default") do
		data.owned[id] = true
	end
	-- pawn skins became accessories: each retired pawn won from a chest is paid back
	-- as if it had been a duplicate
	for id, rarity in Cosmetics.retired do
		if data.owned[id] then
			data.owned[id] = nil
			data.gems = (data.gems or 0) + (Gacha.dupeRefund[rarity] or 0)
		end
	end
	data.equipped.pawn = nil
	-- drop ids that no longer exist
	for id in data.owned do
		if Cosmetics.get(id) == nil then
			data.owned[id] = nil
		end
	end
	for _, cat in { "accessory", "dice", "trail", "title" } do
		local id = data.equipped[cat]
		if id == nil or not data.owned[id] or Cosmetics.get(id) == nil then
			data.equipped[cat] = Cosmetics.defaults[cat]
		end
	end
	local emotes = {}
	for _, id in data.equipped.emotes or {} do
		if data.owned[id] and #emotes < Cosmetics.EmoteSlots then
			table.insert(emotes, id)
		end
	end
	if #emotes == 0 then
		emotes = table.clone(Cosmetics.defaults.emotes)
	end
	data.equipped.emotes = emotes
	if Characters.get(data.character) == nil then
		data.character = Characters.ids[1]
	end
	return data
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

---------------------------------------------------------------------------
-- load / save with session lock
---------------------------------------------------------------------------

local function loadData(player: Player)
	if not store then
		return newProfile(), true
	end
	local lockTimeout = Config.Data.LockTimeout
	for attempt = 1, 10 do
		local result, locked = nil, false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player), function(old)
				local data = old or newProfile()
				local lock = data._lock
				if lock and lock.job ~= game.JobId and os.time() - (lock.t or 0) < lockTimeout and attempt < 10 then
					locked = true
					result = nil
					return nil
				end
				data._lock = { job = game.JobId, t = os.time() }
				result = data
				locked = false
				return data
			end)
		end)
		if ok and result then
			return reconcile(result), false
		end
		if not ok then
			warn("[Trapisque] profile load failed (" .. attempt .. "): " .. tostring(err))
		end
		if player.Parent ~= Players then
			return nil, true
		end
		task.wait(if locked then 3 else 1.5)
	end
	warn("[Trapisque] could not load profile for " .. player.Name .. "; using a temporary one")
	return newProfile(), true
end

local function saveData(player: Player, release: boolean)
	local prof = profiles[player]
	if not prof or prof.temp or not store then
		return true
	end
	local data = prof.data
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			if old and old._lock and old._lock.job ~= game.JobId then
				-- another server owns this profile now; never clobber it
				return nil
			end
			data._lock = if release then nil else { job = game.JobId, t = os.time() }
			return data
		end)
	end)
	if not ok then
		warn("[Trapisque] profile save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

---------------------------------------------------------------------------
-- gamepasses & policy
---------------------------------------------------------------------------

local function ownsPass(player: Player, passKey: string): boolean
	local id = Passes.id(passKey)
	if id == 0 then
		return ServerInfo.isStudio and Config.StudioOwnsAllPasses
	end
	if ServerInfo.isStudio and Config.StudioOwnsAllPasses then
		return true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns == true
end

local function grantPassPerks(prof)
	local data = prof.data
	if prof.passes.VIP then
		for _, id in Cosmetics.fromSource("vip") do
			data.owned[id] = true
		end
	end
	if prof.passes.EmotePack then
		for _, id in Cosmetics.fromSource("emotepack") do
			data.owned[id] = true
		end
	end
	if prof.passes.CaptainsChest then
		for _, id in Cosmetics.fromSource("captain") do
			data.owned[id] = true
		end
	end
end

local function refreshPasses(player: Player)
	local prof = profiles[player]
	if not prof then
		return
	end
	local granted = prof.data.granted or {}
	for _, pass in Passes.list do
		prof.passes[pass.key] = granted[pass.key] == true or ownsPass(player, pass.key)
	end
	grantPassPerks(prof)
end

local function checkPolicy(player: Player): boolean
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok or type(info) ~= "table" then
		return true -- if we can't tell, be safe and treat paid random items as restricted
	end
	return info.ArePaidRandomItemsRestricted == true
end

---------------------------------------------------------------------------
-- public API
---------------------------------------------------------------------------

function DataService.get(player: Player)
	local prof = profiles[player]
	return prof and prof.data
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Waits (up to `timeout` seconds) for a player's profile; true once it's there.
function DataService.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player] ~= nil
end

function DataService.passes(player: Player)
	local prof = profiles[player]
	return prof and prof.passes or {}
end

function DataService.hasPass(player: Player, passKey: string): boolean
	local prof = profiles[player]
	return prof ~= nil and prof.passes[passKey] == true
end

function DataService.randomItemsRestricted(player: Player): boolean
	local prof = profiles[player]
	return prof == nil or prof.restricted == true
end

-- Lucky Charm only counts where paid random items are allowed.
function DataService.isLucky(player: Player): boolean
	local prof = profiles[player]
	return prof ~= nil and prof.passes.LuckyCharm == true and not prof.restricted
end

-- The view of the profile that the client sees.
function DataService.view(player: Player)
	local prof = profiles[player]
	if not prof then
		return nil
	end
	local data = prof.data
	local owned = {}
	for id in data.owned do
		table.insert(owned, id)
	end
	local passes = {}
	for k, v in prof.passes do
		if v then
			table.insert(passes, k)
		end
	end
	local quests = DataService.questView(player)
	return {
		gems = data.gems,
		xp = data.xp,
		level = data.level,
		xpNext = Config.xpForLevel(data.level),
		stats = table.clone(data.stats),
		owned = owned,
		equipped = {
			accessory = data.equipped.accessory,
			dice = data.equipped.dice,
			trail = data.equipped.trail,
			title = data.equipped.title,
			emotes = table.clone(data.equipped.emotes),
		},
		pity = {
			explorer = table.clone(data.pity.explorer or {}),
			royal = table.clone(data.pity.royal or {}),
		},
		freeChests = table.clone(data.freeChests),
		chestsOpened = data.chestsOpened,
		passes = passes,
		restricted = prof.restricted,
		settings = table.clone(data.settings),
		temp = prof.temp,
		character = data.character,
		mastery = table.clone(data.mastery),
		quests = quests,
		questRerolled = data.quests.rerolled,
		questBonus = data.quests.bonus,
		streak = { count = data.streak.count, day = data.streak.day, today = Progress.today() },
		trophies = data.trophies,
		bestTrophies = data.bestTrophies,
		badges = table.clone(data.badges),
		fish = table.clone(data.fish),
		tutorialDone = data.tutorialDone,
		groupReward = data.groupReward,
		deals = DataService.dealsView(data),
	}
end

-- Today's daily deals, with the ones already bought marked.
function DataService.dealsView(data)
	local today = DailyShop.today()
	if data.deals.day ~= today then
		data.deals = { day = today, bought = {} }
	end
	local items = {}
	for _, d in DailyShop.deals(today) do
		table.insert(items, { id = d.id, price = d.price, bought = data.deals.bought[d.id] == true })
	end
	return { day = today, items = items, endsIn = DailyShop.secondsLeft() }
end

-- Today's quests (made fresh on a new day).
local function ensureQuests(player: Player, data)
	local today = Progress.today()
	if data.quests.day ~= today then
		data.quests = {
			day = today,
			list = Progress.dailyQuests(player.UserId, today, function(id)
				return Characters.unlocked(id, data.level)
			end),
			rerolled = false,
			bonus = false,
		}
	end
	return data.quests
end

-- The quests as the lobby shows them.
function DataService.questView(player: Player)
	local data = DataService.get(player)
	if not data then
		return {}
	end
	local out = {}
	for i, q in ensureQuests(player, data).list do
		local def = Progress.questById[q.id]
		if def then
			table.insert(out, {
				index = i,
				id = q.id,
				text = Progress.questText(def),
				goal = def.goal,
				gems = def.gems,
				progress = math.min(q.progress, def.goal),
				done = q.done,
			})
		end
	end
	return out
end

-- The character a player takes into matches (one they've unlocked).
function DataService.selectedCharacter(player: Player): string
	local data = DataService.get(player)
	local id = data and data.character
	if id and Characters.get(id) and Characters.unlocked(id, data.level) then
		return id
	end
	return Characters.ids[1]
end

function DataService.selectCharacter(player: Player, id: any)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	local def = type(id) == "string" and Characters.get(id)
	if not def then
		return false, "Unknown character."
	end
	if not Characters.unlocked(id, data.level) then
		return false, string.format("Reach level %d to unlock the %s.", def.unlockLevel or 0, def.name)
	end
	data.character = id
	return true
end

-- Swap one of today's quests for another (once a day, not finished ones).
function DataService.rerollQuest(player: Player, index: any)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	local quests = ensureQuests(player, data)
	local q = type(index) == "number" and quests.list[index]
	if not q then
		return false, "Pick a quest."
	end
	if quests.rerolled then
		return false, "You've already swapped a quest today."
	end
	if q.done then
		return false, "That quest is already done."
	end
	local fresh = Progress.rerollQuest(quests.list, index, player.UserId + quests.day * 31 + index, function(id)
		return Characters.unlocked(id, data.level)
	end)
	if not fresh then
		return false, "No other quests to swap in."
	end
	quests.list[index] = fresh
	quests.rerolled = true
	return true
end

function DataService.pushProfile(player: Player)
	local view = DataService.view(player)
	if view then
		Net.push(player, "profile", view)
	end
end

-- Cosmetic look for other players to see (party lists, match seats).
function DataService.publicLook(player: Player)
	local data = DataService.get(player)
	local vip = DataService.hasPass(player, "VIP")
	if not data then
		return { accessory = Cosmetics.defaults.accessory, dice = Cosmetics.defaults.dice, trail = Cosmetics.defaults.trail, title = Cosmetics.defaults.title, level = 1, vip = false }
	end
	return {
		accessory = data.equipped.accessory,
		dice = data.equipped.dice,
		trail = data.equipped.trail,
		title = data.equipped.title,
		emotes = table.clone(data.equipped.emotes),
		level = data.level,
		vip = vip,
		-- the base your character stands on: earned with mastery (Progress.baseTier)
		base = Progress.baseTier(Progress.masteryLevel(data.mastery[DataService.selectedCharacter(player)] or 0)),
	}
end

-- A catch for the fish log; returns how many of it they have now.
function DataService.addCatch(player: Player, catchId: string): number
	local data = DataService.get(player)
	if not data or catchId == "coin" then
		return 0
	end
	data.fish[catchId] = (data.fish[catchId] or 0) + 1
	return data.fish[catchId]
end

-- Buy one of today's daily deals.
function DataService.buyDeal(player: Player, itemId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	local view = DataService.dealsView(data)
	local deal = nil
	for _, d in view.items do
		if d.id == itemId then
			deal = d
		end
	end
	if not deal then
		return false, "That deal is gone. New deals every day!"
	end
	if data.owned[deal.id] then
		return false, "You already have that one."
	end
	if data.gems < deal.price then
		return false, "Not enough Gems."
	end
	data.gems -= deal.price
	data.owned[deal.id] = true
	data.deals.bought[deal.id] = true
	return true, nil
end

-- The join-the-group reward, once.
function DataService.claimCommunity(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	if data.groupReward then
		return false, "You already got this reward. Thanks for being in the crew!"
	end
	local groupId = Config.Community.GroupId
	if (groupId or 0) == 0 and game.CreatorType == Enum.CreatorType.Group then
		groupId = game.CreatorId
	end
	if (groupId or 0) == 0 then
		return false, "There's no group to join yet."
	end
	local ok, member = pcall(function()
		return (player :: any):IsInGroupAsync(groupId)
	end)
	if not ok then
		ok, member = pcall(function()
			return player:IsInGroup(groupId)
		end)
	end
	if not ok then
		return false, "Couldn't check right now. Try again in a moment."
	end
	if not member then
		return false, "Join the group first, then claim!"
	end
	data.groupReward = true
	data.gems += Config.Community.Gems
	return true, nil
end

-- Fires (player) when a profile has loaded.
DataService.loaded = loadedSignal.Event

---------------------------------------------------------------------------
-- staff tools (AdminService checks who may use them)
---------------------------------------------------------------------------

-- Give (or take back) a gamepass's perks without a purchase.
function DataService.grantPass(player: Player, passKey: string, on: boolean): boolean
	local prof = profiles[player]
	if not prof or not Passes.byKey[passKey] then
		return false
	end
	prof.data.granted = prof.data.granted or {}
	prof.data.granted[passKey] = if on then true else nil
	refreshPasses(player)
	DataService.pushProfile(player)
	return true
end

function DataService.giveItem(player: Player, itemId: string): boolean
	local data = DataService.get(player)
	if not data or not Cosmetics.get(itemId) then
		return false
	end
	data.owned[itemId] = true
	DataService.pushProfile(player)
	return true
end

function DataService.giveEverything(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	for _, def in Cosmetics.list do
		data.owned[def.id] = true
	end
	DataService.pushProfile(player)
	return true
end

function DataService.giveChests(player: Player, chestId: string, count: number): boolean
	local data = DataService.get(player)
	if not data or (chestId ~= "explorer" and chestId ~= "royal") then
		return false
	end
	data.freeChests[chestId] = math.max(0, (data.freeChests[chestId] or 0) + math.floor(count))
	DataService.pushProfile(player)
	return true
end

-- What the staff panel shows about someone.
function DataService.summary(player: Player)
	local prof = profiles[player]
	if not prof then
		return { userId = player.UserId, name = player.DisplayName, username = player.Name, loading = true }
	end
	local data = prof.data
	local passes, granted = {}, {}
	for key, on in prof.passes do
		if on then
			table.insert(passes, key)
		end
	end
	for key in data.granted or {} do
		table.insert(granted, key)
	end
	local owned = 0
	for _ in data.owned do
		owned += 1
	end
	return {
		userId = player.UserId,
		name = player.DisplayName,
		username = player.Name,
		level = data.level,
		gems = data.gems,
		trophies = data.trophies or 0,
		games = (data.stats.games or 0) + (data.stats.practice or 0),
		wins = data.stats.wins or 0,
		character = data.character,
		passes = passes,
		granted = granted,
		owned = owned,
		freeChests = table.clone(data.freeChests),
	}
end

-- The voice someone's chat bubbles speak in: their pick with the Voice Pack, else
-- "auto" (their character's own).
function DataService.voiceOf(player: Player): string
	local data = DataService.get(player)
	local v = data and data.settings and data.settings.voice
	if type(v) == "string" and Voices.byId[v] and DataService.hasPass(player, "VoicePack") then
		return v
	end
	return "auto"
end

function DataService.addGems(player: Player, amount: number)
	local data = DataService.get(player)
	if data then
		data.gems = math.max(0, data.gems + math.floor(amount))
	end
end

function DataService.equip(player: Player, category: string, value: any)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	if category == "emotes" then
		if type(value) ~= "table" or #value < 1 or #value > Cosmetics.EmoteSlots then
			return false, "Pick 1 to " .. Cosmetics.EmoteSlots .. " emotes."
		end
		local list, seen = {}, {}
		for _, id in value do
			local def = type(id) == "string" and Cosmetics.get(id)
			if not def or def.category ~= "emote" or not data.owned[id] then
				return false, "You don't own that emote."
			end
			if not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
		data.equipped.emotes = list
		return true
	end
	if category ~= "accessory" and category ~= "dice" and category ~= "trail" and category ~= "title" then
		return false, "Unknown slot."
	end
	local def = type(value) == "string" and Cosmetics.get(value)
	if not def or def.category ~= category then
		return false, "That item doesn't fit there."
	end
	if not data.owned[value] then
		return false, "You don't own that yet."
	end
	data.equipped[category] = value
	return true
end

function DataService.saveSettings(player: Player, settings)
	local data = DataService.get(player)
	if not data or type(settings) ~= "table" then
		return false
	end
	for k, current in data.settings do
		local v = settings[k]
		if type(current) == "boolean" and type(v) == "boolean" then
			data.settings[k] = v
		elseif type(current) == "number" and type(v) == "number" and v == v then
			-- volumes (0..1)
			data.settings[k] = math.clamp(v, 0, 1)
		elseif k == "voice" and type(v) == "string" and Voices.byId[v] then
			-- picking a voice is the Voice Pack's (your character's own voice is free)
			if v == "auto" or DataService.hasPass(player, "VoicePack") then
				data.settings.voice = v
			end
		end
	end
	return true
end

-- Mastery XP for the character played; returns what changed.
local function applyMastery(data, result)
	local charId = result.character
	if not charId or Characters.get(charId) == nil then
		return nil
	end
	local before = data.mastery[charId] or 0
	local gain = Progress.masteryXp(result)
	local after = before + gain
	data.mastery[charId] = after
	local oldLevel, newLevel = Progress.masteryLevel(before), Progress.masteryLevel(after)
	local gems, titles = 0, {}
	for level = oldLevel + 1, newLevel do
		gems += Progress.masteryGems(level)
		local tier = Progress.masteryTitles[level]
		if tier then
			local id = Progress.masteryTitleId(charId, tier)
			if Cosmetics.get(id) and not data.owned[id] then
				data.owned[id] = true
				table.insert(titles, id)
			end
		end
	end
	data.gems += gems
	local into, need = Progress.masteryProgress(after)
	return {
		character = charId,
		xp = gain,
		level = newLevel,
		levelsGained = newLevel - oldLevel,
		into = into,
		need = need,
		gems = gems,
		titles = titles,
	}
end

-- Daily quests move along; finished ones pay out right away.
local function applyQuests(player: Player, data, result)
	local quests = ensureQuests(player, data)
	local out, gems, chest = {}, 0, false
	for i, q in quests.list do
		local def = Progress.questById[q.id]
		if def and not q.done then
			local gain = Progress.questGain(def, result)
			if gain > 0 then
				q.progress = math.min(def.goal, q.progress + gain)
				local finished = q.progress >= def.goal
				if finished then
					q.done = true
					gems += def.gems
				end
				table.insert(out, { index = i, text = Progress.questText(def), progress = q.progress, goal = def.goal, done = finished, gems = def.gems })
			end
		end
	end
	data.gems += gems
	local allDone = #quests.list > 0
	for _, q in quests.list do
		allDone = allDone and q.done
	end
	if allDone and not quests.bonus then
		quests.bonus = true
		chest = true
		data.freeChests.explorer = (data.freeChests.explorer or 0) + Progress.QuestBonusChests
	end
	return { changed = out, gems = gems, chest = chest }
end

-- Trophies from a ranked (public free-for-all) match.
local function applyTrophies(data, result)
	if not result.ranked or result.practice then
		return nil
	end
	local before = data.trophies
	local delta = Progress.trophyDelta(result.place or result.players or 1, result.players or 1, result.won == true, result.team == true, before)
	data.trophies = math.max(0, before + delta)
	data.bestTrophies = math.max(data.bestTrophies, data.trophies)
	local oldRank, newRank = Progress.rank(before), Progress.rank(data.trophies)
	return { delta = delta, total = data.trophies, rank = newRank.id, rankUp = newRank.min > oldRank.min }
end

--[[
	Rewards for a finished match. result = { treasures, won, practice, ranked, place,
	players, character, mode, event, stats (the engine's per-player stats) }.
	Returns a summary for the results screen.
]]
function DataService.applyMatchResult(player: Player, result)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local R = Config.Rewards
	local stats = result.stats or {}
	local gems = R.MatchGems + R.TreasureGems * result.treasures + (if result.won then R.WinGems else 0)
	local xp = R.MatchXP + R.TreasureXP * result.treasures + (if result.won then R.WinXP else 0)
	if result.practice then
		gems *= R.PracticeMultiplier
		xp *= R.PracticeMultiplier
	end
	local bonus = {}
	if DataService.hasPass(player, "VIP") then
		gems *= 1 + R.VIPGemBonus
		table.insert(bonus, "VIP +" .. math.floor(R.VIPGemBonus * 100) .. "%")
	end
	if DataService.hasPass(player, "DoubleGems") then
		gems *= R.DoubleGemsMultiplier
		table.insert(bonus, "2x Gems")
	end
	gems = math.floor(gems)
	xp = math.floor(xp)
	-- the guided first match pays once
	local tutorialGems = 0
	if result.tutorial and not data.tutorialDone then
		data.tutorialDone = true
		tutorialGems = Tutorial.Gems
		data.gems += tutorialGems
	end

	data.gems += gems
	data.xp += xp
	local levelBefore = data.level
	local levelsGained = 0
	while data.xp >= Config.xpForLevel(data.level) do
		data.xp -= Config.xpForLevel(data.level)
		data.level += 1
		levelsGained += 1
		data.gems += R.LevelUpGems
	end

	local s = data.stats
	if result.practice then
		s.practice += 1
	else
		s.games += 1
		if result.won then
			s.wins += 1
		end
	end
	s.treasures += result.treasures
	s.deaths += stats.deaths or 0
	s.placed += stats.placed or 0
	s.bonks += stats.bonks or 0
	s.gotchas += stats.gotchas or 0

	local mastery = applyMastery(data, result)
	local quests = applyQuests(player, data, result)
	local trophies = applyTrophies(data, result)

	-- characters that unlocked with this level-up
	local unlocked = {}
	for _, def in Characters.list do
		if def.unlockLevel and levelBefore < def.unlockLevel and data.level >= def.unlockLevel then
			table.insert(unlocked, def.id)
		end
	end

	return {
		gems = gems + levelsGained * R.LevelUpGems + tutorialGems,
		xp = xp,
		levelsGained = levelsGained,
		level = data.level,
		bonus = bonus,
		mastery = mastery,
		quests = quests,
		trophies = trophies,
		unlocked = unlocked,
		tutorialGems = if tutorialGems > 0 then tutorialGems else nil,
	}
end

function DataService.save(player: Player, release: boolean?)
	return saveData(player, release == true)
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- Logging in on consecutive days pays more each day (Progress.streakGems); day 7 adds
-- a free chest. VIPs also get a free Explorer Chest every day.
local function loginStreak(player: Player)
	local prof = profiles[player]
	local data = prof.data
	local today = Progress.today()
	local count, rewardDay = Progress.nextStreak(data.streak, today)
	if not rewardDay then
		return
	end
	data.streak = { day = today, count = count }
	data.lastDaily = today
	local gems = Progress.streakGems[rewardDay]
	data.gems += gems
	local msg = "Day " .. count .. " streak: +" .. gems .. " Gems"
	if rewardDay == Progress.StreakChestDay then
		data.freeChests.explorer = (data.freeChests.explorer or 0) + 1
		msg ..= " and a free Explorer Chest!"
	end
	if prof.passes.VIP then
		data.freeChests.explorer = (data.freeChests.explorer or 0) + 1
		msg ..= " (VIP: +1 free Explorer Chest)"
	end
	ensureQuests(player, data)
	task.delay(4, function()
		Net.push(player, "toast", { text = msg, kind = "reward" })
	end)
end

local function onPlayerAdded(player: Player)
	local data, temp = loadData(player)
	if not data or player.Parent ~= Players then
		return
	end
	local prof = { data = data, temp = temp, passes = {}, restricted = true }
	profiles[player] = prof
	prof.restricted = checkPolicy(player)
	refreshPasses(player)
	loginStreak(player)
	loadedSignal:Fire(player)
	DataService.pushProfile(player)
	if temp and store then
		Net.push(player, "toast", { text = "We couldn't load your save. Progress this session may not be kept.", kind = "error" })
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveData(player, true)
		profiles[player] = nil
	end
end

function DataService.init()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = ds
		-- In Studio without "Enable Studio Access to API Services" (or in a place that
		-- isn't published), DataStore calls fail or never answer: give them 4 seconds.
		if ServerInfo.isStudio then
			local answered, probeOk = false, false
			task.spawn(function()
				probeOk = pcall(function()
					ds:GetAsync("__probe")
				end)
				answered = true
			end)
			local deadline = os.clock() + 4
			while not answered and os.clock() < deadline do
				task.wait(0.05)
			end
			if not probeOk then
				warn("[Trapisque] DataStores unavailable in Studio; profiles are temporary. Enable Game Settings > Security > Studio Access to API Services to test saving.")
				store = nil
			end
		end
	else
		warn("[Trapisque] DataStoreService unavailable: " .. tostring(ds))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and profiles[player] then
			local passKey = Passes.keyForId(passId)
			if passKey then
				profiles[player].passes[passKey] = true
				grantPassPerks(profiles[player])
				DataService.pushProfile(player)
				Net.push(player, "toast", { text = "Thanks! " .. Passes.byKey[passKey].name .. " is now active.", kind = "reward" })
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in profiles do
				task.spawn(saveData, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveData(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)

	Net.handle("profile.get", function(player)
		return true, DataService.view(player)
	end)

	Net.handle("locker.equip", function(player, payload)
		local ok2, err = DataService.equip(player, payload.category, payload.value)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
		return true
	end)

	Net.handle("settings.save", function(player, payload)
		DataService.saveSettings(player, payload.settings)
		return true
	end)

	Net.handle("character.select", function(player, payload)
		local ok2, err = DataService.selectCharacter(player, payload.character)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
		return true
	end)

	Net.handle("quests.reroll", function(player, payload)
		local ok2, err = DataService.rerollQuest(player, payload.index)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
		return true
	end)

	Net.handle("shop.refresh", function(player)
		refreshPasses(player)
		DataService.pushProfile(player)
		return true
	end)

	Net.handle("shop.deal", function(player, payload)
		local ok2, err = DataService.buyDeal(player, payload.id)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
		return true
	end)

	Net.handle("community.claim", function(player)
		local ok2, err = DataService.claimCommunity(player)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
		return true, { gems = Config.Community.Gems }
	end)

	-- skipping the guided match counts as done (it stays in How to Play)
	Net.handle("tutorial.skip", function(player)
		local data = DataService.get(player)
		if data then
			data.tutorialDone = true
			DataService.pushProfile(player)
		end
		return true
	end)
end

return DataService
