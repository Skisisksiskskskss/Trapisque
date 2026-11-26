--[[
	Results: score / placement, rewards, play again.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Modes = require(Shared.Config.Modes)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Audio = require(UI.Parent.Core.Audio)

local function ordinal(n: number): string
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return tostring(n) .. suffix
end

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Results" })
		Widgets.pad(frame, 14)
		local card = Widgets.frame(frame, {
			color = Theme.White,
			size = UDim2.new(1, 0, 0.78, 0),
			position = UDim2.fromScale(0.5, 0.42),
			anchor = Vector2.new(0.5, 0.5),
			round = 22,
			stroke = 4,
		})
		local title = Widgets.label(card, {
			text = "",
			size = UDim2.new(0.9, 0, 0, 60),
			position = UDim2.new(0.05, 0, 0, 16),
			maxText = 52,
			strokeColor = Theme.White,
			strokeThickness = 2,
		})
		local score = Widgets.label(
			card,
			{ text = "", size = UDim2.new(0.9, 0, 0, 90), position = UDim2.new(0.05, 0, 0, 82), maxText = 80 }
		)
		local best = Widgets.label(card, {
			text = "",
			size = UDim2.new(0.9, 0, 0, 30),
			position = UDim2.new(0.05, 0, 0, 176),
			color = Color3.fromHex("#e1a100"),
			maxText = 26,
		})
		local rewards = Widgets.label(card, {
			text = "",
			size = UDim2.new(0.9, 0, 0, 30),
			position = UDim2.new(0.05, 0, 0, 212),
			font = Theme.FontBody,
			maxText = 22,
		})
		local list = Widgets.frame(card, { size = UDim2.new(0.9, 0, 1, -270), position = UDim2.new(0.05, 0, 0, 252) })
		Widgets.list(list, 4)

		-- Versus has no big score number: pull rewards and standings up under the title
		local function setCompact(compact: boolean)
			rewards.Position = UDim2.new(0.05, 0, 0, if compact then 84 else 212)
			list.Position = UDim2.new(0.05, 0, 0, if compact then 126 else 252)
			list.Size = UDim2.new(0.9, 0, 1, if compact then -144 else -270)
		end

		local buttons = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 70), position = UDim2.new(0, 0, 1, -70) })
		Widgets.button(buttons, {
			text = "Menu",
			color = Theme.White,
			size = UDim2.new(0.38, 0, 1, 0),
			onClick = function()
				App.go("Home")
			end,
		})
		Widgets.button(buttons, {
			text = "Play again",
			color = Theme.Yellow,
			size = UDim2.new(0.58, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			onClick = function()
				local q = App.lastQueue
				if q then
					App.queue(q.mode, q.opts)
				else
					App.go("Play")
				end
			end,
		})

		return {
			frame = frame,
			onShow = function(summary)
				for _, c in list:GetChildren() do
					if not c:IsA("UIListLayout") then
						c:Destroy()
					end
				end
				best.Text = ""
				rewards.Text = ""
				setCompact(false)
				if not summary then
					title.Text = "You left the match"
					score.Text = ""
					return
				end
				if summary.error then
					title.Text = "Match ended early"
					score.Text = tostring(summary.score or 0)
					return
				end
				local mode = Modes[summary.mode]
				if mode and mode.versus then
					setCompact(true)
					local place = summary.placement
					title.Text = if place == 1
						then "VICTORY!"
						elseif place then ordinal(place) .. " place"
						else "Round over"
					score.Text = ""
					if mode.couch and not mode.online then
						-- couch duel: both birds are on this device, so say which side won
						local winner = summary.placements and summary.placements[1]
						title.Text = "Round over"
						for _, b in summary.birds or {} do
							if winner ~= nil and b.team == winner then
								local side = if string.find(b.name, "(P1)", 1, true)
									then "PLAYER 1"
									elseif string.find(b.name, "(P2)", 1, true) then "PLAYER 2"
									else b.name
								title.Text = side .. " WINS!"
							end
						end
						Audio.play("ui_win", 1, 0.9)
					elseif place == 1 then
						Audio.play("ui_win", 1, 0.9)
					end
					-- standings
					for i, team in summary.placements or {} do
						local names = {}
						for _, b in summary.birds do
							if b.team == team then
								table.insert(names, b.name .. "  ·  " .. b.strums .. " strums")
							end
						end
						Widgets.label(list, {
							text = ordinal(i) .. "  " .. table.concat(names, " + "),
							size = UDim2.new(1, 0, 0, 26),
							font = Theme.FontBody,
							alignX = Enum.TextXAlignment.Left,
							color = if i == 1 then Theme.Good else Theme.Ink,
							order = i,
							maxText = 18,
						})
					end
				else
					title.Text = if summary.practice then "Practice over" else "GAME OVER"
					score.Text = tostring(summary.score)
					if summary.newBest then
						best.Text = "NEW HIGHSCORE!"
						Audio.play("ui_win", 1.1, 0.8)
					end
				end
				if not summary.practice then
					local text = string.format("+%d coins   +%d XP", summary.coins or 0, summary.xp or 0)
					if summary.levelUp then
						text ..= string.format("   LEVEL UP! Lv %d", summary.level)
					end
					rewards.Text = text
				else
					rewards.Text = "Event Lab runs don't give rewards"
				end
			end,
		}
	end,
}
