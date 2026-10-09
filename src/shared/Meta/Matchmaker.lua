--[[
	Matchmaker
	Pure match-forming logic, shared by the in-server queue (Studio / fallback) and the
	cross-server MemoryStore queue. Unit-tested offline.

	A ticket is one solo player or one party queueing together:
		{ id = string, size = number, users = { userId, ... }, created = seconds }

	Matchmaker.form(mode, tickets, now, cfg) -> matches, leftover
	Each match:
		{ tickets = { ticket, ... }, seats = { { userId, team }, ... }, bots = { { team }, ... } }
	Parties always stay together, and in team modes they are always on the same team.
]]

local Matchmaker = {}

local MAX_DFS_TICKETS = 24

local function copy(list)
	local out = {}
	for i, v in list do
		out[i] = v
	end
	return out
end

local function sizeOf(list)
	local n = 0
	for _, t in list do
		n += t.size
	end
	return n
end

local function removeAll(pending, chosen)
	local set = {}
	for _, t in chosen do
		set[t.id] = true
	end
	local out = {}
	for _, t in pending do
		if not set[t.id] then
			table.insert(out, t)
		end
	end
	return out
end

-- Free-for-all: take tickets oldest-first while they fit.
local function greedy(pending, maxPlayers)
	local chosen, total = {}, 0
	for _, t in pending do
		if total + t.size <= maxPlayers then
			table.insert(chosen, t)
			total += t.size
		end
		if total == maxPlayers then
			break
		end
	end
	return chosen, total
end

local function ffaMatch(chosen, bots)
	local seats = {}
	local team = 0
	for _, t in chosen do
		for _, userId in t.users do
			team += 1
			table.insert(seats, { userId = userId, team = team })
		end
	end
	local botSeats = {}
	for _ = 1, bots do
		team += 1
		table.insert(botSeats, { team = team })
	end
	return { tickets = chosen, seats = seats, bots = botSeats }
end

-- Team modes: find tickets that exactly fill `teams` teams of `teamSize`.
-- The oldest ticket is always included so nobody starves.
local function packTeams(pending, teams, teamSize)
	local list = {}
	for i = 1, math.min(#pending, MAX_DFS_TICKETS) do
		list[i] = pending[i]
	end
	local capacity = {}
	for i = 1, teams do
		capacity[i] = teamSize
	end
	local assignment = {}
	local need = teams * teamSize

	local function dfs(i, filled)
		if filled == need then
			return true
		end
		if i > #list then
			return false
		end
		local t = list[i]
		local triedEmpty = false
		for team = 1, teams do
			if capacity[team] >= t.size then
				local empty = capacity[team] == teamSize
				if not (empty and triedEmpty) then
					triedEmpty = triedEmpty or empty
					capacity[team] -= t.size
					assignment[t.id] = team
					if dfs(i + 1, filled + t.size) then
						return true
					end
					capacity[team] += t.size
					assignment[t.id] = nil
				end
			end
		end
		if i == 1 then
			return false -- the oldest ticket must be in the match
		end
		return dfs(i + 1, filled)
	end

	if dfs(1, 0) then
		local chosen = {}
		for _, t in list do
			if assignment[t.id] then
				table.insert(chosen, t)
			end
		end
		return chosen, assignment
	end
	return nil, nil
end

local function greedyTeams(pending, teams, teamSize)
	local capacity = {}
	for i = 1, teams do
		capacity[i] = teamSize
	end
	local chosen, assignment = {}, {}
	for _, t in pending do
		-- the team with the most room that still fits
		local best, bestRoom = nil, -1
		for team = 1, teams do
			if capacity[team] >= t.size and capacity[team] > bestRoom then
				best, bestRoom = team, capacity[team]
			end
		end
		if best then
			capacity[best] -= t.size
			assignment[t.id] = best
			table.insert(chosen, t)
		end
	end
	return chosen, assignment, capacity
end

local function teamMatch(chosen, assignment, teams, teamSize)
	local seats = {}
	local used = {}
	for team = 1, teams do
		used[team] = 0
		for _, t in chosen do
			if assignment[t.id] == team then
				for _, userId in t.users do
					table.insert(seats, { userId = userId, team = team })
					used[team] += 1
				end
			end
		end
	end
	local bots = {}
	for team = 1, teams do
		for _ = used[team] + 1, teamSize do
			table.insert(bots, { team = team })
		end
	end
	return { tickets = chosen, seats = seats, bots = bots }
end

function Matchmaker.form(mode, tickets, now: number, cfg)
	local pending = copy(tickets)
	table.sort(pending, function(a, b)
		if a.created ~= b.created then
			return a.created < b.created
		end
		return a.id < b.id
	end)
	local matches = {}
	local guard = 0
	while #pending > 0 and guard < 100 do
		guard += 1
		local oldestWait = now - pending[1].created
		local match = nil
		if not mode.isTeam then
			local total = sizeOf(pending)
			if total >= cfg.ChaosTarget or (oldestWait >= cfg.ChaosWait and total >= cfg.ChaosMin) then
				local chosen = greedy(pending, mode.maxPlayers)
				match = ffaMatch(chosen, 0)
			elseif oldestWait >= cfg.BotFillAfter then
				local chosen, count = greedy(pending, mode.maxPlayers)
				match = ffaMatch(chosen, math.max(0, math.max(cfg.ChaosTarget, 2) - count))
			end
		else
			local chosen, assignment = packTeams(pending, mode.teams, mode.teamSize)
			if chosen then
				match = teamMatch(chosen, assignment, mode.teams, mode.teamSize)
			elseif oldestWait >= cfg.BotFillAfter then
				local greedyChosen, greedyAssignment = greedyTeams(pending, mode.teams, mode.teamSize)
				if #greedyChosen > 0 then
					match = teamMatch(greedyChosen, greedyAssignment, mode.teams, mode.teamSize)
				end
			end
		end
		if not match then
			break
		end
		table.insert(matches, match)
		pending = removeAll(pending, match.tickets)
	end
	return matches, pending
end

return Matchmaker
