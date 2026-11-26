--!nocheck
--[[
	End-to-end smoke test: the real server script and real client scripts
	running together on the mini Roblox in tests/mock (virtual 60 Hz clock,
	simulated network latency, DataStores, purchases).

	  lune run tests/smoke            full run (includes all 69 events)
	  lune run tests/smoke quick      skips the all-events sweep

	Players are driven like real people: they tap the actual UI buttons, and
	during matches an autopilot (the game's own bot brain reading the
	client's world) presses the flap/ability keys.
]]

local process = require("@lune/process")
local Mock = require("./mock/Roblox")

local Enum = Mock.Enum
local Vector2 = require("@lune/roblox").Vector2
local quick = table.find(process.args, "quick") ~= nil
local stopAfter = math.huge
for _, a in process.args do
	local n = string.match(a, "^stop=(%d+)$")
	if n then
		stopAfter = tonumber(n)
	end
end
local started = os.clock()

Mock.init(process.cwd)

-- "studio": Roblox Studio before "Enable Studio Access to API Services" is on
local studio = table.find(process.args, "studio") ~= nil
if studio then
	Mock.isStudio = true
	Mock.dataStoresEnabled = false
	quick = true
	stopAfter = math.min(stopAfter, 9) -- persistence checks don't apply
	table.insert(Mock.allowWarnings, "Progress will NOT be saved")
	table.insert(Mock.allowWarnings, "DataStores unavailable")
	print("(studio mode: no DataStore access)")
end

local results = {}
local function section(name: string, fn: () -> ())
	if #results >= stopAfter then
		return
	end
	print("\n== " .. name)
	local before = #Mock.problems
	local t0 = os.clock()
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(Mock.errText(e), 2)
	end)
	if not ok then
		Mock.problem("scenario", name .. ": " .. tostring(err))
	end
	local found = #Mock.problems - before
	table.insert(results, { name = name, problems = found })
	print(
		string.format(
			"   %s (%d new problem%s, %.1fs)",
			if found == 0 then "ok" else "PROBLEMS",
			found,
			if found == 1 then "" else "s",
			os.clock() - t0
		)
	)
end

local function check(cond, msg: string)
	if not cond then
		Mock.problem("check", msg)
	end
	return cond
end

-- Step game time until cond() is true
local function waitFor(cond: () -> boolean, seconds: number, what: string, perFrame: (() -> ())?)
	for _ = 1, math.floor(seconds * 60) do
		if cond() then
			return true
		end
		if perFrame then
			perFrame()
		end
		Mock.step()
	end
	Mock.problem("check", "timed out waiting for " .. what)
	return false
end

local function clickIf(side, text: string): boolean
	local b = Mock.buttons(side, text)[1]
	if b then
		Mock.click(side, b)
		return true
	end
	return false
end

local function serverProfile(side)
	local DataService = Mock.module(Mock.server, "Server/Services/DataService")
	return DataService.get(Mock.wrap(Mock.server, side.playerRaw))
end

local Autopilot = require("./mock/Autopilot")

local function describe(App, pilot)
	local match = App.match
	if not match then
		return "no match"
	end
	local parts = {}
	for _, slot in match.localSlots do
		local b = match.world.birds[slot]
		table.insert(parts, string.format("slot %d lives %s", slot, tostring(b and b.lives)))
	end
	return string.format(
		"tick %d, score %s, %s, flaps %d, abilities %d, event %s",
		match.world.tick,
		tostring(match.world.score),
		table.concat(parts, "; "),
		pilot.flaps,
		pilot.abilities,
		tostring(match.world.event and match.world.event.name)
	)
end

