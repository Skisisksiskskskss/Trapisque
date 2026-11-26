--[[
	Visuals for hazard events (reading the deterministic ev.s state).
]]

local Kit = require(script.Parent.Parent.ViewKit)
local Canvas = Kit.Canvas
local hex = Kit.hex

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = hex("#222222")

local V = {}

local function group(ctx, parent, size: number, z: number)
	local g = Kit.container(parent, z)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Size = Canvas.size(ctx.space, size, size)
	return g, Canvas.space(0.5, 0.5, 1 / size, 1 / size)
end

-- ALIENS (three original designs) -------------------------------------------------------
V.ALIEN_SWARM = {
	update = function(ctx, _w, ev)
		Kit.sync(ctx, "aliens", ev.s.aliens, function(a)
			local size = a.size
			local g, s = group(ctx, ctx.mid, size * 3, 14)
			local c1, c2 = hex(a.color1), hex(a.color2)
			if a.design == 0 then
				Canvas.circle(g, s, 3, 2, size + 3, { color = c1, z = 14 })
				Canvas.ring(g, s, 0, 0, size, size, 2, { color = INK, z = 15 })
				Canvas.rect(g, s, -4, -1, 8, 8, { color = c2, stroke = INK, strokeW = 1.5, z = 15 })
				Canvas.rect(g, s, 6, -1, 8, 8, { color = c2, stroke = INK, strokeW = 1.5, z = 15 })
				Canvas.line(g, s, 0, -size, -5, -size - 10, 2, { color = INK, z = 15 })
				Canvas.circle(g, s, -5, -size - 13, 3, { color = c2, stroke = INK, strokeW = 1.5, z = 15 })
			elseif a.design == 1 then
				Canvas.diamond(g, s, 0, 0, size, { color = c1, stroke = INK, strokeW = 2, z = 14 })
				for i = -1, 1 do
					Canvas.circle(g, s, i * 8, 0, 3, { color = c2, stroke = INK, strokeW = 1, z = 15 })
				end
			else
				Canvas.rect(g, s, 0, 0, size * 2, size * 2, { color = c1, stroke = INK, strokeW = 2, z = 14 })
				Canvas.rect(g, s, 0, size / 2 + 2.5, size, 5, { color = c2, stroke = INK, strokeW = 1, z = 15 })
				Canvas.rect(g, s, -size / 2 + 3, -size / 2 + 3, 6, 6, { color = BLACK, z = 15 })
				Canvas.rect(g, s, size / 2 - 2, -size / 2 + 3, 6, 6, { color = BLACK, z = 15 })
				Canvas.line(g, s, -size / 2, size, -size / 2 - 3, size + 8, 2, { color = INK, z = 14 })
				Canvas.line(g, s, size / 2, size, size / 2 + 2, size + 8, 2, { color = INK, z = 14 })
			end
			return g
		end, function(a, g)
			g.Position = Canvas.pos(ctx.space, a.x, a.y)
			g.Rotation = math.deg(a.rot)
		end, ev)
	end,
}

