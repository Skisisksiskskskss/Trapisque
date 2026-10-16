--[[
	Items
	Every card in Trapisque. A card has:
		category  trap | assist | neutral | potion | coin
		use       how the card is played (each turn you may play ONE card):
		            place     - put it on a tile near you (traps are hidden from opponents)
		            boost     - changes the move you're about to make (speed, bounce, moonwalk)
		            passive   - stays in your hand and works by itself (Shield, Bridge...)
		            juice     - fills your Power bar
		            reroll    - roll your dice again
		            anchor    - Time Travel: drop an anchor where you stand
		            telepathy - move any player 1-3 tiles
		            jeopardy  - Double Jeopardy
		            xray      - see every hidden trap
		hidden    traps that opponents can't see once placed (everything else is visible)
]]

local Items = {}

local defs = {
	-- Traps (hidden from opponents) ---------------------------------------------
	{
		id = "spike",
		name = "Spike",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Back to Start",
		text = "Hide it near you. Whoever lands here is knocked out and goes back to the Start.",
	},
	{
		id = "grog",
		name = "Grog",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Roll 4+ or get eaten",
		text = "Hide a hungry Grog near you. Whoever lands here rolls a die: 1 to 3 and the Grog eats them (back to the Start).",
	},
	{
		id = "fire",
		name = "Fire",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Burns them",
		text = "Hide it near you. Whoever lands here is Burning: they hop back 1 tile at the start of their next 2 turns.",
	},
	{
		id = "ice",
		name = "Ice",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Freezes them",
		text = "Hide it near you. Whoever lands here is Frozen: their next 2 turns they roll just one die and charge no Power.",
	},
	{
		id = "snare",
		name = "Snare",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Skip a turn",
		text = "Hide it near you. Whoever lands here skips their next turn.",
	},
	{
		id = "mudslide",
		name = "Mudslide",
		category = "trap",
		use = "place",
		hidden = true,
		short = "Slide back 3",
		text = "Hide it near you. Whoever lands here slides back 3 tiles.",
	},
	{
		id = "banana",
		name = "Banana Peel",
		nick = "Banana", -- on cards too small for the whole name
		category = "trap",
		use = "place",
		hidden = true,
		short = "Slip back 2, drop a card",
		text = "Hide it near you. Whoever lands here slips back 2 tiles and drops a random card.",
	},
	{
		id = "wall",
		name = "Wall",
		category = "trap",
		use = "place",
		short = "Blocks moves under 5",
		text = "Build it near you, where everyone can see it. Nobody gets past unless they move 5 or more. It crumbles once someone gets over it.",
	},

	-- Assist cards ----------------------------------------------------------------
	{
		id = "speed_boost",
		name = "Speed Boost",
		nick = "Boost", -- on cards too small for the whole name
		category = "assist",
		use = "boost",
		boost = "double",
		short = "Double your move",
		text = "Play before you move: the die you pick counts double.",
	},
	{
		id = "bounce_pad",
		name = "Bounce Pad",
		nick = "Bounce", -- on cards too small for the whole name
		category = "assist",
		use = "boost",
		boost = "plus",
		amount = 3,
		short = "+3 to your move",
		text = "Play before you move: move 3 extra tiles.",
	},
	{
		id = "moonwalk",
		name = "Moonwalk",
		category = "assist",
		use = "boost",
		boost = "back",
		short = "Move backwards",
		text = "Play before you move: this turn you move backwards. Great for grabbing a token or bonking someone behind you.",
	},
	{
		id = "clover",
		name = "Lucky Clover",
		nick = "Clover", -- on cards too small for the whole name
		category = "assist",
		use = "reroll",
		short = "Reroll your dice",
		text = "Don't like your dice? Roll them again.",
	},
	{
		id = "juice",
		name = "Juice Box",
		nick = "Juice", -- on cards too small for the whole name
		category = "assist",
		use = "juice",
		short = "Fill your Power",
		text = "Fills your Power bar, so your ability is ready right now.",
	},
	{
		id = "shield",
		name = "Shield",
		category = "assist",
		use = "passive",
		short = "Blocks a trap or bonk",
		text = "Works by itself: blocks the next trap you land on or the next bonk that hits you.",
	},
	{
		id = "bridge",
		name = "Bridge",
		category = "assist",
		use = "passive",
		short = "Cross a river",
		text = "Works by itself: carries you across one river.",
	},
	{
		id = "key",
		name = "Key",
		category = "assist",
		use = "passive",
		short = "Open a gate",
		text = "Works by itself: opens one locked gate or gated shortcut.",
	},
	{
		id = "boots",
		name = "Boots",
		category = "assist",
		use = "passive",
		short = "Walk through slime",
		text = "Works by itself: carries you through one slime pool.",
	},

	-- Neutral cards (visible board pieces) -----------------------------------------
	{
		id = "teleporter",
		name = "Teleporter",
		category = "neutral",
		use = "place",
		short = "Linked pairs",
		text = "Place it near you, at least 8 tiles from the treasure. Teleporters link in pairs: landing on one sends you to its partner.",
	},
	{
		id = "spore_warper",
		name = "Spore Warper",
		nick = "Spores", -- on cards too small for the whole name
		category = "neutral",
		use = "place",
		short = "Swap with nearest",
		text = "Place it near you. Whoever lands here swaps places with the nearest other player.",
	},
	{
		id = "conveyor",
		name = "Conveyor Belt",
		nick = "Conveyor", -- on cards too small for the whole name
		category = "neutral",
		use = "place",
		short = "3-tile belt",
		text = "Place a 3-tile belt near you, facing forward or back. Anyone landing on it rides it off the end. It wears out after 3 rides.",
	},
	{
		id = "trampoline",
		name = "Trampoline",
		category = "neutral",
		use = "place",
		short = "Bounce ahead 3",
		text = "Place it near you. Whoever lands here bounces 3 tiles forward. It wears out after 2 bounces.",
	},

	-- Potions (Potion Seller) ---------------------------------------------------------
	{
		id = "speed_potion",
		name = "Speed Potion",
		nick = "Speed", -- on cards too small for the whole name
		category = "potion",
		use = "boost",
		boost = "plus",
		amount = 2,
		price = 1,
		short = "+2 to your move",
		text = "Play before you move: move 2 extra tiles.",
	},
	{
		id = "phoenix_potion",
		name = "Phoenix Potion",
		nick = "Phoenix", -- on cards too small for the whole name
		category = "potion",
		use = "passive",
		price = 2,
		short = "Survive a knockout",
		text = "Works by itself: the next time you'd be knocked out (Spike, Grog), you survive instead.",
	},
	{
		id = "xray_potion",
		name = "X-Ray Potion",
		nick = "X-Ray", -- on cards too small for the whole name
		category = "potion",
		use = "xray",
		price = 2,
		short = "See hidden traps",
		text = "Drink it to see every trap that's hidden on the board right now.",
	},
	{
		id = "telepathy_potion",
		name = "Telepathy Potion",
		nick = "Telepathy", -- on cards too small for the whole name
		category = "potion",
		use = "telepathy",
		price = 3,
		short = "Move anyone 1-3",
		text = "Move any player 1 to 3 tiles forward or back. Push someone onto your trap!",
	},
	{
		id = "time_potion",
		name = "Time Travel Potion",
		nick = "Time", -- on cards too small for the whole name
		category = "potion",
		use = "anchor",
		price = 4,
		short = "Anchor & recall",
		text = "Drop a time anchor where you stand. On any later turn you can warp back to it instead of moving, even after you've banked a treasure.",
	},
	{
		id = "jeopardy_potion",
		name = "Double Jeopardy",
		nick = "Jeopardy", -- on cards too small for the whole name
		category = "potion",
		use = "jeopardy",
		price = 5,
		short = "Swap hands, 6 & 6",
		text = "Swap hands with a player, push them back 6 tiles and jump forward 6 yourself.",
	},

	-- Not a card: coins are tracked separately ------------------------------------
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
	def.hidden = def.hidden == true
	Items.byId[def.id] = def
	table.insert(Items.list, def)
end

-- The three spinners. "bkb" is replaced by the map's counter card (Bridge/Key/Boots).
Items.wheels = {
	trap = { "spike", "grog", "fire", "ice", "snare", "mudslide", "banana", "wall", "coin" },
	assist = { "speed_boost", "bounce_pad", "moonwalk", "clover", "juice", "shield", "bkb", "coin" },
	neutral = { "teleporter", "spore_warper", "conveyor", "trampoline", "coin" },
}

Items.potions = { "speed_potion", "phoenix_potion", "xray_potion", "telepathy_potion", "time_potion", "jeopardy_potion" }

Items.trapIds = { "spike", "grog", "fire", "ice", "snare", "mudslide", "banana", "wall" }

-- Natural hazard kind -> the card that counters it
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

-- Is this card hidden from opponents once it's on the board?
function Items.isHidden(id: string): boolean
	local def = Items.byId[id]
	return def ~= nil and def.hidden
end

return Items
