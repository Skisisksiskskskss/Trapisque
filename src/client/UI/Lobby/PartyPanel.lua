--[[
	PartyPanel
	The right half of the lobby. Without a party: create one, join with a code, or
	invite Roblox friends. In a party: the join code (or Invite Only), the members
	(the leader can promote or kick), invites, and leaving.

		local panel = PartyPanel.new(parent, popupLayer)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)

local C = Theme.C

local PartyPanel = {}
PartyPanel.__index = PartyPanel

local player = Players.LocalPlayer

local function request(action: string, payload: { [string]: any }?): (boolean, any)
	local ok, result = Net.request(action, payload)
	if not ok then
		Widgets.toast(tostring(result), "error")
	end
	return ok, result
end

-- Roblox's own invite dialog; friends who accept land in this party (code in LaunchData).
local function inviteFriends()
	local party = State.get("party")
	if not party then
		local ok, view = request("party.create")
		if not ok then
			return
		end
		State.set("party", view)
		party = view
	end
	local canInvite = false
	pcall(function()
		canInvite = SocialService:CanSendGameInviteAsync(player)
	end)
	if not canInvite then
		Widgets.toast("Roblox invites aren't available right now. Share your party code instead!", "info")
		return
	end
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come play Trapisque with me!"
		options.LaunchData = HttpService:JSONEncode({ party = party.code })
		SocialService:PromptGameInvite(player, options)
	end)
	if not ok then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end
end

function PartyPanel.new(parent: Instance, popups: Instance)
	local self = setmetatable({}, PartyPanel)
	self.popups = popups
	self.maid = Util.maid()
	local content, root = Widgets.panel(parent, {
		name = "PartyPanel",
		title = "Party",
		titleWidth = 200,
		size = UDim2.fromScale(1, 1),
	})
	self.root = root
	self.content = content
	self.maid:add(State.watch("party", function()
		self:render()
	end, true))
	return self
end

function PartyPanel:destroy()
	self.maid:clean()
end

function PartyPanel:render()
	Util.clear(self.content)
	local party = State.get("party")
	if party then
		self:_renderParty(party)
	else
		self:_renderEmpty()
	end
end

function PartyPanel:_renderEmpty()
	local c = self.content
	local art = Util.frame(c, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(84, 84),
	})
	Icons.make(art, "people", Icons.flatColors(C.ink, C.parchment))
	Widgets.label(c, {
		text = "Team up with friends, then find a match together or start a private one.",
		font = "heavy",
		size = 17,
		color = C.inkSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 46),
		position = UDim2.fromOffset(0, 94),
	})
	Widgets.button(c, {
		text = "CREATE PARTY",
		icon = "plus",
		style = "green",
		textSize = 20,
		size = UDim2.new(1, 0, 0, 50),
		position = UDim2.fromOffset(0, 150),
		onClick = function()
			local ok, view = request("party.create")
			if ok then
				State.set("party", view)
			end
		end,
	})
	Widgets.button(c, {
		text = "INVITE FRIENDS",
		icon = "people",
		style = "blue",
		textSize = 18,
		size = UDim2.new(1, 0, 0, 46),
		position = UDim2.fromOffset(0, 210),
		onClick = inviteFriends,
	})
	-- join by code
	Widgets.label(c, {
		text = "Got a party code?",
		font = "chunky",
		size = 18,
		color = C.ink,
		sizeUDim = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 270),
	})
	local box: TextBox
	local function join()
		local code = string.upper((box.Text:gsub("%s", "")))
		if #code < 4 then
			Widgets.toast("Type the party code first.", "error")
			return
		end
		request("party.join", { code = code })
	end
	box = Widgets.textBox(c, {
		placeholder = "ABC123",
		font = "chunky",
		textSize = 24,
		maxLength = 8,
		upper = true,
		size = UDim2.new(1, -130, 0, 46),
		position = UDim2.fromOffset(0, 298),
		onSubmit = function()
			join()
		end,
	})
	Widgets.button(c, {
		text = "JOIN",
		style = "brass",
		textSize = 20,
		size = UDim2.fromOffset(118, 46),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 298),
		onClick = join,
	})
