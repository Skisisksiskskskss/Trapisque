--[[
	Voting
	A map vote's cards, and how the vote is decided (the server's Match runs the vote, the
	client's MapVote shows it):

		Voting.cards(cfg, mapIds, eventIds, hasTwist, rng) -> cards, the map under the Mystery card
		Voting.weights(cards, votes) -> each card's slice of the roulette wheel
		Voting.tally(cards, votes, style, rng) -> the chosen card (and, for the wheel, its slices)

	A card is { kind = "map", map } | { kind = "mystery" } (a face-down map that isn't on
	the other cards) | { kind = "twist", map, event } (a map with a twist on the rules).
	cfg = { mystery = boolean, wildcard = boolean }. votes: [seat] = card number.
	rng: a Random (NextInteger, NextNumber).
]]

local Voting = {}

-- How much of the roulette wheel a card nobody voted for keeps (a vote is 1).
Voting.Sliver = 0.35

function Voting.cards(cfg, mapIds: { string }, eventIds: { string }, hasTwist: string?, rng)
	local pool = table.clone(mapIds)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local cards = { { kind = "map", map = pool[1] }, { kind = "map", map = pool[2] } }
	local mystery = nil
	if cfg.mystery then
		mystery = pool[3]
		table.insert(cards, { kind = "mystery" })
	else
		table.insert(cards, { kind = "map", map = pool[3] })
	end
	if cfg.wildcard then
		-- (never the twist the match already has)
		local twists = {}
		for _, id in eventIds do
			if id ~= hasTwist then
				table.insert(twists, id)
			end
		end
		if #twists > 0 then
			table.insert(cards, { kind = "twist", map = pool[4] or pool[1], event = twists[rng:NextInteger(1, #twists)] })
		end
	end
	return cards, mystery
end

function Voting.weights(cards, votes): { number }
	local weights = {}
	for i in cards do
		weights[i] = Voting.Sliver
	end
	for _, i in votes or {} do
		local n = tonumber(i)
		if n and weights[n] then
			weights[n] += 1
		end
	end
	return weights
end

--[[
	"majority": the most votes wins (a tie, or no votes at all, is settled at random
	among the leaders). "roulette": a spin of a wheel where every vote is a slice.
]]
function Voting.tally(cards, votes, style: string?, rng): (number, { number }?)
	if style == "roulette" then
		local weights = Voting.weights(cards, votes)
		local total = 0
		for _, w in weights do
			total += w
		end
		local r = rng:NextNumber() * total
		for i, w in weights do
			r -= w
			if r <= 0 then
				return i, weights
			end
		end
		return #cards, weights
	end
	local count = {}
	for _, i in votes do
		local n = tonumber(i)
		if n then
			count[n] = (count[n] or 0) + 1
		end
	end
	local best, leaders = 0, {}
	for i in cards do
		local n = count[i] or 0
		if n > best then
			best, leaders = n, { i }
		elseif n == best then
			table.insert(leaders, i)
		end
	end
	return leaders[rng:NextInteger(1, #leaders)], nil
end

return Voting
