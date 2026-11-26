--[[
	Visuals for modifier / screen / line / item / spike events.
	(Items and spike states are drawn by ArenaView itself; these add the
	event's decoration, matching the original drawEventNotification effects.)
]]

local Kit = require(script.Parent.Parent.ViewKit)
local Canvas = Kit.Canvas
local hex = Kit.hex

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local V = {}

-- moving decorative lines/arrows ------------------------------------------------------
local function arrowPool(ctx, n, color, alpha)
	return Kit.pool(ctx, n, function()
		local holder = Kit.container(ctx.over, 41)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = Canvas.size(ctx.space, 24, 40)
		local inner = Canvas.space(0.5, 0.5, 1 / 24, 1 / 40)
		Canvas.line(holder, inner, 0, -18, 0, 18, 3, { color = color, alpha = alpha, z = 41 })
		Canvas.line(holder, inner, 0, 18, -9, 8, 3, { color = color, alpha = alpha, z = 41 })
		Canvas.line(holder, inner, 0, 18, 9, 8, 3, { color = color, alpha = alpha, z = 41 })
		return holder
	end)
end

V.SPEED_BOOST = {
	build = function(ctx)
		ctx.data.lines = Kit.pool(ctx, 10, function()
			return Canvas.rect(
				ctx.over,
				ctx.space,
				ctx.W / 2,
				0,
				ctx.W,
				3,
				{ color = hex("#ff6b6b"), alpha = 0.35, z = 41 }
			)
		end)
	end,
	update = function(ctx, _w, _ev, now)
		local H = ctx.H
		for i, l in ctx.data.lines do
			local y = ((i - 1) * H / 10 + (now * 100) % (H / 10))
			l.Position = Canvas.pos(ctx.space, ctx.W / 2, y)
		end
	end,
}

V.GRAVITY_FLIP = {
	build = function(ctx)
		ctx.data.arrows = arrowPool(ctx, 5, hex("#9b59b6"), 0.5)
	end,
	update = function(ctx, _w, _ev, now)
		for i, a in ctx.data.arrows do
			local y = (now * 50 + (i - 1) * 160) % ctx.H
			a.Position = Canvas.pos(ctx.space, ctx.W / 2 - 30, y)
		end
	end,
}

V.GRAVITY_BOOST = {
	build = function(ctx)
		ctx.data.arrows = arrowPool(ctx, 8, hex("#d63031"), 0.45)
	end,
	update = function(ctx, _w, _ev, now)
		for i, a in ctx.data.arrows do
			local x = (i - 1) * ctx.W / 8 + ctx.W / 16
			local y = (now * 66 + (i - 1) * 50) % ctx.H
			a.Position = Canvas.pos(ctx.space, x, y)
		end
	end,
}

V.SIZE_SWAP = {}
V.TINY_MODE = {}
V.GIANT_MODE = {}
V.SHIELD = {}
V.SWAP_POSITIONS = {}
V.REVERSE_CONTROLS = {}
V.ROCKET_BOOTS = {}
V.SPEED_BOOTS = {}
V.HOVER_DRONE = {}
V.GRAVITY_SHOE = {}
V.BLASTERS = {}
V.BIG_WINGS = {}
V.SPIKE_WALK = {}
V.SPIKE_MERGE = {}
V.SPIKE_SPIN = {}
V.SPIKE_SHRINK = {}
V.SPIKE_MULTIPLY = {}

V.MAGNET = {
	build = function(ctx)
		ctx.data.lines = Kit.pool(ctx, 3, function()
			return Canvas.line(ctx.over, ctx.space, 0, 0, 1, 1, 2, { color = hex("#e74c3c"), alpha = 0.55, z = 41 })
		end)
	end,
	update = function(ctx, w, _ev, now)
		local alive = {}
		for _, b in w.birdList do
			if not b.dead then
				table.insert(alive, b)
			end
		end
		for i, l in ctx.data.lines do
			local a, b = alive[1], alive[2]
			if a and b then
				local off = math.sin(now * 5 + i) * 20
				Canvas.setLine(l, ctx.space, a.x, a.y + off, b.x, b.y + off, 2)
				l.Visible = true
			else
				l.Visible = false
			end
		end
	end,
}

V.SOLO_MAGNET = {
	build = function(ctx)
		local g = Kit.container(ctx.mid, 13)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Size = Canvas.size(ctx.space, 100, 100)
		local s = Canvas.space(0.5, 0.5, 1 / 100, 1 / 100)
		local metal = hex("#2b2b2b")
		Canvas.rect(g, s, -24, -8, 14, 44, { color = metal, z = 13 })
		Canvas.rect(g, s, 24, -8, 14, 44, { color = metal, z = 13 })
		Canvas.rect(g, s, 0, 18, 62, 14, { color = metal, round = 6, z = 13 })
		Canvas.rect(g, s, -24, -32, 14, 10, { color = hex("#e74c3c"), z = 14 })
		Canvas.rect(g, s, 24, -32, 14, 10, { color = hex("#3498db"), z = 14 })
		ctx.data.mag = g
	end,
	update = function(ctx, _w, ev)
		local m = ev.s.mag
		if m then
			ctx.data.mag.Position = Canvas.pos(ctx.space, m.x, m.y)
			ctx.data.mag.Rotation = math.deg(m.rot)
		end
	end,
}

V.GHOST_MODE = {
	build = function(ctx)
		Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W,
			ctx.H,
			{ color = hex("#2ecc71"), alpha = 0.05, z = 41 }
		)
	end,
}

