--[[
	Quests
	Today's three quests ("Bonk 5 rivals"), how far along each one is, its Gem reward,
	one free SWAP a day for a quest you don't like, the bonus chest for finishing all
	three, and your login streak: a week of rewards that grows each day you come back
	(day 7 adds a free chest). New quests arrive every day at midnight UTC.

		Quests.open(popups)
		Quests.unfinished(profile) -> number  -- for the menu's badge
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local Quests = {}

function Quests.unfinished(profile): number
	local n = 0
	for _, q in profile and profile.quests or {} do
		if not q.done then
			n += 1
		end
	end
	return n
end

-- "4h 12m" until the next UTC day.
local function untilTomorrow(): string
	local now = os.time()
	local left = 86400 - (now % 86400)
	local h = left // 3600
	local m = (left % 3600) // 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm", m)
end

local function questRow(list: Frame, q, order: number, canSwap: boolean)
	local row = Util.new("Frame", {
		Name = "Quest" .. order,
		BackgroundColor3 = if q.done then C.mine else C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = order,
		Parent = list,
	})
	Util.corner(row, 12)
	Util.stroke(row, if q.done then C.sun else C.line, 2.5)
	local ic = Util.frame(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(40, 40) })
	Icons.medallion(ic, if q.done then "check" else "star", if q.done then C.lime else C.sun, { Size = UDim2.fromScale(1, 1) })
	local right = if canSwap and not q.done then 190 else 110
	Widgets.label(row, {
		text = q.text,
		font = "heavy",
		size = 16,
		color = C.text,
		sizeUDim = UDim2.new(1, -(60 + right), 0, 22),
		position = UDim2.fromOffset(60, 8),
	}).TextTruncate = Enum.TextTruncate.AtEnd
	local bar = Widgets.progress(row, {
		size = UDim2.new(1, -(60 + right + 50), 0, 12),
		position = UDim2.fromOffset(60, 38),
		value = q.progress / math.max(1, q.goal),
		color = if q.done then C.lime else C.sun,
	})
	local _ = bar
	Widgets.label(row, {
		text = tostring(q.progress) .. "/" .. tostring(q.goal),
		font = "chunky",
		size = 14,
		color = C.textSoft,
		sizeUDim = UDim2.fromOffset(46, 18),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -(right - 2), 0, 34),
		align = "right",
	})
	-- the reward
	local reward = Util.frame(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(92, 36),
	})
	Util.list(reward, "x", 4, "Right", "Center")
	if q.done then
		Widgets.badge(reward, { text = "DONE!", color = C.lime, height = 26, textSize = 15, layoutOrder = 1 })
	else
		local gem = Util.frame(reward, { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 })
		Icons.medallion(gem, "gem", C.neutral, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(reward, {
			text = "+" .. tostring(q.gems),
			font = "chunky",
			size = 20,
			color = C.text,
			sizeUDim = UDim2.fromOffset(52, 30),
			layoutOrder = 2,
		})
	end
	if canSwap and not q.done then
		Widgets.button(row, {
			text = "SWAP",
			style = "purple",
			textSize = 14,
			depth = 3,
			corner = 10,
			size = UDim2.fromOffset(70, 34),
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -110, 0.5, 0),
			onClick = function()
				local ok, err = Net.request("quests.reroll", { index = q.index })
				if not ok then
					Widgets.toast(tostring(err), "error")
				else
					Sound.play("reveal")
				end
			end,
		})
	end
	Util.popIn(row, 0.3, 0.6)
end

