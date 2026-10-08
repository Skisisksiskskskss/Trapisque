--[[
	Inspector
	Opens a card big: the carved front and the rules side next to each other, with
	buttons for whatever you can do with it right now.

		Inspector.item(layer, itemId, {
			{ text = "PLACE IT", style = "green", onClick = fn },
			{ text = "Wait for your turn", disabled = true },
		})
		Inspector.character(layer, characterId, actions?)
		Inspector.choose(layer, title, subtitle, options, onPick)
			options = { { text, value, style?, disabled? } }

	Each returns a close function.
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)

local C = Theme.C

local Inspector = {}

local CARD_W = 206

-- Front and back of the same card side by side.
local function pair(content: Frame, make: (Frame) -> any)
	local row = Util.frame(content, {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, CARD_W / CardStyle.aspect + 4),
	})
	Util.list(row, "x", 24, "Center", "Center")
	local frontSlot = Util.frame(row, { Size = UDim2.fromOffset(CARD_W, CARD_W / CardStyle.aspect), LayoutOrder = 1 })
	local backSlot = Util.frame(row, { Size = UDim2.fromOffset(CARD_W, CARD_W / CardStyle.aspect), LayoutOrder = 2 })
	local front = make(frontSlot)
	local back = make(backSlot)
	back:showBack(true, true)
	for _, card in { front, back } do
		Util.popIn(card.root, 0.3, 0.7)
	end
end

local function actionRow(content: Frame, actions, close: () -> ())
	local row = Util.frame(content, {
		Name = "Actions",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 52),
	})
	Util.list(row, "x", 12, "Center", "Center")
	for i, a in actions do
		if a.disabled and not a.onClick then
			-- a plain note ("Wait for your turn")
			local note = Widgets.label(row, {
				text = a.text,
				font = "heavy",
				size = 18,
				color = C.inkSoft,
				align = "center",
				sizeUDim = UDim2.fromOffset(360, 44),
				layoutOrder = i,
			})
			note.TextWrapped = true
		else
			local b = Widgets.button(row, {
				text = a.text,
				icon = a.icon,
				style = a.style or "wood",
				textSize = 20,
				size = UDim2.fromOffset(a.width or 210, 50),
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
	local content, close = Widgets.modal(layer, {
		width = 2 * CARD_W + 120,
		height = CARD_W / CardStyle.aspect + 120,
	})
	pair(content, function(slot)
		return Cards.item(slot, itemId, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		})
	end)
	actionRow(content, actions or {}, close)
	return close
end

function Inspector.character(layer: Instance, characterId: string, actions: { any }?): () -> ()
	local content, close = Widgets.modal(layer, {
		width = 2 * CARD_W + 120,
		height = CARD_W / CardStyle.aspect + (if actions and #actions > 0 then 120 else 60),
	})
	pair(content, function(slot)
		return Cards.character(slot, characterId, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		})
	end)
	if actions and #actions > 0 then
		actionRow(content, actions, close)
	end
	return close
end

-- A small picker: "How far?" 1 / 2 / 3, "Which way?" Forward / Back...
function Inspector.choose(layer: Instance, title: string, subtitle: string?, options: { any }, onPick: (any) -> ()): () -> ()
	local width = math.max(360, #options * 120 + 80)
	local content, close = Widgets.modal(layer, {
		title = title,
		titleWidth = math.min(width - 60, 320),
		width = width,
		height = if subtitle then 210 else 170,
	})
	if subtitle then
		Widgets.label(content, {
			text = subtitle,
			font = "heavy",
			size = 17,
			color = C.inkSoft,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, 44),
		})
	end
	local row = Util.frame(content, {
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 56),
	})
	Util.list(row, "x", 10, "Center", "Center")
	for i, opt in options do
		local b = Widgets.button(row, {
			text = opt.text,
			icon = opt.icon,
			style = opt.style or "wood",
			textSize = 20,
			size = UDim2.fromOffset(opt.width or 108, 52),
			layoutOrder = i,
			onClick = function()
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