V.TURBULENCE = {
	build = function(ctx)
		ctx.data.wind = Kit.pool(ctx, 20, function()
			return Canvas.rect(ctx.over, ctx.space, 0, 0, 12, 2, { color = hex("#1abc9c"), alpha = 0.4, z = 41 })
		end)
	end,
	update = function(ctx, _w, _ev, now)
		for i, f in ctx.data.wind do
			local x = (now * 200 + (i - 1) * 80) % ctx.W
			local y = (i - 1) * ctx.H / 20 + math.sin(now * 5 + i) * 30
			f.Position = Canvas.pos(ctx.space, x, y)
		end
	end,
}

V.SPIKE_RAIN = {
	build = function(ctx)
		ctx.data.flash = Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W,
			ctx.H,
			{ color = hex("#fd79a8"), alpha = 0.1, z = 41 }
		)
	end,
	update = function(ctx, _w, _ev, now)
		ctx.data.flash.BackgroundTransparency = 1 - 0.2 * (0.5 + 0.5 * math.sin(now * 10))
	end,
}

V.SLOW_MO = {
	build = function(ctx)
		ctx.data.boxes = {}
	end,
	update = function(ctx, w, _ev, now)
		local idx = 0
		for _, b in w.birdList do
			if not b.dead then
				for k = 1, 3 do
					idx += 1
					local box = ctx.data.boxes[idx]
					if not box then
						box = Canvas.rect(
							ctx.over,
							ctx.space,
							0,
							0,
							1,
							1,
							{ stroke = hex("#00b894"), strokeW = 2, strokeAlpha = 0.35, z = 41 }
						)
						ctx.data.boxes[idx] = box
					end
					local s = b.radius * 2 + k * 10 + math.sin(now * 2 + k) * 3
					box.Position = Canvas.pos(ctx.space, b.x, b.y)
					box.Size = Canvas.size(ctx.space, s, s)
					box.Visible = true
				end
			end
		end
		for i = idx + 1, #ctx.data.boxes do
			ctx.data.boxes[i].Visible = false
		end
	end,
}

V.RAINBOW_MODE = {
	build = function(ctx)
		ctx.data.bands = Kit.pool(ctx, 8, function(i)
			return Canvas.rect(
				ctx.over,
				ctx.space,
				(i - 0.5) * ctx.W / 8,
				ctx.H / 2,
				ctx.W / 8,
				ctx.H,
				{ color = WHITE, alpha = 0.1, z = 41 }
			)
		end)
	end,
	update = function(ctx, _w, _ev, now)
		for i, f in ctx.data.bands do
			f.BackgroundColor3 = Color3.fromHSV(((now * 100 + i * 30) % 360) / 360, 0.8, 1)
		end
	end,
}