-- Press GO / FIND on a mode card of the Play screen
local function startMode(side, App, modeName: string, opts)
	opts = opts or {}
	if App.current ~= "Play" then
		if App.current ~= "Home" then
			Mock.call(App.go, "Home")
		end
		Mock.clickText(side, "PLAY")
		Mock.run(0.3)
	end
	local label = Mock.labels(side, "^" .. string.gsub(modeName, "%p", "%%%0") .. "$")[1]
	if not check(label ~= nil, modeName .. " card on the Play screen") then
		return false
	end
	local card = label.Parent
	if opts.couch then
		local toggle = Mock.buttons(side, function(b, text)
			return b.Parent == card and string.find(text, "Couch team", 1, true) ~= nil
		end)[1]
		if check(toggle ~= nil, "couch toggle on " .. modeName) then
			Mock.click(side, toggle)
		end
	end
	local go = Mock.buttons(side, function(b, text)
		return (text == "GO" or text == "FIND") and b.Parent == card
	end)[1]
	if not check(go ~= nil, modeName .. " GO/FIND button") then
		return false
	end
	Mock.click(side, go)
	return true
end

local function waitMatch(App, seconds: number, what: string)
	return waitFor(function()
		return App.match ~= nil and App.current == "Hud"
	end, seconds, what)
end

local function waitResults(App, seconds: number, what: string, perFrame)
	return waitFor(function()
		return App.current == "Results"
	end, seconds, what, perFrame)
end

-- Match containers must not grow from one match to the next
local MATCH_CONTAINERS = { "SkuishiUI.Hud", "SkuishiUI.Results", "SkuishiUI.Toasts", "SkuishiBackdrop.Paper" }
local checkLeaks

---------------------------------------------------------------------------------------------
-- Scenario
---------------------------------------------------------------------------------------------
local p1, p2, App1, App2
local guiBaseline, censusBaseline

function checkLeaks(when: string)
	if not censusBaseline then
		return
	end
	local now = Mock.census(p1)
	for _, key in MATCH_CONTAINERS do
		local a, b = censusBaseline[key] or 0, now[key] or 0
		check(b <= a + 25, string.format("%s grew from %d to %d instances %s", key, a, b, when))
	end
end

section("server boots", function()
	Mock.startServer()
	Mock.run(1)
end)

