--[[
	Visuals for scene events: the whole page changes.
]]

local Kit = require(script.Parent.Parent.ViewKit)
local Canvas = Kit.Canvas
local hex = Kit.hex

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local V = {}

local TRAIL_COLORS = { "#ff0055", "#00ccff", "#ffd166", "#84fab0", "#c9b6e4", "#ffb07c" }

-- LOG JAM: the page floods, logs ride up and down ------------------------------------------
V.LOG_JAM = {
	build = function(ctx)
		ctx.data.water =
			Canvas.rect(ctx.back, ctx.space, ctx.W / 2, ctx.H, ctx.W + 4, 0, { color = hex("#4a90e2"), z = 3 })
		ctx.data.water.AnchorPoint = Vector2.new(0.5, 1)
		ctx.data.ripples = Kit.pool(ctx, 32, function(i)
			return Canvas.rect(
				ctx.back,
				ctx.space,
				(i - 1) * 15,
				ctx.H / 2,
				1.5,
				ctx.H,
				{ color = WHITE, alpha = 0.18, z = 4 }
			)
		end)
		ctx.data.logs = {}
	end,
	update = function(ctx, w, ev, now)
		local t = w.tick - ev.startTick
		local flood = math.clamp(t / 60, 0, 1)
		local fillH = ctx.H * flood
		ctx.data.water.Size = Canvas.size(ctx.space, ctx.W + 4, fillH)
		for i, r in ctx.data.ripples do
			local x = (i - 1) * 15
			local top = ctx.H - fillH + math.sin(x / 20 + now * 6.7) * 5
			r.Position = Canvas.pos(ctx.space, x, (top + ctx.H) / 2)
			r.Size = Canvas.size(ctx.space, 1.5, math.max(0, ctx.H - top))
		end
		Kit.sync(ctx, "logs", ev.s.logs, function(_log)
			local g = Kit.container(ctx.mid, 14)
			local body = Canvas.rect(
				g,
				ctx.space,
				0,
				0,
				1,
				1,
				{ color = hex("#8b5a3c"), stroke = hex("#5a3d2a"), strokeW = 2, round = 8, z = 14 }
			)
			body.Name = "Body"
			local capTop = Canvas.ellipse(g, ctx.space, 0, 0, 1, 1, { color = hex("#6b4f3a"), z = 15 })
			capTop.Name = "CapTop"
			local capBot = Canvas.ellipse(g, ctx.space, 0, 0, 1, 1, { color = hex("#6b4f3a"), z = 15 })
			capBot.Name = "CapBot"
			for k = 1, 3 do
				local grain = Canvas.rect(
					body,
					Canvas.space(0, 0, 1, 1),
					k / 4,
					0.5,
					0.03,
					0.9,
					{ color = BLACK, alpha = 0.18, z = 15 }
				)
				grain.Name = "Grain"
			end
			return g
		end, function(log, g)
			local cx, cy = log.x + log.w / 2, log.y + log.h / 2
			g.Body.Position = Canvas.pos(ctx.space, cx, cy)
			g.Body.Size = Canvas.size(ctx.space, log.w, log.h)
			g.CapTop.Position = Canvas.pos(ctx.space, cx, log.y - 4)
			g.CapTop.Size = Canvas.size(ctx.space, log.w, math.max(8, log.w * 0.36))
			g.CapBot.Position = Canvas.pos(ctx.space, cx, log.y + log.h + 4)
			g.CapBot.Size = Canvas.size(ctx.space, log.w, math.max(8, log.w * 0.36))
		end)
	end,
}

