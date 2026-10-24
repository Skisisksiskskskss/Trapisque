--[[
	MapVote
	A match can open with a vote (Quick Play always; a private match when its host turns
	it on). The cards sit side by side (two by two on an upright phone):

		map      a picture of the map (art/maps: the game's own board), its name, what it
		         does to you and the card that gets you past it
		mystery  a face-down map that isn't on the other cards; it turns over if it wins
		twist    a map with one of the weekly events' twists on top

	Tap one to vote. Everyone who has voted shows on their card as their emblem; a bar
	runs down to the server's deadline. "majority": the most votes wins. "roulette":
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
local Art = require(UI.Art)
local CosmeticArt = require(UI.CosmeticArt)

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

-- What each map's hazard does to you, in a few words (Maps: the blurb says it in full).
local HAZARD = {
	river = "Rivers stop you",
	gate = "Gates block the way",
	slime = "Slime eats your steps",
	ghost = "Ghosts scare you back",
	lava = "Lava, and eruptions",
	thinice = "Thin ice gives way",
	kraken = "The Kraken strikes",
	drawbridge = "Drawbridges rise",
}

local PAD = 8 -- inside a card
local GAP = 14 -- between cards

-- The picture at the top of a card: the map itself, or the back of a Mystery card.
local function picture(parent: Instance, option, w: number, h: number): Frame
	local pic = Util.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = C.grapeDark,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(w, h),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = parent,
	})
	Util.corner(pic, 10)
	if option.kind == "mystery" then
		-- a night sea, fog, and question marks
		Util.grad(pic, { C.grapeDark, Util.shade(C.grapeDark, -0.35) }, 90)
		for _, q in { { 0.14, 0.3, -18, 0.34 }, { 0.86, 0.28, 14, 0.3 }, { 0.22, 0.8, 10, 0.26 }, { 0.8, 0.78, -12, 0.3 } } do
			Util.new("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(q[1], q[2]),
				Size = UDim2.fromScale(q[4], q[4]),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Rotation = q[3],
				Text = "?",
				TextScaled = true,
				TextTransparency = 0.45,
				FontFace = Theme.Font.Display,
				TextColor3 = C.sky,
				ZIndex = 3,
				Parent = pic,
			})
		end
		local big = Util.new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.86, 0.86),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = "?",
			TextScaled = true,
			FontFace = Theme.Font.Display,
			TextColor3 = C.sun,
			ZIndex = 4,
			Parent = pic,
		})
		Util.stroke(big, C.ink, 3)
		return pic
	end
	local def = Maps.get(option.map) or Maps.list[1]
	if not Art.image(pic, "maps/" .. def.id, { ZIndex = 3, Size = UDim2.fromScale(1, 1) }) then
		-- (no art: the map's sea and land colours)
		pic.BackgroundColor3 = C.sky
	end
	local event = option.kind == "twist" and Progress.eventById(option.event)
	if event then
		-- the twist on a ribbon across the bottom of the picture
		local ribbon = Util.new("Frame", {
			Name = "Twist",
			BackgroundColor3 = hex(event.color),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, math.floor(h * 0.24)),
			ZIndex = 5,
			Parent = pic,
		})
		Widgets.label(ribbon, {
			text = "+ " .. event.name,
			font = "chunky",
			size = 16,
			color = Theme.textOn(hex(event.color)),
			align = "center",
			scaled = true,
			sizeUDim = UDim2.new(1, -16, 1, -6),
			position = UDim2.fromOffset(8, 3),
			z = 6,
		})
	end
	return pic
end

