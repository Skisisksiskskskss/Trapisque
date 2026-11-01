--!strict
-- Sends each player a snapshot of their own state whenever it changes (coalesced), and maintains leaderstats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local PlayerStats = require(script.Parent.Parent.Modules.PlayerStats)
local BrainrotService = require(script.Parent.BrainrotService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SyncService = {}

local dirty: { [Player]: boolean } = {}
-- Extra fields other services contribute to the snapshot (daily status, shop info, ...).
local providers: { (Player, { [string]: any }) -> () } = {}

function SyncService.AddProvider(provider: (Player, { [string]: any }) -> ())
	table.insert(providers, provider)
end

local function buildState(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return nil
	end
	local slotOf: { [string]: number } = {}
	for slot, uid in BrainrotService.PlacedSlots(data) do
		slotOf[uid] = slot
	end
	local brainrots = {}
	for uid, record in data.Brainrots do
		table.insert(brainrots, {
			Uid = uid,
			Id = record.Id,
			Mutation = record.Mutation,
			Size = record.Size,
			Slot = slotOf[uid],
			Income = BrainrotService.Income(record),
		})
	end
	local state: { [string]: any } = {
		Cash = data.Cash,
		LifetimeCash = data.LifetimeCash,
		Tier = data.Tier,
		CrystalLevel = data.CrystalLevel,
		DoorLevel = data.DoorLevel,
		Rebirths = data.Rebirths,
		Income = session.IncomeCache,
		CashMultiplier = session.CashMultiplier,
		CrystalPower = PlayerStats.CrystalPower(data, session.Passes),
		DoorStrength = PlayerStats.DoorStrength(data, session.Passes),
		Charge = session.Charge,
		Brainrots = brainrots,
		SlotsUnlocked = Economy.Slots(data.Tier),
		StorageMax = GameConfig.StorageMax,
		Index = data.Index,
		IndexCount = PlayerStats.IndexCount(data),
		IndexClaimed = data.IndexClaimed,
		Boosts = data.Boosts,
		Overcharge = session.Overcharge,
		IronDoorUntil = session.IronDoorUntil,
		LuckyPending = session.LuckyPending,
		GoldenPending = session.GoldenPending,
		Passes = session.Passes,
		Tutorial = data.Tutorial,
		Stats = data.Stats,
		Settings = data.Settings,
		Plot = session.Plot,
		Shielded = PlotService.IsShielded(player),
		RebirthCost = Economy.RebirthCost(data.Rebirths),
		SessionSeconds = os.clock() - session.JoinTime,
	}
	for _, provider in providers do
		local ok, err = pcall(provider :: any, player, state)
		if not ok then
			warn("[SyncService] provider failed: " .. tostring(err))
		end
	end
	return state
end

local function updateLeaderstats(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "Cash"
		cash.Parent = folder
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = folder
		folder.Parent = player
		stats = folder
	end
	if stats then
		local cash = stats:FindFirstChild("Cash") :: StringValue?
		local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
		if cash then
			cash.Value = Format.Cash(data.Cash)
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
	end
end

function SyncService.Flush(player: Player)
	dirty[player] = nil
	local state = buildState(player)
	if state then
		Net.Event("State"):FireClient(player, state)
		updateLeaderstats(player)
		PlotService.PublishStats(player)
	end
end

function SyncService.Start()
	DataService.Changed:Connect(function(player)
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in dirty do
				if player.Parent then
					SyncService.Flush(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)
end

return SyncService
