--!strict
-- Pure economy formulas. Tuned with the pacing simulation in tests/economy.spec.luau (see DECISIONS.md).

local Economy = {}

Economy.MaxTier = 10
Economy.LevelsPerTier = 10
Economy.SlotsPerTier = { 4, 6, 8, 10, 12, 14, 16, 18, 21, 24 }

Economy.CrystalBase = 12
Economy.DoorBase = 20
Economy.PowerGrowth = 1.12
Economy.CrystalCostBase = 22
Economy.CostGrowth = 1.165
Economy.DoorCostFactor = 0.8
Economy.TierCostBase = 600
Economy.TierCostGrowth = 6.5
Economy.RebirthCostBase = 1e9
Economy.RebirthCostGrowth = 3
Economy.RebirthCashBonus = 0.5
Economy.RebirthPowerBonus = 0.15
Economy.IndexBonusPerEntry = 0.02 -- +2% cash per unique brainrot discovered

export type Multipliers = {
	cash: number,
	crystal: number,
	door: number,
	luck: number,
}

function Economy.MaxLevelForTier(tier: number): number
	return tier * Economy.LevelsPerTier
end

function Economy.Slots(tier: number): number
	local clamped = math.clamp(tier, 1, Economy.MaxTier)
	return Economy.SlotsPerTier[clamped]
end

function Economy.CrystalPower(level: number, mult: number): number
	return Economy.CrystalBase * Economy.PowerGrowth ^ (level - 1) * mult
end

function Economy.DoorStrength(level: number, mult: number): number
	return Economy.DoorBase * Economy.PowerGrowth ^ (level - 1) * mult
end

function Economy.CrystalCost(level: number): number
	return math.floor(Economy.CrystalCostBase * Economy.CostGrowth ^ (level - 1))
end

function Economy.DoorCost(level: number): number
	return math.floor(Economy.CrystalCost(level) * Economy.DoorCostFactor)
end

function Economy.TierCost(tier: number): number
	return math.floor(Economy.TierCostBase * Economy.TierCostGrowth ^ (tier - 1))
end

function Economy.RebirthCost(rebirths: number): number
	return Economy.RebirthCostBase * Economy.RebirthCostGrowth ^ rebirths
end

function Economy.CanTierUp(tier: number, crystalLevel: number): boolean
	return tier < Economy.MaxTier and crystalLevel >= Economy.MaxLevelForTier(tier)
end

function Economy.CanRebirth(tier: number, crystalLevel: number, cash: number, rebirths: number): boolean
	return tier >= Economy.MaxTier
		and crystalLevel >= Economy.MaxLevelForTier(Economy.MaxTier)
		and cash >= Economy.RebirthCost(rebirths)
end

-- Sell value of a brainrot: 60 seconds of its income, so selling is a convenience, never a money printer.
function Economy.SellValue(incomePerSecond: number): number
	return math.floor(incomePerSecond * 60)
end

-- Cash pack amount: N seconds of the player's current income, never below the floor.
function Economy.ScaledCash(incomePerSecond: number, seconds: number, floor: number): number
	return math.max(floor, math.floor(incomePerSecond * seconds))
end

return Economy
