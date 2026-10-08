--[[
	Chests
	Treasure Chests: spend Gems (earned by playing) to collect cosmetics. Odds are always
	on screen, pity counters show how close a guaranteed drop is, and duplicates turn back
	into Gems.

		Chests.open(popupLayer)
		Chests.art(parent, look, props) -> { root, lid, base }   (also used by the lobby)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gacha = require(Shared.Meta.Gacha)
local Cosmetics = require(Shared.Meta.Cosmetics)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C
local hex = Theme.hex

local Chests = {}

local RARITY_ORDER = { "common", "rare", "epic", "legendary", "mythic" }

---------------------------------------------------------------------------
-- the chest drawing
---------------------------------------------------------------------------

--[[
	A treasure chest drawn from shapes, split into base and lid so the lid can fly off.
	look = { body, trim, band, gem } hex colours (Gacha.chests[i].look)
]]
function Chests.art(parent: Instance, look, props: { [string]: any }?)
	local root = Util.frame(parent, props)
	root.Name = "Chest"
	local body, trim, band, gem = hex(string.sub(look.body, 2)), hex(string.sub(look.trim, 2)), hex(string.sub(look.band, 2)), hex(string.sub(look.gem, 2))

	local base = Shapes.canvas(root, { Name = "Base", ZIndex = 1 })
	Shapes.rect(base, 0.5, 0.68, 0.8, 0.4, body, { r = 0.06 })
	Shapes.rect(base, 0.27, 0.68, 0.09, 0.4, trim)
	Shapes.rect(base, 0.73, 0.68, 0.09, 0.4, trim)
	Shapes.rect(base, 0.5, 0.57, 0.17, 0.15, trim, { r = 0.2 })
	Shapes.circle(base, 0.5, 0.57, 0.075, gem)

	local lid = Shapes.canvas(root, { Name = "Lid", ZIndex = 2 })
	Shapes.rect(lid, 0.5, 0.375, 0.84, 0.22, body, { r = 0.4 })
	Shapes.rect(lid, 0.27, 0.375, 0.09, 0.22, trim)
	Shapes.rect(lid, 0.73, 0.375, 0.09, 0.22, trim)
	Shapes.rect(lid, 0.5, 0.475, 0.84, 0.035, band)
	return { root = root, lid = lid, base = base }
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function rarityColor(rarity: string): Color3
	return CosmeticArt.rarityColor(rarity)
end

local function rarityName(rarity: string): string
	local r = Cosmetics.rarityById[rarity]
	return if r then r.name else rarity
end

local function categoryName(category: string): string
	for _, c in Cosmetics.categories do
		if c.id == category then
			return c.single
		end
	end
	return category
end

-- Light rays behind a reveal: flat translucent spokes that slowly turn.
local function rays(parent: Instance, color: Color3, size: number, z: number): Frame
	local holder = Util.frame(parent, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
	})
	local c = Shapes.canvas(holder)
	for i = 0, 7 do
		Shapes.rect(c, 0.5, 0.5, 0.12, 1, color, { rot = i * 22.5, t = 0.72 })
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation = (holder.Rotation + 0.4) % 360
			task.wait()
		end
	end)
	return holder
end

local function pityText(chest, pity): string
	local best = nil
	for _, rule in chest.pity do
		local since = (pity and pity[rule.rarity]) or 0
		local left = math.max(1, rule.every - since)
		local text = rarityName(rule.rarity) .. " or better within " .. left .. (if left == 1 then " chest" else " chests")
		if best == nil or Gacha.rarityRank(rule.rarity) > best.rank and left <= 10 then
			best = { rank = Gacha.rarityRank(rule.rarity), text = text }
		end
	end
	return if best then best.text else ""
end

---------------------------------------------------------------------------
-- the page
---------------------------------------------------------------------------

