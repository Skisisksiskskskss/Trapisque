--[[
	ChatPanel
	The chat window. The latest lines (each speaker's name in their colour), the quick
	lines anyone can say with one tap, your emotes (in a match) and, with the Chat pass,
	a box to type your own. Without the pass the box is a BUY button; with chat off in
	your Roblox settings (or while muted) it says so, and quick lines still work.

	Tap someone's line for what you can do about them: hide their lines (just for you),
	block them on Roblox, or report them to the game's staff.

		ChatPanel.open(layer, { title?, emotes = { id }?, colorOf = fn(line) -> Color3,
			closeOnSend?, onClose? }) -> close
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Passes = require(Shared.Meta.Passes)
local QuickChat = require(Shared.Meta.QuickChat)

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Chat = require(Client.Chat)

local C = Theme.C

local ChatPanel = {}

local player = Players.LocalPlayer

local function escape(s: string): string
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	s = string.gsub(s, "\"", "&quot;")
	return s
end

local function hexOf(c: Color3): string
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local REASONS = {
	{ id = "mean", text = "BEING MEAN" },
	{ id = "rude", text = "RUDE WORDS" },
	{ id = "scam", text = "SCAM / ASKING FOR INFO" },
	{ id = "spam", text = "SPAM" },
	{ id = "other", text = "SOMETHING ELSE" },
}

-- What you can do about someone in the chat.
local function personMenu(layer: Instance, line)
	local roomW = Widgets.room()
	local name = line.name or "them"
	local content, close = Widgets.modal(layer, {
		title = name,
		titleWidth = 260,
		width = math.min(480, roomW),
		height = 430,
	})
	local body = Util.frame(content, { Name = "Body" })
	Util.list(body, "y", 10, "Center", "Top").SortOrder = Enum.SortOrder.LayoutOrder
	local function text(t: string, order: number, h: number?)
		Widgets.label(body, {
			text = t,
			font = "heavy",
			size = 16,
			minSize = 11,
			color = C.textSoft,
			align = "center",
			wrap = true,
			scaled = true,
			sizeUDim = UDim2.new(1, -8, 0, h or 44),
			layoutOrder = order,
		})
	end
	local function button(t: string, style: string, order: number, onClick: () -> ())
		Widgets.button(body, {
			text = t,
			style = style,
			textSize = 18,
			font = "heavy",
			depth = 3,
			size = UDim2.new(1, -40, 0, 50),
			layoutOrder = order,
			onClick = onClick,
		})
	end
	local function reportStep()
		Util.clear(body, true)
		text("What did they do? Our crew sees your report with their last few lines.", 1)
		for i, r in REASONS do
			Widgets.button(body, {
				text = r.text,
				style = "panel",
				textSize = 16,
				font = "heavy",
				depth = 3,
				size = UDim2.new(1, -40, 0, 38),
				layoutOrder = 1 + i,
				onClick = function()
					local ok, err = Chat.report(line.from, r.id)
					if ok then
						close()
						Widgets.toast("Thanks for telling us! For anything serious, report them to Roblox too, from the Roblox menu.", "info")
					else
						Widgets.toast(tostring(err), "error")
					end
				end,
			})
		end
	end
	local hidden = Chat.isMuted(line.from)
	text("Only you see what you pick here.", 1, 26)
	button(if hidden then "SHOW THEIR LINES" else "HIDE THEIR LINES", "panel", 2, function()
		Chat.mute(line.from, not hidden)
		close()
		Widgets.toast(if hidden then ("Showing " .. name .. "'s lines again.") else ("You won't see " .. name .. "'s lines any more."), "info")
	end)
	button("BLOCK ON ROBLOX", "orange", 3, function()
		close()
		if not Chat.block(line.from) then
			Widgets.toast(name .. " has left. You can block them from their Roblox profile.", "info")
		end
	end)
	button("REPORT", "red", 4, reportStep)
end

local function lineText(line, color: Color3): string
	local tag = if line.staff then string.format('<font color="#%s">[%s]</font> ', hexOf(Theme.inkOf(C.sun)), line.staff) else ""
	return string.format('%s<font color="#%s"><b>%s:</b></font> %s', tag, hexOf(Theme.inkOf(color)), escape(line.name or "?"), escape(line.text))
end

function ChatPanel.open(layer: Instance, o: { [string]: any })
	local maid = Util.maid()
	local roomW, roomH, narrow = Widgets.room()
	local W = math.min(640, roomW)
	local H = math.min(600, roomH)
	local content, close = Widgets.modal(layer, {
		title = o.title or "Chat",
		titleWidth = 220,
		width = W,
		height = H,
		onClose = function()
			maid:clean()
			if o.onClose then
				o.onClose()
			end
		end,
	})
	local colorOf = o.colorOf or function(line)
		return Theme.playerColor(line.character)
	end

	-- from the bottom up: the box to type in, the quick lines, the emotes; the log fills the rest
	local inputH = 50
	local quickRows = if narrow then 3 else 2
	local quickH = quickRows * 40 + (quickRows - 1) * 8 + 8
	local emotes = o.emotes
	local emoteH = if emotes and #emotes > 0 then 50 else 0
	local G = 10

	local input = Util.frame(content, {
		Name = "Input",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, inputH),
	})
	local quick = Widgets.scroll(content, {
		name = "Quick",
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 0, 1, -(inputH + G)),
		size = UDim2.new(1, 0, 0, quickH),
		grid = UDim2.fromOffset(if narrow then 118 else 132, 40),
		gap = 8,
		padding = 4,
	})
	local logBottom = inputH + G + quickH + G
	if emoteH > 0 then
		local row = Util.frame(content, {
			Name = "Emotes",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -logBottom),
			Size = UDim2.new(1, 0, 0, emoteH),
		})
		Util.list(row, "x", 8, "Center", "Center")
		for i, id in emotes do
			local b = Util.new("TextButton", {
				Name = id,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(if narrow then 92 else 104, 44),
				LayoutOrder = i,
				Parent = row,
			})
			local bubble = CosmeticArt.emoteBubble(b, id, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
			if bubble then
				bubble.Active = false
			end
			b.Activated:Connect(function()
				close()
				local ok, err = Net.request("match.emote", { emote = id })
				if not ok then
					Widgets.toast(tostring(err), "error")
				end
			end)
		end
		logBottom += emoteH + G
	end

	-- the log
	local logBox = Util.new("Frame", {
		Name = "LogBox",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -logBottom),
		Parent = content,
	})
	Util.corner(logBox, 8)
	Util.stroke(logBox, C.line, 2.5)
	local log = Widgets.scroll(logBox, { name = "Log", gap = 4, padding = 8, hAlign = "Left" })
	local count = 0
	local empty = Widgets.label(logBox, {
		text = "No one's said anything yet. Say ahoy!",
		font = "body",
		size = 16,
		color = C.textSoft,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
	})
	local function addLine(line)
		count += 1
		empty.Visible = false
		local label = Widgets.label(log, {
			text = lineText(line, colorOf(line)),
			rich = true,
			font = "body",
			size = 17,
			color = C.text,
			wrap = true,
			valign = "top",
			sizeUDim = UDim2.new(1, -14, 0, 0),
			layoutOrder = count,
		})
		label.AutomaticSize = Enum.AutomaticSize.Y
		-- tap someone's line: hide, block or report them
		if line.from and line.from ~= 0 and line.from ~= player.UserId then
			local hit = Util.new("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = label,
			})
			hit.Activated:Connect(function()
				personMenu(layer, line)
			end)
		end
		local kids = log:GetChildren()
		local labels = 0
		for _, k in kids do
			if k:IsA("TextLabel") then
				labels += 1
			end
		end
		if labels > Config.Chat.History then
			for _, k in kids do
				if k:IsA("TextLabel") and k.LayoutOrder <= count - Config.Chat.History then
					k:Destroy()
				end
			end
		end
		task.defer(function()
			log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteSize.Y))
		end)
	end
	for _, line in Chat.history() do
		addLine(line)
	end
	maid:add(Chat.onLine(addLine))

	-- quick lines
	for i, q in QuickChat.list do
		local b = Widgets.button(quick, {
			name = q.id,
			text = q.text,
			style = "panel",
			textSize = if narrow then 15 else 16,
			font = "heavy",
			depth = 3,
			layoutOrder = i,
			onClick = function()
				local ok, err = Chat.quick(q.id)
				if not ok then
					Widgets.toast(tostring(err), "error")
				elseif o.closeOnSend then
					close()
				end
			end,
		})
		local _ = b
	end

	-- typing your own lines
	local function renderInput()
		Util.clear(input)
		local why = Chat.typing()
		if why == "ok" then
			local box: TextBox
			local function send()
				local text = box.Text
				if string.match(text, "%S") == nil then
					return
				end
				box.Text = ""
				local ok, err = Chat.say(text)
				if not ok then
					Widgets.toast(tostring(err), "error")
					box.Text = text
				elseif o.closeOnSend then
					close()
				end
			end
			box = Widgets.textBox(input, {
				placeholder = "Say something...",
				textSize = 18,
				maxLength = Config.Chat.MaxLength,
				size = UDim2.new(1, -118, 1, 0),
				onSubmit = send,
			})
			box.TextXAlignment = Enum.TextXAlignment.Left
			Util.pad(box, 12, 0, 12, 0)
			Widgets.button(input, {
				text = "SEND",
				style = "green",
				textSize = 19,
				size = UDim2.new(0, 108, 1, 0),
				anchor = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				onClick = send,
			})
			return
		end
		local text = if why == "settings"
			then "Chat is off in your Roblox settings, so typing is too. Quick lines still work!"
			elseif why == "muted" then "You're muted for a while. Quick lines still work."
			else "Type your own lines with the Chat pass. Quick lines are free for everyone!"
		local hasBuy = why == "pass"
		Widgets.label(input, {
			text = text,
			font = "heavy",
			size = if narrow then 13 else 15,
			color = C.textSoft,
			wrap = true,
			sizeUDim = UDim2.new(1, if hasBuy then -150 else 0, 1, 0),
		})
		if hasBuy then
			local id = Passes.id("Chat")
			local buy = Widgets.button(input, {
				text = if id == 0 then "SOON" else "R$ 10",
				icon = "bubble",
				style = "green",
				textSize = 18,
				size = UDim2.new(0, 140, 1, 0),
				anchor = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				onClick = function()
					if id == 0 then
						return
					end
					local ok = pcall(function()
						MarketplaceService:PromptGamePassPurchase(player, id)
					end)
					if not ok then
						Widgets.toast("The Roblox store didn't open. Try again in a moment.", "error")
					end
				end,
			})
			if id == 0 then
				buy:setEnabled(false)
			else
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
					end)
					if ok and info and info.PriceInRobux and buy.root.Parent then
						buy:setText("R$ " .. tostring(info.PriceInRobux))
					end
				end)
			end
		end
	end
	renderInput()
	-- buying the pass (or a mute ending) switches the box on
	local last = Chat.typing()
	maid:add(State.watch("profile", function()
		local now = Chat.typing()
		if now ~= last then
			last = now
			renderInput()
		end
	end))
	maid:add(State.watch("chat", function()
		local now = Chat.typing()
		if now ~= last then
			last = now
			renderInput()
		end
	end))
	return close
end

return ChatPanel
