--[[
	Passes
	Gamepasses sold in the Shop. None of them change match gameplay: they speed up the
	cosmetic collection, add cosmetics, or add ways to talk (the Chat pass unlocks typing
	your own lines; quick chat is free). Gamepass ids go in Config.GamePasses (create
	the passes on the Creator Dashboard first). A pass with id 0 is hidden in the Shop.
]]

local Config = require(script.Parent.Parent.Config)

local Passes = {}

Passes.list = {
	{
		key = "VIP",
		name = "VIP",
		color = "#F5B700",
		icon = "crown",
		perks = {
			"+25% Gems from every match",
			"A free Explorer Chest every day",
			"Exclusive Royal Crown accessory and VIP title",
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
	{
		key = "Chat",
		name = "Chat",
		color = "#2E8FB3",
		icon = "bubble",
		perks = {
			"Type your own lines in the game chat",
			"(Quick chat lines are free for everyone)",
			"Needs chat to be on in your Roblox settings",
		},
	},
	{
		key = "VoicePack",
		name = "Voice Pack",
		color = "#D94C9C",
		icon = "music",
		perks = {
			"Pick the voice your chat bubbles talk in",
			"Grumbly, Captain, Dandy, Parrot, Ghostly, Clockwork...",
		},
	},
	{
		key = "VictoryParade",
		name = "Victory Parade",
		color = "#F5B700",
		icon = "star",
		perks = {
			"Cannons, streamers and a brass fanfare when you win",
			"Everyone in the match sees it",
		},
	},
	{
		key = "CaptainsChest",
		name = "Captain's Chest",
		color = "#2B4C7E",
		icon = "chest",
		perks = {
			"The Admiral accessory pack (bicorne and medals)",
			"The Golden Doubloon dice and the Captain title",
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