-- DRILL: dirt fills the page, then birds carve tunnels ---------------------------------------
V.DRILL = {
	build = function(ctx)
		local dirt = Canvas.rect(ctx.back, ctx.space, ctx.W / 2, ctx.H, ctx.W + 4, 0, { color = WHITE, z = 3 })
		dirt.AnchorPoint = Vector2.new(0.5, 1)
		Kit.gradient(
			dirt,
			{ { 0, hex("#4b3326") }, { 0.35, hex("#6b4a34") }, { 0.65, hex("#705032") }, { 1, hex("#3e2a1e") } },
			90
		)
		ctx.data.dirt = dirt
		ctx.data.pebbles = {}
		for r = 0, 79 do
			local rs = 1 + (r * 13) % 6
			local p = Canvas.ellipse(ctx.back, ctx.space, (r * 97) % ctx.W, (r * 53 + 31) % ctx.H, rs, rs * 0.8, {
				color = if r % 3 == 0 then hex("#5a4a3f") else hex("#2f241e"),
				alpha = 0.7,
				z = 4,
			})
			p.Visible = false
			table.insert(ctx.data.pebbles, p)
		end
		ctx.data.tunnels = Kit.container(ctx.back, 5)
		ctx.data.lastStamp = {}
	end,
	update = function(ctx, w, ev)
		local t = w.tick - ev.startTick
		local fill = math.clamp(t / 150, 0, 1)
		ctx.data.dirt.Size = Canvas.size(ctx.space, ctx.W + 4, ctx.H * fill)
		if fill < 1 then
			ctx.view.shake = math.max(ctx.view.shake, math.min(18, 24 * (0.25 + fill)) * 0.5)
			for _ = 1, 3 do
				ctx.view.particles:burst(
					ctx.rng:NextNumber(0, ctx.W),
					-5,
					hex("#4b3426"),
					1,
					{ speed = 0.6, up = -4 - fill * 4, gravity = 0.1, decay = 0.02 }
				)
			end
		else
			for _, p in ctx.data.pebbles do
				p.Visible = true
			end
			-- tunnels behind drilling birds
			for _, b in w.birdList do
				if not b.dead and b.drill then
					local last = ctx.data.lastStamp[b.slot]
					if not last or math.abs(last[1] - b.x) + math.abs(last[2] - b.y) > 6 then
						if not last or math.abs(last[2] - b.y) < 100 then
							Canvas.circle(
								ctx.data.tunnels,
								ctx.space,
								b.x,
								b.y,
								b.radius * 1.1,
								{ color = hex("#1a120d"), alpha = 0.95, z = 5 }
							)
						end
						ctx.data.lastStamp[b.slot] = { b.x, b.y }
					end
				end
			end
		end
	end,
}

-- QUICKSAND: sandstorm -----------------------------------------------------------------------
V.QUICKSAND = {
	build = function(ctx)
		Kit.background(ctx, hex("#e0cda9"), hex("#c2b280"), 2)
		ctx.data.dune1 = Canvas.ellipse(
			ctx.back,
			ctx.space,
			ctx.W / 2,
			ctx.H,
			ctx.W * 0.9,
			140,
			{ color = hex("#c2b280"), alpha = 0.4, z = 3 }
		)
		ctx.data.dune2 = Canvas.ellipse(
			ctx.back,
			ctx.space,
			ctx.W / 2,
			ctx.H,
			ctx.W * 0.8,
			120,
			{ color = hex("#b4a06e"), alpha = 0.3, z = 3 }
		)
		ctx.data.streaks = Kit.pool(ctx, 45, function()
			return Canvas.rect(ctx.over, ctx.space, 0, 0, 1.5, 12, { color = hex("#e6d2b4"), alpha = 0.5, z = 41 })
		end)
		ctx.data.seeds = {}
		for i = 1, 45 do
			ctx.data.seeds[i] = {
				x = ctx.rng:NextNumber(0, ctx.W),
				speed = ctx.rng:NextNumber(360, 840),
				len = ctx.rng:NextNumber(2, 22),
				a = ctx.rng:NextNumber(0.3, 0.8),
			}
		end
		Canvas.rect(
			ctx.over,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W,
			ctx.H,
			{ color = Color3.fromRGB(160, 140, 100), alpha = 0.15, z = 40 }
		)
	end,
	update = function(ctx, w, _ev, now)
		local sink = now * 3
		ctx.data.dune1.Position =
			Canvas.pos(ctx.space, ctx.W / 2 + math.sin(now * 0.6) * 40, ctx.H * 0.3 + (sink * 0.5 % ctx.H) * 0.4)
		ctx.data.dune2.Position =
			Canvas.pos(ctx.space, ctx.W / 2 + math.sin(-now * 0.9) * 60, ctx.H * 0.6 + (sink * 0.8 % ctx.H) * 0.3)
		for i, s in ctx.data.streaks do
			local sd = ctx.data.seeds[i]
			local y = (now * sd.speed + i * 61) % (ctx.H + 100) - 50
			s.Position = Canvas.pos(ctx.space, (sd.x + now * 120) % ctx.W, y)
			s.Size = Canvas.size(ctx.space, 1.5, sd.len)
			s.BackgroundTransparency = 1 - sd.a
		end
		for _, b in w.birdList do
			if not b.dead and ctx.rng:NextNumber() < 0.15 then
				ctx.view.particles:burst(
					b.x + ctx.rng:NextNumber(-6, 6),
					b.y - b.radius - 3,
					hex("#f0e6d2"),
					1,
					{ speed = 0.4, up = 0.5 }
				)
			end
		end
	end,
}

