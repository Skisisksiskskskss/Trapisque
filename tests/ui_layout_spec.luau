-- Screen layout across real device sizes: nothing overlaps, everything stays inside the
-- safe area and clear of Roblox's own buttons, and the board gets most of the screen.
local Layout = requireModule("Client/UI/Layout")

-- physical size, touch, safe insets, Roblox top bar (y0, y1, l, r) as the engine reports them
local DEVICES = {
	{ name = "1080p monitor", w = 1920, h = 1080 },
	{ name = "1440p monitor", w = 2560, h = 1440 },
	{ name = "720p", w = 1280, h = 720 },
	{ name = "laptop 1366", w = 1366, h = 768 },
	{ name = "laptop 16:10", w = 1280, h = 800 },
	{ name = "4:3 monitor", w = 1024, h = 768 },
	{ name = "5:4 monitor", w = 1280, h = 1024 },
	{ name = "small window", w = 1000, h = 640 },
	{ name = "ultrawide", w = 3440, h = 1440 },
	{ name = "iPad landscape", w = 1180, h = 820, touch = true, safe = { t = 24, b = 20 } },
	{ name = "iPad mini landscape", w = 1024, h = 768, touch = true, safe = { t = 20 } },
	{ name = "iPhone 14 landscape", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, b = 21 }, bar = { y1 = 48, l = 160 } },
	{ name = "iPhone Pro Max landscape", w = 932, h = 430, touch = true, safe = { l = 59, r = 59, b = 21 }, bar = { y1 = 48, l = 170 } },
	{ name = "iPhone SE landscape", w = 667, h = 375, touch = true, bar = { y1 = 44, l = 110 } },
	{ name = "Android landscape", w = 800, h = 360, touch = true, safe = { l = 24 }, bar = { y1 = 44 } },
	{ name = "Pixel landscape", w = 915, h = 412, touch = true, safe = { l = 30 }, bar = { y1 = 48 } },
	{ name = "iPhone 14 portrait", w = 390, h = 844, touch = true, safe = { t = 47, b = 34 }, bar = { y0 = 47, y1 = 95, l = 110, r = 340 } },
	{ name = "iPhone 14 portrait (bar at top)", w = 390, h = 844, touch = true, safe = { t = 47, b = 34 }, bar = { y1 = 58, l = 110, r = 340 } },
	{ name = "iPhone Pro Max portrait", w = 430, h = 932, touch = true, safe = { t = 59, b = 34 }, bar = { y0 = 59, y1 = 107, l = 110, r = 380 } },
	{ name = "iPhone SE portrait", w = 375, h = 667, touch = true, safe = { t = 20 }, bar = { y0 = 20, y1 = 64, l = 100, r = 335 } },
	{ name = "Android portrait", w = 360, h = 800, touch = true, safe = { t = 24 }, bar = { y1 = 56, l = 100, r = 320 } },
	{ name = "big Android portrait", w = 412, h = 915, touch = true, safe = { t = 30 }, bar = { y1 = 60, l = 104, r = 370 } },
	{ name = "iPad portrait", w = 820, h = 1180, touch = true, safe = { t = 24, b = 20 }, bar = { y0 = 24, y1 = 82 } },
	{ name = "iPad mini portrait", w = 744, h = 1133, touch = true, safe = { t = 24, b = 20 }, bar = { y0 = 24, y1 = 82 } },
}

local function metricsFor(d)
	local bar = d.bar or {}
	return Layout.metrics(d.w, d.h, {
		touch = d.touch,
		safe = d.safe,
		topbar = { y0 = bar.y0, y1 = bar.y1, l = bar.l, r = bar.r },
	})
end

local function fmt(r)
	return string.format("(%.0f,%.0f %.0fx%.0f)", r.x, r.y, r.w, r.h)
end

