--[[
	Cards
	Carved wooden cards. The front is wood with an engraved symbol, a painted band for
	the card type and a paper name strip; the back is parchment with the rules.

	Cards.item(parent, itemId, props)        -> card object (front, can flip to back)
	Cards.character(parent, characterId, props)
	card:flip() / card:showBack(bool) / card.root
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Game.Items)
local Characters = require(ReplicatedStorage.Shared.Game.Characters)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Shapes = require(script.Parent.Shapes)
local Icons = require(script.Parent.Icons)
local Widgets = require(script.Parent.Widgets)
local CardStyle = require(script.Parent.CardStyle)
local Sound = require(script.Parent.Parent.Sound)

local C = Theme.C

local Cards = {}

local POTION_ACCENT = {
	speed_potion = Color3.fromHex("4FA3FF"),
	phoenix_potion = Color3.fromHex("FF7B2E"),
	time_potion = Color3.fromHex("B98CFF"),
	telepathy_potion = Color3.fromHex("FF5FA2"),
	jeopardy_potion = Color3.fromHex("5BD18B"),
}
Cards.POTION_ACCENT = POTION_ACCENT

local CATEGORY_LABEL = {
	trap = "TRAP",
	assist = "ASSIST",
	neutral = "NEUTRAL",
	potion = "POTION",
	natural = "NATURAL",
	coin = "COIN",
}

local function woodTones(kind: string): (Color3, Color3)
	local t = CardStyle.wood[kind] or CardStyle.wood.assist
	return Color3.fromHex(t[1]), Color3.fromHex(t[2])
end

-- The wooden slab every card is made of.
local function slab(parent: Instance, kind: string, darker: number): Frame
	local top, bottom = woodTones(kind)
	top, bottom = Util.shade(top, -darker), Util.shade(bottom, -darker)
	local body = Util.new("Frame", {
		Name = "Slab",
		BackgroundColor3 = top,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(CardStyle.corner, 0), Parent = body })
	Util.scaledStroke(body, Util.shade(bottom, -0.5), 0.012, 2)

	-- grain + knot, drawn on a canvas measured in card widths
	local grain = Util.frame(body, { Name = "Grain", ZIndex = 1 })
	grain:SetAttribute("Aspect", CardStyle.aspect)
	local grainColor = Util.shade(bottom, -0.25)
	for _, pts in CardStyle.grain do
		local scaled = {}
		for i, p in pts do
			scaled[i] = { p[1], p[2] / CardStyle.aspect }
		end
		Shapes.taper(grain, scaled, 0.012, 0.006, grainColor, { t = 0.68, steps = 3 })
	end
	local k = CardStyle.knot
	Shapes.oring(grain, k.cx, k.cy / CardStyle.aspect, k.w, k.h, 0.01, grainColor, { t = 0.6, px = 120 })

	-- carved inner frame
	local frameInset = Util.new("Frame", {
		Name = "CarvedFrame",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.91, 0, 1 - 0.09 * CardStyle.aspect, 0),
		ZIndex = 2,
		Parent = body,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(CardStyle.corner * 0.7, 0), Parent = frameInset })
	local st = Util.scaledStroke(frameInset, Util.shade(bottom, -0.35), 0.012, 2)
	st.Transparency = 0.4
	return body
end

local function band(body: Frame, color: Color3, text: string)
	local B = CardStyle.band
	local strip = Util.new("Frame", {
		Name = "Band",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(B.inset, B.y),
		Size = UDim2.fromScale(1 - 2 * B.inset, B.h),
		ZIndex = 6,
		Parent = body,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(0.25, 0), Parent = strip })
	Util.scaledStroke(strip, Util.shade(color, -0.45), 0.06, 2)
	local shadowText = Widgets.label(strip, {
		text = text,
		font = "chunky",
		size = 40,
		color = Util.shade(color, -0.55),
		align = "center",
		sizeUDim = UDim2.fromScale(0.8, 0.66),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, 0, 0.5, 2),
		scaled = true,
		z = 7,
	})
	shadowText.Name = "LabelShadow"
	Widgets.label(strip, {
		text = text,
		font = "chunky",
		size = 40,
		color = Color3.fromHex("FFF8EA"),
		align = "center",
		sizeUDim = UDim2.fromScale(0.8, 0.66),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		scaled = true,
		z = 8,
	})
	return strip