V.TRAMPOLINE = {
	build = function(ctx, w)
		local s = ctx.space
		Canvas.ellipse(ctx.back, s, ctx.W / 2, ctx.H + 20, ctx.W * 0.6, 50, { color = BLACK, z = 3 })
		Canvas.ellipse(ctx.back, s, ctx.W / 2, ctx.H + 20, ctx.W * 0.7, 70, { color = BLACK, alpha = 0.2, z = 3 })
		if #w.birdList >= 2 then
			Canvas.ellipse(ctx.back, s, ctx.W / 2, -20, ctx.W * 0.6, 50, { color = BLACK, z = 3 })
			Canvas.ellipse(ctx.back, s, ctx.W / 2, -20, ctx.W * 0.7, 70, { color = BLACK, alpha = 0.2, z = 3 })
		end
	end,
}

V.MIRROR_WORLD = {
	build = function(ctx)
		ctx.data.ghosts = {}
	end,
	update = function(ctx, w)
		local i = 0
		for _, b in w.birdList do
			if not b.dead then
				i += 1
				local g = ctx.data.ghosts[i]
				if not g then
					g = Canvas.circle(ctx.mid, ctx.space, 0, 0, 1, {
						color = hex("#95a5a6"),
						alpha = 0.25,
						stroke = hex("#222222"),
						strokeW = 1,
						strokeAlpha = 0.2,
						z = 13,
					})
					ctx.data.ghosts[i] = g
				end
				local bv = ctx.view.birdViews[b.slot]
				if bv then
					g.BackgroundColor3 = bv.color
				end
				g.Position = Canvas.pos(ctx.space, ctx.W - b.x, b.y)
				g.Size = Canvas.size(ctx.space, b.radius * 2, b.radius * 2)
				g.Visible = true
			end
		end
		for k = i + 1, #ctx.data.ghosts do
			ctx.data.ghosts[k].Visible = false
		end
	end,
}

V.SPIKE_MELT = {
	update = function(ctx, w)
		for _, s in w.spikes do
			if s.meltStart and ctx.rng:NextNumber() < 0.1 then
				local tipX = if s.side < 0 then s.size * 1.5 else ctx.W - s.size * 1.5
				ctx.view.particles:burst(tipX, s.y + 5, hex("#e67e22"), 1, { speed = 0.5, up = -1 })
			end
		end
	end,
}

V.SPIKE_SHATTER = {
	build = function(ctx, w)
		for _, s in w.spikes do
			ctx.view:shatterSpike(s, w.tick)
		end
	end,
}

V.SPIKE_VANISH = {
	update = function(ctx, w)
		for _, s in w.spikes do
			if s.vanishStart and ctx.rng:NextNumber() < 0.05 then
				local tipX = if s.side < 0 then s.size * 1.5 else ctx.W - s.size * 1.5
				ctx.view.particles:burst(tipX, s.y, hex("#9b59b6"), 1)
			end
		end
	end,
}

V.BUBBLE_BOUNCE = {
	build = function(ctx)
		ctx.data.bubbles = Kit.pool(ctx, 14, function()
			return Canvas.ring(ctx.back, ctx.space, 0, 0, 6, 6, 1.5, { color = hex("#74ebd5"), alpha = 0.6, z = 3 })
		end)
		ctx.data.seed = {}
		for i = 1, 14 do
			ctx.data.seed[i] =
				{ x = ctx.rng:NextNumber(0, ctx.W), speed = ctx.rng:NextNumber(30, 80), r = ctx.rng:NextNumber(3, 10) }
		end
	end,
	update = function(ctx, _w, _ev, now)
		for i, b in ctx.data.bubbles do
			local sd = ctx.data.seed[i]
			local y = ctx.H - ((now * sd.speed + i * 97) % (ctx.H + 40))
			b.Position = Canvas.pos(ctx.space, sd.x + math.sin(now * 2 + i) * 10, y)
			b.Size = Canvas.size(ctx.space, sd.r * 2, sd.r * 2)
		end
	end,
}

