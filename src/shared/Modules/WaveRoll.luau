--!strict
-- Pure, deterministic-given-RNG wave rolls. Used by the server; covered by tests/waveroll.spec.luau.

local Brainrots = require(script.Parent.Parent.Config.Brainrots)
local Mutations = require(script.Parent.Parent.Config.Mutations)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Sizes = require(script.Parent.Parent.Config.Sizes)
local BrainrotStats = require(script.Parent.BrainrotStats)

export type Rng = {
	NextNumber: (self: Rng) -> number,
}

export type Roll = {
	Id: string,
	Mutation: string,
	Size: string,
	Power: number,
	Income: number,
	Rarity: number,
	Boss: boolean,
	Guaranteed: boolean,
}

export type RollParams = {
	Tier: number,
	Rebirths: number,
	Luck: number, -- 1 = normal
	MutationMult: { [string]: number }?, -- per-mutation chance multipliers from events / luck
	ForcedMutation: string?,
}

local WaveRoll = {}

local function pickWeighted<T>(rng: Rng, items: { T }, weights: { number }): T
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber() * total
	for i, w in weights do
		roll -= w
		if roll <= 0 then
			return items[i]
		end
	end
	return items[#items]
end

local function pickFromList<T>(rng: Rng, items: { T }): T
	local index = math.clamp(math.floor(rng:NextNumber() * #items) + 1, 1, #items)
	return items[index]
end

function WaveRoll.RarityOdds(tier: number, rebirths: number, luck: number): { { Rarity: number, Chance: number } }
	local window = Rarities.Window(tier, rebirths)
	local weights = {}
	local total = 0
	for position, rarityIndex in window do
		local w = Rarities.Get(rarityIndex).Weight * luck ^ (position - 1)
		weights[position] = w
		total += w
	end
	local odds = {}
	for position, rarityIndex in window do
		table.insert(odds, { Rarity = rarityIndex, Chance = weights[position] / total })
	end
	return odds
end

function WaveRoll.RollRarity(rng: Rng, tier: number, rebirths: number, luck: number): number
	local odds = WaveRoll.RarityOdds(tier, rebirths, luck)
	local items = {}
	local weights = {}
	for _, entry in odds do
		table.insert(items, entry.Rarity)
		table.insert(weights, entry.Chance)
	end
	return pickWeighted(rng, items, weights)
end

function WaveRoll.RollSize(rng: Rng): string
	local items = {}
	local weights = {}
	for _, size in Sizes.List do
		table.insert(items, size.Name)
		table.insert(weights, size.Weight)
	end
	return pickWeighted(rng, items, weights)
end

function WaveRoll.RollMutation(rng: Rng, mult: { [string]: number }?): string
	-- Check rarest first so a lucky roll is never shadowed by a common one.
	for i = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[i]
		local factor = if mult then (mult[mutation.Name] or 1) else 1
		if rng:NextNumber() * 100 < mutation.Chance * factor then
			return mutation.Name
		end
	end
	return "None"
end

local function finish(id: string, mutation: string, size: string, boss: boolean, guaranteed: boolean): Roll
	local def = Brainrots.ById[id]
	return {
		Id = id,
		Mutation = mutation,
		Size = size,
		Power = BrainrotStats.Power(id, mutation, size),
		Income = BrainrotStats.Income(id, mutation, size),
		Rarity = def.Rarity,
		Boss = boss,
		Guaranteed = guaranteed,
	}
end

function WaveRoll.RollNormal(rng: Rng, params: RollParams): Roll
	local rarity = WaveRoll.RollRarity(rng, params.Tier, params.Rebirths, params.Luck)
	local def = pickFromList(rng, Brainrots.ByRarity[rarity])
	local size = WaveRoll.RollSize(rng)
	local mutation = params.ForcedMutation or WaveRoll.RollMutation(rng, params.MutationMult)
	return finish(def.Id, mutation, size, false, false)
end

-- Boss: a brainrot whose power lands in [minMult, maxMult] x the player's crystal power.
function WaveRoll.RollBoss(rng: Rng, params: RollParams, crystalPower: number, minMult: number, maxMult: number): Roll
	local window = Rarities.Window(params.Tier, params.Rebirths)
	local top = window[#window]
	local highest = math.min(Rarities.Count, top + 1)
	local lowest = math.max(1, top - 2)
	local mutation = params.ForcedMutation or WaveRoll.RollMutation(rng, params.MutationMult)
	local candidates: { { id: string, size: string } } = {}
	local bestId, bestSize, bestDistance = "", "Normal", math.huge
	for rarity = lowest, highest do
		local bucket: { Brainrots.BrainrotDef } = Brainrots.ByRarity[rarity] or {}
		for _, def in bucket do
			for _, size in Sizes.List do
				local power = BrainrotStats.Power(def.Id, mutation, size.Name)
				local ratio = power / math.max(crystalPower, 1)
				if ratio >= minMult and ratio <= maxMult then
					table.insert(candidates, { id = def.Id, size = size.Name })
				end
				local distance = math.abs(math.log(math.max(ratio, 1e-9) / ((minMult + maxMult) / 2)))
				if distance < bestDistance then
					bestDistance = distance
					bestId = def.Id
					bestSize = size.Name
				end
			end
		end
	end
	if #candidates > 0 then
		local pick = pickFromList(rng, candidates)
		return finish(pick.id, mutation, pick.size, true, false)
	end
	return finish(bestId, mutation, bestSize, true, false)
end

-- Lucky Wave odds: rarities at or above the window's top, weighted by base rarity weight.
function WaveRoll.LuckyOdds(tier: number, rebirths: number): { { Rarity: number, Chance: number } }
	local window = Rarities.Window(tier, rebirths)
	local anchor = window[#window]
	if #window >= 2 and Rarities.Get(anchor).Weight < 0.05 then
		-- Secret jackpot at the end of the window: anchor on the rarity before it, keep Secret as a jackpot.
		anchor = window[#window - 1]
	end
	local highest = Rarities.HighestUnlocked(tier, rebirths)
	local entries = {}
	local total = 0
	for rarity = anchor, highest do
		local w = Rarities.Get(rarity).Weight
		total += w
		table.insert(entries, { Rarity = rarity, Chance = w })
	end
	for _, entry in entries do
		entry.Chance = entry.Chance / total
	end
	return entries
end

function WaveRoll.RollLucky(rng: Rng, params: RollParams): Roll
	local odds = WaveRoll.LuckyOdds(params.Tier, params.Rebirths)
	local items = {}
	local weights = {}
	for _, entry in odds do
		table.insert(items, entry.Rarity)
		table.insert(weights, entry.Chance)
	end
	local rarity = pickWeighted(rng, items, weights)
	local def = pickFromList(rng, Brainrots.ByRarity[rarity])
	local mutation = params.ForcedMutation or WaveRoll.RollMutation(rng, params.MutationMult)
	return finish(def.Id, mutation, "Normal", false, true)
end

function WaveRoll.Tutorial(): Roll
	return finish("toastino_pinguino", "None", "Normal", false, true)
end

function WaveRoll.FromSpec(id: string, mutation: string, size: string): Roll
	return finish(id, mutation, size, false, false)
end

return WaveRoll
