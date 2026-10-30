--[[
	PartyFx
	How the board looks while a Party rule (Shared/Game/PartyRules) is in play: a tint
	over it, and something drifting across it, each rule its own:

	  sparks   Power Surge     golden sparks rising, a warm glow
	  dice     Triple Dice     dice tumbling down
	  bangs    Bonk Bonanza    stars bursting here and there, an orange flush
	  alarm    Trap Frenzy     the edges pulse red, warning skulls drift up
	  coins    Gold Rush       doubloons falling, everything a little golden
	  fog      Pea-Souper      thick fog rolling across, the board greyed out
	  cards    Card Shower     cards fluttering down

		fx = PartyFx.new(container)   -- the board's screen-space frame
		fx:set(ruleId | nil)          -- swaps to that rule's look (nil: none)
		fx:destroy()
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Art = require(UI.Art)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartyRules = require(ReplicatedStorage.Shared.Game.PartyRules)

local PartyFx = {}
PartyFx.__index = PartyFx

-- per look: the tint (colour, transparency), what drifts (sprites), which way, how often
local LOOKS = {
	sparks = { tint = Color3.fromRGB(255, 214, 90), alpha = 0.88, sprites = { "ui/star" }, dir = "up", every = 0.3, size = { 18, 34 } },
	dice = { tint = Color3.fromRGB(110, 190, 255), alpha = 0.9, sprites = { "dice/bone", "dice/charcoal", "dice/cosmic" }, dir = "down", every = 0.55, size = { 30, 44 }, spin = true },
	bangs = { tint = Color3.fromRGB(255, 150, 70), alpha = 0.88, sprites = { "ui/star" }, dir = "pop", every = 0.45, size = { 40, 70 }, color = Color3.fromRGB(255, 170, 60) },
	alarm = { tint = Color3.fromRGB(255, 70, 80), alpha = 0.92, sprites = { "ui/skull" }, dir = "up", every = 0.9, size = { 26, 36 }, edges = true },
	coins = { tint = Color3.fromRGB(255, 205, 70), alpha = 0.86, sprites = { "ui/coin" }, dir = "down", every = 0.22, size = { 22, 36 }, spin = true },
	fog = { tint = Color3.fromRGB(205, 215, 220), alpha = 0.62, sprites = { "ground/soft" }, dir = "across", every = 0.6, size = { 260, 420 }, color = Color3.fromRGB(235, 240, 242), fade = 0.35 },
	cards = { tint = Color3.fromRGB(170, 140, 255), alpha = 0.9, sprites = { "cards/clover", "cards/speed_boost", "cards/shield", "cards/compass", "cards/juice" }, dir = "down", every = 0.5, size = { 34, 48 }, spin = true },
}

function PartyFx.new(container: Frame)
	local self = setmetatable({}, PartyFx)
	self.container = container
	self.layer = Util.frame(container, { Name = "PartyFx", ZIndex = 4 })
	self.layer.ClipsDescendants = true
	self.rule = nil
	self.token = 0
	return self
end

local function pick(list: { string }, i: number): string?
	for k = 0, #list - 1 do
		local name = list[(i + k) % #list + 1]
		if Art.has(name) then
			return name
		end
	end
	return nil
end

function PartyFx:_clear()
	self.token += 1
	for _, child in self.layer:GetChildren() do
		child:Destroy()
	end
end

function PartyFx:set(ruleId: string?)
	if ruleId == self.rule then
		return
	end
	self.rule = ruleId
	self:_clear()
	local rule = PartyRules.get(ruleId)
	local look = rule and LOOKS[rule.fx]
	if not look or not self.layer.Parent then
		return
	end
	-- the tint, eased in
	local tint = Util.new("Frame", {
		Name = "Tint",
		BackgroundColor3 = look.tint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = self.layer,
	})
	Util.tween(tint, 1.2, { BackgroundTransparency = look.alpha })
	-- red edges for Trap Frenzy
	if look.edges then
		for _, e in { { 0, 0, 1, 0.12, 90 }, { 0, 0.88, 1, 0.12, 270 }, { 0, 0, 0.08, 1, 0 }, { 0.92, 0, 0.08, 1, 180 } } do
			local f = Util.new("Frame", {
				Name = "Edge",
				BackgroundColor3 = look.tint,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(e[1], e[2]),
				Size = UDim2.fromScale(e[3], e[4]),
				ZIndex = 2,
				Parent = self.layer,
			})
			Util.grad(f, { Color3.new(1, 1, 1), Color3.new(1, 1, 1) }, e[5], { 0, 1 })
		end
	end
	-- what drifts across it, until the rule changes
	local token = self.token
	task.spawn(function()
		local i = 0
		while self.token == token and self.layer.Parent do
			i += 1
			self:_spawn(look, i)
			task.wait(look.every)
		end
	end)
end

function PartyFx:_spawn(look, i: number)
	local name = pick(look.sprites, i)
	local size = look.size[1] + (look.size[2] - look.size[1]) * ((i * 37) % 10) / 10
	local x = ((i * 0.618) % 1)
	local from, to
	if look.dir == "down" then
		from, to = UDim2.fromScale(x, -0.08), UDim2.fromScale(x + 0.05 * math.sin(i), 1.1)
	elseif look.dir == "up" then
		from, to = UDim2.fromScale(x, 1.05), UDim2.fromScale(x + 0.04 * math.sin(i), 0.35)
	elseif look.dir == "across" then
		local y = 0.1 + ((i * 0.37) % 0.85)
		from, to = UDim2.fromScale(-0.25, y), UDim2.fromScale(1.25, y + 0.05)
	else
		local y = 0.15 + ((i * 0.41) % 0.7)
		from, to = UDim2.fromScale(x, y), UDim2.fromScale(x, y)
	end
	local holder = Util.new("Frame", {
		Name = "Drift",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = from,
		Size = UDim2.fromOffset(size, if look.dir == "across" then size * 0.45 else size),
		Rotation = if look.spin then (i * 47) % 360 else 0,
		ZIndex = 3,
		Parent = self.layer,
	})
	local img: ImageLabel? = nil
	if name then
		local art = Art.image(holder, name, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		img = art and art:FindFirstChild("Image") :: ImageLabel?
		if img and look.color then
			img.ImageColor3 = look.color
		end
		if art and look.dir == "across" then
			-- (a fog bank is wide: stretch it)
			local ratio = art:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ratio then
				ratio:Destroy()
			end
		end
	end
	local life = if look.dir == "across" then 9 elseif look.dir == "pop" then 0.9 else 4.5
	if look.dir == "pop" then
		holder.Size = UDim2.fromOffset(size * 0.3, size * 0.3)
		Util.tween(holder, 0.25, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Back)
	else
		Util.tween(holder, life, { Position = to, Rotation = holder.Rotation + (if look.spin then 200 else 0) }, Enum.EasingStyle.Linear)
	end
	if img then
		img.ImageTransparency = look.fade or 0.15
		Util.tween(img, life, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(life, function()
		holder:Destroy()
	end)
end

function PartyFx:destroy()
	self:_clear()
	self.layer:Destroy()
end

return PartyFx