end

function PartyPanel:_renderParty(party)
	local c = self.content
	local isLeader = party.leader == player.UserId

	-- code + privacy
	local codeBox = Util.new("Frame", {
		Name = "Code",
		BackgroundColor3 = C.parchmentMid,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = c,
	})
	Util.corner(codeBox, 10)
	Util.stroke(codeBox, C.parchmentEdge, 2)
	local inviteOnly = party.privacy == "invite"
	Widgets.label(codeBox, {
		text = if inviteOnly then "INVITE ONLY" else "PARTY CODE",
		font = "heavy",
		size = 13,
		color = C.inkSoft,
		sizeUDim = UDim2.new(0.55, 0, 0, 18),
		position = UDim2.fromOffset(12, 6),
	})
	Widgets.label(codeBox, {
		text = if inviteOnly then "Friends join by invite" else (party.code or "------"),
		font = "chunky",
		size = if inviteOnly then 18 else 30,
		color = C.ink,
		sizeUDim = UDim2.new(0.55, 0, 0, 34),
		position = UDim2.fromOffset(12, 24),
	})
	local privacy = Widgets.choice(codeBox, {
		options = { { text = "Code", value = "code" }, { text = "Invite only", value = "invite" } },
		value = party.privacy,
		size = UDim2.new(0.42, -10, 0, 38),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
		textSize = 15,
		onChange = function(v)
			request("party.privacy", { privacy = v })
		end,
	})
	privacy:setEnabled(isLeader)

	-- members (scrolls if a full party doesn't fit)
	local list = Widgets.scroll(c, {
		name = "Members",
		position = UDim2.fromOffset(0, 74),
		size = UDim2.new(1, 0, 1, -74 - 58),
		gap = 6,
		padding = 2,
	})
	for i, m in party.members do
		self:_member(list, i, m, isLeader, party)
	end
	if #party.members < (party.max or 6) then
		local hint = Widgets.label(list, {
			text = (party.max or 6) - #party.members .. " more can join",
			font = "body",
			size = 14,
			color = C.inkFaint,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 20),
			layoutOrder = 99,
		})
		hint.Name = "Room"
	end

	-- buttons
	local row = Util.frame(c, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
	})
	Widgets.button(row, {
		text = "INVITE",
		icon = "plus",
		style = "blue",
		textSize = 18,
		size = UDim2.new(0.62, -6, 1, 0),
		onClick = function()
			self:_invitePicker()
		end,
	})
	Widgets.button(row, {
		text = "LEAVE",
		icon = "exit",
		style = "red",
		textSize = 18,
		size = UDim2.new(0.38, -6, 1, 0),
		anchor = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		onClick = function()
			local ok = request("party.leave")
			if ok then
				State.set("party", nil)
			end
		end,
	})
end

