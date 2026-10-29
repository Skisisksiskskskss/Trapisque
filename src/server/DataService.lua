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
local Passes = require(Shared.Meta.Passes)
local Progress = require(Shared.Meta.Progress)
local DailyShop = require(Shared.Meta.DailyShop)
local Fishing = require(Shared.Meta.Fishing)
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
		stats = { games = 0, wins = 0, treasures = 0, deaths = 0, placed = 0, practice = 0, bonks = 0, gotchas = 0, friendGames = 0 },
		rival = { week = -1, userId = 0, name = "", target = 0, done = false }, -- this week's friend to pass (Progress.RivalGems)
		character = Characters.ids[1], -- the character you play in matches
		mastery = {}, -- [characterId] = mastery XP
		awards = {}, -- [awardId] = how many times you've won it (Shared/Game/Awards)
		quests = { day = -1, list = {}, rerolled = false, bonus = false },
		streak = { day = -10, count = 0 },
		trophies = 0,
		bestTrophies = 0,
		season = { id = 0, best = 0 }, -- the ranked season your trophies are in, and your best in it
		seasonNews = nil, -- how the last season you played ended, until you've seen it
		owned = owned,
		equipped = {
			finish = Cosmetics.defaults.finish,
			dice = Cosmetics.defaults.dice,
			trail = Cosmetics.defaults.trail,
			title = Cosmetics.defaults.title,
			emotes = table.clone(Cosmetics.defaults.emotes),
			emblems = {}, -- [characterId] = emblem id (none: Classic)
		},
		pity = { explorer = {}, royal = {} },
		granted = {}, -- [passKey] = true: passes the owner gave this player
		passGifts = {}, -- [passKey] = true: that pass's one-time gift is handed over
		receipts = {}, -- the latest Gem pack purchase ids (each one granted once)
		freeChests = { explorer = Config.Rewards.StartingFreeChests },
		chestsOpened = 0,
		lastDaily = 0,
		settings = { sfx = true, music = true, sfxVolume = 1, musicVolume = 0.7, autoRoll = false, fastAnim = false, bubbles = true },
		badges = {}, -- [badge key] = when it was earned (Meta/Badges)
		fish = {}, -- [catch id] = how many (the fish log, Meta/Fishing)
		fishBest = {}, -- [catch id] = the biggest one landed, in centimetres
		fishGems = 0, -- Gems from fishing today (Fishing.GemsPerDay at most)
		fishGemsDay = 0, -- which day that was (days since 1970, UTC)
		tutorialDone = false, -- finished (or skipped) the guided first match
		groupReward = false, -- claimed the join-the-group Gems
		deals = { day = -1, bought = {} }, -- today's daily deals already bought
		-- the owner's switch: every character, cosmetic and gold base while it's on,
		-- without touching their real progress (see DataService.setUnlockAll)
		unlockAll = false,
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
	-- accessory packs became piece finishes (a second pack that became the same finish
	-- is paid back as a duplicate)
	data.gems = (data.gems or 0) + Cosmetics.migratePacks(data.owned, data.equipped, Gacha.dupeRefund)
	-- portrait outfits became emblems (each the emblem of its set)
	Cosmetics.migrateOutfits(data.owned, data.equipped)
	-- drop ids that no longer exist
	for id in data.owned do
		if Cosmetics.get(id) == nil then
			data.owned[id] = nil
		end
	end
	-- (with the owner's unlock-all on, what they wear needn't be owned)
	for _, cat in { "finish", "dice", "trail", "title" } do
		local id = data.equipped[cat]
		if id == nil or not (data.owned[id] or data.unlockAll) or Cosmetics.get(id) == nil then
			data.equipped[cat] = Cosmetics.defaults[cat]
		end
	end
	for character, id in table.clone(data.equipped.emblems) do
		local def = Cosmetics.get(id)
		if not def or def.category ~= "emblem" or def.character ~= character or not (data.owned[id] or data.unlockAll) then
			data.equipped.emblems[character] = nil
		end
	end
	local emotes = {}
	for _, id in data.equipped.emotes or {} do
		if (data.owned[id] or (data.unlockAll and Cosmetics.get(id))) and #emotes < Cosmetics.EmoteSlots then
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

-- Titles earned by deeds (Cosmetics: deed = { stat, goal }) that the profile's
-- lifetime stats have reached and it doesn't own yet: grants them, returns their ids.
local function applyDeeds(data): { string }
	local earned = {}
	for _, id in Cosmetics.fromSource("deed") do
		local def = Cosmetics.get(id)
		local deed = def and def.deed
		if deed and not data.owned[id] and (data.stats[deed.stat] or 0) >= deed.goal then
			data.owned[id] = true
			table.insert(earned, id)
		end
	end
	return earned
