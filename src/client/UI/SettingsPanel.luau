--!strict
-- Settings: music and sound effect toggles (saved to the player's profile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Kit = require(script.Parent.Kit)
local Panels = require(script.Parent.Panels)

local SettingsPanel = {}

function SettingsPanel.Register()
	Panels.Register("Settings", "⚙️ Settings", Vector2.new(460, 300), function(content)
		Kit.list(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top).Parent =
			content
		local toggles: { [string]: TextButton } = {}
		local values: { [string]: boolean } = { Music = true, Sfx = true }
		for order, entry in { { Key = "Music", Label = "🎵 Music" }, { Key = "Sfx", Label = "🔊 Sound Effects" } } do
			local row = Kit.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -20, 0, 60),
				BackgroundTransparency = 1,
				Parent = content,
			})
			Kit.label({
				Text = entry.Label,
				Size = UDim2.new(0.6, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 28,
				Parent = row,
			})
			local key = entry.Key
			toggles[key] = Kit.button({
				Text = "ON",
				Color = Kit.Colors.Green,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(120, 50),
				Parent = row,
				OnClick = function()
					values[key] = not values[key]
					Net.Event("Settings"):FireServer(key, values[key])
				end,
			})
		end
		Kit.label({
			LayoutOrder = 10,
			Text = "Beam a Brainrot · made with love",
			Size = UDim2.new(1, -20, 0, 24),
			TextColor3 = Kit.Colors.Muted,
			MaxTextSize = 18,
			Parent = content,
		})

		local function refresh(state: { [string]: any })
			local settings = state.Settings or {}
			for key, button in toggles do
				local on = settings[key] ~= false
				values[key] = on
				button.Text = if on then "ON" else "OFF"
				Kit.setButtonColor(button, if on then Kit.Colors.Green else Kit.Colors.Grey)
			end
		end
		return { Refresh = refresh }
	end)
end

return SettingsPanel
