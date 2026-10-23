--[[
	MapVote
	A match can open with a vote (Quick Play always; a private match when its host turns
	it on). The cards sit side by side (stacked, or two by two, on an upright phone):

		map      a map with its colours, its hazard and what it does
		mystery  a face-down map that isn't on the other cards; it turns over if it wins
		twist    a map with one of the weekly events' twists on top

	Tap one to vote; everyone's vote shows as a dot in their character's colour, and a
	countdown runs to the server's deadline. "majority": the most votes wins. "roulette":
	every vote is a slice of a wheel (a card nobody picked keeps a sliver), the cards show
	their chances, and the wheel spins when time is up.

		MapVote.show(layer, data)   -- the server's "match.vote" (again for each vote)
		MapVote.result(data)        -- "match.voted": { option, map, mystery, event, style, weights }
		MapVote.close()
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Items = require(Shared.Game.Items)
local Voting = require(Shared.Game.Voting)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local Shapes = require(UI.Shapes)
local StickerArt = require(UI.StickerArt)
local MapScenes = require(script.Parent.MapScenes)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)

local C = Theme.C

local MapVote = {}

-- { id, root, content, cards = { card }, options, data, maid }
local open = nil

local function hex(s: string?): Color3
	return Color3.fromHex(string.sub(s or "#888888", 2))
end

-- Each card's colour: its number badge and its slice of the roulette wheel.
local FLAG = { C.sky, C.lime, C.pink, C.orange }
local function flagColor(i: number, option): Color3
	if option.kind == "mystery" then
		return C.grape
	end
	return FLAG[i] or C.sun
end

-- The hazard each map is known for, as its sticker.
local HAZARD_ART = { river = "river", gate = "gate", slime = "slime", lava = "lava" }

-- A little picture of a place: its sea, an island in its land colours, the hazard.
local function picture(parent: Instance, mapId: string): Frame
	local def = Maps.get(mapId)
	local scene = MapScenes[mapId] or MapScenes.blissful
	local col = scene.colors
	local pic = Util.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = hex(col.water),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0.5, -10),
		ClipsDescendants = true,
		Parent = parent,
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
	return pic
end

-- The back of a card: a night sea full of question marks.
local function mysteryPicture(parent: Instance): Frame
	local pic = Util.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = C.grapeDark,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0.5, -10),
		ClipsDescendants = true,
		Parent = parent,
	})
	Util.corner(pic, 10)
	Util.stroke(pic, C.line, 2.5)
	for _, q in { { 0.14, 0.26, -18 }, { 0.86, 0.3, 14 }, { 0.2, 0.8, 10 }, { 0.8, 0.78, -12 }, { 0.5, 0.12, 4 } } do
		Util.new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(q[1], q[2]),
			Size = UDim2.fromScale(0.3, 0.3),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Rotation = q[3],
			Text = "?",
			TextScaled = true,
			FontFace = Theme.Font.Display,
			TextColor3 = C.grape,
			ZIndex = 2,
			Parent = pic,
		})
	end
	local big = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Text = "?",
		TextScaled = true,
		FontFace = Theme.Font.Display,
		TextColor3 = C.sun,
		ZIndex = 5,
		Parent = pic,
	})
	Util.stroke(big, C.ink, 3)
	return pic
end

