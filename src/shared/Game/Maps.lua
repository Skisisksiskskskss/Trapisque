--[[
	Maps
	The three Trapisque boards, written as walks on a hex grid (see Board.lua).

	route     main path from Start; the last tile is the Treasure
	branches  gated shortcuts: leave the main route at `from`, rejoin at `to`.
	          Only players holding a Key (or the Naturalist) take them.
	natural   permanent natural traps, by main-route tile number
	tokenEvery a random token is placed every N tiles (rulebook: 3 / 5 / 6)
]]

local Maps = {}

local defs = {
	{
		id = "blissful",
		name = "Blissful Tricks",
		theme = "water",
		blurb = "A floating path across a sparkling lake. Rivers stop you in your tracks unless you carry a Bridge.",
		start = { 0, 0 },
		route = "E3 NE E2 SE E2 NE2 NW W3 NW W3 SW W2 NW2 NE E4 NE E2 SE E2",
		natural = { [9] = "river", [19] = "river", [30] = "river" },
		tokenEvery = 3,
		naturalKind = "river",
		counterItem = "bridge",
		naturalCard = "river_trap",
	},
	{
		id = "junction",
		name = "Junction Dungeon",
		theme = "dungeon",
		blurb = "Torch-lit corridors full of junctions. A Key opens gated shortcuts and locked gates.",
		start = { 0, 0 },
		route = "E10 NE NW NE NW W10 NW NE E10 NE NW W8",
		branches = {
			{ from = 6, steps = "NW NE NW NW", to = 21 },
			{ from = 22, steps = "NW NE", to = 30 },
		},
		natural = { [13] = "gate", [37] = "gate" },
		-- (rulebook) "Spike traps": the dungeon starts with two spikes already set
		startingPlaced = { [18] = "spike", [33] = "spike" },
		tokenEvery = 5,
		naturalKind = "gate",
		counterItem = "key",
		naturalCard = "gate_trap",
	},
	{
		id = "slimy",
		name = "Slimy Snares",
		theme = "swamp",
		blurb = "A bubbling swamp that spirals in to the treasure. Slime halves your moves unless you wear Boots.",
		start = { 0, 0 },
		route = "E10 NE NW NE NW NE NW W10 SW SE SW SE E7 NE NW W4",
		natural = { [8] = "slime", [19] = "slime", [34] = "slime" },
		-- (digital) the rulebook says every 6 tiles; 5 keeps the smaller swamp lively
		tokenEvery = 5,
		naturalKind = "slime",
		counterItem = "boots",
		naturalCard = "slime_trap",
	},
}

Maps.byId = {}
Maps.list = {}
for i, def in defs do
	def.order = i
	Maps.byId[def.id] = def
	table.insert(Maps.list, def)
end

function Maps.get(id: string)
	return Maps.byId[id]
end

return Maps
