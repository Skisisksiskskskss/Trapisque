--[[
	Cards
	Trapisque's cards. The front is white card stock: the name on a band of the card's
	category colour, its illustration (StickerArt) on a light tint of that colour, and
	the kind of card along the bottom. The back is the same stock with the rules.

	Cards.item(parent, itemId, props)        -> card object (front, can flip to back)
	Cards.character(parent, characterId, props)
	card:flip() / card:showBack(bool) / card.root
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Game.Items)
local Characters = require(ReplicatedStorage.Shared.Game.Characters)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Widgets = require(script.Parent.Widgets)
local CardStyle = require(script.Parent.CardStyle)
local StickerArt = require(script.Parent.StickerArt)
local Art = require(script.Parent.Art)
local Sound = require(script.Parent.Parent.Sound)

local C = Theme.C

local Cards = {}

local CATEGORY_LABEL = {
	trap = "Trap",
	assist = "Assist",
	neutral = "Board piece",
	potion = "Potion",
	coin = "Coin",
}
Cards.CATEGORY_LABEL = CATEGORY_LABEL

-- The illustration for a card (sticker art), or nil.
function Cards.art(itemId: string)
	return StickerArt.cards[itemId]
end

--[[
	Card text keeps one size on every card (a fraction of the card's width) and only
	steps down when it doesn't fit its box. An outlined label's outline scales too.
]]
local function cardText(label: TextLabel, card: GuiObject, frac: number, minSize: number, strokeFrac: number?, short: string?)
	label.TextScaled = false
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint:Destroy()
	end
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local full = label.Text
	local function fit()
		local width = card.AbsoluteSize.X / Util.inheritedScale(card, true)
		if width < 1 then
			return
		end
		label.Text = full
		label.TextSize = math.max(minSize, math.floor(width * frac))
		while not label.TextFits and label.TextSize > minSize do
			label.TextSize -= 1
		end
		if short and not label.TextFits then
			-- a small card (a phone's hand): the short name instead
			label.Text = short
			label.TextSize = math.max(minSize, math.floor(width * frac))
			while not label.TextFits and label.TextSize > minSize do
				label.TextSize -= 1
			end
		end
		if stroke and strokeFrac then
			stroke.Thickness = math.max(1, card.AbsoluteSize.X * strokeFrac)
		end
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
end

local TEXT = CardStyle.text

-- The card stock: a white face with a thin border of the card's colour, on a darker
-- edge of stock. With `band`, the top of the face is a band of that colour.
local function slab(parent: Instance, color: Color3, band: boolean?): (Frame, Frame)
	local holder = Util.frame(parent, { Name = "Slab" })
	local lip = Util.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Util.shade(color, -0.3),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(CardStyle.corner, 0), Parent = lip })
	local face = Util.new("Frame", {
		Name = "Face",
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1 - CardStyle.lip),
		ZIndex = 2,
		Parent = holder,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(CardStyle.corner, 0), Parent = face })
	Util.scaledStroke(face, color, CardStyle.outline, 2)
	if band then
		Util.new("Frame", {
			Name = "Band",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, CardStyle.band.h),
			ZIndex = 3,
			Parent = face,
		})
	end
	return holder, face
end

-- The tinted window, and the art in it.
local function window(face: Frame, color: Color3, ops: { any }?)
	local W = CardStyle.window
	local win = Util.new("Frame", {
		Name = "Window",
		BackgroundColor3 = C.panelRaised:Lerp(color, 0.1),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(W.x, W.y),
		Size = UDim2.fromScale(W.w, W.h),
		ZIndex = 3,
		Parent = face,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(W.corner, 0), Parent = win })
	if ops then
		local I = CardStyle.icon
		local art = Icons.sticker(face, ops, {
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(I.cx, I.cy),
			Size = UDim2.fromScale(I.size, I.size),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 4,
		})
		art.ZIndex = 4
	end
	return win
end

-- The kind of card (or a character's ability), small, along the bottom.
local function topTag(face: Frame, text: string, card: GuiObject, color: Color3)
	local T = CardStyle.tag
	local label = Widgets.label(face, {
		name = "Tag",
		text = text,
		font = "chunky",
		size = 20,
		color = Theme.inkOf(color),
		align = "center",
		sizeUDim = UDim2.fromScale(0.86, T.h),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, T.y),
		z = 6,
	})
	cardText(label, card, TEXT.tag, 6)
	return label
end

-- The name, in the coloured band across the top.
local function nameLine(face: Frame, text: string, card: GuiObject, color: Color3, short: string?)
	local N = CardStyle.name
	local label = Widgets.label(face, {
		name = "Name",
		text = text,
		font = "chunky",
		size = 30,
		color = Theme.textOn(color),
		align = "center",
		sizeUDim = UDim2.fromScale(0.9, N.h),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, N.y),
		z = 6,
	})
	cardText(label, card, TEXT.name, 7, nil, short)
	return label
end