-- METEORS with fading trails -------------------------------------------------------------
V.METEOR_SHOWER = {
	build = function(ctx)
		ctx.data.trails = {}
	end,
	update = function(ctx, _w, ev)
		Kit.sync(ctx, "meteors", ev.s.meteors, function(m)
			local g = Kit.container(ctx.mid, 14)
			local core = Canvas.circle(
				g,
				ctx.space,
				m.x,
				m.y,
				m.size,
				{ color = WHITE, stroke = INK, strokeW = 1.5, strokeAlpha = 0.6, z = 15 }
			)
			Kit.gradient(core, { { 0, hex("#ffd999") }, { 0.6, hex("#ff8a4b") }, { 1, hex("#8b2b00") } }, 45)
			local trail = {}
			for i = 1, 10 do
				trail[i] = Canvas.circle(
					g,
					ctx.space,
					m.x,
					m.y,
					m.size * 0.45,
					{ color = Color3.fromRGB(255, 120, 60), alpha = 0.5, z = 14 }
				)
			end
			ctx.data.trails[g] = { core = core, trail = trail, hist = {} }
			return g
		end, function(m, g)
			local d = ctx.data.trails[g]
			d.core.Position = Canvas.pos(ctx.space, m.x, m.y)
			d.core.Rotation = math.deg(m.rot)
			table.insert(d.hist, 1, { m.x, m.y })
			if #d.hist > 12 then
				table.remove(d.hist)
			end
			for i, t in d.trail do
				local h = d.hist[i + 1]
				if h then
					local life = 1 - i * 0.09
					t.Visible = true
					t.Position = Canvas.pos(ctx.space, h[1], h[2])
					t.Size = Canvas.size(ctx.space, m.size * 0.9 * life, m.size * 0.9 * life)
					t.BackgroundTransparency = 1 - life * 0.5
				else
					t.Visible = false
				end
			end
		end, ev)
	end,
}

-- LIGHTNING ---------------------------------------------------------------------------------
V.LIGHTNING_STORM = {
	update = function(ctx, w, ev, now)
		local t = w.tick - ev.startTick
		Kit.sync(ctx, "strikes", ev.s.strikes, function(st)
			local g = Kit.container(ctx.mid, 16)
			local warnCircle =
				Canvas.circle(g, ctx.space, st.x, st.targetY, 16, { color = hex("#c8e6ff"), alpha = 0.2, z = 16 })
			warnCircle.Name = "Warn"
			for y = 0, st.targetY, 12 do
				local dash =
					Canvas.rect(g, ctx.space, st.x, y + 3, 2, 6, { color = hex("#b4d2ff"), alpha = 0.3, z = 16 })
				dash.Name = "Dash"
			end
			local bolt = Kit.container(g, 17)
			bolt.Name = "Bolt"
			for i = 1, #st.segments - 1 do
				local a, b = st.segments[i], st.segments[i + 1]
				Canvas.line(bolt, ctx.space, a[1], a[2], b[1], b[2], 6, { color = WHITE, z = 18 })
				Canvas.line(
					bolt,
					ctx.space,
					a[1],
					a[2],
					b[1],
					b[2],
					11,
					{ color = hex("#78b4ff"), alpha = 0.5, z = 17 }
				)
			end
			Canvas.circle(bolt, ctx.space, st.x, st.targetY, 28, { color = hex("#a0c8ff"), alpha = 0.45, z = 17 })
			bolt.Visible = false
			return g
		end, function(st, g)
			local age = t - st.born
			local active = age >= st.warning and age < st.warning + st.active
			local pulse = 0.18 + math.sin(now * 12.5) * 0.08
			for _, c in g:GetChildren() do
				if c.Name == "Warn" then
					c.Visible = not active
					c.BackgroundTransparency = 1 - pulse
					c.Size = Canvas.size(ctx.space, (16 + math.sin(now * 8) * 4) * 2, (16 + math.sin(now * 8) * 4) * 2)
				elseif c.Name == "Dash" then
					c.Visible = not active
				elseif c.Name == "Bolt" then
					c.Visible = active
				end
			end
			if age >= st.warning + st.active then
				g.Visible = false
			end
		end, ev)
	end,
}

