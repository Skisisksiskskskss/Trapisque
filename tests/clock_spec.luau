-- Turn timers and away players (Shared/Game/TurnClock). The server's Match asks the
-- clock whose time is up and whether a bot should play for a human.
local TurnClock = requireModule("Shared/Game/TurnClock")
local Config = requireModule("Shared/Config")

local T = Config.Timing

test("a slow player who is still there never gets a bot", function()
	local clock = TurnClock.new({ timed = true })
	local t = 0
	for turn = 1, 6 do
		clock:begin(1, "action", t, turn)
		-- reads cards, looks around the board... and runs out of time anyway
		clock:activity(1, t + 12)
		truthy(clock:expired(t + T.TurnTime), "out of time after TurnTime")
		falsy(clock:expire(), "turn " .. turn .. " must not count as away")
		falsy(clock:isAway(1), "still in control after turn " .. turn)
		t += 200
	end
end)

test("a player who does nothing for two turns in a row gets a bot, after a grace", function()
	local clock = TurnClock.new({ timed = true })
	clock:begin(1, "action", 0, 1)
	falsy(clock:expire(), "one idle turn is not enough")
	clock:begin(1, "action", 100, 2)
	truthy(clock:expire(), "the second idle turn in a row makes them away")
	truthy(clock:isAway(1))
	clock:begin(1, "action", 200, 3)
	eq(clock:botMayActAt(), 200 + T.AwayGrace, "the bot waits for them first")
end)

test("any input takes control back at once", function()
	local clock = TurnClock.new({ timed = true })
	clock:begin(1, "action", 0, 1)
	clock:expire()
	clock:begin(1, "action", 100, 2)
	clock:expire()
	truthy(clock:isAway(1))
	truthy(clock:activity(1, 150), "activity reports the comeback")
	falsy(clock:isAway(1))
	falsy(clock:activity(1, 151), "only the first input is a comeback")
	-- it takes two more idle turns to count as away again
	clock:begin(1, "action", 300, 3)
	falsy(clock:expire())
	falsy(clock:isAway(1))
end)

test("input between turns counts as being there", function()
	local clock = TurnClock.new({ timed = true })
	clock:begin(1, "action", 100, 1)
	falsy(clock:expire())
	-- they clicked around while the others played
	clock:activity(1, 150)
	clock:begin(1, "action", 200, 2)
	falsy(clock:expire(), "the streak starts over")
	falsy(clock:isAway(1))
	clock:begin(1, "action", 300, 3)
	truthy(clock:expire(), "two idle turns in a row since then")
end)

test("a turn counts once, however many times it times out", function()
	local clock = TurnClock.new({ timed = true })
	-- the Potion Seller times out, then the rest of the same turn does
	clock:begin(1, "shop", 0, 7)
	eq(clock.deadline, T.ShopTime)
	falsy(clock:expire())
	clock:begin(1, "action", 40, 7)
	eq(clock.deadline, 40 + T.TurnTime)
	falsy(clock:expire(), "the same turn again: still just one idle turn")
	falsy(clock:isAway(1))
end)

test("other seats keep their own count", function()
	local clock = TurnClock.new({ timed = true })
	clock:begin(1, "action", 0, 1)
	clock:expire()
	clock:begin(2, "action", 50, 2)
	clock:expire()
	clock:begin(1, "action", 100, 3)
	clock:activity(1, 101)
	falsy(clock:expire(), "seat 1 was there this time")
	clock:begin(2, "action", 150, 4)
	truthy(clock:expire(), "seat 2 was idle twice")
	falsy(clock:isAway(1))
	truthy(clock:isAway(2))
end)

test("practice games have no timer", function()
	local clock = TurnClock.new({ timed = false })
	clock:begin(1, "action", 0, 1)
	eq(clock.deadline, math.huge)
	falsy(clock:expired(1e9))
	clock:extend(500)
	eq(clock.deadline, math.huge, "doing things doesn't start a timer")
end)

test("playing a card leaves time to finish the turn", function()
	local clock = TurnClock.new({ timed = true })
	clock:begin(1, "action", 0, 1)
	-- a card played with 2s left, whose animation runs until t = 46
	clock:extend(46)
	eq(clock.deadline, 54)
	clock:extend(10)
	eq(clock.deadline, 54, "never shortens")
end)
