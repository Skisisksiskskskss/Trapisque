--[[
	Characters
	The eight Trapisque characters. You pick yours in the lobby; four are free and the
	rest unlock as your account levels up (Config.CharacterUnlocks). Every character has:

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
		passive = "Hazards never stop or slow you: rivers, locked gates, slime, ghosts and lava.",
		ability = {
			id = "stampede",
			name = "Stampede",
			text = "Charge " .. C.naturalist.charge .. " tiles forward with a herd of wild boars. Every rival in the way is knocked back " .. C.naturalist.trample .. " tiles.",
			cost = C.naturalist.cost,
			target = "none",
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
	{
		id = "gambler",
		name = "Gambler",
		tagline = "Bets it all on one more roll",
		passiveName = "Loaded Dice",
		passive = "Your dice never roll a 1.",
		ability = {
			id = "doubledown",
			name = "Double Down",
			text = "This turn your move counts double, and you leap right over rivers, gates, slime, ghosts and lava on the way.",
			cost = C.gambler.cost,
			target = "none",
		},
	},
	{
		id = "cannoneer",
		name = "Cannoneer",
		tagline = "Always arrives with a bang",
		passiveName = "Broadside",
		passive = "Your bonks knock rivals back " .. (Config.Rules.BonkBack + C.cannoneer.extraBack) .. " tiles instead of " .. Config.Rules.BonkBack .. ".",
		ability = {
			id = "cannonball",
			name = "Cannonball",
			text = "Fire yourself at the nearest rival up to " .. C.cannoneer.range .. " tiles ahead and bonk them. Nobody there? You still fly " .. C.cannoneer.fly .. " tiles.",
			cost = C.cannoneer.cost,
			target = "none",
		},
	},
}

Characters.byId = {}
Characters.list = {}
Characters.ids = {}
for i, def in defs do
	def.order = i
	def.unlockLevel = Config.CharacterUnlocks[def.id] -- nil: free from the start
	Characters.byId[def.id] = def
	table.insert(Characters.list, def)
	table.insert(Characters.ids, def.id)
end

function Characters.get(id: string)
	return Characters.byId[id]
end

-- Can a player of account `level` pick this character?
function Characters.unlocked(id: string, level: number): boolean
	local def = Characters.byId[id]
	return def ~= nil and (def.unlockLevel == nil or level >= def.unlockLevel)
end

-- How much Power this character's ability needs (the length of their Power bar).
function Characters.cost(id: string): number
	local def = Characters.byId[id]
	return if def and def.ability then def.ability.cost else 0
end

return Characters
