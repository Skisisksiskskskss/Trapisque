--[[
	Play: pick a mode. Online modes have a "couch team" toggle so two people on
	one device can join Duos/Versus together.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Modes = require(Shared.Config.Modes)
local Images = require(Shared.Config.Images)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Play" })
		Widgets.pad(frame, 10)
		Widgets.header(frame, "Choose a mode", function()
			App.go("Home")
		end)

		local scroll = Widgets.scroll(frame, { size = UDim2.new(1, 0, 1, -72), position = UDim2.new(0, 0, 0, 72) })
		Widgets.list(scroll, 12)
		Widgets.pad(scroll, 6)

		local couchToggles = {}
		local bests = {}
		local list = {}
		for _, m in Modes do
			table.insert(list, m)
		end
		table.sort(list, function(a, b)
			return a.order < b.order
		end)

		for _, mode in list do
			local card = Widgets.frame(scroll, {
				color = Theme.White,
				size = UDim2.new(1, -8, 0, if mode.online then 150 else 108),
				round = 18,
				stroke = 3,
				order = mode.order,
			})
			local accent = Widgets.frame(card, {
				color = Theme.ModeColors[mode.id],
				size = UDim2.new(0, 14, 1, -16),
				position = UDim2.new(0, 8, 0, 8),
				round = 7,
			})
			local icon = Images.ModeIcons[mode.id]
			if icon and icon ~= "" then
				accent.Size = UDim2.fromOffset(64, 64)
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Size = UDim2.fromScale(1, 1)
				img.Image = icon
				img.Parent = accent
			end
			Widgets.label(card, {
				text = mode.name,
				size = UDim2.new(0.6, 0, 0, 36),
				position = UDim2.new(0, 32, 0, 10),
				alignX = Enum.TextXAlignment.Left,
				maxText = 30,
			})
			Widgets.label(card, {
				text = mode.tagline,
				size = UDim2.new(0.6, 0, 0, 40),
				position = UDim2.new(0, 32, 0, 48),
				font = Theme.FontBody,
				color = Theme.InkSoft,
				alignX = Enum.TextXAlignment.Left,
				alignY = Enum.TextYAlignment.Top,
				maxText = 16,
			})
			bests[mode.id] = Widgets.label(card, {
				text = "",
				size = UDim2.new(0.6, 0, 0, 18),
				position = UDim2.new(0, 32, 0, 86),
				font = Theme.FontBody,
				color = Theme.InkSoft,
				alignX = Enum.TextXAlignment.Left,
				maxText = 14,
			})
			local couchOn = false
			if mode.online then
				local toggle
				toggle = Widgets.button(card, {
					text = "Couch team: OFF",
					color = Theme.PaperDark,
					size = UDim2.new(0.55, 0, 0, 34),
					position = UDim2.new(0, 32, 1, -44),
					maxText = 16,
					strokeWidth = 2,
					onClick = function()
						couchOn = not couchOn
						Widgets.setText(
							toggle,
							if couchOn then "Couch team: ON (2 on this device)" else "Couch team: OFF"
						)
						toggle.BackgroundColor3 = if couchOn then Theme.Mint else Theme.PaperDark
					end,
				})
				couchToggles[mode.id] = function()
					return couchOn
				end
			end
			Widgets.button(card, {
				text = if mode.online then "FIND" else "GO",
				color = Theme.ModeColors[mode.id],
				size = UDim2.new(0.3, 0, 0, 58),
				position = UDim2.new(1, -12, 0, 22),
				anchor = Vector2.new(1, 0),
				maxText = 30,
				onClick = function()
					local couch = couchToggles[mode.id] and couchToggles[mode.id]() or false
					App.lastQueue = { mode = mode.id, opts = { couch = couch } }
					App.queue(mode.id, { couch = couch })
				end,
			})
		end

		local function refresh(p)
			if not p then
				return
			end
			bests.SOLO.Text = "Best: " .. p.stats.soloBest
			bests.COUCH_COOP.Text = "Duo best: " .. p.stats.duoBest
			bests.DUOS.Text = "Duo best: " .. p.stats.duoBest
			bests.VERSUS.Text = "Wins: " .. p.stats.versusWins
			bests.BOT.Text = "Your bird + an AI partner on top"
			bests.COUCH_DUEL.Text = "Top player vs bottom player"
		end
		App.ProfileChanged:Connect(refresh)

		return {
			frame = frame,
			onShow = function()
				refresh(App.profile)
			end,
		}
	end,
}
