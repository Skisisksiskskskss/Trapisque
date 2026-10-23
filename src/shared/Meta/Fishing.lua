--[[
	Fishing
	Something to do while the others take their turns: cast a line off the board, watch
	the bobber, and reel in when it really bites. Each map has its own waters: a few
	fish live only there, a few turn up anywhere. Most catches go in your fish log (a
	collection to fill, with your biggest of each); now and then it's a gold coin for
	this match (one per round at most), or an old boot. The server rolls every catch
	(Match:fish); the client shows the rod.

	A cast: the fish is chosen when the line goes in, and its shadow (small, medium or
	large) shows under the bobber. It nibbles a time or two (pull then and it swims off),
	then bites. The rarer it is, the less time you have to reel.

		Fishing.roll(map, r1, r2, coinOk) -> catch id    (r1, r2 in [0, 1))
		Fishing.sizeOf(id, r) -> centimetres             (r in [0, 1); 0 for coins)
		Fishing.window(id) -> seconds to reel once it bites
		Fishing.shadow(id) -> "small" | "medium" | "large"
		Fishing.livesIn(id, map) -> boolean
]]

local Fishing = {}

Fishing.BiteMin = 3 -- seconds after a cast before the real bite
Fishing.BiteMax = 7
Fishing.Nibbles = { 1, 2 } -- fake bites before the real one (at least, at most)
Fishing.Grace = 0.35 -- for the trip to the server and back

-- how long you have to reel once it bites, and the shadow it throws, by rarity
local WINDOW = { common = 1.3, uncommon = 1.1, rare = 0.9, legendary = 0.75, junk = 1.3, coin = 1.3 }
local SHADOW = { common = "small", uncommon = "medium", rare = "large", legendary = "large", junk = "small", coin = "small" }

--[[
	rarity: common | uncommon | rare | legendary (go in the log), junk (logged too, for a
	laugh), coin (+1 coin in the match, not logged). weight: how often it bites where it
	lives. where: "any", or the maps it lives in. size: its range in centimetres.
	look: { body, fin, kind } for the client's drawing.
]]
Fishing.catches = {
	-- anywhere
	{ id = "sardine", name = "Sardine", rarity = "common", weight = 22, where = "any", size = { 12, 22 }, look = { body = "#9FB8C9", fin = "#6E8BA3", kind = "slim" } },
	{ id = "golden", name = "Golden Fish", rarity = "legendary", weight = 1, where = "any", size = { 20, 45 }, look = { body = "#E7B023", fin = "#FFE7A3", kind = "round" } },
	{ id = "boot", name = "Old Boot", rarity = "junk", weight = 7, where = "any", size = { 24, 32 }, look = { body = "#7A4A1F", fin = "#3A2A1E", kind = "boot" } },
	{ id = "coin", name = "Gold Coin", rarity = "coin", weight = 9, where = "any", look = { body = "#E7B023", fin = "#B88A12", kind = "coin" } },
	-- Blissful Tricks: a tropical island
	{ id = "snapper", name = "Red Snapper", rarity = "common", weight = 16, where = { "blissful" }, size = { 30, 70 }, look = { body = "#D64545", fin = "#A83434", kind = "round" } },
	{ id = "clownfish", name = "Clownfish", rarity = "uncommon", weight = 9, where = { "blissful" }, size = { 6, 11 }, look = { body = "#EE8A2E", fin = "#FFF9EF", kind = "round" } },
	{ id = "puffer", name = "Pufferfish", rarity = "uncommon", weight = 7, where = { "blissful" }, size = { 10, 40 }, look = { body = "#E7B023", fin = "#B88A12", kind = "puffer" } },
	{ id = "swordfish", name = "Swordfish", rarity = "rare", weight = 4, where = { "blissful" }, size = { 120, 300 }, look = { body = "#2F4C6E", fin = "#22384F", kind = "sword" } },
	-- Junction Dungeon: a rocky sea fortress
	{ id = "mackerel", name = "Mackerel", rarity = "common", weight = 16, where = { "junction" }, size = { 25, 45 }, look = { body = "#4F86A8", fin = "#2F4C6E", kind = "slim" } },
	{ id = "squid", name = "Squid", rarity = "uncommon", weight = 9, where = { "junction" }, size = { 20, 60 }, look = { body = "#D35A9C", fin = "#A43F77", kind = "squid" } },
	{ id = "eel", name = "Moray Eel", rarity = "rare", weight = 4, where = { "junction" }, size = { 60, 150 }, look = { body = "#5E7A3A", fin = "#3F5426", kind = "eel" } },
	-- Slimy Snares: a swamp
	{ id = "catfish", name = "Catfish", rarity = "common", weight = 16, where = { "slimy" }, size = { 30, 90 }, look = { body = "#7D6B52", fin = "#5A4C3A", kind = "cat" } },
	{ id = "piranha", name = "Piranha", rarity = "uncommon", weight = 9, where = { "slimy" }, size = { 15, 35 }, look = { body = "#8E9AA6", fin = "#D64545", kind = "round" } },
	{ id = "gar", name = "Alligator Gar", rarity = "rare", weight = 4, where = { "slimy" }, size = { 100, 250 }, look = { body = "#6E7F4E", fin = "#4C5A34", kind = "sword" } },
	-- Haunted Hollow: a graveyard by the sea
	{ id = "bonefish", name = "Bonefish", rarity = "common", weight = 16, where = { "haunted" }, size = { 30, 75 }, look = { body = "#D8D4C8", fin = "#A9A396", kind = "slim" } },
	{ id = "angler", name = "Anglerfish", rarity = "uncommon", weight = 9, where = { "haunted" }, size = { 20, 60 }, look = { body = "#3B3A48", fin = "#E7B023", kind = "angler" } },
	{ id = "ghostfish", name = "Ghost Fish", rarity = "rare", weight = 4, where = { "haunted" }, size = { 10, 30 }, look = { body = "#E9EEF0", fin = "#B9C6CC", kind = "round" } },
	-- Mount Kaboom: a volcano
	{ id = "tilapia", name = "Tilapia", rarity = "common", weight = 16, where = { "volcano" }, size = { 20, 45 }, look = { body = "#9AA38C", fin = "#6F7864", kind = "round" } },
	{ id = "crab", name = "Obsidian Crab", rarity = "uncommon", weight = 9, where = { "volcano" }, size = { 10, 25 }, look = { body = "#3A3440", fin = "#F2541B", kind = "crab" } },
	{ id = "ember", name = "Ember Eel", rarity = "rare", weight = 4, where = { "volcano" }, size = { 50, 120 }, look = { body = "#F2541B", fin = "#B83A12", kind = "eel" } },
	-- Frostbite Floes: a frozen sea
	{ id = "cod", name = "Arctic Cod", rarity = "common", weight = 16, where = { "frostbite" }, size = { 30, 80 }, look = { body = "#9FB4C2", fin = "#6F8797", kind = "slim" } },
	{ id = "snowcrab", name = "Snow Crab", rarity = "uncommon", weight = 9, where = { "frostbite" }, size = { 10, 25 }, look = { body = "#E07A4F", fin = "#FFF9EF", kind = "crab" } },
	{ id = "narwhal", name = "Narwhal", rarity = "rare", weight = 4, where = { "frostbite" }, size = { 300, 500 }, look = { body = "#B9C6CC", fin = "#7E8794", kind = "sword" } },
	-- Kraken's Reach: the deep round a whirlpool
	{ id = "lanternfish", name = "Lanternfish", rarity = "common", weight = 16, where = { "kraken" }, size = { 3, 15 }, look = { body = "#2F4C6E", fin = "#F4CF6B", kind = "round" } },
	{ id = "octopus", name = "Octopus", rarity = "uncommon", weight = 9, where = { "kraken" }, size = { 30, 90 }, look = { body = "#B5485E", fin = "#F6D2D2", kind = "squid" } },
	{ id = "oarfish", name = "Oarfish", rarity = "rare", weight = 4, where = { "kraken" }, size = { 300, 800 }, look = { body = "#C9D3DA", fin = "#D64545", kind = "eel" } },
	-- Clockwork Cove: a tinkerer's harbour
	{ id = "bass", name = "Harbour Bass", rarity = "common", weight = 16, where = { "clockwork" }, size = { 25, 60 }, look = { body = "#6E8B6A", fin = "#4C6A49", kind = "round" } },
	{ id = "brasscrab", name = "Brass Crab", rarity = "uncommon", weight = 9, where = { "clockwork" }, size = { 10, 30 }, look = { body = "#E7B023", fin = "#B88A12", kind = "crab" } },
	{ id = "tinfish", name = "Clockwork Fish", rarity = "rare", weight = 4, where = { "clockwork" }, size = { 15, 40 }, look = { body = "#B8BDC7", fin = "#E7B023", kind = "round" } },
}

