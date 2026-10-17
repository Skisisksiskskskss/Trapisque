--[[
	Spectate
	Watch a friend's match: your Roblox friends who are in a Trapisque match right now,
	with the mode and map, and a WATCH button. Watching shows the board the way every
	player sees it (no one's hand, no hidden traps); you can leave from the menu.

		Spectate.open(popups)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Modes = require(Shared.Game.Modes)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)

local Client = UI.Parent
local Net = require(Client.Net)

local C = Theme.C

local Spectate = {}

local player = Players.LocalPlayer

-- Friends who are in this game right now: { { userId, name } }.
local function friendsHere(): { { userId: number, name: string } }
	local out = {}
	local ok, list = pcall(function()
		return player:GetFriendsOnline(100)
	end)
	if ok and type(list) == "table" then
		for _, f in list do
			if f.PlaceId == game.PlaceId and f.VisitorId then
				table.insert(out, { userId = f.VisitorId, name = f.DisplayName or f.UserName or "Friend" })
			end
		end
	end
	-- (friends on this very server, too: the list above can lag behind)
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local isFriend = false
			pcall(function()
				isFriend = player:IsFriendsWith(p.UserId)
			end)
			if isFriend then
				local seen = false
				for _, f in out do
					if f.userId == p.UserId then
						seen = true
					end
				end
				if not seen then
					table.insert(out, { userId = p.UserId, name = p.DisplayName })
				end
			end
		end
	end
	return out
end

function Spectate.open(popups: Instance)
	local roomW, roomH = Widgets.room()
	local content, close = Widgets.modal(popups, {
		title = "Watch a Friend",
		titleWidth = 300,
		width = math.min(560, roomW),
		height = math.min(480, roomH),
	})
	local status = Widgets.label(content, {
		text = "Looking for your friends...",
		font = "heavy",
		size = 16,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
	})
	local list = Widgets.scroll(content, {
		position = UDim2.fromOffset(0, 46),
		size = UDim2.new(1, 0, 1, -46),
		gap = 8,
	})
	task.spawn(function()
		local friends = friendsHere()
		local ids = {}
		for _, f in friends do
			table.insert(ids, f.userId)
		end
		local ok, found = Net.request("spectate.find", { userIds = ids })
		if not status.Parent then
			return
		end
		local any = false
		for i, f in friends do
			local m = ok and type(found) == "table" and found[tostring(f.userId)]
			if m then
				any = true
				local row = Util.new("Frame", {
					Name = "Friend" .. f.userId,
					BackgroundColor3 = C.panelRaised,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -12, 0, 64),
					LayoutOrder = i,
					Parent = list,
				})
				Util.corner(row, 12)
				Util.stroke(row, C.line, 2.5)
				Avatars.portrait(row, { userId = f.userId, name = f.name }, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(46, 46),
				})
				local mode = Modes.get(m.mode or "")
				local map = Maps.get(m.map or "")
				Widgets.label(row, {
					text = f.name,
					font = "chunky",
					size = 19,
					color = C.text,
					sizeUDim = UDim2.new(1, -190, 0, 24),
					position = UDim2.fromOffset(64, 8),
				}).TextTruncate = Enum.TextTruncate.AtEnd
				Widgets.label(row, {
					text = (if mode then mode.name else "A match") .. (if map then (" on " .. map.name) else ""),
					font = "body",
					size = 14,
					color = C.textSoft,
					sizeUDim = UDim2.new(1, -190, 0, 20),
					position = UDim2.fromOffset(64, 34),
				}).TextTruncate = Enum.TextTruncate.AtEnd
				Widgets.button(row, {
					text = "WATCH",
					icon = "eye",
					style = "green",
					textSize = 17,
					size = UDim2.fromOffset(110, 44),
					anchor = Vector2.new(1, 0.5),
					position = UDim2.new(1, -10, 0.5, 0),
					onClick = function()
						local wok, err = Net.request("spectate.watch", { userId = f.userId })
						if wok then
							close()
						else
							Widgets.toast(tostring(err), "info")
						end
					end,
				})
			end
		end
		status.Text = if any then "Pick a match to watch. You'll see the board the way every player does." else "None of your friends is in a match right now. Check back in a bit!"
	end)
	return close
end

return Spectate
