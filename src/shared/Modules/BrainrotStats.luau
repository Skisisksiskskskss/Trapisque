--!strict
-- Pure stat math for a brainrot instance (catalog entry + mutation + size).

local Brainrots = require(script.Parent.Parent.Config.Brainrots)
local Mutations = require(script.Parent.Parent.Config.Mutations)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Sizes = require(script.Parent.Parent.Config.Sizes)

local BrainrotStats = {}

function BrainrotStats.Power(id: string, mutation: string, size: string): number
	local def = Brainrots.Get(id)
	if def == nil then
		return 0
	end
	local rarity = Rarities.Get(def.Rarity)
	return rarity.BasePower * def.Factor * Mutations.Get(mutation).PowerMult * Sizes.Get(size).Mult
end

function BrainrotStats.Income(id: string, mutation: string, size: string): number
	local def = Brainrots.Get(id)
	if def == nil then
		return 0
	end
	local rarity = Rarities.Get(def.Rarity)
	return rarity.BaseIncome * def.Factor * Mutations.Get(mutation).IncomeMult * Sizes.Get(size).Mult
end

-- Display name, e.g. "Huge Gold Toastino Pinguino".
function BrainrotStats.DisplayName(id: string, mutation: string, size: string): string
	local def = Brainrots.Get(id)
	local name = if def then def.Name else "???"
	if mutation ~= "None" then
		name = mutation .. " " .. name
	end
	if size ~= "Normal" then
		name = size .. " " .. name
	end
	return name
end

-- Key used by the Index (collection book).
function BrainrotStats.IndexKey(id: string, mutation: string): string
	return id .. "|" .. mutation
end

return BrainrotStats
