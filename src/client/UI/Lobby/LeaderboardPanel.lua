--[[
	LeaderboardPanel
	The all-time top players: most wins, most treasures found, highest level. Each row
	shows the player's avatar, display name and @username; your own row is gold, and
	the footer says where you stand even when you're not in the top 50.

		local panel = LeaderboardPanel.new(parent, { title = bool, untitled = bool })
		panel:destroy()
	title = false fills `parent` plainly (inside a modal); untitled keeps the parchment
	panel without its title (under the lobby's tabs).
]]

local Players = game:GetService("Players")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)

local Client = UI.Parent
local Net = require(Client.Net)

local C = Theme.C
local hex = Theme.hex

local LeaderboardPanel = {}
LeaderboardPanel.__index = LeaderboardPanel

local player = Players.LocalPlayer

local BOARDS = {
	{ id = "wins", text = "Wins", unit = "win", units = "wins" },
	{ id = "treasures", text = "Treasures", unit = "treasure", units = "treasures" },
	{ id = "level", text = "Level", unit = "", units = "" },
}
local MEDALS = { hex("E2B53C"), hex("B8C0C8"), hex("C98A4B") }
local CACHE_TIME = 30

-- shared between panels (the lobby rebuilds them when the screen changes shape)
local selected = "wins"
local cache = {} -- [board] = { at, data }

local function boardDef(id: string)
	for _, b in BOARDS do
		if b.id == id then
			return b
		end
	end
	return BOARDS[1]
end

local function valueText(def, value: number): string
	if def.id == "level" then
		return "LV " .. value
	end
	return Util.commas(value)
end

function LeaderboardPanel.new(parent: Instance, opts)
	local self = setmetatable({}, LeaderboardPanel)
	self.alive = true
	local o = opts or {}
	local content, root
	if o.title ~= false then
		content, root = Widgets.panel(parent, {
			name = "LeaderboardPanel",
			title = if o.untitled then nil else "Top Players",
			titleWidth = 220,
			size = UDim2.fromScale(1, 1),
		})
	else
		root = Util.frame(parent, { Name = "LeaderboardPanel" })
		content = root
	end
	self.root = root

	self.choice = Widgets.choice(content, {
		options = (function()
			local list = {}
			for _, b in BOARDS do
				table.insert(list, { text = b.text, value = b.id })
			end
			return list
		end)(),
		value = selected,
		size = UDim2.new(1, 0, 0, 38),
		textSize = 16,
		onChange = function(v)
			selected = v
			self:load(v)
		end,
	})
	self.list = Widgets.scroll(content, {
		name = "Rows",
		position = UDim2.fromOffset(0, 46),
		size = UDim2.new(1, 0, 1, -46 - 40),
		gap = 5,
		padding = 2,
	})
	self.footer = Widgets.label(content, {
		text = "",
		font = "heavy",
		size = 15,
		color = C.textSoft,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 32),
		anchor = Vector2.new(0, 1),
		position = UDim2.fromScale(0, 1),
	})
	self.footer.TextWrapped = true
	self:load(selected)
	return self
end

function LeaderboardPanel:destroy()
	self.alive = false
	self.root:Destroy()
end

function LeaderboardPanel:_note(text: string)
	Util.clear(self.list, true)
	local note = Widgets.label(self.list, {
		text = text,
		font = "heavy",
		size = 15,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, -8, 0, 60),
	})
	note.Name = "Note"
end

function LeaderboardPanel:load(board: string)
	self.loadingBoard = board
	local c = cache[board]
	if c and os.clock() - c.at < CACHE_TIME then
		self:_render(c.data)
		return
	end
	self:_note("Unrolling the scroll...")
	self.footer.Text = ""
	task.spawn(function()
		local ok, data = Net.request("leaderboard.get", { board = board })
		if not self.alive or self.loadingBoard ~= board then
			return
		end
		if not ok or type(data) ~= "table" then
			self:_note("Couldn't load the leaderboard right now. Try again in a bit!")
			return
		end
		cache[board] = { at = os.clock(), data = data }
		self:_render(data)
	end)
end

function LeaderboardPanel:_render(data)
	local def = boardDef(data.board)
	Util.clear(self.list, true)
	if #data.entries == 0 then
		self:_note("Nobody's on this board yet. Finish a match to claim the top spot!")
	end
	for i, e in data.entries do
		self:_row(i, e, def)
	end
	local me = data.me or {}
	local mine = valueText(def, me.value or 0) .. (if def.units ~= "" then (" " .. (if me.value == 1 then def.unit else def.units)) else "")
	if me.rank then
		self.footer.Text = "You're #" .. me.rank .. " with " .. mine
	else
		self.footer.Text = "You: " .. mine .. "  ·  top 50 shown"
	end
	if data.live == false then
		self.footer.Text ..= "  (this server only while testing)"
	end
end

function LeaderboardPanel:_row(i: number, e, def)
	local mine = e.userId == player.UserId
	local row = Util.new("Frame", {
		Name = "Row" .. i,
		BackgroundColor3 = if mine then C.mine else C.panelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 46),
		LayoutOrder = i,
		Parent = self.list,
	})
	Util.corner(row, 10)
	Util.stroke(row, if mine then C.brass else C.panelEdge, if mine then 2 else 1.5)
	-- rank: medals for the top three
	local rank = Util.new("Frame", {
		Name = "Rank",
		BackgroundColor3 = MEDALS[e.rank] or C.panelDeep,
		BackgroundTransparency = if MEDALS[e.rank] then 0 else 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Parent = row,
	})
	Util.corner(rank, 0.5)
	if MEDALS[e.rank] then
		Util.stroke(rank, Util.shade(MEDALS[e.rank], -0.35), 2)
	end
	Widgets.label(rank, {
		text = tostring(e.rank),
		font = "chunky",
		size = if e.rank >= 10 then 14 else 17,
		color = if MEDALS[e.rank] then C.textOnLight else C.textSoft,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
	})
	Avatars.portrait(row, { userId = e.userId, name = e.name }, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
	}, { ring = if mine then C.brass else C.panelEdge, ringPx = 2 })
	-- the score on the right (the tab already says what it counts), names get the rest
	local SCORE_W = 58
	local textX = 82
	local name = Widgets.label(row, {
		text = e.name .. (if mine then " (you)" else ""),
		font = "heavy",
		size = 15,
		color = C.text,
		sizeUDim = UDim2.new(1, -(textX + SCORE_W + 12), 0, 20),
		position = UDim2.fromOffset(textX, 4),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	if e.username then
		local user = Widgets.label(row, {
			text = "@" .. e.username,
			font = "body",
			size = 12,
			color = C.textSoft,
			sizeUDim = UDim2.new(1, -(textX + SCORE_W + 12), 0, 16),
			position = UDim2.fromOffset(textX, 25),
		})
		user.TextTruncate = Enum.TextTruncate.AtEnd
	end
	Widgets.label(row, {
		name = "Score",
		text = valueText(def, e.value),
		font = "chunky",
		size = 18,
		color = MEDALS[e.rank] or C.text,
		align = "right",
		sizeUDim = UDim2.fromOffset(SCORE_W, 26),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
	})
end

return LeaderboardPanel
