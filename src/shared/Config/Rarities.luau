--!strict
-- Rarity tiers. Power and income are per-rarity baselines; each brainrot multiplies them by its own factor.

export type Rarity = {
	Index: number,
	Name: string,
	Color: Color3,
	Weight: number,
	BasePower: number,
	BaseIncome: number,
	UnlockTier: number,
	Announce: boolean,
}

local list: { Rarity } = {
	{
		Index = 1,
		Name = "Common",
		Color = Color3.fromRGB(190, 190, 190),
		Weight = 60,
		BasePower = 10,
		BaseIncome = 1,
		UnlockTier = 1,
		Announce = false,
	},
	{
		Index = 2,
		Name = "Uncommon",
		Color = Color3.fromRGB(90, 215, 90),
		Weight = 25,
		BasePower = 40,
		BaseIncome = 4,
		UnlockTier = 1,
		Announce = false,
	},
	{
		Index = 3,
		Name = "Rare",
		Color = Color3.fromRGB(60, 150, 255),
		Weight = 10,
		BasePower = 120,
		BaseIncome = 14,
		UnlockTier = 2,
		Announce = false,
	},
	{
		Index = 4,
		Name = "Epic",
		Color = Color3.fromRGB(175, 85, 255),
		Weight = 4,
		BasePower = 400,
		BaseIncome = 50,
		UnlockTier = 3,
		Announce = false,
	},
	{
		Index = 5,
		Name = "Legendary",
		Color = Color3.fromRGB(255, 195, 40),
		Weight = 1.2,
		BasePower = 3500,
		BaseIncome = 300,
		UnlockTier = 5,
		Announce = true,
	},
	{
		Index = 6,
		Name = "Mythic",
		Color = Color3.fromRGB(255, 70, 70),
		Weight = 0.3,
		BasePower = 30000,
		BaseIncome = 2000,
		UnlockTier = 7,
		Announce = true,
	},
	{
		Index = 7,
		Name = "Brainrot God",
		Color = Color3.fromRGB(255, 120, 230),
		Weight = 0.06,
		BasePower = 300000,
		BaseIncome = 15000,
		UnlockTier = 9,
		Announce = true,
	},
	{
		Index = 8,
		Name = "Secret",
		Color = Color3.fromRGB(20, 20, 20),
		Weight = 0.01,
		BasePower = 2500000,
		BaseIncome = 90000,
		UnlockTier = 10,
		Announce = true,
	},
}

local byName: { [string]: Rarity } = {}
for _, rarity in list do
	byName[rarity.Name] = rarity
end

local Rarities = {
	List = list,
	ByName = byName,
	Count = #list,
}

function Rarities.Get(index: number): Rarity
	local rarity = list[index]
	assert(rarity ~= nil, "unknown rarity index " .. tostring(index))
	return rarity
end

-- Highest rarity index that can appear for a base tier (Secret also unlocks after the first rebirth).
function Rarities.HighestUnlocked(tier: number, rebirths: number): number
	local highest = 1
	for _, rarity in list do
		if rarity.UnlockTier <= tier then
			highest = rarity.Index
		end
	end
	if rebirths >= 1 then
		highest = math.max(highest, list[#list].Index)
	end
	return highest
end

-- The rarities that normal waves draw from: the highest unlocked and the two below it.
function Rarities.Window(tier: number, rebirths: number): { number }
	local hi = Rarities.HighestUnlocked(tier, rebirths)
	-- Secret is a jackpot add-on, never the anchor of the window.
	local anchor = hi
	if hi == #list and Rarities.HighestUnlocked(tier, 0) < hi then
		anchor = Rarities.HighestUnlocked(tier, 0)
	elseif hi == #list then
		anchor = hi - 1
	end
	local lo = math.max(1, anchor - 2)
	local window = {}
	for i = lo, anchor do
		table.insert(window, i)
	end
	if hi > anchor then
		table.insert(window, hi)
	end
	return window
end

return Rarities