-- LASERS (rays from the center) -----------------------------------------------------------
V.LASER_BEAMS = {
	build = function(ctx, _w, ev)
		ctx.data.beams = {}
		for i = 1, #ev.s.lasers do
			local glow =
				Canvas.line(ctx.mid, ctx.space, 0, 0, 1, 1, 15, { color = hex("#e74c3c"), alpha = 0.6, z = 15 })
			local core = Canvas.line(ctx.mid, ctx.space, 0, 0, 1, 1, 7, { color = WHITE, alpha = 0.9, z = 16 })
			ctx.data.beams[i] = { glow = glow, core = core }
		end
		ctx.data.hub = Canvas.circle(
			ctx.mid,
			ctx.space,
			ctx.W / 2,
			ctx.H / 2,
			10,
			{ color = hex("#e74c3c"), stroke = INK, strokeW = 2, z = 17 }
		)
	end,
	update = function(ctx, w, ev, now)
		local t = w.tick - ev.startTick
		local warning = t < ev.s.warning
		local cx, cy = ctx.W / 2, ctx.H / 2
		local L = ev.s.length
		for i, l in ev.s.lasers do
			local a = l.angle0 + l.speed * t
			local x2, y2 = cx + math.cos(a) * L, cy + math.sin(a) * L
			local b = ctx.data.beams[i]
			Canvas.setLine(b.glow, ctx.space, cx, cy, x2, y2, l.width)
			Canvas.setLine(b.core, ctx.space, cx, cy, x2, y2, l.width / 2)
			if warning then
				b.glow.BackgroundTransparency = 1 - (0.3 + math.sin(now * 10) * 0.2)
				b.core.Visible = false
			else
				b.glow.BackgroundTransparency = 0.25
				b.core.Visible = true
			end
		end
	end,
}

V.HORIZON_BEAMS = {
	update = function(ctx, w, ev, now)
		local t = w.tick - ev.startTick
		Kit.sync(ctx, "hbeams", ev.s.beams, function(b)
			local g = Kit.container(ctx.mid, 15)
			local warn =
				Canvas.rect(g, ctx.space, ctx.W / 2, b.y, ctx.W, 4, { color = hex("#e74c3c"), alpha = 0.4, z = 15 })
			warn.Name = "Warn"
			local mark = Canvas.text(g, {
				text = "!",
				position = Canvas.pos(ctx.space, ctx.W / 2, b.y - 14),
				size = Canvas.size(ctx.space, 30, 22),
				color = hex("#e74c3c"),
				z = 16,
			})
			mark.Name = "Mark"
			local beam = Canvas.rect(
				g,
				ctx.space,
				ctx.W / 2,
				b.y,
				ctx.W,
				b.width,
				{ color = hex("#e74c3c"), alpha = 0.9, z = 15 }
			)
			beam.Name = "Beam"
			Canvas.rect(beam, Canvas.space(0.5, 0.5, 1, 1), 0, 0, 1, 0.5, { color = WHITE, z = 16 })
			return g
		end, function(b, g)
			local on = b.warnStart + b.warning
			local active = t >= on and t < on + b.active
			local warning = t >= b.warnStart and t < on
			local pulse = 0.3 + math.sin(now * 20) * 0.2
			g.Warn.Visible = warning
			g.Warn.BackgroundTransparency = 1 - pulse
			g.Mark.Visible = warning
			g.Mark.TextTransparency = 1 - pulse
			g.Beam.Visible = active
		end)
	end,
}

V.BLACK_HOLE = {
	build = function(ctx, _w, ev)
		local h = ev.s.hole
		local core = Canvas.circle(ctx.mid, ctx.space, h.x, h.y, h.r, { color = WHITE, z = 15 })
		Kit.gradient(core, { { 0, BLACK }, { 0.7, hex("#2c3e50") }, { 1, hex("#5d6d7e") } }, 45)
		ctx.data.arcs = {}
		for i = 1, 5 do
			ctx.data.arcs[i] = Canvas.line(
				ctx.mid,
				ctx.space,
				0,
				0,
				1,
				1,
				3,
				{ color = hex("#e74c3c"), alpha = 0.6 - i * 0.1, z = 16 }
			)
		end
	end,
	update = function(ctx, _w, ev, now)
		local h = ev.s.hole
		for i, arc in ctx.data.arcs do
			local r = h.r + 10 + (i - 1) * 8
			local a0 = now * 2 + (i - 1) * math.pi * 2 / 5
			local a1 = a0 + math.pi * 0.3
			Canvas.setLine(
				arc,
				ctx.space,
				h.x + math.cos(a0) * r,
				h.y + math.sin(a0) * r,
				h.x + math.cos(a1) * r,
				h.y + math.sin(a1) * r,
				3
			)
		end
	end,
}

