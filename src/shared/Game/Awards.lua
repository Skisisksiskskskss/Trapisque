--[[
	Awards
	When a match ends, everyone gets an award for how they played, winners and losers
	alike (it pays a few Gems: Config.Rewards.AwardGems):

		Awards.pick(players) -> { [seat] = { id, name, icon, text } }

	players are the engine's (index, treasures, stats). Each award in Awards.list goes to
	whoever did the most of something, if they did enough of it (a tie: everyone tied gets
	it). Nobody gets two: the list is in order of how much an award says about your
	match. Whoever tops nothing gets one of the awards everyone can get.
]]

local Awards = {}

-- value(stats) -> a number to be the most of (nil: doesn't count), at least `min`
Awards.list = {
	{
		id = "bounty_hunter",
		name = "Bounty Hunter",
		icon = "wanted",
		min = 1,
		value = function(st)
			return st.bounties
		end,
		text = function(n)
			return if n == 1 then "Claimed a Wanted poster" else ("Claimed " .. n .. " Wanted posters")
		end,
	},
	{
		id = "trap_master",
		name = "Trap Master",
		icon = "token_trap",
		min = 2,
		value = function(st)
			return st.gotchas
		end,
		text = function(n)
			return n .. " rivals caught in hidden traps"
		end,
	},
	{
		id = "bonk_champ",
		name = "Bonk Champ",
		icon = "star",
		min = 2,
		value = function(st)
			return st.bonks
		end,
		text = function(n)
			return n .. " bonks landed"
		end,
	},
	{
		id = "most_wanted",
		name = "Most Wanted",
		icon = "wanted",
		min = 2,
		value = function(st)
			return st.wantedRounds
		end,
		text = function(n)
			return n .. " rounds with a price on their head"
		end,
	},
	{
		id = "punching_bag",
		name = "Punching Bag",
		icon = "star",
		min = 3,
		value = function(st)
			return st.bonked
		end,
		text = function(n)
			return "Bonked " .. n .. " times"
		end,
	},
	{
		id = "walk_the_plank",
		name = "Walked the Plank",
		icon = "skull",
		min = 2,
		value = function(st)
			return st.deaths
		end,
		text = function(n)
			return "Sent back to the Start " .. n .. " times"
		end,
	},
	{
		id = "unlucky",
		name = "Unluckiest Roller",
		icon = "dice",
		-- the lowest average roll (of a fair few), as the most of its opposite
		min = -3.1,
		value = function(st)
			if (st.rolls or 0) < 8 then
				return nil
			end
			return -st.rolled / st.rolls
		end,
		text = function(n)
			return string.format("Rolled %.1f on average", -n)
		end,
	},
	{
		id = "card_shark",
		name = "Card Shark",
		icon = "book",
		min = 4,
		value = function(st)
			return st.played
		end,
		text = function(n)
			return n .. " cards played"
		end,
	},
	{
		id = "ability_addict",
		name = "Power Hungry",
		icon = "bolt",
		min = 3,
		value = function(st)
			return st.abilities
		end,
		text = function(n)
			return "Used their ability " .. n .. " times"
		end,
	},
	{
		id = "big_spender",
		name = "Big Spender",
		icon = "coin",
		min = 2,
		value = function(st)
			return st.bought
		end,
		text = function(n)
			return n .. " potions bought"
		end,
	},
	{
		id = "double_trouble",
		name = "Double Trouble",
		icon = "dice",
		min = 3,
		value = function(st)
			return st.doubles
		end,
		text = function(n)
			return n .. " doubles rolled"
		end,
	},
	{
		id = "comeback",
		name = "Comeback Kid",
		icon = "dice",
		min = 3,
		value = function(st)
			return st.underdog
		end,
		text = function(n)
			return n .. " turns with the underdog's gold die"
		end,
	},
	{
		id = "speedrunner",
		name = "Speedrunner",
		icon = "boots",
		min = 1,
		value = function(st)
			return st.tiles
		end,
		text = function(n)
			return n .. " tiles walked"
		end,
	},
}

-- The awards anyone can get (the first that fits).
Awards.everyone = {
	{
		id = "pacifist",
		name = "Pacifist",
		icon = "heart",
		fits = function(p)
			local st = p.stats
			return (st.bonks or 0) == 0 and (st.gotchas or 0) == 0
		end,
		text = "Never bonked or trapped a soul",
	},
	{
		id = "sightseer",
		name = "Sightseer",
		icon = "map",
		fits = function(p)
			return (p.treasures or 0) == 0
		end,
		text = "Took the scenic route",
	},
	{
		id = "good_sport",
		name = "Good Sport",
		icon = "crown",
		fits = function()
			return true
		end,
		text = "Played it to the end",
	},
}

Awards.byId = {}
for _, a in Awards.list do
	Awards.byId[a.id] = a
end
for _, a in Awards.everyone do
	Awards.byId[a.id] = a
end

function Awards.pick(players): { [number]: { id: string, name: string, icon: string, text: string } }
	local out = {}
	for _, a in Awards.list do
		local best, top = -math.huge, {}
		for _, p in players do
			local v = a.value(p.stats or {})
			if type(v) == "number" and v >= a.min then
				if v > best then
					best, top = v, { p }
				elseif v == best then
					table.insert(top, p)
				end
			end
		end
		for _, p in top do
			if not out[p.index] then
				out[p.index] = { id = a.id, name = a.name, icon = a.icon, text = a.text(best) }
			end
		end
	end
	for _, p in players do
		if not out[p.index] then
			for _, a in Awards.everyone do
				if a.fits(p) then
					out[p.index] = { id = a.id, name = a.name, icon = a.icon, text = a.text }
					break
				end
			end
		end
	end
	return out
end

return Awards
