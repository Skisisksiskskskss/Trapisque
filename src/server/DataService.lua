--[[
	DataService
	Player profiles (Gems, levels, stats, cosmetics, settings), gamepass ownership and
	the paid-random-items policy check.

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
local Passes = require(Shared.Meta.Passes)

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
		stats = { games = 0, wins = 0, treasures = 0, deaths = 0, placed = 0, practice = 0 },
		owned = owned,
		equipped = {
			pawn = Cosmetics.defaults.pawn,
			dice = Cosmetics.defaults.dice,
			trail = Cosmetics.defaults.trail,
			title = Cosmetics.defaults.title,
			emotes = table.clone(Cosmetics.defaults.emotes),
		},
		pity = { explorer = {}, royal = {} },
		freeChests = { explorer = Config.Rewards.StartingFreeChests },
		chestsOpened = 0,
		lastDaily = 0,
		settings = { sfx = true, music = true, sfxVolume = 1, musicVolume = 0.7, autoRoll = false, fastAnim = false },
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
	-- drop ids that no longer exist
	for id in data.owned do
		if Cosmetics.get(id) == nil then
			data.owned[id] = nil
		end
	end
	for _, cat in { "pawn", "dice", "trail", "title" } do
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
end

local function refreshPasses(player: Player)
	local prof = profiles[player]
	if not prof then
		return
	end
	for _, pass in Passes.list do
		prof.passes[pass.key] = ownsPass(player, pass.key)
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

function DataService.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		loadedSignal.Event:Wait()
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
	return {
		gems = data.gems,
		xp = data.xp,
		level = data.level,
		xpNext = Config.xpForLevel(data.level),
		stats = table.clone(data.stats),
		owned = owned,
		equipped = {
			pawn = data.equipped.pawn,
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
	}
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
		return { pawn = Cosmetics.defaults.pawn, dice = Cosmetics.defaults.dice, trail = Cosmetics.defaults.trail, title = Cosmetics.defaults.title, level = 1, vip = false }
	end
	return {
		pawn = data.equipped.pawn,
		dice = data.equipped.dice,
		trail = data.equipped.trail,
		title = data.equipped.title,
		emotes = table.clone(data.equipped.emotes),
		level = data.level,
		vip = vip,
	}
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
	if category ~= "pawn" and category ~= "dice" and category ~= "trail" and category ~= "title" then
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
		end
	end
	return true
end

-- Gems/XP for a finished match. Returns a summary for the results screen.
function DataService.applyMatchResult(player: Player, result)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local R = Config.Rewards
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

	data.gems += gems
	data.xp += xp
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
	s.deaths += result.deaths or 0
	s.placed += result.placed or 0

	return {
		gems = gems + levelsGained * R.LevelUpGems,
		xp = xp,
		levelsGained = levelsGained,
		level = data.level,
		bonus = bonus,
	}
end

function DataService.save(player: Player, release: boolean?)
	return saveData(player, release == true)
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

local function dailyReward(player: Player)
	local prof = profiles[player]
	local data = prof.data
	local today = os.time() // 86400
	if data.lastDaily == today then
		return
	end
	data.lastDaily = today
	data.gems += Config.Rewards.DailyGems
	local msg = "Daily reward: +" .. Config.Rewards.DailyGems .. " Gems"
	if prof.passes.VIP then
		data.freeChests.explorer = (data.freeChests.explorer or 0) + 1
		msg ..= " and a free Explorer Chest (VIP)"
	end
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
	dailyReward(player)
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
		-- In Studio without "Enable Studio Access to API Services", DataStore calls fail.
		if ServerInfo.isStudio then
			local probeOk = pcall(function()
				ds:GetAsync("__probe")
			end)
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

	Net.handle("shop.refresh", function(player)
		refreshPasses(player)
		DataService.pushProfile(player)
		return true
	end)
end

return DataService
