--[[
	Deaths: what plays when a bird loses its last heart (customizable in the
	shop), plus the small heart splat when you lose a life.

	Each animation is a small timeline driven by Deaths.step(view, frames).
]]

local Canvas = require(script.Parent.Canvas)

local Deaths = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromHex("#222222")

local function track(view, fx)
	view.deathAnims = view.deathAnims or {}
	table.insert(view.deathAnims, fx)
end

local function newFx(view, duration: number, update)
	local fx = { t = 0, duration = duration, frames = {}, update = update, view = view }
	track(view, fx)
	return fx
end

local function add(fx, inst)
	table.insert(fx.frames, inst)
	return inst
end

-- Persistent paint splat (original Splatter): blob + droplets, stays for the round
local function splat(view, x: number, y: number, color: Color3, scale: number)
	local s = view.space
	local layer = view.layers.eventBack
	local group = Instance.new("Folder")
	group.Name = "Splat"
	group.Parent = layer
	local rng = view.rng
	Canvas.circle(group, s, x, y, 18 * scale, { color = color, alpha = 0.85, z = 3 })
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(14, 30) * scale
		Canvas.circle(
			group,
			s,
			x + math.cos(a) * d,
			y + math.sin(a) * d,
			rng:NextNumber(3, 8) * scale,
			{ color = color, alpha = 0.85, z = 3 }
		)
	end
	for _ = 1, 3 do
		local dx = rng:NextNumber(-14, 14) * scale
		Canvas.ellipse(
			group,
			s,
			x + dx,
			y + 22 * scale,
			2.5 * scale,
			rng:NextNumber(5, 10) * scale,
			{ color = color, alpha = 0.85, z = 3 }
		)
	end
	view.splats = view.splats or {}
	table.insert(view.splats, group)
end

function Deaths.heartSplat(view, x: number, y: number, color: Color3)
	local fx = newFx(view, 40, nil)
	local s = view.space
	local holder = add(fx, Instance.new("Frame"))
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = Canvas.pos(s, x, y)
	holder.Size = Canvas.size(s, 24, 24)
	holder.ZIndex = 35
	holder.Parent = view.layers.fx
	local inner = Canvas.space(0.5, 0.5, 0.5, 0.5)
	Canvas.circle(holder, inner, -0.3, -0.15, 0.34, { color = color, z = 36 })
	Canvas.circle(holder, inner, 0.3, -0.15, 0.34, { color = color, z = 36 })
	Canvas.diamond(holder, inner, 0, 0.12, 0.48, { color = color, z = 36 })
	fx.update = function(t)
		local p = t / 40
		holder.Size = Canvas.size(s, 24 * (1 + p), 24 * (1 + p))
		for _, d in holder:GetChildren() do
			if d:IsA("Frame") then
				d.BackgroundTransparency = p
			end
		end
	end
end

local PLAYERS = {}

PLAYERS.splat = function(view, x, y, color)
	view.particles:burst(x, y, color, 120)
	local ring = Canvas.ring(view.layers.fx, view.space, x, y, 10, 10, 4, { color = color, z = 36 })
	local fx = newFx(view, 24, function(t)
		local p = t / 24
		ring.Size = Canvas.size(view.space, 20 + p * 80, 20 + p * 80)
		local st = ring:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = p
		end
	end)
	add(fx, ring)
	task.delay(0.12, function()
		if view.arena.Parent then
			splat(view, x, y, color, 1)
		end
	end)
end

PLAYERS.confetti = function(view, x, y, _color)
	for i = 1, 40 do
		local c = Color3.fromHSV((i * 37 % 360) / 360, 0.7, 1)
		view.particles:burst(
			x,
			y,
			c,
			1,
			{ speed = 4, up = 5, gravity = 0.15, decay = 0.02, square = true, spin = true, sizeMin = 2, sizeMax = 4 }
		)
	end
end

PLAYERS.feathers = function(view, x, y, color)
	local fx = newFx(view, 90, nil)
	local s = view.space
	local list = {}
	for i = 1, 16 do
		local f = add(
			fx,
			Canvas.ellipse(
				view.layers.fx,
				s,
				x,
				y,
				7,
				2.5,
				{ color = if i % 3 == 0 then color else WHITE, stroke = INK, strokeW = 0.8, z = 36 }
			)
		)
		table.insert(list, {
			f = f,
			vx = view.rng:NextNumber(-3, 3),
			vy = view.rng:NextNumber(-4, -1),
			rot = view.rng:NextNumber(0, 360),
			spin = view.rng:NextNumber(-6, 6),
			x = x,
			y = y,
		})
	end
	fx.update = function(t, frames)
		for _, p in list do
			p.vx *= 0.97 ^ frames
			p.vy = math.min(p.vy + 0.08 * frames, 1.2)
			p.x += (p.vx + math.sin(t / 8 + p.rot) * 0.6) * frames
			p.y += p.vy * frames
			p.rot += p.spin * frames
			p.f.Position = Canvas.pos(s, p.x, p.y)
			p.f.Rotation = p.rot
			p.f.BackgroundTransparency = math.max(0, (t - 50) / 40)
		end
	end
