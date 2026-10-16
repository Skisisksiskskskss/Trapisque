--[[
	Pacing
	How long each engine event takes to animate on the client. The server waits this
	long before the next turn (and before bots act), so everyone sees every hop, spin
	and splash. The client uses the same numbers to time its animations.
]]

local Config = require(script.Parent.Parent.Config)

local T = Config.Timing

local Pacing = {}

-- moves that hop tile by tile
local WALK_KINDS = {
	walk = true,
	moonwalk = true,
	conveyor = true,
	mudslide = true,
	banana = true,
	telepathy = true,
	jeopardy = true,
	nudge = true,
	burn = true,
}
-- moves that zip along the path (knocked back, launched, sliding)
local FAST_KINDS = {
	bonk = true,
	bounce = true,
	skate = true,
	blast = true,
	trampoline = true,
	bounty = true,
}
Pacing.walkKinds = WALK_KINDS
Pacing.fastKinds = FAST_KINDS
Pacing.FastStep = 0.11

local fixed = {
	setup = 0.4,
	deal = 0.8,
	turn = T.TurnBanner,
	skip = 1.1,
	burn = 0.5,
	roll = T.DiceTime,
	choose = 0.25,
	power = 0.25,
	spin = T.SpinTime,
	gain = 0.55,
	handFull = 0.9,
	coin = 0.45,
	trigger = 0.6,
	gotcha = 1.0,
	bounty = 0.4,
	bonk = 0.9,
	shield = 1.0,
	death = 1.4,
	phoenix = 1.3,
	treasure = 2.0,
	gameover = 2.8,
	natural = 0.9,
	blocked = 0.9,
	grog = 1.9,
	snared = 0.9,
	status = 0.7,
	immune = 0.8,
	place = 1.05, -- the card arcs over and is slapped down onto its tile
	hide = 0.75, -- someone hid a trap: a puff of smoke near them
	play = 0.75,
	useCard = 0.7,
	drop = 0.8,
	xray = 1.2,
	ability = 1.3,
	blizzard = 1.2,
	embers = 0.6,
	embersOut = 0.3,
	scorch = 0.8,
	grow = 1.0,
	wither = 0.4,
	offer = 0.5,
	picked = 0.5,
	swap = 1.2,
	handSwap = 0.8,
	give = 0.8,
	recall = 0.5,
	removed = 0.25,
	fizzle = 0.7,
	buy = 0.5,
	shop = 0.4,
	shopClose = 0.2,
	left = 0.6,
	tokenMove = 0.55, -- a used token flies to its new tile
}

function Pacing.duration(e): number
	if e.t == "move" then
		if WALK_KINDS[e.kind] then
			return #e.path * T.StepTime + 0.2
		elseif FAST_KINDS[e.kind] then
			return #e.path * Pacing.FastStep + 0.3
		end
		return 0.8 -- warps: respawn, home, teleport, recall
	end
	if e.t == "status" and e.on == false then
		return 0.3
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
