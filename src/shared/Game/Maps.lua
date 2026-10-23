--[[
	Maps
	The Trapisque boards, written as walks on a hex grid (see Board.lua): that gives the
	board graph the rules use. How each map looks (the winding route through an island,
	a fortress, a swamp, a haunted graveyard, a volcano) is the client's MapScenes.

	route     main path from Start; the last tile is the Treasure
	branches  gated shortcuts: leave the main route at `from`, rejoin at `to`.
	          Only players holding a Key (or the Naturalist) take them.
	natural   permanent natural traps, by main-route tile number
	tokenEvery a random token is placed every N tiles (rulebook: 3 / 5 / 6)
	ghosts    (Haunted Hollow) the tiles its ghosts start on; they drift toward the Start
	          every round and scare back whoever walks into them
	          (Mount Kaboom's natural "lava" streams stop you like rivers, and the volcano
	          scorches whoever stands in one when it erupts)
	counterItem the card that gets you past the map's hazard (the Assist wheel's map slot)
]]

local Maps = {}

local defs = {
	{
		id = "blissful",
		name = "Blissful Tricks",
		theme = "water",
		blurb = "A sunny island cut by two rivers. Rivers stop you in your tracks unless you carry a Bridge.",
		start = { 0, 0 },
		route = "E3 NE E2 SE E2 NE2 NW W3 NW W3 SW W2 NW2 NE E4 NE E2 SE E2",
		natural = { [12] = "river", [26] = "river" },
		tokenEvery = 3,
		naturalKind = "river",
		counterItem = "bridge",
	},
	{
		id = "junction",
		name = "Junction Dungeon",
		theme = "dungeon",
		blurb = "A rocky sea fortress full of locked gates and secret tunnels. Gates stop you; a Key opens them and the tunnels.",
		start = { 0, 0 },
		route = "E10 NE NW NE NW W10 NW NE E10 NE NW W8",
		branches = {
			{ from = 6, steps = "NW NE NW NW", to = 21 },
			{ from = 22, steps = "NW NE", to = 30 },
		},
		natural = { [13] = "gate", [25] = "gate", [37] = "gate" },
		tokenEvery = 5,
		naturalKind = "gate",
		counterItem = "key",
	},
	{
		id = "slimy",
		name = "Slimy Snares",
		theme = "swamp",
		blurb = "A swamp boardwalk that spirals in to the treasure. Slime pools eat 5 of your steps (you're stuck in one if that's all you had) unless you wear Boots.",
		start = { 0, 0 },
		route = "E10 NE NW NE NW NE NW W10 SW SE SW SE E7 NE NW W4",
		natural = { [8] = "slime", [19] = "slime", [34] = "slime" },
		-- (digital) the rulebook says every 6 tiles; 5 keeps the smaller swamp lively
		tokenEvery = 5,
		naturalKind = "slime",
		counterItem = "boots",
	},
	{
		id = "haunted",
		name = "Haunted Hollow",
		theme = "haunted",
		blurb = "A graveyard cove under a full moon. Two ghosts drift down the trail every round: walk into one and you stop dead and jump back a tile in fright, unless you carry a Lantern.",
		start = { 0, 0 },
		route = "E10 NE NW W10 NW NE E10 NE NW W3",
		ghosts = { 14, 32 },
		tokenEvery = 4,
		naturalKind = "ghost",
		counterItem = "lantern",
	},
	{
		id = "volcano",
		name = "Mount Kaboom",
		theme = "volcano",
		blurb = "A volcano island crossed by two lava streams. A stream stops you in your tracks unless you wear a Fire Cloak, and every 3 rounds the volcano blows: anyone standing in a stream gets scorched.",
		start = { 0, 0 },
		route = "E8 NE E2 NE NW W10 NW NE E10 NE NW W4",
		natural = { [14] = "lava", [29] = "lava" },
		tokenEvery = 4,
		naturalKind = "lava",
		counterItem = "cloak",
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

-- How much of the trail a short board keeps (house rules: HouseRules.ShortShare).
Maps.ShortShare = 0.65

--[[
	A map's board as a match plays it: `board` "short" is the same place with only the
	first part of its trail (Maps.ShortShare of it, from the Start); the treasure sits
	where the cut falls, and the hazards and shortcuts past it are left out (Board).
]]
local variants = {}
function Maps.variant(def, board: string?)
	if board ~= "short" or def == nil then
		return def
	end
	local v = variants[def.id]
	if not v then
		v = table.clone(def)
		v.variant = "short"
		v.cutShare = Maps.ShortShare
		variants[def.id] = v
	end
	return v
end

return Maps