end
DataService.applyDeeds = applyDeeds

local function grantPassPerks(prof)
	local data = prof.data
	applyDeeds(data)
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
	-- the one-time gifts that come with a pass (Gems, free chests)
	data.passGifts = data.passGifts or {}
	local gifts = {}
	for _, pass in Passes.list do
		local gift = pass.gift
		if gift and prof.passes[pass.key] and not data.passGifts[pass.key] then
			data.passGifts[pass.key] = true
			data.gems += gift.gems or 0
			for chest, n in gift.chests or {} do
				data.freeChests[chest] = (data.freeChests[chest] or 0) + n
			end
			table.insert(gifts, pass.name)
		end
	end
	return gifts
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

-- Whether a player may use the unlock-all switch (Main hands over the owner check).
function DataService.canUnlockAll(_player: Player): boolean
	return false
end

-- The owner's unlock-all is on (and they're still the owner).
local function everything(player: Player, data): boolean
	return data.unlockAll == true and DataService.canUnlockAll(player)
end

local function hasCharacter(player: Player, data, id: string): boolean
	return everything(player, data) or Characters.unlocked(id, data.level)
end

local function hasItem(player: Player, data, id: string): boolean
	return data.owned[id] == true or (everything(player, data) and Cosmetics.get(id) ~= nil)
end

-- The view of the profile that the client sees.
function DataService.view(player: Player)
	local prof = profiles[player]
	if not prof then
		return nil
	end
	local data = prof.data
	local owned = {}
	if everything(player, data) then
		for _, def in Cosmetics.list do
			table.insert(owned, def.id)
		end
	else
		for id in data.owned do
			table.insert(owned, id)
		end
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
			finish = data.equipped.finish,
			dice = data.equipped.dice,
			trail = data.equipped.trail,
			title = data.equipped.title,
			emotes = table.clone(data.equipped.emotes),
			emblems = table.clone(data.equipped.emblems or {}),
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
		season = { id = data.season.id, best = data.season.best, ends = Progress.seasonEnds(data.season.id) },
		seasonNews = data.seasonNews,
		awards = table.clone(data.awards),
		badges = table.clone(data.badges),
		fish = table.clone(data.fish),
		fishBest = table.clone(data.fishBest),
		tutorialDone = data.tutorialDone,
		groupReward = data.groupReward,
		deals = DataService.dealsView(data),
		unlockAll = everything(player, data),
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
			end, (data.stats.friendGames or 0) > 0),
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
	if id and Characters.get(id) and hasCharacter(player, data, id) then
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
	if not hasCharacter(player, data, id) then
		return false, string.format("Reach level %d to unlock the %s.", def.unlockLevel or 0, def.name)
	end
	data.character = id
	return true
end

-- The owner's unlock-all switch. Off again, they're back to exactly what they've earned:
-- anything worn or picked that they don't really have goes back to a default.
function DataService.setUnlockAll(player: Player, on: boolean): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	if not DataService.canUnlockAll(player) then
		return false, "Only the game's owner can do that."
	end
	data.unlockAll = on
	if not on then
		for _, cat in { "finish", "dice", "trail", "title" } do
			if not data.owned[data.equipped[cat]] then
				data.equipped[cat] = Cosmetics.defaults[cat]
			end
		end
		local emotes = {}
		for _, id in data.equipped.emotes do
			if data.owned[id] then
				table.insert(emotes, id)
			end
		end
		data.equipped.emotes = if #emotes > 0 then emotes else table.clone(Cosmetics.defaults.emotes)
		for character, id in table.clone(data.equipped.emblems) do
			if not data.owned[id] then
				data.equipped.emblems[character] = nil
			end
		end
		if not Characters.unlocked(data.character, data.level) then
			data.character = Characters.ids[1]
		end
	end
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
	end, (data.stats.friendGames or 0) > 0)
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
		return { finish = Cosmetics.defaults.finish, dice = Cosmetics.defaults.dice, trail = Cosmetics.defaults.trail, title = Cosmetics.defaults.title, level = 1, vip = false }
	end
	return {
		finish = data.equipped.finish,
		dice = data.equipped.dice,
		trail = data.equipped.trail,
		title = data.equipped.title,
		emotes = table.clone(data.equipped.emotes),
		emblems = table.clone(data.equipped.emblems or {}),
		level = data.level,
		vip = vip,
		-- the base your character stands on: earned with mastery (Progress.baseTier)
		base = DataService.baseFor(player, DataService.selectedCharacter(player)),
	}
