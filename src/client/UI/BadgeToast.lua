--[[
	BadgeToast
	"Badge earned!": the medal drops in at the top of the screen with the badge's name
	and what it was for, then slides away. Several in a row queue up.

		BadgeToast.show(layer, key)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Badges = require(ReplicatedStorage.Shared.Meta.Badges)

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local BadgeArt = require(UI.BadgeArt)

local Client = UI.Parent
local Sound = require(Client.Sound)

local C = Theme.C

local BadgeToast = {}

local queue: { string } = {}
local showing = false

local function showNext(layer: Instance)
	local key = table.remove(queue, 1)
	if not key then
		showing = false
		return
	end
	showing = true
	local def = Badges.byKey[key]
	local m = Widgets.metrics
	local w = math.min(460, (m and m.vw or 800) - 24)
	local top = (m and math.max(m.topbar.y1, m.safe.t) or 40) + 12
	local card = Util.new("Frame", {
		Name = "BadgeToast",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.fromOffset(w, 92),
		ZIndex = 260,
		Parent = layer,
	})
	Util.corner(card, 14)
	Util.stroke(card, C.line, 4)
	BadgeArt.medal(card, key, true, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(76, 76),
		ZIndex = 261,
	})
	Widgets.label(card, {
		text = "BADGE EARNED!",
		font = "chunky",
		size = 15,
		color = C.sun,
		outline = C.line,
		sizeUDim = UDim2.new(1, -110, 0, 18),
		position = UDim2.fromOffset(98, 10),
		z = 262,
	})
	Widgets.label(card, {
		text = if def then def.name else key,
		font = "chunky",
		size = 24,
		color = C.text,
		outline = C.line,
		scaled = true,
		sizeUDim = UDim2.new(1, -110, 0, 28),
		position = UDim2.fromOffset(98, 28),
		z = 262,
	})
	Widgets.label(card, {
		text = if def then def.text else "",
		font = "body",
		size = 14,
		minSize = 9,
		color = C.textSoft,
		wrap = true,
		scaled = true,
		sizeUDim = UDim2.new(1, -110, 0, 30),
		position = UDim2.fromOffset(98, 56),
		z = 262,
	})
	Sound.play("levelUp")
	Util.tween(card, 0.45, { Position = UDim2.new(0.5, 0, 0, top) }, Enum.EasingStyle.Back)
	task.delay(4.2, function()
		Util.tween(card, 0.3, { Position = UDim2.new(0.5, 0, 0, -120) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.32)
		card:Destroy()
		showNext(layer)
	end)
end

function BadgeToast.show(layer: Instance, key: string)
	table.insert(queue, key)
	if not showing then
		showNext(layer)
	end
end

return BadgeToast