-- A card: its picture, its name, what it does, and who voted for it.
local function card(parent: Instance, i: number, option, w: number, h: number, onPick: () -> ())
	local root = Util.new("TextButton", {
		Name = "Option" .. i,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		Selectable = true,
		Size = UDim2.fromOffset(w, h),
		ZIndex = 1,
		Parent = parent,
	})
	Util.corner(root, 14)
	local rim = Util.stroke(root, C.line, 2.5)
	local picW = w - 2 * PAD
	local picH = math.floor(picW * 9 / 16)
	local c = { root = root, rim = rim, option = option, w = w, h = h, picW = picW, picH = picH }
	c.pic = picture(root, option, picW, picH)
	-- its number, in the colour of its slice of the wheel
	local badge = Util.new("Frame", {
		Name = "Badge",
		BackgroundColor3 = flagColor(i, option),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD + 6, PAD + 6),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 20,
		Parent = root,
	})
	Util.corner(badge, 0.5)
	Util.stroke(badge, C.white, 2.5)
	Widgets.label(badge, {
		text = tostring(i),
		font = "chunky",
		size = 17,
		color = C.white,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 21,
	})
	-- (roulette) its chance of coming up
	local chance = Util.new("Frame", {
		Name = "Chance",
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(PAD + 6), 0, PAD + 6),
		Size = UDim2.fromOffset(52, 24),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Util.corner(chance, 0.5)
	c.chance = Widgets.label(chance, {
		text = "",
		font = "chunky",
		size = 15,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 21,
	})
	c.chanceBox = chance
	-- your vote (on its top edge)
	c.mineTag = Util.new("Frame", {
		Name = "Mine",
		BackgroundColor3 = C.sun,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(92, 24),
		Visible = false,
		ZIndex = 22,
		Parent = root,
	})
	Util.corner(c.mineTag, 0.5)
	Util.stroke(c.mineTag, C.white, 2)
	Widgets.label(c.mineTag, {
		text = "Your vote",
		font = "chunky",
		size = 14,
		color = C.textOnLight,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 23,
	})
	-- its name, and what it does to you (and the card that gets you past it)
	local y = PAD + picH + 14
	local name, line, counter
	if option.kind == "mystery" then
		name, line = "Mystery Map", "One you can't see. It turns over if it wins."
	else
		local def = Maps.get(option.map) or Maps.list[1]
		name = def.name
		local event = option.kind == "twist" and Progress.eventById(option.event)
		line = if event then event.blurb else (HAZARD[def.naturalKind or ""] or "")
		counter = if event then nil else Items.get(def.counterItem or "")
	end
	c.name = Widgets.label(root, {
		name = "Name",
		text = name,
		font = "chunky",
		size = 19,
		color = C.text,
		align = "center",
		scaled = true,
		sizeUDim = UDim2.new(1, -2 * PAD, 0, 24),
		position = UDim2.fromOffset(PAD, y),
		z = 3,
	})
	y += 26
	local lineH = h - y - 40
	local info = Util.frame(root, { Name = "Info", Position = UDim2.fromOffset(PAD, y), Size = UDim2.new(1, -2 * PAD, 0, lineH), ZIndex = 3 })
	local textX = 0
	if counter then
		local icon = Util.frame(info, {
			Name = "Counter",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(math.min(30, lineH), math.min(30, lineH)),
			ZIndex = 3,
		})
		Icons.cardBadge(icon, counter.id, Theme.Category[counter.category] or C.lime, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		textX = math.min(30, lineH) + 6
	end
	Widgets.label(info, {
		name = "Line",
		text = if counter then (line .. "\nCounter: " .. counter.name) else line,
		font = "body",
		size = 13,
		minSize = 9,
		color = C.textSoft,
		wrap = true,
		scaled = true,
		align = if counter then "left" else "center",
		sizeUDim = UDim2.new(1, -textX, 1, 0),
		position = UDim2.fromOffset(textX, 0),
		z = 3,
	})
	-- who voted for it: their emblems
	c.voters = Util.frame(root, {
		Name = "Votes",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -2 * PAD, 0, 28),
		ZIndex = 3,
	})
	Util.list(c.voters, "x", 4, "Center", "Center")
	root.Activated:Connect(onPick)
	root.MouseEnter:Connect(function()
		Util.tween(Util.scaler(root), 0.12, { Scale = 1.03 }, Enum.EasingStyle.Back)
	end)
	root.MouseLeave:Connect(function()
		Util.tween(Util.scaler(root), 0.12, { Scale = 1 })
	end)
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
	local seatInfo = {}
	for _, s in data.seats or {} do
		seatInfo[s.seat] = s
	end
	local weights = Voting.weights(open.options, data.votes)
	local total = 0
	for _, w in weights do
		total += w
	end
	for i, c in open.cards do
		Util.clear(c.voters, true)
		local count = 0
		for seatKey, voted in data.votes or {} do
			if tonumber(voted) == i then
				count += 1
				local s = seatInfo[tonumber(seatKey) or 0]
				local holder = Util.frame(c.voters, { Name = "Vote", Size = UDim2.fromOffset(26, 26), LayoutOrder = tonumber(seatKey) or 0, ZIndex = 4 })
				if s and s.character then
					Icons.emblem(holder, CosmeticArt.emblemId(s.character, s.look and s.look.emblems), { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
				else
					local dot = Util.new("Frame", { BackgroundColor3 = C.sun, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = holder })
					Util.corner(dot, 0.5)
				end
			end
		end
		if count == 0 then
			Widgets.label(c.voters, {
				name = "None",
				text = "No votes yet",
				font = "body",
				size = 12,
				color = C.textFaint,
				align = "center",
				sizeUDim = UDim2.new(1, 0, 1, 0),
				z = 4,
			})
		end
		c.chanceBox.Visible = data.style == "roulette"
		c.chance.Text = math.floor(100 * weights[i] / total + 0.5) .. "%"
		local picked = mine == i
		c.mineTag.Visible = picked
		c.rim.Color = if picked then C.sun else C.line
		c.rim.Thickness = if picked then 4 else 2.5
		c.root.BackgroundColor3 = if picked then C.mine else C.panelRaised
	end
end

-- Where the cards go: in a row, or two by two on an upright screen (a last odd one in
-- the middle). Returns each card's position, the card size and the space they take.
local function arrange(n: number, w: number, h: number, upright: boolean): ({ Vector2 }, Vector2, Vector2)
	local cols = if upright then math.min(2, n) else n
	local rows = math.ceil(n / cols)
	local cw = math.floor(math.min(if upright then 210 else 270, (w - GAP * (cols - 1)) / cols))
	local ch = math.floor(cw * 9 / 16) + 2 * PAD + 112
	if rows * ch + (rows - 1) * GAP > h then
		-- (a short screen: smaller cards)
		local k = (h - (rows - 1) * GAP) / (rows * ch)
		cw, ch = math.floor(cw * k), math.floor(ch * k)
	end
	local spots = {}
	for i = 1, n do
		local row, col = (i - 1) // cols, (i - 1) % cols
		local inRow = math.min(cols, n - row * cols)
		local rowW = inRow * cw + (inRow - 1) * GAP
		local x0 = (cols * cw + (cols - 1) * GAP - rowW) / 2
		spots[i] = Vector2.new(x0 + col * (cw + GAP), row * (ch + GAP))
	end
	return spots, Vector2.new(cw, ch), Vector2.new(cols * cw + (cols - 1) * GAP, rows * ch + (rows - 1) * GAP)
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
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		Parent = layer,
	})
	local roomW, roomH, narrow = Widgets.room()
	local upright = roomH > roomW
	local n = #data.options
	local headH = if narrow then 92 else 112
	local spots, cardSize, span = arrange(n, math.min(roomW - 24, 1180), roomH - headH - 24, upright)
	local w = math.max(span.X, math.min(roomW - 24, 520))
	local content = Util.frame(dim, {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, headH + span.Y),
		ZIndex = 301,
	})
	open = { id = data.id, root = dim, content = content, cards = {}, options = data.options, data = data, maid = maid }
	local roulette = data.style == "roulette"
	Widgets.label(content, {
		text = "Vote for the map",
		font = "display",
		size = if narrow then 30 else 40,
		color = C.textLight,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, if narrow then 36 else 46),
		z = 302,
	})
	Widgets.label(content, {
		text = if roulette then "Roulette: every vote is a slice of the wheel, and the wheel decides." else "The most votes wins. A tie is settled at random.",
		font = "body",
		size = 15,
		minSize = 10,
		color = C.textLightSoft,
		align = "center",
		scaled = true,
		sizeUDim = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, if narrow then 36 else 46),
		z = 302,
	})
	-- the time left: a bar running down, and the seconds
	local barY = if narrow then 62 else 76
	local track = Util.new("Frame", {
		Name = "Time",
		BackgroundColor3 = C.bgDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, barY),
		Size = UDim2.new(0.7, 0, 0, 10),
		ZIndex = 302,
		Parent = content,
	})
	Util.corner(track, 0.5)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.sun,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 303,
		Parent = track,
	})
	Util.corner(fill, 0.5)
	local timer = Widgets.label(content, {
		text = "",
		font = "chunky",
		size = 15,
		color = C.textLight,
		align = "left",
		sizeUDim = UDim2.fromOffset(120, 20),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0.85, 10, 0, barY + 5),
		z = 302,
	})
	local grid = Util.frame(content, {
		Name = "Cards",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, headH),
		Size = UDim2.fromOffset(span.X, span.Y),
		ZIndex = 302,
	})
	for i, option in data.options do
		local c = card(grid, i, option, cardSize.X, cardSize.Y, function()
			if data.seat == 0 then
				return -- spectators watch the vote
			end
			Sound.play("click")
			local ok, err = Net.request("match.vote", { option = i })
			if not ok then
				Widgets.toast(tostring(err), "info")
			end
		end)
		c.root.Position = UDim2.fromOffset(spots[i].X, spots[i].Y)
		open.cards[i] = c
		Util.popIn(c.root, 0.3 + 0.06 * i, 0.7)
	end
	Sound.play("open")
	local total = math.max(1, (data.deadline or 0) - workspace:GetServerTimeNow())
	maid:add(RunService.Heartbeat:Connect(function()
		local d = open and open.data
		if not d then
			return
		end
		local left = math.max(0, (d.deadline or 0) - workspace:GetServerTimeNow())
		fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		fill.BackgroundColor3 = if left < 3 then C.coral else C.sun
		timer.Text = (if d.seat == 0 then "Watching  ·  " else "") .. math.ceil(left) .. "s"
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
	local old = c.pic :: Frame
	Util.tweenWait(old, 0.14, { Size = UDim2.fromOffset(0, c.picH), Position = UDim2.fromOffset(PAD + c.picW / 2, PAD) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	old:Destroy()
	c.option = { kind = "map", map = mapId }
	local pic = picture(c.root, c.option, c.picW, c.picH)
	pic.Size = UDim2.fromOffset(0, c.picH)
	pic.Position = UDim2.fromOffset(PAD + c.picW / 2, PAD)
	c.pic = pic
	local def = Maps.get(mapId)
	if def then
		c.name.Text = def.name
	end
	Util.tween(pic, 0.22, { Size = UDim2.fromOffset(c.picW, c.picH), Position = UDim2.fromOffset(PAD, PAD) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
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
				;(c.root :: TextButton).ZIndex = 5
				Util.tween(Util.scaler(c.root), 0.25, { Scale = 1.08 }, Enum.EasingStyle.Back)
				-- "This one!" across the top of it
				c.mineTag.Visible = false
				local tag = Util.new("Frame", {
					Name = "Chosen",
					BackgroundColor3 = C.sun,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.fromOffset(120, 30),
					ZIndex = 40,
					Parent = c.root,
				})
				Util.corner(tag, 0.5)
				Util.stroke(tag, C.white, 2.5)
				Widgets.label(tag, {
					text = "This one!",
					font = "chunky",
					size = 17,
					color = C.textOnLight,
					align = "center",
					sizeUDim = UDim2.fromScale(1, 1),
					z = 41,
				})
				Util.popIn(tag, 0.3, 0.4)
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
