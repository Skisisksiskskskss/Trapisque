--[[
	Tutorial
	The guided first match: a short race (Blitz, one treasure) on Blissful Tricks against
	two gentle bots, as the Fire Starter, with a coach that explains each thing as it
	comes up. The first dice are scripted so every lesson happens: a token to land on,
	a trap card to hide, Power that fills up in time for Blast Off. The bots roll small
	for a while and never play cards, so a new player wins their first match.

	The server (Match) uses mode / map / character / hand / dice; the client's coach
	(Match/Coach) shows the steps.
]]

local Tutorial = {}

Tutorial.mode = "blitz"
Tutorial.map = "blissful"
Tutorial.character = "fire_starter"
Tutorial.hand = { "spike", "speed_boost" }
Tutorial.Gems = 100 -- for finishing it (once)

-- The player's first dice: 3 lands on the first token; no doubles to explain yet.
local HUMAN = { { 3, 5 }, { 6, 2 }, { 4, 5 }, { 5, 3 }, { 6, 4 }, { 4, 6 }, { 5, 6 }, { 6, 3 } }
-- The bots shuffle along meanwhile.
local BOT = { { 1, 2 }, { 2, 1 }, { 1, 3 }, { 2, 3 }, { 3, 1 }, { 1, 2 }, { 2, 1 }, { 3, 2 }, { 1, 2 }, { 2, 3 } }

-- The scripted dice for Engine.new's `rig`.
function Tutorial.dice(humanSeat: number, seats: number)
	local rig = {}
	for seat = 1, seats do
		local list = if seat == humanSeat then HUMAN else BOT
		local copy = {}
		for i, d in list do
			copy[i] = { d[1], d[2] }
		end
		rig[seat] = copy
	end
	return rig
end

--[[
	The coach's lines. `when` names the moment the client waits for (Coach.lua):
		myTurn1      your first turn starts
		previewed    you looked at where a die goes
		gotCard      a card landed in your hand
		myTurn2      your second turn starts
		placed       you hid a trap
		powerFull    your Power bar is full
		ability      you used your ability
		nearRiver    a river is in reach
		won          the match is over
]]
Tutorial.steps = {
	{ id = "dice", when = "myTurn1", text = "Your two dice rolled by themselves. Tap a die to see where it takes you on the board.", point = "dice" },
	{ id = "move", when = "previewed", text = "The die you don't move with charges your POWER. Moving 3 lands on that token: tap the die again to go!", point = "dice" },
	{ id = "card", when = "gotCard", text = "Tokens spin a wheel and win you a card. Your cards wait down here.", point = "hand" },
	{ id = "trap", when = "myTurn2", text = "Hide your Spike near you: drag it onto a tile (or tap it, then a tile). Rivals can't see it!", point = "hand" },
	{ id = "afterTrap", when = "placed", text = "Sneaky! Anyone who lands there goes back to the Start. Now pick a die and move.", point = "dice" },
	{ id = "power", when = "powerFull", text = "Your Power is full! Tap your ability to BLAST OFF 4 tiles forward.", point = "ability" },
	{ id = "river", when = "nearRiver", text = "Rivers stop you in your tracks. A Bridge card carries you across.", point = nil },
	{ id = "goal", when = "ability", text = "Race to the treasure chest at the end of the trail. First one there wins!", point = nil },
	{ id = "done", when = "won", text = "You're a natural! Find a Match to race real pirates.", point = nil },
}

return Tutorial
