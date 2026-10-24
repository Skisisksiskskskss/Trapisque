--[[
	FishingRod
	Fishing between turns (Shared/Meta/Fishing): a round pool in the board's corner while
	someone else is playing. Tap it to cast: the bobber floats and a fish's shadow (how big
	it is) circles under it. It nibbles (leave it), then bites with a splash ("Hook it!"):
	tap fast to hook it. Then it fights: a meter rises over the pool, its needle sweeping
	to and fro; tap whenever the needle is over the green (it moves after each one) until
	the fish is reeled in. Three taps off the green and the line snaps. What you land
	rises out of the water with its size (a new fish for your log, a record, a reward for
	filling the log, now and then a gold coin for this match, or an old boot). Put away on
	your turn. The pool, rod, bobber and splash are art/fishing.py's, the fish art/fish.py's;
	without the art they're drawn from shapes.

		local rod = FishingRod.new(parent, { onCaught = fn(catchId, new) })
		rod:layout(rect)
		rod:setAllowed(boolean)        -- someone else's turn, and you're playing
		rod:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fishing = require(ReplicatedStorage.Shared.Meta.Fishing)
local Cosmetics = require(ReplicatedStorage.Shared.Meta.Cosmetics)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local FishArt = require(UI.FishArt)
local Art = require(UI.Art)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)

local C = Theme.C

local FishingRod = {}
FishingRod.__index = FishingRod

-- how wide the fish's shadow is in the pool, by how big it is
local SHADOW_SIZE = { small = 0.42, medium = 0.58, large = 0.76 }
local FIGHT_W, FIGHT_H = 236, 70

-- A sprite filling `props`, or nil without the art.
local function sprite(parent: Instance, name: string, props: { [string]: any }): Frame?
	if not Art.has(name) then
		return nil
	end
	return Art.image(parent, name, props)
end

