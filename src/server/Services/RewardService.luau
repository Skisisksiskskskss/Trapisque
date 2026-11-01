--!strict
-- Grants reward specs (cash, income-scaled cash, boosts) and handles Index set rewards and player settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local Rarities = require(Shared.Config.Rarities)
local Rewards = require(Shared.Config.Rewards)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local RewardService = {}

-- Applies a reward and returns a description of what was granted.
function RewardService.Grant(player: Player, reward: Rewards.Reward): string
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return ""
	end
	local cash = reward.Cash or 0
	if reward.CashMinutes then
		cash += math.max(reward.MinCash or 0, math.floor(session.IncomeCache * reward.CashMinutes * 60))
	end
	if cash > 0 then
		DataService.AddCash(player, cash)
	end
	if reward.Boosts then
		for name, count in reward.Boosts do
			data.Boosts[name] = (data.Boosts[name] or 0) + count
		end
	end
	DataService.MarkDirty(player)
	return Rewards.Describe(reward, cash, Format.Cash)
end

function RewardService.IndexProgress(data: { Index: { [string]: boolean } }, rarity: number): (number, number)
	local bucket = Brainrots.OfRarity(rarity)
	local found = 0
	for _, def in bucket do
		if data.Index[BrainrotStats.IndexKey(def.Id, "None")] then
			found += 1
		end
	end
	return found, #bucket
end

local function onClaimIndex(player: Player, rarity: unknown): (boolean, string)
	if not DataService.Throttle(player, "ClaimIndex", 0.5) then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data or type(rarity) ~= "number" or Rewards.IndexSets[rarity] == nil then
		return false, "Not available"
	end
	local key = tostring(rarity)
	if data.IndexClaimed[key] then
		return false, "Already claimed"
	end
	local found, total = RewardService.IndexProgress(data, rarity)
	if found < total then
		return false, string.format("Discover all %s brainrots first (%d/%d)", Rarities.Get(rarity).Name, found, total)
	end
	data.IndexClaimed[key] = true
	local text = RewardService.Grant(player, Rewards.IndexSets[rarity])
	Net.Event("Effect"):FireClient(player, "Reward", { Text = text })
	return true, "Index reward: " .. text
end

local function onSettings(player: Player, key: unknown, value: unknown)
	if not DataService.Throttle(player, "Settings", 0.2) then
		return
	end
	local data = DataService.Get(player)
	if not data or type(value) ~= "boolean" then
		return
	end
	if key == "Music" then
		data.Settings.Music = value
	elseif key == "Sfx" then
		data.Settings.Sfx = value
	else
		return
	end
	DataService.MarkDirty(player)
end

function RewardService.Start()
	Net.Function("ClaimIndex").OnServerInvoke = onClaimIndex
	Net.Event("Settings").OnServerEvent:Connect(onSettings)
end

return RewardService