end

PLAYERS.scribble = function(view, x, y, color)
	splat(view, x, y, color, 0.6)
	local fx = newFx(view, 70, nil)
	local s = view.space
	local lines = {}
	for i = 1, 9 do
		local y0 = y - 18 + i * 4
		local l = add(fx, Canvas.line(view.layers.fx, s, x - 20, y0 + 6, x + 20, y0 - 6, 2.5, { color = INK, z = 37 }))
		l.Visible = false
		lines[i] = l
	end
	fx.update = function(t)
		for i, l in lines do
			l.Visible = t > i * 3
			l.BackgroundTransparency = math.max(0, (t - 45) / 25)
		end
	end
end

PLAYERS.eraser = function(view, x, y, color)
	local fx = newFx(view, 70, nil)
	local s = view.space
	local blob = add(fx, Canvas.circle(view.layers.fx, s, x, y, 15, { color = color, z = 35 }))
	local eraser = add(
		fx,
		Canvas.rect(
			view.layers.fx,
			s,
			x,
			y,
			26,
			14,
			{ color = Color3.fromHex("#ff9fb5"), stroke = INK, strokeW = 1.5, round = 3, z = 37 }
		)
	)
	add(
		fx,
		Canvas.rect(
			eraser,
			Canvas.space(0.5, 0.5, 1 / 26, 1 / 14),
			8,
			0,
			8,
			14,
			{ color = Color3.fromHex("#4a90e2"), z = 38 }
		)
	)
	fx.update = function(t)
		eraser.Position = Canvas.pos(s, x + math.sin(t * 0.6) * 16, y + math.cos(t * 0.3) * 4)
		eraser.Rotation = math.sin(t * 0.6) * 15
		blob.BackgroundTransparency = math.min(1, t / 50)
		if t % 4 == 0 and t < 55 then
			view.particles:burst(x, y + 6, Color3.fromHex("#ff9fb5"), 2, { speed = 1.5, up = 0, gravity = 0.25 })
		end
		eraser.BackgroundTransparency = math.max(0, (t - 55) / 15)
	end
end

PLAYERS.ghost = function(view, x, y, _color)
	local fx = newFx(view, 100, nil)
	local s = view.space
	local body = add(
		fx,
		Canvas.circle(view.layers.fx, s, x, y, 14, { color = WHITE, alpha = 0.8, stroke = INK, strokeW = 1.5, z = 37 })
	)
	local halo =
		add(fx, Canvas.ring(view.layers.fx, s, x, y - 20, 10, 3, 2.5, { color = Color3.fromHex("#ffd700"), z = 38 }))
	local eyes = {
		add(fx, Canvas.circle(view.layers.fx, s, x - 4, y - 2, 2, { color = INK, z = 38 })),
		add(fx, Canvas.circle(view.layers.fx, s, x + 4, y - 2, 2, { color = INK, z = 38 })),
	}
	fx.update = function(t)
		local yy = y - t * 1.2
		local xx = x + math.sin(t / 8) * 6
		local a = math.min(1, t / 100)
		body.Position = Canvas.pos(s, xx, yy)
		body.BackgroundTransparency = 0.2 + a * 0.8
		halo.Position = Canvas.pos(s, xx, yy - 20)
		eyes[1].Position = Canvas.pos(s, xx - 4, yy - 2)
		eyes[2].Position = Canvas.pos(s, xx + 4, yy - 2)
		for _, e in eyes do
			e.BackgroundTransparency = a
		end
		local st = halo:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = a
		end
	end
end

