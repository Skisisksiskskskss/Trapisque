--[[
	TurnClock
	Who has to act by when, and when a bot steps in for a human who's away. Pure: the
	caller passes the time in, so the server's Match drives it and the tests can too.

	- A human gets TurnTime (ShopTime at the Potion Seller) from the moment their turn
	  shows up on screen. Untimed games (practice) never run out.
	- When time runs out, the turn is played for them: a roll, or leaving the shop.
	- Only a player who did nothing at all during AwayAfter of their turns in a row
	  counts as away. Then a bot plays their turns, but waits AwayGrace seconds first,
	  so they can take over.
	- Anything they do (a command, a tap, a click) puts them back in control.

		local clock = TurnClock.new({ timed = true })
		clock:begin(seat, phase, shownAt, turnId)  -- a turn or phase starts
		clock:extend(busyUntil)                    -- the current player did something
		clock:activity(seat, now) -> wasAway        -- any input from a human
		clock:expired(now) -> boolean               -- is the current player out of time?
		clock:expire() -> wentAway                  -- time ran out: count it
		clock:isAway(seat), clock:botMayActAt()
]]

local Config = require(script.Parent.Parent.Config)

local T = Config.Timing

local TurnClock = {}
TurnClock.__index = TurnClock

function TurnClock.new(opts)
	local o = opts or {}
	local self = setmetatable({}, TurnClock)
	self.timed = o.timed ~= false
	self.turnTime = o.turnTime or T.TurnTime
	self.shopTime = o.shopTime or T.ShopTime
	self.grace = o.grace or T.AwayGrace
	self.awayAfter = o.awayAfter or T.AwayAfter
	self.seat = nil
	self.turnId = nil
	self.shownAt = 0
	self.deadline = math.huge
	self.lastActive = {} -- [seat] = time of the last input
	self.idleTurns = {} -- [seat] = turns in a row that timed out with no input
	self.counted = {} -- [seat] = the last turn id already counted
	self.away = {} -- [seat] = true while a bot plays for them
	return self
end

-- A turn (or a new phase of one) begins for `seat`; screens show it at `shownAt`.
function TurnClock:begin(seat: number, phase: string, shownAt: number, turnId: any)
	self.seat = seat
	self.turnId = turnId
	self.shownAt = shownAt
	if self.timed then
		self.deadline = shownAt + (if phase == "shop" then self.shopTime else self.turnTime)
	else
		self.deadline = math.huge
	end
end

-- The current player did something mid-turn: leave them time after it finishes playing.
function TurnClock:extend(busyUntil: number)
	if self.timed then
		self.deadline = math.max(self.deadline, busyUntil + 8)
	end
end

-- Input from a human. Returns true if this took them back from a bot.
function TurnClock:activity(seat: number, now: number): boolean
	self.lastActive[seat] = now
	self.idleTurns[seat] = 0
	if self.away[seat] then
		self.away[seat] = nil
		return true
	end
	return false
end

function TurnClock:expired(now: number): boolean
	return now >= self.deadline
end

--[[
	The current player ran out of time (the caller plays the turn for them). Each turn
	counts once, and only if they did nothing since it showed up. Returns true when this
	makes them count as away.
]]
function TurnClock:expire(): boolean
	local seat = self.seat
	if seat == nil or self.counted[seat] == self.turnId then
		return false
	end
	self.counted[seat] = self.turnId
	local idle = (self.lastActive[seat] or -math.huge) < self.shownAt
	if not idle then
		self.idleTurns[seat] = 0
		return false
	end
	self.idleTurns[seat] = (self.idleTurns[seat] or 0) + 1
	if self.idleTurns[seat] >= self.awayAfter and not self.away[seat] then
		self.away[seat] = true
		return true
	end
	return false
end

function TurnClock:isAway(seat: number): boolean
	return self.away[seat] == true
end

-- An away player's turn: a bot may play it from this time on.
function TurnClock:botMayActAt(): number
	return self.shownAt + self.grace
end

return TurnClock