V.WORMHOLES = {
	build = function(ctx, _w, ev)
		ctx.data.swirls = {}
		for _, p in ev.s.pairs do
			-- dotted connector
			for k = 0, 12 do
				local t = k / 12
				Canvas.circle(
					ctx.back,
					ctx.space,
					p.a.x + (p.b.x - p.a.x) * t,
					p.a.y + (p.b.y - p.a.y) * t,
					2,
					{ color = hex("#8e44ad"), alpha = 0.3, z = 3 }
				)
			end
			for _, hole in { p.a, p.b } do
				Canvas.circle(
					ctx.mid,
					ctx.space,
					hole.x,
					hole.y,
					hole.r * 0.5,
					{ color = hex("#9b59b6"), alpha = 0.5, z = 14 }
				)
				Canvas.ring(ctx.mid, ctx.space, hole.x, hole.y, hole.r, hole.r, 4, { color = hex("#8e44ad"), z = 15 })
				for k = 1, 3 do
					table.insert(ctx.data.swirls, {
						hole = hole,
						k = k,
						f = Canvas.line(ctx.mid, ctx.space, 0, 0, 1, 1, 2, { color = hex("#9b59b6"), z = 15 }),
					})
				end
			end
		end
	end,
	update = function(ctx, _w, _ev, now)
		for _, sw in ctx.data.swirls do
			local r = sw.hole.r * 0.6
			local a0 = now + sw.k * math.pi * 2 / 3
			local a1 = a0 + math.pi * 0.7
			Canvas.setLine(
				sw.f,
				ctx.space,
				sw.hole.x + math.cos(a0) * r,
				sw.hole.y + math.sin(a0) * r,
				sw.hole.x + math.cos(a1) * r,
				sw.hole.y + math.sin(a1) * r,
				2
			)
		end
	end,
}

V.TORNADO = {
	build = function(ctx)
		ctx.data.rings = Kit.pool(ctx, 18, function()
			return Canvas.ring(ctx.mid, ctx.space, 0, 0, 1, 1, 2, { color = hex("#787d82"), alpha = 0.3, z = 14 })
		end)
		ctx.data.debris = Kit.pool(ctx, 14, function()
			return Canvas.rect(ctx.mid, ctx.space, 0, 0, 8, 8, { color = hex("#646464"), alpha = 0.3, z = 15 })
		end)
		ctx.data.base = Canvas.ellipse(ctx.mid, ctx.space, 0, 0, 40, 12, { color = BLACK, alpha = 0.18, z = 13 })
	end,
	update = function(ctx, _w, ev, now)
		local tx, ty = ev.s.x, ev.s.y
		local time = now * 1000 / 60
		local n = #ctx.data.rings
		for i, ring in ctx.data.rings do
			local t = (i - 1) / n
			local y = -t * 500
			local baseR = 30 + t ^ 1.2 * 175
			local wave = math.sin(time * 0.6 + i * 0.9) * (6 + t * 18)
			local r = math.max(6, baseR + wave)
			ring.Position = Canvas.pos(ctx.space, tx + math.cos(time * 0.03 + i) * (1 + t * 6), ty + y)
			ring.Size = Canvas.size(ctx.space, r * (0.6 + t * 0.6) * 2, r * (0.25 + t * 0.9) * 2)
			ring.Rotation = math.deg(math.sin(i + time * 0.02) * 0.35)
			local st = ring:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 1 - (0.05 + t * 0.45)
			end
		end
		for i, d in ctx.data.debris do
			local di = i / #ctx.data.debris
			local vertical = -(0.1 + di * 0.9) * 500 * 0.6
			local angle = time * 0.07 + i * 0.9
			local radial = 30 + di * 190
			d.Position = Canvas.pos(ctx.space, tx + math.cos(angle) * radial * (0.2 + di * 0.85), ty + vertical)
			d.Rotation = time * 3 + i * 40
		end
		ctx.data.base.Position = Canvas.pos(ctx.space, tx, ty + 18)
	end,
}