PLAYERS.balloon = function(view, x, y, color)
	local fx = newFx(view, 45, nil)
	local s = view.space
	local b = add(fx, Canvas.circle(view.layers.fx, s, x, y, 15, { color = color, stroke = INK, strokeW = 2, z = 37 }))
	fx.update = function(t)
		if t < 30 then
			local r = 15 + t * 0.8 + math.sin(t) * 1.5
			b.Size = Canvas.size(s, r * 2, r * 2)
		elseif not fx.popped then
			fx.popped = true
			b.Visible = false
			view.particles:ring(x, y, color, 18, 4, { decay = 0.04 })
			view.particles:burst(x, y, color, 30, { speed = 4 })
			view.shake = math.max(view.shake, 8)
		end
	end
end

PLAYERS.pixel = function(view, x, y, color)
	for gx = -2, 1 do
		for gy = -2, 1 do
			view.particles:burst(x + gx * 7 + 3.5, y + gy * 7 + 3.5, color, 1, {
				speed = 0.6,
				vx = gx * 1.2 + 0.6,
				vy = gy * 1.2 - 1.5,
				up = 0,
				gravity = 0.18,
				decay = 0.025,
				square = true,
				sizeMin = 3.5,
				sizeMax = 3.5,
			})
		end
	end
end

PLAYERS.paperplane = function(view, x, y, _color)
	local fx = newFx(view, 80, nil)
	local s = view.space
	local plane = add(fx, Canvas.tri(view.layers.fx, s, x, y, 30, 16, "right", { color = WHITE, z = 37 }))
	local trail = {}
	for i = 1, 8 do
		trail[i] = add(fx, Canvas.circle(view.layers.fx, s, x, y, 1.5, { color = INK, alpha = 0.5, z = 36 }))
		trail[i].Visible = false
	end
	fx.update = function(t)
		local px, py = x + t * 4, y - t * 3 + math.sin(t / 6) * 6
		plane.Position = Canvas.pos(s, px, py)
		for i, d in trail do
			local tt = t - i * 4
			if tt > 0 then
				d.Visible = true
				d.Position = Canvas.pos(s, x + tt * 4, y - tt * 3 + math.sin(tt / 6) * 6)
			end
		end
	end
end

PLAYERS.blackhole = function(view, x, y, color)
	local fx = newFx(view, 50, nil)
	local s = view.space
	local hole = add(fx, Canvas.circle(view.layers.fx, s, x, y, 4, { color = Color3.new(0, 0, 0), z = 37 }))
	local parts = {}
	for i = 1, 20 do
		local a = i / 20 * math.pi * 2
		local d = view.rng:NextNumber(20, 40)
		parts[i] = { f = add(fx, Canvas.circle(view.layers.fx, s, x, y, 2.5, { color = color, z = 36 })), a = a, d = d }
	end
	fx.update = function(t)
		local p = t / 50
		for _, q in parts do
			local d = q.d * (1 - p)
			local a = q.a + p * 6
			q.f.Position = Canvas.pos(s, x + math.cos(a) * d, y + math.sin(a) * d)
		end
		local r = if p < 0.7 then 4 + p * 14 else 14 * (1 - (p - 0.7) / 0.3)
		hole.Size = Canvas.size(s, r * 2, r * 2)
	end
end

PLAYERS.glitch = function(view, x, y, color)
	local fx = newFx(view, 45, nil)
	local s = view.space
	local copies = {
		add(fx, Canvas.circle(view.layers.fx, s, x, y, 15, { color = Color3.fromHex("#ff0055"), alpha = 0.6, z = 36 })),
		add(fx, Canvas.circle(view.layers.fx, s, x, y, 15, { color = Color3.fromHex("#00e5ff"), alpha = 0.6, z = 36 })),
		add(fx, Canvas.circle(view.layers.fx, s, x, y, 15, { color = color, z = 37 })),
	}
	fx.update = function(t)
		local p = t / 45
		for i, c in copies do
			c.Position = Canvas.pos(s, x + view.rng:NextNumber(-8, 8) * p * (i - 2), y + view.rng:NextNumber(-3, 3))
			c.Visible = view.rng:NextNumber() > p * 0.7
		end
	end
end

PLAYERS.melt = function(view, x, y, color)
	local fx = newFx(view, 70, nil)
	local s = view.space
	local blob = add(fx, Canvas.ellipse(view.layers.fx, s, x, y, 15, 15, { color = color, z = 36 }))
	local drips = {}
	for i = 1, 4 do
		drips[i] = {
			f = add(fx, Canvas.ellipse(view.layers.fx, s, x, y, 2.5, 5, { color = color, z = 36 })),
			dx = (i - 2.5) * 6,
			speed = view.rng:NextNumber(0.8, 1.6),
		}
	end
	fx.update = function(t)
		local p = t / 70
		blob.Size = Canvas.size(s, 30 + p * 16, 30 * (1 - p * 0.75))
		blob.Position = Canvas.pos(s, x, y + p * 12)
		for _, d in drips do
			d.f.Position = Canvas.pos(s, x + d.dx, y + 10 + t * d.speed)
		end
	end
	task.delay(1.1, function()
		if view.arena.Parent then
			splat(view, x, y + 14, color, 0.7)
		end
	end)