test("every device gets a sensible stage and form", function()
	for _, d in DEVICES do
		local m = metricsFor(d)
		truthy(m.vw >= 400 and m.vh >= 400, d.name .. ": tiny stage " .. m.vw .. "x" .. m.vh)
		if d.h > d.w * 1.1 then
			eq(m.form, "tall", d.name)
		elseif d.h < 560 then
			eq(m.form, "short", d.name)
		else
			eq(m.form, "wide", d.name)
		end
		-- text designed at 14 stage px must stay readable (at least ~11 real px)
		truthy(14 * m.scale >= 11, d.name .. ": text too small, scale " .. m.scale)
	end
end)

test("match HUD pieces never overlap each other, the board or Roblox's buttons", function()
	for _, d in DEVICES do
		for n = 2, 6 do
			local m = metricsFor(d)
			local L = Layout.match(m, n)
			local hud = Layout.matchHud(L)
			local safe = Layout.safeRect(m, 0)
			local names = {}
			for name in hud do
				table.insert(names, name)
			end
			table.sort(names)
			for i, a in names do
				local r = hud[a]
				truthy(r.w > 0 and r.h > 0, d.name .. " " .. a .. " is empty " .. fmt(r))
				truthy(Layout.inside(r, safe), string.format("%s n=%d: %s %s leaves the safe area %s", d.name, n, a, fmt(r), fmt(safe)))
				for _, core in Layout.coreRects(m) do
					falsy(Layout.overlaps(r, core), string.format("%s n=%d: %s %s covers Roblox's buttons %s", d.name, n, a, fmt(r), fmt(core)))
				end
				falsy(Layout.overlaps(r, L.focus), string.format("%s n=%d: %s %s overlaps the board %s", d.name, n, a, fmt(r), fmt(L.focus)))
				for j = i + 1, #names do
					local b = names[j]
					falsy(Layout.overlaps(r, hud[b]), string.format("%s n=%d: %s %s overlaps %s %s", d.name, n, a, fmt(r), b, fmt(hud[b])))
				end
			end
			truthy(Layout.inside(L.focus, safe), d.name .. ": board leaves the safe area")
			for _, core in Layout.coreRects(m) do
				falsy(Layout.overlaps(L.focus, core), d.name .. ": board under Roblox's buttons")
			end
		end
	end
end)

test("the board gets the biggest share of the screen", function()
	for _, d in DEVICES do
		local m = metricsFor(d)
		local L = Layout.match(m, 6)
		local share = (L.focus.w * L.focus.h) / (m.vw * m.vh)
		local want = if m.form == "wide" then 0.45 else 0.45
		truthy(share >= want, string.format("%s: board gets only %.0f%% of the screen", d.name, share * 100))
	end
end)

test("touch targets are big enough to hit", function()
	for _, d in DEVICES do
		local m = metricsFor(d)
		local L = Layout.match(m, 6)
		local s = m.scale
		truthy(L.roll.w * s >= 80 and L.roll.h * s >= 56, d.name .. ": ROLL is too small " .. fmt(L.roll))
		truthy(L.buttons.size * s >= 32, d.name .. ": top buttons too small " .. L.buttons.size * s)
		truthy(L.hand.card.w * s >= 50, d.name .. ": cards too small " .. L.hand.card.w * s)
		truthy(L.players.chip.w * s >= 52, d.name .. ": player chips too narrow " .. L.players.chip.w * s)
		-- the ability is a portrait + button dock, except upright phones where it's one button
		local minAbility = if m.form == "tall" then 34 else 56
		truthy(L.ability.h * s >= minAbility, d.name .. ": ability button too small")
	end
end)

test("modals fit every screen", function()
	for _, d in DEVICES do
		local m = metricsFor(d)
		for _, size in { { 560, 420 }, { 900, 580 }, { 420, 300 } } do
			local w, h, scale = Layout.modal(m, size[1], size[2])
			local cx, cy = Layout.modalCenter(m)
			local r = Layout.rect(cx - w * scale / 2, cy - h * scale / 2, w * scale, h * scale)
			truthy(Layout.inside(r, Layout.safeRect(m, 0)), string.format("%s: modal %dx%d leaves the screen %s", d.name, size[1], size[2], fmt(r)))
			for _, core in Layout.coreRects(m) do
				falsy(Layout.overlaps(r, core), d.name .. ": modal under Roblox's buttons")
			end
		end
	end
end)
