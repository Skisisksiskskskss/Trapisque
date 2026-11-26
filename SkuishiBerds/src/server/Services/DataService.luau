--[[
	DataService: player profiles with session locking.

	Each record is { data = profile, lock = { jobId, time } }. A server only
	writes a record it holds the lock for, so two servers can never overwrite
	each other (e.g. while a player hops servers). Stale locks (crashed server)
	expire after LOCK_TIMEOUT.

	In Studio without "Enable Studio Access to API Services", profiles still
	work in memory (nothing is saved) and a warning is printed.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Birds = require(Shared.Config.Birds)
local Signal = require(Shared.Util.Signal)

local DataService = {}

local STORE_NAME = "SkuishiProfiles_v1"
local LOCK_TIMEOUT = 30 * 60
local AUTOSAVE_SECONDS = 90
local SCHEMA_VERSION = 1

DataService.Changed = Signal.new() -- (player, data)
DataService.Loaded = Signal.new() -- (player, data)
DataService.Persistent = true

local store: DataStore? = nil
local profiles: { [Player]: { data: any, dirty: boolean, persistent: boolean } } = {}
local loading: { [Player]: boolean } = {}

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

function DataService.template()
	local owned = { bird = {}, color = {}, pattern = {}, hat = {}, death = {} }
	for _, def in Birds.List do
		if def.price == 0 then
			owned.bird[def.id] = true
		end
	end
	for category, list in Cosmetics.Categories do
		for _, item in list do
			if item.price == 0 and not item.robuxOnly then
				owned[category][item.id] = true
			end
		end
	end
	return {
		v = SCHEMA_VERSION,
		coins = 100,
		xp = 0,
		owned = owned,
		loadout = deepCopy(Cosmetics.DefaultLoadout),
		loadout2 = deepCopy(Cosmetics.DefaultLoadout2),
		stats = {
			soloBest = 0,
			duoBest = 0,
			versusWins = 0,
			versusGames = 0,
			games = 0,
			strums = 0,
			deaths = 0,
		},
		discovered = {},
		reviveTokens = 1,
		receipts = {},
		receiptOrder = {},
		daily = { day = 0, streak = 0 },
		settings = { music = 0.5, sfx = 0.8, shake = true, eventText = true },
	}
end

-- Fill in anything missing (new fields added in later updates), recursively
local function fillMissing(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "receipts" and k ~= "receiptOrder" then
			-- only recurse into dictionary-like tables
			if next(v) ~= nil and #v == 0 then
				fillMissing(data[k], v)
			end
		end
	end
end

local function reconcile(data, template)
	fillMissing(data, template)
	-- free items added later are granted automatically
	for category, list in Cosmetics.Categories do
		data.owned[category] = data.owned[category] or {}
		for _, item in list do
			if item.price == 0 and not item.robuxOnly then
				data.owned[category][item.id] = true
			end
		end
	end
	data.owned.bird = data.owned.bird or {}
	data.owned.bird[Birds.DEFAULT] = true
	data.v = SCHEMA_VERSION
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function initStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable: " .. tostring(result))
	end
end

local function disablePersistence(reason: string)
	if DataService.Persistent then
		DataService.Persistent = false
		warn(
			"[DataService] Progress will NOT be saved: "
				.. reason
				.. "\n  In Studio: Game Settings > Security > Enable Studio Access to API Services (place must be published)."
		)
	end
end

local function loadProfile(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local template = DataService.template()
	local data = nil
	local persistent = DataService.Persistent and store ~= nil

	if persistent then
		local key = keyFor(player)
		for attempt = 1, 6 do
			local lockedElsewhere = false
			local ok, result = pcall(function()
				return (store :: DataStore):UpdateAsync(key, function(old)
					old = old or { data = nil, lock = nil }
					local lock = old.lock
					if
						lock
						and lock.jobId ~= game.JobId
						and os.time() - (lock.time or 0) < LOCK_TIMEOUT
						and attempt < 6
					then
						lockedElsewhere = true
						return nil
					end
					old.lock = { jobId = game.JobId, time = os.time() }
					return old
				end)
			end)
			if ok and not lockedElsewhere then
				data = if result and result.data then result.data else nil
				break
			elseif not ok then
				local msg = tostring(result)
				if string.find(msg, "Studio") or string.find(msg, "publish") or string.find(msg, "API") then
					disablePersistence(msg)
					persistent = false
					break
				end
				warn(string.format("[DataService] load attempt %d for %s failed: %s", attempt, player.Name, msg))
			end
			if not player.Parent then
				loading[player] = nil
				return
			end
			task.wait(if lockedElsewhere then 4 else 2 ^ attempt * 0.5)
		end
	end

	if not player.Parent then
		loading[player] = nil
		return
	end

	data = reconcile(data or template, template)
	profiles[player] = { data = data, dirty = true, persistent = persistent }
	loading[player] = nil
	DataService.Loaded:Fire(player, data)
	DataService.Changed:Fire(player, data)
end

local function saveProfile(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.persistent or not store then
		return
	end
	local payload = profile.data
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if old and old.lock and old.lock.jobId ~= game.JobId then
				-- another server took over this profile; never overwrite it
				return nil
			end
			return {
				data = payload,
				lock = if release then nil else { jobId = game.JobId, time = os.time() },
			}
		end)
	end)
	if ok then
		profile.dirty = false
	else
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Public API ------------------------------------------------------------------

function DataService.get(player: Player): any?
	local p = profiles[player]
	return p and p.data
end

function DataService.waitFor(player: Player, timeout: number?): any?
	local start = os.clock()
	while player.Parent and not profiles[player] do
		if timeout and os.clock() - start > timeout then
			return nil
		end
		task.wait(0.1)
	end
	return DataService.get(player)
end

-- Mutate a profile; fires Changed so the client gets the new data
function DataService.update(player: Player, fn: (data: any) -> ())
	local p = profiles[player]
	if not p then
		return false
	end
	fn(p.data)
	p.dirty = true
	DataService.Changed:Fire(player, p.data)
	return true
end

function DataService.addCoins(player: Player, amount: number): boolean
	return DataService.update(player, function(d)
		d.coins = math.max(0, d.coins + math.floor(amount))
	end)
end

function DataService.levelFor(xp: number): number
	return math.floor(math.sqrt(xp / 60)) + 1
end

-- Returns levels gained
function DataService.addXp(player: Player, amount: number): number
	local gained = 0
	DataService.update(player, function(d)
		local before = DataService.levelFor(d.xp)
		d.xp += math.floor(amount)
		local after = DataService.levelFor(d.xp)
		gained = after - before
		if gained > 0 then
			d.coins += gained * 25 * after
		end
	end)
	return gained
end

function DataService.saveNow(player: Player)
	saveProfile(player, false)
end

function DataService.isPersistent(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.persistent
end

function DataService.init()
	initStore()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, true)
		profiles[player] = nil
		loading[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, p in profiles do
				if p.dirty then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)
end

return DataService
