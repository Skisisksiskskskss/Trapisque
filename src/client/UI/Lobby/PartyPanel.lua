--[[
	PartyPanel
	The right half of the lobby. Without a party: create one, join with a code, or
	invite Roblox friends. In a party: the join code (or Invite Only), the members
	(the leader can promote or kick), invites, and leaving.

		local panel = PartyPanel.new(parent, popupLayer, { compact = bool })

	Members show their Roblox avatar and @username. Compact (phones held sideways)
	drops the title and the picture and tightens the spacing.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)

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

function PartyPanel.new(parent: Instance, popups: Instance, opts: { [string]: any }?)
	local self = setmetatable({}, PartyPanel)
	self.popups = popups
	self.maid = Util.maid()
	self.compact = opts ~= nil and opts.compact == true
	-- under the lobby's tabs (upright phones) the tab already says "Party"
	local titled = not self.compact and not (opts ~= nil and opts.untitled == true)
	local content, root = Widgets.panel(parent, {
		name = "PartyPanel",
		title = if titled then "Party" else nil,
		titleWidth = 200,
		padding = if self.compact then 12 else 18,
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
	local compact = self.compact
	local y = 0
	if not compact then
		local art = Util.frame(c, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(84, 84),
		})
		Icons.make(art, "people", Icons.flatColors(C.textFaint, C.panel))
		y = 94
	end
	Widgets.label(c, {
		text = "Team up with friends, then find a match together or start a private one.",
		font = "heavy",
		size = if compact then 15 else 17,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 46),
		position = UDim2.fromOffset(0, y),
	})
	y += if compact then 52 else 56
	local bigH = if compact then 44 else 50
	local smallH = if compact then 42 else 46
	Widgets.button(c, {
		text = "CREATE PARTY",
		icon = "plus",
		style = "green",
		textSize = if compact then 18 else 20,
		size = UDim2.new(1, 0, 0, bigH),
		position = UDim2.fromOffset(0, y),
		onClick = function()
			local ok, view = request("party.create")
			if ok then
				State.set("party", view)
			end
		end,
	})
	y += bigH + (if compact then 6 else 10)
	Widgets.button(c, {
		text = "INVITE FRIENDS",
		icon = "people",
		style = "blue",
		textSize = if compact then 16 else 18,
		size = UDim2.new(1, 0, 0, smallH),
		position = UDim2.fromOffset(0, y),
		onClick = inviteFriends,
	})
	y += smallH + (if compact then 8 else 14)
	-- join by code
	Widgets.label(c, {
		text = "Got a party code?",
		font = "chunky",
		size = if compact then 16 else 18,
		color = C.text,
		sizeUDim = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, y),
	})
	y += 28
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
		size = UDim2.new(1, -130, 0, smallH),
		position = UDim2.fromOffset(0, y),
		onSubmit = function()
			join()
		end,
	})
	Widgets.button(c, {
		text = "JOIN",
		style = "brass",
		textSize = 20,
		size = UDim2.fromOffset(118, smallH),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, y),
		onClick = join,
	})
end

