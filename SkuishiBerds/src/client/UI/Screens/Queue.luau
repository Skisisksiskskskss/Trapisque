--[[
	Queue: waiting for other birds (bots fill in if the server is quiet).
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Modes = require(Shared.Config.Modes)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Net = require(UI.Parent.Core.Net)

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Queue" })
		Widgets.pad(frame, 16)
		local title = Widgets.label(frame, {
			text = "Finding birds...",
			size = UDim2.new(1, 0, 0, 56),
			position = UDim2.new(0, 0, 0.18, 0),
			maxText = 44,
		})
		local status = Widgets.label(frame, {
			text = "",
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.new(0, 0, 0.18, 64),
			font = Theme.FontBody,
			color = Theme.InkSoft,
			maxText = 20,
		})
		local spinner = Widgets.frame(frame, {
			color = Theme.Pink,
			size = UDim2.fromOffset(70, 70),
			position = UDim2.fromScale(0.5, 0.55),
			anchor = Vector2.new(0.5, 0.5),
			round = 35,
			stroke = 3,
		})
		Widgets.frame(spinner, {
			color = Theme.White,
			size = UDim2.fromScale(0.3, 0.3),
			position = UDim2.fromScale(0.62, 0.3),
			round = 20,
			stroke = 2,
		})
		Widgets.button(frame, {
			text = "Cancel",
			color = Theme.White,
			size = UDim2.new(0.6, 0, 0, 60),
			position = UDim2.fromScale(0.5, 0.85),
			anchor = Vector2.new(0.5, 0.5),
			onClick = function()
				Net.send("Leave")
				App.go("Play")
			end,
		})

		local conn
		local screen = {
			frame = frame,
			onShow = function(args)
				local mode = args and Modes[args.mode]
				title.Text = if mode then mode.name .. ": finding birds..." else "Finding birds..."
				status.Text = "Waiting for players. Bots fill in if it's quiet."
				conn = RunService.RenderStepped:Connect(function()
					local t = os.clock()
					spinner.Position = UDim2.new(0.5, 0, 0.55, -math.abs(math.sin(t * 4)) * 40)
					spinner.Rotation = math.sin(t * 2) * 12
				end)
			end,
			onHide = function()
				if conn then
					conn:Disconnect()
				end
			end,
		}
		function screen.setStatus(st)
			if not st then
				return
			end
			if st.birds then
				status.Text = string.format("%d bird(s) waiting. Bots fill in in %ds.", st.birds, st.fillIn or 0)
			else
				status.Text = "Looking for a partner. A bot partner joins after 20s."
			end
		end
		return screen
	end,
}