-- The back: the same card stock, with the card's rules.
local function backFace(parent: Instance, color: Color3, title: string, tag: string, sections: { { string } }, footer: string?)
	local card = parent.Parent :: GuiObject -- the card root (parent is its flipper)
	local holder, face = slab(parent, color)
	holder.Name = "Back"
	local paper = Util.new("Frame", {
		Name = "Paper",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 1 - 0.1 * CardStyle.aspect, 0),
		ZIndex = 5,
		Parent = face,
	})
	local list = Util.frame(paper, { Name = "List", ZIndex = 6 })
	Util.pad(list, 6)
	local layout = Util.list(list, "y", 2, "Center", "Top")
	layout.Padding = UDim.new(0.012, 0)
	cardText(Widgets.label(list, {
		text = title,
		font = "chunky",
		size = 34,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 0.11),
		layoutOrder = 1,
		z = 7,
	}), card, TEXT.title, 8)
	cardText(Widgets.label(list, {
		text = tag,
		font = "chunky",
		size = 18,
		color = color:Lerp(Color3.new(0, 0, 0), 0.25),
		align = "center",
		sizeUDim = UDim2.fromScale(1, 0.055),
		layoutOrder = 2,
		z = 7,
	}), card, TEXT.header, 6)
	local div = Widgets.divider(list, 3)
	div.ZIndex = 7
	div.BackgroundColor3 = color
	local order = 4
	for _, sec in sections do
		if sec[1] ~= "" then
			cardText(Widgets.label(list, {
				text = sec[1],
				font = "chunky",
				size = 18,
				color = color:Lerp(Color3.new(0, 0, 0), 0.25),
				align = "left",
				sizeUDim = UDim2.fromScale(0.94, 0.055),
				layoutOrder = order,
				z = 7,
			}), card, TEXT.header, 6)
			order += 1
		end
		cardText(Widgets.label(list, {
			text = sec[2],
			font = "heavy",
			size = 22,
			color = C.text,
			align = "left",
			valign = "top",
			wrap = true,
			sizeUDim = UDim2.fromScale(0.94, sec[3] and tonumber(sec[3]) or (if #sections > 1 then 0.27 else 0.52)),
			layoutOrder = order,
			z = 7,
		}), card, TEXT.body, 7)
		order += 1
	end
	if footer and footer ~= "" then
		local pill = Util.new("Frame", {
			Name = "Footer",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.94, 0.09),
			ZIndex = 7,
			Parent = paper,
		})
		Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pill })
		cardText(Widgets.label(pill, {
			text = footer,
			font = "heavy",
			size = 18,
			color = Theme.textOn(color),
			align = "center",
			sizeUDim = UDim2.fromScale(0.94, 0.8),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			z = 8,
		}), card, TEXT.footer, 6)
	end
	return holder
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
	local color = Theme.Category[category] or C.panelHi

	-- front
	local front, face = slab(flipper, color, true)
	front.Name = "Front"
	topTag(face, CATEGORY_LABEL[category] or "", root, color)
	window(face, color, Cards.art(itemId))
	nameLine(face, def.name, root, color, def.nick)

	-- back
	local tag = (CATEGORY_LABEL[category] or "") .. (if category == "trap" and def.hidden then " · hidden" else "")
	local back = backFace(flipper, color, def.name, tag, { { "", def.text } }, CardStyle.howToPlay(def))

	return makeCardObject(root, flipper, front, back)
end

-- (`portraitId` is a character, or one in an outfit: "mage:ghost")
function Cards.character(parent: Instance?, portraitId: string, props: { [string]: any }?)
	local characterId = Icons.splitPortrait(portraitId)
	local def = Characters.get(characterId)
	assert(def, "Cards: unknown character " .. tostring(characterId))
	local root, flipper = newCard(parent, props)
	root.Name = "Character_" .. characterId
	local color = Theme.Character[characterId] or C.panelHi

	local front, face = slab(flipper, color, true)
	front.Name = "Front"
	topTag(face, if def.ability then def.ability.name else "", root, color)
	local portrait = Icons.portraitSprite(portraitId)
	local win = window(face, color, if Art.has(portrait) then nil else StickerArt.mascot(characterId))
	if Art.has(portrait) then
		-- their illustrated portrait, cropped to the window
		local crop = Util.new("CanvasGroup", {
			Name = "Portrait",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = win,
		})
		Util.new("UICorner", { CornerRadius = UDim.new(CardStyle.window.corner, 0), Parent = crop })
		Art.image(crop, portrait, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			ZIndex = 4,
		})
	end
	nameLine(face, def.name, root, color)

	local sections = { { def.passiveName or "Passive", def.passive, "0.24" } }
	if def.ability then
		table.insert(sections, {
			def.ability.name .. " · " .. def.ability.cost .. " Power",
			def.ability.text,
			"0.27",
		})
	end
	local back = backFace(flipper, color, def.name, def.tagline, sections, nil)
	return makeCardObject(root, flipper, front, back)
end

--[[
	Opens a card big over everything, to read it: it turns to its rules side; click it to
	turn it back over, click outside it to close. `make(parent, props)` builds the card
	(Cards.item / Cards.character) at the size given. Returns a close function.
]]
function Cards.zoom(from: GuiObject, make: (Instance, { [string]: any }) -> any): () -> ()
	local gui = from:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui then
		return function() end
	end
	local backdrop = Util.new("TextButton", {
		Name = "CardZoom",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 900,
		Parent = gui,
	})
	Util.tween(backdrop, 0.15, { BackgroundTransparency = 0.3 })
	local screen = gui.AbsoluteSize
	local h = math.min(screen.Y * 0.74, screen.X * 0.86 / CardStyle.aspect)
	local card = make(backdrop, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(h * CardStyle.aspect, h),
		ZIndex = 901,
	})
	Util.popIn(card.root, 0.25, 0.6)
	task.delay(0.2, function()
		if card.root.Parent then
			card:showBack(true)
		end
	end)
	Cards.interactive(card, function()
		card:flip()
	end)
	Widgets.label(backdrop, {
		text = "Click the card to turn it over. Click outside it to close.",
		font = "heavy",
		size = 18,
		color = C.textLight,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 24),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -16),
		z = 902,
	})
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Util.tween(backdrop, 0.12, { BackgroundTransparency = 1 })
		Util.tween(Util.scaler(card.root), 0.12, { Scale = 0.85 })
		task.delay(0.13, function()
			backdrop:Destroy()
		end)
	end
	backdrop.Activated:Connect(close)
	return close
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