V.PORTAL_SPIN = {
	build = function(ctx, _w, ev)
		local cx, cy = ctx.W / 2, ctx.H / 2
		Canvas.circle(ctx.mid, ctx.space, cx, cy, 50, { color = hex("#8e44ad"), alpha = 0.55, z = 13 })
		Canvas.ring(
			ctx.back,
			ctx.space,
			cx,
			cy,
			ev.s.radius,
			ev.s.radius,
			2,
			{ color = hex("#8e44ad"), alpha = 0.3, z = 3 }
		)
		ctx.data.swirls = Kit.pool(ctx, 5, function()
			return Canvas.line(ctx.mid, ctx.space, 0, 0, 1, 1, 3, { color = hex("#9b59b6"), z = 14 })
		end)
	end,
	update = function(ctx, w, ev)
		local cx, cy = ctx.W / 2, ctx.H / 2
		local angle = (w.tick - ev.startTick) * 0.02
		for i, s in ctx.data.swirls do
			local a0 = angle * 3 + (i - 1) * math.pi * 2 / 5
			local a1 = a0 + math.pi * 0.6
			Canvas.setLine(
				s,
				ctx.space,
				cx + math.cos(a0) * 30,
				cy + math.sin(a0) * 30,
				cx + math.cos(a1) * 30,
				cy + math.sin(a1) * 30,
				3
			)
		end
	end,
}

-- GEARS --------------------------------------------------------------------------------
V.GEAR_GRIND = {
	build = function(ctx)
		Kit.background(ctx, hex("#e8e0d5"), hex("#c9bca5"), 2)
		ctx.data.bigGears = {}
		for i = 0, 5 do
			local gx, gy, gr = (i * 150) % ctx.W, (i * 100) % ctx.H, 80 + i * 10
			local g, s = group(ctx, ctx.back, gr * 2.6, 3)
			Canvas.circle(g, s, 0, 0, gr, { color = hex("#8c7853"), alpha = 0.15, z = 3 })
			for t = 0, 11 do
				local a = t / 12 * math.pi * 2
				Canvas.rect(
					g,
					s,
					math.cos(a) * (gr + 5),
					math.sin(a) * (gr + 5),
					20,
					20,
					{ color = hex("#8c7853"), alpha = 0.15, z = 3, rot = math.deg(a) }
				)
			end
			g.Position = Canvas.pos(ctx.space, gx, gy)
			ctx.data.bigGears[i + 1] = { g = g, dir = if i % 2 == 1 then -1 else 1 }
		end
	end,
	update = function(ctx, w, ev, now)
		for _, bg in ctx.data.bigGears do
			bg.g.Rotation = now * 30 * bg.dir
		end
		local t = w.tick - ev.startTick
		Kit.sync(ctx, "gears", ev.s.gears, function(gear)
			local g, s = group(ctx, ctx.mid, gear.r * 3, 14)
			local color = hex(gear.color)
			local body = Canvas.circle(
				g,
				s,
				0,
				0,
				gear.r,
				{ color = color, stroke = Canvas.shade(color, -60), strokeW = 2, z = 14 }
			)
			body.Name = "Body"
			for k = 0, gear.teeth - 1 do
				local a = k / gear.teeth * math.pi * 2
				local tooth = Canvas.rect(
					g,
					s,
					math.cos(a) * (gear.r + gear.r * 0.12),
					math.sin(a) * (gear.r + gear.r * 0.12),
					gear.r * 0.3,
					gear.r * 0.3,
					{
						color = Canvas.shade(color, -20),
						z = 13,
						rot = math.deg(a),
					}
				)
				tooth.Name = "Tooth"
			end
			Canvas.circle(g, s, 0, 0, gear.r * 0.62, { color = hex("#e8e0d5"), z = 15 })
			for k = 0, 3 do
				local a = k * math.pi / 2
				Canvas.line(
					g,
					s,
					0,
					0,
					math.cos(a) * gear.r * 0.7,
					math.sin(a) * gear.r * 0.7,
					6,
					{ color = Canvas.shade(color, -40), z = 16 }
				)
			end
			Canvas.circle(g, s, 0, 0, gear.r * 0.15, { color = Canvas.shade(color, 40), z = 17 })
			return g
		end, function(gear, g)
			g.Position = Canvas.pos(ctx.space, gear.x, gear.y)
			g.Rotation = math.deg(gear.angle)
			local safe = t < gear.collidableAt
			local alpha = if safe then 0.6 else 0
			for _, c in g:GetChildren() do
				if c:IsA("GuiObject") then
					c.BackgroundTransparency = if c.Name == "Body" and safe then 0.75 else alpha
				end
			end
		end, ev)
	end,
}

