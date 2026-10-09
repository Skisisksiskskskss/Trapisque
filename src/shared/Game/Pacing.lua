--[[
	Pacing
	How long each engine event takes to animate on the client. The server waits this
	long before the next turn (and before bots act), so everyone sees every hop, spin
	and splash. The client uses the same numbers to time its animations.
]]

local Config = require(script.Parent.Parent.Config)

local T = Config.Timing

local Pacing = {}

local WALK_KINDS = {
	walk = true,
	moonwalk = true,
	conveyor = true,
	mud = true,
	mudslide = true,
	sands = true,
	telepathy = true,
	jeopardy = true,
	nudge = true,
}
Pacing.walkKinds = WALK_KINDS

local fixed = {
	setup = 0.4,
	deal = 1.0,
	turn = T.TurnBanner,
	skip = 1.1,
	roll = T.DiceTime,
	spin = T.SpinTime,
	gain = 0.7,
	handFull = 0.9,
	coin = 0.6,
	trigger = 0.6,
	shield = 1.0,
	death = 1.4,
	phoenix = 1.3,
	treasure = 2.0,
	lap = 1.0,
	finished = 1.6,
	gameover = 2.8,
	natural = 1.1,
	blocked = 0.9,
	grog = 1.9,
	snared = 0.9,
	status = 0.9,
	immune = 0.8,
	place = 0.9,
	useCard = 0.9,
	ability = 1.8,
	swap = 1.2,
	handSwap = 0.8,
	give = 0.8,
	recall = 0.5,
	recharge = 0.5,
	removed = 0.25,
	fizzle = 0.7,
	sands = 0.6,
	buy = 0.5,
	shop = 0.4,
	shopClose = 0.2,
	arm = 0.1,
	left = 0.6,
	tokenMove = 0.75, -- a used token flies to its new tile
}

function Pacing.duration(e): number
	if e.t == "move" then
		if WALK_KINDS[e.kind] then
			return #e.path * T.StepTime + 0.2
		end
		return 0.8 -- warps: respawn, home, teleport, recall, spore
	end
	return fixed[e.t] or 0.4
end

function Pacing.total(events): number
	local sum = 0
	for _, e in events do
		sum += Pacing.duration(e)
	end
	return sum
end

return Pacing
