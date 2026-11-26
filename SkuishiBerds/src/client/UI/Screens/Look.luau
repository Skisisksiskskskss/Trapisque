--[[
	Look: birds & customization. Live preview, then pick a bird (ability),
	body/pattern colors, pattern (+ opacity), hat and death animation.
	Player 2 tab edits the second couch bird's look.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Birds = require(Shared.Config.Birds)
local Cosmetics = require(Shared.Config.Cosmetics)
local Products = require(Shared.Config.Products)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Net = require(Client.Core.Net)
local Audio = require(Client.Core.Audio)
local Canvas = require(Client.Render.Canvas)
local BirdView = require(Client.Render.BirdView)
local Patterns = require(Client.Render.Patterns)
local Particles = require(Client.Render.Particles)
local Deaths = require(Client.Render.Deaths)

local CATS = { "bird", "color", "pattern", "hat", "death" }
local CAT_NAMES = { bird = "Bird", color = "Colors", pattern = "Pattern", hat = "Hat", death = "Death" }

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Look" })
		Widgets.pad(frame, 8)
		Widgets.header(frame, "Birds & Looks", function()
			App.go("Home")
		end)

		local which = 1
		local category = "bird"
		local colorField = "color"
		local selected: { [string]: string } = {}

		-- player tabs
		local tabs = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 40), position = UDim2.new(0, 0, 0, 66) })
		local p1Tab, p2Tab

		-- preview
		local preview = Widgets.frame(frame, {
			color = Theme.White,
			size = UDim2.new(1, 0, 0.27, 0),
			position = UDim2.new(0, 0, 0, 112),
			round = 18,
			stroke = 3,
			clip = true,
		})
		-- the stage is square so preview units are equal in x and y (round birds stay round)
		local stageFrame = Widgets.frame(preview, {
			size = UDim2.fromScale(1, 1),
			position = UDim2.fromScale(0.04, 0),
			z = 2,
			name = "Stage",
		})
		local square = Instance.new("UIAspectRatioConstraint")
		square.AspectRatio = 1
		square.Parent = stageFrame
		local stageBack = Widgets.frame(stageFrame, { z = 2 })
		local stageFx = Widgets.frame(stageFrame, { z = 30 })
		local birdHolder = Widgets.frame(stageFrame, { z = 10 })
		local infoName = Widgets.label(preview, {
			text = "",
			size = UDim2.new(0.5, 0, 0, 28),
			position = UDim2.new(0, 12, 0, 8),
			alignX = Enum.TextXAlignment.Left,
			z = 20,
			maxText = 24,
		})
		local infoAbility = Widgets.label(preview, {
			text = "",
			size = UDim2.new(0.42, 0, 0.7, 0),
			position = UDim2.new(1, -10, 0, 10),
			anchor = Vector2.new(1, 0),
			font = Theme.FontBody,
			color = Theme.InkSoft,
			alignX = Enum.TextXAlignment.Right,
			alignY = Enum.TextYAlignment.Top,
			z = 20,
			maxText = 15,
		})

		local SPACE_UNITS = 110
		local previewSpace = Canvas.space(0.5, 0.58, 1 / SPACE_UNITS, 1 / SPACE_UNITS)
		local birdView
		local stage = {
			space = previewSpace,
			layers = { fx = stageFx, eventBack = stageBack },
			rng = Random.new(),
			shake = 0,
			arena = preview,
		}
		stage.particles = Particles.new(stageFx, previewSpace)

		-- category tabs
		local catBar = Widgets.frame(
			frame,
			{ size = UDim2.new(1, 0, 0, 44), position = UDim2.new(0.5, 0, 0.27, 120), anchor = Vector2.new(0.5, 0) }
		)
		Widgets.list(catBar, 6, true)
		local catButtons = {}

		local content =
			Widgets.scroll(frame, { size = UDim2.new(1, 0, 0.73, -262), position = UDim2.new(0, 0, 0.27, 170) })

		local action = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 74), position = UDim2.new(0, 0, 1, -74) })
		local coinLabel = Widgets.label(action, {
			text = "",
			size = UDim2.new(0.34, 0, 0, 30),
			position = UDim2.new(0, 4, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			alignX = Enum.TextXAlignment.Left,
			maxText = 22,
		})
		local actionButton

		local function loadout()
			local p = App.profile
			if not p then
				return which == 1 and Cosmetics.DefaultLoadout or Cosmetics.DefaultLoadout2
			end
			return if which == 1 then p.loadout else p.loadout2
		end

		local function fieldFor(cat: string): string
			if cat == "color" then
				return colorField
			end
			return cat
		end

		local function itemCategory(cat: string): string
			return cat
		end

		local function previewLoadout()
			local lo = table.clone(loadout())
			for cat, id in selected do
				lo[cat] = id
			end
			return lo
		end

		local function rebuildPreview()
			local px = stageFrame.AbsoluteSize.X
			local lo = previewLoadout()
			if birdView then
				birdView:destroy()
			end
			birdView = BirdView.new(birdHolder, {
				space = previewSpace,
				loadout = lo,
				seed = 7,
				ppu = if px > 0 then px / SPACE_UNITS else 3,
				z = 10,
			})
			local def = Birds.get(lo.bird)
			infoName.Text = def.name
			infoAbility.Text = string.format("%s (%d strums)\n%s", def.abilityName, def.cost, def.abilityDesc)
		end

		-- Ownership / action bar ---------------------------------------------------------------
		local function ownedOf(cat: string, id: string): boolean
			return App.owns(itemCategory(cat), id)
		end

		local function priceOf(cat: string, id: string): (number?, string?)
			if cat == "bird" then
				local def = Birds.ById[id]
				return def and def.price, def and def.productKey
			end
			local item = Cosmetics.get(itemCategory(cat), id)
			if not item then
				return nil, nil
			end
			if item.robuxOnly then
				return nil, item.productKey
			end
			return item.price, item.productKey
		end

		local renderContent

		local function equip(cat: string, id: string)
			local res = Net.ask("Equip", which, fieldFor(cat), id)
			if res and res.ok then
				selected[fieldFor(cat)] = nil
				Audio.play("ui_click", 1.2, 0.8)
			end
		end

		local function refreshAction()
			if actionButton then
				actionButton:Destroy()
				actionButton = nil
			end
			coinLabel.Text = tostring(App.coins()) .. " coins"
			local field = fieldFor(category)
			local id = selected[field]
			if not id then
				return
			end
			local current = loadout()[field]
			local owned = ownedOf(category, id)
			local price, productKey = priceOf(category, id)
			if current == id then
				actionButton = Widgets.button(action, {
					text = "Equipped",
					color = Theme.PaperDark,
					size = UDim2.new(0.6, 0, 0, 60),
					position = UDim2.new(1, -4, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
				})
			elseif owned then
				actionButton = Widgets.button(action, {
					text = "Equip",
					color = Theme.Mint,
					size = UDim2.new(0.6, 0, 0, 60),
					position = UDim2.new(1, -4, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
					onClick = function()
						equip(category, id)
					end,
				})
			elseif price then
				actionButton = Widgets.button(action, {
					text = string.format("Buy  %d coins", price),
					sub = if productKey and Products.isEnabled(productKey) then "or tap-hold for Robux" else nil,
					color = Theme.Yellow,
					size = UDim2.new(0.6, 0, 0, 60),
					position = UDim2.new(1, -4, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
					onClick = function()
						if App.coins() < price then
							if productKey and Products.isEnabled(productKey) then
								App.promptProduct(productKey)
							else
								Widgets.toast("Not enough coins yet. Keep strumming!", Theme.Orange)
							end
							return
						end
						Widgets.confirm(App.gui, "Buy it?", string.format("Spend %d coins?", price), "Buy", function()
							local res = if category == "bird"
								then Net.ask("BuyBird", id)
								else Net.ask("Buy", itemCategory(category), id)
							if res and res.ok then
								Audio.play("ui_buy", 1, 0.9)
								equip(category, id)
							else
								Widgets.toast(res and res.err or "Couldn't buy that", Theme.Orange)
							end
						end)
					end,
				})
				if productKey and Products.isEnabled(productKey) then
					actionButton.TouchLongPress:Connect(function()
						App.promptProduct(productKey)
					end)
					actionButton.MouseButton2Click:Connect(function()
						App.promptProduct(productKey)
					end)
				end
			elseif productKey then
				actionButton = Widgets.button(action, {
					text = "Get with Robux",
					color = Theme.Purple,
					size = UDim2.new(0.6, 0, 0, 60),
					position = UDim2.new(1, -4, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
					onClick = function()
						App.promptProduct(productKey)
					end,
				})
			end
		end

		local function pick(cat: string, id: string)
			selected[fieldFor(cat)] = id
			if cat == "death" then
				-- play the death animation in the preview
				birdView:setVisible(false)
				local lo = previewLoadout()
				Deaths.play(stage, id, 0, 0, Canvas.color(lo.color), lo.hat, nil)
				task.delay(1.4, function()
					if birdView then
						birdView:setVisible(true)
					end
					if stage.splats then
						for _, s in stage.splats do
							s:Destroy()
						end
						stage.splats = nil
					end
				end)
			else
				rebuildPreview()
			end
			refreshAction()
			renderContent()
		end

		-- Content grids ----------------------------------------------------------------------
		local function tag(parent: Instance, text: string, color: Color3?)
			return Widgets.label(parent, {
				text = text,
				size = UDim2.new(1, -8, 0, 18),
				position = UDim2.new(0.5, 0, 1, -4),
				anchor = Vector2.new(0.5, 1),
				font = Theme.FontBody,
				color = color or Theme.InkSoft,
				z = 6,
				maxText = 13,
			})
		end

		local function statusText(cat: string, id: string): (string, Color3?)
			local field = fieldFor(cat)
			if loadout()[field] == id then
				return "equipped", Theme.Good
			end
			if ownedOf(cat, id) then
				return "owned", nil
			end
			local price, productKey = priceOf(cat, id)
			if price then
				return tostring(price) .. " c", Color3.fromHex("#b07d00")
			end
			if productKey then
				return "R$ exclusive", Color3.fromHex("#8e44ad")
			end
			return "", nil
		end

		function renderContent()
			for _, c in content:GetChildren() do
				if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
					c:Destroy()
				end
			end
			for _, c in content:GetChildren() do
				c:Destroy()
			end
			Widgets.pad(content, 6)
			local field = fieldFor(category)
			local sel = selected[field] or loadout()[field]

			if category == "bird" then
				Widgets.list(content, 8)
				for _, def in Birds.List do
					local card = Instance.new("TextButton")
					card.Text = ""
					card.AutoButtonColor = false
					card.Size = UDim2.new(1, -6, 0, 92)
					card.BackgroundColor3 = if sel == def.id then Theme.Yellow else Theme.White
					card.LayoutOrder = def.order
					Widgets.corner(card, 14)
					Widgets.stroke(card, 3)
					card.Parent = content
					Widgets.frame(card, {
						color = Canvas.color(def.defaultColor),
						size = UDim2.fromOffset(52, 52),
						position = UDim2.new(0, 12, 0.5, 0),
						anchor = Vector2.new(0, 0.5),
						round = 26,
						stroke = 2,
						z = 4,
					})
					Widgets.label(card, {
						text = def.name,
						size = UDim2.new(0.4, 0, 0, 28),
						position = UDim2.new(0, 76, 0, 8),
						alignX = Enum.TextXAlignment.Left,
						z = 4,
						maxText = 22,
					})
					Widgets.label(card, {
						text = def.abilityName .. " · " .. def.cost .. " strums",
						size = UDim2.new(0.6, 0, 0, 20),
						position = UDim2.new(0, 76, 0, 36),
						font = Theme.FontBody,
						color = Theme.InkSoft,
						alignX = Enum.TextXAlignment.Left,
						z = 4,
						maxText = 15,
					})
					Widgets.label(card, {
						text = def.tagline,
						size = UDim2.new(0.72, 0, 0, 22),
						position = UDim2.new(0, 76, 0, 58),
						font = Theme.FontHand,
						color = Theme.InkSoft,
						alignX = Enum.TextXAlignment.Left,
						z = 4,
						maxText = 16,
					})
					local st, col = statusText("bird", def.id)
					Widgets.label(card, {
						text = st,
						size = UDim2.new(0.3, 0, 0, 22),
						position = UDim2.new(1, -10, 0, 10),
						anchor = Vector2.new(1, 0),
						alignX = Enum.TextXAlignment.Right,
						font = Theme.FontBody,
						color = col or Theme.InkSoft,
						z = 4,
						maxText = 16,
					})
					card.Activated:Connect(function()
						pick("bird", def.id)
					end)
				end
				return
			end

			if category == "color" then
				local toggle = Widgets.frame(content, { size = UDim2.new(1, -6, 0, 40), order = -1 })
				for i, f in { "color", "patternColor" } do
					Widgets.button(toggle, {
						text = if f == "color" then "Body color" else "Pattern color",
						color = if colorField == f then Theme.Yellow else Theme.White,
						size = UDim2.new(0.49, 0, 1, 0),
						position = UDim2.new((i - 1) * 0.51, 0, 0, 0),
						maxText = 18,
						strokeWidth = 2,
						onClick = function()
							colorField = f
							refreshAction()
							renderContent()
						end,
					})
				end
				local gridHolder = Widgets.frame(content, { size = UDim2.new(1, -6, 0, 0), order = 1 })
				gridHolder.AutomaticSize = Enum.AutomaticSize.Y
				Widgets.list(content, 8)
				Widgets.grid(gridHolder, UDim2.fromOffset(58, 72), 8)
				for _, item in Cosmetics.Colors do
					local cell = Instance.new("TextButton")
					cell.Text = ""
					cell.AutoButtonColor = false
					cell.BackgroundTransparency = 1
					cell.LayoutOrder = item.order
					cell.Parent = gridHolder
					local sw = Widgets.frame(cell, {
						color = if item.robuxOnly then Theme.White else Canvas.color(item.id),
						size = UDim2.fromOffset(48, 48),
						position = UDim2.new(0.5, 0, 0, 2),
						anchor = Vector2.new(0.5, 0),
						round = 24,
						stroke = if sel == item.id then 4 else 2,
						z = 4,
					})
					if item.robuxOnly then
						local g = Instance.new("UIGradient")
						g.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHex("#ff6b6b")),
							ColorSequenceKeypoint.new(0.33, Color3.fromHex("#ffd166")),
							ColorSequenceKeypoint.new(0.66, Color3.fromHex("#84fab0")),
							ColorSequenceKeypoint.new(1, Color3.fromHex("#a29bfe")),
						})
						g.Rotation = 45
						g.Parent = sw
					end
					local st, col = statusText("color", item.id)
					tag(cell, if st == "owned" then "" else st, col)
					cell.Activated:Connect(function()
						pick("color", item.id)
					end)
				end
				return
			end

			if category == "pattern" then
				Widgets.list(content, 8)
				local alphaRow = Widgets.frame(content, { size = UDim2.new(1, -6, 0, 40), order = -1 })
				local currentAlpha = loadout().patternAlpha or 0.6
				for i, a in { 0.25, 0.5, 0.75, 1 } do
					Widgets.button(alphaRow, {
						text = math.floor(a * 100) .. "%",
						color = if math.abs(currentAlpha - a) < 0.05 then Theme.Yellow else Theme.White,
						size = UDim2.new(0.235, 0, 1, 0),
						position = UDim2.new((i - 1) * 0.255, 0, 0, 0),
						strokeWidth = 2,
						maxText = 18,
						onClick = function()
							Net.ask("Equip", which, "patternAlpha", a)
						end,
					})
				end
				local gridHolder = Widgets.frame(content, { size = UDim2.new(1, -6, 0, 0), order = 1 })
				gridHolder.AutomaticSize = Enum.AutomaticSize.Y
				Widgets.grid(gridHolder, UDim2.fromOffset(96, 112), 8)
				local lo = loadout()
				for _, item in Cosmetics.Patterns do
					local cell = Instance.new("TextButton")
					cell.Text = ""
					cell.AutoButtonColor = false
					cell.BackgroundColor3 = if sel == item.id then Theme.Yellow else Theme.White
					cell.LayoutOrder = item.order
					Widgets.corner(cell, 12)
					Widgets.stroke(cell, 2)
					cell.Parent = gridHolder
					local cg = Instance.new("CanvasGroup")
					cg.Size = UDim2.fromOffset(60, 60)
					cg.Position = UDim2.new(0.5, 0, 0, 8)
					cg.AnchorPoint = Vector2.new(0.5, 0)
					cg.BackgroundColor3 = Canvas.color(lo.color)
					cg.ZIndex = 4
					Widgets.corner(cg, 30)
					cg.Parent = cell
					local oldPpu = Canvas.ppu
					Canvas.ppu = 2
					Patterns.draw(cg, item.id, Canvas.color(lo.patternColor), 0.8, 7, 5)
					Canvas.ppu = oldPpu
					Widgets.label(cell, {
						text = item.name,
						size = UDim2.new(1, -6, 0, 20),
						position = UDim2.new(0.5, 0, 0, 70),
						anchor = Vector2.new(0.5, 0),
						z = 5,
						maxText = 14,
					})
					local st, col = statusText("pattern", item.id)
					tag(cell, st, col)
					cell.Activated:Connect(function()
						pick("pattern", item.id)
					end)
				end
				return
			end

			-- hats + deaths: text tiles
			local list = if category == "hat" then Cosmetics.Hats else Cosmetics.Deaths
			local gridHolder = Widgets.frame(content, { size = UDim2.new(1, -6, 0, 0) })
			gridHolder.AutomaticSize = Enum.AutomaticSize.Y
			Widgets.list(content, 8)
			Widgets.grid(
				gridHolder,
				if category == "hat" then UDim2.fromOffset(120, 64) else UDim2.fromOffset(250, 74),
				8
			)
			for _, item in list do
				local cell = Instance.new("TextButton")
				cell.Text = ""
				cell.AutoButtonColor = false
				cell.BackgroundColor3 = if sel == item.id then Theme.Yellow else Theme.White
				cell.LayoutOrder = item.order
				Widgets.corner(cell, 12)
				Widgets.stroke(cell, 2)
				cell.Parent = gridHolder
				Widgets.label(cell, {
					text = item.name,
					size = UDim2.new(1, -10, 0, 26),
					position = UDim2.new(0.5, 0, 0, 6),
					anchor = Vector2.new(0.5, 0),
					z = 5,
					maxText = 18,
				})
				if item.desc then
					Widgets.label(cell, {
						text = item.desc,
						size = UDim2.new(1, -10, 0, 18),
						position = UDim2.new(0.5, 0, 0, 32),
						anchor = Vector2.new(0.5, 0),
						font = Theme.FontHand,
						color = Theme.InkSoft,
						z = 5,
						maxText = 14,
					})
				end
				local st, col = statusText(category, item.id)
				tag(cell, st, col)
				cell.Activated:Connect(function()
					pick(category, item.id)
				end)
			end
		end

		for i, cat in CATS do
			catButtons[cat] = Widgets.button(catBar, {
				text = CAT_NAMES[cat],
				color = Theme.White,
				size = UDim2.new(0.19, -5, 1, 0),
				order = i,
				maxText = 16,
				strokeWidth = 2,
				onClick = function()
					category = cat
					for c, b in catButtons do
						b.BackgroundColor3 = if c == cat then Theme.Yellow else Theme.White
					end
					refreshAction()
					renderContent()
				end,
			})
		end
		catButtons.bird.BackgroundColor3 = Theme.Yellow

		local function setWhich(n: number)
			which = n
			table.clear(selected)
			p1Tab.BackgroundColor3 = if n == 1 then Theme.Pink else Theme.White
			p2Tab.BackgroundColor3 = if n == 2 then Theme.Mint else Theme.White
			rebuildPreview()
			refreshAction()
			renderContent()
		end
		p1Tab = Widgets.button(tabs, {
			text = "Player 1 / online",
			color = Theme.Pink,
			size = UDim2.new(0.49, 0, 1, 0),
			strokeWidth = 2,
			maxText = 18,
			onClick = function()
				setWhich(1)
			end,
		})
		p2Tab = Widgets.button(tabs, {
			text = "Player 2 (couch)",
			color = Theme.White,
			size = UDim2.new(0.49, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			strokeWidth = 2,
			maxText = 18,
			onClick = function()
				setWhich(2)
			end,
		})

		App.ProfileChanged:Connect(function()
			if App.current == "Look" then
				rebuildPreview()
				refreshAction()
				renderContent()
			end
		end)

		local conn
		return {
			frame = frame,
			onShow = function()
				table.clear(selected)
				task.defer(function()
					rebuildPreview()
					refreshAction()
					renderContent()
				end)
				local flapAt = 0
				conn = RunService.RenderStepped:Connect(function(dt)
					local t = os.clock()
					if birdView then
						local wing = t - flapAt < 0.2
						if t - flapAt > 1.2 then
							flapAt = t
						end
						birdView:setPose({
							x = 0,
							y = math.sin(t * 2) * 5,
							dir = 1,
							upside = false,
							radius = 15,
							squishX = if wing then 1.15 else 1,
							squishY = if wing then 0.88 else 1,
							wingUp = wing,
							now = t,
						})
					end
					stage.particles:step(dt * 60)
					Deaths.step(stage, dt * 60)
				end)
			end,
			onHide = function()
				if conn then
					conn:Disconnect()
				end
			end,
		}
	end,
}
