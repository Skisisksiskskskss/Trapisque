--[[
	Inspector
	Opens a card big: the carved front and the rules side next to each other, with
	buttons for whatever you can do with it right now.

		Inspector.item(layer, itemId, {
			{ text = "PLACE IT", style = "green", onClick = fn },
			{ text = "Wait for your turn", disabled = true },
		})
		Inspector.character(layer, characterId, actions?)
		Inspector.choose(layer, title, subtitle, options, onPick, onCancel?)
			options = { { text, value, style?, disabled? } }
			onCancel runs if it's closed without a pick

	Each returns a close function. Everything sizes itself to the screen: cards get a
	little smaller on phones and pickers wrap onto more rows instead of shrinking.
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)
local Layout = require(UI.Layout)

local C = Theme.C

local Inspector = {}

local PAD = 18 -- the panel's inner padding (Widgets.panel)

-- How wide a modal can be on this screen (stage pixels).
local function screenWidth(): number
	local m = Widgets.metrics
	if not m then
		return 1000
	end
	return Layout.safeRect(m, if m.form == "wide" then 16 else 6).w
end

-- Inspected cards: 206 wide on a monitor, down to 140 on a narrow phone.
local function cardWidth(): number
	return math.clamp(math.floor((screenWidth() - 2 * PAD - 66) / 2), 140, 206)
end

-- Front and back of the same card side by side.
local function pair(content: Frame, cardW: number, make: (Frame) -> any)
	local row = Util.frame(content, {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, cardW / CardStyle.aspect + 4),
	})
	Util.list(row, "x", 24, "Center", "Center")
	local frontSlot = Util.frame(row, { Size = UDim2.fromOffset(cardW, cardW / CardStyle.aspect), LayoutOrder = 1 })
	local backSlot = Util.frame(row, { Size = UDim2.fromOffset(cardW, cardW / CardStyle.aspect), LayoutOrder = 2 })
	local front = make(frontSlot)
	local back = make(backSlot)
	back:showBack(true, true)
	for _, card in { front, back } do
		Util.popIn(card.root, 0.3, 0.7)
	end
end

-- `avail` is the content width; buttons share it when they'd otherwise overflow.
local function actionRow(content: Frame, actions, close: () -> (), avail: number)
	local row = Util.frame(content, {
		Name = "Actions",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 52),
	})
	Util.list(row, "x", 12, "Center", "Center")
	local wanted = 0
	for _, a in actions do
		wanted += if a.disabled and not a.onClick then 360 else (a.width or 210)
	end
	wanted += 12 * math.max(0, #actions - 1)
	local shrink = math.min(1, avail / math.max(1, wanted))
	for i, a in actions do
		if a.disabled and not a.onClick then
			-- a plain note ("Wait for your turn")
			local note = Widgets.label(row, {
				text = a.text,
				font = "heavy",
				size = 18,
				color = C.textSoft,
				align = "center",
				sizeUDim = UDim2.fromOffset(math.floor(360 * shrink), 44),
				layoutOrder = i,
			})
			note.TextWrapped = true
			note.TextSize = if shrink < 0.8 then 15 else 18
		else
			local b = Widgets.button(row, {
				text = a.text,
				icon = a.icon,
				style = a.style or "wood",
				textSize = if shrink < 0.8 then 16 else 20,
				size = UDim2.fromOffset(math.max(104, math.floor((a.width or 210) * shrink)), 50),
				layoutOrder = i,
				onClick = function()
					close()
					if a.onClick then
						task.spawn(a.onClick)
					end
				end,
			})
			if a.disabled then
				b:setEnabled(false)
			end
		end
	end
end

function Inspector.item(layer: Instance, itemId: string, actions: { any }?): () -> ()
	local cardW = cardWidth()
	local width = 2 * cardW + 84
	local content, close = Widgets.modal(layer, {
		width = width,
		height = cardW / CardStyle.aspect + 120,
	})
	pair(content, cardW, function(slot)
		return Cards.item(slot, itemId, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		})
	end)
	actionRow(content, actions or {}, close, width - 2 * PAD)
	return close
end

function Inspector.character(layer: Instance, characterId: string, actions: { any }?): () -> ()
	local cardW = cardWidth()
	local width = 2 * cardW + 84
	local content, close = Widgets.modal(layer, {
		width = width,
		height = cardW / CardStyle.aspect + (if actions and #actions > 0 then 120 else 60),
	})
	pair(content, cardW, function(slot)
		return Cards.character(slot, characterId, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		})
	end)
	if actions and #actions > 0 then
		actionRow(content, actions, close, width - 2 * PAD)
	end
	return close
end

-- A small picker: "How far?" 1 / 2 / 3, "Which way?" Forward / Back... Options that
-- don't fit across the screen wrap onto more rows.
function Inspector.choose(layer: Instance, title: string, subtitle: string?, options: { any }, onPick: (any) -> (), onCancel: (() -> ())?): () -> ()
	local GAP = 10
	local optW = 0
	for _, opt in options do
		optW = math.max(optW, opt.width or 108)
	end
	local width = math.min(math.max(360, #options * (optW + GAP) + 70), screenWidth())
	local perRow = math.max(1, math.floor((width - 2 * PAD - 16 + GAP) / (optW + GAP)))
	local rows = math.ceil(#options / perRow)
	local chosen = false
	local content, close = Widgets.modal(layer, {
		title = title,
		titleWidth = math.min(width - 60, 320),
		width = width,
		height = (if subtitle then 210 else 170) + (rows - 1) * (52 + GAP),
		onClose = function()
			if not chosen and onCancel then
				onCancel()
			end
		end,
	})
	if subtitle then
		Widgets.label(content, {
			text = subtitle,
			font = "heavy",
			size = 17,
			color = C.textSoft,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, 44),
		})
	end
	local grid = Util.frame(content, {
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, rows * 52 + (rows - 1) * GAP + 4),
	})
	Util.list(grid, "y", GAP, "Center", "Bottom")
	local row: Frame? = nil
	for i, opt in options do
		if (i - 1) % perRow == 0 then
			row = Util.frame(grid, {
				Name = "Row",
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = i,
			})
			Util.list(row :: Frame, "x", GAP, "Center", "Center")
		end
		local b = Widgets.button(row, {
			text = opt.text,
			icon = opt.icon,
			style = opt.style or "wood",
			textSize = 20,
			size = UDim2.fromOffset(opt.width or 108, 52),
			layoutOrder = i,
			onClick = function()
				chosen = true
				close()
				task.spawn(onPick, opt.value)
			end,
		})
		if opt.disabled then
			b:setEnabled(false)
		end
	end
	return close
end

return Inspector