-- RAIL RUSH: subway tunnel with trains --------------------------------------------------------
V.RAIL_RUSH = {
	build = function(ctx)
		Kit.background(ctx, hex("#111111"), nil, 2)
		for y = 0, ctx.H, 100 do
			Canvas.rect(ctx.back, ctx.space, ctx.W / 2, y, ctx.W, 2, { color = hex("#333333"), z = 3 })
		end
		ctx.data.lights = Kit.pool(ctx, 8, function(i)
			local top = i <= 4
			local f = Canvas.rect(
				ctx.back,
				ctx.space,
				0,
				if top then 25 else ctx.H - 25,
				40,
				10,
				{ color = hex("#444444"), z = 3 }
			)
			Canvas.rect(f, Canvas.space(0.5, 0.5, 1 / 40, 1 / 10), 0, 0, 30, 6, { color = hex("#ccffcc"), z = 4 })
			return f
		end)
	end,
	update = function(ctx, _w, ev, now)
		local scroll = (now * 500) % 300
		for i, l in ctx.data.lights do
			local k = (i - 1) % 4
			local top = i <= 4
			l.Position = Canvas.pos(ctx.space, -300 + k * 300 + scroll + 20, if top then 25 else ctx.H - 25)
		end
		local blink = math.floor(now * 10) % 2 == 0
		Kit.sync(ctx, "warnings", ev.s.warnings, function(wn)
			local g = Kit.container(ctx.mid, 16)
			Canvas.circle(g, ctx.space, wn.x, wn.y, 25, { color = hex("#ff0000"), z = 16 }).Name = "Light"
			local t = Canvas.text(g, {
				text = "!",
				position = Canvas.pos(ctx.space, wn.x, wn.y),
				size = Canvas.size(ctx.space, 30, 30),
				color = WHITE,
				z = 17,
			})
			t.Name = "Mark"
			return g
		end, function(_wn, g)
			g.Visible = blink
		end)
		Kit.sync(ctx, "trains", ev.s.trains, function(tr)
			local g = Kit.container(ctx.mid, 15)
			local body = Canvas.rect(
				g,
				ctx.space,
				0,
				0,
				tr.w,
				tr.h,
				{ color = hex("#5dade2"), stroke = hex("#2874a6"), strokeW = 4, round = 10, z = 15 }
			)
			body.Name = "Body"
			local inner = Canvas.space(0.5, 0.5, 1 / tr.w, 1 / tr.h)
			Canvas.rect(body, inner, 0, 0, tr.w, 10, { color = hex("#f1c40f"), z = 16 })
			for wx = 20, tr.w - 60, 60 do
				Canvas.rect(
					body,
					inner,
					wx + 20 - tr.w / 2,
					-tr.h / 6 - 2,
					40,
					tr.h / 3 - 5,
					{ color = hex("#abebc6"), z = 16 }
				)
			end
			local cone = Canvas.tri(
				g,
				ctx.space,
				0,
				0,
				200,
				80,
				if tr.dir > 0 then "left" else "right",
				{ color = hex("#ffffc8"), alpha = 0.45, z = 14 }
			)
			cone.Name = "Cone"
			return g
		end, function(tr, g)
			g.Body.Position = Canvas.pos(ctx.space, tr.x + tr.w / 2, tr.y)
			local coneX = if tr.dir > 0 then tr.x + tr.w + 100 else tr.x - 100
			g.Cone.Position = Canvas.pos(ctx.space, coneX, tr.y)
			ctx.view.shake = math.max(ctx.view.shake, 2)
		end)
	end,
}

