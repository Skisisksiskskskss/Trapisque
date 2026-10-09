--[[
	Items
	Every card in Trapisque. A card has:
		category  trap | assist | neutral | potion | natural | coin
		use       how the card is played:
		            place     - put on a board tile (ends your turn)
		            boost     - arm before rolling; changes this turn's roll (free)
		            passive   - sits in your hand and triggers automatically
		            regen     - recharge your character ability (free)
		            anchor    - Time Travel: drop an anchor where you stand (free)
		            moonwalk  - step back 1-3 tiles (ends your turn)
		            telepathy - move any player 1-3 tiles (ends your turn)
		            jeopardy  - Double Jeopardy (ends your turn)
		free      true when using it does NOT end your turn
]]

local Items = {}

local defs = {
	-- Trap cards ------------------------------------------------------------
	{
		id = "spike",
		name = "Spike",
		category = "trap",
		use = "place",
		short = "Lander dies",
		text = "Place on a tile. Whoever lands here dies and must restart their cycle.",
	},
	{
		id = "fire",
		name = "Fire",
		category = "trap",
		use = "place",
		short = "Lander burns",
		text = "Place on a tile. The lander Burns until their cycle ends: trap penalties are doubled, assist cards are halved and dying also costs a treasure.",
	},
	{
		id = "ice",
		name = "Ice",
		category = "trap",
		use = "place",
		short = "Lander freezes",
		text = "Place on a tile. The lander is Frozen until their cycle ends: even rolls are halved, odd rolls lose 1.",
	},
	{
		id = "mudslide",
		name = "Mudslide",
		category = "trap",
		use = "place",
		short = "Back 2",
		text = "Place on a tile. The lander slides back 2 tiles.",
	},
	{
		id = "mud",
		name = "Mud",
		category = "trap",
		use = "place",
		short = "Back 1",
		text = "Place on a tile. The lander slips back 1 tile.",
	},
	{
		id = "wall",
		name = "Wall",
		category = "trap",
		use = "place",
		short = "Blocks moves under 5",
		text = "Place on a tile. Nobody can move past it unless they move 5 or more. Landing exactly on it is fine. It crumbles once someone gets over it.",
	},
	{
		id = "snare",
		name = "Snare",
		category = "trap",
		use = "place",
		short = "Skip a turn",
		text = "Place on a tile. The lander skips their next turn.",
	},
	{
		id = "grog",
		name = "Grog",
		category = "trap",
		use = "place",
		short = "Roll 4+ or die",
		text = "Place a Grog monster. The lander must roll 4 or more or the Grog eats them.",
	},

	-- Assist cards ----------------------------------------------------------
	{
		id = "regeneration",
		name = "Regeneration",
		category = "assist",
		use = "regen",
		free = true,
		short = "Recharge ability",
		text = "Free: instantly recharge your character's ability.",
	},
	{
		id = "bounce_pad",
		name = "Bounce Pad",
		category = "assist",
		use = "boost",
		free = true,
		short = "+2 this move",
		text = "Boost: arm before rolling to move 2 extra tiles this turn.",
	},
	{
		id = "speed_boost",
		name = "Speed Boost",
		category = "assist",
		use = "boost",
		free = true,
		short = "x2 this move",
		text = "Boost: arm before rolling to double this turn's move.",
	},
	{
		id = "bridge",
		name = "Bridge",
		category = "assist",
		use = "passive",
		short = "Cross a river",
		text = "Automatic: lets you cross one river without falling in.",
	},
	{
		id = "key",
		name = "Key",
		category = "assist",
		use = "passive",
		short = "Open a gate",
		text = "Automatic: opens one locked gate, or a gated shortcut.",
	},
	{
		id = "boots",
		name = "Boots",
		category = "assist",
		use = "passive",
		short = "Walk through slime",
		text = "Automatic: the first time slime would slow you, you pull these on and ignore slime for the rest of the cycle.",
	},
	{
		id = "shield",
		name = "Shield",
		category = "assist",
		use = "passive",
		short = "Block one trap",
		text = "Automatic: blocks the next trap you trigger.",
	},
	{
		id = "moonwalk",
		name = "Moonwalk",
		category = "assist",
		use = "moonwalk",
		short = "Back 1-3",
		text = "Action: step back 1 to 3 tiles of your choice. You land like a normal move.",
	},

	-- Neutral cards ---------------------------------------------------------
	{
		id = "teleporter",
		name = "Teleporter",
		category = "neutral",
		use = "place",
		short = "Linked pairs",
		text = "Place on a tile at least 8 tiles from the treasure. Teleporters link in pairs: landing on one sends you to its partner.",
	},
	{
		id = "spore_warper",
		name = "Spore Warper",
		category = "neutral",
		use = "place",
		short = "Swap with nearest",
		text = "Place on a tile. The lander swaps places with the nearest player.",
	},
	{
		id = "conveyor",
		name = "Conveyor Belt",
		category = "neutral",
		use = "place",
		short = "3-tile belt",
		text = "Place a 3-tile belt facing forward or backward. Anyone landing on it rides it off the end.",
	},
	{
		id = "shifting_sands",
		name = "Shifting Sands",
		category = "neutral",
		use = "place",
		short = "Moves by treasures",
		text = "Place on a tile. On an even cycle the lander moves forward by their treasure count; on an odd cycle, backward.",
	},

	-- Potions (Potion Seller) -------------------------------------------------
	{
		id = "speed_potion",
		name = "Speed Potion",
		category = "potion",
		use = "boost",
		free = true,
		price = 1,
		short = "+1 this move",
		text = "Boost: arm before rolling to move 1 extra tile this turn.",
	},
	{
		id = "phoenix_potion",
		name = "Phoenix Potion",
		category = "potion",
		use = "passive",
		price = 2,
		short = "Survive a death",
		text = "Automatic: the next time you would die, you survive instead.",
	},
	{
		id = "time_potion",
		name = "Time Travel Potion",
		category = "potion",
		use = "anchor",
		free = true,
		price = 3,
		short = "Anchor & recall",
		text = "Free: drop a time anchor where you stand. On a later turn, use your action to warp back to it.",
	},
	{
		id = "telepathy_potion",
		name = "Telepathy Potion",
		category = "potion",
		use = "telepathy",
		price = 4,
		short = "Move anyone 1-3",
		text = "Action: move any player 1 to 3 tiles forward or backward.",
	},
	{
		id = "jeopardy_potion",
		name = "Double Jeopardy",
		category = "potion",
		use = "jeopardy",
		price = 5,
		short = "Swap hands, 6 & 6",
		text = "Action: swap hands with a player, push them back 6 tiles and jump forward 6 yourself.",
	},

	-- Natural trap cards (Naturalist only) -----------------------------------
	{
		id = "river_trap",
		name = "River",
		category = "natural",
		use = "place",
		natural = "river",
		short = "Ends your move",
		text = "Place a river. Anyone without a Bridge falls in and their move ends there. Naturalists swim through.",
	},
	{
		id = "gate_trap",
		name = "Locked Gate",
		category = "natural",
		use = "place",
		natural = "gate",
		short = "Stuck until 4+",
		text = "Place a locked gate. Anyone without a Key stops on it and is stuck until they roll 4+.",
	},
	{
		id = "slime_trap",
		name = "Slime",
		category = "natural",
		use = "place",
		natural = "slime",
		short = "Halves moves",
		text = "Place slime. Moving through it without Boots halves your move (odd moves lose 1).",
	},

	-- Not a card: coins are tracked separately -------------------------------
	{
		id = "coin",
		name = "Coin",
		category = "coin",
		use = "none",
		short = "+1 coin",
		text = "Spend coins at the Potion Seller.",
	},
}

Items.byId = {}
Items.list = {}
for i, def in defs do
	def.order = i
	def.free = def.free == true
	Items.byId[def.id] = def
	table.insert(Items.list, def)
end

-- The three spinners. "bkb" is replaced by the map's counter item (Bridge/Key/Boots),
-- or by the map's natural trap card when the Naturalist spins.
Items.wheels = {
	trap = { "spike", "fire", "ice", "mudslide", "mud", "wall", "snare", "grog", "coin" },
	assist = { "regeneration", "bounce_pad", "speed_boost", "bkb", "shield", "moonwalk", "coin" },
	neutral = { "teleporter", "spore_warper", "conveyor", "shifting_sands", "coin" },
}

Items.potions = { "speed_potion", "phoenix_potion", "time_potion", "telepathy_potion", "jeopardy_potion" }

Items.trapIds = { "spike", "fire", "ice", "mudslide", "mud", "wall", "snare", "grog" }

-- Natural trap kind -> the card that counters it
Items.naturalCounter = {
	river = "bridge",
	gate = "key",
	slime = "boots",
}

function Items.get(id: string)
	return Items.byId[id]
end

function Items.isTrap(id: string): boolean
	local def = Items.byId[id]
	return def ~= nil and def.category == "trap"
end

return Items
