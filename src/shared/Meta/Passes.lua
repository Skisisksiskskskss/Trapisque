--[[
	Passes
	What the Shop sells for Robux. None of it changes how a match plays: it speeds up
	or adds to the cosmetic collection, or adds ways to talk and show off.

	  Passes.list      gamepasses (bought once). Ids in Config.GamePasses; a pass at 0
	                   shows as "Soon". `gift` is handed over once, the first time the
	                   owner joins after buying it (Gems, free chests).
	  Passes.gemPacks  Gem packs: developer products, bought as often as you like. Ids
	                   in Config.DevProducts; a pack at 0 is hidden.

	`robux` is the price to set on the Creator Dashboard (the Shop shows Roblox's own
	price). Anything that buys a random item (Gems open Treasure Chests) is
	`randomItems`: hidden for players whose region doesn't allow paid random items.
]]

local Config = require(script.Parent.Parent.Config)

local Passes = {}

Passes.list = {
	{
		key = "StarterPack",
		name = "Starter Pack",
		color = "#E8643C",
		icon = "chest",
		picture = "ui/chest",
		robux = 49,
		badge = "Best value",
		randomItems = true,
		gift = { gems = 1500, chests = { explorer = 3 } },
		perks = {
			"1,500 Gems, straight away",
			"3 free Explorer Chests",
			"Once per player",
		},
	},
	{
		key = "VIP",
		name = "VIP",
		color = "#F5B700",
		icon = "crown",
		picture = "ui/crown",
		robux = 129,
		perks = {
			"+25% Gems from every match",
			"A free Explorer Chest every day",
			"The Royal finish and the VIP title",
			"A gold name, and a victory parade when you win",
		},
	},
	{
		key = "DoubleGems",
		name = "2x Gems",
		color = "#3FA7F5",
		icon = "gem",
		picture = "ui/gem",
		robux = 99,
		perks = {
			"Double Gems from every match",
			"Stacks with VIP",
		},
	},
	{
		key = "CaptainsChest",
		name = "Captain's Chest",
		color = "#2B4C7E",
		icon = "chest",
		picture = "ui/locker",
		robux = 79,
		gift = { gems = 500 },
		perks = {
			"The Admiralty finish (navy and gold)",
			"The Golden Doubloon dice and the Captain title",
			"500 Gems to start your collection",
		},
	},
	{
		key = "LuckyCharm",
		name = "Lucky Charm",
		color = "#3CC48A",
		icon = "clover",
		picture = "ui/coin",
		robux = 49,
		randomItems = true,
		perks = {
			"Legendary and Mythic chest odds x1.5",
			"The chest screens show your boosted odds",
		},
	},
	{
		key = "EmotePack",
		name = "Emote Pack",
		color = "#FF9F1C",
		icon = "bubble",
		picture = "ui/chat",
		robux = 25,
		perks = {
			"6 extra emotes, yours forever",
			"Equip up to 6 emotes in matches",
		},
	},
	{
		key = "Chat",
		name = "Chat",
		color = "#2E8FB3",
		icon = "bubble",
		picture = "ui/chat",
		robux = 10,
		perks = {
			"Type your own lines in the game chat",
			"Quick lines are free for everyone",
			"Needs chat on in your Roblox settings",
		},
	},
}

-- Gems for Robux, as often as you like: more Gems per Robux the bigger the pack.
Passes.gemPacks = {
	{ key = "Gems250", gems = 250, robux = 25, pile = 1 },
	{ key = "Gems600", gems = 600, robux = 49, pile = 2 },
	{ key = "Gems1400", gems = 1400, robux = 99, pile = 3, badge = "Popular" },
	{ key = "Gems3000", gems = 3000, robux = 199, pile = 4 },
	{ key = "Gems8000", gems = 8000, robux = 449, pile = 5, badge = "Best value" },
}

Passes.byKey = {}
for _, p in Passes.list do
	Passes.byKey[p.key] = p
end
Passes.packByKey = {}
for _, p in Passes.gemPacks do
	Passes.packByKey[p.key] = p
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

function Passes.productId(key: string): number
	return (Config.DevProducts and Config.DevProducts[key]) or 0
end

-- The Gem pack a developer product id sells, if any.
function Passes.packForProduct(productId: number)
	for key, id in Config.DevProducts or {} do
		if id == productId and id ~= 0 then
			return Passes.packByKey[key]
		end
	end
	return nil
end

return Passes