function Chests.open(layer: Instance): () -> ()
	local maid = Util.maid()
	local content, close = Widgets.modal(layer, {
		title = "Treasure Chests",
		titleWidth = 320,
		width = 900,
		height = 580,
		onClose = function()
			maid:clean()
		end,
	})

	-- purse
	local purse = Util.frame(content, { Name = "Purse", Size = UDim2.new(1, 0, 0, 40) })
	local gemIcon = Util.frame(purse, { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(0, 2) })
	Icons.medallion(gemIcon, "gem", C.neutral, { Size = UDim2.fromScale(1, 1) })
	local gems = Widgets.label(purse, {
		text = "",
		font = "chunky",
		size = 28,
		color = C.ink,
		sizeUDim = UDim2.new(0, 200, 1, 0),
		position = UDim2.fromOffset(44, 0),
	})
	Widgets.label(purse, {
		text = "Gems come from playing matches. Duplicates turn back into Gems.",
		font = "heavy",
		size = 15,
		color = C.inkSoft,
		align = "right",
		sizeUDim = UDim2.new(1, -250, 1, 0),
		position = UDim2.fromOffset(250, 0),
	})

	local row = Util.frame(content, {
		Name = "Chests",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
	})
	Util.list(row, "x", 20, "Center", "Top")

	local cards = {}
	local opening = false
	local function render()
		local profile = State.get("profile")
		gems.Text = Util.commas(profile and profile.gems or 0)
		for _, card in cards do
			card.update(profile)
		end
	end

	for i, chest in Gacha.chests do
		local card = Util.new("Frame", {
			Name = chest.id,
			BackgroundColor3 = C.parchmentMid,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, -10, 1, 0),
			LayoutOrder = i,
			Parent = row,
		})
		Util.corner(card, 14)
		Util.stroke(card, C.parchmentEdge, 2)
		local art = Chests.art(card, chest.look, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(170, 170),
		})
		task.spawn(function()
			-- an idle wobble so the chests feel alive
			while art.root.Parent do
				task.wait(2.5 + math.random() * 2)
				if not art.root.Parent then
					break
				end
				for _, r in { -4, 4, -2, 0 } do
					Util.tween(art.root, 0.08, { Rotation = r })
					task.wait(0.08)
				end
			end
		end)
		Widgets.label(card, {
			text = chest.name,
			font = "chunky",
			size = 26,
			color = C.ink,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 176),
		})
		Widgets.label(card, {
			text = chest.blurb,
			font = "heavy",
			size = 15,
			color = C.inkSoft,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.new(1, -30, 0, 38),
			position = UDim2.fromOffset(15, 206),
		})
		local pity = Widgets.label(card, {
			text = "",
			font = "heavy",
			size = 14,
			color = C.neutral,
			align = "center",
			sizeUDim = UDim2.new(1, -30, 0, 18),
			position = UDim2.fromOffset(15, 246),
		})
		local buttons = Util.frame(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -50),
			Size = UDim2.new(1, -30, 0, 52),
		})
		local one = Widgets.button(buttons, {
			text = tostring(chest.price),
			icon = "gem",
			style = "brass",
			textSize = 20,
			size = UDim2.new(0.5, -6, 1, 0),
			onClick = function()
				if not opening then
					opening = true
					Chests._buy(layer, chest, 1, function()
						opening = false
					end)
				end
			end,
		})
		Widgets.button(buttons, {
			text = "x10  " .. Util.commas(chest.tenPrice),
			icon = "gem",
			style = "purple",
			textSize = 18,
			size = UDim2.new(0.5, -6, 1, 0),
			anchor = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			onClick = function()
				if not opening then
					opening = true
					Chests._buy(layer, chest, 10, function()
						opening = false
					end)
				end
			end,
		})
		Widgets.button(card, {
			text = "SEE ODDS",
			style = "parchment",
			textSize = 15,
			size = UDim2.fromOffset(140, 36),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			onClick = function()
				Chests._odds(layer, chest)
			end,
		})
		table.insert(cards, {
			update = function(profile)
				local free = profile and profile.freeChests and profile.freeChests[chest.id] or 0
				if free > 0 then
					one:setText("OPEN FREE")
					one:setStyle("green")
				else
					one:setText(tostring(chest.price))
					one:setStyle("brass")
				end
				pity.Text = pityText(chest, profile and profile.pity and profile.pity[chest.id])
			end,
		})
	end
	maid:add(State.watch("profile", render))
	render()
	return close
end