-- PHOTON beams -----------------------------------------------------------------------------
V.PHOTON_SHIFT = {
	build = function(ctx)
		ctx.data.parts = {}
	end,
	update = function(ctx, w, ev)
		local t = w.tick - ev.startTick
		Kit.sync(ctx, "beams", ev.s.beams, function(b)
			local g = Kit.container(ctx.mid, 15)
			local half = math.max(ctx.W, ctx.H) * 1.3
			local dx, dy = math.cos(b.angle), math.sin(b.angle)
			local x1, y1, x2, y2 = b.x - dx * half, b.y - dy * half, b.x + dx * half, b.y + dy * half
			local hue = Color3.fromHSV((b.hue % 360) / 360, 0.9, 1)
			local dashes = Kit.container(g, 15)
			dashes.Name = "Dashes"
			for k = 0, 40 do
				local a, c = k / 41, (k + 0.55) / 41
				Canvas.line(
					dashes,
					ctx.space,
					x1 + (x2 - x1) * a,
					y1 + (y2 - y1) * a,
					x1 + (x2 - x1) * c,
					y1 + (y2 - y1) * c,
					2,
					{ color = hue, alpha = 0.7, z = 15 }
				)
			end
			local glow = Canvas.line(g, ctx.space, x1, y1, x2, y2, 20, { color = hue, alpha = 0.25, z = 15 })
			glow.Name = "Glow"
			local core = Canvas.line(
				g,
				ctx.space,
				x1,
				y1,
				x2,
				y2,
				5,
				{ color = Color3.fromHSV((b.hue % 360) / 360, 0.2, 1), z = 16 }
			)
			core.Name = "Core"
			return g
		end, function(b, g)
			local p = math.max(0, 1 - (t - b.pulseStart) / 25)
			local pulsing = p > 0.02
			g.Dashes.Visible = not pulsing
			g.Glow.Visible = pulsing
			g.Core.Visible = pulsing
			if pulsing then
				g.Glow.Size = UDim2.new(g.Glow.Size.X.Scale, 0, 0, (10 + p * 28) * Canvas.ppu)
				g.Core.Size = UDim2.new(g.Core.Size.X.Scale, 0, 0, (2 + p * 6) * Canvas.ppu)
				g.Glow.BackgroundTransparency = 1 - (0.1 + p * 0.25)
			end
		end)
	end,
}