-- MAGMA FLOW --------------------------------------------------------------------------------
V.MAGMA_FLOW = {
	build = function(ctx)
		local lava = Canvas.rect(ctx.mid, ctx.space, ctx.W / 2, ctx.H, ctx.W + 4, 0, { color = WHITE, z = 13 })
		lava.AnchorPoint = Vector2.new(0.5, 1)
		Kit.gradient(lava, { { 0, hex("#ffd999") }, { 0.6, hex("#ff8a4b") }, { 1, hex("#8b2b00") } }, 90)
		ctx.data.lava = lava
		ctx.data.glow = Canvas.rect(
			ctx.mid,
			ctx.space,
			ctx.W / 2,
			ctx.H,
			ctx.W + 4,
			30,
			{ color = hex("#ffb347"), alpha = 0.35, z = 12 }
		)
	end,
	update = function(ctx, _w, ev, now)
		local h = ev.s.height or 0
		local visible = h < ctx.H * 0.75
		ctx.data.lava.Visible = visible
		ctx.data.glow.Visible = visible
		ctx.data.lava.Size = Canvas.size(ctx.space, ctx.W + 4, h)
		ctx.data.glow.Position = Canvas.pos(ctx.space, ctx.W / 2, ctx.H - h - 8 + math.sin(now * 4) * 3)
		Kit.sync(ctx, "rocks", ev.s.rocks, function(r)
			return Canvas.ellipse(
				ctx.mid,
				ctx.space,
				r.x,
				r.y,
				r.size,
				r.size * 0.7,
				{ color = hex("#8b2b00"), z = 14 }
			)
		end, function(r, f)
			f.Position = Canvas.pos(ctx.space, r.x, r.y)
		end)
	end,
}

-- ICE FIELD: night sky, ice slabs, snowflakes that freeze ---------------------------------
V.ICE_FIELD = {
	build = function(ctx, _w, ev)
		Kit.background(ctx, hex("#071028"), nil, 2)
		ctx.data.stars = Kit.pool(ctx, 60, function(i)
			local s = if i % 8 == 0 then 2.2 else 1
			return Canvas.rect(ctx.back, ctx.space, 0, 0, s, s, { color = WHITE, alpha = 0.8, z = 3 })
		end)
		for _, p in ev.s.patches do
			Canvas.ellipse(ctx.back, ctx.space, p.x + p.w / 2, p.y + 18, p.w / 2, 26, {
				color = hex("#b4d2ff"),
				alpha = 0.14,
				stroke = hex("#c8e6ff"),
				strokeW = 1,
				strokeAlpha = 0.15,
				z = 4,
			})
		end
	end,
	update = function(ctx, _w, ev, now)
		for i, s in ctx.data.stars do
			s.Position = Canvas.pos(ctx.space, (i * 97 + now * 20) % ctx.W, ((i * 53 + now * 8) % ctx.H) * 0.6)
			s.BackgroundTransparency = 0.1 + math.abs(math.sin(now * 3 + i)) * 0.4
		end
		Kit.sync(ctx, "flakes", ev.s.flakes, function(f)
			return Canvas.circle(ctx.mid, ctx.space, f.x, f.y, f.size, { color = hex("#ebf5ff"), z = 15 })
		end, function(f, fr)
			fr.Position = Canvas.pos(ctx.space, f.x, f.y)
		end, ev)
	end,
}

