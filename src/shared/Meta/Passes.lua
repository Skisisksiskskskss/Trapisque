--[[
	Passes
	Gamepasses sold in the Shop. None of them change match gameplay: they speed up the
	cosmetic collection or add cosmetics. Gamepass ids go in Config.GamePasses (create
	the passes on the Creator Dashboard first). A pass with id 0 is hidden in the Shop.
]]

local Config = require(script.Parent.Parent.Config)

local Passes = {}

Passes.list = {
	{
		key = "VIP",
		name = "VIP",
		color = "#C77DFF",
		icon = "crown",
		perks = {
			"+25% Gems from every match",
			"A free Explorer Chest every day",
			"Exclusive Royal Crown pawn and VIP title",
			"Gold name in parties and matches",
		},
	},
	{
		key = "DoubleGems",
		name = "2x Gems",
		color = "#4FA3FF",
		icon = "gem",
		perks = {
			"Double Gems from every match",
			"Stacks with VIP",
		},
	},
	{
		key = "LuckyCharm",
		name = "Lucky Charm",
		color = "#3CC48A",
		icon = "clover",
		randomItems = true, -- hidden where paid random items are restricted
		perks = {
			"Legendary and Mythic chest odds x1.5",
			"Chest screens show your boosted odds",
		},
	},
	{
		key = "EmotePack",
		name = "Emote Pack",
		color = "#FF9F1C",
		icon = "bubble",
		perks = {
			"6 extra emotes, yours forever",
			"Equip up to 6 emotes in matches",
		},
	},
}

Passes.byKey = {}
for _, p in Passes.list do
	Passes.byKey[p.key] = p
end

function Passes.id(key: string): number
	return (Config.GamePasses and Config.GamePasses[key]) or 0
end

function Passes.keyForId(id: number): string?
	for key, passId in Config.GamePasses do
		if passId == id and passId ~= 0 then
			return key
		end
	end
	return nil
end

return Passes