-- ECHO CHAMBER ---------------------------------------------------------------------------
V.ECHO_CHAMBER = {
	build = function(ctx)
		Kit.background(ctx, hex("#1a0b2e"), nil, 2)
		ctx.data.grid = {}
		for x = 0, ctx.W, 60 do
			table.insert(
				ctx.data.grid,
				Canvas.rect(
					ctx.back,
					ctx.space,
					x,
					ctx.H / 2,
					2,
					ctx.H,
					{ color = hex("#9632ff"), alpha = 0.15, z = 3 }
				)
			)
		end
		for y = 0, ctx.H, 60 do
			table.insert(
				ctx.data.grid,
				Canvas.rect(
					ctx.back,
					ctx.space,
					ctx.W / 2,
					y,
					ctx.W,
					2,
					{ color = hex("#9632ff"), alpha = 0.15, z = 3 }
				)
			)
		end
		ctx.data.bars = Kit.pool(ctx, 60, function()
			local f = Canvas.rect(ctx.back, ctx.space, 0, 0, ctx.W / 30 - 2, 20, { color = WHITE, z = 3 })
			return f
		end)
	end,
	update = function(ctx, w, ev, now)
		local beat = math.sin(now * 1000 / 150)
		for _, f in ctx.data.grid do
			f.BackgroundTransparency = 1 - (0.1 + math.max(0, beat) * 0.2)
		end
		local barW = ctx.W / 30
		for i, f in ctx.data.bars do
			local k = (i - 1) % 30
			local top = i > 30
			local h = math.abs(math.sin(now * 5 + k * 0.5) * math.sin(now * 10 + k * 0.2)) * 100 + 20
			f.Size = Canvas.size(ctx.space, barW - 2, h)
			f.Position = Canvas.pos(ctx.space, k * barW + barW / 2, if top then h / 2 else ctx.H - h / 2)
			f.BackgroundColor3 = Color3.fromHSV(((now * 100 + k * 10) % 360) / 360, 0.6, 0.95)
		end
		local t = w.tick - ev.startTick
		Kit.sync(ctx, "orbs", ev.s.orbs, function(o)
			local g = Kit.container(ctx.mid, 14)
			Canvas.ring(g, ctx.space, o.x - 4, o.y, 1, 1, 4, { color = hex("#00ffff"), alpha = 0.8, z = 14 }).Name = "C"
			Canvas.ring(g, ctx.space, o.x + 4, o.y, 1, 1, 4, { color = hex("#ff00ff"), alpha = 0.8, z = 14 }).Name = "M"
			Canvas.ring(g, ctx.space, o.x, o.y, 1, 1, 4, { color = WHITE, z = 15 }).Name = "Wt"
			return g
		end, function(o, g)
			local age = t - o.born
			local progress = math.clamp(age / o.life, 0, 1)
			local r = math.max(1, progress * o.maxR)
			local alpha = 1 - progress * progress
			for _, ring in g:GetChildren() do
				if ring:IsA("GuiObject") then
					ring.Visible = age >= 0
					ring.Size = Canvas.size(ctx.space, r * 2, r * 2)
					local st = ring:FindFirstChildOfClass("UIStroke")
					if st then
						st.Transparency = 1 - alpha * (if ring.Name == "Wt" then 1 else 0.8)
						st.Thickness = math.max(1, (6 * (1 - progress) + 1) * Canvas.ppu)
					end
				end
			end
		end)
	end,
}

-- COLOR RIFT shards ------------------------------------------------------------------------
V.COLOR_RIFT = {
	update = function(ctx, _w, ev, now)
		Kit.sync(ctx, "shards", ev.s.shards, function(s)
			local g = Kit.container(ctx.mid, 15)
			local color = Color3.fromHSV(s.hue / 360, 0.85, 1)
			Canvas.circle(g, ctx.space, s.x, s.y, s.size * 2.2, { color = color, alpha = 0.16, z = 14 }).Name = "Glow"
			Canvas.diamond(g, ctx.space, s.x, s.y, s.size, { color = color, stroke = WHITE, strokeW = 1, z = 15 }).Name =
				"Core"
			return g
		end, function(s, g)
			local pulse = 0.85 + 0.25 * math.sin(now * 5.5 + s.id)
			local size = s.size * pulse
			g.Glow.Position = Canvas.pos(ctx.space, s.x, s.y)
			g.Glow.Size = Canvas.size(ctx.space, size * 4.4, size * 4.4)
			g.Core.Position = Canvas.pos(ctx.space, s.x, s.y)
			g.Core.Size = Canvas.size(ctx.space, size * 1.3, size * 1.3)
		end, ev)
	end,
}

