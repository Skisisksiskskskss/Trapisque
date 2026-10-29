--[[
	HouseRules
	What a private match's host can change, as plain data (the party leader picks them in
	the lobby; the server checks them with HouseRules.clean; the engine reads them):

		board     "full" | "short": the whole trail, or about the first two thirds of it
		          (Maps.variant)
		timer     seconds per turn (0: no timer)
		power     Power everyone starts with: "empty" | "half" | "full"
		cards     cards everyone starts with (1 to 3)
		abilities false: nobody can use their ability (the Power bar goes)
		wanted    false: no price on the leader's head (Engine "Wanted")
		underdog  false: no gold die for whoever is clearly last
		twist     a twist on the rules ("none" or a twist id, Meta/Progress events)
		banned    [card id] = true: those cards never come up (wheels, shop, starting hands)
		vote      how the map is chosen when the match opens: "off" (the map picked in the
		          settings), "majority" (most votes wins) or "roulette" (every vote is a
		          slice of a wheel, which spins)
		mystery   the vote has a face-down map among its choices
		wildcard  the vote has a map with a random twist among its choices

	Quick Play always plays the standard rules (HouseRules.defaults) with a majority vote
	that has a Mystery map in it.
]]

local Items = require(script.Parent.Items)

local HouseRules = {}

HouseRules.defaults = {
	board = "full",
	timer = 45,
	power = "empty",
	cards = 1,
	abilities = true,
	wanted = true,
	underdog = true,
	twist = "none",
	banned = {},
	vote = "off",
	mystery = true,
	wildcard = false,
}

HouseRules.options = {
	board = { "full", "short" },
	timer = { 0, 30, 45, 60, 90 },
	power = { "empty", "half", "full" },
	cards = { 1, 2, 3 },
	vote = { "off", "majority", "roulette" },
	twist = { "none", "trap_frenzy", "bonk_bonanza", "power_surge", "triple_dice" },
}

-- Cards a host may ban: the ones the wheels and the Potion Seller hand out (a map's
-- counter card, which gets you past its hazard, always stays).
HouseRules.bannable = {}
do
	local seen = {}
	for _, wheel in { "trap", "assist", "neutral" } do
		for _, id in Items.wheels[wheel] do
			if id ~= "coin" and id ~= "bkb" and not seen[id] then
				seen[id] = true
				table.insert(HouseRules.bannable, id)
			end
		end
	end
	for _, id in Items.potions do
		if not seen[id] then
			seen[id] = true
			table.insert(HouseRules.bannable, id)
		end
	end
end
local BANNABLE = {}
for _, id in HouseRules.bannable do
	BANNABLE[id] = true
end
HouseRules.MaxBans = 10
-- (at least this many traps that can be hidden must stay, for the Trapper's sake)
HouseRules.MinTraps = 2

local function pick(list, value, fallback)
	if table.find(list, value) then
		return value
	end
	return fallback
end

-- A safe, complete copy of `raw` (anything missing or wrong is the default).
function HouseRules.clean(raw: any)
	local d = HouseRules.defaults
	local r = if type(raw) == "table" then raw else {}
	local out = {
		board = pick(HouseRules.options.board, r.board, d.board),
		timer = pick(HouseRules.options.timer, tonumber(r.timer), d.timer),
		power = pick(HouseRules.options.power, r.power, d.power),
		cards = pick(HouseRules.options.cards, tonumber(r.cards), d.cards),
		abilities = if type(r.abilities) == "boolean" then r.abilities else d.abilities,
		wanted = if type(r.wanted) == "boolean" then r.wanted else d.wanted,
		underdog = if type(r.underdog) == "boolean" then r.underdog else d.underdog,
		twist = pick(HouseRules.options.twist, r.twist, d.twist),
		banned = {},
		vote = pick(HouseRules.options.vote, r.vote, d.vote),
		mystery = if type(r.mystery) == "boolean" then r.mystery else d.mystery,
		wildcard = if type(r.wildcard) == "boolean" then r.wildcard else d.wildcard,
	}
	if type(r.banned) == "table" then
		local want = {}
		for _, id in HouseRules.bannable do
			if r.banned[id] == true then
				want[id] = true
			end
		end
		-- keep enough traps in the game
		local left = 0
		for _, id in Items.trapIds do
			if id ~= "wall" and not want[id] then
				left += 1
			end
		end
		for _, id in Items.trapIds do
			if left >= HouseRules.MinTraps then
				break
			end
			if id ~= "wall" and want[id] then
				want[id] = nil
				left += 1
			end
		end
		local n = 0
		for _, id in HouseRules.bannable do
			if want[id] and n < HouseRules.MaxBans then
				out.banned[id] = true
				n += 1
			end
		end
	end
	return out
end

function HouseRules.isBannable(id: string): boolean
	return BANNABLE[id] == true
end

-- How many cards are banned.
function HouseRules.banCount(rules): number
	local n = 0
	for _ in rules.banned or {} do
		n += 1
	end
	return n
end

-- Do these rules change anything about how a match plays (the vote aside)?
function HouseRules.changesPlay(rules): boolean
	local d = HouseRules.defaults
	return rules.board ~= d.board
		or rules.power ~= d.power
		or rules.cards ~= d.cards
		or rules.abilities ~= d.abilities
		or rules.wanted ~= d.wanted
		or rules.underdog ~= d.underdog
		or rules.twist ~= d.twist
		or HouseRules.banCount(rules) > 0
end

-- The rule changes in a few words each, for the lobby and the match ("Short board",
-- "Abilities off", "3 cards banned"...).
function HouseRules.describe(rules): { string }
	local out = {}
	if rules.board == "short" then
		table.insert(out, "Short board")
	end
	if rules.power == "half" then
		table.insert(out, "Half Power to start")
	elseif rules.power == "full" then
		table.insert(out, "Full Power to start")
	end
	if rules.cards ~= HouseRules.defaults.cards then
		table.insert(out, rules.cards .. " starting cards")
	end
	if not rules.abilities then
		table.insert(out, "Abilities off")
	end
	if not rules.wanted then
		table.insert(out, "No Wanted posters")
	end
	if not rules.underdog then
		table.insert(out, "No underdog die")
	end
	local bans = HouseRules.banCount(rules)
	if bans > 0 then
		table.insert(out, bans .. (if bans == 1 then " card" else " cards") .. " banned")
	end
	if rules.timer == 0 then
		table.insert(out, "No turn timer")
	elseif rules.timer ~= HouseRules.defaults.timer then
		table.insert(out, rules.timer .. "s turns")
	end
	return out
end

return HouseRules
