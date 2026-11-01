--!strict
-- Inventory: every owned brainrot, placed or in storage, with Place / Store / Sell and Place Best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Kit = require(script.Parent.Kit)
local Panels = require(script.Parent.Panels)

local BrainrotsPanel = {}

function BrainrotsPanel.Register(toast: (string, string?) -> ())
	Panels.Register("Brainrots", "🎒 Your Brainrots", Vector2.new(780, 480), function(content)
		local header = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			Parent = content,
		})
		local summary = Kit.label({
			Text = "",
			Size = UDim2.new(0.6, 0, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = header,
		})
		Kit.button({
			Text = "⭐ Place Best",
			Color = Kit.Colors.Yellow,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 0),
			Size = UDim2.fromOffset(200, 46),
			TextSize = 24,
			Parent = header,
			OnClick = function()
				local ok, message = Net.Function("Inventory"):InvokeServer("PlaceBest")
				toast(message, if ok then "good" else "warn")
			end,
		})

		local scroll = Kit.new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 56),
			Size = UDim2.new(1, 0, 1, -56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = content,
		})
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(176, 200),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})
		Kit.padding(4).Parent = scroll

		local signature = ""

		local function act(action: string, uid: string)
			local ok, message = Net.Function("Inventory"):InvokeServer(action, uid)
			toast(message, if ok then "good" else "warn")
		end

		local function refresh(state: { [string]: any })
			local list = state.Brainrots or {}
			table.sort(list, function(a, b)
				if (a.Slot ~= nil) ~= (b.Slot ~= nil) then
					return a.Slot ~= nil
				end
				return a.Income > b.Income
			end)
			local placed = 0
			for _, item in list do
				if item.Slot then
					placed += 1
				end
			end
			summary.Text = string.format(
				"On pedestals: %d/%d · Storage: %d/%d",
				placed,
				state.SlotsUnlocked or Economy.Slots(state.Tier),
				#list - placed,
				state.StorageMax or 50
			)
			local parts = {}
			for _, item in list do
				table.insert(parts, item.Uid .. ":" .. tostring(item.Slot))
			end
			local newSignature = table.concat(parts, ",")
			if newSignature == signature then
				return
			end
			signature = newSignature
			for _, child in scroll:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			local mult = state.CashMultiplier or 1
			for order, item in list do
				local def = Brainrots.Get(item.Id)
				local rarity = Rarities.Get(if def then def.Rarity else 1)
				local card = Kit.panelFrame({
					LayoutOrder = order,
					BackgroundColor3 = Kit.darken(rarity.Color, 0.6),
					Parent = scroll,
				})
				local preview = Kit.new("Frame", {
					Size = UDim2.new(1, -12, 0, 78),
					Position = UDim2.fromOffset(6, 6),
					BackgroundTransparency = 1,
					Parent = card,
				})
				task.spawn(function()
					local model = BrainrotBuilder.Build(item.Id, { Mutation = item.Mutation, Effects = false })
					Kit.viewport(model, UDim2.fromScale(1, 1)).Parent = preview
				end)
				Kit.label({
					Text = BrainrotStats.DisplayName(item.Id, item.Mutation, item.Size),
					Size = UDim2.new(1, -10, 0, 36),
					Position = UDim2.fromOffset(5, 86),
					TextColor3 = rarity.Color,
					TextWrapped = true,
					MaxTextSize = 18,
					Parent = card,
				})
				Kit.label({
					Text = Format.Cash(item.Income * mult) .. "/s",
					Size = UDim2.new(1, -10, 0, 20),
					Position = UDim2.fromOffset(5, 122),
					TextColor3 = Kit.Colors.Cash,
					MaxTextSize = 18,
					Parent = card,
				})
				local buttons = Kit.new("Frame", {
					Size = UDim2.new(1, -10, 0, 44),
					Position = UDim2.new(0, 5, 1, -50),
					BackgroundTransparency = 1,
					Parent = card,
				})
				Kit.list(Enum.FillDirection.Horizontal, 6).Parent = buttons
				local uid: string = item.Uid
				if item.Slot then
					Kit.button({
						Text = "📦",
						Color = Kit.Colors.Blue,
						Size = UDim2.new(0.5, -3, 1, 0),
						LayoutOrder = 1,
						TextSize = 22,
						Parent = buttons,
						OnClick = function()
							act("Store", uid)
						end,
					})
				else
					Kit.button({
						Text = "Place",
						Color = Kit.Colors.Green,
						Size = UDim2.new(0.5, -3, 1, 0),
						LayoutOrder = 1,
						TextSize = 20,
						Parent = buttons,
						OnClick = function()
							act("Place", uid)
						end,
					})
				end
				local sellText = "💰" .. Format.Short(Economy.SellValue(item.Income * mult))
				local armed = false
				local sellButton: TextButton
				sellButton = Kit.button({
					Text = sellText,
					Color = Kit.Colors.Orange,
					Size = UDim2.new(0.5, -3, 1, 0),
					LayoutOrder = 2,
					TextSize = 18,
					Parent = buttons,
					OnClick = function()
						-- Rare brainrots need a second tap so nobody sells a Legendary by accident.
						if rarity.Index >= 4 and not armed then
							armed = true
							sellButton.Text = "Sure?"
							task.delay(2.5, function()
								armed = false
								if sellButton.Parent then
									sellButton.Text = sellText
								end
							end)
							return
						end
						act("Sell", uid)
					end,
				})
			end
		end

		return {
			Refresh = refresh,
			OnOpen = function()
				signature = ""
			end,
		}
	end)
end

return BrainrotsPanel