-- BLIMPS over a sky ------------------------------------------------------------------------
V.BLIMP_CANOPY = {
	build = function(ctx)
		Kit.background(ctx, hex("#cfeefd"), hex("#a6d8ff"), 2)
		ctx.data.clouds = {}
		for i = 0, 5 do
			local g = Kit.container(ctx.back, 3)
			local cw, ch = 120 + (i % 3) * 60, 40 + (i % 2) * 20
			Canvas.ellipse(g, ctx.space, -cw * 0.2, 0, cw * 0.6, ch * 0.8, { color = WHITE, alpha = 0.92, z = 3 })
			Canvas.ellipse(g, ctx.space, cw * 0.1, -6, cw * 0.5, ch * 0.7, { color = WHITE, alpha = 0.92, z = 3 })
			Canvas.ellipse(g, ctx.space, cw * 0.4, 6, cw * 0.45, ch * 0.65, { color = WHITE, alpha = 0.92, z = 3 })
			ctx.data.clouds[i + 1] = { g = g, i = i }
		end
	end,
	update = function(ctx, _w, ev, now)
		for _, c in ctx.data.clouds do
			local i = c.i
			local cx = ((now * 33) * (0.3 + i * 0.02) + i * 220) % (ctx.W + 300) - 150
			local cy = 60 + i * 50 + math.sin(now * 1000 / (600 + i * 30)) * 8
			c.g.Position = UDim2.fromScale(cx / ctx.W, cy / ctx.H)
		end
		Kit.sync(ctx, "blimps", ev.s.blimps, function(b)
			local g, s = group(ctx, ctx.mid, b.width * 1.6, 14)
			local color = hex(b.color)
			local flip = if b.fromBottom then 1 else -1
			local bulbW, bulbH = b.width * 0.9, b.height * 1.4
			local env = Canvas.ellipse(
				g,
				s,
				0,
				-bulbH * 0.08 * flip,
				bulbW / 2,
				bulbH / 2,
				{ color = color, stroke = hex("#282828"), strokeW = 1.4, z = 14 }
			)
			Kit.gradient(
				env,
				{ { 0, Canvas.shade(color, 18) }, { 0.45, color }, { 1, Canvas.shade(color, -8) } },
				90 * flip
			)
			Canvas.ellipse(
				g,
				s,
				-bulbW * 0.18,
				-bulbH * 0.2 * flip,
				bulbW * 0.36,
				bulbH * 0.18,
				{ color = WHITE, alpha = 0.14, z = 15, rot = -14 * flip }
			)
			local gy = bulbH * 0.62 * flip
			local gw = bulbW * 0.5
			Canvas.line(g, s, -gw / 2 + 6, gy - 10 * flip, -gw / 2 + 6, gy, 1.6, { color = hex("#3c3c3c"), z = 14 })
			Canvas.line(g, s, gw / 2 - 6, gy - 10 * flip, gw / 2 - 6, gy, 1.6, { color = hex("#3c3c3c"), z = 14 })
			Canvas.rect(g, s, 0, gy + 6 * flip, gw, 12, { color = hex("#3a3a3a"), round = 4, z = 15 })
			local flame = Canvas.diamond(g, s, 0, gy + 2 * flip, 5, { color = hex("#ff8a3d"), z = 16 })
			flame.Name = "Flame"
			return g
		end, function(b, g)
			g.Position = Canvas.pos(ctx.space, b.x, b.y)
			local f = g:FindFirstChild("Flame")
			if f then
				local flick = 1 + math.sin(now * 12 + b.x) * 0.25
				f.Size = Canvas.size(ctx.space, 7 * flick, 7 * flick)
			end
		end)
	end,
}

return V
