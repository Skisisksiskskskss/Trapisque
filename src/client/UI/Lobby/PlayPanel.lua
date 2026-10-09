--[[
	PlayPanel
	The left half of the lobby: pick a mode, then Find a Match (public matchmaking),
	Practice against bots, or start a Private Match with your party.

		local panel = PlayPanel.new(parent, popupLayer, { compact = bool })
		panel:refresh()   -- party / queue changed

	Compact (phones held sideways): no title, the four modes in one row, smaller buttons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)

local C = Theme.C

local PlayPanel = {}
PlayPanel.__index = PlayPanel

local player = Players.LocalPlayer

-- the mode you picked survives the lobby being rebuilt (e.g. turning your phone)
local lastMode = "chaos"

local function playerRange(mode): string
	if mode.minPlayers == mode.maxPlayers then
		return mode.maxPlayers .. " players"
	end
	return mode.minPlayers .. "-" .. mode.maxPlayers .. " players"
end

function PlayPanel.new(parent: Instance, popups: Instance, opts: { [string]: any }?)
	local self = setmetatable({}, PlayPanel)
	self.popups = popups
	self.mode = lastMode
	self.maid = Util.maid()
	self.tiles = {}
	local compact = opts ~= nil and opts.compact == true
	self.compact = compact

	local content, root = Widgets.panel(parent, {
		name = "PlayPanel",
		title = if compact then nil else "Play",
		titleWidth = 200,
		padding = if compact then 12 else 18,
		size = UDim2.fromScale(1, 1),
	})
	self.root = root

	-- mode tiles: 2 x 2, or one row when compact
	local findH = if compact then 50 else 58
	local smallH = if compact then 42 else 48
	local buttonsH = findH + 8 + smallH
	local grid = Util.frame(content, { Name = "Modes", Size = UDim2.new(1, 0, 1, -(buttonsH + 12)) })
	Util.new("UIGridLayout", {
		CellSize = if compact then UDim2.new(0.25, -9, 1, 0) else UDim2.new(0.5, -6, 0.5, -6),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, mode in Modes.list do
		self.tiles[mode.id] = self:_modeTile(grid, mode, i)
	end

	-- buttons
	local row = Util.frame(content, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, buttonsH),
	})
	self.findButton = Widgets.button(row, {
		name = "Find",
		text = "FIND A MATCH",
		icon = "play",
		style = "green",
		textSize = if compact then 22 else 26,
		depth = 6,
		size = UDim2.new(1, 0, 0, findH),
		onClick = function()
			self:_find()
		end,
	})
	self.practiceButton = Widgets.button(row, {
		name = "Practice",
		text = "PRACTICE",
		icon = "dice",
		style = "wood",
		textSize = if compact then 16 else 19,
		size = UDim2.new(0.5, -6, 0, smallH),
		position = UDim2.new(0, 0, 1, -smallH),
		onClick = function()
			self:_practice()
		end,
	})
	self.privateButton = Widgets.button(row, {
		name = "Private",
		text = if compact then "PRIVATE" else "PRIVATE MATCH",
		icon = "people",
		style = "blue",
		textSize = if compact then 16 else 19,
		size = UDim2.new(0.5, -6, 0, smallH),
		position = UDim2.new(0.5, 6, 1, -smallH),
		onClick = function()
			self:_private()
		end,
	})
	-- while searching, the Practice / Private row shows how the search is going
	local status = Util.frame(row, {
		Name = "Searching",
		Position = UDim2.new(0, 0, 1, -smallH),
		Size = UDim2.new(1, 0, 0, smallH),
		Visible = false,
	})
	local compass = Util.frame(status, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
	})
	Icons.make(compass, "compass", Icons.flatColors(C.ink, C.parchment))
	self.statusText = Widgets.label(status, {
		text = "",
		font = "heavy",
		size = 18,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -50, 1, 0),
		position = UDim2.fromOffset(48, 0),
	})
	self.statusText.TextTruncate = Enum.TextTruncate.AtEnd
	self.status = status
	task.spawn(function()
		while root.Parent do
			if status.Visible then
				compass.Rotation = (compass.Rotation + 6) % 360
				self:_updateStatus()
			end
			task.wait(0.1)
		end
	end)

	self.maid:add(State.watch("party", function()
		self:refresh()
	end))
	self.maid:add(State.watch("queue", function()
		self:refresh()
	end))
	self:refresh()
	return self
end

function PlayPanel:destroy()
	self.maid:clean()
end