-- A card's face (the part that turns over when a Mystery map wins).
local function face(root: Instance, option): Frame
	local f = Util.frame(root, {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	})
	local name, blurb
	if option.kind == "mystery" then
		mysteryPicture(f)
		name = "Mystery Map"
		blurb = "A map that isn't on the other cards, face down. You see which one only if it wins."
	else
		local def = Maps.get(option.map) or Maps.list[1]
		local pic = picture(f, def.id)
		name = def.name
		local counter = Items.get(def.counterItem or "")
		blurb = def.blurb .. (if counter then ("  Counter: " .. counter.name .. ".") else "")
		local event = option.kind == "twist" and Progress.eventById(option.event)
		if event then
			-- a ribbon across the picture with the twist on it
			local ribbon = Util.new("Frame", {
				Name = "Twist",
				BackgroundColor3 = hex(event.color),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.new(1, 24, 0, 28),
				Rotation = -4,
				ZIndex = 8,
				Parent = pic,
			})
			Util.stroke(ribbon, C.ink, 2.5)
			Widgets.label(ribbon, {
				text = "+ " .. string.upper(event.name),
				font = "chunky",
				size = 16,
				color = C.white,
				outline = C.ink,
				align = "center",
				scaled = true,
				sizeUDim = UDim2.new(1, -40, 1, -6),
				position = UDim2.fromOffset(20, 3),
				z = 9,
			})
			blurb = "Twist: " .. event.blurb
		end
	end
	Widgets.label(f, {
		text = name,
		font = "chunky",
		size = 22,
		color = C.text,
		outline = C.line,
		align = "center",
		scaled = true,
		sizeUDim = UDim2.new(1, -16, 0, 26),
		position = UDim2.new(0, 8, 0.5, 6),
	})
	Widgets.label(f, {
		text = blurb,
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
	return f
end

local function card(parent: Instance, i: number, option, onPick: () -> ())
	local root = Util.new("TextButton", {
		Name = "Option" .. i,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		Selectable = true,
		LayoutOrder = i,
		Parent = parent,
	})
	Util.corner(root, 14)
	local rim = Util.stroke(root, C.line, 3)
	local c = { root = root, rim = rim, option = option, face = face(root, option) }
	-- its number, in the colour of its slice of the wheel
	local badge = Util.new("Frame", {
		Name = "Badge",
		BackgroundColor3 = flagColor(i, option),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 20,
		Parent = root,
	})
	Util.corner(badge, 0.5)
	Util.stroke(badge, C.ink, 2.5)
	Widgets.label(badge, {
		text = tostring(i),
		font = "chunky",
		size = 18,
		color = C.white,
		outline = C.ink,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 21,
	})
	-- (roulette) its chance of coming up
	c.chance = Widgets.label(root, {
		text = "",
		font = "chunky",
		size = 16,
		color = C.text,
		align = "right",
		sizeUDim = UDim2.fromOffset(70, 22),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -14, 0, 14),
		z = 20,
	})
	-- who voted for it: a dot in each voter's colour
	c.dots = Util.frame(root, {
		Name = "Votes",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 22),
		ZIndex = 20,
	})
	Util.list(c.dots, "x", 6, "Center", "Center")
	root.Activated:Connect(onPick)
	return c
end