function Chests._odds(layer: Instance, chest)
	local content = Widgets.modal(layer, {
		title = chest.name .. " Odds",
		titleWidth = 340,
		width = 460,
		height = 380,
	})
	local list = Util.frame(content, {})
	Util.list(list, "y", 8, "Center", "Top")
	local function fill(odds, lucky: boolean)
		Util.clear(list, true)
		for i, rarity in RARITY_ORDER do
			local pct = odds[rarity]
			if pct and pct > 0 then
				local row = Util.frame(list, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i })
				local dot = Util.new("Frame", {
					BackgroundColor3 = rarityColor(rarity),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 4, 0.5, 0),
					Size = UDim2.fromOffset(18, 18),
					Parent = row,
				})
				Util.corner(dot, 0.5)
				Widgets.label(row, {
					text = rarityName(rarity),
					font = "chunky",
					size = 20,
					color = C.ink,
					sizeUDim = UDim2.new(0.6, 0, 1, 0),
					position = UDim2.fromOffset(32, 0),
				})
				Widgets.label(row, {
					text = string.format("%.1f%%", pct),
					font = "chunky",
					size = 20,
					color = C.ink,
					align = "right",
					sizeUDim = UDim2.new(0.4, -8, 1, 0),
					position = UDim2.fromScale(0.6, 0),
				})
			end
		end
		local note = {}
		for _, rule in chest.pity do
			table.insert(note, rarityName(rule.rarity) .. " or better is guaranteed at least every " .. rule.every .. " chests.")
		end
		if lucky then
			table.insert(note, "Includes your Lucky Charm bonus.")
		end
		Widgets.label(list, {
			text = table.concat(note, " "),
			font = "body",
			size = 14,
			color = C.inkSoft,
			wrap = true,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 60),
			layoutOrder = 99,
		})
	end
	fill(Gacha.odds(chest, false), false)
	task.spawn(function()
		local ok, data = Net.request("gacha.odds", { chest = chest.id })
		if ok and data and list.Parent then
			fill(data.odds, data.lucky == true)
		end
	end)
end

function Chests._buy(layer: Instance, chest, count: number, done: () -> ())
	local ok, result = Net.request("gacha.open", { chest = chest.id, count = count })
	if not ok then
		Widgets.toast(tostring(result), "error")
		done()
		return
	end
	if count == 1 then
		Chests._revealOne(layer, chest, result.results[1], done)
	else
		Chests._revealMany(layer, chest, result.results, done)
	end
end

---------------------------------------------------------------------------
-- reveals
---------------------------------------------------------------------------

local function backdrop(layer: Instance): Frame
	local dim = Util.new("TextButton", {
		Name = "Reveal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		Parent = layer,
	})
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.25 })
	return dim
end

local function resultLines(parent: Instance, r, z: number, y: number)
	local def = Cosmetics.get(r.item)
	local color = rarityColor(r.rarity)
	Widgets.label(parent, {
		text = string.upper(rarityName(r.rarity)),
		font = "chunky",
		size = 30,
		color = color,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 34),
		position = UDim2.new(0, 0, 0.5, y),
		outline = C.ink,
		outlineThickness = 3,
		z = z,
	})
	Widgets.label(parent, {
		text = (if def then def.name else r.item) .. (if def then ("  ·  " .. categoryName(def.category)) else ""),
		font = "display",
		size = 30,
		color = C.parchment,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 36),
		position = UDim2.new(0, 0, 0.5, y + 36),
		outline = C.ink,
		outlineThickness = 2,
		z = z,
	})
	Widgets.label(parent, {
		text = if r.new then "NEW! Find it in your Locker." else ("Duplicate: +" .. r.refund .. " Gems"),
		font = "heavy",
		size = 18,
		color = if r.new then C.gold else C.parchment,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 24),
		position = UDim2.new(0, 0, 0.5, y + 76),
		outline = C.ink,
		outlineThickness = 2,
		z = z,
	})
end

function Chests._revealOne(layer: Instance, chest, r, done: () -> ())
	local dim = backdrop(layer)
	local stage = Util.frame(dim, { Name = "Stage", ZIndex = 301 })
	local art = Chests.art(stage, chest.look, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(240, 240),
		ZIndex = 305,
	})
	Util.popIn(art.root, 0.35, 0.3)
	Sound.play("chest")
	task.wait(0.45)
	-- the more special the item, the longer the chest rattles
	local shakes = 2 + Gacha.rarityRank(r.rarity)
	for i = 1, shakes do
		Util.tween(art.root, 0.06, { Rotation = if i % 2 == 0 then 7 else -7 })
		task.wait(0.07)
	end
	Util.tween(art.root, 0.06, { Rotation = 0 })
	-- lid flies off, light pours out
	Util.tween(art.lid, 0.4, { Position = UDim2.new(0.5, 30, 0.5, -170), Rotation = 28 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in art.lid:GetChildren() do
		if part:IsA("GuiObject") then
			Util.tween(part, 0.4, { BackgroundTransparency = 1 })
		end
	end
	local color = rarityColor(r.rarity)
	local glow = rays(stage, color, 520, 302)
	glow.Position = UDim2.fromScale(0.5, 0.42)
	Util.popIn(glow, 0.4, 0.2)
	Sound.play("reveal", 0.9 + Gacha.rarityRank(r.rarity) * 0.05)
	local item = CosmeticArt.preview(stage, r.item, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(170, 170),
		ZIndex = 310,
	})
	item.ZIndex = 310
	local s = Util.scaler(item)
	s.Scale = 0
	Util.tween(s, 0.45, { Scale = 1.15 }, Enum.EasingStyle.Back)
	Util.tween(item, 0.45, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Back)
	Util.tween(art.root, 0.4, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Quad)
	task.wait(0.5)
	Util.tween(s, 0.2, { Scale = 1 })
	resultLines(stage, r, 312, 40)
	Widgets.button(stage, {
		text = "COLLECT",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(220, 54),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -40),
		z = 320,
		onClick = function()
			dim:Destroy()
			done()
		end,
	})