V.KALEIDOSCOPE = {
	build = function(ctx)
		Kit.background(ctx, hex("#1a1033"), nil, 2)
		ctx.data.petals = Kit.pool(ctx, 24, function()
			return Canvas.diamond(ctx.back, ctx.space, ctx.W / 2, ctx.H / 2, 40, { color = WHITE, alpha = 0.5, z = 3 })
		end)
	end,
	update = function(ctx, _w, _ev, now)
		local cx, cy = ctx.W / 2, ctx.H / 2
		for i, p in ctx.data.petals do
			local ring = math.floor((i - 1) / 8)
			local a = ((i - 1) % 8) / 8 * math.pi * 2 + now * (0.6 + ring * 0.25) * (if ring % 2 == 0 then 1 else -1)
			local d = 90 + ring * 110 + math.sin(now * 2 + i) * 20
			p.Position = Canvas.pos(ctx.space, cx + math.cos(a) * d, cy + math.sin(a) * d)
			p.Rotation = 45 + math.deg(a) + now * 60
			p.BackgroundColor3 = Color3.fromHSV(((now * 60 + i * 15) % 360) / 360, 0.75, 1)
			local size = 50 + ring * 20
			p.Size = Canvas.size(ctx.space, size, size)
		end
	end,
}

V.BOUNCY = {
	build = function(ctx)
		ctx.view:setLineStyle("accent", hex("#55efc4"))
	end,
}

V.LINE_PULSE = {
	build = function(ctx)
		ctx.view:setLineStyle("accent", hex("#00bcd4"))
		ctx.data.waves = {}
	end,
	update = function(ctx, _w, ev)
		Kit.sync(ctx, "waves", ev.s.waves, function()
			local holder = Kit.container(ctx.over, 41)
			local ring = Canvas.ring(holder, ctx.space, 0, 0, 1, 1, 4, { color = hex("#00bcd4"), alpha = 0.5, z = 41 })
			local bar = Canvas.rect(holder, ctx.space, 0, 0, 1, 4, { color = hex("#00bcd4"), alpha = 0.5, z = 41 })
			holder:SetAttribute("ok", true)
			ctx.data.waves[holder] = { ring = ring, bar = bar }
			return holder
		end, function(wv, holder)
			local parts = ctx.data.waves[holder]
			local mid = ctx.W / 2
			parts.ring.Position = Canvas.pos(ctx.space, mid, wv.y)
			parts.ring.Size = Canvas.size(ctx.space, wv.radius * 2, wv.radius * 2)
			local st = parts.ring:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 1 - wv.alpha * 0.5
			end
			parts.bar.Position = Canvas.pos(ctx.space, mid, wv.y)
			parts.bar.Size = Canvas.size(ctx.space, wv.radius * 2, 4)
			parts.bar.BackgroundTransparency = 1 - wv.alpha * 0.5
		end)
	end,
}

V.LINE_SPLIT = {
	build = function(ctx)
		ctx.view:setLineStyle("hidden")
		for _, fx in { 0.33, 0.5, 0.67 } do
			local x = ctx.W * fx
			for y = 0, ctx.H, 15 do
				Canvas.rect(ctx.back, ctx.space, x, y + 5, 3, 10, { color = hex("#9c27b0"), alpha = 0.6, z = 4 })
			end
		end
	end,
}

V.LINE_MAGNET = {
	build = function(ctx)
		ctx.view:setLineStyle("accent", hex("#ff5722"))
		for i = 0, 4 do
			local off = 30 + i * 25
			for _, x in { ctx.W / 2 - off, ctx.W / 2 + off } do
				for y = 0, ctx.H, 10 do
					Canvas.rect(
						ctx.back,
						ctx.space,
						x,
						y + 2.5,
						2,
						5,
						{ color = hex("#ff5722"), alpha = 0.3 - i * 0.05, z = 4 }
					)
				end
			end
		end
	end,
}

