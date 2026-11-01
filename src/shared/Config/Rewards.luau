--!strict
-- Reward specs used by daily rewards, playtime gifts, codes and Index completion.
-- CashMinutes pays N minutes of the player's current income (never below MinCash) so rewards stay meaningful at
-- every stage of the game.

export type Reward = {
	Cash: number?,
	CashMinutes: number?,
	MinCash: number?,
	Boosts: { [string]: number }?,
}

local Rewards = {}

Rewards.BoostNames = {
	Overcharge = "Overcharge",
	IronDoor = "Iron Door",
	LuckyWave = "Lucky Wave",
	GoldenWave = "Golden Wave",
	InstantRepair = "Instant Repair",
}

Rewards.BoostIcons = {
	Overcharge = "⚡",
	IronDoor = "🛡️",
	LuckyWave = "🍀",
	GoldenWave = "✨",
	InstantRepair = "🔧",
}

-- Index: completing every brainrot of a rarity (base form) unlocks a one-time reward.
Rewards.IndexSets = {
	[1] = { Boosts = { Overcharge = 3 } },
	[2] = { Boosts = { Overcharge = 3, IronDoor = 1 } },
	[3] = { Boosts = { LuckyWave = 1, Overcharge = 2 } },
	[4] = { Boosts = { LuckyWave = 2, IronDoor = 2 } },
	[5] = { Boosts = { GoldenWave = 2, LuckyWave = 2 } },
	[6] = { Boosts = { LuckyWave = 3, GoldenWave = 2 } },
	[7] = { Boosts = { LuckyWave = 5, GoldenWave = 3 } },
	[8] = { Boosts = { LuckyWave = 8, GoldenWave = 5 } },
} :: { [number]: Reward }

-- Short human-readable summary, e.g. "3x ⚡ Overcharge + $12K".
function Rewards.Describe(reward: Reward, cashAmount: number?, formatCash: ((number) -> string)?): string
	local parts = {}
	if cashAmount and cashAmount > 0 and formatCash then
		table.insert(parts, formatCash(cashAmount))
	elseif reward.CashMinutes then
		table.insert(parts, string.format("%d min of cash", reward.CashMinutes))
	elseif reward.Cash and formatCash then
		table.insert(parts, formatCash(reward.Cash))
	end
	if reward.Boosts then
		local names = {}
		for name in reward.Boosts do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local count = reward.Boosts[name]
			table.insert(
				parts,
				string.format("%dx %s %s", count, Rewards.BoostIcons[name] or "", Rewards.BoostNames[name] or name)
			)
		end
	end
	return table.concat(parts, " + ")
end

return Rewards
