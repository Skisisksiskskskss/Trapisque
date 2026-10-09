--[[
	Modes
	The four Trapisque game modes.

	teams = number of teams, teamSize = players per team. A teamSize of 1 means
	free-for-all. `target` is how many treasures each player needs.
]]

local Config = require(script.Parent.Parent.Config)

local Modes = {}

local defs = {
	{
		id = "chaos",
		name = "Chaos Trapisque",
		short = "Chaos",
		blurb = "Free-for-all. First to 5 treasures wins.",
		minPlayers = 2,
		maxPlayers = 6,
		teamSize = 1,
		target = Config.Rules.TreasuresToWin,
	},
	{
		id = "assist",
		name = "Assist Trapisque",
		short = "Assist",
		blurb = "2 vs 2. A team wins when both teammates have 5 treasures.",
		minPlayers = 4,
		maxPlayers = 4,
		teams = 2,
		teamSize = 2,
		target = Config.Rules.TreasuresToWin,
	},
	{
		id = "factions",
		name = "Factions",
		short = "Factions",
		blurb = "Three teams of 2. Both teammates need 5 treasures.",
		minPlayers = 6,
		maxPlayers = 6,
		teams = 3,
		teamSize = 2,
		target = Config.Rules.TreasuresToWin,
	},
	{
		id = "ww4",
		name = "World War Four",
		short = "WW4",
		blurb = "3 vs 3. Every teammate needs 4 treasures.",
		minPlayers = 6,
		maxPlayers = 6,
		teams = 2,
		teamSize = 3,
		target = 4,
	},
}

Modes.byId = {}
Modes.list = {}
for i, def in defs do
	def.order = i
	def.isTeam = def.teamSize > 1
	Modes.byId[def.id] = def
	table.insert(Modes.list, def)
end

function Modes.get(id: string)
	return Modes.byId[id]
end

-- Match length presets. Classic is the rulebook; Quick fits a Roblox session better.
Modes.lengths = {
	{ id = "quick", name = "Quick", target = 2, blurb = "2 treasures each. About 10 minutes." },
	{ id = "standard", name = "Standard", target = 3, blurb = "3 treasures each. About 15 minutes." },
	{ id = "classic", name = "Classic", blurb = "The full rulebook: 5 treasures (4 in World War Four)." },
}
Modes.lengthById = {}
for _, l in Modes.lengths do
	Modes.lengthById[l.id] = l
end

function Modes.targetFor(mode, length: string?): number
	local l = length and Modes.lengthById[length]
	if l and l.target then
		return math.min(l.target, mode.target)
	end
	return mode.target
end

-- Can a party of `size` players queue for this mode together?
-- Team modes keep a party together on one team, so the party must fit in a team.
function Modes.partyFits(mode, size: number): boolean
	if size < 1 or size > mode.maxPlayers then
		return false
	end
	if mode.isTeam then
		return size <= mode.teamSize
	end
	return true
end

return Modes
