--[[
	Characters
	The six Trapisque characters. You pick yours in the lobby (two players can pick the
	same one). Every character has:

		passive   always on, and worth about the same on every map
		ability   costs Power. Your Power bar is as long as your ability's cost: the die
		          you don't move with charges it, and when it's full the ability is ready.

	Every ability helps the one who uses it, not just hurts someone: in a free-for-all,
	hurting one rival helps your other rivals as much as it helps you.

	ability.target:
		other   any other player          any   any player, including yourself
		none    no target                 tile  a tile near you
	ability.range: how far away (in tiles) the target may be, if limited.
]]

local Config = require(script.Parent.Parent.Config)

local Characters = {}

local C = Config.Characters

local defs = {
	{
		id = "mage",
		name = "Mage",
		tagline = "Master of frost and flame",
		passiveName = "Frostproof",
		passive = "Can't be Frozen.",
		ability = {
			id = "blizzard",
			name = "Blizzard",
			text = "Freeze every rival for their next turn, and skate " .. C.mage.skate .. (if C.mage.skate == 1 then " tile" else " tiles") .. " ahead on the ice.",
			cost = C.mage.cost,
			target = "none",
		},
	},
	{
		id = "trapper",
		name = "Trapper",
		tagline = "Never leaves home without a trap",
		passiveName = "Bounty Hunter",
		passive = "Hides traps anywhere on the board and keeps up to " .. C.trapper.trapCap .. " out. Each time one catches someone, you hop " .. C.trapper.bounty .. (if C.trapper.bounty == 1 then " tile" else " tiles") .. " forward.",
		ability = {
			id = "scavenge",
			name = "Scavenge",
			text = "Pick one of two random trap cards.",
			cost = C.trapper.cost,
			target = "none",
		},
		startingCards = "trap",
	},
	{
		id = "fire_starter",
		name = "Fire Starter",
		tagline = "Leaves a trail of embers",
		passiveName = "Hot Hands",
		passive = "Your bonks set rivals on fire. Starts with a Fire card.",
		ability = {
			id = "blast",
			name = "Blast Off",
			text = "Rocket " .. C.fire_starter.blast .. " tiles forward. The tiles you fly over burn until your next turn.",
			cost = C.fire_starter.cost,
			target = "none",
		},
		startingCards = "fire",
	},
	{
		id = "naturalist",
		name = "Naturalist",
		tagline = "At home in the wild",
		passiveName = "Wild Walker",
		passive = "Rivers, locked gates and slime pools never stop or slow you.",
		ability = {
			id = "overgrow",
			name = "Overgrow",
			text = "Grow this map's hazard (river, gate or slime) on a tile up to " .. C.naturalist.range .. " tiles away. You can keep " .. C.naturalist.cap .. " out at once.",
			cost = C.naturalist.cost,
			target = "tile",
			range = C.naturalist.range,
		},
	},
	{
		id = "warper",
		name = "Warper",
		tagline = "Here one moment, there the next",
		passiveName = "Slippery",
		passive = "Can't be swapped by anyone else.",
		ability = {
			id = "warp",
			name = "Warp",
			text = "Swap places with a player up to " .. C.warper.range .. " tiles away.",
			cost = C.warper.cost,
			target = "other",
			range = C.warper.range,
		},
	},
	{
		id = "overseer",
		name = "Overseer",
		tagline = "Sees every move before it happens",
		passiveName = "All-Seeing",
		passive = "Sees every hidden trap.",
		ability = {
			id = "nudge",
			name = "Nudge",
			text = "Move any player (even yourself) " .. C.overseer.steps .. " tiles forward or back.",
			cost = C.overseer.cost,
			target = "any",
			options = { "fwd", "back" },
		},
	},
}

Characters.byId = {}
Characters.list = {}
Characters.ids = {}
for i, def in defs do
	def.order = i
	Characters.byId[def.id] = def
	table.insert(Characters.list, def)
	table.insert(Characters.ids, def.id)
end

function Characters.get(id: string)
	return Characters.byId[id]
end

-- How much Power this character's ability needs (the length of their Power bar).
function Characters.cost(id: string): number
	local def = Characters.byId[id]
	return if def and def.ability then def.ability.cost else 0
end

return Characters