section("player joins (phone), profile loads, daily reward", function()
	p1 = Mock.addPlayer(1001, "Robin", { touch = true })
	App1 = Mock.module(p1, "Client/UI/App")
	waitFor(function()
		return App1.profile ~= nil
	end, 10, "profile on the client")
	Mock.run(2)
	check(App1.current == "Home", "Home screen is shown (got " .. tostring(App1.current) .. ")")
	check(#Mock.buttons(p1, "PLAY") == 1, "PLAY button visible")
	local p = App1.profile
	check(p and p.coins == 150, "100 starting coins + 50 daily reward (got " .. tostring(p and p.coins) .. ")")
	check(#Mock.labels(p1, "Daily reward") > 0, "daily reward toast")
	guiBaseline = Mock.countGui(p1)
	censusBaseline = Mock.census(p1)
	print("   GUI instances on Home: " .. guiBaseline)
end)

section("menu screens open and close", function()
	for _, pair in
		{
			{ "Birds & Looks", "Look" },
			{ "Shop", "Shop" },
			{ "Leaderboards", "Leaderboards" },
			{ "Event Journal", "Journal" },
			{ "Settings", "Settings" },
		}
	do
		Mock.clickText(p1, pair[1])
		Mock.run(1.5)
		check(App1.current == pair[2], "opened " .. pair[2] .. " (got " .. tostring(App1.current) .. ")")
		local back = Mock.buttons(p1, function(_, text)
			return text == "<" or text == "Back" or text == "‹" or text == "←"
		end)
		if check(#back > 0, "back button on " .. pair[2]) then
			Mock.click(p1, back[1])
			Mock.run(0.5)
			check(App1.current == "Home", "back to Home from " .. pair[2])
		else
			Mock.call(App1.go, "Home")
		end
	end
	check(#Mock.labels(p1, "Robux shop opens soon") == 0, "shop notice hidden outside the shop")
end)

section("solo: 40 s of autopilot play", function()
	local pilot = Autopilot.new(Mock, p1)
	startMode(p1, App1, "Solo")
	waitMatch(App1, 5, "solo match to start")
	Mock.run(40, function()
		pilot:frame()
	end)
	print("   " .. describe(App1, pilot))
	check(App1.match and App1.match.world.score > 0, "scored some points")
end)

local function stamp(what)
	local m = App1.match
	print(
		string.format(
			"   [%.1fs] %s: screen %s, match %s, revive %s",
			Mock.Clock.now,
			what,
			tostring(App1.current),
			tostring(m and m.id),
			tostring(m and m.revive ~= nil)
		)
	)
end

section("solo: stop flapping, revive with token, game over, results", function()
	stamp("start")
	waitFor(function()
		return App1.match == nil or App1.match.revive ~= nil or App1.current == "Results"
	end, 120, "death / revive offer")
	if check(App1.match and App1.match.revive, "revive offered") then
		stamp("revive offered")
		check(clickIf(p1, "Use a revive token (1)"), "token revive button")
		waitFor(function()
			return App1.match ~= nil and App1.match.revive == nil
		end, 5, "revive accepted")
		stamp("revived")
		waitFor(function()
			return App1.match == nil or App1.match.revive ~= nil or App1.current == "Results"
		end, 120, "second game over")
		stamp("second game over")
		check(#Mock.buttons(p1, "Use a revive token (1)") == 0, "no token left to offer")
		clickIf(p1, "No thanks")
	end
	waitResults(App1, 40, "results screen")
	Mock.run(2)
	local p = serverProfile(p1)
	check(p and p.stats.soloBest > 0, "solo best saved on the server")
	check(p and p.reviveTokens == 0, "revive token consumed")
	print(string.format("   coins %d, soloBest %d", App1.profile.coins, App1.profile.stats.soloBest))
	Mock.clickText(p1, "Menu")
	Mock.run(1)
	check(App1.current == "Home", "back to Home")
	-- baseline for leak checks: match containers after one full match
	censusBaseline = Mock.census(p1)
	print(
		string.format(
			"   HUD %d, Results %d, backdrop %d instances after the first match",
			censusBaseline["SkuishiUI.Hud"] or 0,
			censusBaseline["SkuishiUI.Results"] or 0,
			censusBaseline["SkuishiBackdrop.Paper"] or 0
		)
	)
end)

local function tiles(side)
	return Mock.buttons(side, function(b)
		local cur = b.Parent
		while cur do
			if cur.ClassName == "ScrollingFrame" then
				return true
			end
			cur = cur.Parent
		end
		return false
	end)
end

section("looks: every bird, color, pattern, hat and death tile", function()
	Mock.clickText(p1, "Birds & Looks")
	Mock.run(1)
	local counts = {}
	for _, cat in { "Bird", "Colors", "Pattern", "Hat", "Death" } do
		Mock.clickText(p1, cat)
		Mock.run(0.3)
		local n = #tiles(p1)
		local clicked = 0
		for i = 1, 80 do
			local list = tiles(p1)
			if i > #list then
				break
			end
			Mock.click(p1, list[i])
			clicked += 1
			Mock.run(if cat == "Death" then 2.5 else 0.25)
		end
		counts[cat] = clicked
		check(n > 0, "tiles in " .. cat)
	end
	print(
		string.format(
			"   clicked %d birds, %d color tiles, %d pattern tiles, %d hats, %d deaths",
			counts.Bird,
			counts.Colors,
			counts.Pattern,
			counts.Hat,
			counts.Death
		)
	)
end)

section("looks: buy and equip a hat, equip a free death, player 2 tab", function()
	local Cosmetics = Mock.module(p1, "Shared/Config/Cosmetics")
	local coins = App1.profile.coins
	local target
	for _, item in Cosmetics.Hats do
		if item.price > 0 and not item.robuxOnly and item.price <= coins and not App1.owns("hat", item.id) then
			if not target or item.price < target.price then
				target = item
			end
		end
	end
	Mock.clickText(p1, "Hat")
	Mock.run(0.3)
	if check(target ~= nil, "an affordable hat (coins " .. coins .. ")") then
		local tile = Mock.buttons(p1, function(b, text)
			return text == target.name and b.Parent and b.Parent.ClassName == "Frame"
		end)[1]
		if check(tile ~= nil, "tile for " .. target.name) then
			Mock.click(p1, tile)
			Mock.run(0.3)
			local buy = Mock.buttons(p1, function(_, text)
				return string.find(text, "^Buy") ~= nil and text ~= "Buy"
			end)[1]
			if check(buy ~= nil, "Buy button for " .. target.name) then
				Mock.click(p1, buy)
				Mock.run(0.3)
				check(clickIf(p1, "Buy"), "confirm Buy")
				waitFor(function()
					return App1.owns("hat", target.id)
				end, 5, "hat ownership")
				Mock.run(0.5)
				check(App1.profile.coins == coins - target.price, "coins charged")
				-- buying equips it right away
				waitFor(function()
					return App1.profile.loadout.hat == target.id
				end, 5, "hat equipped")
				local sp = serverProfile(p1)
				check(sp and sp.loadout.hat == target.id, "server loadout has the hat")
				print("   bought + equipped " .. target.name .. " for " .. target.price)
			end
		end
	end
	-- a free death animation
	Mock.clickText(p1, "Death")
	Mock.run(0.3)
	local free
	for _, item in Cosmetics.Deaths do
		if item.price == 0 and not item.robuxOnly and item.id ~= App1.profile.loadout.death then
			free = item
			break
		end
	end
	if free then
		local tile = Mock.buttons(p1, function(_, text)
			return text == free.name
		end)[1]
		if check(tile ~= nil, "death tile " .. free.name) then
			Mock.click(p1, tile)
			Mock.run(2.5)
			check(clickIf(p1, "Equip"), "Equip death")
			waitFor(function()
				return App1.profile.loadout.death == free.id
			end, 5, "death equipped")
		end
	end
	-- player 2 (couch) tab
	check(clickIf(p1, "Player 2 (couch)"), "Player 2 tab")
	Mock.run(0.5)
	Mock.clickText(p1, "Colors")
	Mock.run(0.3)
	local list = tiles(p1)
	if check(#list > 3, "color swatches on P2 tab") then
		Mock.click(p1, list[4])
		Mock.run(0.3)
		if clickIf(p1, "Equip") then
			waitFor(function()
				return App1.profile.loadout2.color ~= Cosmetics.DefaultLoadout2.color
			end, 5, "P2 color equipped")
		end
	end
	clickIf(p1, "Player 1 / online")
	Mock.call(App1.go, "Home")
	Mock.run(0.5)
end)

section("settings: toggles reach the server", function()
	Mock.clickText(p1, "Settings")
	Mock.run(0.5)
	local toggles = Mock.buttons(p1, function(_, text)
		return string.find(text, ": ON$") ~= nil
	end)
	check(#toggles > 0, "settings toggles")
	for _, t in toggles do
		Mock.click(p1, t)
		Mock.run(0.4)
	end
	Mock.run(1)
	local sp = serverProfile(p1)
	check(sp and sp.settings.shake == false, "shake setting saved (got " .. tostring(sp and sp.settings.shake) .. ")")
	local vols = Mock.buttons(p1, function(_, text)
		return string.find(text, "%%$") ~= nil
	end)
	if vols[1] then
		Mock.click(p1, vols[1])
		Mock.run(0.5)
	end
	-- turn them back on so later matches use default settings
	for _, t in
		Mock.buttons(p1, function(_, text)
			return string.find(text, ": OFF$") ~= nil
		end)
	do
		Mock.click(p1, t)
		Mock.run(0.4)
	end
	Mock.call(App1.go, "Home")
end)

section("journal: practice an event from the lab, leave with X", function()
	local pilot = Autopilot.new(Mock, p1)
	Mock.clickText(p1, "Event Journal")
	Mock.run(0.5)
	local practice = Mock.buttons(p1, "Practice")
	if check(#practice > 0, "Practice buttons for discovered events") then
		Mock.click(p1, practice[1])
		waitMatch(App1, 5, "practice match")
		local seen = nil
		Mock.run(12, function()
			pilot:frame()
			local ev = App1.match and App1.match.world.event
			if ev and not seen then
				seen = ev.name
			end
		end)
		check(seen ~= nil, "practice event started")
		print("   practiced " .. tostring(seen))
		check(clickIf(p1, "X"), "leave button")
		Mock.run(0.3)
		check(clickIf(p1, "Leave"), "confirm leave")
		waitResults(App1, 5, "results after leaving")
		check(#Mock.labels(p1, "You left the match") > 0, "left-match title")
		Mock.clickText(p1, "Menu")
		Mock.run(0.5)
	end
end)

section("bot buddy: autopilot with an AI partner", function()
	local pilot = Autopilot.new(Mock, p1)
	startMode(p1, App1, "Bot Buddy")
	waitMatch(App1, 5, "bot buddy match")
	local nBirds = 0
	if App1.match then
		for _ in App1.match.world.birds do
			nBirds += 1
		end
	end
	check(nBirds == 2, "2 birds in Bot Buddy (got " .. nBirds .. ")")
	Mock.run(30, function()
		pilot:frame()
	end)
	print("   " .. describe(App1, pilot))
	pilot.enabled = false
	waitResults(App1, 180, "bot buddy results", function()
		pilot:frame()
		clickIf(p1, "No thanks")
	end)
	Mock.clickText(p1, "Menu")
	Mock.run(0.5)
end)

section("couch co-op on one phone (touch halves)", function()
	local pilot = Autopilot.new(Mock, p1)
	pilot.useTouch = true
	startMode(p1, App1, "Couch Co-op")
	waitMatch(App1, 5, "couch co-op match")
	check(App1.match and #App1.match.localSlots == 2, "two local birds")
	Mock.run(30, function()
		pilot:frame()
	end)
	print("   " .. describe(App1, pilot))
	local alive = 0
	for _, slot in App1.match and App1.match.localSlots or {} do
		local b = App1.match.world.birds[slot]
		if b and b.lives > 0 then
			alive += 1
		end
	end
	check(alive == 2, "both couch birds still alive after 30 s of autopilot")
	pilot.enabled = false
	waitResults(App1, 240, "couch co-op results", function()
		pilot:frame()
		clickIf(p1, "No thanks")
	end)
	Mock.clickText(p1, "Menu")
	Mock.run(0.5)
	checkLeaks("after couch co-op")
end)

section("couch duel (keyboard)", function()
	local pilot = Autopilot.new(Mock, p1)
	startMode(p1, App1, "Couch Duel")
	waitMatch(App1, 5, "couch duel match")
	Mock.run(25, function()
		pilot:frame()
	end)
	check(App1.match ~= nil and App1.current == "Hud", "couch duel still running after 25 s of good play")
	print("   " .. describe(App1, pilot))
	pilot.enabled = false -- both stop flapping: someone runs out of lives
	waitResults(App1, 300, "couch duel results", function()
		pilot:frame()
	end)
	Mock.run(1)
	local title = Mock.labels(p1, "WINS!")[1] or Mock.labels(p1, "Round over")[1]
	check(title ~= nil, "couch duel result names the winning side")
	print("   result: " .. (if title then title.Text else "?"))
	Mock.clickText(p1, "Menu")
	Mock.run(0.5)
end)

section("second player joins (PC keyboard)", function()
	p2 = Mock.addPlayer(1002, "Sky", { touch = false, viewport = Vector2.new(1920, 1080) })
	App2 = Mock.module(p2, "Client/UI/App")
	waitFor(function()
		return App2.profile ~= nil and App2.current == "Home"
	end, 10, "player 2 home")
end)

local function slotOf(App)
	return App.match and App.match.localSlots[1]
end

section("duos online: two real clients team up", function()
	local a, b = Autopilot.new(Mock, p1), Autopilot.new(Mock, p2)
	startMode(p1, App1, "Duos")
	Mock.run(0.5)
	startMode(p2, App2, "Duos")
	waitMatch(App1, 10, "duos match (p1)")
	waitMatch(App2, 10, "duos match (p2)")
	check(App1.match and App2.match and App1.match.id == App2.match.id, "same match")
	-- How p1 sees p2's bird, compared with p2's own (true) path, using the positions
	-- actually handed to the renderer:
	--   lag: how many ticks behind the true path it is drawn; fit: distance from that path
	--   jerk: |x(t) - 2x(t-1) + x(t-2)| of the drawn bird (0 for steady motion)
	local drawn = {} -- [App] = { [slot] = {x, y} } from the latest render call
	local function hook(App)
		local match = App.match
		if match and not match.__hooked then
			match.__hooked = true
			local view = match.view
			local orig = view.render
			view.render = function(v, world, positions, ...)
				drawn[App] = positions
				return orig(v, world, positions, ...)
			end
		end
	end
	local history = {} -- owner tick -> {x, y}
	local lagSum, fitSum, samples = 0, 0, 0
	local jerkSum, jerkN, ownJerkSum, ownJerkN = 0, 0, 0, 0
	local prevSeen, prevOwn = {}, {}
	local function jerkOf(list, x)
		table.insert(list, x)
		if #list > 3 then
			table.remove(list, 1)
		end
		if #list == 3 then
			local d1, d2 = list[2] - list[1], list[3] - list[2]
			if math.abs(d1) < 12 and math.abs(d2) < 12 and (d1 > 0) == (d2 > 0) and d1 ~= 0 and d2 ~= 0 then
				return math.abs(d2 - d1)
			end
		end
		return nil
	end
	Mock.run(40, function()
		a:frame()
		b:frame()
		hook(App1)
		hook(App2)
		local s2 = slotOf(App2)
		if not (App1.match and App2.match and s2) then
			return
		end
		local mine = App2.match.world.birds[s2]
		if not mine or mine.lives <= 0 then
			return
		end
		local ot = App2.match.world.tick
		history[ot] = { mine.x, mine.y }
		history[ot - 120] = nil
		local seen = drawn[App1] and drawn[App1][s2]
		local own = drawn[App2] and drawn[App2][s2]
		if not seen or ot < 240 then
			return
		end
		local bestD, bestLag = math.huge, nil
		for lag = 0, 60 do
			local h = history[ot - lag]
			if h then
				local d = math.sqrt((h[1] - seen[1]) ^ 2 + (h[2] - seen[2]) ^ 2)
				if d < bestD then
					bestD, bestLag = d, lag
				end
			end
		end
		if bestLag then
			lagSum += bestLag
			fitSum += bestD
			samples += 1
		end
		local j = jerkOf(prevSeen, seen[1])
		if j then
			jerkSum += j
			jerkN += 1
		end
		if own then
			local oj = jerkOf(prevOwn, own[1])
			if oj then
				ownJerkSum += oj
				ownJerkN += 1
			end
		end
	end)
	print("   p1: " .. describe(App1, a))
	print("   p2: " .. describe(App2, b))
	local lag = lagSum / math.max(1, samples)
	local fit = fitSum / math.max(1, samples)
	local jerk = jerkSum / math.max(1, jerkN)
	local ownJerk = ownJerkSum / math.max(1, ownJerkN)
	print(
		string.format(
			"   remote bird: %.1f ticks behind, %.1f units off its true path, jerk %.2f (owner's own %.2f), %d samples",
			lag,
			fit,
			jerk,
			ownJerk,
			samples
		)
	)
	check(samples > 500, "remote bird samples")
	check(lag < 20, "remote bird drawn too far in the past")
	check(fit < 6, "remote bird strays from its true path")
	check(jerk < 0.35, "remote bird motion stutters")
	check(App1.match and App2.match and App1.match.world.score == App2.match.world.score, "both see the same score")
	a.enabled, b.enabled = false, false
	local finalScore = 0
	waitResults(App1, 240, "duos results p1", function()
		a:frame()
		b:frame()
		if App1.match then
			finalScore = App1.match.world.score
		end
		clickIf(p1, "No thanks")
		clickIf(p2, "No thanks")
	end)
	waitResults(App2, 30, "duos results p2")
	Mock.run(1)
	local sp1, sp2 = serverProfile(p1), serverProfile(p2)
	check(
		sp1 and sp2 and finalScore > 0 and sp1.stats.duoBest >= finalScore and sp2.stats.duoBest >= finalScore,
		"duo best saved for both (final score " .. finalScore .. ")"
	)
	Mock.clickText(p1, "Menu")
	Mock.clickText(p2, "Menu")
	Mock.run(0.5)
end)

section("versus online: two clients + bots, played to the end", function()
	local a, b = Autopilot.new(Mock, p1, 0.95), Autopilot.new(Mock, p2, 0.95)
	local wins1 = App1.profile.stats.versusWins + App2.profile.stats.versusWins
	startMode(p1, App1, "Versus")
	startMode(p2, App2, "Versus")
	Mock.run(1)
	check(App1.current == "Queue" and App2.current == "Queue", "both in the versus queue")
	waitMatch(App1, 30, "versus match (p1)")
	waitMatch(App2, 5, "versus match (p2)")
	if App1.match then
		local n = 0
		for _ in App1.match.world.birds do
			n += 1
		end
		print("   birds in the round: " .. n)
		check(n >= 4, "bots filled the versus round")
	end
	local roundStart = Mock.Clock.now
	waitResults(App1, 300, "versus results p1", function()
		a:frame()
		b:frame()
	end)
	local length = Mock.Clock.now - roundStart
	print(string.format("   round lasted %.0f s", length))
	check(length > 15, "versus round ended suspiciously fast")
	waitResults(App2, 300, "versus results p2", function()
		b:frame()
	end)
	Mock.run(2)
	local placements = Mock.labels(p1, "place")
	local victory = Mock.labels(p1, "VICTORY") or {}
	print(
		string.format(
			"   p1 result: %s",
			if #victory > 0 then "VICTORY" elseif placements[1] then placements[1].Text else "?"
		)
	)
	local sp1, sp2 = serverProfile(p1), serverProfile(p2)
	check(sp1.stats.versusGames >= 1 and sp2.stats.versusGames >= 1, "versus games counted")
	print("   versus wins before/after: " .. wins1 .. " / " .. (sp1.stats.versusWins + sp2.stats.versusWins))
	Mock.clickText(p1, "Menu")
	Mock.clickText(p2, "Menu")
	Mock.run(0.5)
end)

section("leaderboards show both players", function()
	Mock.clickText(p1, "Leaderboards")
	waitFor(function()
		return #Mock.labels(p1, "^Robin$") > 0
	end, 10, "Robin on a leaderboard")
	local tabs = Mock.buttons(p1, function(_, text)
		return text == "Duo best" or text == "Duo Best" or string.find(text, "Duo", 1, true) ~= nil
	end)
	if tabs[1] then
		Mock.click(p1, tabs[1])
		waitFor(function()
			return #Mock.labels(p1, "^Sky$") > 0
		end, 10, "Sky on the duo leaderboard")
	end
	Mock.call(App1.go, "Home")
end)

section("robux products: coins granted exactly once, starter pack, revive", function()
	-- pretend the developer pasted product IDs into Config/Products.luau
	for _, side in { Mock.server, p1, p2 } do
		local Products = Mock.module(side, "Shared/Config/Products")
		Products.Ids.Coins_Small = 9001
		Products.Ids.StarterPack = 9002
		Products.Ids.Revive = 9003
		Products.KeyById[9001] = "Coins_Small"
		Products.KeyById[9002] = "StarterPack"
		Products.KeyById[9003] = "Revive"
	end
	Mock.clickText(p1, "Shop")
	Mock.run(1)
	check(#Mock.labels(p1, "Robux shop opens soon") == 0, "shop lists products once IDs exist")
	local coins = serverProfile(p1).coins
	local r1 = Mock.purchase(p1, 9001, "receipt-1")
	local r2 = Mock.purchase(p1, 9001, "receipt-1") -- Roblox may call again for the same receipt
	check(r1 == Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted")
	check(r2 == Enum.ProductPurchaseDecision.PurchaseGranted, "repeat receipt acknowledged")
	Mock.run(1)
	check(serverProfile(p1).coins == coins + 500, "500 coins granted exactly once")
	check(#Mock.labels(p1, "Thanks!") > 0, "thank-you toast")
	Mock.purchase(p1, 9002, "receipt-2")
	Mock.run(1)
	local d = serverProfile(p1)
	check(d.owned.bird.zippy and d.owned.hat.goldcrown and d.owned.death.firework, "starter pack items granted")
	Mock.purchase(p1, 9003, "receipt-3")
	Mock.run(1)
	check(serverProfile(p1).reviveTokens >= 1, "revive token from a purchase outside a match")
	table.insert(Mock.allowWarnings, "unknown product id 424242")
	local unknown = Mock.purchase(p1, 424242, "receipt-4")
	check(unknown == Enum.ProductPurchaseDecision.NotProcessedYet, "unknown product not granted")
	Mock.call(App1.go, "Home")
end)

section("leave and rejoin: profile saved and restored", function()
	local before = Mock.deepCopy(serverProfile(p2))
	Mock.removePlayer(p2)
	Mock.run(3)
	local stored = Mock.storeData("SkuishiProfiles_v1")
	local rec = stored and stored["u_1002"]
	check(rec ~= nil, "profile record in the DataStore")
	if rec then
		check(rec.lock == nil, "session lock released on leave")
		check(rec.data.coins == before.coins, "saved coins match")
	end
	p2 = Mock.addPlayer(1002, "Sky", { touch = false })
	App2 = Mock.module(p2, "Client/UI/App")
	waitFor(function()
		return App2.profile ~= nil
	end, 15, "rejoined profile")
	check(App2.profile.coins == before.coins, "coins restored after rejoin")
	check(App2.profile.stats.versusGames == before.stats.versusGames, "stats restored after rejoin")
end)

if not quick then
	section("all 69 events: practice each one with autopilot", function()
		local Events = Mock.module(p1, "Shared/Config/Events")
		local pilot = Autopilot.new(Mock, p1)
		local never = {}
		-- practice only works for discovered events: discover them all
		local DataService = Mock.module(Mock.server, "Server/Services/DataService")
		Mock.call(DataService.update, Mock.wrap(Mock.server, p1.playerRaw), function(d)
			for _, meta in Events.List do
				d.discovered[meta.name] = true
			end
		end)
		Mock.run(0.5)
		for i, meta in Events.List do
			local before = #Mock.problems
			Mock.call(App1.go, "Home")
			Mock.run(0.1)
			Mock.call(App1.queue, "SOLO", { labEvent = meta.name })
			if not waitMatch(App1, 5, "practice " .. meta.name) then
				continue
			end
			local seen = false
			Mock.run(13, function()
				pilot:frame()
				local ev = App1.match and App1.match.world.event
				if ev and ev.name == meta.name then
					seen = true
				end
			end)
			if not seen then
				table.insert(never, meta.name)
			end
			if App1.match then
				Mock.call(function()
					App1.match:leave()
				end)
			end
			waitResults(App1, 5, "results after practicing " .. meta.name)
			local found = #Mock.problems - before
			if found > 0 or i % 10 == 0 then
				print(
					string.format(
						"   %2d/%d %-16s %s",
						i,
						Events.Count,
						meta.name,
						if found > 0 then found .. " problem(s)" else "ok"
					)
				)
			end
		end
		check(#never == 0, "events that never started in practice: " .. table.concat(never, ", "))
		Mock.call(App1.go, "Home")
		Mock.run(1)
		checkLeaks("after 69 practice matches")
	end)
end

section("server shutdown saves everyone", function()
	local writes = 0
	Mock.close()
	local stored = Mock.storeData("SkuishiProfiles_v1")
	for _, rec in stored or {} do
		writes += 1
		check(rec.data ~= nil, "saved profile has data")
	end
	check(writes >= 2, "profiles saved on shutdown")
end)

print("\n== summary")
for _, r in results do
	print(string.format("   %-62s %s", r.name, if r.problems == 0 then "ok" else r.problems .. " problem(s)"))
end
print(
	string.format(
		"   network: %d reliable, %d unreliable (largest ~%d bytes, limit 900), %d dropped",
		Mock.stats.reliable,
		Mock.stats.unreliable,
		Mock.stats.maxUnreliable,
		Mock.stats.dropped
	)
)
print(string.format("   %.0f s of game time in %.0f s", Mock.Clock.now, os.clock() - started))
print(string.format("   %d problem(s) total", #Mock.problems))
if #Mock.problems > 0 then
	process.exit(1)
end
