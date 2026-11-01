--!strict
-- Owns every player's save data and per-session runtime state.
-- Loading: session-locked via SaveStore, migrated + reconciled via DataSchema.
-- Saving: autosave every GameConfig.AutosaveInterval, on leave (with lock release) and on shutdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataSchema = require(Shared.Modules.DataSchema)
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Modules.Signal)
local SaveStore = require(script.Parent.Parent.Modules.SaveStore)

export type Session = {
	Plot: number?,
	Charge: number,
	LastTap: number,
	Overcharge: boolean,
	IronDoorUntil: number,
	LuckyPending: boolean,
	GoldenPending: boolean,
	Pending: { [number]: number }, -- uncollected cash per pedestal slot
	Passes: { [string]: boolean },
	JoinTime: number,
	WaveCount: number,
	LastBonk: number,
	Throttles: { [string]: number },
	IncomeCache: number,
	CashMultiplier: number,
	PlaytimeAtJoin: number,
	Released: boolean,
	InGroup: boolean,
	ShieldNoticeShown: boolean,
	WelcomeSent: boolean,
}

type Profile = {
	Data: DataSchema.PlayerData,
	Session: Session,
	Dirty: boolean,
	LockLost: boolean,
}

local DataService = {}

DataService.Loaded = Signal.new() :: Signal.Signal<Player, DataSchema.PlayerData>
DataService.Releasing = Signal.new() :: Signal.Signal<Player, DataSchema.PlayerData>
DataService.Changed = Signal.new() :: Signal.Signal<Player>

local profiles: { [Player]: Profile } = {}
local releasing: { [number]: boolean } = {}
local store: SaveStore.Store

local function newSession(data: DataSchema.PlayerData): Session
	return {
		Plot = nil,
		Charge = 0,
		LastTap = 0,
		Overcharge = false,
		IronDoorUntil = 0,
		LuckyPending = false,
		GoldenPending = false,
		Pending = {},
		Passes = {},
		JoinTime = os.clock(),
		WaveCount = 0,
		LastBonk = 0,
		Throttles = {},
		IncomeCache = 0,
		CashMultiplier = 1,
		PlaytimeAtJoin = data.Stats.Playtime or 0,
		Released = false,
		InGroup = false,
		ShieldNoticeShown = false,
		WelcomeSent = false,
	}
end

function DataService.Get(player: Player): DataSchema.PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.GetSession(player: Player): Session?
	local profile = profiles[player]
	return if profile then profile.Session else nil
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.WaitForData(player: Player, timeout: number?): DataSchema.PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and os.clock() < deadline do
		local profile = profiles[player]
		if profile then
			return profile.Data
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.Players(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

function DataService.MarkDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
		DataService.Changed:Fire(player)
	end
end

-- Returns true when the action is allowed (at most once per interval seconds).
function DataService.Throttle(player: Player, key: string, interval: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local now = os.clock()
	local last = profile.Session.Throttles[key] or 0
	if now - last < interval then
		return false
	end
	profile.Session.Throttles[key] = now
	return true
end

function DataService.AddCash(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount ~= amount or amount == math.huge then
		return
	end
	local data = profile.Data
	data.Cash = math.max(0, data.Cash + amount)
	if amount > 0 then
		data.LifetimeCash += amount
	end
	DataService.MarkDirty(player)
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.Data.Cash < amount then
		return false
	end
	profile.Data.Cash -= amount
	DataService.MarkDirty(player)
	return true
end

function DataService.AddStat(player: Player, stat: string, amount: number)
	local profile = profiles[player]
	if profile then
		profile.Data.Stats[stat] = (profile.Data.Stats[stat] or 0) + amount
	end
end

local function updatePlaytime(profile: Profile)
	local session = profile.Session
	profile.Data.Stats.Playtime = session.PlaytimeAtJoin + math.floor(os.clock() - session.JoinTime)
end

-- Saves immediately (used after purchases). Returns true when the save is confirmed.
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.LockLost then
		return false
	end
	updatePlaytime(profile)
	profile.Data.LastOnline = os.time()
	local ok, lockLost = store:Save(player.UserId, profile.Data, false)
	if lockLost then
		profile.LockLost = true
		player:Kick("Your progress was loaded on another server. Please rejoin!")
		return false
	end
	if ok then
		profile.Dirty = false
	end
	return ok
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile or profile.Session.Released then
		return
	end
	profile.Session.Released = true
	releasing[player.UserId] = true
	pcall(function()
		DataService.Releasing:Fire(player, profile.Data)
	end)
	updatePlaytime(profile)
	profile.Data.LastOnline = os.time()
	if not profile.LockLost then
		store:Save(player.UserId, profile.Data, true)
	end
	profiles[player] = nil
	releasing[player.UserId] = nil
end

local function load(player: Player)
	-- If this player is still being released on this server (fast rejoin), wait so we read the final save.
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		task.wait(0.25)
		waited += 0.25
	end
	local raw, status = store:Load(player.UserId)
	if not player.Parent then
		if status == "ok" then
			store:Save(player.UserId, raw, true)
		end
		return
	end
	if status ~= "ok" then
		player:Kick("Your data is still saving on another server. Please rejoin in a minute!")
		return
	end
	if DataSchema.IsNewer(raw) then
		store:Save(player.UserId, raw, true)
		player:Kick("This server is out of date. Please rejoin to get the latest version!")
		return
	end
	local data = DataSchema.Migrate(raw)
	local now = os.time()
	if data.FirstJoin == 0 then
		data.FirstJoin = now
	end
	local profile: Profile = {
		Data = data,
		Session = newSession(data),
		Dirty = true,
		LockLost = false,
	}
	profiles[player] = profile
	DataService.Loaded:Fire(player, data)
	DataService.MarkDirty(player)
end

function DataService.Init()
	store = SaveStore.new(GameConfig.DataStoreName)
end

function DataService.IsMemoryStore(): boolean
	return store:IsMemory()
end

-- Called by the bootstrap after every service has started, so no Loaded/Releasing listener can miss a player
-- (in Studio the in-memory store loads instantly, without yielding).
function DataService.BeginLoading()
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		release(player)
	end)
end

function DataService.Start()
	-- Autosave loop, staggered across players.
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player, profile in profiles do
				if not profile.Session.Released and player.Parent then
					task.spawn(function()
						DataService.SaveNow(player)
					end)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