function PlayPanel:_modeTile(grid: Frame, mode, order: number)
	local tile = Util.new("TextButton", {
		Name = mode.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.parchmentMid,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = grid,
	})
	Util.corner(tile, 12)
	local stroke = Util.stroke(tile, C.parchmentEdge, 2)
	local compact = self.compact
	local pad = if compact then 8 else 12
	local iconSize = if compact then 24 else 34
	local icon = Util.frame(tile, {
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.fromOffset(iconSize, iconSize),
	})
	Icons.make(icon, if mode.isTeam then "people" else "bolt", Icons.flatColors(C.ink, C.parchmentMid))
	local textX = pad + iconSize + 8
	Widgets.label(tile, {
		text = if compact then mode.short else mode.name,
		font = "chunky",
		size = if compact then 17 else 20,
		color = C.ink,
		sizeUDim = UDim2.new(1, -(textX + pad), 0, if compact then 20 else 24),
		position = UDim2.fromOffset(textX, if compact then 6 else 10),
		scaled = true,
	})
	Widgets.label(tile, {
		text = playerRange(mode),
		font = "heavy",
		size = if compact then 11 else 13,
		color = C.inkSoft,
		sizeUDim = UDim2.new(1, -(textX + pad), 0, 16),
		position = UDim2.fromOffset(textX, if compact then 26 else 34),
	})
	local top = if compact then 44 else 58
	Widgets.label(tile, {
		text = mode.blurb,
		font = "body",
		size = if compact then 13 else 15,
		minSize = 9,
		color = C.textDark,
		wrap = true,
		valign = "top",
		sizeUDim = UDim2.new(1, -2 * pad, 1, -(top + pad)),
		position = UDim2.fromOffset(pad, top),
		scaled = compact,
	})
	tile.Activated:Connect(function()
		if self.mode ~= mode.id then
			self.mode = mode.id
			lastMode = mode.id
			Util.bump(tile, 0.04)
			self:refresh()
		end
	end)
	return { frame = tile, stroke = stroke }
end