function FishingRod.new(parent: Instance, opts: { [string]: any }?)
	local self = setmetatable({}, FishingRod)
	self.opts = opts or {}
	self.state = "idle"
	self.allowed = false
	self.maid = Util.maid()
	local root = Util.frame(parent, { Name = "Fishing", ZIndex = 30, Visible = false })
	self.root = root
	local button = Util.new("TextButton", {
		Name = "Rod",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Selectable = true,
		Parent = root,
	})
	Util.corner(button, 0.5)
	self.rim = Util.stroke(button, C.line, 3)
	self.button = button
	-- the pool the bobber floats in
	local water = Util.new("Frame", {
		Name = "Water",
		BackgroundColor3 = C.sky,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = button,
	})
	Util.corner(water, 0.5)
	if sprite(water, "fishing/water", { Name = "Pool", ZIndex = 31 }) then
		water.BackgroundTransparency = 1
	end
	self.water = water
	-- the fish's shadow under the surface: how big it is (shown once the line is in)
	local shadow = Util.frame(water, {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.42, 0.42),
		ZIndex = 32,
		Visible = false,
	})
	if Art.has("fish/sardine") then
		FishArt.image(shadow, "sardine", { Size = UDim2.fromScale(1, 1), ZIndex = 32 }, true)
	else
		local blob = Util.new("Frame", {
			BackgroundColor3 = C.bgDeep,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.5),
			ZIndex = 32,
			Parent = shadow,
		})
		Util.corner(blob, 0.5)
	end
	self.shadow = shadow
	-- the rod, while the line's out of the water
	self.icon = sprite(water, "fishing/rod", {
		Name = "RodArt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		ZIndex = 33,
	}) or Icons.make(water, "rod", Icons.flatColors(C.textLight, C.sky), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 32,
	})
	-- the bobber
	local bobber = Util.frame(water, {
		Name = "Bobber",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 34,
		Visible = false,
	})
	if not sprite(bobber, "fishing/bobber", { Name = "Float", ZIndex = 34 }) then
		local ball = Util.new("Frame", {
			Name = "Float",
			BackgroundColor3 = C.coral,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.55, 0.55),
			ZIndex = 34,
			Parent = bobber,
		})
		Util.corner(ball, 0.5)
		Util.stroke(ball, C.line, 2)
		local cap = Util.new("Frame", {
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.45, 0),
			ZIndex = 35,
			Parent = ball,
		})
		Util.corner(cap, 0.5)
	end
	self.bobber = bobber
	-- the splash when it bites
	self.splash = sprite(water, "fishing/splash", {
		Name = "Splash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.9, 0.9),
		ZIndex = 35,
		Visible = false,
	})
	self.tag = Widgets.label(root, {
		text = "Fish",
		font = "chunky",
		size = 13,
		color = C.textLight,
		outline = C.ink,
		align = "center",
		anchor = Vector2.new(0.5, 0),
		sizeUDim = UDim2.new(1.6, 0, 0, 16),
		position = UDim2.new(0.5, 0, 1, 2),
		z = 35,
	})
	button.Activated:Connect(function()
		self:_tap()
	end)
	self.maid:add(Net.on("fish.state", function(data)
		if type(data) ~= "table" then
			return
		end
		if data.state == "nibble" and self.state == "cast" then
			-- a little dip: not yet!
			self.nibbleAt = os.clock()
			self:_ripple()
			Sound.play("click", 1.5)
		elseif data.state == "bite" and self.state == "cast" then
			self:_set("bite")
			Sound.play("splash", 1.4)
		elseif data.state == "idle" and self.state ~= "idle" then
			self:_set("idle")
			if data.reason == "late" or data.reason == "snapped" then
				self:_say("It got away!", C.textFaint)
			end
		end
	end))
	-- the bobber bobs (and dips hard on a bite), the shadow circles, rings spread
	local t, nextRing = 0, 0
	self.maid:add(RunService.RenderStepped:Connect(function(dt)
		if not root.Visible then
			return
		end
		t += dt
		if self.state == "cast" then
			local nibble = self.nibbleAt and os.clock() - self.nibbleAt < 0.25
			bobber.Position = UDim2.fromScale(0.5, (if nibble then 0.58 else 0.5) + math.sin(t * 3) * 0.04)
			shadow.Position = UDim2.fromScale(0.5 + math.sin(t * 0.9) * 0.14, 0.6 + math.cos(t * 0.9) * 0.08)
			shadow.Rotation = math.cos(t * 0.9) * 14
			if t > nextRing then
				nextRing = t + 1.6
				self:_ripple()
			end
		elseif self.state == "bite" then
			bobber.Position = UDim2.fromScale(0.5 + math.sin(t * 40) * 0.04, 0.64)
		end
		if self.state == "fight" then
			self:_stepFight()
		end
	end))
	return self
end

