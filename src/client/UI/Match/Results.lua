--[[
	Results
	End-of-match screen: who won, everyone's treasures, what you earned.

		local close = Results.show(layer, data, mySeat, isTeam, onLeave)
	data is the server's "match.end" payload.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)
local Sound = require(UI.Parent.Sound)

local C = Theme.C

local Results = {}

local PLACE = { "1st", "2nd", "3rd", "4th", "5th", "6th" }

local function row(list: Frame, i: number, r, mine: boolean, isTeam: boolean)
	local seatColor = Theme.Seat[((r.seat - 1) % 6) + 1]
	local f = Util.new("Frame", {
		Name = "Row" .. i,
		BackgroundColor3 = if mine then Color3.fromHex("FFF1C4") else Color3.fromHex("FBF3DD"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = i,
		Parent = list,
	})
	Util.corner(f, 10)
	Util.stroke(f, if r.won then C.brass else C.parchmentEdge, 2)
	Widgets.label(f, {
		text = PLACE[i] or tostring(i),
		font = "chunky",
		size = 22,
		color = if r.won then C.brassDark else C.inkSoft,
		align = "center",
		sizeUDim = UDim2.fromOffset(52, 52),
	})
	local pawn = Util.frame(f, { Position = UDim2.fromOffset(52, 6), Size = UDim2.fromOffset(40, 40) })
	CosmeticArt.pawn(pawn, r.look and r.look.pawn, seatColor, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	local charDef = Characters.get(r.character or "")
	local who = r.name .. (if mine then "  (you)" else "")
	local name = Widgets.label(f, {
		text = who,
		font = "heavy",
		size = 18,
		color = Theme.nameColor(r.look),
		sizeUDim = UDim2.new(1, -330, 0, 22),
		position = UDim2.fromOffset(102, 6),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = (if charDef then charDef.name else "")
	if isTeam and r.team then
		sub ..= "  ·  " .. (Theme.TeamName[r.team] or ("Team " .. r.team))
	end
	Widgets.label(f, {
		text = sub,
		font = "body",
		size = 14,
		color = Theme.Character[r.character] or C.inkSoft,
		sizeUDim = UDim2.new(1, -330, 0, 18),
		position = UDim2.fromOffset(102, 28),
	})
	-- treasures
	local chest = Util.frame(f, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(110, 30),
	})
	Util.list(chest, "x", 6, "Right", "Center")
	local icon = Util.frame(chest, { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 })
	Icons.make(icon, "chest", Icons.flatColors(C.brassDark, C.parchment))
	Widgets.label(chest, {
		text = "x" .. tostring(r.treasures),
		font = "chunky",
		size = 22,
		color = C.textDark,
		sizeUDim = UDim2.fromOffset(46, 30),
		layoutOrder = 2,
	})
	if r.won then
		Widgets.badge(f, {
			text = "WINNER",
			color = C.brass,
			stroke = C.brassDark,
			textColor = C.ink,
			height = 26,
			textSize = 15,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -10, 0.5, 0),
		})
	end
	Util.popIn(f, 0.3, 0.6)
	return f
end

function Results.show(layer: Instance, data, mySeat: number, isTeam: boolean, onLeave: () -> ()): () -> ()
	local me = nil
	for _, r in data.results do
		if r.seat == mySeat then
			me = r
		end
	end
	local won = me ~= nil and me.won
	local title = if won then "Victory!" elseif data.kind == "practice" then "Practice Over" else "Game Over"

	local content, close = Widgets.modal(layer, {
		title = title,
		titleWidth = 300,
		width = 720,
		height = 560,
		noClose = true,
	})
	Sound.play(if won then "win" else "treasure")

	-- why it ended
	local winners = {}
	for _, r in data.results do
		if r.won then
			table.insert(winners, r.name)
		end
	end
	local reason
	if data.reason == "rounds" then
		reason = "Out of rounds! Closest to the treasure wins: " .. table.concat(winners, ", ")
	elseif isTeam and data.winnerTeam then
		reason = (Theme.TeamName[data.winnerTeam] or "A team") .. " found every treasure!"
	else
		reason = table.concat(winners, ", ") .. " found every treasure!"
	end
	Widgets.label(content, {
		text = reason,
		font = "heavy",
		size = 18,
		color = C.inkSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 26),
	})

	-- standings
	local list = Util.frame(content, {
		Name = "Standings",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 6 * 58),
	})
	Util.list(list, "y", 6, "Center", "Top")
	local bySeat = {}
	for _, r in data.results do
		bySeat[r.seat] = r
	end
	local order = data.ranking or {}
	task.spawn(function()
		for i, seat in order do
			local r = bySeat[seat]
			if r then
				row(list, i, r, seat == mySeat, isTeam)
				task.wait(0.12)
			end
		end
	end)

	-- rewards
	local reward = data.reward
	local bottom = Util.frame(content, {
		Name = "Rewards",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56),
	})
	if reward then
		local chips = Util.frame(bottom, { Size = UDim2.new(1, -230, 1, 0) })
		Util.list(chips, "x", 10, "Left", "Center")
		local function chip(order: number, iconId: string, color: Color3, text: string)
			local holder = Util.frame(chips, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order })
			Util.list(holder, "x", 6, "Left", "Center")
			local ic = Util.frame(holder, { Size = UDim2.fromOffset(34, 34), LayoutOrder = 1 })
			Icons.medallion(ic, iconId, color, { Size = UDim2.fromScale(1, 1) })
			local l = Widgets.label(holder, {
				text = text,
				font = "chunky",
				size = 22,
				color = C.textDark,
				sizeUDim = UDim2.fromOffset(0, 34),
				layoutOrder = 2,
			})
			l.AutomaticSize = Enum.AutomaticSize.X
		end
		chip(1, "gem", C.neutral, "+" .. tostring(reward.gems))
		chip(2, "level", C.info, "+" .. tostring(reward.xp) .. " XP")
		if (reward.levelsGained or 0) > 0 then
			chip(3, "star", C.brassDark, "Level " .. tostring(reward.level) .. "!")
		end
		for i, b in reward.bonus or {} do
			Widgets.badge(chips, { text = b, color = C.good, height = 26, textSize = 14, layoutOrder = 10 + i })
		end
	end
	local leave = Widgets.button(bottom, {
		text = "LOBBY",
		icon = "back",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(210, 52),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		onClick = function()
			close()
			onLeave()
		end,
	})
	-- the server sends everyone home after a while; show how long
	local endsAt = os.clock() + (data.resultsTime or 25)
	task.spawn(function()
		while leave.root.Parent do
			local left = math.max(0, math.ceil(endsAt - os.clock()))
			leave:setText("LOBBY (" .. left .. ")")
			task.wait(0.5)
		end
	end)
	return close
end

return Results
