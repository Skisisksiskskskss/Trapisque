--[[
	Shop
	The Potion Seller's stall, opened when you land on a Potion Seller token.

		local shop = Shop.open(layer, {
			coins = 3, stock = { speed_potion = 9, ... }, hand = { ... },
			onBuy = function(itemId) end, onDone = function() end,
		})
		shop:update(coins, stock, hand)
		shop:close()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Game.Items)
local Config = require(Shared.Config)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local Rules = Config.Rules

local Shop = {}
Shop.__index = Shop

local CARD_W = 112

local function count(list, value): number
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

function Shop.open(layer: Instance, o)
	local self = setmetatable({}, Shop)
	self.o = o
	self.slots = {}

	local dim = Util.new("Frame", {
		Name = "PotionShop",
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = layer,
	})
	self.root = dim
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.5 })

	local width = #Items.potions * (CARD_W + 18) + 40
	local content, panel = Widgets.panel(dim, {
		title = "Potion Seller",
		titleWidth = 300,
		style = "wood",
		size = UDim2.fromOffset(width, 440),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		z = 71,
	})
	Util.popIn(panel, 0.35, 0.6)
	Sound.play("open")

	-- your purse
	local purse = Util.frame(content, {
		Name = "Purse",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(220, 34),
	})
	Util.list(purse, "x", 8, "Center", "Center")
	local coinIcon = Util.frame(purse, { Size = UDim2.fromOffset(30, 30), LayoutOrder = 1 })
	Icons.medallion(coinIcon, "coin", C.brassDark, { Size = UDim2.fromScale(1, 1) })
	self.coinsLabel = Widgets.label(purse, {
		text = "",
		font = "chunky",
		size = 26,
		color = C.parchment,
		sizeUDim = UDim2.fromOffset(160, 32),
		layoutOrder = 2,
	})

	-- one stall slot per potion
	local row = Util.frame(content, {
		Name = "Potions",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 250),
	})
	Util.list(row, "x", 18, "Center", "Top")
	for i, id in Items.potions do
		local def = Items.get(id)
		local slot = Util.frame(row, { Name = id, Size = UDim2.fromOffset(CARD_W, 250), LayoutOrder = i })
		local card = Cards.item(slot, id, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(CARD_W, CARD_W / CardStyle.aspect),
		})
		Cards.interactive(card, function()
			card:flip()
		end)
		local stock = Widgets.label(slot, {
			text = "",
			font = "heavy",
			size = 14,
			color = C.woodPale,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 18),
			position = UDim2.fromOffset(0, CARD_W / CardStyle.aspect + 4),
		})
		local buy = Widgets.button(slot, {
			text = def.price .. (if def.price == 1 then " COIN" else " COINS"),
			icon = "coin",
			style = "brass",
			textSize = 16,
			size = UDim2.new(1, 0, 0, 40),
			position = UDim2.fromOffset(0, CARD_W / CardStyle.aspect + 26),
			onClick = function()
				if self.o.onBuy then
					self.o.onBuy(id)
				end
			end,
		})
		self.slots[id] = { card = card, stock = stock, buy = buy, price = def.price }
	end

	Widgets.button(content, {
		name = "Done",
		text = "DONE SHOPPING",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(260, 50),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			if self.o.onDone then
				self.o.onDone()
			end
		end,
	})
	self:update(o.coins, o.stock, o.hand)
	return self
end

function Shop:update(coins: number, stock: { [string]: number }, hand: { string })
	self.coinsLabel.Text = coins .. (if coins == 1 then " coin" else " coins")
	local handFull = #hand >= Rules.HandLimit
	for id, s in self.slots do
		local left = stock[id] or 0
		s.stock.Text = if left > 0 then (left .. " left") else "Sold out"
		local reason = nil
		if left <= 0 then
			reason = "sold out"
		elseif coins < s.price then
			reason = "coins"
		elseif handFull or count(hand, id) >= Rules.PerItemLimit then
			reason = "full"
		end
		s.buy:setEnabled(reason == nil)
	end
end

-- A potion was bought: the card hops up so it's clear what happened.
function Shop:bought(itemId: string)
	local s = self.slots[itemId]
	if s then
		Util.bump(s.card.root, 0.15)
		Sound.play("coin")
	end
end

function Shop:close()
	if self.closed then
		return
	end
	self.closed = true
	local root = self.root
	Util.tween(root, 0.15, { BackgroundTransparency = 1 })
	for _, d in root:GetChildren() do
		if d:IsA("GuiObject") then
			Util.tween(Util.scaler(d), 0.15, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	Sound.play("close")
	task.delay(0.16, function()
		root:Destroy()
	end)
end

return Shop