-- A ring spreading on the water round the bobber.
function FishingRod:_ripple()
	local w = self.water
	local size = w.AbsoluteSize.X
	if size <= 0 then
		return
	end
	local ring = Art.label(w, "fishing/ripple", Vector2.new(size * 0.5, size * 0.56), size * 0.3, false, {
		Name = "Ripple",
		ZIndex = 33,
		ImageTransparency = 0.1,
	})
	if not ring then
		return
	end
	local img = ring :: ImageLabel
	Util.tween(img, 1.1, { Size = UDim2.fromOffset(size * 0.9, size * 0.41), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(1.15, function()
		img:Destroy()
	end)
end

function FishingRod:_set(state: string, shadow: string?)
	self.state = state
	if state == "cast" then
		local w = SHADOW_SIZE[shadow or "small"] or SHADOW_SIZE.small
		self.shadow.Size = UDim2.fromScale(w, w)
		self.nibbleAt = nil
	end
	if state ~= "fight" then
		self:_endFight()
	end
	self.shadow.Visible = state == "cast" or state == "bite"
	self.bobber.Visible = state == "cast" or state == "bite"
	self.icon.Visible = state == "idle"
	if self.splash then
		self.splash.Visible = state == "bite"
		if state == "bite" then
			Util.popIn(self.splash, 0.25, 0.3)
		end
	end
	self.tag.Text = if state == "idle" then "Fish" elseif state == "cast" then "Wait..." elseif state == "bite" then "Hook it!" else "Reel!"
	self.tag.TextColor3 = if state == "bite" or state == "fight" then C.sun else C.textLight
	self.rim.Color = if state == "bite" or state == "fight" then C.sun else C.line
	self.rim.Thickness = if state == "bite" then 5 else 3
	if state == "bite" then
		Util.bump(self.button, 0.12)
	end
end

function FishingRod:_say(text: string, color: Color3)
	local label = Widgets.label(self.root, {
		text = text,
		font = "chunky",
		size = 16,
		color = color,
		outline = C.ink,
		align = "right",
		anchor = Vector2.new(1, 1),
		sizeUDim = UDim2.fromOffset(260, 20),
		position = UDim2.new(1, 0, 0, -6),
		z = 40,
	})
	Util.popIn(label, 0.25, 0.6)
	task.delay(1.6, function()
		label:Destroy()
	end)
end

---------------------------------------------------------------------------
-- the fight
---------------------------------------------------------------------------

-- Somewhere new for the green: on the meter, and away from where it was.
local function placeZone(zone: number, old: number?): number
	local lo, hi = zone / 2 + 0.04, 1 - zone / 2 - 0.04
	local at = lo + math.random() * (hi - lo)
	if old then
		for _ = 1, 6 do
			if math.abs(at - old) >= 0.28 then
				break
			end
			at = lo + math.random() * (hi - lo)
		end
	end
	return at
end

function FishingRod:_startFight(spec)
	self:_endFight()
	local fight = {
		spec = spec,
		reels = 0,
		slips = 0,
		t0 = os.clock(),
		zoneAt = placeZone(spec.zone, nil),
		busy = false,
	}
	self.fight = fight
	local panel = Util.new("TextButton", {
		Name = "Fight",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -10),
		Size = UDim2.fromOffset(FIGHT_W, FIGHT_H),
		ZIndex = 40,
		Parent = self.root,
	})
	Util.corner(panel, 12)
	Util.stroke(panel, C.sun, 3)
	panel.Activated:Connect(function()
		self:_tap()
	end)
	Widgets.label(panel, {
		text = "Tap on the green!",
		font = "chunky",
		size = 14,
		color = C.text,
		align = "left",
		sizeUDim = UDim2.fromOffset(FIGHT_W - 20 - spec.reels * 16, 18),
		position = UDim2.fromOffset(10, 6),
		z = 41,
	})
	-- the notches still to reel (filled as they're won) and the slips left
	local dots = {}
	for i = 1, spec.reels do
		local d = Util.new("Frame", {
			Name = "Notch" .. i,
			BackgroundColor3 = C.panelDeep,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10 - (spec.reels - i) * 16, 0, 8),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 41,
			Parent = panel,
		})
		Util.corner(d, 0.5)
		Util.stroke(d, C.line, 2)
		dots[i] = d
	end
	local slips = {}
	for i = 1, Fishing.Slips do
		local s = Util.new("Frame", {
			Name = "Slip" .. i,
			BackgroundColor3 = C.panelDeep,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10 + (i - 1) * 12, FIGHT_H - 15),
			Size = UDim2.fromOffset(8, 8),
			ZIndex = 41,
			Parent = panel,
		})
		Util.corner(s, 0.5)
		slips[i] = s
	end
	local track = Util.new("Frame", {
		Name = "Meter",
		BackgroundColor3 = Color3.fromHex("1D5F86"), -- deep water
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 20),
		ZIndex = 41,
		Parent = panel,
	})
	Util.corner(track, 0.5)
	local zone = Util.new("Frame", {
		Name = "Green",
		BackgroundColor3 = C.lime,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(fight.zoneAt, 0),
		Size = UDim2.fromScale(spec.zone, 1),
		ZIndex = 42,
		Parent = track,
	})
	Util.corner(zone, 0.5)
	-- the needle: a fish, darting along the meter
	local needle = Util.frame(track, {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(36, 36),
		ZIndex = 44,
	})
	if not (Art.has("fish/sardine") and FishArt.image(needle, "sardine", { Size = UDim2.fromScale(1, 1), ZIndex = 44 })) then
		local bar = Util.new("Frame", {
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 5, 1, 0),
			ZIndex = 44,
			Parent = needle,
		})
		Util.corner(bar, 0.5)
	end
	Widgets.label(panel, {
		text = "Slips",
		font = "heavy",
		size = 11,
		color = C.textFaint,
		align = "left",
		sizeUDim = UDim2.fromOffset(60, 14),
		position = UDim2.fromOffset(14 + Fishing.Slips * 12, FIGHT_H - 18),
		z = 41,
	})
	fight.panel, fight.zone, fight.needle, fight.dots, fight.slipDots, fight.track = panel, zone, needle, dots, slips, track
	Util.popIn(panel, 0.25, 0.6)
