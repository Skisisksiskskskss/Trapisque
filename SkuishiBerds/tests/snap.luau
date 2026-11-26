--!nocheck
--[[
	Screenshots without Roblox: plays through the game on the mini Roblox and
	writes an approximate HTML rendering of the player's screen at key
	moments to build/snapshots/. Turn them into PNGs with:

	  lune run tests/snap
	  node tests/snap_png.js build/snapshots
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Mock = require("./mock/Roblox")
local Snapshot = require("./mock/Snapshot")
local Autopilot = require("./mock/Autopilot")

local OUT = "build/snapshots"
Mock.init(process.cwd)
fs.writeDir(OUT)

local shots = 0
local function snap(side, name: string)
	shots += 1
	local file = string.format("%s/%02d_%s.html", OUT, shots, name)
	fs.writeFile(file, Snapshot.html(Mock, side, name))
	print("  " .. file)
end

local function clickIf(side, text)
	local b = Mock.buttons(side, text)[1]
	if b then
		Mock.click(side, b)
	end
	return b ~= nil
end

local function waitFor(cond, seconds, perFrame)
	for _ = 1, math.floor(seconds * 60) do
		if cond() then
			return true
		end
		if perFrame then
			perFrame()
		end
		Mock.step()
	end
	return false
end

Mock.startServer()
Mock.run(1)
local p1 = Mock.addPlayer(1001, "Robin", { touch = true })
local App = Mock.module(p1, "Client/UI/App")
waitFor(function()
	return App.profile ~= nil
end, 10)
Mock.run(1)
-- practice (event lab) needs discovered events: discover them all for the screenshots
local Events = Mock.module(p1, "Shared/Config/Events")
local DataService = Mock.module(Mock.server, "Server/Services/DataService")
Mock.call(DataService.update, Mock.wrap(Mock.server, p1.playerRaw), function(d)
	for _, meta in Events.List do
		d.discovered[meta.name] = true
	end
end)
snap(p1, "home_daily_toast")
Mock.run(4)
snap(p1, "home")

Mock.clickText(p1, "PLAY")
Mock.run(0.5)
snap(p1, "play_modes")

-- a solo round
local pilot = Autopilot.new(Mock, p1)
local solo = Mock.labels(p1, "^Solo$")[1]
Mock.click(
	p1,
	Mock.buttons(p1, function(b, text)
		return text == "GO" and b.Parent == solo.Parent
	end)[1]
)
Mock.run(1)
snap(p1, "solo_countdown")
Mock.run(14, function()
	pilot:frame()
end)
snap(p1, "solo_15s")
local gotEvent = waitFor(
	function()
		local m = App.match
		return m and m.world.event ~= nil and m.world.tick > (m.world.event.startTick or 0) + 90
	end,
	30,
	function()
		pilot:frame()
	end
)
if gotEvent then
	snap(p1, "solo_event_" .. App.match.world.event.name)
end
Mock.run(10, function()
	pilot:frame()
end)
snap(p1, "solo_35s")
-- stop playing: death, revive offer
pilot.enabled = false
waitFor(
	function()
		return App.match and App.match.revive ~= nil
	end,
	90,
	function()
		pilot:frame()
	end
)
snap(p1, "revive_offer")
clickIf(p1, "No thanks")
waitFor(function()
	return App.current == "Results"
end, 30)
Mock.run(1.5)
snap(p1, "results_solo")
Mock.clickText(p1, "Menu")
Mock.run(0.5)

-- looks
Mock.clickText(p1, "Birds & Looks")
Mock.run(1)
snap(p1, "look_birds")
for _, cat in { "Colors", "Pattern", "Hat", "Death" } do
	Mock.clickText(p1, cat)
	Mock.run(0.5)
	if cat == "Death" then
		local tiles = Mock.buttons(p1, function(b)
			local cur = b.Parent
			while cur do
				if cur.ClassName == "ScrollingFrame" then
					return true
				end
				cur = cur.Parent
			end
			return false
		end)
		if tiles[3] then
			Mock.click(p1, tiles[3])
			Mock.run(0.4)
		end
	end
	snap(p1, "look_" .. string.lower(cat))
end
Mock.call(App.go, "Home")

for _, pair in
	{
		{ "Shop", "shop" },
		{ "Leaderboards", "leaderboards" },
		{ "Event Journal", "journal" },
		{ "Settings", "settings" },
	}
do
	Mock.clickText(p1, pair[1])
	Mock.run(1.5)
	snap(p1, pair[2])
	Mock.call(App.go, "Home")
end

-- event lab: a few visually busy events
for _, name in { "METEOR_SHOWER", "NEON_TRAILS", "CRT_MODE", "RAIL_RUSH", "BONE_ZONE", "PAPER_MODE" } do
	Mock.call(App.queue, "SOLO", { labEvent = name })
	waitFor(function()
		return App.match ~= nil
	end, 5)
	local seen = waitFor(
		function()
			local m = App.match
			return m
				and m.world.event ~= nil
				and m.world.event.name == name
				and m.world.tick > (m.world.event.startTick or 0) + 150
		end,
		20,
		function()
			pilot.enabled = true
			pilot:frame()
		end
	)
	if seen then
		snap(p1, "event_" .. string.lower(name))
	end
	if App.match then
		Mock.call(function()
			App.match:leave()
		end)
	end
	waitFor(function()
		return App.current == "Results"
	end, 5)
	Mock.call(App.go, "Home")
end

-- couch co-op on one phone
Mock.call(App.queue, "COUCH_COOP", {})
waitFor(function()
	return App.match ~= nil
end, 5)
pilot.useTouch = true
Mock.run(12, function()
	pilot:frame()
end)
snap(p1, "couch_coop")
if App.match then
	Mock.call(function()
		App.match:leave()
	end)
end
pilot.useTouch = false
Mock.run(1)
Mock.call(App.go, "Home")

-- versus with a second (PC) player
local p2 = Mock.addPlayer(1002, "Sky", { touch = false, viewport = roblox.Vector2.new(1600, 900) })
local App2 = Mock.module(p2, "Client/UI/App")
waitFor(function()
	return App2.profile ~= nil
end, 10)
Mock.run(1)
snap(p2, "pc_home")
Mock.call(App.queue, "VERSUS", {})
Mock.call(App2.queue, "VERSUS", {})
Mock.run(1)
snap(p1, "versus_queue")
local pilot2 = Autopilot.new(Mock, p2)
waitFor(function()
	return App.match ~= nil and App2.match ~= nil
end, 30)
Mock.run(20, function()
	pilot:frame()
	pilot2:frame()
end)
snap(p1, "versus_phone")
snap(p2, "versus_pc")
waitFor(
	function()
		return App.current == "Results"
	end,
	240,
	function()
		pilot:frame()
		pilot2:frame()
	end
)
Mock.run(2)
snap(p1, "results_versus")

print(string.format("%d snapshots, %d problem(s)", shots, #Mock.problems))