Fishing.byId = {}
for i, c in Fishing.catches do
	c.order = i
	Fishing.byId[c.id] = c
end

-- The fish log: every catch except coins (the map fish first, by map, then the rest).
Fishing.logged = {}
for _, c in Fishing.catches do
	if c.rarity ~= "coin" then
		table.insert(Fishing.logged, c)
	end
end

function Fishing.livesIn(id: string, map: string?): boolean
	local c = Fishing.byId[id]
	if not c then
		return false
	end
	if c.where == "any" then
		return true
	end
	return map ~= nil and table.find(c.where, map) ~= nil
end

local function pick(r: number, list): string
	local total = 0
	for _, c in list do
		total += c.weight
	end
	local roll = r * total
	for _, c in list do
		roll -= c.weight
		if roll < 0 then
			return c.id
		end
	end
	return list[#list].id
end

-- What's on the hook in `map`'s waters. `coinOk` false: a coin was already landed this
-- round, so roll again among the rest.
function Fishing.roll(map: string?, r1: number, r2: number, coinOk: boolean): string
	local here, noCoin = {}, {}
	for _, c in Fishing.catches do
		if c.where == "any" or (map ~= nil and table.find(c.where, map) ~= nil) then
			table.insert(here, c)
			if c.rarity ~= "coin" then
				table.insert(noCoin, c)
			end
		end
	end
	local id = pick(r1, here)
	if id == "coin" and not coinOk then
		id = pick(r2, noCoin)
	end
	return id
end

-- How big this one is: most are on the small side, a few are whoppers.
function Fishing.sizeOf(id: string, r: number): number
	local c = Fishing.byId[id]
	if not c or not c.size then
		return 0
	end
	local lo, hi = c.size[1], c.size[2]
	return math.floor(lo + (hi - lo) * r * r + 0.5)
end

function Fishing.window(id: string): number
	local c = Fishing.byId[id]
	return WINDOW[c and c.rarity or "common"] or WINDOW.common
end

function Fishing.shadow(id: string): string
	local c = Fishing.byId[id]
	return SHADOW[c and c.rarity or "common"] or "small"
end

-- "54 cm", "1.2 m"
function Fishing.sizeText(cm: number): string
	if cm >= 100 then
		return string.format("%.1f m", cm / 100)
	end
	return tostring(cm) .. " cm"
end

return Fishing