end

function FishingRod:_stepFight()
	local fight = self.fight
	if not fight then
		return
	end
	local t = os.clock() - fight.t0
	fight.needle.Position = UDim2.fromScale(Fishing.needle(fight.spec.speed, t), 0.5)
	-- it tugs as it goes
	fight.needle.Rotation = math.sin(t * 14) * 10
end

function FishingRod:_endFight()
	local fight = self.fight
	self.fight = nil
	if fight and fight.panel then
		fight.panel:Destroy()
	end
end

-- A tap while it fights: on the green, a notch reeled in; off it, a slip.
function FishingRod:_fightTap()
	local fight = self.fight
	if not fight or fight.busy then
		return
	end
	local spec = fight.spec
	local x = Fishing.needle(spec.speed, os.clock() - fight.t0)
	if math.abs(x - fight.zoneAt) <= spec.zone / 2 then
		fight.reels += 1
		local dot = fight.dots[fight.reels]
		if dot then
			dot.BackgroundColor3 = C.lime
			Util.bump(dot, 0.4)
		end
		Sound.play("pop", 1.1 + fight.reels * 0.1)
		if fight.reels >= spec.reels then
			self:_land(false)
			return
		end
		fight.zoneAt = placeZone(spec.zone, fight.zoneAt)
		Util.tween(fight.zone, 0.18, { Position = UDim2.fromScale(fight.zoneAt, 0) }, Enum.EasingStyle.Quad)
		Util.bump(fight.panel, 0.05)
	else
		fight.slips += 1
		local s = fight.slipDots[fight.slips]
		if s then
			s.BackgroundColor3 = C.coral
		end
		Util.shake(fight.track, 5, 0.25)
		Sound.play("click", 0.7)
		if fight.slips >= Fishing.Slips then
			self:_land(true)
		end
	end
end

-- The fight's over: tell the server how it went, and show what came of it.
function FishingRod:_land(snapped: boolean)
	local fight = self.fight
	if not fight then
		return
	end
	fight.busy = true
	task.spawn(function()
		local ok, data = Net.request("match.fish", { action = "land", reels = fight.reels, slips = fight.slips, snapped = snapped })
		self:_set("idle")
		if ok and type(data) == "table" and data.result == "caught" and data.catch then
			self:_show(data.catch, data.new == true, tonumber(data.size), data.record == true, data.unlocked)
			if self.opts.onCaught then
				self.opts.onCaught(data.catch, data.new == true)
			end
		elseif snapped or (ok and type(data) == "table" and data.result == "snapped") then
			self:_say("Snap! The line broke.", C.textFaint)
		end
	end)
end

---------------------------------------------------------------------------
-- what came up
---------------------------------------------------------------------------

