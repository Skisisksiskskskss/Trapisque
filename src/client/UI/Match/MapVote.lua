--[[
	MapVote
	Quick Play opens with a vote: three maps side by side (stacked on an upright phone),
	each with its colours, its hazard and what it does. Tap one to vote; everyone's
	vote shows as a dot in their character's colour, and a countdown runs to the
	server's deadline. The winner flashes before the board comes up.

		MapVote.show(layer, data)   -- the server's "match.vote" (again for each vote)
		MapVote.result(mapId)       -- "match.voted"
		MapVote.close()
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Items = require(Shared.Game.Items)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local StickerArt = require(UI.StickerArt)
local MapScenes = require(script.Parent.MapScenes)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)

local C = Theme.C

local MapVote = {}

local open = nil -- { root, cards = { [mapId] = card }, data, maid }

local function hex(s: string?): Color3
	return Color3.fromHex(string.sub(s or "#888888", 2))
end

-- The hazard each map is known for, as its sticker.
local HAZARD_ART = { river = "river", gate = "gate", slime = "slime", lava = "lava" }

local function card(parent: Instance, mapId: string, onPick: () -> ())
	local def = Maps.get(mapId)
	local scene = MapScenes[mapId] or MapScenes.blissful
	local col = scene.colors
	local root = Util.new("TextButton", {
		Name = "Map_" .. mapId,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		Selectable = true,
		Parent = parent,
	})
	Util.corner(root, 14)
	local rim = Util.stroke(root, C.line, 3)
	-- a little picture of the place: its sea, an island in its land colours, the hazard
	local pic = Util.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = hex(col.water),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0.5, -10),
		ClipsDescendants = true,
		Parent = root,
	})
	Util.corner(pic, 10)
	Util.stroke(pic, C.line, 2.5)
	for i, blob in { { 0.32, 0.62, 0.9 }, { 0.62, 0.48, 1.0 }, { 0.82, 0.7, 0.55 } } do
		local shore = Util.new("Frame", {
			BackgroundColor3 = hex(col.shallows),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(blob[1], blob[2]),
			Size = UDim2.fromScale(blob[3] * 0.62, blob[3] * 0.95),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 1,
			Parent = pic,
		})
		Util.corner(shore, 0.5)
		local land = Util.new("Frame", {
			BackgroundColor3 = hex(if i == 2 then col.inner else col.land),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			ZIndex = 2,
			Parent = shore,
		})
		Util.corner(land, 0.5)
		Util.stroke(land, C.line, 2)
	end
	local art = if def.naturalKind == "ghost" then StickerArt.misc.ghost else StickerArt.hazards[HAZARD_ART[def.naturalKind or ""] or "river"]
	if art then
		Icons.sticker(pic, art, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 5,
		}, 0.07)
	end
	Widgets.label(root, {
		text = string.upper(def.name),
		font = "chunky",
		size = 22,
		color = C.text,
		outline = C.line,
		align = "center",
		scaled = true,
		sizeUDim = UDim2.new(1, -16, 0, 26),
		position = UDim2.new(0, 8, 0.5, 6),
	})
	local counter = Items.get(def.counterItem or "")
	Widgets.label(root, {
		text = def.blurb .. (if counter then ("  Counter: " .. counter.name .. ".") else ""),
		font = "body",
		size = 14,
		minSize = 9,
		color = C.textSoft,
		wrap = true,
		valign = "top",
		scaled = true,
		sizeUDim = UDim2.new(1, -20, 0.5, -72),
		position = UDim2.new(0, 10, 0.5, 36),
	})
	-- who voted for it: a dot in each voter's colour
	local dots = Util.frame(root, {
		Name = "Votes",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 22),
	})
	Util.list(dots, "x", 6, "Center", "Center")
	root.Activated:Connect(onPick)
	return { root = root, rim = rim, dots = dots }
end

