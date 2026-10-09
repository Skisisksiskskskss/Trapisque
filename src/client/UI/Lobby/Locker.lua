--[[
	Locker
	Your collection: pawns, dice, trails, titles and emotes. Click something you own to
	equip it (emotes: pick up to six). Things you haven't found yet show as mystery tiles.

		Locker.open(popupLayer, startCategory?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Meta.Cosmetics)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C
local hex = Theme.hex

local Locker = {}

local TILE = Vector2.new(150, 172)

local SOURCE_TEXT = {
	vip = "VIP pass",
	emotepack = "Emote Pack",
}

local function rarityOrder(def): number
	local r = Cosmetics.rarityById[def.rarity]
	return if r then r.order else 0
end

function Locker.open(layer: Instance, startCategory: string?): () -> ()
	local maid = Util.maid()
	local roomW, roomH, narrow = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "Locker",
		titleWidth = 220,
		width = math.min(940, roomW),
		height = math.min(600, roomH),
		onClose = function()
			maid:clean()
		end,
	})
	local category = startCategory or "pawn"

	local tabs = {}
	for _, c in Cosmetics.categories do
		table.insert(tabs, { text = c.name, value = c.id })
	end
	-- the category tabs take the whole row on narrow screens (the count goes under them)
	content:SetAttribute("Narrow", narrow)
	Widgets.choice(content, {
		options = tabs,
		value = category,
		size = if narrow then UDim2.new(1, 0, 0, 40) else UDim2.new(1, -200, 0, 44),
		textSize = if narrow then 15 else 18,
		onChange = function(v)
			category = v
			Locker._fill(maid, content, category)
		end,
	})
	maid:add(State.watch("profile", function()
		Locker._fill(maid, content, category)
	end))
	Locker._fill(maid, content, category)
	return close
end

function Locker._fill(_maid, content: Frame, category: string)
	local profile = State.get("profile")
	if not profile then
		return
	end
	local owned = {}
	for _, id in profile.owned or {} do
		owned[id] = true
	end
	local equipped = profile.equipped or {}

	local old = content:FindFirstChild("Grid")
	local scrollPos = Vector2.zero
	if old then
		scrollPos = (old :: ScrollingFrame).CanvasPosition
		old:Destroy()
	end
	local oldCount = content:FindFirstChild("Count")
	if oldCount then
		oldCount:Destroy()
	end

	local items = table.clone(Cosmetics.byCategory[category] or {})
	table.sort(items, function(a, b)
		local oa, ob = owned[a.id] == true, owned[b.id] == true
		if oa ~= ob then
			return oa
		end
		if rarityOrder(a) ~= rarityOrder(b) then
			return rarityOrder(a) < rarityOrder(b)
		end
		return a.order < b.order
	end)
	local have = 0
	for _, def in items do
		if owned[def.id] then
			have += 1
		end
	end
	local narrow = content:GetAttribute("Narrow") == true
	Widgets.label(content, {
		name = "Count",
		text = have .. " / " .. #items .. " found",
		font = "chunky",
		size = if narrow then 16 else 20,
		color = C.textSoft,
		align = "right",
		sizeUDim = if narrow then UDim2.new(1, 0, 0, 24) else UDim2.new(0, 190, 0, 44),
		anchor = Vector2.new(1, 0),
		position = if narrow then UDim2.new(1, 0, 0, 46) else UDim2.fromScale(1, 0),
	})

	local top = if narrow then 76 else 56
	local grid = Widgets.scroll(content, {
		name = "Grid",
		size = UDim2.new(1, 0, 1, -top),
		position = UDim2.fromOffset(0, top),
		grid = UDim2.fromOffset(TILE.X, TILE.Y),
		gap = 12,
	})

	local emoteSlots = {}
	if category == "emote" then
		for i, id in equipped.emotes or {} do
			emoteSlots[id] = i
		end
	end

	for i, def in items do
		local isOwned = owned[def.id] == true
		local isEquipped = if category == "emote" then emoteSlots[def.id] ~= nil else equipped[category] == def.id
		local rarity = Cosmetics.rarityById[def.rarity]
		local rimColor = if rarity then hex(string.sub(rarity.color, 2)) else C.textFaint
		local tile = Util.new("TextButton", {
			Name = def.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = hex("3B2A1E"),
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		})
		Util.corner(tile, 12)
		Util.stroke(tile, if isEquipped then C.good else rimColor, if isEquipped then 4 else 3)
		if isOwned then
			CosmeticArt.preview(tile, def.id, nil, { Size = UDim2.new(1, 0, 0, 118) })
		else
			Widgets.label(tile, {
				text = "?",
				font = "chunky",
				size = 64,
				color = rimColor,
				align = "center",
				sizeUDim = UDim2.new(1, 0, 0, 118),
			}).TextTransparency = 0.25
		end
		-- name strip
		local strip = Util.new("Frame", {
			BackgroundColor3 = hex("2A1D14"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 44),
			Parent = tile,
		})
		Util.corner(strip, 8)
		Widgets.label(strip, {
			text = def.name,
			font = "heavy",
			size = 15,
			color = C.textLight,
			align = "center",
			sizeUDim = UDim2.new(1, -8, 0, 20),
			position = UDim2.fromOffset(4, 2),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local status
		if isEquipped then
			status = if category == "emote" then ("SLOT " .. emoteSlots[def.id]) else "EQUIPPED"
		elseif isOwned then
			status = string.upper(rarity and rarity.name or "")
		else
			status = if def.source and SOURCE_TEXT[def.source] then SOURCE_TEXT[def.source] else "In Treasure Chests"
		end
		Widgets.label(strip, {
			text = status,
			font = "chunky",
			size = 13,
			color = if isEquipped then C.good elseif isOwned then rimColor else C.textFaint,
			align = "center",
			sizeUDim = UDim2.new(1, -8, 0, 16),
			position = UDim2.fromOffset(4, 24),
		})

		tile.MouseEnter:Connect(function()
			Util.tween(Util.scaler(tile), 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end)
		tile.MouseLeave:Connect(function()
			Util.tween(Util.scaler(tile), 0.12, { Scale = 1 })
		end)
		tile.Activated:Connect(function()
			if not isOwned then
				Util.shake(tile, 4, 0.2)
				Sound.play("error")
				return
			end
			Sound.play("click")
			local ok, err
			if category == "emote" then
				local list = table.clone(equipped.emotes or {})
				local at = table.find(list, def.id)
				if at then
					if #list <= 1 then
						Widgets.toast("Keep at least one emote equipped.", "error")
						return
					end
					table.remove(list, at)
				else
					if #list >= Cosmetics.EmoteSlots then
						Widgets.toast("You can equip up to " .. Cosmetics.EmoteSlots .. " emotes. Remove one first.", "error")
						return
					end
					table.insert(list, def.id)
				end
				ok, err = Net.request("locker.equip", { category = "emotes", value = list })
			else
				if isEquipped then
					return
				end
				ok, err = Net.request("locker.equip", { category = category, value = def.id })
			end
			if not ok then
				Widgets.toast(tostring(err), "error")
			end
		end)
	end
	task.defer(function()
		if grid.Parent then
			grid.CanvasPosition = scrollPos
		end
	end)
end

return Locker
