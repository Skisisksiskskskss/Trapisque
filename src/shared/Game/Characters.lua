--[[
	Characters
	The six Trapisque characters. Characters are dealt at random at the start of a match
	(rulebook: "Assign characters by drawing cards randomly"), one of each at most.

	ability.recharge:
		cycles    - recharges after the owner completes `amount` cycles (treasure laps)
		rounds    - recharges after `amount` full rounds of turns
		once      - one use per game; only a Regeneration card brings it back
		perTurn   - can be used once every turn, no recharge needed
	ability.target:
		other     - any other player
		any       - any player, including yourself
		sameTile  - another player standing on your tile
		none      - no target
]]

local Config = require(script.Parent.Parent.Config)

local Characters = {}

local R = Config.Rules

local defs = {
	{
		id = "mage",
		name = "Mage",
		tagline = "Master of frost and flame",
		passive = "Immune to Ice and freezing.",
		ability = {
			id = "hex",
			name = "Hex",
			text = "Freeze or Burn any player until their cycle ends.",
			recharge = "cycles",
			amount = R.AbilityRechargeCycles,
			target = "other",
			options = { "freeze", "burn" },
		},
	},
	{
		id = "trapper",
		name = "Trapper",
		tagline = "Never leaves home without a trap",
		passive = "Starts with " .. R.TrapperStartingTraps .. " random trap cards.",
		ability = {
			id = "scavenge",
			name = "Scavenge",
			text = "Spin the Trap wheel for a free card.",
			recharge = "cycles",
			amount = R.AbilityRechargeCycles,
			target = "none",
		},
		startingCards = "traps",
	},
	{
		id = "fire_starter",
		name = "Fire Starter",
		tagline = "Leaves a trail of embers",
		passive = "Starts with " .. R.FireStarterStartingFires .. " Fire cards.",
		ability = {
			id = "ignite",
			name = "Ignite",
			text = "Burn a player standing on your tile. Usable every turn.",
			recharge = "perTurn",
			target = "sameTile",
		},
		startingCards = "fires",
	},
	{
		id = "naturalist",
		name = "Naturalist",
		tagline = "At home in the wild",
		passive = "Walks through rivers, gates, slime and gated shortcuts. Gets natural trap cards instead of Bridge/Key/Boots. Takes double penalties from trap cards.",
		ability = nil,
	},
	{
		id = "warper",
		name = "Warper",
		tagline = "Here one moment, there the next",
		passive = "Immune to swaps.",
		ability = {
			id = "warp",
			name = "Warp",
			text = "Swap places with any player. Once per game (Regeneration restores it).",
			recharge = "once",
			target = "other",
		},
	},
	{
		id = "overseer",
		name = "Overseer",
		tagline = "Sees every move before it happens",
		passive = "Always takes the first turn.",
		ability = {
			id = "nudge",
			name = "Nudge",
			text = "Move any player (even yourself) 1 tile forward or back.",
			recharge = "rounds",
			amount = R.OverseerRechargeRounds,
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

return Characters