-- BONE ZONE: black box, bone walls scroll in -------------------------------------------------
V.BONE_ZONE = {
	build = function(ctx)
		Kit.background(ctx, BLACK, nil, 2)
		local box = Canvas.rect(
			ctx.back,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			ctx.W - 40,
			ctx.H - 40,
			{ stroke = WHITE, strokeW = 4, z = 3 }
		)
		box.BackgroundTransparency = 1
		ctx.view:setLineStyle("hidden")
	end,
	update = function(ctx, _w, ev)
		Kit.sync(ctx, "bones", ev.s.bones, function(b)
			local g = Kit.container(ctx.mid, 15)
			if b.kind == "floating" then
				Canvas.rect(g, ctx.space, 0, 0, b.w, b.h, { color = WHITE, round = 6, z = 15 }).Name = "Shaft"
				Canvas.circle(g, ctx.space, 0, 0, 10, { color = WHITE, z = 15 }).Name = "CapA"
				Canvas.circle(g, ctx.space, 0, 0, 10, { color = WHITE, z = 15 }).Name = "CapB"
			else
				Canvas.rect(g, ctx.space, 0, 0, b.w - 4, b.h, { color = WHITE, z = 15 }).Name = "Shaft"
				Canvas.circle(g, ctx.space, 0, 0, 10, { color = WHITE, z = 15 }).Name = "CapA"
				Canvas.circle(g, ctx.space, 0, 0, 10, { color = WHITE, z = 15 }).Name = "CapB"
			end
			return g
		end, function(b, g)
			if b.kind == "floating" then
				g.Shaft.Position = Canvas.pos(ctx.space, b.x + b.w / 2, b.y)
				g.CapA.Position = Canvas.pos(ctx.space, b.x, b.y)
				g.CapB.Position = Canvas.pos(ctx.space, b.x + b.w, b.y)
			else
				g.Shaft.Position = Canvas.pos(ctx.space, b.x + b.w / 2, b.y + b.h / 2)
				local endY = if b.y == 0 then b.h else b.y
				g.CapA.Position = Canvas.pos(ctx.space, b.x - 2, endY)
				g.CapB.Position = Canvas.pos(ctx.space, b.x + b.w + 2, endY)
			end
		end)
	end,
}