local function paint(data)
	if not open then
		return
	end
	local mine = nil
	local counts = {}
	for seatKey, mapId in data.votes or {} do
		counts[mapId] = (counts[mapId] or 0) + 1
		if tonumber(seatKey) == data.seat then
			mine = mapId
		end
	end
	local colorOf = {}
	for _, s in data.seats or {} do
		colorOf[s.seat] = Theme.playerColor(s.character)
	end
	for mapId, c in open.cards do
		Util.clear(c.dots, true)
		for seatKey, voted in data.votes or {} do
			if voted == mapId then
				local dot = Util.new("Frame", {
					Name = "Vote",
					BackgroundColor3 = colorOf[tonumber(seatKey) or 0] or C.sun,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(20, 20),
					Parent = c.dots,
				})
				Util.corner(dot, 0.5)
				Util.stroke(dot, C.line, 2)
			end
		end
		local picked = mine == mapId
		c.rim.Color = if picked then C.sun else C.line
		c.rim.Thickness = if picked then 5 else 3
		c.root.BackgroundColor3 = if picked then C.mine else C.panelRaised
	end
end

function MapVote.show(layer: Instance, data)
	if type(data) ~= "table" or type(data.options) ~= "table" then
		return
	end
	if open and open.id == data.id then
		open.data = data
		paint(data)
		return
	end
	MapVote.close()
	local maid = Util.maid()
	local dim = Util.new("Frame", {
		Name = "MapVote",
		BackgroundColor3 = C.table,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		Parent = layer,
	})
	open = { id = data.id, root = dim, cards = {}, data = data, maid = maid }
	local roomW, roomH, narrow = Widgets.room()
	local upright = roomH > roomW
	local w = math.min(roomW, if upright then 420 else 980)
	local h = math.min(roomH, if upright then 720 else 470)
	local content = Util.frame(dim, {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 301,
	})
	Widgets.label(content, {
		text = "VOTE FOR THE MAP",
		font = "display",
		size = if narrow then 34 else 44,
		color = C.sun,
		outline = C.line,
		outlineThickness = 3,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 50),
		z = 302,
	})
	local timer = Widgets.label(content, {
		text = "",
		font = "heavy",
		size = 18,
		color = C.textLight,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 50),
		z = 302,
	})
	local grid = Util.frame(content, {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -82),
		ZIndex = 302,
	})
	local n = #data.options
	Util.new("UIGridLayout", {
		CellSize = if upright then UDim2.new(1, 0, 1 / n, -10) else UDim2.new(1 / n, -14, 1, 0),
		CellPadding = UDim2.fromOffset(if upright then 0 else 14, if upright then 12 else 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, mapId in data.options do
		local c = card(grid, mapId, function()
			if data.seat == 0 then
				return -- spectators watch the vote
			end
			Sound.play("click")
			local ok, err = Net.request("match.vote", { map = mapId })
			if not ok then
				Widgets.toast(tostring(err), "info")
			end
		end)
		c.root.LayoutOrder = i
		open.cards[mapId] = c
	end
	Util.popIn(content, 0.35, 0.8)
	Sound.play("open")
	maid:add(RunService.Heartbeat:Connect(function()
		local d = open and open.data
		if not d then
			return
		end
		local left = math.max(0, math.ceil((d.deadline or 0) - workspace:GetServerTimeNow()))
		timer.Text = if d.seat == 0 then ("Watching the vote  ·  " .. left .. "s") else ("Tap a map  ·  " .. left .. "s")
	end))
	paint(data)
end

-- The winner flashes gold; the rest fade back.
function MapVote.result(mapId: string)
	if not open then
		return
	end
	for id, c in open.cards do
		if id == mapId then
			c.rim.Color = C.sun
			c.rim.Thickness = 6
			Util.bump(c.root, 0.08)
		else
			Util.tween(c.root, 0.3, { BackgroundTransparency = 0.6 })
		end
	end
	Sound.play("reveal")
end

function MapVote.close()
	if not open then
		return
	end
	local o = open
	open = nil
	o.maid:clean()
	Util.tween(o.root, 0.25, { BackgroundTransparency = 1 })
	task.delay(0.26, function()
		o.root:Destroy()
	end)
end

return MapVote