end

-- The base `character` stands on for this player: 0 none yet, 1 their base, 2 gilded.
function DataService.baseFor(player: Player, character: string?): number
	local data = DataService.get(player)
	if not data or not character then
		return 0
	end
	if everything(player, data) then
		return 2
	end
	return Progress.baseTier(Progress.masteryLevel(data.mastery[character] or 0))
end

-- A catch for the fish log; returns how many of it they have now, whether it's bigger
-- than any they'd landed before, and what filling the log has just earned them
-- (Fishing.Rewards: cosmetic ids, given here).
function DataService.addCatch(player: Player, catchId: string, size: number?): (number, boolean, { string })
	local data = DataService.get(player)
	if not data or catchId == "coin" then
		return 0, false, {}
	end
	data.fish[catchId] = (data.fish[catchId] or 0) + 1
	local record = false
	if size and size > 0 then
		local best = data.fishBest[catchId]
		record = best ~= nil and size > best
		if best == nil or size > best then
			data.fishBest[catchId] = size
		end
	end
	local species = 0
	for _, c in Fishing.logged do
		if (data.fish[c.id] or 0) > 0 then
			species += 1
		end
	end
	local unlocked = {}
	for _, item in Fishing.rewardsFor(species) do
		if not data.owned[item] and Cosmetics.get(item) then
			data.owned[item] = true
			table.insert(unlocked, item)
		end
	end
	if #unlocked > 0 then
		DataService.pushProfile(player)
	end
	return data.fish[catchId], record, unlocked
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
		return player:IsInGroupAsync(groupId)
	end)
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

