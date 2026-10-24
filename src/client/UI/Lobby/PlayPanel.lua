--[[
	PlayPanel
	The left half of the lobby: the character you play (CHANGE opens the character
	picker), this week's event, the classic modes, then Find a Match (public
	matchmaking), Practice against bots, or start a Private Match with your party.

		local panel = PlayPanel.new(parent, popupLayer, { compact = bool })
		panel:refresh()   -- party / queue changed

	Compact (phones held sideways): no title, every mode in one row, smaller buttons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)
local Items = require(Shared.Game.Items)
local HouseRules = require(Shared.Game.HouseRules)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CharacterSelect = require(script.Parent.CharacterSelect)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)
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
	-- under the lobby's tabs (upright phones) the tab already says "Play"
	local titled = not compact and not (opts ~= nil and opts.untitled == true)

	local content, root = Widgets.panel(parent, {
		name = "PlayPanel",
		title = if titled then "Play" else nil,
		titleWidth = 200,
		padding = if compact then 12 else 18,
		size = UDim2.fromScale(1, 1),
	})
	self.root = root

	local findH = if compact then 50 else 58
	local smallH = if compact then 42 else 48
	local buttonsH = findH + 8 + smallH

	-- your character
	local stripH = if compact then 44 else 62
	local stripHolder = Util.frame(content, { Name = "Character", Size = UDim2.new(1, 0, 0, stripH) })
	local strip = CharacterSelect.strip(stripHolder, {
		compact = compact,
		onChange = function()
			CharacterSelect.open(popups)
		end,
	})
	self.maid:add(strip.destroy)
	local top = stripH + (if compact then 8 else 12)

	-- this week's event: a wide banner tile over the classic modes (one more tile in a
	-- row when compact)
	local event = Progress.currentEvent()
	local classic = {}
	local eventMode = nil
	for _, mode in Modes.list do
		if mode.isEvent then
			eventMode = mode
		else
			table.insert(classic, mode)
		end
	end
	if eventMode and not compact then
		local bannerH = 58
		local holder = Util.frame(content, { Name = "Event", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, bannerH) })
		self.tiles[eventMode.id] = self:_eventTile(holder, eventMode, event)
		top += bannerH + 12
	end
	local grid = Util.frame(content, { Name = "Modes", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -(buttonsH + 12 + top)) })
	local inRow = if compact then #classic + (if eventMode then 1 else 0) else 2
	local rows = if compact then 1 else math.ceil(#classic / 2)
	for i, mode in classic do
		self.tiles[mode.id] = self:_modeTile(grid, mode, i)
	end
	if eventMode and compact then
		self.tiles[eventMode.id] = self:_modeTile(grid, eventMode, 0, event)
	end
	Util.grid(grid, inRow, rows, 12)

	-- buttons
	local row = Util.frame(content, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, buttonsH),
	})
	self.findButton = Widgets.button(row, {
		name = "Find",
		text = "Find a match",
		icon = "play",
		style = "brass",
		textSize = if compact then 20 else 22,
		size = UDim2.new(1, 0, 0, findH),
		onClick = function()
			self:_find()
		end,
	})
	self.practiceButton = Widgets.button(row, {
		name = "Practice",
		text = "Practice",
		icon = "dice",
		style = "wood",
		textSize = if compact then 16 else 18,
		size = UDim2.new(0.5, -6, 0, smallH),
		position = UDim2.new(0, 0, 1, -smallH),
		onClick = function()
			self:_practice()
		end,
	})
	self.privateButton = Widgets.button(row, {
		name = "Private",
		text = if compact then "Private" else "Private match",
		icon = "people",
		style = "wood",
		textSize = if compact then 16 else 18,
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
	Icons.medallion(compass, "dice", C.sun, { Size = UDim2.fromScale(1, 1) })
	self.statusText = Widgets.label(status, {
		text = "",
		font = "heavy",
		size = 18,
		color = C.text,
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

-- The weekly event as a wide tile: its name, its twist, in its own colour.
function PlayPanel:_eventTile(holder: Frame, mode, event)
	local color = Color3.fromHex(string.sub(event.color, 2))
	local tile = Util.new("TextButton", {
		Name = mode.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Util.corner(tile, 12)
	local stroke = Util.stroke(tile, C.line, 2)
	local ic = Util.frame(tile, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(34, 34) })
	Icons.medallion(ic, "star", color, { Size = UDim2.fromScale(1, 1) })
	Widgets.label(tile, {
		text = "This week: " .. event.name,
		font = "chunky",
		size = 18,
		color = C.text,
		sizeUDim = UDim2.new(1, -66, 0, 22),
		position = UDim2.fromOffset(56, 7),
	}).TextTruncate = Enum.TextTruncate.AtEnd
	Widgets.label(tile, {
		text = event.blurb .. "  ·  " .. playerRange(mode),
		font = "body",
		size = 14,
		minSize = 9,
		color = C.textSoft,
		wrap = true,
		valign = "top",
		scaled = true,
		sizeUDim = UDim2.new(1, -66, 1, -34),
		position = UDim2.fromOffset(56, 30),
	})
	tile.Activated:Connect(function()
		if self.mode ~= mode.id then
			self.mode = mode.id
			lastMode = mode.id
			Util.bump(tile, 0.03)
			self:refresh()
		end
	end)
	return { frame = tile, stroke = stroke }
end

function PlayPanel:_modeTile(grid: Frame, mode, order: number, event: any?)
	local tile = Util.new("TextButton", {
		Name = mode.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = grid,
	})
	Util.corner(tile, 12)
	local stroke = Util.stroke(tile, C.line, 2)
	local compact = self.compact
	local pad = if compact then 8 else 12
	local iconSize = if compact then 24 else 28
	local icon = Util.frame(tile, {
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.fromOffset(iconSize, iconSize),
	})
	Icons.medallion(icon, if mode.isEvent then "star" elseif mode.isTeam then "people" elseif mode.id == "blitz" then "hourglass" else "bolt", if mode.isEvent then C.pink else C.sun, { Size = UDim2.fromScale(1, 1) })
	local textX = pad + iconSize + 10
	-- the name, with the player count beside it on a wide tile (under it on a narrow one)
	local name = Widgets.label(tile, {
		text = if event then (if compact then "Event" else event.name) elseif compact then mode.short else mode.name,
		font = "chunky",
		size = if compact then 17 else 18,
		color = C.text,
		sizeUDim = UDim2.new(1, -(textX + pad + (if compact then 0 else 76)), 0, if compact then 22 else 24),
		position = UDim2.fromOffset(textX, if compact then 8 else pad + (iconSize - 24) / 2),
		scaled = true,
	})
	local count = Widgets.label(tile, {
		text = playerRange(mode),
		font = "heavy",
		size = if compact then 12 else 13,
		color = C.textSoft,
		align = if compact then "left" else "right",
		sizeUDim = if compact then UDim2.new(1, -2 * pad, 0, 16) else UDim2.fromOffset(72, 24),
		anchor = if compact then Vector2.zero else Vector2.new(1, 0),
		position = if compact then UDim2.fromOffset(pad, 36) else UDim2.new(1, -pad, 0, pad + (iconSize - 24) / 2),
	})
	local top = if compact then 56 else pad + iconSize + 8
	local blurb = Widgets.label(tile, {
		text = if event then event.blurb else mode.blurb,
		font = "body",
		size = if compact then 13 else 15,
		minSize = 9,
		color = C.text,
		wrap = true,
		valign = "top",
		sizeUDim = UDim2.new(1, -2 * pad, 1, -(top + pad)),
		position = UDim2.fromOffset(pad, top),
		scaled = compact,
	})
	-- a short tile (a small screen, or the lobby giving room to your character and the
	-- event) shows just the name and player count
	local function fit()
		local k = math.max(0.01, Util.inheritedScale(tile, true))
		local h = tile.AbsoluteSize.Y / k
		blurb.Visible = h >= top + pad + 30
		-- (and a very short compact tile has room for the name only)
		count.Visible = not compact or h >= 36 + 16 + 2
		if not compact then
			-- a one-line tile keeps its row centred; a tall one starts at the top
			local y = if blurb.Visible then pad else math.max(2, math.floor((h - iconSize) / 2))
			icon.Position = UDim2.fromOffset(pad, y)
			name.Position = UDim2.fromOffset(textX, y + (iconSize - 24) / 2)
			count.Position = UDim2.new(1, -pad, 0, y + (iconSize - 24) / 2)
		end
	end
	tile:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
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
		t.frame.BackgroundColor3 = if on then C.mine else C.panelRaised
		t.stroke.Color = if on then C.orange else C.line
		t.stroke.Thickness = 2
	end
	local party = State.get("party")
	local queue = State.get("queue")
	local searching = queue ~= nil and queue.state == "searching"
	local isLeader = party == nil or party.leader == player.UserId
	if searching then
		self.findButton:setText("Cancel search")
		self.findButton:setStyle("red")
		self.findButton:setIcon("close")
		self.findButton:setEnabled(true)
		if not self.status.Visible then
			self.searchStart = os.clock() - (queue.elapsed or 0)
		end
	else
		self.findButton:setText("Find a match")
		self.findButton:setStyle("brass")
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

-- The maps in a grid: five to a row, or three on narrow screens.
local function mapGrid(): (number, number)
	local _, _, narrow = Widgets.room()
	local cols = if narrow then 3 else 5
	local rows = math.ceil(#MAP_OPTIONS / cols)
	return cols, rows * 36 + (rows - 1) * 6
end

-- A label and its choices side by side, or the label on top on narrow screens
-- (`height`: the choices', when they take more than one row).
local function settingRow(parent: Instance, order: number, label: string, build: (Frame) -> (), height: number?)
	local _, _, narrow = Widgets.room()
	local h = height or 40
	local row = Util.frame(parent, { Name = label, Size = UDim2.new(1, 0, 0, if narrow then 26 + h else h), LayoutOrder = order })
	Widgets.label(row, {
		text = label,
		font = "chunky",
		size = 18,
		color = C.text,
		sizeUDim = if narrow then UDim2.new(1, 0, 0, 22) else UDim2.new(0, 110, 1, 0),
	})
	local holder = if narrow
		then Util.frame(row, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, h) })
		else Util.frame(row, { Position = UDim2.fromOffset(116, 0), Size = UDim2.new(1, -116, 1, 0) })
	build(holder)
	return row
end

function PlayPanel:_practice()
	local mode = Modes.get(self.mode)
	local settings = { map = "random", length = "quick", bots = 3 }
	local roomW, _, narrow = Widgets.room()
	local cols, gridH = mapGrid()
	local content, close = Widgets.modal(self.popups, {
		title = "Practice",
		titleWidth = 220,
		width = math.min(620, roomW),
		height = (if narrow then 470 else 380) + gridH - 40,
	})
	local list = Util.frame(content, { Size = UDim2.new(1, 0, 1, -64) })
	Util.list(list, "y", 10, "Left", "Top")
	Widgets.label(list, {
		text = mode.name .. " against bots. Rewards are halved, so it's the place to learn the ropes.",
		font = "heavy",
		size = 16,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
		layoutOrder = 0,
	})
	settingRow(list, 1, "Map", function(h)
		Widgets.choice(h, { options = MAP_OPTIONS, value = settings.map, size = UDim2.fromScale(1, 1), textSize = 15, columns = cols, onChange = function(v)
			settings.map = v
		end })
	end, gridH)
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
		text = "Start",
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

-- The house rules' choices (short names: the rows are narrow on a phone).
local VOTE_OPTIONS = {
	{ text = "Off", value = "off" },
	{ text = "Most votes", value = "majority" },
	{ text = "Roulette", value = "roulette" },
}
local BOARD_OPTIONS = { { text = "Full", value = "full" }, { text = "Short", value = "short" } }
local TIMER_OPTIONS = {}
for _, t in HouseRules.options.timer do
	table.insert(TIMER_OPTIONS, { text = if t == 0 then "Off" else (t .. "s"), value = t })
end
local POWER_OPTIONS = { { text = "Empty", value = "empty" }, { text = "Half", value = "half" }, { text = "Full", value = "full" } }
local CARD_OPTIONS = {}
for _, n in HouseRules.options.cards do
	table.insert(CARD_OPTIONS, { text = tostring(n), value = n })
end
local TWIST_SHORT = { trap_frenzy = "Traps", bonk_bonanza = "Bonks", power_surge = "Power", triple_dice = "3 dice" }
local TWIST_OPTIONS = {}
for _, id in HouseRules.options.twist do
	table.insert(TWIST_OPTIONS, { text = if id == "none" then "None" else (TWIST_SHORT[id] or id), value = id })
end

local function twistNote(id: string): string
	local e = Progress.eventById(id)
	if not e then
		return "No twist: the rules as they are."
	end
	return e.name .. ": " .. e.blurb
end

--[[
	Private match settings, on three pages: the match (mode, map or map vote, length,
	bots), its house rules, and the cards it bans. Only the party leader can change them
	(everyone else sees them); each change is saved to the party at once.
]]
function PlayPanel:_private()
	local party = State.get("party")
	if not party then
		Widgets.toast("Create a party first, then invite your friends.", "info")
		return
	end
	local s = table.clone(party.settings or {})
	local rules = HouseRules.clean(s.rules)
	local leader = party.leader == player.UserId
	local roomW, _, narrow = Widgets.room()
	local content, close = Widgets.modal(self.popups, {
		title = "Private match",
		titleWidth = 280,
		width = math.min(700, roomW),
		height = if narrow then 640 else 560,
	})
	local function save(fields)
		local ok, err = Net.request("party.settings", fields)
		if not ok then
			Widgets.toast(tostring(err), "error")
		end
	end
	local function setRule(key: string, value: any)
		rules[key] = value
		save({ rules = { [key] = value } })
	end
	local choices = {}
	local function choice(h: Frame, options, value, onChange, textSize: number?, columns: number?)
		local c = Widgets.choice(h, { options = options, value = value, size = UDim2.fromScale(1, 1), textSize = textSize, columns = columns, onChange = onChange })
		if not leader then
			c:setEnabled(false)
		end
		table.insert(choices, c)
		return c
	end
	-- an on / off switch with a few words on what it does
	local function switch(h: Frame, value: boolean, note: string, onChange: (boolean) -> ())
		local t
		t = Widgets.toggle(h, {
			value = value,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
			onChange = function(v)
				if not leader then
					t:set(not v, true)
					Widgets.toast("Only the party leader can change match settings.", "info")
					return
				end
				onChange(v)
			end,
		})
		Widgets.label(h, {
			text = note,
			font = "body",
			size = 14,
			minSize = 10,
			color = C.textSoft,
			wrap = true,
			scaled = true,
			sizeUDim = UDim2.new(1, -88, 1, 0),
			position = UDim2.fromOffset(86, 0),
		})
		return t
	end

	-- the pages, and the tabs across the top that switch between them
	local pages = {}
	local function page(name: string): ScrollingFrame
		local p = Widgets.scroll(content, {
			name = name,
			size = UDim2.new(1, 0, 1, -40 - 12 - 64),
			position = UDim2.fromOffset(0, 52),
			gap = 10,
			hAlign = "Left",
			padding = 4,
		})
		local pad = p:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingRight = UDim.new(0, 16)
		end
		p.Visible = name == "match"
		pages[name] = p
		return p
	end
	local tabs = Util.frame(content, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 40) })
	Widgets.choice(tabs, {
		options = { { text = "Match", value = "match" }, { text = "House rules", value = "rules" }, { text = "Cards", value = "cards" } },
		value = "match",
		size = UDim2.fromScale(1, 1),
		onChange = function(v)
			for name, p in pages do
				p.Visible = name == v
			end
		end,
	})

	-- the match
	local main = page("match")
	local modeOptions = {}
	for _, m in Modes.list do
		table.insert(modeOptions, { text = m.short, value = m.id })
	end
	local botRow, mapRow, voteRow
	local function showRows()
		local m = Modes.get(s.mode or "chaos")
		botRow.Visible = m ~= nil and not m.isTeam
		mapRow.Visible = rules.vote == "off"
		voteRow.Visible = rules.vote ~= "off"
	end
	settingRow(main, 1, "Mode", function(h)
		choice(h, modeOptions, s.mode or "chaos", function(v)
			s.mode = v
			save({ mode = v })
			showRows()
		end)
	end)
	settingRow(main, 2, "Map vote", function(h)
		choice(h, VOTE_OPTIONS, rules.vote, function(v)
			setRule("vote", v)
			showRows()
		end)
	end)
	local mapCols, mapH = mapGrid()
	mapRow = settingRow(main, 3, "Map", function(h)
		choice(h, MAP_OPTIONS, s.map or "random", function(v)
			save({ map = v })
		end, 15, mapCols)
	end, mapH)
	voteRow = Util.frame(main, { Name = "VoteCards", Size = UDim2.new(1, 0, 0, if narrow then 92 else 44), LayoutOrder = 4 })
	do
		local half = if narrow then UDim2.new(1, 0, 0, 44) else UDim2.new(0.5, -6, 1, 0)
		local a = Util.frame(voteRow, { Size = half })
		switch(a, rules.mystery, "A face-down Mystery map among the cards", function(v)
			setRule("mystery", v)
		end)
		local b = Util.frame(voteRow, { Size = half, Position = if narrow then UDim2.fromOffset(0, 48) else UDim2.new(0.5, 6, 0, 0) })
		switch(b, rules.wildcard, "A map with a random twist among the cards", function(v)
			setRule("wildcard", v)
		end)
	end
	settingRow(main, 5, "Length", function(h)
		choice(h, LENGTH_OPTIONS, s.length or "quick", function(v)
			save({ length = v })
		end)
	end)
	local botOptions = {}
	for n = 0, 5 do
		table.insert(botOptions, { text = tostring(n), value = n })
	end
	botRow = settingRow(main, 6, "Bots", function(h)
		choice(h, botOptions, s.bots or 0, function(v)
			save({ bots = v })
		end)
	end)
	Widgets.label(main, {
		text = "Team modes fill empty seats with bots automatically. Roulette: every vote is a slice of a wheel, and the wheel decides.",
		font = "body",
		size = 14,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
		layoutOrder = 7,
	})
	showRows()

	-- house rules
	local hr = page("rules")
	settingRow(hr, 1, "Board", function(h)
		choice(h, BOARD_OPTIONS, rules.board, function(v)
			setRule("board", v)
		end)
	end)
	settingRow(hr, 2, "Turn timer", function(h)
		choice(h, TIMER_OPTIONS, rules.timer, function(v)
			setRule("timer", v)
		end)
	end)
	settingRow(hr, 3, "Power", function(h)
		choice(h, POWER_OPTIONS, rules.power, function(v)
			setRule("power", v)
		end)
	end)
	settingRow(hr, 4, "Cards", function(h)
		choice(h, CARD_OPTIONS, rules.cards, function(v)
			setRule("cards", v)
		end)
	end)
	settingRow(hr, 5, "Abilities", function(h)
		switch(h, rules.abilities, "Characters' abilities and the Power bar", function(v)
			setRule("abilities", v)
		end)
	end)
	settingRow(hr, 6, "Wanted", function(h)
		switch(h, rules.wanted, "A price on the leader's head, for whoever bonks them", function(v)
			setRule("wanted", v)
		end)
	end)
	settingRow(hr, 7, "Underdog", function(h)
		switch(h, rules.underdog, "A gold die for whoever is clearly last", function(v)
			setRule("underdog", v)
		end)
	end)
	local note
	settingRow(hr, 8, "Twist", function(h)
		choice(h, TWIST_OPTIONS, rules.twist, function(v)
			setRule("twist", v)
			note.Text = twistNote(v)
		end)
	end)
	note = Widgets.label(hr, {
		text = twistNote(rules.twist),
		font = "body",
		size = 14,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 38),
		layoutOrder = 9,
	})
	Widgets.label(hr, {
		text = "Board: Short keeps about two thirds of the trail. Power and Cards: what everyone starts with.",
		font = "body",
		size = 14,
		color = C.textFaint,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 38),
		layoutOrder = 10,
	})

	-- banned cards
	local cp = page("cards")
	local banNote = Widgets.label(cp, {
		text = "",
		font = "body",
		size = 14,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
		layoutOrder = 1,
	})
	local grid = Util.frame(cp, { Name = "Bans", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(if narrow then 84 else 96, if narrow then 96 else 104),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	local cells = {}
	local function paintBans()
		local n = HouseRules.banCount(rules)
		banNote.Text = "Tap a card to keep it out of this match (the wheels, the Potion Seller and starting hands skip it). "
			.. n .. " of " .. HouseRules.MaxBans .. " banned; two traps always stay."
		for id, cell in cells do
			local banned = rules.banned[id] == true
			cell.cross.Visible = banned
			cell.root.BackgroundColor3 = if banned then C.badSoft else C.panelRaised
			cell.stroke.Color = if banned then C.coral else C.line
		end
	end
	for i, id in HouseRules.bannable do
		local item = Items.get(id)
		if not item then
			continue
		end
		local root = Util.new("TextButton", {
			Name = "Ban_" .. id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		})
		Util.corner(root, 10)
		local stroke = Util.stroke(root, C.line, 2)
		local icon = Util.frame(root, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(52, 52),
		})
		Icons.medallion(icon, id, Theme.Category[item.category] or C.neutral, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(root, {
			text = item.name,
			font = "chunky",
			size = 13,
			minSize = 9,
			color = C.text,
			align = "center",
			wrap = true,
			scaled = true,
			sizeUDim = UDim2.new(1, -8, 0, 32),
			position = UDim2.new(0, 4, 1, -36),
		})
		-- a red slash across a banned card
		local cross = Util.new("Frame", {
			Name = "Banned",
			BackgroundColor3 = C.coral,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 32),
			Size = UDim2.fromOffset(66, 8),
			Rotation = -35,
			ZIndex = 5,
			Visible = false,
			Parent = root,
		})
		Util.corner(cross, 0.5)
		Util.stroke(cross, C.ink, 2)
		cells[id] = { root = root, stroke = stroke, cross = cross }
		root.Activated:Connect(function()
			if not leader then
				Widgets.toast("Only the party leader can change match settings.", "info")
				return
			end
			local want = table.clone(rules.banned)
			want[id] = if want[id] then nil else true
			if want[id] then
				local traps = 0
				for _, t in Items.trapIds do
					if t ~= "wall" and not want[t] then
						traps += 1
					end
				end
				if HouseRules.banCount(rules) >= HouseRules.MaxBans then
					Widgets.toast("You can ban up to " .. HouseRules.MaxBans .. " cards.", "info")
					return
				elseif traps < HouseRules.MinTraps then
					Widgets.toast("At least two traps have to stay in the game.", "info")
					return
				end
			end
			local test = table.clone(rules)
			test.banned = want
			local cleaned = HouseRules.clean(test)
			Sound.play("click")
			Util.bump(root, 0.06)
			rules.banned = cleaned.banned
			paintBans()
			save({ rules = { banned = cleaned.banned } })
		end)
	end
	paintBans()

	if leader then
		Widgets.button(content, {
			text = "Start match",
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
	else
		Widgets.label(content, {
			text = "The party leader picks these and starts the match.",
			font = "heavy",
			size = 16,
			color = C.textSoft,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 52),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, 0),
		})
	end
end

return PlayPanel