-- The catch's picture, name and size rise out of the water for a moment.
function FishingRod:_show(catchId: string, new: boolean, size: number?, record: boolean?, unlocked: { string }?)
	local def = Fishing.byId[catchId]
	local pop = Util.frame(self.root, {
		Name = "Catch",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(104, 104),
		ZIndex = 41,
	})
	if def and (def.rarity == "rare" or def.rarity == "legendary") then
		-- a glow behind the rare ones
		local glow = Util.new("Frame", {
			Name = "Glow",
			BackgroundColor3 = if def.rarity == "legendary" then C.sun else C.sky,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.9),
			ZIndex = 41,
			Parent = pop,
		})
		Util.corner(glow, 0.5)
	end
	FishArt.image(pop, catchId, { Size = UDim2.fromScale(1, 1), ZIndex = 42 })
	Util.popIn(pop, 0.35, 0.3)
	local name = if def then def.name else catchId
	local text = if catchId == "coin" then "+1 coin" elseif catchId == "boot" then "An old boot..." else ((if new then "New: " else "") .. name)
	if size and size > 0 and catchId ~= "boot" then
		text ..= ", " .. Fishing.sizeText(size) .. (if record then " (your biggest!)" else "")
	end
	self:_say(text, if def and def.rarity == "legendary" then C.sun elseif new or record then C.mint else C.textLight)
	Util.tween(pop, 1.4, { Position = UDim2.new(0.5, 0, 0, -30) }, Enum.EasingStyle.Quad)
	task.delay(1.5, function()
		pop:Destroy()
	end)
	Sound.play(if catchId == "coin" then "coin" else "pop")
	-- filling the log pays
	for _, item in unlocked or {} do
		local reward = Cosmetics.get(item)
		if reward then
			local kind = if reward.category == "trail" then "trail" elseif reward.category == "title" then "title" else reward.category
			Widgets.toast("Fish log reward: the " .. reward.name .. " " .. kind .. " is yours!", "reward")
			Sound.play("reveal")
		end
	end
end

function FishingRod:_tap()
	if not self.allowed or self.busy then
		return
	end
	if self.state == "fight" then
		self:_fightTap()
		return
	end
	self.busy = true
	if self.state == "idle" then
		local ok, data = Net.request("match.fish", { action = "cast" })
		if ok then
			self:_set("cast", type(data) == "table" and data.shadow or nil)
			Sound.play("whoosh", 1.2)
			self:_ripple()
		elseif data and data ~= "It's your turn!" and data ~= "No fishing right now." then
			-- (the server's a moment ahead of the screen as the turn comes round to you:
			-- no need to say so, the rod's put away as soon as the screen catches up)
			Widgets.toast(tostring(data), "info")
		end
	else
		local ok, data = Net.request("match.fish", { action = "reel" })
		if ok and type(data) == "table" and data.result == "hooked" and type(data.fight) == "table" then
			self:_set("fight")
			self:_startFight(data.fight)
			Sound.play("splash", 1.0)
		else
			self:_set("idle")
			if ok and type(data) == "table" then
				if data.result == "early" then
					self:_say("Too soon! It was only nibbling.", C.textFaint)
				elseif data.result == "late" then
					self:_say("It got away!", C.textFaint)
				end
			end
		end
	end
	self.busy = false
end

function FishingRod:layout(r)
	if not r then
		self.root.Visible = false
		return
	end
	self.rect = r
	self.root.Position = UDim2.fromOffset(r.x, r.y)
	self.root.Size = UDim2.fromOffset(r.w, r.h)
	self.root.Visible = self.allowed
end

function FishingRod:setAllowed(on: boolean)
	if self.allowed == on then
		return
	end
	self.allowed = on
	if not on then
		self:_set("idle")
	end
	self.root.Visible = on and self.rect ~= nil
	if on then
		Util.popIn(self.root, 0.25, 0.6)
	end
end

function FishingRod:destroy()
	self:_endFight()
	self.maid:clean()
	self.root:Destroy()
end

return FishingRod
