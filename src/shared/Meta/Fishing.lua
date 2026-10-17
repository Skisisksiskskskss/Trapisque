--[[
	Fishing
	Something to do while the others take their turns: cast a line off the board, wait
	for a bite and reel it in quickly. Most catches go in your fish log (a collection
	to fill); now and then it's a gold coin for this match (one per round at most), or
	an old boot. The server rolls every catch (Match:fish); the client shows the rod.

		Fishing.roll(r1, r2, coinOk) -> catch id    (r1, r2 in [0, 1))
]]

local Fishing = {}

Fishing.BiteMin = 2.5 -- seconds after a cast before a bite
Fishing.BiteMax = 6
Fishing.Window = 1.2 -- seconds to reel once it bites
Fishing.Grace = 0.35 -- for the trip to the server and back

--[[
	rarity: common | uncommon | rare | legendary (go in the log), junk (logged too, for a
	laugh), coin (+1 coin in the match, not logged). weight: how often it bites.
	look: { body, fin, belly, kind } for the client's drawing.
]]
Fishing.catches = {
	{ id = "sardine", name = "Sardine", rarity = "common", weight = 26, look = { body = "#9FB8C9", fin = "#6E8BA3", kind = "slim" } },
	{ id = "mackerel", name = "Mackerel", rarity = "common", weight = 20, look = { body = "#4F86A8", fin = "#2B4C7E", kind = "slim" } },
	{ id = "snapper", name = "Red Snapper", rarity = "common", weight = 16, look = { body = "#D7263D", fin = "#9E1B2C", kind = "round" } },
	{ id = "clownfish", name = "Clownfish", rarity = "uncommon", weight = 10, look = { body = "#F08A24", fin = "#FFF8E7", kind = "round" } },
	{ id = "puffer", name = "Pufferfish", rarity = "uncommon", weight = 8, look = { body = "#F5B700", fin = "#C98F00", kind = "puffer" } },
	{ id = "squid", name = "Squid", rarity = "rare", weight = 5, look = { body = "#D94C9C", fin = "#A1336F", kind = "squid" } },
	{ id = "swordfish", name = "Swordfish", rarity = "rare", weight = 4, look = { body = "#2B4C7E", fin = "#1C3459", kind = "sword" } },
	{ id = "golden", name = "Golden Fish", rarity = "legendary", weight = 1, look = { body = "#F5B700", fin = "#FFE7A3", kind = "round" } },
	{ id = "boot", name = "Old Boot", rarity = "junk", weight = 7, look = { body = "#7A4A1F", fin = "#3A2A1E", kind = "boot" } },
	{ id = "coin", name = "Gold Coin", rarity = "coin", weight = 9, look = { body = "#F5B700", fin = "#C98F00", kind = "coin" } },
}

Fishing.byId = {}
for i, c in Fishing.catches do
	c.order = i
	Fishing.byId[c.id] = c
end

-- The fish log: every catch except coins.
Fishing.logged = {}
for _, c in Fishing.catches do
	if c.rarity ~= "coin" then
		table.insert(Fishing.logged, c)
	end
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

-- What's on the hook. `coinOk` false: a coin was already landed this round, so roll
-- again among the rest.
function Fishing.roll(r1: number, r2: number, coinOk: boolean): string
	local id = pick(r1, Fishing.catches)
	if id == "coin" and not coinOk then
		id = pick(r2, Fishing.logged)
	end
	return id
end

return Fishing