function PlayPanel:refresh()
	for id, t in self.tiles do
		local on = id == self.mode
		t.frame.BackgroundColor3 = if on then Color3.fromHex("FFF1C4") else C.parchmentMid
		t.stroke.Color = if on then C.brassDark else C.parchmentEdge
		t.stroke.Thickness = if on then 3 else 2
	end
	local party = State.get("party")
	local queue = State.get("queue")
	local searching = queue ~= nil and queue.state == "searching"
	local isLeader = party == nil or party.leader == player.UserId
	if searching then
		self.findButton:setText("CANCEL SEARCH")
		self.findButton:setStyle("red")
		self.findButton:setIcon("close")
		self.findButton:setEnabled(true)
		if not self.status.Visible then
			self.searchStart = os.clock() - (queue.elapsed or 0)
		end
	else
		self.findButton:setText("FIND A MATCH")
		self.findButton:setStyle("green")
		self.findButton:setIcon("play")
		self.findButton:setEnabled(isLeader)
	end
	self.status.Visible = searching
	self.practiceButton.root.Visible = not searching
	self.privateButton.root.Visible = not searching
	self.practiceButton:setEnabled(party == nil or #party.members <= 1)
	self.privateButton:setEnabled(party ~= nil and isLeader)
	self:_updateStatus()
end

function PlayPanel:_updateStatus()
	local queue = State.get("queue")
	if not queue or queue.state ~= "searching" then
		return
	end
	local mode = Modes.get(queue.mode or self.mode)
	local secs = math.floor(os.clock() - (self.searchStart or os.clock()))
	local others = if (queue.searching or 0) > 1 then ("  ·  " .. queue.searching .. " searching") else ""
	self.statusText.Text = "Finding a " .. (if mode then mode.short else "") .. " match  " .. string.format("%d:%02d", secs // 60, secs % 60) .. others
end

function PlayPanel:_find()
	local queue = State.get("queue")
	if queue and queue.state == "searching" then
		local ok, err = Net.request("mm.cancel")
		if not ok then
			Widgets.toast(tostring(err), "error")
		end
		return
	end
	local ok, err = Net.request("mm.queue", { mode = self.mode })
	if not ok then
		Widgets.toast(tostring(err), "error")
	end
end

-- Map / length options shared by Practice and Private Match.
local MAP_OPTIONS = { { text = "Random", value = "random" } }
for _, m in Maps.list do
	table.insert(MAP_OPTIONS, { text = m.name, value = m.id })
end
local LENGTH_OPTIONS = {}
for _, l in Modes.lengths do
	table.insert(LENGTH_OPTIONS, { text = l.name, value = l.id })
end

local function settingRow(parent: Instance, order: number, label: string, build: (Frame) -> ())
	local row = Util.frame(parent, { Name = label, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
	Widgets.label(row, {
		text = label,
		font = "chunky",
		size = 18,
		color = C.ink,
		sizeUDim = UDim2.new(0, 110, 1, 0),
	})
	local holder = Util.frame(row, { Position = UDim2.fromOffset(116, 0), Size = UDim2.new(1, -116, 1, 0) })
	build(holder)
	return row
end

function PlayPanel:_practice()
	local mode = Modes.get(self.mode)
	local settings = { map = "random", length = "quick", bots = 3 }
	local content, close = Widgets.modal(self.popups, {
		title = "Practice",
		titleWidth = 220,
		width = 620,
		height = 380,
	})
	local list = Util.frame(content, { Size = UDim2.new(1, 0, 1, -64) })
	Util.list(list, "y", 10, "Left", "Top")
	Widgets.label(list, {
		text = mode.name .. " against bots. Rewards are halved, so it's the place to learn the ropes.",
		font = "heavy",
		size = 16,
		color = C.inkSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
		layoutOrder = 0,
	})
	settingRow(list, 1, "Map", function(h)
		Widgets.choice(h, { options = MAP_OPTIONS, value = settings.map, size = UDim2.fromScale(1, 1), textSize = 15, onChange = function(v)
			settings.map = v
		end })
	end)
	settingRow(list, 2, "Length", function(h)
		Widgets.choice(h, { options = LENGTH_OPTIONS, value = settings.length, size = UDim2.fromScale(1, 1), onChange = function(v)
			settings.length = v
		end })
	end)
	if not mode.isTeam then
		local botOptions = {}
		for n = 1, mode.maxPlayers - 1 do
			table.insert(botOptions, { text = tostring(n), value = n })
		end
		settingRow(list, 3, "Bots", function(h)
			Widgets.choice(h, { options = botOptions, value = settings.bots, size = UDim2.fromScale(1, 1), onChange = function(v)
				settings.bots = v
			end })
		end)
	end
	Widgets.button(content, {
		text = "START",
		icon = "play",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(220, 52),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			close()
			local ok, err = Net.request("match.practice", {
				mode = self.mode,
				map = settings.map,
				length = settings.length,
				bots = settings.bots,
			})
			if not ok then
				Widgets.toast(tostring(err), "error")
			end
		end,
	})
end

function PlayPanel:_private()
	local party = State.get("party")
	if not party then
		Widgets.toast("Create a party first, then invite your friends.", "info")
		return
	end
	local s = table.clone(party.settings or {})
	local content, close = Widgets.modal(self.popups, {
		title = "Private Match",
		titleWidth = 280,
		width = 640,
		height = 430,
	})
	local list = Util.frame(content, { Size = UDim2.new(1, 0, 1, -64) })
	Util.list(list, "y", 10, "Left", "Top")
	local function save(fields)
		local ok, err = Net.request("party.settings", fields)
		if not ok then
			Widgets.toast(tostring(err), "error")
		end
	end
	local modeOptions = {}
	for _, m in Modes.list do
		table.insert(modeOptions, { text = m.short, value = m.id })
	end
	local botRow
	settingRow(list, 1, "Mode", function(h)
		Widgets.choice(h, { options = modeOptions, value = s.mode or "chaos", size = UDim2.fromScale(1, 1), onChange = function(v)
			s.mode = v
			save({ mode = v })
			if botRow then
				local m = Modes.get(v)
				botRow.Visible = m ~= nil and not m.isTeam
			end
		end })
	end)
	settingRow(list, 2, "Map", function(h)
		Widgets.choice(h, { options = MAP_OPTIONS, value = s.map or "random", size = UDim2.fromScale(1, 1), textSize = 15, onChange = function(v)
			save({ map = v })
		end })
	end)
	settingRow(list, 3, "Length", function(h)
		Widgets.choice(h, { options = LENGTH_OPTIONS, value = s.length or "quick", size = UDim2.fromScale(1, 1), onChange = function(v)
			save({ length = v })
		end })
	end)
	local botOptions = {}
	for n = 0, 5 do
		table.insert(botOptions, { text = tostring(n), value = n })
	end
	botRow = settingRow(list, 4, "Bots", function(h)
		Widgets.choice(h, { options = botOptions, value = s.bots or 0, size = UDim2.fromScale(1, 1), onChange = function(v)
			save({ bots = v })
		end })
	end)
	local m = Modes.get(s.mode or "chaos")
	botRow.Visible = m ~= nil and not m.isTeam
	Widgets.label(list, {
		text = "Team modes fill empty seats with bots automatically.",
		font = "body",
		size = 14,
		color = C.inkSoft,
		sizeUDim = UDim2.new(1, 0, 0, 20),
		layoutOrder = 5,
	})
	Widgets.button(content, {
		text = "START MATCH",
		icon = "play",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(260, 52),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = function()
			close()
			local ok, err = Net.request("match.private")
			if not ok then
				Widgets.toast(tostring(err), "error")
			end
		end,
	})
end

return PlayPanel
