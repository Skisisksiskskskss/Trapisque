--[[
	Particles: pooled circles/squares for all the little bursts.

	Default motion is the original Particle class: random velocity, gravity
	0.2/frame, life 1 -> 0 at 0.05/frame (20 frames), size 2-5, alpha = life.
]]

local Canvas = require(script.Parent.Canvas)

local Particles = {}
Particles.__index = Particles

local MAX = 260

function Particles.new(layer: Instance, space)
	local self = setmetatable({}, Particles)
	self.layer = layer
	self.space = space
	self.live = {}
	self.pool = {}
	self.rng = Random.new()
	return self
end

function Particles:take(square: boolean): Frame
	local list = self.pool
	for i = #list, 1, -1 do
		local f = list[i]
		if (f:GetAttribute("square") == true) == square then
			table.remove(list, i)
			f.Visible = true
			return f
		end
	end
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = 40
	if not square then
		Canvas.corner(f)
	end
	f:SetAttribute("square", square)
	f.Parent = self.layer
	return f
end

--[[
	opts: speed (default 2 = original +-2), up (extra upward kick, default 2),
	      gravity (0.2), decay (0.05), size {min,max} (2..5), square, spin
]]
function Particles:burst(x: number, y: number, color: Color3, count: number, opts)
	opts = opts or {}
	local rng = self.rng
	local speed = opts.speed or 2
	local up = if opts.up ~= nil then opts.up else 2
	for _ = 1, count do
		if #self.live >= MAX then
			-- recycle the oldest
			local old = table.remove(self.live, 1)
			old.frame.Visible = false
			table.insert(self.pool, old.frame)
		end
		local square = opts.square == true
		local f = self:take(square)
		local size = rng:NextNumber(opts.sizeMin or 2, opts.sizeMax or 5)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0
		f.Size = Canvas.size(self.space, size * 2, size * 2)
		f.Rotation = if square then rng:NextNumber(0, 360) else 0
		table.insert(self.live, {
			frame = f,
			x = x,
			y = y,
			vx = rng:NextNumber(-speed, speed) + (opts.vx or 0),
			vy = rng:NextNumber(-speed, speed) - up + (opts.vy or 0),
			g = opts.gravity or 0.2,
			life = 1,
			decay = opts.decay or 0.05,
			spin = if opts.spin then rng:NextNumber(-12, 12) else 0,
			size = size,
			shrink = opts.shrink == true,
		})
	end
end

-- A ring of particles flying outward (strums, pops)
function Particles:ring(x: number, y: number, color: Color3, count: number, speed: number, opts)
	opts = opts or {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		self:burst(x, y, color, 1, {
			speed = 0.3,
			up = 0,
			vx = math.cos(a) * speed,
			vy = math.sin(a) * speed,
			gravity = opts.gravity or 0,
			decay = opts.decay or 0.04,
			sizeMin = opts.sizeMin or 2,
			sizeMax = opts.sizeMax or 4,
			square = opts.square,
		})
	end
end

-- frames = how many 60 Hz frames elapsed (1 normally)
function Particles:step(frames: number)
	local live = self.live
	local space = self.space
	for i = #live, 1, -1 do
		local p = live[i]
		p.x += p.vx * frames
		p.y += p.vy * frames
		p.vy += p.g * frames
		p.life -= p.decay * frames
		if p.life <= 0 then
			p.frame.Visible = false
			table.insert(self.pool, p.frame)
			table.remove(live, i)
		else
			local f = p.frame
			f.Position = Canvas.pos(space, p.x, p.y)
			f.BackgroundTransparency = 1 - p.life
			if p.spin ~= 0 then
				f.Rotation += p.spin * frames
			end
			if p.shrink then
				local s = p.size * 2 * p.life
				f.Size = Canvas.size(space, s, s)
			end
		end
	end
end

function Particles:clear()
	for _, p in self.live do
		p.frame.Visible = false
		table.insert(self.pool, p.frame)
	end
	table.clear(self.live)
end

return Particles