end

function Chests._revealMany(layer: Instance, chest, results, done: () -> ())
	local dim = backdrop(layer)
	local stage = Util.frame(dim, { Name = "Stage", ZIndex = 301 })
	Widgets.label(stage, {
		text = chest.name .. " x" .. #results,
		font = "display",
		size = 40,
		color = C.parchment,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 48),
		position = UDim2.fromOffset(0, 70),
		outline = C.ink,
		outlineThickness = 3,
		z = 302,
	})
	local grid = Util.frame(stage, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(5 * 150 + 4 * 14, 2 * 186 + 14),
		ZIndex = 302,
	})
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 186),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local newCount, refund = 0, 0
	for i, r in results do
		if r.new then
			newCount += 1
		end
		refund += r.refund or 0
		local color = rarityColor(r.rarity)
		local tile = Util.new("Frame", {
			Name = "Result" .. i,
			BackgroundColor3 = hex("3B2A1E"),
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 303,
			Parent = grid,
		})
		Util.corner(tile, 12)
		Util.stroke(tile, color, 4)
		local inner = Util.frame(tile, { Name = "Inner", ZIndex = 304, Visible = false })
		CosmeticArt.preview(inner, r.item, nil, {
			Size = UDim2.new(1, 0, 0, 130),
			ZIndex = 305,
		})
		local def = Cosmetics.get(r.item)
		Widgets.label(inner, {
			text = if def then def.name else r.item,
			font = "heavy",
			size = 15,
			color = C.textLight,
			align = "center",
			sizeUDim = UDim2.new(1, -8, 0, 20),
			position = UDim2.new(0, 4, 1, -48),
			z = 306,
		})
		Widgets.label(inner, {
			text = if r.new then "NEW!" else ("+" .. r.refund .. " Gems"),
			font = "chunky",
			size = 15,
			color = if r.new then C.gold else color,
			align = "center",
			sizeUDim = UDim2.new(1, -8, 0, 20),
			position = UDim2.new(0, 4, 1, -26),
			z = 306,
		})
		-- face-down until flipped
		Chests.art(tile, chest.look, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(110, 110),
			ZIndex = 304,
		})
	end
	task.spawn(function()
		for i, r in results do
			local tile = grid:FindFirstChild("Result" .. i) :: Frame
			if not tile then
				continue
			end
			local s = Util.scaler(tile)
			Util.tween(s, 0.1, { Scale = 0.85 })
			task.wait(0.1)
			local cover = tile:FindFirstChild("Chest")
			if cover then
				cover:Destroy()
			end
			local inner = tile:FindFirstChild("Inner") :: Frame
			inner.Visible = true
			Util.tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
			Sound.play("reveal", 0.85 + Gacha.rarityRank(r.rarity) * 0.06)
			task.wait(0.12 + Gacha.rarityRank(r.rarity) * 0.05)
		end
		Widgets.label(stage, {
			text = newCount .. " new" .. (if refund > 0 then ("  ·  +" .. refund .. " Gems from duplicates") else ""),
			font = "heavy",
			size = 20,
			color = C.parchment,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 26),
			position = UDim2.new(0, 0, 1, -120),
			outline = C.ink,
			outlineThickness = 2,
			z = 302,
		})
		Widgets.button(stage, {
			text = "COLLECT",
			style = "green",
			textSize = 22,
			size = UDim2.fromOffset(220, 54),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -40),
			z = 320,
			onClick = function()
				dim:Destroy()
				done()
			end,
		})
	end)
end

return Chests