V.LINE_TELEPORT = {
	build = function(ctx)
		ctx.view:setLineStyle("hidden")
		ctx.data.segs = Kit.pool(ctx, 40, function()
			return Canvas.line(ctx.back, ctx.space, 0, 0, 1, 1, 6, { color = hex("#673ab7"), alpha = 0.7, z = 4 })
		end)
		ctx.data.dots = Kit.pool(ctx, 10, function()
			return Canvas.circle(ctx.back, ctx.space, 0, 0, 3, { color = hex("#673ab7"), alpha = 0.6, z = 5 })
		end)
	end,
	update = function(ctx, _w, _ev, now)
		local t = now * 10
		local step = ctx.H / #ctx.data.segs
		for i, seg in ctx.data.segs do
			local y0, y1 = (i - 1) * step, i * step
			Canvas.setLine(
				seg,
				ctx.space,
				ctx.W / 2 + math.sin(y0 / 30 + t) * 10,
				y0,
				ctx.W / 2 + math.sin(y1 / 30 + t) * 10,
				y1,
				6
			)
		end
		for i, d in ctx.data.dots do
			local y = (t * 10 + i * 50) % ctx.H
			d.Position = Canvas.pos(ctx.space, ctx.W / 2 + math.sin(y / 30 + t) * 10, y)
		end
	end,
}

V.WALL_WRAP = {
	build = function(ctx)
		for _, x in { 7.5, ctx.W - 7.5 } do
			local f = Canvas.rect(
				ctx.back,
				ctx.space,
				x,
				ctx.H / 2,
				15,
				ctx.H,
				{ color = hex("#8e44ad"), alpha = 0.8, z = 4 }
			)
			Kit.fadeGradient(f, 0.8, 0.2, if x < ctx.W / 2 then 0 else 180)
		end
	end,
}

V.SPACE = {
	build = function(ctx)
		Kit.background(ctx, BLACK, nil, 2)
		ctx.data.stars = Kit.pool(ctx, 60, function(i)
			local size = (i % 3) + 1
			return Canvas.rect(ctx.back, ctx.space, 0, 0, size, size, { color = WHITE, z = 3 })
		end)
	end,
	update = function(ctx, _w, _ev, now)
		for i, st in ctx.data.stars do
			local x = (i * 137 + now * 50) % ctx.W
			local y = (i * 293) % ctx.H
			st.Position = Canvas.pos(ctx.space, x, y)
			st.Rotation = math.deg(math.sin(now + i * 0.3) * 0.2)
		end
	end,
}

-- LIGHTS OUT: darkness everywhere except around the birds you control (all birds in couch)
V.DARKNESS = {
	build = function(ctx)
		ctx.data.rects = Kit.pool(ctx, 16, function()
			return Canvas.rect(ctx.over, ctx.space, 0, 0, 1, 1, { color = BLACK, alpha = 0.95, z = 45 })
		end)
		ctx.data.rings = Kit.pool(ctx, 2, function()
			local f = Canvas.circle(ctx.over, ctx.space, 0, 0, 1, { z = 45 })
			f.BackgroundTransparency = 1
			return f
		end)
	end,
	update = function(ctx, w)
		local R = 150
		local holes = {}
		for _, b in w.birdList do
			if b.sim and not b.dead and #holes < 2 then
				table.insert(holes, { b.x - R, b.y - R, b.x + R, b.y + R })
			end
		end
		-- vertical bands from hole x-edges; cover everything outside the holes
		local xs = { 0, ctx.W }
		for _, h in holes do
			table.insert(xs, math.clamp(h[1], 0, ctx.W))
			table.insert(xs, math.clamp(h[3], 0, ctx.W))
		end
		table.sort(xs)
		local used = 0
		local s = ctx.space
		for i = 1, #xs - 1 do
			local x0, x1 = xs[i], xs[i + 1]
			if x1 - x0 > 0.5 then
				local cx = (x0 + x1) / 2
				local covers = {}
				for _, h in holes do
					if cx > h[1] and cx < h[3] then
						table.insert(covers, { h[2], h[4] })
					end
				end
				table.sort(covers, function(a, b)
					return a[1] < b[1]
				end)
				local y = 0
				local function emit(ya, yb)
					if yb - ya > 0.5 and used < #ctx.data.rects then
						used += 1
						local r = ctx.data.rects[used]
						r.Position = Canvas.pos(s, cx, (ya + yb) / 2)
						r.Size = Canvas.size(s, x1 - x0 + 1, yb - ya + 1)
						r.Visible = true
					end
				end
				for _, c in covers do
					emit(y, math.max(y, c[1]))
					y = math.max(y, c[2])
				end
				emit(y, ctx.H)
			end
		end
		for i = used + 1, #ctx.data.rects do
			ctx.data.rects[i].Visible = false
		end
		-- round the square holes with thick rings
		local ppu = Canvas.ppu
		for i, ring in ctx.data.rings do
			local h = holes[i]
			if h then
				ring.Visible = true
				ring.Position = Canvas.pos(s, (h[1] + h[3]) / 2, (h[2] + h[4]) / 2)
				ring.Size = Canvas.size(s, R * 2, R * 2)
				Canvas.stroke(ring, BLACK, R * 0.45 * ppu, 0.05)
			else
				ring.Visible = false
			end
		end
	end,
}

