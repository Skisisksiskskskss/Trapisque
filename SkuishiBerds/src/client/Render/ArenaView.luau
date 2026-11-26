--[[
	ArenaView: renders a World into a portrait arena frame.

	Layers (bottom -> top): paper+grid, event background, middle line, spikes,
	hazards, birds, effects, overlays, text. Everything is positioned in world
	units through Canvas spaces, so the arena scales to any screen.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EventMeta = require(Shared.Config.Events)
local Spikes = require(Shared.Sim.Spikes)
local Abilities = require(Shared.Sim.Abilities)
local Physics = require(Shared.Sim.Physics)

local Canvas = require(script.Parent.Canvas)
local Particles = require(script.Parent.Particles)
local BirdView = require(script.Parent.BirdView)
local Patterns = require(script.Parent.Patterns)
local EventViews = require(script.Parent.EventViews)
local Deaths = require(script.Parent.Deaths)

local W, H, MID = GameConfig.W, GameConfig.H, GameConfig.MID_X

local INK = Color3.fromHex("#222222")
local PAPER = Color3.fromHex("#fafafa")
local WHITE = Color3.new(1, 1, 1)

local ArenaView = {}
ArenaView.__index = ArenaView

local LINE_SEGMENTS = 40

local function layer(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

--[[
	holder: frame the arena should fit inside
	opts: { couch: boolean, showTopBanner: boolean, versus: boolean }
]]
function ArenaView.new(holder: Instance, opts)
	local self = setmetatable({}, ArenaView)
	self.opts = opts or {}
	self.space = Canvas.space(0, 0, 1 / W, 1 / H)

	local arena = Instance.new("Frame")
	arena.Name = "Arena"
	arena.AnchorPoint = Vector2.new(0.5, 0.5)
	arena.Position = UDim2.fromScale(0.5, 0.5)
	arena.Size = UDim2.fromScale(1, 1)
	arena.BackgroundColor3 = PAPER
	arena.BorderSizePixel = 0
	arena.ClipsDescendants = true
	arena.ZIndex = 1
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = W / H
	ar.Parent = arena
	Canvas.corner(arena, 0, 10)
	arena.Parent = holder
	self.arena = arena

	local function updatePpu()
		local px = arena.AbsoluteSize.X
		if px > 0 then
			Canvas.ppu = px / W
			self.ppu = Canvas.ppu
		end
	end
	updatePpu()
	arena:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePpu)

	-- the page itself (squashes during the REVERSE page flip)
	self.page = layer(arena, "Page", 1)
	self.layers = {
		bg = layer(self.page, "Background", 1),
		eventBack = layer(self.page, "EventBack", 2),
		line = layer(self.page, "Line", 5),
		spikes = layer(self.page, "Spikes", 8),
		hazards = layer(self.page, "Hazards", 12),
		birds = layer(self.page, "Birds", 20),
		fx = layer(self.page, "Fx", 30),
		overlay = layer(self.page, "Overlay", 40),
	}
	self.textLayer = layer(arena, "Text", 50)

	self.particles = Particles.new(self.layers.fx, self.space)
	self.birdViews = {}
	self.spikeViews = {}
	self.strums = {}
	self.bands = {}
	self.bends = {}
	self.eggs = {}
	self.eventView = nil
	self.eventId = nil
	self.shake = 0
	self.rng = Random.new()

	self:buildBackground()
	self:buildLine()
	self:buildText()
	return self
end

-- Background: paper, 30-unit graph grid, faint blue/red halves (original look)
function ArenaView:buildBackground()
	local bg = self.layers.bg
	local s = self.space
	for x = 0, W, 30 do
		Canvas.rect(bg, s, x, H / 2, 2, H, { color = Color3.new(0, 0, 0), alpha = 0.035, z = 1 })
	end
	for y = 0, H, 30 do
		Canvas.rect(bg, s, W / 2, y, W, 2, { color = Color3.new(0, 0, 0), alpha = 0.035, z = 1 })
	end
	Canvas.rect(bg, s, W / 2, H / 4, W, H / 2, { color = Color3.fromRGB(173, 216, 230), alpha = 0.07, z = 1 })
	Canvas.rect(bg, s, W / 2, H * 0.75, W, H / 2, { color = Color3.fromRGB(255, 99, 71), alpha = 0.05, z = 1 })
	-- soft wall glow strips
	for _, x in { 7.5, W - 7.5 } do
		local wall = Canvas.rect(bg, s, x, H / 2, 15, H, { color = WHITE, alpha = 0.3, z = 2 })
		local g = Instance.new("UIGradient")
		g.Rotation = if x < W / 2 then 0 else 180
		g.Transparency = NumberSequence.new(0.4, 0.85)
		g.Parent = wall
	end
end

function ArenaView:buildLine()
	self.lineSegs = {}
	for i = 1, LINE_SEGMENTS do
		local seg = Instance.new("Frame")
		seg.BorderSizePixel = 0
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.BackgroundColor3 = Color3.new(0, 0, 0)
		seg.BackgroundTransparency = 0.85
		seg.ZIndex = 5
		seg.Parent = self.layers.line
		self.lineSegs[i] = seg
	end
	self.lineStyle = "normal"
	self:layoutLine(0)
end

-- Middle line x offset at height y (strum wiggles, original drawMiddleLine)
function ArenaView:lineOffset(y: number, now: number): number
	local x = 0
	for _, b in self.bends do
		local dist = math.abs(y - b.y)
		local wrapped = math.min(dist, H - dist)
		x += b.dir * b.amount * math.max(0, 1 - wrapped / 150)
	end
	for _, st in self.strums do
		local dist = math.abs(y - st.y)
		local wrapped = math.min(dist, H - dist)
		local influence = math.max(0, 1 - wrapped / 200)
		if influence > 0 then
			x += math.sin(now * 1000 / 30 + y / 20 + st.phase) * 15 * influence * st.intensity
		end
	end
	return x
end

function ArenaView:layoutLine(now: number)
	local segH = H / LINE_SEGMENTS
	local dash = segH * 0.66
	for i, seg in self.lineSegs do
		local y0 = (i - 1) * segH
		local y1 = y0 + dash
		local x0 = MID + self:lineOffset(y0, now)
		local x1 = MID + self:lineOffset(y1, now)
		Canvas.setLine(seg, self.space, x0, y0, x1, y1, 2)
	end
end

function ArenaView:setLineStyle(style: string, color: Color3?)
	if style == self.lineStyle then
		return
	end
	self.lineStyle = style
	for _, seg in self.lineSegs do
		if style == "hidden" then
			seg.Visible = false
		else
			seg.Visible = true
			seg.BackgroundColor3 = color or Color3.new(0, 0, 0)
			seg.BackgroundTransparency = if style == "normal" then 0.85 else 0.35
		end
	end
end

function ArenaView:buildText()
	local t = self.textLayer
	self.scoreBottom = Canvas.text(t, {
		text = "0",
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.fromScale(0.6, 0.085),
		font = Enum.Font.FredokaOne,
		color = Color3.new(0, 0, 0),
		transparency = 0.7,
		strokeColor = WHITE,
		strokeThickness = 3,
		z = 51,
	})
	self.scoreTop = Canvas.text(t, {
		text = "0",
		position = UDim2.fromScale((MID - 25) / W, (H / 2 - 30) / H),
		size = UDim2.fromScale(0.6, 0.085),
		font = Enum.Font.FredokaOne,
		color = Color3.new(0, 0, 0),
		transparency = 0.7,
		strokeColor = WHITE,
		strokeThickness = 3,
		rot = 180,
		z = 51,
	})
	self.scoreTop.Visible = false
	self.bannerBottom = Canvas.text(t, {
		text = "",
		position = UDim2.fromScale(0.5, (H - 60) / H),
		size = UDim2.fromScale(0.95, 0.06),
		font = Enum.Font.FredokaOne,
		strokeColor = WHITE,
		strokeThickness = 3,
		z = 55,
	})
	self.bannerTop = Canvas.text(t, {
		text = "",
		position = UDim2.fromScale(0.5, 60 / H),
		size = UDim2.fromScale(0.95, 0.06),
		font = Enum.Font.FredokaOne,
		strokeColor = WHITE,
		strokeThickness = 3,
		rot = 180,
		z = 55,
	})
	self.center = Canvas.text(t, {
		text = "",
		position = UDim2.fromScale(0.5, 0.42),
		size = UDim2.fromScale(0.8, 0.14),
		font = Enum.Font.FredokaOne,
		color = WHITE,
		strokeColor = Color3.new(0, 0, 0),
		strokeThickness = 4,
		z = 60,
	})
	self.centerSub = Canvas.text(t, {
		text = "",
		position = UDim2.fromScale(0.5, 0.52),
		size = UDim2.fromScale(0.8, 0.045),
		font = Enum.Font.FredokaOne,
		color = WHITE,
		strokeColor = Color3.new(0, 0, 0),
		strokeThickness = 2,
		z = 60,
	})
end

-- Birds -----------------------------------------------------------------------------

function ArenaView:addBird(bird, loadout, opts)
	opts = opts or {}
	local view = BirdView.new(self.layers.birds, {
		space = self.space,
		loadout = loadout or {},
		seed = opts.seed or (bird.userId % 9973 + bird.slot),
		name = opts.name,
		z = 20 + bird.slot * 2,
	})
	local hearts = {}
	for i = 1, 3 do
		local hc = Instance.new("Frame")
		hc.BackgroundTransparency = 1
		hc.AnchorPoint = Vector2.new(0.5, 0.5)
		hc.Size = Canvas.size(self.space, 16, 16)
		hc.ZIndex = 45
		hc.Parent = self.layers.birds
		Patterns.heart(hc, 0, -0.15, 0.5, view.color, 1, 46)
		hearts[i] = { frame = hc, x = bird.x, y = bird.y }
	end
	self.birdViews[bird.slot] = {
		view = view,
		hearts = hearts,
		lifeRot = 0,
		strumBoost = 0,
		squishX = 1,
		squishY = 1,
		wingUntil = 0,
		color = view.color,
		gear = {},
		trail = {},
		lastFlapCount = bird.flapCount,
		deadShown = false,
	}
end

function ArenaView:removeBird(slot: number)
	local bv = self.birdViews[slot]
	if bv then
		bv.view:destroy()
		for _, h in bv.hearts do
			h.frame:Destroy()
		end
		for _, g in bv.gear do
			g:Destroy()
		end
		self.birdViews[slot] = nil
	end
end

function ArenaView:squish(slot: number, sx: number, sy: number)
	local bv = self.birdViews[slot]
	if bv then
		bv.squishX, bv.squishY = sx, sy
	end
end

function ArenaView:flapFx(bird)
	local bv = self.birdViews[bird.slot]
	if not bv then
		return
	end
	bv.squishX, bv.squishY = 1.8, 0.4
	bv.wingUntil = os.clock() + 0.2
	self.particles:burst(bird.x, bird.y, bv.color, 2)
end

function ArenaView:bounceFx(bird)
	local bv = self.birdViews[bird.slot]
	if not bv then
		return
	end
	bv.squishX, bv.squishY = 0.6, 1.3
	self.particles:burst(bird.x, bird.y, bv.color, 8)
end

-- small extra gear drawn around a bird (items / statuses)
local function gearPart(bv, key: string, parent: Instance, make: () -> GuiObject): GuiObject
	local g = bv.gear[key]
	if not g then
		g = make()
		g.Parent = parent
		bv.gear[key] = g
	end
	g.Visible = true
	return g
end

local function hideGear(bv, key: string)
	local g = bv.gear[key]
	if g then
		g.Visible = false
	end
end

function ArenaView:renderBird(world, bird, rx: number, ry: number, now: number, frames: number)
	local bv = self.birdViews[bird.slot]
	if not bv then
		return
	end
	local view = bv.view
	local tick = world.tick
	if bird.dead then
		view:setVisible(false)
		for _, h in bv.hearts do
			h.frame.Visible = false
		end
		for _, g in bv.gear do
			g.Visible = false
		end
		return
	end

	-- squish springs back (original: += (1 - s) * 0.2 per frame)
	local k = 1 - (0.8 ^ frames)
	bv.squishX += (1 - bv.squishX) * k
	bv.squishY += (1 - bv.squishY) * k
	local stretch = 1 + math.abs(bird.vy) * 0.02
	local sx = bv.squishX / math.sqrt(stretch)
	local sy = bv.squishY * stretch

	local ev = world:eventActive()
	local evName = ev and ev.name

	view:setPose({
		x = rx,
		y = ry,
		dir = bird.dir,
		upside = bird.upside,
		radius = bird.radius,
		squishX = sx,
		squishY = sy,
		wingUp = now < bv.wingUntil,
		now = now,
		bigWings = evName == "BIG_WINGS",
	})

	local abilityKind = Abilities.kind(bird)
	local trailing = evName == "ECHO_CHAMBER"
		or (tick < bird.abilityUntil and (abilityKind == "DASH" or abilityKind == "BLINK"))
	self:renderAfterimages(bv, bird, rx, ry, trailing)

	-- invulnerability blink (original: 50% alpha every 100 ms)
	local invuln = tick < bird.invulnUntil or tick < world.testPhaseUntil
	view:setVisible(not invuln or math.floor(now * 10) % 2 == 0)

	-- event tints
	if evName == "RAINBOW_MODE" then
		view:setBodyColor(Color3.fromHSV((now * 100 / 360) % 1, 0.6, 1))
	elseif evName == "COLOR_CHAOS" then
		view:setBodyColor(Color3.fromHSV(((now * 500 + rx) / 360) % 1, 0.8, 0.9))
	elseif evName == "BINARY_MODE" then
		local c = bv.color
		local lum = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
		view:setBodyColor(if lum > 0.5 then WHITE else Color3.new(0, 0, 0))
	elseif not view.rainbow then
		view:setBodyColor(nil)
	end
	view:setTransparency(if bird.ghost then 0.5 else 0)

	-- hearts orbit (lives - 1, max 3), original lifePositions with lag
	bv.lifeRot += 0.015 * frames + bv.strumBoost
	bv.strumBoost *= 0.85 ^ frames
	local showHearts = math.clamp(bird.lives - 1, 0, 3)
	for i, h in bv.hearts do
		if i <= showHearts then
			local a = ((i - 1) / 3) * math.pi * 2 + bv.lifeRot
			local tx = rx + math.cos(a) * (bird.radius + 8)
			local ty = ry + math.sin(a) * (bird.radius + 8)
			h.x += (tx - h.x) * math.min(1, 0.6 * frames)
			h.y += (ty - h.y) * math.min(1, 0.6 * frames)
			h.frame.Position = Canvas.pos(self.space, h.x, h.y)
			h.frame.Visible = view.root.Visible
		else
			h.frame.Visible = false
		end
	end

	-- status rings ---------------------------------------------------------------
	local s = self.space
	local layerB = self.layers.birds
	local r = bird.radius
	if bird.shielded then
		local g = gearPart(bv, "shield", layerB, function()
			local f = Canvas.ring(layerB, s, 0, 0, 1, 1, 3, { color = Color3.fromHex("#3498db"), z = 44 })
			return f
		end)
		g.Position = Canvas.pos(s, rx, ry)
		g.Size = Canvas.size(s, (r + 8) * 2, (r + 8) * 2)
	else
		hideGear(bv, "shield")
	end
	if evName == "BUBBLE_BOUNCE" then
		local g = gearPart(bv, "bubble", layerB, function()
			local f = Canvas.circle(layerB, s, 0, 0, 1, {
				color = Color3.fromHex("#74ebd5"),
				alpha = 0.18,
				stroke = Color3.fromHex("#74ebd5"),
				strokeW = 2,
				z = 43,
			})
			Canvas.circle(
				f,
				Canvas.space(0.5, 0.5, 0.5, 0.5),
				-0.45,
				-0.45,
				0.16,
				{ color = WHITE, alpha = 0.6, z = 44 }
			)
			return f
		end)
		g.Position = Canvas.pos(s, rx, ry)
		g.Size = Canvas.size(s, (r + 15) * 2, (r + 15) * 2)
	else
		hideGear(bv, "bubble")
	end
	if tick < bird.frozenUntil then
		local g = gearPart(bv, "frozen", layerB, function()
			return Canvas.circle(layerB, s, 0, 0, 1, { color = Color3.fromHex("#88d9ff"), alpha = 0.5, z = 44 })
		end)
		g.Position = Canvas.pos(s, rx, ry)
		g.Size = Canvas.size(s, r * 2.2, r * 2.2)
	else
		hideGear(bv, "frozen")
	end
	if tick < bird.hitGlowUntil then
		local g = gearPart(bv, "glow", layerB, function()
			return Canvas.circle(layerB, s, 0, 0, 1, { color = Color3.fromHex("#9b59b6"), alpha = 0.5, z = 19 })
		end)
		g.Position = Canvas.pos(s, rx, ry)
		g.Size = Canvas.size(s, (r + 14) * 2, (r + 14) * 2)
		g.BackgroundTransparency = 1 - 0.6 * (bird.hitGlowUntil - tick) / 30
	else
		hideGear(bv, "glow")
	end

	-- ability visuals
	local abilityOn = tick < bird.abilityUntil
	local kind = Abilities.kind(bird)
	if abilityOn and (kind == "PUFF" or kind == "PECK" or kind == "FOCUS" or kind == "DASH") then
		local colors = { PUFF = "#ffd166", PECK = "#e74c3c", FOCUS = "#9b59b6", DASH = "#84fab0" }
		local g = gearPart(bv, "ability", layerB, function()
			return Canvas.ring(layerB, s, 0, 0, 1, 1, 3, { color = WHITE, alpha = 0.9, z = 44 })
		end)
		local st = g:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = Color3.fromHex(colors[kind])
		end
		g.Position = Canvas.pos(s, rx, ry)
		local pulse = 1 + math.sin(now * 12) * 0.08
		g.Size = Canvas.size(s, (r + 6) * 2 * pulse, (r + 6) * 2 * pulse)
	else
		hideGear(bv, "ability")
	end
	if abilityOn and kind == "PECK" and bird.pecking == false then
		hideGear(bv, "ability")
	end

	-- items (drawn toward the bird's "down" side)
	local down = if bird.upside then -1 else 1
	if bird.rocketBoots then
		local g = gearPart(bv, "boots", layerB, function()
			local f = Canvas.rect(
				layerB,
				s,
				0,
				0,
				16,
				7,
				{ color = Color3.fromHex("#c0392b"), stroke = INK, strokeW = 1, round = 2, z = 42 }
			)
			return f
		end)
		g.Position = Canvas.pos(s, rx, ry + down * (r + 2))
		if bird.thrusting then
			local fl = gearPart(bv, "flame", layerB, function()
				return Canvas.diamond(layerB, s, 0, 0, 6, { color = Color3.fromHex("#ff8c42"), z = 41 })
			end)
			local flick = 1 + math.sin(now * 40) * 0.25
			fl.Position = Canvas.pos(s, rx, ry + down * (r + 10))
			fl.Size = Canvas.size(s, 8 * flick, 8 * flick)
			if self.rng:NextNumber() < 0.5 then
				self.particles:burst(
					rx,
					ry + down * (r + 12),
					Color3.fromHex("#ffb347"),
					1,
					{ speed = 0.8, up = -2 * down, decay = 0.08 }
				)
			end
		else
			hideGear(bv, "flame")
		end
	else
		hideGear(bv, "boots")
		hideGear(bv, "flame")
	end
	if bird.speedBoots then
		local g = gearPart(bv, "sboots", layerB, function()
			return Canvas.rect(
				layerB,
				s,
				0,
				0,
				14,
				5,
				{ color = Color3.fromHex("#ffd166"), stroke = INK, strokeW = 1, round = 2, z = 42 }
			)
		end)
		g.Position = Canvas.pos(s, rx - bird.dir * 2, ry + down * (r + 1))
		if tick < bird.dashFlashUntil then
			self.particles:burst(
				rx - bird.dir * 8,
				ry,
				Color3.fromHex("#ffd86b"),
				1,
				{ speed = 0.5, up = 0, vx = -bird.dir * 2 }
			)
		end
	else
		hideGear(bv, "sboots")
	end
	if bird.hoverDrone then
		local g = gearPart(bv, "drone", layerB, function()
			local f = Canvas.rect(
				layerB,
				s,
				0,
				0,
				14,
				5,
				{ color = Color3.fromHex("#7f8c8d"), stroke = INK, strokeW = 1, round = 2, z = 42 }
			)
			local rotor = Canvas.rect(f, Canvas.space(0.5, 0.5, 1 / 14, 1 / 5), 0, -4, 20, 1.5, { color = INK, z = 43 })
			rotor.Name = "Rotor"
			return f
		end)
		g.Position = Canvas.pos(s, rx, ry - down * (r + 9))
		local rotor = g:FindFirstChild("Rotor")
		if rotor then
			rotor.Size = UDim2.fromScale(math.abs(math.sin(now * 30)) * 1.4 + 0.1, 0.3)
		end
	else
		hideGear(bv, "drone")
	end
	if bird.gravityShoe then
		local g = gearPart(bv, "gshoe", layerB, function()
			return Canvas.rect(
				layerB,
				s,
				0,
				0,
				14,
				6,
				{ color = Color3.fromHex("#b28cff"), stroke = INK, strokeW = 1, round = 2, z = 42 }
			)
		end)
		g.Position = Canvas.pos(s, rx, ry + down * (r + 2))
	else
		hideGear(bv, "gshoe")
	end
	if bird.gun then
		local g = gearPart(bv, "gun", layerB, function()
			return Canvas.rect(
				layerB,
				s,
				0,
				0,
				12,
				6,
				{ color = Color3.fromHex("#7f8c8d"), stroke = INK, strokeW = 1, round = 1, z = 42 }
			)
		end)
		g.Position = Canvas.pos(s, rx + bird.dir * (r + 4), ry - r * 0.35 * down)
	else
		hideGear(bv, "gun")
	end
	if bird.drill then
		local g = gearPart(bv, "drill", layerB, function()
			return Canvas.diamond(
				layerB,
				s,
				0,
				0,
				9,
				{ color = Color3.fromHex("#c9c9c9"), stroke = INK, strokeW = 1, z = 42 }
			)
		end)
		g.Position = Canvas.pos(s, rx + bird.dir * (r + 6), ry)
		g.Rotation = 45 + (now * 900) % 90
	else
		hideGear(bv, "drill")
	end
end

-- Spikes ----------------------------------------------------------------------------

function ArenaView:spikeColor(world, spike): (Color3, Color3)
	if spike.owner ~= 0 and world.mode.versus then
		local bv = self.birdViews[spike.owner]
		if bv then
			return bv.color, Canvas.shade(bv.color, -110)
		end
	end
	if spike.merged then
		return Color3.fromHex("#e91e63"), INK
	end
	return Color3.fromHex("#cccccc"), INK
end

function ArenaView:ensureSpike(world, spike)
	local sv = self.spikeViews[spike.id]
	if sv and sv.spike == spike then
		return sv
	end
	if sv then
		sv.frame:Destroy()
		for _, z in sv.zap do
			z:Destroy()
		end
	end
	local fill, stroke = self:spikeColor(world, spike)
	local f =
		Canvas.diamond(self.layers.spikes, self.space, 0, 0, 1, { color = fill, stroke = stroke, strokeW = 2, z = 9 })
	local zap = {}
	for i = 1, 10 do
		local seg = Instance.new("Frame")
		seg.BorderSizePixel = 0
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.ZIndex = 10
		seg.Visible = false
		seg.Parent = self.layers.spikes
		zap[i] = seg
	end
	sv = { frame = f, zap = zap, spike = spike, fill = fill, legs = nil }
	self.spikeViews[spike.id] = sv
	return sv
end

function ArenaView:renderSpikes(world, now: number)
	local tick = world.tick
	local seen = {}
	local space = self.space
	for _, spike in world.spikes do
		seen[spike.id] = true
		local sv = self:ensureSpike(world, spike)
		local f = sv.frame
		local y = Spikes.yAt(spike, tick)
		local solidAt = spike.spawnTick + spike.zapTicks
		local wallX = if spike.side < 0 then 0 else W
		local d = spike.size * 1.4

		if tick < solidAt then
			-- invisible + harmless while the zap flies toward the wall
			f.Visible = false
			local progress = math.clamp((tick - spike.spawnTick) / math.max(1, spike.zapTicks), 0, 1)
			local tipX = Spikes.tipX(spike)
			local x0, y0 = spike.zapFromX, spike.zapFromY
			local zapColor = if spike.side < 0 then Color3.fromHex("#bae1ff") else Color3.fromHex("#ffb3ba")
			if spike.owner ~= 0 and world.mode.versus then
				zapColor = sv.fill
			end
			local wave = 30 * (1 - progress)
			local px, py = x0, y0
			for i, seg in sv.zap do
				local t = i / #sv.zap
				if t <= progress then
					local nx = x0 + (tipX - x0) * t + self.rng:NextNumber(-1, 1)
					local ny = y0 + (y - y0) * t + math.sin(t * math.pi * 15 + now * 50) * wave * (1 - t * 0.5)
					Canvas.setLine(seg, space, px, py, nx, ny, 2 + (1 - progress) * 3)
					seg.BackgroundColor3 = zapColor
					seg.Visible = true
					px, py = nx, ny
				else
					seg.Visible = false
				end
			end
		else
			for _, seg in sv.zap do
				seg.Visible = false
			end
			f.Visible = true
			f.Position = Canvas.pos(space, wallX, y)
			f.Size = Canvas.size(space, d * math.sqrt(2), d * math.sqrt(2))
			f.Rotation = 45 + math.deg(Spikes.angleAt(spike, tick))
			local alpha = Spikes.opacityAt(spike, tick)
			-- hologram solidify phase (light blue, fading in)
			local holo = math.clamp((tick - solidAt) / GameConfig.SPIKE_SOLIDIFY_TICKS, 0, 1)
			if holo < 1 then
				f.BackgroundColor3 = Color3.fromHex("#bae1ff")
				f.BackgroundTransparency = 1 - holo * 0.6
			else
				f.BackgroundColor3 = sv.fill
				f.BackgroundTransparency = 1 - alpha
			end
			local st = f:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 1 - alpha
			end
			-- walking legs
			if spike.walkVy and spike.walkStart and tick < (spike.walkEnd or 0) + 30 then
				if not sv.legs then
					sv.legs = {}
					for i = 1, 2 do
						local leg = Instance.new("Frame")
						leg.BorderSizePixel = 0
						leg.AnchorPoint = Vector2.new(0.5, 0.5)
						leg.BackgroundColor3 = Color3.fromHex("#666666")
						leg.ZIndex = 9
						leg.Parent = self.layers.spikes
						sv.legs[i] = leg
					end
				end
				local walking = tick < (spike.walkEnd or 0)
				local legLen = if walking then 8 else 8 * math.max(0, 1 - (tick - (spike.walkEnd or 0)) / 30)
				local phase = tick * 0.15
				for i, leg in sv.legs do
					local lx = if spike.side < 0
						then spike.size * (0.4 + 0.5 * (i - 1))
						else W - spike.size * (0.4 + 0.5 * (i - 1))
					local swing = math.sin(phase + (i - 1) * math.pi) * 0.4
					Canvas.setLine(leg, space, lx, y + d * 0.7, lx + math.sin(swing) * 6, y + d * 0.7 + legLen, 2)
					leg.Visible = legLen > 0.5
				end
			elseif sv.legs then
				for _, leg in sv.legs do
					leg.Visible = false
				end
			end
		end
	end
	for id, sv in self.spikeViews do
		if not seen[id] then
			sv.frame:Destroy()
			for _, z in sv.zap do
				z:Destroy()
			end
			if sv.legs then
				for _, leg in sv.legs do
					leg:Destroy()
				end
			end
			self.spikeViews[id] = nil
		end
	end
end

function ArenaView:shatterSpike(spike, tick: number)
	local y = Spikes.yAt(spike, tick)
	self.particles:burst(Spikes.tipX(spike), y, Color3.fromHex("#3498db"), 14, { square = true, spin = true })
end

-- Strums ------------------------------------------------------------------------------

function ArenaView:strumFx(y: number, hueBase: number, color: Color3?)
	table.insert(self.strums, { y = y, intensity = 1, phase = self.rng:NextNumber(0, math.pi * 2) })
	if #self.strums > 6 then
		table.remove(self.strums, 1)
	end
	-- colored waves spreading along the line (original drawStrumEffect)
	local band = { y = y, t = 0, hue = hueBase, frames = {} }
	for dir = -1, 1, 2 do
		for wave = 0, 2 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.ZIndex = 6
			f.BackgroundColor3 = Canvas.hsl(hueBase + wave * 20, 0.7, 0.6)
			Canvas.corner(f)
			f.Parent = self.layers.line
			table.insert(band.frames, { frame = f, dir = dir, wave = wave })
		end
	end
	table.insert(self.bands, band)
	self.particles:ring(MID, y, color or Color3.fromRGB(100, 150, 255), 8, 2.2, { decay = 0.06 })
end

-- BOUNCY: the line bends where a bird bounced off it
function ArenaView:addBend(y: number, dir: number)
	table.insert(self.bends, { y = y, dir = dir, amount = 60 })
	self.particles:burst(MID, y, Color3.fromHex("#55efc4"), 12)
end

function ArenaView:updateStrums(frames: number, now: number)
	local active = false
	for i = #self.bends, 1, -1 do
		local b = self.bends[i]
		b.amount *= 0.85 ^ frames
		if b.amount < 1 then
			table.remove(self.bends, i)
		else
			active = true
		end
	end
	for i = #self.strums, 1, -1 do
		local st = self.strums[i]
		st.intensity -= (16 / 300) * frames
		if st.intensity <= 0 then
			table.remove(self.strums, i)
		else
			active = true
		end
	end
	if active or self.lineWasActive then
		self:layoutLine(now)
	end
	self.lineWasActive = active

	for i = #self.bands, 1, -1 do
		local b = self.bands[i]
		b.t += (16 / 300) * frames
		local intensity = 1 - b.t
		if intensity <= 0 then
			for _, e in b.frames do
				e.frame:Destroy()
			end
			table.remove(self.bands, i)
		else
			local dist = (1 - intensity) * 240
			for _, e in b.frames do
				local yy = b.y + e.dir * (dist + e.wave * 60)
				if yy < 0 then
					yy += H
				elseif yy > H then
					yy -= H
				end
				e.frame.Position = Canvas.pos(self.space, MID + math.cos(now * 20 + e.wave) * 8 * intensity, yy)
				e.frame.Size = Canvas.size(self.space, 6 - e.wave * 2 + 2, 80)
				e.frame.BackgroundTransparency = 1 - intensity * (1 - e.wave * 0.3) * 0.8
			end
		end
	end
end

-- Text --------------------------------------------------------------------------------

function ArenaView:setScore(text: string, coopTwin: boolean)
	self.scoreBottom.Text = text
	self.scoreTop.Text = text
	self.scoreTop.Visible = coopTwin
	if coopTwin then
		self.scoreBottom.Position = UDim2.fromScale((MID + 25) / W, (H / 2 + 30) / H)
	else
		self.scoreBottom.Position = UDim2.fromScale(0.5, 0.5)
	end
end

function ArenaView:setBanner(text: string, color: Color3?, alpha: number, flippedTwin: boolean)
	for _, label in { self.bannerBottom, self.bannerTop } do
		label.Text = text
		label.TextColor3 = color or INK
		label.TextTransparency = 1 - alpha
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = 1 - alpha
		end
	end
	self.bannerTop.Visible = flippedTwin and text ~= ""
	self.bannerBottom.Visible = text ~= ""
	if not flippedTwin then
		-- single-player: show it near the top where thumbs don't cover it
		self.bannerBottom.Position = UDim2.fromScale(0.5, 70 / H)
	else
		self.bannerBottom.Position = UDim2.fromScale(0.5, (H - 60) / H)
	end
end

function ArenaView:setCenter(text: string, sub: string?, scale: number?)
	self.center.Text = text
	self.centerSub.Text = sub or ""
	local s = scale or 1
	self.center.Size = UDim2.fromScale(0.8 * s, 0.14 * s)
end

-- Events --------------------------------------------------------------------------------

function ArenaView:syncEventView(world, now: number, frames: number)
	local ev = world:eventActive()
	local id = ev and ev.id
	if id ~= self.eventId then
		if self.eventView then
			self.eventView:destroy()
			self.eventView = nil
		end
		self.eventId = id
		self:setLineStyle("normal")
		if ev then
			self.eventView = EventViews.create(self, world, ev)
		end
	end
	if self.eventView then
		self.eventView:update(world, ev, now, frames)
	end
end

-- Deaths --------------------------------------------------------------------------------

function ArenaView:deathFx(bird, deathId: string?, hat: string?)
	local bv = self.birdViews[bird.slot]
	local color = if bv then bv.color else WHITE
	self.shake = math.max(self.shake, 15)
	Deaths.play(self, deathId or "splat", bird.x, bird.y, color, hat, bird)
end

function ArenaView:hurtFx(bird)
	local bv = self.birdViews[bird.slot]
	local color = if bv then bv.color else WHITE
	Deaths.heartSplat(self, bird.x, bird.y, color)
	self.particles:burst(bird.x, bird.y, color, 30)
end

-- Frame -------------------------------------------------------------------------------

--[[
	positions: { [slot] = {x, y} } render positions (interpolated)
	frames: elapsed time in 60 fps frames
]]
function ArenaView:render(world, positions, now: number, frames: number)
	-- page flip (REVERSE_CONTROLS): squash to a line, mirror, expand back
	local flip = world.flip
	local scaleX = 1
	if flip.active then
		scaleX = math.abs(math.cos(flip.progress * math.pi / 2))
	elseif flip.doneTick >= 0 and world.tick - flip.doneTick < 13 then
		scaleX = math.sin(((world.tick - flip.doneTick) / 13) * math.pi / 2)
	end
	scaleX = math.max(0.02, scaleX)
	local pageSize = UDim2.fromScale(scaleX, 1)
	if self.page.Size ~= pageSize then
		self.page.Size = pageSize
	end

	-- screen shake (can be turned off in Settings)
	if self.noShake then
		self.shake = 0
	end
	if self.shake > 0.1 then
		self.shake *= 0.9 ^ frames
		local ppu = self.ppu or 1
		self.page.Position = UDim2.new(
			0.5,
			self.rng:NextNumber(-0.5, 0.5) * self.shake * ppu,
			0.5,
			self.rng:NextNumber(-0.5, 0.5) * self.shake * ppu
		)
	elseif self.page.Position ~= UDim2.fromScale(0.5, 0.5) then
		self.shake = 0
		self.page.Position = UDim2.fromScale(0.5, 0.5)
	end

	self:syncEventView(world, now, frames)
	self:updateStrums(frames, now)
	self:renderSpikes(world, now)
	for _, bird in world.birdList do
		local p = positions[bird.slot]
		self:renderBird(world, bird, if p then p[1] else bird.x, if p then p[2] else bird.y, now, frames)
	end
	self:renderEggs(world)
	self.particles:step(frames)
	Deaths.step(self, frames)

	-- Hoot's Focus: flight-path preview for your own bird
	self:renderFocusPath(world)
end

-- BLASTERS eggs in flight
function ArenaView:renderEggs(world)
	local list = world.bullets or {}
	for i, b in list do
		local egg = self.eggs[i]
		if not egg then
			egg = Canvas.ellipse(self.layers.fx, self.space, 0, 0, 4.5, 3.4, {
				color = Color3.fromHex("#fff8e7"),
				stroke = INK,
				strokeW = 1,
				z = 33,
			})
			self.eggs[i] = egg
		end
		egg.Visible = true
		egg.Position = Canvas.pos(self.space, b.x, b.y)
	end
	for i = #list + 1, #self.eggs do
		self.eggs[i].Visible = false
	end
end

-- Afterimages: ECHO CHAMBER on everyone, Dash/Blink on the bird using it
function ArenaView:renderAfterimages(bv, bird, rx: number, ry: number, on: boolean)
	bv.echo = bv.echo or {}
	bv.echoHist = bv.echoHist or {}
	if on then
		table.insert(bv.echoHist, 1, { rx, ry })
		if #bv.echoHist > 12 then
			table.remove(bv.echoHist)
		end
	else
		table.clear(bv.echoHist)
	end
	for i = 1, 6 do
		local f = bv.echo[i]
		local h = bv.echoHist[i * 2]
		if h then
			if not f then
				f = Canvas.circle(self.layers.birds, self.space, 0, 0, 1, { color = bv.color, z = 19 })
				bv.echo[i] = f
			end
			f.Visible = true
			f.Position = Canvas.pos(self.space, h[1], h[2])
			f.Size = Canvas.size(self.space, bird.radius * 2, bird.radius * 2)
			f.BackgroundTransparency = 0.55 + i * 0.07
		elseif f then
			f.Visible = false
		end
	end
end

function ArenaView:renderFocusPath(world)
	local shown = 0
	for _, bird in world.birdList do
		if bird.sim and not bird.dead and world.tick < bird.abilityUntil and Abilities.kind(bird) == "FOCUS" then
			local pts = Physics.predictPath(world, bird, 60, 4)
			self.pathDots = self.pathDots or {}
			for i, p in pts do
				local dotF = self.pathDots[i]
				if not dotF then
					dotF = Canvas.circle(
						self.layers.fx,
						self.space,
						0,
						0,
						2.5,
						{ color = Color3.fromHex("#9b59b6"), alpha = 0.7, z = 35 }
					)
					self.pathDots[i] = dotF
				end
				dotF.Position = Canvas.pos(self.space, p[1], p[2])
				dotF.Visible = true
				shown = i
			end
		end
	end
	if self.pathDots then
		for i = shown + 1, #self.pathDots do
			self.pathDots[i].Visible = false
		end
	end
end

function ArenaView:destroy()
	if self.eventView then
		self.eventView:destroy()
	end
	self.arena:Destroy()
end

-- Expose for EventViews
ArenaView.W = W
ArenaView.H = H
ArenaView.EventMeta = EventMeta

return ArenaView