-- The week of login rewards: days so far filled in, today marked.
local function streakRow(parent: Frame, profile)
	local streak = profile and profile.streak or { count = 0, day = -10, today = 0 }
	local count = streak.count or 0
	local days = #Progress.streakGems
	-- where today sits in the week (1..7)
	local todayIndex = if count > 0 then ((count - 1) % days) + 1 else 0
	local row = Util.frame(parent, { Name = "Streak" })
	Util.list(row, "x", 6, "Center", "Center")
	for i = 1, days do
		local got = i <= todayIndex
		local isToday = i == todayIndex
		local box = Util.new("Frame", {
			Name = "Day" .. i,
			BackgroundColor3 = if got then C.sun elseif i == todayIndex + 1 then C.panelHi else C.panelRaised,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / days, -6 * (days - 1) / days, 1, 0),
			LayoutOrder = i,
			Parent = row,
		})
		Util.corner(box, 10)
		Util.stroke(box, if isToday then C.white else C.line, if isToday then 3 else 2)
		Widgets.label(box, {
			text = "DAY " .. i,
			font = "chunky",
			size = 12,
			color = if got then C.textOnLight else C.textSoft,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 16),
			position = UDim2.fromOffset(0, 4),
		})
		local ic = Util.frame(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(26, 26),
		})
		Icons.medallion(ic, if i == Progress.StreakChestDay then "chest" else "gem", if i == Progress.StreakChestDay then C.orange else C.neutral, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(box, {
			text = "+" .. tostring(Progress.streakGems[i]),
			font = "chunky",
			size = 13,
			color = if got then C.textOnLight else C.text,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 16),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 0, 1, -3),
		})
	end
	return row
end

function Quests.open(popups: Instance)
	local roomW, _, narrow = Widgets.room()
	local width = math.min(620, roomW)
	local content, close = Widgets.modal(popups, {
		title = "Daily Quests",
		titleWidth = 300,
		width = width,
		height = if narrow then 610 else 570,
	})
	local body = Util.frame(content, { Name = "Body" })
	local maid = Util.maid()
	local function build()
		Util.clear(body)
		local profile = State.get("profile")
		local quests = profile and profile.quests or {}
		local canSwap = profile ~= nil and profile.questRerolled ~= true
		Widgets.label(body, {
			text = "New quests in " .. untilTomorrow() .. (if canSwap then "  ·  you can SWAP one quest a day" else ""),
			font = "heavy",
			size = if narrow then 13 else 15,
			color = C.textSoft,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 20),
		})
		local list = Util.frame(body, {
			Name = "List",
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 3 * 64 + 2 * 8),
		})
		Util.list(list, "y", 8, "Center", "Top")
		for i, q in quests do
			questRow(list, q, i, canSwap)
		end
		-- finishing all three
		local allDone = #quests > 0 and Quests.unfinished(profile) == 0
		local bonus = Util.new("Frame", {
			Name = "Bonus",
			BackgroundColor3 = if allDone then C.mine else C.panelDeep,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 28 + 3 * 64 + 2 * 8 + 10),
			Size = UDim2.new(1, 0, 0, 44),
			Parent = body,
		})
		Util.corner(bonus, 10)
		Util.stroke(bonus, if allDone then C.sun else C.line, 2)
		local chestIcon = Util.frame(bonus, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(32, 32) })
		Icons.medallion(chestIcon, "chest", C.orange, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(bonus, {
			text = if profile and profile.questBonus then "All done today! Your free Explorer Chest is waiting in CHESTS." else "Finish all three for a free Explorer Chest!",
			font = "heavy",
			size = if narrow then 13 else 15,
			color = if allDone then C.sun else C.text,
			wrap = true,
			sizeUDim = UDim2.new(1, -56, 1, 0),
			position = UDim2.fromOffset(48, 0),
		})
		-- the login streak
		local streakTop = 28 + 3 * 64 + 2 * 8 + 10 + 44 + 16
		local streak = profile and profile.streak or {}
		Widgets.label(body, {
			text = "LOGIN STREAK: " .. tostring(streak.count or 0) .. (if (streak.count or 0) == 1 then " DAY" else " DAYS"),
			font = "chunky",
			size = 18,
			color = C.text,
			outline = C.line,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 22),
			position = UDim2.fromOffset(0, streakTop),
		})
		local row = streakRow(body, profile)
		row.Position = UDim2.fromOffset(0, streakTop + 28)
		row.Size = UDim2.new(1, 0, 0, 72)
		Widgets.label(body, {
			text = "Come back tomorrow to keep it going. Miss a day and it starts over.",
			font = "body",
			size = 13,
			color = C.textFaint,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 18),
			position = UDim2.fromOffset(0, streakTop + 106),
		})
	end
	build()
	maid:add(State.watch("profile", function()
		if body.Parent then
			build()
		end
	end))
	task.spawn(function()
		while body.Parent do
			task.wait(1)
		end
		maid:clean()
	end)
	return close
end

return Quests
