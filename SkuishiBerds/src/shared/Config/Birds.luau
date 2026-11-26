--[[
	Birds: the roster. Every bird has exactly one ability, charged by strumming
	(crossing the middle line). Abilities are sidegrades: cheaper abilities are
	smaller, stronger ones cost more strums. Nothing here is sold for an edge;
	birds can be unlocked with coins (Robux is only a shortcut).

	silhouette fields are read by the renderer so each bird is recognisable even
	with custom colors/patterns/hats:
	  beak:  "classic" | "needle" | "stub" | "puffin" | "chisel" | "hook" | "bill" | "bent"
	  crest: nil | "tuft" | "mohawk" | "ears"
	  eye:   "round" | "sparkle" | "owl" | "angry" | "sleepy"
	  extra: nil | "facepatch" | "cheeks" | "longneck"
]]

export type BirdDef = {
	id: string,
	name: string,
	tagline: string,
	ability: string,
	abilityName: string,
	abilityDesc: string,
	cost: number,
	price: number,
	order: number,
	defaultColor: string,
	silhouette: { beak: string, crest: string?, eye: string, extra: string? },
	productKey: string?,
}

local Birds = {}

Birds.List = {
	{
		id = "berd",
		name = "Berd",
		tagline = "The original skuishi. Round, reliable, iconic.",
		ability = "UTURN",
		abilityName = "U-Turn",
		abilityDesc = "Instantly flip your flying direction with a little hop. Dodge a wall full of spikes.",
		cost = 3,
		price = 0,
		order = 1,
		defaultColor = "#ffb3ba",
		silhouette = { beak = "classic", eye = "round" },
	},
	{
		id = "zippy",
		name = "Zippy",
		tagline = "A hummingbird with zero chill.",
		ability = "DASH",
		abilityName = "Dash",
		abilityDesc = "Burst forward at 2.6x speed for 0.4s, phasing through event hazards (not spikes).",
		cost = 3,
		price = 600,
		order = 2,
		defaultColor = "#84fab0",
		silhouette = { beak = "needle", eye = "sparkle", crest = "tuft" },
		productKey = "Bird_zippy",
	},
	{
		id = "blinky",
		name = "Blinky",
		tagline = "Now you see it. Now you also see it, but higher.",
		ability = "BLINK",
		abilityName = "Blink",
		abilityDesc = "Teleport a short hop 'up' (against your gravity), wrapping around the screen.",
		cost = 3,
		price = 750,
		order = 3,
		defaultColor = "#c9b6e4",
		silhouette = { beak = "stub", eye = "sparkle", extra = "cheeks" },
		productKey = "Bird_blinky",
	},
	{
		id = "puffin",
		name = "Puff",
		tagline = "Inflates when stressed. Always stressed.",
		ability = "PUFF",
		abilityName = "Puff Up",
		abilityDesc = "For 1.5s spikes can't hurt you, but you're bigger and heavier.",
		cost = 4,
		price = 900,
		order = 4,
		defaultColor = "#333333",
		silhouette = { beak = "puffin", eye = "round", extra = "facepatch" },
		productKey = "Bird_puffin",
	},
	{
		id = "pecky",
		name = "Pecky",
		tagline = "Solves problems with its face.",
		ability = "PECK",
		abilityName = "Peck",
		abilityDesc = "For 3s, the first spike you touch shatters instead of hurting you.",
		cost = 4,
		price = 900,
		order = 5,
		defaultColor = "#bae1ff",
		silhouette = { beak = "chisel", eye = "angry", crest = "mohawk" },
		productKey = "Bird_pecky",
	},
	{
		id = "hoot",
		name = "Hoot",
		tagline = "Sees everything. Slowly.",
		ability = "FOCUS",
		abilityName = "Focus",
		abilityDesc = "For 3s your own bird moves at half speed and shows its flight path.",
		cost = 4,
		price = 1100,
		order = 6,
		defaultColor = "#ffd1a9",
		silhouette = { beak = "hook", eye = "owl", crest = "ears" },
		productKey = "Bird_hoot",
	},
	{
		id = "honk",
		name = "Honk",
		tagline = "Peace was never an option.",
		ability = "HONK",
		abilityName = "HONK",
		abilityDesc = "A shockwave that pops nearby hazards. In Versus it shoves rivals and makes their flaps weak.",
		cost = 5,
		price = 1300,
		order = 7,
		defaultColor = "#fff5e1",
		silhouette = { beak = "bill", eye = "angry", extra = "longneck" },
		productKey = "Bird_honk",
	},
	{
		id = "flippy",
		name = "Flippy",
		tagline = "Gravity is more of a suggestion.",
		ability = "FLIP",
		abilityName = "Flip",
		abilityDesc = "Toggle your own gravity. Stays flipped until you flip back.",
		cost = 3,
		price = 1100,
		order = 8,
		defaultColor = "#ff77ff",
		silhouette = { beak = "bent", eye = "sleepy" },
		productKey = "Bird_flippy",
	},
} :: { BirdDef }

Birds.ById = {} :: { [string]: BirdDef }
for _, def in Birds.List do
	Birds.ById[def.id] = def
end

Birds.DEFAULT = "berd"

function Birds.get(id: string?): BirdDef
	return Birds.ById[id or ""] or Birds.ById[Birds.DEFAULT]
end

return Birds