local function paint(data)
	if not open then
		return
	end
	local mine = nil
	for seatKey, i in data.votes or {} do
		if tonumber(seatKey) == data.seat then
			mine = tonumber(i)
		end
	end
	local colorOf = {}
	for _, s in data.seats or {} do
		colorOf[s.seat] = Theme.playerColor(s.character)
	end
	local weights = Voting.weights(open.options, data.votes)
	local total = 0
	for _, w in weights do
		total += w
	end
	for i, c in open.cards do
		Util.clear(c.dots, true)
		for seatKey, voted in data.votes or {} do
			if tonumber(voted) == i then
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
		c.chance.Text = if data.style == "roulette" then (math.floor(100 * weights[i] / total + 0.5) .. "%") else ""
		local picked = mine == i
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
	local roomW, roomH, narrow = Widgets.room()
	local upright = roomH > roomW
	local n = #data.options
	local w = math.min(roomW, if upright then 420 else (if n >= 4 then 1080 else 980))
	local h = math.min(roomH, if upright then 720 else 470)
	local content = Util.frame(dim, {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 301,
	})
	open = { id = data.id, root = dim, content = content, cards = {}, options = data.options, data = data, maid = maid }
	local roulette = data.style == "roulette"
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
	local top = 82
	if roulette then
		Widgets.label(content, {
			text = "Roulette: every vote is a slice of the wheel, and the wheel decides.",
			font = "body",
			size = 15,
			minSize = 10,
			color = C.textLightSoft,
			align = "center",
			scaled = true,
			sizeUDim = UDim2.new(1, 0, 0, 20),
			position = UDim2.fromOffset(0, 74),
			z = 302,
		})
		top = 102
	end
	local grid = Util.frame(content, {
		Name = "Cards",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		ZIndex = 302,
	})
	local cell, gap
	if upright and n >= 4 then
		cell, gap = UDim2.new(0.5, -6, 0.5, -6), UDim2.fromOffset(12, 12)
	elseif upright then
		cell, gap = UDim2.new(1, 0, 1 / n, -10), UDim2.fromOffset(0, 12)
	else
		cell, gap = UDim2.new(1 / n, -14 * (n - 1) / n, 1, 0), UDim2.fromOffset(14, 0)
	end
	Util.new("UIGridLayout", {
		CellSize = cell,
		CellPadding = gap,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, option in data.options do
		open.cards[i] = card(grid, i, option, function()
			if data.seat == 0 then
				return -- spectators watch the vote
			end
			Sound.play("click")
			local ok, err = Net.request("match.vote", { option = i })
			if not ok then
				Widgets.toast(tostring(err), "info")
			end
		end)
	end
	Util.popIn(content, 0.35, 0.8)
	Sound.play("open")
	maid:add(RunService.Heartbeat:Connect(function()
		local d = open and open.data
		if not d then
			return
		end
		local left = math.max(0, math.ceil((d.deadline or 0) - workspace:GetServerTimeNow()))
		timer.Text = if d.seat == 0 then ("Watching the vote  ·  " .. left .. "s") else ("Tap a card  ·  " .. left .. "s")
	end))
	paint(data)
end

--[[
	The roulette: a wheel with a slice per card (as wide as its votes) spins and stops
	with the chosen card's slice under the pointer. Yields ~3.3 s.
]]
local function spinWheel(o, weights: { number }, chosen: number)
	local roomW, roomH = Widgets.room()
	local size = math.floor(math.min(300, roomW - 48, roomH * 0.6))
	local back = Util.new("Frame", {
		Name = "RouletteDim",
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 400,
		Parent = o.root,
	})
	Util.tween(back, 0.2, { BackgroundTransparency = 0.35 })
	local holder = Util.frame(back, {
		Name = "Roulette",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 401,
	})
	Util.popIn(holder, 0.25, 0.6)
	local canvas = Shapes.canvas(holder)
	Shapes.circle(canvas, 0.5, 0.53, 1, C.shadow)
	Shapes.circle(canvas, 0.5, 0.5, 1, C.ink)
	Shapes.circle(canvas, 0.5, 0.5, 0.955, C.sun)
	local spinFrame = Util.frame(holder, {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.88),
		ZIndex = 402,
	})
	local disc = Shapes.canvas(spinFrame)
	Shapes.circle(disc, 0.5, 0.5, 1, C.ink)
	-- the slices, as a fan of thin spokes (degrees clockwise from the top)
	local total = 0
	for _, w in weights do
		total += w
	end
	local starts, ends = {}, {}
	local acc = 0
	for i, w in weights do
		starts[i] = acc
		acc += 360 * w / total
		ends[i] = acc
	end
	local function sliceAt(a: number): number
		for i in weights do
			if a < ends[i] then
				return i
			end
		end
		return #weights
	end
	local STEPS = 120
	for k = 0, STEPS - 1 do
		local a = (k + 0.5) * 360 / STEPS
		local i = sliceAt(a)
		local col = flagColor(i, o.options[i] or {})
		local r = math.rad(a)
		Shapes.line(disc, 0.5, 0.5, 0.5 + math.sin(r) * 0.47, 0.5 - math.cos(r) * 0.47, 0.034, col, { square = true })
	end
	for i in weights do
		local r = math.rad(starts[i])
		Shapes.line(disc, 0.5, 0.5, 0.5 + math.sin(r) * 0.48, 0.5 - math.cos(r) * 0.48, 0.016, C.ink)
	end
	Shapes.ring(disc, 0.5, 0.5, 1, 0.04, C.ink)
	-- each slice's card number
	for i in weights do
		if ends[i] - starts[i] >= 16 then
			local r = math.rad((starts[i] + ends[i]) / 2)
			local x, y = 0.5 + math.sin(r) * 0.32, 0.5 - math.cos(r) * 0.32
			Shapes.circle(disc, x, y, 0.15, C.ink)
			Shapes.circle(disc, x, y, 0.12, C.panel)
			Shapes.text(disc, x, y, 0.1, 0.1, tostring(i), C.text, Theme.Font.Chunky)
		end
	end
	Shapes.circle(disc, 0.5, 0.5, 0.2, C.ink)
	Shapes.circle(disc, 0.5, 0.5, 0.16, C.sun)
	-- the pointer at the top
	local pointer = Util.frame(holder, {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 410,
	})
	local pc = Shapes.canvas(pointer)
	Shapes.tri(pc, 0.5, 0.24, 1, C.line, { dir = 180 })
	Shapes.tri(pc, 0.5, 0.2, 0.84, C.coral, { dir = 180 })
	Shapes.circle(pc, 0.5, 0.18, 0.36, C.ink)
	Shapes.circle(pc, 0.5, 0.18, 0.3, C.sun)

	-- spin: a few turns, stopping somewhere inside the chosen slice
	local span = ends[chosen] - starts[chosen]
	local target = starts[chosen] + span * (0.25 + 0.5 * math.random())
	local finalRot = 4 * 360 - target
	local duration = 2.7
	spinFrame.Rotation = 0
	task.wait(0.25)
	Util.tween(spinFrame, duration, { Rotation = finalRot }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	task.spawn(function()
		local last = 0
		local t0 = os.clock()
		while os.clock() - t0 < duration and holder.Parent do
			local p = (os.clock() - t0) / duration
			local passed = math.floor((1 - (1 - p) ^ 4) * finalRot / 30)
			if passed ~= last then
				last = passed
				Sound.play("tick", 1 + p * 0.3)
				Util.bump(pointer, 0.1)
			end
			task.wait(1 / 60)
		end
	end)
	task.wait(duration)
	Sound.play("reveal")
	Util.bump(holder, 0.12)
	task.wait(0.35)
	Util.tween(back, 0.2, { BackgroundTransparency = 1 })
	Util.tween(Util.scaler(holder), 0.2, { Scale = 0.4 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.21, function()
		back:Destroy()
	end)
	task.wait(0.2)
end

-- A Mystery card turns over to show the map under it.
local function flip(c, mapId: string)
	local old = c.face
	Util.tweenWait(old, 0.14, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	old:Destroy()
	c.option = { kind = "map", map = mapId }
	local f = face(c.root, c.option)
	f.Size = UDim2.fromScale(0, 1)
	c.face = f
	Util.tween(f, 0.22, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- The chosen card flashes gold (a Mystery one turns over); the rest go dark.
function MapVote.result(data)
	if not open or type(data) ~= "table" then
		return
	end
	local o = open
	local chosen = tonumber(data.option)
	if not chosen then
		for i, opt in o.options do
			if opt.map == data.map then
				chosen = i
			end
		end
	end
	if not chosen or not o.cards[chosen] then
		return
	end
	task.spawn(function()
		if data.style == "roulette" and type(data.weights) == "table" and #data.weights == #o.options then
			spinWheel(o, data.weights, chosen)
		end
		if open ~= o then
			return
		end
		for i, c in o.cards do
			if i == chosen then
				c.rim.Color = C.sun
				c.rim.Thickness = 6
				Util.bump(c.root, 0.08)
			else
				local shade = Util.new("Frame", {
					Name = "Shade",
					BackgroundColor3 = C.dim,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 30,
					Parent = c.root,
				})
				Util.corner(shade, 14)
				Util.tween(shade, 0.3, { BackgroundTransparency = 0.45 })
			end
		end
		Sound.play("reveal")
		if data.mystery and type(data.map) == "string" and Maps.get(data.map) then
			task.wait(0.35)
			if open == o then
				flip(o.cards[chosen], data.map)
			end
		end
	end)
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
