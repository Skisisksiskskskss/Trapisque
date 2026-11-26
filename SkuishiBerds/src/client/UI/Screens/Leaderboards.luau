--[[
	Leaderboards: global top 50 for Solo best, Duo best and Versus wins.
]]

local Players = game:GetService("Players")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Net = require(UI.Parent.Core.Net)

local BOARDS = {
	{ key = "SoloBest", name = "Solo", stat = "soloBest" },
	{ key = "DuoBest", name = "Duo", stat = "duoBest" },
	{ key = "VersusWins", name = "Versus", stat = "versusWins" },
}

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Leaderboards" })
		Widgets.pad(frame, 10)
		Widgets.header(frame, "Leaderboards", function()
			App.go("Home")
		end)
		local tabs = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 46), position = UDim2.new(0, 0, 0, 68) })
		local mine = Widgets.label(frame, {
			text = "",
			size = UDim2.new(1, 0, 0, 28),
			position = UDim2.new(0, 0, 0, 120),
			font = Theme.FontBody,
			maxText = 20,
		})
		local scroll = Widgets.scroll(frame, { size = UDim2.new(1, 0, 1, -156), position = UDim2.new(0, 0, 0, 154) })

		local current = BOARDS[1]
		local tabButtons = {}

		local function load(board)
			current = board
			for k, b in tabButtons do
				b.BackgroundColor3 = if k == board.key then Theme.Yellow else Theme.White
			end
			for _, c in scroll:GetChildren() do
				c:Destroy()
			end
			Widgets.list(scroll, 6)
			Widgets.pad(scroll, 4)
			local loading = Widgets.label(
				scroll,
				{ text = "Loading...", size = UDim2.new(1, 0, 0, 40), font = Theme.FontBody, color = Theme.InkSoft }
			)
			local p = App.profile
			if p then
				mine.Text = "Your " .. board.name .. ": " .. tostring(p.stats[board.stat])
			end
			task.spawn(function()
				local result = Net.ask("Leaderboard", board.key)
				if current ~= board then
					return
				end
				loading:Destroy()
				local rows = result and result.rows or {}
				if #rows == 0 then
					Widgets.label(scroll, {
						text = if result and result.available == false
							then "Leaderboards need a published place with API access."
							else "No scores yet. Be the first!",
						size = UDim2.new(1, 0, 0, 50),
						font = Theme.FontBody,
						color = Theme.InkSoft,
						maxText = 18,
					})
				end
				for _, row in rows do
					local isMe = row.userId == Players.LocalPlayer.UserId
					local f = Widgets.frame(scroll, {
						color = if isMe then Theme.Yellow elseif row.rank <= 3 then Theme.Orange else Theme.White,
						size = UDim2.new(1, -8, 0, 46),
						round = 12,
						stroke = 2,
						order = row.rank,
					})
					Widgets.label(f, {
						text = "#" .. row.rank,
						size = UDim2.new(0, 56, 0.7, 0),
						position = UDim2.new(0, 8, 0.5, 0),
						anchor = Vector2.new(0, 0.5),
						maxText = 22,
					})
					Widgets.label(f, {
						text = row.name,
						size = UDim2.new(0.55, 0, 0.6, 0),
						position = UDim2.new(0, 70, 0.5, 0),
						anchor = Vector2.new(0, 0.5),
						alignX = Enum.TextXAlignment.Left,
						font = Theme.FontBody,
						maxText = 20,
					})
					Widgets.label(f, {
						text = tostring(row.value),
						size = UDim2.new(0.25, 0, 0.7, 0),
						position = UDim2.new(1, -12, 0.5, 0),
						anchor = Vector2.new(1, 0.5),
						alignX = Enum.TextXAlignment.Right,
						maxText = 24,
					})
				end
			end)
		end

		for i, board in BOARDS do
			tabButtons[board.key] = Widgets.button(tabs, {
				text = board.name,
				color = Theme.White,
				size = UDim2.new(0.32, 0, 1, 0),
				position = UDim2.new((i - 1) * 0.34, 0, 0, 0),
				strokeWidth = 2,
				maxText = 20,
				onClick = function()
					load(board)
				end,
			})
		end

		return {
			frame = frame,
			onShow = function()
				load(current)
			end,
		}
	end,
}
