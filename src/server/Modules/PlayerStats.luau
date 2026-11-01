--!strict
-- Derived player stats: every multiplier from rebirths, gamepasses, index and events in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local DataSchema = require(Shared.Modules.DataSchema)
local ServerState = require(script.Parent.ServerState)

type Passes = { [string]: boolean }

local PlayerStats = {}

local function indexCount(data: DataSchema.PlayerData): number
	-- Only base (non-mutated) entries count toward the index cash bonus.
	local count = 0
	for key in data.Index do
		if string.sub(key, -5) == "|None" then
			count += 1
		end
	end
	return count
end
PlayerStats.IndexCount = indexCount

function PlayerStats.CashMultiplier(data: DataSchema.PlayerData, passes: Passes): number
	local mult = 1 + data.Rebirths * Economy.RebirthCashBonus
	mult *= 1 + indexCount(data) * Economy.IndexBonusPerEntry
	if passes.DoubleCash then
		mult *= 2
	end
	if passes.VIP then
		mult *= 1.25
	end
	mult *= ServerState.CashEventMult
	return mult
end

function PlayerStats.PowerMultiplier(data: DataSchema.PlayerData): number
	return 1 + data.Rebirths * Economy.RebirthPowerBonus
end

function PlayerStats.CrystalPower(data: DataSchema.PlayerData, passes: Passes): number
	local mult = PlayerStats.PowerMultiplier(data)
	if passes.SuperCrystal then
		mult *= 1.25
	end
	return Economy.CrystalPower(data.CrystalLevel, mult)
end

function PlayerStats.DoorStrength(data: DataSchema.PlayerData, passes: Passes): number
	local mult = PlayerStats.PowerMultiplier(data)
	if passes.Fortress then
		mult *= 1.5
	end
	return Economy.DoorStrength(data.DoorLevel, mult)
end

function PlayerStats.Luck(passes: Passes): number
	local luck = 1
	if passes.VIP then
		luck *= 1.1
	end
	if os.time() < ServerState.ServerLuckUntil then
		luck *= 2
	end
	luck *= ServerState.LuckEventMult
	return luck
end

function PlayerStats.MutationMultipliers(passes: Passes): { [string]: number }
	local mult: { [string]: number } = table.clone(ServerState.MutationMult)
	if os.time() < ServerState.ServerLuckUntil then
		for _, name in { "Gold", "Diamond", "Rainbow", "Galaxy" } do
			mult[name] = (mult[name] or 1) * 1.5
		end
	end
	if passes.VIP then
		mult.Gold = (mult.Gold or 1) * 1.1
	end
	return mult
end

return PlayerStats