end

local function namePlate(body: Frame, text: string)
	local P = CardStyle.plate
	local plate = Util.new("Frame", {
		Name = "NamePlate",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(P.x, P.y),
		Size = UDim2.fromScale(P.w, P.h),
		ZIndex = 6,
		Parent = body,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = plate })
	Util.scaledStroke(plate, C.parchmentEdge, 0.04, 1)
	Widgets.label(plate, {
		text = text,
		font = "display",
		size = 40,
		color = C.ink,
		align = "center",
		sizeUDim = UDim2.fromScale(0.92, 0.78),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		scaled = true,
		z = 7,
	})
	return plate
end

-- Parchment back with the card's rules.
local function backFace(parent: Instance, kind: string, title: string, tag: string, tagColor: Color3, sections: { { string } }, footer: string?)
	local body = slab(parent, kind, 0.15)
	body.Name = "Back"
	local paper = Util.new("Frame", {
		Name = "Paper",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 1 - 0.14 * CardStyle.aspect, 0),
		ZIndex = 5,
		Parent = body,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(0.06, 0), Parent = paper })
	Util.scaledStroke(paper, C.parchmentEdge, 0.012, 2)
	local list = Util.frame(paper, { Name = "List", ZIndex = 6 })
	Util.pad(list, 6)
	local layout = Util.list(list, "y", 2, "Center", "Top")
	layout.Padding = UDim.new(0.012, 0)
	Widgets.label(list, {
		text = title,
		font = "display",
		size = 34,
		color = C.ink,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 0.11),
		scaled = true,
		layoutOrder = 1,
		z = 7,
	})
	Widgets.label(list, {
		text = tag,
		font = "chunky",
		size = 18,
		color = tagColor,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 0.05),
		scaled = true,
		layoutOrder = 2,
		z = 7,
	})
	local div = Widgets.divider(list, 3)
	div.ZIndex = 7
	local order = 4
	for _, sec in sections do
		if sec[1] ~= "" then
			Widgets.label(list, {
				text = sec[1],
				font = "chunky",
				size = 18,
				color = tagColor,
				align = "left",
				sizeUDim = UDim2.fromScale(0.94, 0.05),
				scaled = true,
				layoutOrder = order,
				z = 7,
			})
			order += 1
		end
		Widgets.label(list, {
			text = sec[2],
			font = "body",
			size = 22,
			minSize = 7,
			color = C.textDark,
			align = "left",
			valign = "top",
			wrap = true,
			sizeUDim = UDim2.fromScale(0.94, sec[3] and tonumber(sec[3]) or (if #sections > 1 then 0.27 else 0.52)),
			scaled = true,
			layoutOrder = order,
			z = 7,
		})
		order += 1
	end
	if footer and footer ~= "" then
		local pill = Util.new("Frame", {
			Name = "Footer",
			BackgroundColor3 = Util.shade(tagColor, 0.75),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.92, 0.08),
			ZIndex = 7,
			Parent = paper,
		})
		Util.new("UICorner", { CornerRadius = UDim.new(0.4, 0), Parent = pill })
		Widgets.label(pill, {
			text = footer,
			font = "heavy",
			size = 18,
			color = Util.shade(tagColor, -0.45),
			align = "center",
			sizeUDim = UDim2.fromScale(0.94, 0.8),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			scaled = true,
			z = 8,
		})
	end
	return body
end

local function newCard(parent: Instance?, props: { [string]: any }?)
	local root = Util.new("Frame", {
		Name = "Card",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, 120 / CardStyle.aspect),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end
	Util.ratio(root, CardStyle.aspect)
	-- the flipper squashes horizontally to fake a 3D flip
	local flipper = Util.frame(root, {
		Name = "Flipper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	root.Parent = parent
	return root, flipper
end

local function makeCardObject(root: Frame, flipper: Frame, front: Frame, back: Frame)
	back.Visible = false
	local card = { root = root, front = front, back = back, showingBack = false }
	local busy = false
	function card.showBack(_self, on: boolean, instant: boolean?)
		if card.showingBack == on or busy then
			return
		end
		if instant then
			card.showingBack = on
			front.Visible = not on
			back.Visible = on
			return
		end
		busy = true
		Sound.play("card")
		Util.tween(flipper, 0.12, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.12, function()
			card.showingBack = on
			front.Visible = not on
			back.Visible = on
			Util.tween(flipper, 0.14, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			task.delay(0.14, function()
				busy = false
			end)
		end)
	end
	function card.flip(_self)
		card:showBack(not card.showingBack)
	end
	return card
end

function Cards.item(parent: Instance?, itemId: string, props: { [string]: any }?)
	local def = Items.get(itemId)
	assert(def, "Cards: unknown item " .. tostring(itemId))
	local root, flipper = newCard(parent, props)
	root.Name = "Card_" .. itemId
	local category = def.category
	local color = Theme.Category[category] or C.inkSoft

	-- front
	local front = slab(flipper, category, 0)
	front.Name = "Front"
	local woodMid = woodTones(category)
	local I = CardStyle.icon
	Icons.engraved(front, itemId, woodMid, {
		Name = "Symbol",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(I.cx, I.cy),
		Size = UDim2.fromScale(I.size, I.size * CardStyle.aspect),
		ZIndex = 4,
	}, POTION_ACCENT[itemId])
	band(front, color, CATEGORY_LABEL[category] or "")
	namePlate(front, def.name)

	-- back
	local footer = CardStyle.useText[def.use] or ""
	if def.price then
		footer = def.price .. (if def.price == 1 then " coin" else " coins") .. " at the Potion Seller"
	end
	local tag = (CATEGORY_LABEL[category] or "") .. (if category ~= "potion" then " CARD" else "")
	local back = backFace(flipper, category, def.name, tag, color, { { "", def.text } }, footer)

	return makeCardObject(root, flipper, front, back)
end

function Cards.character(parent: Instance?, characterId: string, props: { [string]: any }?)
	local def = Characters.get(characterId)
	assert(def, "Cards: unknown character " .. tostring(characterId))
	local root, flipper = newCard(parent, props)
	root.Name = "Character_" .. characterId
	local color = Theme.Character[characterId] or C.inkSoft

	local front = slab(flipper, "character", 0)
	front.Name = "Front"
	-- portrait medallion
	local medal = Icons.medallion(front, characterId, color, {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.fromScale(0.66, 0.66),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ZIndex = 4,
	})
	medal.ZIndex = 4
	band(front, color, string.upper(def.name))
	namePlate(front, if def.ability then def.ability.name else "Nature's Path")

	local sections = { { "PASSIVE", def.passive, if def.ability then "0.25" else "0.6" } }
	if def.ability then
		local recharge = ({
			cycles = "Recharges after cycles.",
			rounds = "Recharges after rounds.",
			once = "Once per game.",
			perTurn = "Every turn.",
		})[def.ability.recharge] or ""
		table.insert(sections, { "ABILITY: " .. string.upper(def.ability.name), def.ability.text .. " " .. recharge, "0.3" })
	end
	local back = backFace(flipper, "character", def.name, def.tagline, color, sections, nil)
	return makeCardObject(root, flipper, front, back)
end

-- Lifts a card on hover; calls onClick when pressed.
function Cards.interactive(card, onClick: (() -> ())?)
	local root = card.root
	local btn = Util.new("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	local scale = Util.scaler(root)
	btn.MouseEnter:Connect(function()
		Util.tween(scale, 0.15, { Scale = 1.08 }, Enum.EasingStyle.Back)
		Sound.play("hover")
	end)
	btn.MouseLeave:Connect(function()
		Util.tween(scale, 0.15, { Scale = 1 })
	end)
	btn.Activated:Connect(function()
		Util.bump(root, 0.06)
		if onClick then
			task.spawn(onClick)
		end
	end)
	return btn
end

return Cards
