--[[
	Badges
	Goals that are moments, not grinds: getting sent home three times in one match,
	bonking two rivals with one move, rolling snake eyes, being scared by three ghosts,
	fishing up the Golden Fish. Earned badges show on the lobby's BADGES page (and on
	Roblox, once Config.Badges has their ids). The server decides (BadgeService).

	icon: the badge's art (client BadgeArt, also rendered to docs/store/badges for
	the Creator Dashboard). color: its rim.
]]

local Badges = {}

Badges.list = {
	{ key = "first_voyage", name = "Learned the Ropes", text = "Finish the guided first match.", icon = "compass", color = "#1E7FD6" },
	{ key = "walk_the_plank", name = "Walk the Plank", text = "Get sent back to the Start 3 times in one match.", icon = "plank", color = "#9C6B3A" },
	{ key = "bowling", name = "Bowling Ball", text = "Bonk two rivals with one move.", icon = "pins", color = "#F5B700" },
	{ key = "hat_trick", name = "Gotcha Hat Trick", text = "Catch rivals with your hidden traps 3 times in one match.", icon = "trap", color = "#D7263D" },
	{ key = "comeback", name = "Rags to Riches", text = "Win a match after rolling the underdog's gold die.", icon = "golddie", color = "#F5B700" },
	{ key = "snake_eyes", name = "Snake Eyes", text = "Roll double 1s.", icon = "snake", color = "#43A047" },
	{ key = "boxcars", name = "Boxcars", text = "Roll double 6s.", icon = "sixes", color = "#F08A24" },
	{ key = "untouchable", name = "Untouchable", text = "Win a match without anyone bonking you.", icon = "shield", color = "#2A9D8F" },
	{ key = "boo_who", name = "Boo Who?", text = "Get scared by a ghost 3 times in one match on Haunted Hollow.", icon = "ghost", color = "#C9D3E0" },
	{ key = "hot_feet", name = "Hot Feet", text = "Get scorched when Mount Kaboom erupts.", icon = "volcano", color = "#F2541B" },
	{ key = "phoenix", name = "Back from the Ashes", text = "Survive a knockout with a Phoenix Potion.", icon = "phoenix", color = "#F08A24" },
	{ key = "grog_dodger", name = "Grog Dodger", text = "Outrun a hungry Grog.", icon = "grog", color = "#5DB54A" },
	{ key = "jackpot", name = "Jackpot", text = "As the Gambler, reach the treasure on a Double Down.", icon = "jackpot", color = "#13A398" },
	{ key = "human_cannonball", name = "Human Cannonball", text = "As the Cannoneer, bonk a rival with a Cannonball.", icon = "cannonball", color = "#8B5A2B" },
	{ key = "golden_fish", name = "Gone Fishin'", text = "Fish up the Golden Fish between turns.", icon = "fish", color = "#F5B700" },
	{ key = "captains_table", name = "Captain's Table", text = "Play a match with the game's crew (its owner or an admin).", icon = "crown", color = "#2B4C7E" },
	{ key = "full_crew", name = "Full Crew", text = "Play a match with a party of 6.", icon = "people", color = "#D94C9C" },
	{ key = "hoarder", name = "Treasure Hoarder", text = "Bank 100 treasures in all.", icon = "chest", color = "#F5B700" },
	{ key = "meet_the_crew", name = "Meet the Crew", text = "Play a match as every character.", icon = "crew", color = "#1E7FD6" },
	{ key = "master", name = "Master of One", text = "Reach mastery 10 with a character.", icon = "star", color = "#F5B700" },
}

Badges.byKey = {}
for i, b in Badges.list do
	b.order = i
	Badges.byKey[b.key] = b
end

return Badges
