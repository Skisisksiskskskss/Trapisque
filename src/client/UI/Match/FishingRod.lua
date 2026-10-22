--[[
	FishingRod
	Fishing between turns (Shared/Meta/Fishing): a round button in the board's corner
	while someone else is playing. Tap it to cast; the bobber floats, and when it dips
	("BITE!") tap again fast to reel it in. What you land pops up (a new fish for your
	log, now and then a gold coin for this match, or an old boot). Put away on your turn.

		local rod = FishingRod.new(parent, { onCaught = fn(catchId, new) })
		rod:layout(rect)
		rod:setAllowed(boolean)        -- someone else's turn, and you're playing
		rod:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fishing = require(ReplicatedStorage.Shared.Meta.Fishing)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local FishArt = require(UI.FishArt)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)

local C = Theme.C

local FishingRod = {}
FishingRod.__index = FishingRod

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
	-- the water inside the button, where the bobber floats
	local water = Util.new("Frame", {
		Name = "Water",
		BackgroundColor3 = C.sky,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		ZIndex = 31,
		Parent = button,
	})
	Util.corner(water, 0.5)
	self.water = water
	self.icon = Icons.make(water, "rod", Icons.flatColors(C.textLight, C.sky), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 32,
	})
	local bobber = Util.new("Frame", {
		Name = "Bobber",
		BackgroundColor3 = C.coral,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.34),
		ZIndex = 33,
		Visible = false,
		Parent = water,
	})
	Util.corner(bobber, 0.5)
	Util.stroke(bobber, C.line, 2)
	local cap = Util.new("Frame", {
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.45, 0),
		ZIndex = 34,
		Parent = bobber,
	})
	Util.corner(cap, 0.5)
	self.bobber = bobber
	self.tag = Widgets.label(root, {
		text = "Fish",
		font = "chunky",
		size = 13,
		color = C.textLight,
		outline = C.line,
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
		if data.state == "bite" and self.state == "cast" then
			self:_set("bite")
			Sound.play("splash", 1.4)
		elseif data.state == "idle" and self.state ~= "idle" then
			self:_set("idle")
			if data.reason == "late" then
				self:_say("It got away!", C.textFaint)
			end
		end
	end))
	-- the bobber bobs (and dips hard on a bite)
	task.spawn(function()
		local t = 0
		while root.Parent do
			t += task.wait(0.05)
			if self.state == "cast" then
				bobber.Position = UDim2.fromScale(0.5, 0.5 + math.sin(t * 3) * 0.05)
			elseif self.state == "bite" then
				bobber.Position = UDim2.fromScale(0.5 + math.sin(t * 40) * 0.04, 0.62)
			end
		end
	end)
	return self
end

function FishingRod:_set(state: string)
	self.state = state
	self.bobber.Visible = state ~= "idle"
	self.icon.Visible = state == "idle"
	self.tag.Text = if state == "idle" then "Fish" elseif state == "cast" then "Wait..." else "Reel!"
	self.tag.TextColor3 = if state == "bite" then C.sun else C.textLight
	self.rim.Color = if state == "bite" then C.sun else C.line
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
		outline = C.line,
		align = "right",
		anchor = Vector2.new(1, 1),
		sizeUDim = UDim2.fromOffset(240, 20),
		position = UDim2.new(1, 0, 0, -6),
		z = 40,
	})
	Util.popIn(label, 0.25, 0.6)
	task.delay(1.6, function()
		label:Destroy()
	end)
end

-- What came up: the catch's picture and name rise out of the water for a moment.
function FishingRod:_show(catchId: string, new: boolean)
	local def = Fishing.byId[catchId]
	local pop = Util.frame(self.root, {
		Name = "Catch",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(84, 84),
		ZIndex = 41,
	})
	Icons.sticker(pop, FishArt.ops(catchId), { ZIndex = 42 }, 0.06)
	Util.popIn(pop, 0.35, 0.3)
	local name = if def then def.name else catchId
	local text = if catchId == "coin" then "+1 coin" elseif catchId == "boot" then "An old boot..." else ((if new then "New: " else "") .. name)
	self:_say(text, if def and def.rarity == "legendary" then C.sun elseif new then C.mint else C.textLight)
	Util.tween(pop, 1.4, { Position = UDim2.new(0.5, 0, 0, -30) }, Enum.EasingStyle.Quad)
	task.delay(1.5, function()
		pop:Destroy()
	end)
	Sound.play(if catchId == "coin" then "coin" else "pop")
end

function FishingRod:_tap()
	if not self.allowed or self.busy then
		return
	end
	self.busy = true
	if self.state == "idle" then
		local ok, data = Net.request("match.fish", { action = "cast" })
		if ok then
			self:_set("cast")
			Sound.play("whoosh", 1.2)
		elseif data then
			Widgets.toast(tostring(data), "info")
		end
	else
		local ok, data = Net.request("match.fish", { action = "reel" })
		self:_set("idle")
		if ok and type(data) == "table" then
			if data.result == "caught" and data.catch then
				self:_show(data.catch, data.new == true)
				if self.opts.onCaught then
					self.opts.onCaught(data.catch, data.new == true)
				end
			elseif data.result == "early" then
				self:_say("Too soon! Wait for the bite.", C.textFaint)
			elseif data.result == "late" then
				self:_say("It got away!", C.textFaint)
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
	self.maid:clean()
	self.root:Destroy()
end

return FishingRod
