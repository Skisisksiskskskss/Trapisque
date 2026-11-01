--!strict
-- The Index (collection book): every brainrot by rarity, discovered or "???", mutation stamps, the +cash bonus
-- and one-time rewards for completing a rarity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Rewards = require(Shared.Config.Rewards)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local Net = require(Shared.Modules.Net)
local Kit = require(script.Parent.Kit)
local Panels = require(script.Parent.Panels)

local IndexPanel = {}

type Card = {
	Frame: Frame,
	Name: TextLabel,
	Preview: Frame,
	Stamps: { [string]: Frame },
	Shown: string, -- "none" | "silhouette" | "model"
}

local function silhouette(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Color = Color3.fromRGB(25, 22, 45)
			child.Material = Enum.Material.SmoothPlastic
			child.Reflectance = 0
		end
	end
end

function IndexPanel.Register(toast: (string, string?) -> ())
	Panels.Register("Index", "📖 Brainrot Index", Vector2.new(800, 490), function(content)
		local header = Kit.label({
			Text = "",
			Size = UDim2.new(1, 0, 0, 30),
			TextColor3 = Kit.Colors.Cash,
			MaxTextSize = 24,
			Parent = content,
		})
		local scroll = Kit.new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 1, -36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = content,
		})
		Kit.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top).Parent =
			scroll

		local cards: { [string]: Card } = {}
		local sections: { [number]: { Progress: TextLabel, Claim: TextButton } } = {}

		for _, rarity in Rarities.List do
			local bucket = Brainrots.OfRarity(rarity.Index)
			local rows = math.ceil(#bucket / 6)
			local section = Kit.new("Frame", {
				Name = rarity.Name,
				LayoutOrder = rarity.Index,
				Size = UDim2.new(1, -12, 0, 52 + rows * 138),
				BackgroundTransparency = 1,
				Parent = scroll,
			})
			local bar = Kit.panelFrame({
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Kit.darken(
					if rarity.Index == 8 then Color3.fromRGB(90, 90, 90) else rarity.Color,
					0.45
				),
				Parent = section,
			})
			Kit.label({
				Text = rarity.Name,
				Size = UDim2.new(0.3, 0, 1, -8),
				Position = UDim2.fromOffset(10, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if rarity.Index == 8 then Color3.new(1, 1, 1) else rarity.Color,
				MaxTextSize = 26,
				Parent = bar,
			})
			local progress = Kit.label({
				Text = "0/0",
				Size = UDim2.new(0.3, 0, 1, -10),
				Position = UDim2.new(0.3, 0, 0, 5),
				MaxTextSize = 22,
				Parent = bar,
			})
			local reward = Rewards.IndexSets[rarity.Index]
			local claim = Kit.button({
				Text = "🎁 " .. Rewards.Describe(reward),
				Color = Kit.Colors.Grey,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0.4, -10, 1, -10),
				TextSize = 18,
				Parent = bar,
				OnClick = function()
					local ok, message = Net.Function("ClaimIndex"):InvokeServer(rarity.Index)
					toast(message, if ok then "reward" else "warn")
				end,
			})
			sections[rarity.Index] = { Progress = progress, Claim = claim }

			local grid = Kit.new("Frame", {
				Position = UDim2.fromOffset(0, 52),
				Size = UDim2.new(1, 0, 1, -52),
				BackgroundTransparency = 1,
				Parent = section,
			})
			Kit.new("UIGridLayout", {
				CellSize = UDim2.new(1 / 6, -8, 0, 128),
				CellPadding = UDim2.fromOffset(8, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})
			for order, def in bucket do
				local card = Kit.panelFrame({
					LayoutOrder = order,
					BackgroundColor3 = Color3.fromRGB(40, 36, 76),
					Parent = grid,
				})
				local preview = Kit.new("Frame", {
					Size = UDim2.new(1, -8, 0, 76),
					Position = UDim2.fromOffset(4, 4),
					BackgroundTransparency = 1,
					Parent = card,
				})
				local name = Kit.label({
					Text = "???",
					Size = UDim2.new(1, -6, 0, 28),
					Position = UDim2.fromOffset(3, 80),
					TextWrapped = true,
					MaxTextSize = 15,
					Parent = card,
				})
				local stampRow = Kit.new("Frame", {
					Size = UDim2.new(1, -8, 0, 14),
					Position = UDim2.new(0, 4, 1, -18),
					BackgroundTransparency = 1,
					Parent = card,
				})
				Kit.list(Enum.FillDirection.Horizontal, 4).Parent = stampRow
				local stamps: { [string]: Frame } = {}
				for i, mutation in Mutations.List do
					if mutation.Name ~= "None" and mutation.Color then
						stamps[mutation.Name] = Kit.new("Frame", {
							LayoutOrder = i,
							Size = UDim2.fromOffset(14, 14),
							BackgroundColor3 = mutation.Color,
							BackgroundTransparency = 0.85,
							Parent = stampRow,
						}, { Kit.corner(7) })
					end
				end
				cards[def.Id] = { Frame = card, Name = name, Preview = preview, Stamps = stamps, Shown = "none" }
			end
		end

		local function setPreview(card: Card, id: string, discovered: boolean)
			local wanted = if discovered then "model" else "silhouette"
			if card.Shown == wanted then
				return
			end
			card.Shown = wanted
			for _, child in card.Preview:GetChildren() do
				child:Destroy()
			end
			local model = BrainrotBuilder.Build(id, { Effects = false })
			if not discovered then
				silhouette(model)
			end
			Kit.viewport(model, UDim2.fromScale(1, 1)).Parent = card.Preview
		end

		local function refresh(state: { [string]: any })
			local index = state.Index or {}
			local claimed = state.IndexClaimed or {}
			local discoveredCount = 0
			for _, def in Brainrots.List do
				local card = cards[def.Id]
				local discovered = index[BrainrotStats.IndexKey(def.Id, "None")] == true
				if discovered then
					discoveredCount += 1
				end
				card.Name.Text = if discovered then def.Name else "???"
				card.Name.TextColor3 = if discovered then Rarities.Get(def.Rarity).Color else Kit.Colors.Muted
				setPreview(card, def.Id, discovered)
				for mutationName, stamp in card.Stamps do
					stamp.BackgroundTransparency = if index[BrainrotStats.IndexKey(def.Id, mutationName)]
						then 0
						else 0.85
				end
			end
			header.Text = string.format(
				"Discovered %d / %d  ·  +%d%% cash from your Index",
				discoveredCount,
				#Brainrots.List,
				math.floor(discoveredCount * Economy.IndexBonusPerEntry * 100 + 0.5)
			)
			for rarityIndex, section in sections do
				local bucket = Brainrots.OfRarity(rarityIndex)
				local found = 0
				for _, def in bucket do
					if index[BrainrotStats.IndexKey(def.Id, "None")] then
						found += 1
					end
				end
				section.Progress.Text = string.format("%d / %d", found, #bucket)
				local isClaimed = claimed[tostring(rarityIndex)] == true
				if isClaimed then
					section.Claim.Text = "✅ Claimed"
					Kit.setButtonColor(section.Claim, Kit.Colors.Grey)
				else
					section.Claim.Text = "🎁 " .. Rewards.Describe(Rewards.IndexSets[rarityIndex])
					Kit.setButtonColor(section.Claim, if found >= #bucket then Kit.Colors.Green else Kit.Colors.Grey)
				end
			end
		end

		return { Refresh = refresh }
	end)
end

-- True when any completed rarity set is waiting to be claimed (drives the menu badge).
function IndexPanel.HasClaimable(state: { [string]: any }): boolean
	local index = state.Index or {}
	local claimed = state.IndexClaimed or {}
	for rarityIndex in Rewards.IndexSets do
		if not claimed[tostring(rarityIndex)] then
			local bucket = Brainrots.OfRarity(rarityIndex)
			local found = 0
			for _, def in bucket do
				if index[BrainrotStats.IndexKey(def.Id, "None")] then
					found += 1
				end
			end
			if #bucket > 0 and found >= #bucket then
				return true
			end
		end
	end
	return false
end

return IndexPanel
