--[[
	Results
	End-of-match screen: who won, everyone's treasures and their award for how they
	played (Shared/Game/Awards), and what you earned: Gems and XP, your character's mastery, daily quests that moved,
	and trophies from ranked games.

		local close = Results.show(layer, data, mySeat, isTeam, onLeave, onRematch?)
	data is the server's "match.end" payload. On a narrow screen the rows drop the
	WINNER badge for a sun rim and the rewards stack above the buttons. onRematch: the
	Rematch button asks for the same table again (it starts once everyone still there
	has asked; the button counts the votes).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)
local Layout = require(UI.Layout)
local Sound = require(UI.Parent.Sound)
local Net = require(UI.Parent.Net)

local C = Theme.C

local Results = {}

local PLACE = { "1st", "2nd", "3rd", "4th", "5th", "6th" }

local function row(list: Frame, i: number, r, mine: boolean, isTeam: boolean, narrow: boolean)
	local seatColor = Theme.seatColor(r.seat)
	local f = Util.new("Frame", {
		Name = "Row" .. i,
		BackgroundColor3 = if mine then C.mine else C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = i,
		Parent = list,
	})
	Util.corner(f, 10)
	Util.stroke(f, if r.won then C.sun else C.line, 2.5)
	Widgets.label(f, {
		text = PLACE[i] or tostring(i),
		font = "chunky",
		size = 22,
		color = if r.won then C.sun else C.textSoft,
		align = "center",
		sizeUDim = UDim2.fromOffset(52, 52),
	})
	-- the player's avatar in their seat colour (bots get their character's medallion)
	Avatars.portrait(f, { userId = r.userId, character = r.character, isBot = r.isBot }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 52, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
	}, { back = seatColor, ring = C.line, ringPx = 3 })
	local charDef = Characters.get(r.character or "")
	local who = r.name .. (if mine then "  (you)" else "")
	-- room on the right for the treasure count (and the WINNER badge and award when there's space)
	local award = r.award
	local right = if narrow then 84 elseif award then 390 else 360
	local name = Widgets.label(f, {
		text = who,
		font = "heavy",
		size = if narrow then 16 else 18,
		color = Theme.nameColor(r.look),
		sizeUDim = UDim2.new(1, -(102 + right), 0, 22),
		position = UDim2.fromOffset(102, 5),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = (if r.username and not r.isBot then ("@" .. r.username .. "  ·  ") else "") .. (if charDef then charDef.name else "")
	if isTeam and r.team then
		sub ..= "  ·  " .. (Theme.TeamName[r.team] or ("Team " .. r.team))
	end
	if award and narrow then
		-- (no room for the award's ribbon: its name leads the line instead)
		sub = '<font color="#' .. C.sunDark:ToHex() .. '">' .. award.name .. "</font>  ·  " .. (if charDef then charDef.name else "")
	end
	local subLabel = Widgets.label(f, {
		text = sub,
		font = "body",
		size = if narrow then 12 else 14,
		color = C.textSoft,
		rich = true,
		sizeUDim = UDim2.new(1, -(102 + right), 0, 18),
		position = UDim2.fromOffset(102, 28),
	})
	subLabel.TextTruncate = Enum.TextTruncate.AtEnd
	-- treasures
	local chest = Util.frame(f, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, if narrow then -8 else -96, 0.5, 0),
		Size = UDim2.fromOffset(if narrow then 76 else 110, 30),
	})
	Util.list(chest, "x", 6, "Right", "Center")
	local icon = Util.frame(chest, { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 })
	Icons.medallion(icon, "chest", C.sun, { Size = UDim2.fromScale(1, 1) })
	Widgets.label(chest, {
		text = "x" .. tostring(r.treasures),
		font = "chunky",
		size = 22,
		color = C.text,
		sizeUDim = UDim2.fromOffset(46, 30),
		layoutOrder = 2,
	})
	-- their award for how they played, on a ribbon (wide screens)
	local st = r.stats or {}
	if award and not narrow then
		local ribbon = Util.new("Frame", {
			Name = "Award",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -212, 0.5, 0),
			Size = UDim2.fromOffset(172, 42),
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			Parent = f,
		})
		Util.corner(ribbon, 10)
		Util.stroke(ribbon, C.sun, 2)
		local ic = Util.frame(ribbon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
		})
		Icons.medallion(ic, award.icon or "star", C.sun, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(ribbon, {
			text = award.name,
			font = "chunky",
			size = 15,
			color = C.text,
			sizeUDim = UDim2.new(1, -46, 0, 19),
			position = UDim2.fromOffset(42, 3),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		Widgets.label(ribbon, {
			text = award.text or "",
			font = "body",
			size = 11,
			minSize = 8,
			scaled = true,
			color = C.textSoft,
			sizeUDim = UDim2.new(1, -46, 0, 15),
			position = UDim2.fromOffset(42, 22),
		})
	elseif not narrow and ((st.bonks or 0) + (st.gotchas or 0)) > 0 then
		local moments = Util.frame(f, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -212, 0.5, 0),
			Size = UDim2.fromOffset(110, 30),
		})
		Util.list(moments, "x", 6, "Right", "Center")
		local function moment(iconId: string, color: Color3, n: number, order: number)
			if n <= 0 then
				return
			end
			local box = Util.frame(moments, { Size = UDim2.fromOffset(48, 26), LayoutOrder = order })
			local ic = Util.frame(box, { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(0, 1) })
			Icons.medallion(ic, iconId, color, { Size = UDim2.fromScale(1, 1) })
			Widgets.label(box, {
				text = "x" .. n,
				font = "chunky",
				size = 16,
				color = C.text,
				sizeUDim = UDim2.fromOffset(24, 26),
				position = UDim2.fromOffset(26, 0),
			})
		end
		moment("star", C.sun, st.bonks or 0, 1)
		moment("token_trap", C.coral, st.gotchas or 0, 2)
	end
	if r.won and not narrow then
		Widgets.badge(f, {
			text = "Winner",
			color = C.sun,
			stroke = C.line,
			textColor = C.textOnLight,
			height = 26,
			textSize = 15,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -10, 0.5, 0),
		})
	end
	Util.popIn(f, 0.3, 0.6)
	return f
