--[[
	Settings: volumes, screen shake, event text, and the controls cheat sheet.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Net = require(UI.Parent.Core.Net)
local Audio = require(UI.Parent.Core.Audio)

local CONTROLS = [[<b>Solo / online</b>
Flap: tap, click, Space, W or Up (gamepad A / R2)
Ability: E, Q, Shift, S or Down, right-click (gamepad X / L2), or the ability button

<b>Couch (one device)</b>
Phone: top half = Player 1 (top bird), bottom half = Player 2
Keyboard: P1 = W / S, P2 = Up / Down
Two gamepads: one each. One gamepad: L1/L2 = P1, R1/R2 = P2

Abilities charge by strumming (crossing the middle line).]]

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Settings" })
		Widgets.pad(frame, 10)
		Widgets.header(frame, "Settings", function()
			App.go("Home")
		end)
		local body = Widgets.scroll(frame, { size = UDim2.new(1, 0, 1, -72), position = UDim2.new(0, 0, 0, 72) })
		Widgets.list(body, 10)
		Widgets.pad(body, 6)

		local settings = { music = 0.5, sfx = 0.8, shake = true, eventText = true }
		local rows = {}

		local function save()
			Audio.setVolumes(settings.music, settings.sfx)
			Net.ask("Settings", settings)
		end

		local function stepRow(label: string, key: string, order: number)
			local row = Widgets.frame(body, { size = UDim2.new(1, -8, 0, 92), order = order })
			Widgets.label(
				row,
				{ text = label, size = UDim2.new(1, 0, 0, 30), alignX = Enum.TextXAlignment.Left, maxText = 22 }
			)
			local buttons = {}
			for i, v in { 0, 0.25, 0.5, 0.75, 1 } do
				buttons[i] = Widgets.button(row, {
					text = math.floor(v * 100) .. "%",
					color = Theme.White,
					size = UDim2.new(0.18, 0, 0, 48),
					position = UDim2.new((i - 1) * 0.205, 0, 0, 38),
					strokeWidth = 2,
					maxText = 16,
					onClick = function()
						settings[key] = v
						save()
						for k, b in buttons do
							b.BackgroundColor3 = if k == i then Theme.Yellow else Theme.White
						end
					end,
				})
			end
			rows[key] = function()
				for k, b in buttons do
					local v = ({ 0, 0.25, 0.5, 0.75, 1 })[k]
					b.BackgroundColor3 = if math.abs(v - settings[key]) < 0.01 then Theme.Yellow else Theme.White
				end
			end
		end

		local function toggleRow(label: string, key: string, order: number)
			local btn
			btn = Widgets.button(body, {
				text = label .. ": ON",
				color = Theme.Mint,
				size = UDim2.new(1, -8, 0, 56),
				order = order,
				maxText = 22,
				onClick = function()
					settings[key] = not settings[key]
					save()
					rows[key]()
				end,
			})
			rows[key] = function()
				Widgets.setText(btn, label .. ": " .. (if settings[key] then "ON" else "OFF"))
				btn.BackgroundColor3 = if settings[key] then Theme.Mint else Theme.White
			end
		end

		stepRow("Music", "music", 1)
		stepRow("Sound effects", "sfx", 2)
		toggleRow("Screen shake", "shake", 3)
		toggleRow("Event names on screen", "eventText", 4)

		local help = Widgets.frame(
			body,
			{ color = Theme.White, size = UDim2.new(1, -8, 0, 250), round = 14, stroke = 2, order = 5 }
		)
		Widgets.label(help, {
			text = CONTROLS,
			rich = true,
			size = UDim2.new(1, -20, 1, -20),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			font = Theme.FontBody,
			color = Theme.Ink,
			alignX = Enum.TextXAlignment.Left,
			alignY = Enum.TextYAlignment.Top,
			maxText = 15,
		})

		return {
			frame = frame,
			onShow = function()
				local p = App.profile
				if p and p.settings then
					for k, v in p.settings do
						settings[k] = v
					end
				end
				for _, fn in rows do
					fn()
				end
			end,
		}
	end,
}
