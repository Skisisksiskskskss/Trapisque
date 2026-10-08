--[[
	Gacha (Treasure Chests)
	Chests are opened with Gems, which are only earned by playing. Odds are always shown
	to players (Roblox requires odds disclosure for random items), there is a pity
	counter, and duplicates turn back into Gems.

	Pure logic: the server calls Gacha.roll with its own RNG and the player's saved
	pity counters, and this module is unit-tested offline.
]]

local Cosmetics = require(script.Parent.Cosmetics)

local Gacha = {}

Gacha.chests = {
	{
		id = "explorer",
		name = "Explorer Chest",
		blurb = "Everything can drop. Great for starting a collection.",
		price = 100,
		tenPrice = 900, -- one chest free when opening 10
		odds = { common = 62, rare = 26, epic = 9, legendary = 2.5, mythic = 0.5 },
		-- guaranteed drop of at least this rarity after N chests without one
		pity = { { rarity = "epic", every = 10 }, { rarity = "legendary", every = 50 } },
		look = { body = "#8B5E34", trim = "#D4A373", band = "#6F4518", gem = "#4FA3FF" },
	},
	{
		id = "royal",
		name = "Royal Chest",
		blurb = "No commons. Much better shot at Legendary and Mythic.",
		price = 350,
		tenPrice = 3150,
		odds = { rare = 58, epic = 30, legendary = 10, mythic = 2 },
		pity = { { rarity = "legendary", every = 20 } },
		look = { body = "#5A189A", trim = "#FFD60A", band = "#3C096C", gem = "#FF5FA2" },
	},
}
Gacha.byId = {}
for _, c in Gacha.chests do
	Gacha.byId[c.id] = c
end

-- Lucky Charm gamepass: Legendary and Mythic weights are multiplied, then all odds are
-- re-normalised. The adjusted odds are what the chest screen shows.
Gacha.luck = { legendary = 1.5, mythic = 1.5 }

-- Gems refunded for a duplicate
Gacha.dupeRefund = { common = 15, rare = 40, epic = 90, legendary = 220, mythic = 500 }

-- Unowned items are this many times more likely than owned ones within a rarity.
Gacha.newItemBias = 3

local RARITY_ORDER = { common = 1, rare = 2, epic = 3, legendary = 4, mythic = 5 }

-- Percent odds per rarity (sums to 100), with or without the Lucky Charm.
function Gacha.odds(chest, lucky: boolean?)
	local weights = {}
	local total = 0
	for rarity, w in chest.odds do
		local m = if lucky then (Gacha.luck[rarity] or 1) else 1
		weights[rarity] = w * m
		total += w * m
	end
	local out = {}
	for rarity, w in weights do
		out[rarity] = w / total * 100
	end
	return out
end

local function pickRarity(rng, odds, minRank: number)
	local entries = {}
	for rarity, pct in odds do
		if RARITY_ORDER[rarity] >= minRank and pct > 0 then
			table.insert(entries, { rarity, pct })
		end
	end
	table.sort(entries, function(a, b)
		return RARITY_ORDER[a[1]] < RARITY_ORDER[b[1]]
	end)
	if #entries == 0 then
		return nil
	end
	return rng:weighted(entries)
end

--[[
	Rolls one chest.
		chest   a Gacha.chests entry
		pity    { [rarity] = chests since that rarity or better } (mutated)
		owned   { [itemId] = true }
		rng     object with :float() / :weighted() (see Game/Rng)
		lucky   Lucky Charm active?
	Returns itemId, rarity, pityTriggered
]]
function Gacha.roll(chest, pity, owned, rng, lucky: boolean?)
	local odds = Gacha.odds(chest, lucky)
	local pool = Cosmetics.chestPool()

	-- pity: the highest guaranteed rarity whose counter is due
	local minRank = 1
	local pityHit = false
	for _, rule in chest.pity do
		local since = pity[rule.rarity] or 0
		if since + 1 >= rule.every and RARITY_ORDER[rule.rarity] > minRank then
			minRank = RARITY_ORDER[rule.rarity]
			pityHit = true
		end
	end

	local rarity = pickRarity(rng, odds, minRank)
	if rarity == nil or #pool[rarity] == 0 then
		-- fall back to the closest rarity that has items
		rarity = nil
		for r, _ in odds do
			if #pool[r] > 0 and (rarity == nil or RARITY_ORDER[r] > RARITY_ORDER[rarity]) then
				rarity = r
			end
		end
	end
	assert(rarity, "Gacha: chest has no items")

	-- prefer items the player doesn't own yet
	local entries = {}
	for _, id in pool[rarity] do
		table.insert(entries, { id, if owned[id] then 1 else Gacha.newItemBias })
	end
	local item = rng:weighted(entries)

	-- update pity counters: reset every rule at or below the rarity we got
	for _, rule in chest.pity do
		if RARITY_ORDER[rarity] >= RARITY_ORDER[rule.rarity] then
			pity[rule.rarity] = 0
		else
			pity[rule.rarity] = (pity[rule.rarity] or 0) + 1
		end
	end
	return item, rarity, pityHit
end

function Gacha.rarityRank(rarity: string): number
	return RARITY_ORDER[rarity] or 0
end

return Gacha