end

function Results.show(layer: Instance, data, mySeat: number, isTeam: boolean, onLeave: () -> (), onRematch: (() -> ())?): () -> ()
	local me = nil
	for _, r in data.results do
		if r.seat == mySeat then
			me = r
		end
	end
	local won = me ~= nil and me.won
	local title = if won then "Victory!" elseif data.kind == "practice" then "Practice over" else "Game over"

	local m = Widgets.metrics
	local width = math.min(760, Layout.safeRect(m, if m.form == "wide" then 16 else 6).w)
	local narrow = width < 600
	-- the rewards get a row of their own above the buttons: on a narrow screen, or when
	-- there are two buttons (Rematch and Lobby)
	local stack = narrow or onRematch ~= nil
	local seats = #data.results
	local reward = data.reward
	local cardsH = if reward then (if narrow then 3 * 46 + 12 else 104) else 0
	local content, close = Widgets.modal(layer, {
		title = title,
		titleWidth = math.min(300, width - 60),
		width = width,
		height = (if narrow then 260 elseif stack then 246 else 190) + seats * 58 + cardsH,
		noClose = true,
	})
	-- (the win or lose jingle already played as the game ended)
	Sound.play("coins")

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
		size = if narrow then 15 else 18,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, if narrow then 40 else 26),
	})

	-- standings
	local list = Util.frame(content, {
		Name = "Standings",
		Position = UDim2.fromOffset(0, if narrow then 46 else 34),
		Size = UDim2.new(1, 0, 0, seats * 58),
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
				row(list, i, r, seat == mySeat, isTeam, narrow)
				task.wait(0.12)
			end
		end
	end)

	-- what this match did for you: mastery, quests, trophies
	if reward then
		local cards = Util.frame(content, {
			Name = "Progress",
			Position = UDim2.fromOffset(0, (if narrow then 46 else 34) + seats * 58 + 8),
			Size = UDim2.new(1, 0, 0, cardsH - 8),
		})
		Util.list(cards, if narrow then "y" else "x", 8, "Center", "Top")
		local count = 0
		local function card(order: number): Frame
			count += 1
			local f = Util.new("Frame", {
				Name = "Card" .. order,
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				Size = if narrow then UDim2.new(1, 0, 0, 42) else UDim2.new(1 / 3, -6, 1, 0),
				LayoutOrder = order,
				Parent = cards,
			})
			Util.corner(f, 10)
			Util.stroke(f, C.line, 2.5)
			Util.popIn(f, 0.3, 0.4 + order * 0.15)
			return f
		end
		-- character mastery
		local mastery = reward.mastery
		if mastery then
			local f = card(1)
			local cdef = Characters.get(mastery.character)
			local ps = if narrow then 34 else 44
			local ic = Util.frame(f, { Position = UDim2.fromOffset(6, if narrow then 4 else 8), Size = UDim2.fromOffset(ps, ps) })
			Icons.medallion(ic, mastery.character, Theme.Character[mastery.character] or C.grape, { Size = UDim2.fromScale(1, 1) })
			local up = (mastery.levelsGained or 0) > 0
			Widgets.label(f, {
				text = (if cdef then cdef.name else "") .. " Lv " .. tostring(mastery.level) .. (if up then "  Level up!" else ""),
				font = "chunky",
				size = if narrow then 15 else 17,
				color = if up then C.sun else C.text,
				sizeUDim = UDim2.new(1, -(ps + 16), 0, 20),
				position = UDim2.fromOffset(ps + 12, if narrow then 2 else 8),
			}).TextTruncate = Enum.TextTruncate.AtEnd
			local bar = Widgets.progress(f, {
				size = UDim2.new(1, -(ps + 70), 0, 12),
				position = UDim2.fromOffset(ps + 12, if narrow then 26 else 34),
				value = 0,
				color = Theme.Character[mastery.character] or C.sky,
			})
			local frac = if mastery.need then (mastery.into / math.max(1, mastery.need)) else 1
			task.delay(0.6, function()
				bar:set(frac)
			end)
			Widgets.label(f, {
				text = "+" .. tostring(mastery.xp),
				font = "chunky",
				size = 15,
				color = C.textSoft,
				align = "right",
				sizeUDim = UDim2.fromOffset(52, 18),
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -8, 0, if narrow then 22 else 30),
			})
			if not narrow then
				local extra = {}
				if (mastery.gems or 0) > 0 then
					table.insert(extra, "+" .. mastery.gems .. " Gems")
				end
				for _, id in mastery.titles or {} do
					table.insert(extra, "New title!")
					local _ = id
				end
				Widgets.label(f, {
					text = if #extra > 0 then table.concat(extra, "  ·  ") else "Character mastery",
					font = "heavy",
					size = 13,
					color = if #extra > 0 then C.sun else C.textFaint,
					sizeUDim = UDim2.new(1, -(ps + 16), 0, 16),
					position = UDim2.fromOffset(ps + 12, 54),
				})
			end
			if up then
				task.delay(0.9, Sound.play, "levelUp")
			end
		end
		-- daily quests that moved
		local quests = reward.quests
		do
			local f = card(2)
			local changed = quests and quests.changed or {}
			local ic = Util.frame(f, { Position = UDim2.fromOffset(6, if narrow then 4 else 8), Size = UDim2.fromOffset(if narrow then 34 else 44, if narrow then 34 else 44) })
			Icons.medallion(ic, "star", C.sun, { Size = UDim2.fromScale(1, 1) })
			local tx = if narrow then 46 else 56
			local lines = {}
			for _, q in changed do
				table.insert(lines, (if q.done then "Done: " else "") .. q.text .. "  " .. tostring(q.progress) .. "/" .. tostring(q.goal) .. (if q.done then ("  +" .. q.gems) else ""))
			end
			if #lines == 0 then
				table.insert(lines, "No quest progress this time")
			end
			if quests and quests.chest then
				table.insert(lines, 1, "ALL QUESTS DONE: free Explorer Chest!")
			end
			Widgets.label(f, {
				text = "Daily quests",
				font = "chunky",
				size = if narrow then 13 else 15,
				color = C.text,
				sizeUDim = UDim2.new(1, -(tx + 6), 0, 18),
				position = UDim2.fromOffset(tx, if narrow then 2 else 8),
			})
			local l = Widgets.label(f, {
				text = table.concat(lines, if narrow then "  ·  " else "\n"),
				font = "heavy",
				size = if narrow then 11 else 12,
				color = if quests and (quests.gems or 0) > 0 then C.sun else C.textSoft,
				wrap = true,
				valign = "top",
				sizeUDim = UDim2.new(1, -(tx + 6), 1, if narrow then -22 else -30),
				position = UDim2.fromOffset(tx, if narrow then 20 else 28),
			})
			l.TextTruncate = Enum.TextTruncate.AtEnd
		end
		-- trophies (ranked Quick Play)
		local trophies = reward.trophies
		do
			local f = card(3)
			local ic = Util.frame(f, { Position = UDim2.fromOffset(6, if narrow then 4 else 8), Size = UDim2.fromOffset(if narrow then 34 else 44, if narrow then 34 else 44) })
			local rankDef = if trophies then Progress.rank(trophies.total) else nil
			local rankColor = if rankDef then Color3.fromHex(string.sub(rankDef.color, 2)) else C.steel
			Icons.medallion(ic, "crown", rankColor, { Size = UDim2.fromScale(1, 1) })
			local tx = if narrow then 46 else 56
			local head, sub
			if trophies then
				local d = trophies.delta or 0
				head = (if d >= 0 then "+" else "") .. tostring(d) .. " trophies"
				sub = tostring(trophies.total) .. "  ·  " .. (if rankDef then rankDef.name else "") .. (if trophies.rankUp then "  Rank up!" else "")
			else
				head = "Trophies"
				sub = if data.kind == "public" then "Team and event games aren't ranked" else "Only Quick Play counts"
			end
			Widgets.label(f, {
				text = head,
				font = "chunky",
				size = if narrow then 14 else 17,
				color = if trophies and (trophies.delta or 0) > 0 then C.good elseif trophies and (trophies.delta or 0) < 0 then C.bad else C.text,
				sizeUDim = UDim2.new(1, -(tx + 6), 0, 20),
				position = UDim2.fromOffset(tx, if narrow then 2 else 8),
			})
			Widgets.label(f, {
				text = sub,
				font = "heavy",
				size = if narrow then 11 else 13,
				color = if trophies and trophies.rankUp then C.sun else C.textSoft,
				wrap = true,
				valign = "top",
				sizeUDim = UDim2.new(1, -(tx + 6), 1, if narrow then -22 else -32),
				position = UDim2.fromOffset(tx, if narrow then 22 else 32),
			})
		end
		local _ = count
	end

	-- rewards
	local bottom = Util.frame(content, {
		Name = "Rewards",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, if stack then 112 else 56),
	})
	if reward then
		-- beside the Lobby button, or above it on a narrow screen
		local chips = Util.frame(bottom, {
			Size = if stack then UDim2.new(1, 0, 0, 48) else UDim2.new(1, -230, 1, 0),
		})
		Util.list(chips, "x", 10, if stack then "Center" else "Left", "Center")
		local function chip(order: number, iconId: string, color: Color3, text: string)
			local holder = Util.frame(chips, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order })
			Util.list(holder, "x", 6, "Left", "Center")
			local ic = Util.frame(holder, { Size = UDim2.fromOffset(34, 34), LayoutOrder = 1 })
			Icons.medallion(ic, iconId, color, { Size = UDim2.fromScale(1, 1) })
			local l = Widgets.label(holder, {
				text = text,
				font = "chunky",
				size = 22,
				color = C.text,
				sizeUDim = UDim2.fromOffset(0, 34),
				layoutOrder = 2,
			})
			l.AutomaticSize = Enum.AutomaticSize.X
		end
		local questGems = reward.quests and reward.quests.gems or 0
		local masteryGems = reward.mastery and reward.mastery.gems or 0
		chip(1, "gem", C.neutral, "+" .. tostring((reward.gems or 0) + questGems + masteryGems))
		chip(2, "level", C.info, "+" .. tostring(reward.xp) .. " XP")
		if (reward.levelsGained or 0) > 0 then
			chip(3, "star", C.sun, "Level " .. tostring(reward.level) .. "!")
			task.delay(0.6, Sound.play, "levelUp")
		end
		for i, b in reward.bonus or {} do
			Widgets.badge(chips, { text = b, color = C.good, height = 26, textSize = 14, layoutOrder = 10 + i })
		end
		-- a level-up that unlocked someone new to play
		for i, id in reward.unlocked or {} do
			local cdef = Characters.get(id)
			if cdef then
				task.delay(1 + i * 0.8, function()
					Widgets.toast("New character unlocked: the " .. cdef.name .. "! Pick them in the lobby.", "reward")
				end)
			end
		end
		if reward.tutorialGems then
			task.delay(0.8, function()
				Widgets.toast("Guided match complete! +" .. tostring(reward.tutorialGems) .. " Gems. Now go Find a Match!", "reward")
			end)
		end
	end
	-- the buttons: Lobby, and Rematch beside it
	local both = onRematch ~= nil
	local bw = if narrow and both then 150 else 210
	local leave = Widgets.button(bottom, {
		text = "Lobby",
		icon = "back",
		style = if both then "panel" else "brass",
		textSize = 22,
		size = UDim2.fromOffset(bw, 52),
		anchor = if stack then (if both then Vector2.new(0, 1) else Vector2.new(0.5, 1)) else Vector2.new(1, 0.5),
		position = if stack then UDim2.new(0.5, if both then 6 else 0, 1, 0) else UDim2.new(1, 0, 0.5, 0),
		onClick = function()
			close()
			onLeave()
		end,
	})
	if onRematch then
		local again
		again = Widgets.button(bottom, {
			text = "Rematch",
			icon = "play",
			style = "brass",
			textSize = 22,
			size = UDim2.fromOffset(bw, 52),
			anchor = Vector2.new(1, 1),
			position = UDim2.new(0.5, -6, 1, 0),
			onClick = function()
				again:setEnabled(false)
				again:setText("Waiting...")
				onRematch()
			end,
		})
		local stop
		stop = Net.on("match.rematch", function(info)
			if not again.root.Parent then
				stop()
			elseif type(info) == "table" and info.votes and info.needed then
				again:setText(string.format("Rematch %d/%d", info.votes, info.needed))
			end
		end)
	end
	-- the server sends everyone home after a while; show how long
	local endsAt = os.clock() + (data.resultsTime or 25)
	task.spawn(function()
		while leave.root.Parent do
			local left = math.max(0, math.ceil(endsAt - os.clock()))
			leave:setText("Lobby (" .. left .. ")")
			task.wait(0.5)
		end
	end)
	return close
end

return Results