-- Gems from fishing, up to Fishing.GemsPerDay a day (UTC). Returns how many were given.
function DataService.addFishGems(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local day = os.time() // 86400
	if data.fishGemsDay ~= day then
		data.fishGemsDay = day
		data.fishGems = 0
	end
	local give = math.max(0, math.min(math.floor(amount), Fishing.GemsPerDay - (data.fishGems or 0)))
	data.fishGems = (data.fishGems or 0) + give
	data.gems += give
	return give
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
			if not def or def.category ~= "emote" or not hasItem(player, data, id) then
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
	if category == "emblem" then
		-- (worn by one character)
		local def = type(value) == "string" and Cosmetics.get(value)
		if not def or def.category ~= "emblem" then
			return false, "That item doesn't fit there."
		end
		if not hasItem(player, data, value) then
			return false, "You don't own that yet."
		end
		data.equipped.emblems[def.character] = if def.set == "classic" then nil else value
		return true
	end
	if category ~= "finish" and category ~= "dice" and category ~= "trail" and category ~= "title" then
		return false, "Unknown slot."
	end
	local def = type(value) == "string" and Cosmetics.get(value)
	if not def or def.category ~= category then
		return false, "That item doesn't fit there."
	end
	if not hasItem(player, data, value) then
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
	local emblem = nil
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
		if level == Progress.EmblemMastery then
			-- their Gilded emblem
			local id = "emblem_" .. charId .. "_gilded"
			if Cosmetics.get(id) and not data.owned[id] then
				data.owned[id] = true
				emblem = id
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
		emblem = emblem,
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
	-- (a season can end mid-session)
	DataService.seasonRollover(data)
	local before = data.trophies
	local delta = Progress.trophyDelta(result.place or result.players or 1, result.players or 1, result.won == true, result.team == true, before)
	data.trophies = math.max(0, before + delta)
	data.bestTrophies = math.max(data.bestTrophies, data.trophies)
	data.season.best = math.max(data.season.best or 0, data.trophies)
	local oldRank, newRank = Progress.rank(before), Progress.rank(data.trophies)
	-- passed this week's rival (the friend who was just ahead)
	local passed = nil
	local rival = data.rival
	if rival.week == Progress.week() and not rival.done and rival.userId ~= 0 and data.trophies > rival.target then
		rival.done = true
		data.gems += Progress.RivalGems
		passed = { name = rival.name, gems = Progress.RivalGems }
	end
	return { delta = delta, total = data.trophies, rank = newRank.id, rankUp = newRank.min > oldRank.min, rival = passed }
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
	-- everyone's end-of-match award
	if type(result.award) == "string" then
		gems += R.AwardGems
		data.awards[result.award] = (data.awards[result.award] or 0) + 1
	end
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
	if (result.friends or 0) > 0 then
		s.friendGames += 1
	end
	s.deaths += stats.deaths or 0
	s.placed += stats.placed or 0
	s.bonks += stats.bonks or 0
	s.gotchas += stats.gotchas or 0

	local mastery = applyMastery(data, result)
	local quests = applyQuests(player, data, result)
	local trophies = applyTrophies(data, result)
	local deeds = applyDeeds(data)

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
		deeds = if #deeds > 0 then deeds else nil,
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

--[[
	A new ranked season (Progress.season): the last one you played pays out by the best
	rank you reached in it, and your trophies carry over at half. The lobby shows how it
	went (data.seasonNews) until you've seen it.
]]
local function seasonRollover(data)
	local now = Progress.season()
	local s = data.season
	if s.id == now then
		return
	end
	if (s.id or 0) <= 0 or s.id > now then
		-- (a new profile, or one from before seasons: it starts in this one)
		data.season = { id = now, best = data.trophies }
		return
	end
	local rank = Progress.rank(math.max(s.best or 0, data.trophies))
	local news = { season = s.id, rank = rank.id, gems = Progress.seasonGems[rank.id] or 0 }
	data.gems += news.gems
	if rank.id ~= "wood" then
		local title = Progress.seasonTitleId(s.id, rank.id)
		if Cosmetics.get(title) then
			data.owned[title] = true
			news.title = title
		end
	end
	local chest = Progress.seasonChest[rank.id]
	if chest then
		data.freeChests[chest] = (data.freeChests[chest] or 0) + 1
		news.chest = chest
	end
	news.trophiesBefore = data.trophies
	data.trophies = Progress.seasonCarry(data.trophies)
	news.trophies = data.trophies
	data.season = { id = now, best = data.trophies }
	data.seasonNews = news
end
DataService.seasonRollover = seasonRollover

--[[
	This week's rival (the friends trophies board): the friend just ahead of you when you
	first look this week, and the trophies to pass. `entries` is the board, best first.
]]
function DataService.rival(player: Player, entries)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local week = Progress.week()
	local r = data.rival
	if r.week ~= week or r.userId == 0 then
		r = { week = week, userId = 0, name = "", target = 0, done = false }
		local above = nil
		for _, e in entries do
			if e.userId ~= player.UserId and e.value > data.trophies then
				above = e -- (the list is best first: the last one above is the closest)
			end
		end
		if above then
			r.userId, r.name, r.target = above.userId, above.name, above.value
		end
		data.rival = r
	end
	if r.userId == 0 then
		return nil
	end
	return { name = r.name, target = r.target, done = r.done, gems = Progress.RivalGems }
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
	seasonRollover(data)
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

	-- Gem packs (developer products): granted once per purchase id, and only told to
	-- Roblox as granted once the profile holding them is saved.
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local prof = player and profiles[player]
		local pack = Passes.packForProduct(receipt.ProductId)
		if not player or not prof or not pack then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = prof.data
		data.receipts = data.receipts or {}
		if table.find(data.receipts, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		data.gems += pack.gems
		table.insert(data.receipts, receipt.PurchaseId)
		while #data.receipts > 50 do
			table.remove(data.receipts, 1)
		end
		if not prof.temp and not saveData(player, false) then
			-- not saved: take it back, and Roblox will ask again later
			data.gems -= pack.gems
			table.remove(data.receipts)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		DataService.pushProfile(player)
		Net.push(player, "toast", { text = "Thanks! +" .. pack.gems .. " Gems", kind = "reward" })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and profiles[player] then
			local passKey = Passes.keyForId(passId)
			if passKey then
				profiles[player].passes[passKey] = true
				local gifts = grantPassPerks(profiles[player])
				DataService.pushProfile(player)
				local gift = Passes.byKey[passKey].gift
				local extra = if gift and #gifts > 0 and gift.gems then " +" .. gift.gems .. " Gems" else ""
				Net.push(player, "toast", { text = "Thanks! " .. Passes.byKey[passKey].name .. " is now active." .. extra, kind = "reward" })
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

	-- the end-of-season news has been seen
	Net.handle("season.seen", function(player)
		local data = DataService.get(player)
		if data and data.seasonNews then
			data.seasonNews = nil
			DataService.pushProfile(player)
		end
		return true
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

	Net.handle("owner.unlockAll", function(player, payload)
		local ok2, err = DataService.setUnlockAll(player, type(payload) == "table" and payload.on == true)
		if not ok2 then
			return false, err
		end
		DataService.pushProfile(player)
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
