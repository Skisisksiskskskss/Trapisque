-- Balance report (not part of the normal test run: it plays thousands of games).
-- Bots play free-for-all games with random characters; we count how often each
-- character wins on each map. Fair is 1 / players.
--
--   python3 tools/bundle.py /tmp/b.luau tests/balance.luau && luau /tmp/b.luau
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local Maps = requireModule("Shared/Game/Maps")
local Modes = requireModule("Shared/Game/Modes")
local Characters = requireModule("Shared/Game/Characters")
local Rng = requireModule("Shared/Game/Rng")

local GAMES = BALANCE_GAMES or 1200
local SETUPS = BALANCE_SETUPS or { { 2, "quick" }, { 4, "quick" }, { 4, "standard" }, { 6, "quick" } }
-- BALANCE_MAPS = { "slimy" } limits the report to some maps

local function play(seed, mapId, n, length)
	local rng = Rng.new(seed * 13 + 7)
	local pool = table.clone(Characters.ids)
	rng:shuffle(pool)
	local players = {}
	for i = 1, n do
		players[i] = { id = "bot" .. i, name = "Bot " .. i, isBot = true, character = pool[i] }
	end
	local mode = Modes.get("chaos")
	local g = Engine.new({ mode = "chaos", map = mapId, players = players, seed = seed, target = Modes.targetFor(mode, length), length = length })
	g:start()
	local guard = 0
	while g.phase ~= "over" do
		guard += 1
		if guard > 20000 then
			error("stuck at seed " .. seed)
		end
		local cmd = Bot.decide(g, g.current)
		local ok = false
		if cmd then
			ok = g:command(g.current, cmd)
		end
		if not ok then
			g:autoAct()
		end
	end
	return g
end

local worst = 0
for _, setup in SETUPS do
	local n, length = setup[1], setup[2]
	local fair = 100 / n
	print(string.format("\n== %d players, %s: win %% per character (fair %.1f%%), %d games per map ==", n, length, fair, GAMES))
	local header = string.format("%-10s", "map")
	for _, c in Characters.ids do
		header ..= string.format("%13s", c)
	end
	print(header .. "   rounds  limit")
	for _, mapDef in Maps.list do
		if BALANCE_MAPS and not table.find(BALANCE_MAPS, mapDef.id) then
			continue
		end
		local wins, seen = {}, {}
		for _, c in Characters.ids do
			wins[c] = 0
			seen[c] = 0
		end
		local rounds, limit = 0, 0
		for s = 1, GAMES do
			local g = play(s * 101 + n * 7, mapDef.id, n, length)
			rounds += g.round
			if g.endReason == "rounds" then
				limit += 1
			end
			for _, p in g.players do
				seen[p.character] += 1
				if p.team == g.winnerTeam then
					wins[p.character] += 1
				end
			end
		end
		local line = string.format("%-10s", mapDef.id)
		for _, c in Characters.ids do
			local pct = 100 * wins[c] / math.max(seen[c], 1)
			worst = math.max(worst, math.abs(pct - fair) / fair)
			line ..= string.format("%12.1f%%", pct)
		end
		print(line .. string.format("   %6.1f  %5d", rounds / GAMES, limit))
	end
end
print(string.format("\nWorst character is %.0f%% away from fair.", worst * 100))