function PartyPanel:_renderParty(party)
	local c = self.content
	local isLeader = party.leader == player.UserId

	-- code + privacy
	local compact = self.compact
	local codeH = if compact then 54 else 64
	local buttonsH = if compact then 42 else 48
	local codeBox = Util.new("Frame", {
		Name = "Code",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, codeH),
		Parent = c,
	})
	Util.corner(codeBox, 10)
	Util.stroke(codeBox, C.panelEdge, 2)
	local inviteOnly = party.privacy == "invite"
	Widgets.label(codeBox, {
		text = if inviteOnly then "INVITE ONLY" else "PARTY CODE",
		font = "heavy",
		size = if compact then 11 else 13,
		color = C.textSoft,
		sizeUDim = UDim2.new(0.55, 0, 0, 16),
		position = UDim2.fromOffset(12, if compact then 4 else 6),
	})
	Widgets.label(codeBox, {
		text = if inviteOnly then "Friends join by invite" else (party.code or "------"),
		font = "chunky",
		size = if inviteOnly then (if compact then 15 else 18) else (if compact then 26 else 30),
		color = C.brassLight,
		sizeUDim = UDim2.new(0.55, 0, 0, if compact then 30 else 34),
		position = UDim2.fromOffset(12, if compact then 20 else 24),
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
		position = UDim2.fromOffset(0, codeH + 8),
		size = UDim2.new(1, 0, 1, -(codeH + 8) - (buttonsH + 10)),
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
			color = C.textFaint,
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
		Size = UDim2.new(1, 0, 0, buttonsH),
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
	-- compact rows are a little shorter so a party of three fits a phone held sideways
	local h = if self.compact then 38 else 44
	local avatar = h - 8
	local row = Util.new("Frame", {
		Name = "Member" .. i,
		BackgroundColor3 = if m.userId == player.UserId then C.mine else C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, h),
		LayoutOrder = i,
		Parent = list,
	})
	Util.corner(row, 10)
	Util.stroke(row, if m.userId == player.UserId then C.brassDark else C.panelEdge, 1.5)
	Avatars.portrait(row, { userId = m.userId, name = m.name }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(avatar, avatar),
	}, { ring = Theme.Seat[((i - 1) % 6) + 1], ringPx = 2 })
	local nameX = avatar + 14
	if m.leader then
		local crown = Util.frame(row, { Position = UDim2.fromOffset(nameX, (h - 22) / 2), Size = UDim2.fromOffset(22, 22) })
		Icons.make(crown, "crown", Icons.flatColors(C.brass, C.panel))
		nameX += 28
	end
	local name = Widgets.label(row, {
		text = m.name .. (if m.userId == player.UserId then "  (you)" else ""),
		font = "heavy",
		size = if self.compact then 15 else 16,
		color = Theme.nameColor(m.look),
		sizeUDim = UDim2.new(1, -(nameX + 100), 0, 18),
		position = UDim2.fromOffset(nameX, if self.compact then 2 else 4),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	if m.username then
		local user = Widgets.label(row, {
			text = "@" .. m.username,
			font = "body",
			size = if self.compact then 11 else 12,
			color = C.textSoft,
			sizeUDim = UDim2.new(1, -(nameX + 100), 0, 15),
			position = UDim2.fromOffset(nameX, if self.compact then 20 else 24),
		})
		user.TextTruncate = Enum.TextTruncate.AtEnd
	end
	if isLeader and m.userId ~= player.UserId and party.state == "idle" then
		local bh = h - 10
		local tools = Util.frame(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(90, bh),
		})
		Util.list(tools, "x", 6, "Right", "Center")
		Widgets.iconButton(tools, {
			icon = "crown",
			style = "brass",
			size = UDim2.fromOffset(38, bh),
			layoutOrder = 1,
			onClick = function()
				request("party.promote", { userId = m.userId })
			end,
		})
		Widgets.iconButton(tools, {
			icon = "close",
			style = "red",
			size = UDim2.fromOffset(38, bh),
			layoutOrder = 2,
			onClick = function()
				request("party.kick", { userId = m.userId })
			end,
		})
	end
end

-- Invite people on this server, or Roblox friends anywhere.
function PartyPanel:_invitePicker()
	local roomW = Widgets.room()
	local content, close = Widgets.modal(self.popups, {
		title = "Invite",
		titleWidth = 200,
		width = math.min(520, roomW),
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
		color = C.text,
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
		color = C.textSoft,
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
				color = C.textSoft,
				align = "center",
				wrap = true,
				sizeUDim = UDim2.new(1, 0, 0, 50),
			})
			return
		end
		for i, p in list do
			local row = Util.new("Frame", {
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 46),
				LayoutOrder = i,
				Parent = scroll,
			})
			Util.corner(row, 10)
			Util.stroke(row, C.panelEdge, 1.5)
			Avatars.portrait(row, { userId = p.userId, name = p.name }, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
			}, { ring = C.panelEdge, ringPx = 2 })
			Widgets.label(row, {
				text = p.name,
				font = "heavy",
				size = 16,
				color = C.text,
				sizeUDim = UDim2.new(1, -190, 0, 20),
				position = UDim2.fromOffset(50, 4),
			}).TextTruncate = Enum.TextTruncate.AtEnd
			if p.username then
				Widgets.label(row, {
					text = "@" .. p.username,
					font = "body",
					size = 12,
					color = C.textSoft,
					sizeUDim = UDim2.new(1, -190, 0, 16),
					position = UDim2.fromOffset(50, 25),
				}).TextTruncate = Enum.TextTruncate.AtEnd
			end
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