V.CRT_MODE = {
	build = function(ctx)
		for y = 0, ctx.H, 8 do
			Canvas.rect(ctx.over, ctx.space, ctx.W / 2, y, ctx.W, 1.4, { color = BLACK, alpha = 0.22, z = 42 })
		end
		local vig =
			Canvas.rect(ctx.over, ctx.space, ctx.W / 2, ctx.H / 2, ctx.W, ctx.H, { color = BLACK, alpha = 0.3, z = 42 })
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.2, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		g.Parent = vig
		ctx.data.bar = Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			0,
			ctx.W + 20,
			20,
			{ color = hex("#ff7878"), alpha = 0.12, z = 42 }
		)
	end,
	update = function(ctx, _w, ev, now)
		ctx.view.page.Position = UDim2.new(0.5, math.floor(math.sin(now * 2.2) * 2 + math.sin(now * 5.3) * 0.6), 0.5, 0)
		local bar = ctx.data.bar
		bar.Visible = ctx.rng:NextNumber() < 0.06
		if bar.Visible then
			bar.Position = Canvas.pos(ctx.space, ctx.W / 2, ctx.rng:NextNumber(0, ctx.H))
		end
		Kit.sync(ctx, "glitches", ev.s.glitches, function(g)
			return Canvas.diamond(ctx.mid, ctx.space, g.x, g.y, g.size, {
				color = Color3.fromHSV(g.hue / 360, 0.65, 1),
				stroke = WHITE,
				strokeW = 1,
				z = 14,
			})
		end, function(g, f)
			local pulse = 0.85 + 0.25 * math.sin(now * 5.5 + g.id)
			f.Position = Canvas.pos(ctx.space, g.x, g.y)
			f.Size = Canvas.size(ctx.space, g.size * 1.3 * pulse, g.size * 1.3 * pulse)
		end, ev)
	end,
}

V.BINARY_MODE = {
	build = function(ctx)
		Kit.background(ctx, WHITE, nil, 2)
		Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W,
			ctx.H,
			{ color = hex("#808080"), alpha = 0.15, z = 41 }
		)
	end,
}

V.COLOR_CHAOS = {
	build = function(ctx)
		ctx.data.tint = Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W,
			ctx.H,
			{ color = WHITE, alpha = 0.12, z = 41 }
		)
	end,
	update = function(ctx, _w, _ev, now)
		ctx.data.tint.BackgroundColor3 = Color3.fromHSV((now * 0.5) % 1, 0.8, 1)
	end,
}

V.GLITCH_MODE = {
	build = function(ctx)
		ctx.data.bars = Kit.pool(ctx, 3, function()
			return Canvas.rect(ctx.over, ctx.space, 0, 0, 80, 4, { color = hex("#ff00ff"), alpha = 0.4, z = 42 })
		end)
	end,
	update = function(ctx)
		local rng = ctx.rng
		if rng:NextNumber() < 0.3 then
			ctx.view.page.Position = UDim2.new(0.5, rng:NextNumber(-20, 20) * Canvas.ppu, 0.5, 0)
		else
			ctx.view.page.Position = UDim2.fromScale(0.5, 0.5)
		end
		for _, b in ctx.data.bars do
			b.Visible = rng:NextNumber() < 0.4
			if b.Visible then
				b.Position = Canvas.pos(ctx.space, rng:NextNumber(0, ctx.W), rng:NextNumber(0, ctx.H))
				b.Size = Canvas.size(ctx.space, rng:NextNumber(10, 100), rng:NextNumber(1, 5))
				b.BackgroundColor3 = if rng:NextNumber() < 0.5 then hex("#ff00ff") else hex("#00ffff")
			end
		end
	end,
}

return V
