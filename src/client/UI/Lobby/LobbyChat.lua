--[[
	LobbyChat
	The chat in the lobby: a gold CHAT button in the free part of Roblox's top bar (or
	the T key) that opens the chat window (with a count of lines you haven't seen), and
	speech bubbles that drop
	in under it as people talk, each with the speaker's avatar and their name on a tab
	in their character's colour. Your party's lines (and yours) are read out loud.

		LobbyChat.build(parent, maid, rect, popups)
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)
local ChatPanel = require(UI.ChatPanel)

local Client = UI.Parent
local Chat = require(Client.Chat)
local Sound = require(Client.Sound)
local Gamepad = require(Client.Gamepad)

local C = Theme.C

local LobbyChat = {}

local player = Players.LocalPlayer

local MAX_SHOWN = 3

function LobbyChat.build(parent: Instance, maid, r, popups: Instance)
	local open = false
	local unread = 0
	local button
	local function openChat()
		if open then
			return
		end
		open = true
		unread = 0
		button:setBadge(nil)
		ChatPanel.open(popups, {
			title = "Chat",
			onClose = function()
				open = false
			end,
		})
	end
	-- a gold CHAT button where it's easy to find (just an icon if the bar is tight)
	local wide = r.w >= r.h * 2
	local opts = {
		name = "Chat",
		icon = "bubble",
		style = "brass",
		size = UDim2.fromOffset(r.w, r.h),
		position = UDim2.fromOffset(r.x, r.y),
		onClick = openChat,
	}
	if wide then
		opts.text = "CHAT"
		opts.textSize = math.clamp(math.floor(r.h * 0.42), 14, 22)
		opts.depth = 4
		button = Widgets.button(parent, opts)
	else
		button = Widgets.iconButton(parent, opts)
	end
	-- T opens it from the keyboard (X on a controller)
	maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.T and button.root.Parent then
			openChat()
		end
	end))
	maid:add(Gamepad.on("chat", function()
		if button.root.Parent then
			openChat()
		end
	end))

	-- the bubbles, newest at the top, right under the button
	local W = 330
	local stack = Util.frame(parent, {
		Name = "ChatBubbles",
		Position = UDim2.fromOffset(r.x, r.y + r.h + 10),
		Size = UDim2.fromOffset(W, 300),
		ZIndex = 60,
	})
	local list = Util.list(stack, "y", 8, "Left", "Top")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	local n = 0

	local function bubble(line)
		n += 1
		local color = Theme.playerColor(line.character)
		local size = 18
		local maxW = W - 64
		local bounds = TextService:GetTextSize(line.text, size, Enum.Font.Oswald, Vector2.new(maxW / 1.12, 1000))
		local textW = math.clamp(math.ceil(bounds.X * 1.12) + 2, 40, maxW)
		local textH = math.max(size + 2, math.ceil(bounds.Y) + 2)
		local name = (line.name or "?") .. (if line.staff then ("  ·  " .. line.staff) else "")
		local tabW = math.min(maxW, math.ceil(TextService:GetTextSize(name, 14, Enum.Font.Oswald, Vector2.new(1000, 40)).X) + 22)
		local bodyW = math.max(textW + 24, tabW + 16)
		local h = textH + 20
		local row = Util.frame(stack, {
			Name = "Line",
			Size = UDim2.fromOffset(W, h + 12),
			LayoutOrder = -n,
			ZIndex = 60,
		})
		Avatars.portrait(row, { userId = line.from or 0, name = line.name }, {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.fromOffset(42, 42),
			ZIndex = 61,
		}, { ring = color, ringPx = 3 })
		local body = Util.new("Frame", {
			Name = "Body",
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(54, 12),
			Size = UDim2.fromOffset(bodyW, h),
			ZIndex = 61,
			Parent = row,
		})
		Util.corner(body, 12)
		Util.stroke(body, C.line, 3)
		-- a little tail pointing at the avatar
		local tail = Util.new("Frame", {
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(54, 12 + math.min(h / 2, 22)),
			Size = UDim2.fromOffset(14, 14),
			Rotation = 45,
			ZIndex = 60,
			Parent = row,
		})
		Util.stroke(tail, C.line, 3)
		Widgets.label(body, {
			text = line.text,
			font = "heavy",
			size = size,
			color = C.text,
			wrap = true,
			sizeUDim = UDim2.new(1, -20, 1, -10),
			position = UDim2.fromOffset(10, 7),
			z = 62,
		})
		local tab = Util.new("Frame", {
			Name = "Name",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.fromOffset(tabW, 22),
			ZIndex = 63,
			Parent = row,
		})
		Util.corner(tab, 6)
		Util.stroke(tab, C.line, 2.5)
		Widgets.label(tab, {
			text = name,
			font = "heavy",
			size = 14,
			color = Theme.textOn(color),
			align = "center",
			sizeUDim = UDim2.fromScale(1, 1),
			z = 64,
		}).TextTruncate = Enum.TextTruncate.AtEnd
		Util.popIn(row, 0.3, 0.6)
		-- only the newest few stay
		local rows = {}
		for _, k in stack:GetChildren() do
			if k:IsA("Frame") then
				table.insert(rows, k)
			end
		end
		table.sort(rows, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = MAX_SHOWN + 1, #rows do
			rows[i]:Destroy()
		end
		task.delay(math.clamp(5 + #line.text / 25, 5, 10), function()
			if row.Parent then
				Util.tween(Util.scaler(row), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.wait(0.2)
				row:Destroy()
			end
		end)
	end

	maid:add(Chat.onLine(function(line)
		if line.seat then
			return -- a match's line (this screen is going away)
		end
		if not open then
			if line.from ~= player.UserId then
				unread += 1
				button:setBadge(tostring(math.min(unread, 99)))
			end
			if Chat.bubbles() then
				bubble(line)
				Sound.play("pop")
			end
		end
	end))
	return button
end

return LobbyChat