function PartyPanel:_member(list: Instance, i: number, m, isLeader: boolean, party)
	local row = Util.new("Frame", {
		Name = "Member" .. i,
		BackgroundColor3 = if m.userId == player.UserId then Color3.fromHex("FFF1C4") else Color3.fromHex("FBF3DD"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 44),
		LayoutOrder = i,
		Parent = list,
	})
	Util.corner(row, 10)
	Util.stroke(row, C.parchmentEdge, 1.5)
	local pawn = Util.frame(row, { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(36, 36) })
	CosmeticArt.pawn(pawn, m.look and m.look.pawn, Theme.Seat[((i - 1) % 6) + 1], {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	local nameX = 50
	if m.leader then
		local crown = Util.frame(row, { Position = UDim2.fromOffset(50, 11), Size = UDim2.fromOffset(22, 22) })
		Icons.make(crown, "crown", Icons.flatColors(C.brassDark, C.parchment))
		nameX = 78
	end
	local name = Widgets.label(row, {
		text = m.name .. (if m.userId == player.UserId then "  (you)" else ""),
		font = "heavy",
		size = 17,
		color = Theme.nameColor(m.look),
		sizeUDim = UDim2.new(1, -(nameX + 100), 1, 0),
		position = UDim2.fromOffset(nameX, 0),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	if isLeader and m.userId ~= player.UserId and party.state == "idle" then
		local tools = Util.frame(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(90, 34),
		})
		Util.list(tools, "x", 6, "Right", "Center")
		Widgets.iconButton(tools, {
			icon = "crown",
			style = "brass",
			size = UDim2.fromOffset(38, 34),
			layoutOrder = 1,
			onClick = function()
				request("party.promote", { userId = m.userId })
			end,
		})
		Widgets.iconButton(tools, {
			icon = "close",
			style = "red",
			size = UDim2.fromOffset(38, 34),
			layoutOrder = 2,
			onClick = function()
				request("party.kick", { userId = m.userId })
			end,
		})
	end
end

-- Invite people on this server, or Roblox friends anywhere.
function PartyPanel:_invitePicker()
	local content, close = Widgets.modal(self.popups, {
		title = "Invite",
		titleWidth = 200,
		width = 520,
		height = 470,
	})
	Widgets.button(content, {
		text = "INVITE ROBLOX FRIENDS",
		icon = "people",
		style = "blue",
		textSize = 18,
		size = UDim2.new(1, 0, 0, 48),
		onClick = function()
			close()
			inviteFriends()
		end,
	})
	Widgets.label(content, {
		text = "Players on this server",
		font = "chunky",
		size = 18,
		color = C.ink,
		sizeUDim = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 58),
	})
	local scroll = Widgets.scroll(content, {
		size = UDim2.new(1, 0, 1, -88),
		position = UDim2.fromOffset(0, 86),
		gap = 6,
	})
	local loading = Widgets.label(scroll, {
		text = "Looking around...",
		font = "heavy",
		size = 16,
		color = C.inkSoft,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 30),
	})
	task.spawn(function()
		local ok, list = Net.request("lobby.players")
		loading:Destroy()
		if not ok or type(list) ~= "table" or #list == 0 then
			Widgets.label(scroll, {
				text = "Nobody else is here right now. Invite Roblox friends instead!",
				font = "heavy",
				size = 16,
				color = C.inkSoft,
				align = "center",
				wrap = true,
				sizeUDim = UDim2.new(1, 0, 0, 50),
			})
			return
		end
		for i, p in list do
			local row = Util.new("Frame", {
				BackgroundColor3 = Color3.fromHex("FBF3DD"),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 46),
				LayoutOrder = i,
				Parent = scroll,
			})
			Util.corner(row, 10)
			Util.stroke(row, C.parchmentEdge, 1.5)
			local pawn = Util.frame(row, { Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(36, 36) })
			CosmeticArt.pawn(pawn, p.look and p.look.pawn, Theme.Seat[((i - 1) % 6) + 1], {
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			})
			Widgets.label(row, {
				text = p.name,
				font = "heavy",
				size = 17,
				color = C.textDark,
				sizeUDim = UDim2.new(1, -190, 1, 0),
				position = UDim2.fromOffset(50, 0),
			}).TextTruncate = Enum.TextTruncate.AtEnd
			local b = Widgets.button(row, {
				text = if p.inMyParty then "IN PARTY" else "INVITE",
				style = "green",
				textSize = 16,
				size = UDim2.fromOffset(120, 36),
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -6, 0.5, -2),
			})
			b:setEnabled(not p.inMyParty)
			b.root.Activated:Connect(function()
				if not b.enabled then
					return
				end
				local ok2 = request("party.invite", { userId = p.userId })
				if ok2 then
					b:setText("SENT")
					b:setEnabled(false)
				end
			end)
		end
	end)
end

return PartyPanel