end

PLAYERS.stars = function(view, x, y, _color)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		view.particles:burst(x, y, Color3.fromHex("#ffd700"), 1, {
			speed = 0.2,
			up = 0,
			vx = math.cos(a) * 5,
			vy = math.sin(a) * 5,
			gravity = 0,
			decay = 0.03,
			square = true,
			spin = true,
			sizeMin = 4,
			sizeMax = 5,
		})
	end
	view.particles:burst(x, y, WHITE, 20, { speed = 2 })
end

PLAYERS.firework = function(view, x, y, color)
	local fx = newFx(view, 70, nil)
	local s = view.space
	local rocket =
		add(fx, Canvas.rect(view.layers.fx, s, x, y, 5, 12, { color = color, stroke = INK, strokeW = 1, z = 37 }))
	fx.update = function(t)
		if t < 28 then
			rocket.Position = Canvas.pos(s, x, y - t * 6)
			view.particles:burst(x, y - t * 6 + 8, Color3.fromHex("#ffb347"), 1, { speed = 0.6, up = -1, decay = 0.08 })
		elseif not fx.boom then
			fx.boom = true
			rocket.Visible = false
			local by = y - 28 * 6
			for i = 1, 3 do
				local c = Color3.fromHSV(((i * 120) + view.rng:NextNumber(0, 60)) / 360, 0.75, 1)
				view.particles:ring(x, by, c, 16, 2.5 + i * 1.3, { decay = 0.025, gravity = 0.04 })
			end
			view.shake = math.max(view.shake, 10)
		end
	end
end

PLAYERS.rubberduck = function(view, x, y, _color)
	local fx = newFx(view, 90, nil)
	local s = view.space
	local yellow = Color3.fromHex("#ffd700")
	local body = add(
		fx,
		Canvas.ellipse(view.layers.fx, s, x, y, 16, 11, { color = yellow, stroke = INK, strokeW = 1.5, z = 37 })
	)
	local head = add(
		fx,
		Canvas.circle(view.layers.fx, s, x + 8, y - 12, 8, { color = yellow, stroke = INK, strokeW = 1.5, z = 38 })
	)
	local beak = add(
		fx,
		Canvas.ellipse(view.layers.fx, s, x + 16, y - 11, 5, 2.5, { color = Color3.fromHex("#ff8c42"), z = 39 })
	)
	local eye = add(fx, Canvas.circle(view.layers.fx, s, x + 10, y - 14, 1.6, { color = INK, z = 39 }))
	local label = add(
		fx,
		Canvas.text(view.layers.fx, {
			text = "squeak!",
			position = Canvas.pos(s, x, y - 34),
			size = Canvas.size(s, 70, 16),
			font = Enum.Font.FredokaOne,
			color = INK,
			z = 40,
		})
	)
	fx.update = function(t)
		local bob = math.sin(t / 5) * 3
		local ox, oy = 0, bob - math.max(0, t - 60) * 0.5
		body.Position = Canvas.pos(s, x + ox, y + oy)
		head.Position = Canvas.pos(s, x + 8 + ox, y - 12 + oy)
		beak.Position = Canvas.pos(s, x + 16 + ox, y - 11 + oy)
		eye.Position = Canvas.pos(s, x + 10 + ox, y - 14 + oy)
		label.TextTransparency = math.max(0, (t - 50) / 40)
	end
end

function Deaths.play(view, id: string, x: number, y: number, color: Color3, _hat: string?, _bird)
	local fn = PLAYERS[id] or PLAYERS.splat
	fn(view, x, y, color)
end

function Deaths.step(view, frames: number)
	local list = view.deathAnims
	if not list then
		return
	end
	for i = #list, 1, -1 do
		local fx = list[i]
		fx.t += frames
		if fx.update then
			fx.update(math.floor(fx.t), frames)
		end
		if fx.t >= fx.duration then
			for _, f in fx.frames do
				f:Destroy()
			end
			table.remove(list, i)
		end
	end
end

-- Preview in menus: play the animation once inside an arbitrary view-like table
Deaths.PLAYERS = PLAYERS

return Deaths
