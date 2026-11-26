--[[
	Journal: every event you've discovered (each first discovery pays 50 coins),
	with a PRACTICE button that starts a Solo run in the Event Lab with that
	event on repeat (the original's TEST EVENT menu, earned instead of free).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Journal" })
		Widgets.pad(frame, 10)
		Widgets.header(frame, "Event Journal", function()
			App.go("Home")
		end)
		local progress = Widgets.label(frame, {
			text = "",
			size = UDim2.new(1, 0, 0, 26),
			position = UDim2.new(0, 0, 0, 66),
			font = Theme.FontBody,
			maxText = 18,
		})
		local scroll = Widgets.scroll(frame, { size = UDim2.new(1, 0, 1, -100), position = UDim2.new(0, 0, 0, 98) })

		local function render()
			for _, c in scroll:GetChildren() do
				c:Destroy()
			end
			Widgets.pad(scroll, 6)
			Widgets.grid(scroll, UDim2.new(0.5, -8, 0, 128), 8)
			local p = App.profile
			local found = 0
			for i, meta in Events.List do
				local known = p ~= nil and p.discovered[meta.name] == true
				if known then
					found += 1
				end
				local color = Color3.fromHex(meta.color)
				local card = Widgets.frame(scroll, {
					color = if known then Theme.White else Theme.PaperDark,
					round = 14,
					stroke = 3,
					strokeColor = if known then color else Theme.InkSoft,
					order = i,
				})
				Widgets.label(card, {
					text = if known then meta.display else "???",
					size = UDim2.new(1, -12, 0, 28),
					position = UDim2.new(0.5, 0, 0, 6),
					anchor = Vector2.new(0.5, 0),
					color = if known then color else Theme.InkSoft,
					strokeColor = if known then Theme.Ink else nil,
					strokeThickness = 1,
					maxText = 22,
				})
				Widgets.label(card, {
					text = if known then meta.blurb else "Keep playing to discover this event.",
					size = UDim2.new(1, -12, 0, 44),
					position = UDim2.new(0.5, 0, 0, 36),
					anchor = Vector2.new(0.5, 0),
					font = Theme.FontHand,
					color = Theme.InkSoft,
					maxText = 15,
				})
				if known then
					Widgets.button(card, {
						text = "Practice",
						color = Theme.Mint,
						size = UDim2.new(0.8, 0, 0, 36),
						position = UDim2.new(0.5, 0, 1, -8),
						anchor = Vector2.new(0.5, 1),
						strokeWidth = 2,
						maxText = 18,
						onClick = function()
							App.lastQueue = { mode = "SOLO", opts = { labEvent = meta.name } }
							App.queue("SOLO", { labEvent = meta.name })
						end,
					})
				end
			end
			progress.Text =
				string.format("%d / %d discovered  ·  practice runs don't give rewards", found, Events.Count)
		end

		App.ProfileChanged:Connect(function()
			if App.current == "Journal" then
				render()
			end
		end)

		return {
			frame = frame,
			onShow = render,
		}
	end,
}
