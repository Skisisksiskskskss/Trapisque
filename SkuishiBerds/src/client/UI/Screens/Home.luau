--[[
	Home: title screen. Squishy SKUISHI BERDS logo (original menu), PLAY, and
	the hub buttons.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Images = require(Shared.Config.Images)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Home" })
		Widgets.pad(frame, 12)

		-- top pills: coins + level
		local top = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 44) })
		local coins =
			Widgets.frame(top, { color = Theme.White, size = UDim2.new(0.44, 0, 1, 0), round = 22, stroke = 3 })
		local coinText = Widgets.label(coins, {
			text = "0",
			size = UDim2.new(0.8, 0, 0.7, 0),
			position = UDim2.fromScale(0.55, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			maxText = 26,
		})
		local coinIcon = Widgets.frame(coins, {
			color = Theme.Coin,
			size = UDim2.fromOffset(26, 26),
			position = UDim2.new(0, 10, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			round = 13,
			stroke = 2,
		})
		if Images.CoinIcon ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = Images.CoinIcon
			img.Parent = coinIcon
		end
		local level = Widgets.frame(top, {
			color = Theme.Blue,
			size = UDim2.new(0.3, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			round = 22,
			stroke = 3,
		})
		local levelText = Widgets.label(level, {
			text = "Lv 1",
			size = UDim2.new(0.8, 0, 0.7, 0),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			maxText = 24,
		})

		-- logo
		local logo = Widgets.frame(frame, { size = UDim2.new(1, 0, 0.26, 0), position = UDim2.new(0, 0, 0, 70) })
		local logoScale = Instance.new("UIScale")
		logoScale.Parent = logo
		if Images.Logo ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.ScaleType = Enum.ScaleType.Fit
			img.Image = Images.Logo
			img.Parent = logo
		else
			for i, word in { "SKUISHI", "BERDS" } do
				local t = Widgets.label(logo, {
					text = word,
					size = UDim2.new(1, 0, 0.48, 0),
					position = UDim2.new(0, 0, (i - 1) * 0.5, 0),
					font = Theme.FontTitle,
					color = Theme.White,
					strokeColor = Theme.Ink,
					strokeThickness = 5,
					maxText = 90,
				})
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.Pink),
					ColorSequenceKeypoint.new(0.5, Theme.Mint),
					ColorSequenceKeypoint.new(1, Theme.Blue),
				})
				g.Rotation = 90
				g.Parent = t
			end
		end

		-- buttons
		local buttons = Widgets.frame(frame, { size = UDim2.new(1, 0, 0.52, 0), position = UDim2.new(0, 0, 0.4, 0) })
		Widgets.list(buttons, 12)
		local play = Widgets.button(buttons, {
			text = "PLAY",
			color = Theme.Yellow,
			size = UDim2.new(0.86, 0, 0, 84),
			order = 1,
			maxText = 48,
			strokeWidth = 4,
			onClick = function()
				App.go("Play")
			end,
		})
		if Images.PlayButton ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = Images.PlayButton
			img.ZIndex = 2
			img.Parent = play
		end
		local row1 = Widgets.frame(buttons, { size = UDim2.new(0.86, 0, 0, 64), order = 2 })
		Widgets.button(row1, {
			text = "Birds & Looks",
			color = Theme.Pink,
			size = UDim2.new(0.485, 0, 1, 0),
			onClick = function()
				App.go("Look")
			end,
		})
		Widgets.button(row1, {
			text = "Shop",
			color = Theme.Mint,
			size = UDim2.new(0.485, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			onClick = function()
				App.go("Shop")
			end,
		})
		local row2 = Widgets.frame(buttons, { size = UDim2.new(0.86, 0, 0, 64), order = 3 })
		Widgets.button(row2, {
			text = "Leaderboards",
			color = Theme.Blue,
			size = UDim2.new(0.485, 0, 1, 0),
			onClick = function()
				App.go("Leaderboards")
			end,
		})
		Widgets.button(row2, {
			text = "Event Journal",
			color = Theme.Purple,
			size = UDim2.new(0.485, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			onClick = function()
				App.go("Journal")
			end,
		})
		Widgets.button(buttons, {
			text = "Settings",
			color = Theme.White,
			size = UDim2.new(0.5, 0, 0, 50),
			order = 4,
			onClick = function()
				App.go("Settings")
			end,
		})

		local footer = Widgets.label(frame, {
			text = "",
			size = UDim2.new(1, 0, 0, 22),
			position = UDim2.new(0, 0, 1, -22),
			font = Theme.FontBody,
			color = Theme.InkSoft,
			maxText = 16,
		})

		local function refresh(p)
			if not p then
				return
			end
			coinText.Text = tostring(p.coins)
			levelText.Text = "Lv " .. tostring(p.level or 1)
			footer.Text = string.format(
				"Solo best %d  ·  Duo best %d  ·  Versus wins %d  ·  v%s",
				p.stats.soloBest,
				p.stats.duoBest,
				p.stats.versusWins,
				GameConfig.VERSION
			)
		end
		App.ProfileChanged:Connect(refresh)

		local conn
		return {
			frame = frame,
			onShow = function()
				refresh(App.profile)
				conn = RunService.RenderStepped:Connect(function()
					local t = os.clock()
					logoScale.Scale = 1 + math.sin(t * 4) * 0.04
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
