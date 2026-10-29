--[[
	PartyRules
	The Party mode's rules: every treasure anyone banks brings a new one, which replaces
	the one before (the first treasure brings the first). Each changes how the match
	plays (its `mutator`, read live by the engine, or `instant`: something that happens
	once when it arrives) and how the board looks while it lasts (`fx`, drawn by the
	client's PartyFx: a tint over the board and something drifting across it).

		PartyRules.list, PartyRules.get(id)
]]

local PartyRules = {}

PartyRules.list = {
	{
		id = "power_surge",
		name = "Power Surge",
		text = "Power charges twice as fast.",
		mutator = { powerMult = 2 },
		icon = "ui/star",
		color = "#FFD23F",
		fx = "sparks",
	},
	{
		id = "triple_dice",
		name = "Triple Dice",
		text = "Roll three dice and pick one.",
		mutator = { diceCount = 3 },
		icon = "ui/barrel",
		color = "#45C3FF",
		fx = "dice",
	},
	{
		id = "bonk_bonanza",
		name = "Bonk Bonanza",
		text = "Bonks knock rivals back 4 tiles.",
		mutator = { bonkBack = 4 },
		icon = "ui/cannonball",
		color = "#FF9A3C",
		fx = "bangs",
	},
	{
		id = "trap_frenzy",
		name = "Trap Frenzy",
		text = "Hide traps anywhere within 10 tiles of you.",
		mutator = { trapRange = 10 },
		icon = "ui/trap",
		color = "#FF4F5E",
		fx = "alarm",
	},
	{
		id = "gold_rush",
		name = "Gold Rush",
		text = "Every coin you get counts double.",
		mutator = { coinMult = 2 },
		icon = "ui/coin",
		color = "#F2C230",
		fx = "coins",
	},
	{
		id = "fog",
		name = "Pea-Souper",
		text = "Thick fog: no peeking where a die will take you.",
		mutator = { noPreview = true },
		icon = "ui/ghost",
		color = "#B8C8CC",
		fx = "fog",
	},
	{
		id = "card_shower",
		name = "Card Shower",
		text = "Everyone draws a free card.",
		mutator = {},
		instant = "cards",
		icon = "ui/quests",
		color = "#9A6BFF",
		fx = "cards",
	},
}

PartyRules.byId = {}
for _, r in PartyRules.list do
	PartyRules.byId[r.id] = r
end

function PartyRules.get(id: string?)
	return if id then PartyRules.byId[id] else nil
end

return PartyRules