-- TIMBER: a tree grows in the middle and gets bonked down -----------------------------------
V.TIMBER = {
	build = function(ctx)
		Kit.background(ctx, hex("#87ceeb"), hex("#e0f7fa"), 2)
		ctx.data.far = {}
		for i = 0, 11 do
			local th = 100 + math.sin(i) * 30
			local tri = Canvas.tri(
				ctx.back,
				ctx.space,
				i * ctx.W / 12 + 20,
				ctx.H - th / 2,
				40,
				th,
				"up",
				{ color = hex("#2e7d32"), z = 3 }
			)
			ctx.data.far[i + 1] = { f = tri, th = th, i = i }
		end
		ctx.data.birdsBg = Kit.pool(ctx, 5, function()
			return Canvas.circle(ctx.back, ctx.space, 0, 0, 2.5, { color = WHITE, z = 4 })
		end)
		ctx.data.birdSeeds = {}
		for i = 1, 5 do
			ctx.data.birdSeeds[i] = {
				x = ctx.rng:NextNumber(0, ctx.W),
				y = ctx.rng:NextNumber(0, ctx.H * 0.6),
				vx = ctx.rng:NextNumber(-1, 1),
			}
		end
		-- tree group pivots at its base (W/2, H+50) when it falls
		local SIZE = 4000
		local g = Kit.container(ctx.mid, 14)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = Canvas.pos(ctx.space, ctx.W / 2, ctx.H + 50)
		g.Size = Canvas.size(ctx.space, SIZE, SIZE)
		ctx.data.tree = g
		ctx.data.treeSpace = Canvas.space(0.5, 0.5, 1 / SIZE, 1 / SIZE)
		ctx.data.segments = {}
		ctx.data.canopy = {}
	end,
	update = function(ctx, _w, ev, now)
		for _, t in ctx.data.far do
			t.f.Position = Canvas.pos(ctx.space, t.i * ctx.W / 12 + 20 + math.sin(now + t.i) * 20, ctx.H - t.th / 2)
		end
		for i, b in ctx.data.birdsBg do
			local sd = ctx.data.birdSeeds[i]
			b.Position = Canvas.pos(ctx.space, (sd.x + now * 60 * sd.vx) % (ctx.W + 40) - 20, sd.y)
		end
		local s = ev.s
		local ts = ctx.data.treeSpace
		local pivotY = ctx.H + 50
		local treeW, segH = 110, 120
		-- trunk segments from the top down past the bottom of the screen
		local count = math.ceil((pivotY + 200 - s.treeTop) / segH)
		for i = 1, math.max(count, #ctx.data.segments) do
			local seg = ctx.data.segments[i]
			if i <= count then
				if not seg then
					seg = Canvas.rect(
						ctx.data.tree,
						ts,
						0,
						0,
						treeW,
						segH,
						{ color = hex("#795548"), stroke = hex("#3e2723"), strokeW = 4, z = 14 }
					)
					Canvas.rect(
						seg,
						Canvas.space(0, 0, 1 / treeW, 1 / segH),
						15,
						20,
						10,
						20,
						{ color = BLACK, alpha = 0.1, z = 15 }
					)
					Canvas.rect(
						seg,
						Canvas.space(0, 0, 1 / treeW, 1 / segH),
						treeW - 12,
						30,
						15,
						10,
						{ color = BLACK, alpha = 0.1, z = 15 }
					)
					ctx.data.segments[i] = seg
				end
				seg.Visible = true
				local y = s.treeTop + (i - 1) * segH + segH / 2
				seg.Position = Canvas.pos(ts, 0, y - pivotY)
			elseif seg then
				seg.Visible = false
			end
		end
		-- bushy canopy
		if #ctx.data.canopy == 0 then
			ctx.data.canopy[1] = Canvas.circle(
				ctx.data.tree,
				ts,
				0,
				0,
				treeW * 1.5,
				{ color = hex("#4caf50"), stroke = hex("#3e2723"), strokeW = 3, z = 16 }
			)
			for k = 1, 5 do
				ctx.data.canopy[k + 1] = Canvas.circle(ctx.data.tree, ts, 0, 0, 20, { color = hex("#81c784"), z = 17 })
			end
		end
		local topY = s.treeTop - pivotY
		ctx.data.canopy[1].Position = Canvas.pos(ts, 0, topY - treeW * 0.6)
		for k = 1, 5 do
			ctx.data.canopy[k + 1].Position =
				Canvas.pos(ts, (k - 3) * 40, topY - 40 - math.abs(k - 3) * 10 - treeW * 0.6)
		end
		ctx.data.tree.Rotation = math.deg(s.fallAngle or 0)
	end,
}

-- NEON TRAILS ---------------------------------------------------------------------------------
V.NEON_TRAILS = {
	build = function(ctx)
		Kit.background(ctx, hex("#050505"), nil, 2)
		ctx.data.vlines = {}
		for x = 0, ctx.W, 60 do
			table.insert(
				ctx.data.vlines,
				Canvas.rect(
					ctx.back,
					ctx.space,
					x,
					ctx.H / 2,
					1,
					ctx.H,
					{ color = hex("#00ffcc"), alpha = 0.15, z = 3 }
				)
			)
		end
		ctx.data.hlines = Kit.pool(ctx, 15, function()
			return Canvas.rect(
				ctx.back,
				ctx.space,
				ctx.W / 2,
				0,
				ctx.W,
				1,
				{ color = hex("#00ffcc"), alpha = 0.15, z = 3 }
			)
		end)
		ctx.data.segs = {}
	end,
	update = function(ctx, _w, ev, now)
		local off = (now * 1000 / 50 * 2) % 60
		for i, l in ctx.data.hlines do
			l.Position = Canvas.pos(ctx.space, ctx.W / 2, off + (i - 1) * 60)
		end
		local trails = ev.s.trails or {}
		for slot, trail in trails do
			local list = ctx.data.segs[slot]
			if not list then
				list = {}
				ctx.data.segs[slot] = list
			end
			local color = hex(TRAIL_COLORS[(slot - 1) % #TRAIL_COLORS + 1])
			local idx = 0
			local step = 4
			local i = 1
			while i + step <= #trail do
				local a, b = trail[i], trail[i + step]
				i += step
				if math.abs(a[1] - b[1]) <= 100 and math.abs(a[2] - b[2]) <= 100 then
					idx += 1
					local seg = list[idx]
					if not seg then
						seg = Canvas.line(ctx.mid, ctx.space, 0, 0, 1, 1, 4, { color = color, z = 14 })
						list[idx] = seg
					end
					Canvas.setLine(seg, ctx.space, a[1], a[2], b[1], b[2], 4)
					seg.Visible = true
				end
			end
			for k = idx + 1, #list do
				list[k].Visible = false
			end
		end
	end,
}

return V
