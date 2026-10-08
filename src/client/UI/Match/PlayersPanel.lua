--[[
	PlayersPanel
	The column of player cards beside the board: pawn, name, character, treasures,
	coins, cards in hand, status effects and whose turn it is (with a timer bar).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local C = Theme.C
local hex = Theme.hex

local PlayersPanel = {}
PlayersPanel.__index = PlayersPanel

local STATUS = {
	{ key = "burning", icon = "fire", color = hex("E2622B"), tip = "Burning" },
	{ key = "frozen", icon = "ice", color = hex("5DADE2"), tip = "Frozen" },
	{ key = "boots", icon = "boots", color = hex("8B6B3E"), tip = "Boots on" },
	{ key = "held", icon = "lock", color = hex("6D747C"), tip = "Stuck at a gate" },
	{ key = "skip", icon = "snare", color = hex("A0522D"), tip = "Skips next turn" },
	{ key = "anchor", icon = "hourglass", color = hex("8E6CEF"), tip = "Time anchor set" },
}

function PlayersPanel.new(parent: Instance, seats, target: number, mySeat: number, isTeam: boolean)
	local self = setmetatable({}, PlayersPanel)
	self.target = target
	self.mySeat = mySeat
	self.isTeam = isTeam
	self.cards = {}
	self.onClick = nil

	local content, root = Widgets.panel(parent, {
		name = "PlayersPanel",
		style = "parchment",
		size = UDim2.fromScale(1, 1),
		padding = 10,
	})
	self.root = root
	local list = Util.frame(content, { Name = "List" })
	Util.list(list, "y", 8, "Center", "Top")
	self.list = list

	for _, info in seats do
		self.cards[info.seat] = self:_makeCard(list, info)
	end
	return self
end

function PlayersPanel:_makeCard(list: Frame, info)
	local seatColor = Theme.Seat[((info.seat - 1) % 6) + 1]
	local card = Util.new("TextButton", {
		Name = "Player" .. info.seat,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHex("FBF3DD"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 82),
		LayoutOrder = info.seat,
		Parent = list,
	})
	Util.corner(card, 12)
	local stroke = Util.stroke(card, C.parchmentEdge, 2)
	local stripe = Util.new("Frame", {
		Name = "SeatStripe",
		BackgroundColor3 = seatColor,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 8, 1, 0),
		Parent = card,
	})
	Util.corner(stripe, 6)
	if self.isTeam then
		local teamColor = Theme.Team[info.team] or seatColor
		local tag = Widgets.badge(card, {
			text = "T" .. tostring(info.team),
			color = teamColor,
			height = 18,
			textSize = 12,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -6, 0, 4),
			z = 6,
		})
		tag.Name = "TeamTag"
	end

	local pawnHolder = Util.frame(card, {
		Name = "PawnHolder",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(50, 50),
	})
	CosmeticArt.pawn(pawnHolder, info.look and info.look.pawn, seatColor, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})

	local name = Widgets.label(card, {
		name = "Name",
		text = info.name .. (if info.seat == self.mySeat then "  (you)" else ""),
		font = "heavy",
		size = 17,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -150, 0, 20),
		position = UDim2.fromOffset(72, 6),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local charDef = Characters.get(info.character or "")
	-- character: a small badge in front of its name
	local textX = 72
	if info.character then
		CosmeticArt.characterBadge(card, info.character, {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(72, 25),
			Size = UDim2.fromOffset(18, 18),
		})
		textX = 94
	end
	local sub = Widgets.label(card, {
		name = "Character",
		text = (charDef and charDef.name or "") .. (if info.isBot then "  ·  BOT" else ""),
		font = "body",
		size = 13,
		color = Theme.Character[info.character] or C.inkSoft,
		sizeUDim = UDim2.new(1, -150 - (textX - 72), 0, 16),
		position = UDim2.fromOffset(textX, 26),
	})
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	-- treasures: one slot per treasure needed
	local slots = Util.frame(card, {
		Name = "Treasures",
		Position = UDim2.fromOffset(72, 46),
		Size = UDim2.fromOffset(130, 24),
	})
	Util.list(slots, "x", 3, "Left", "Center")
	local slotFrames = {}
	for i = 1, self.target do
		local slot = Util.new("Frame", {
			Name = "Slot" .. i,
			BackgroundColor3 = C.parchmentDark,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(20, 20),
			LayoutOrder = i,
			Parent = slots,
		})
		Util.corner(slot, 0.5)
		Util.stroke(slot, C.brassDark, 2)
		slotFrames[i] = slot
	end

	-- coins and cards
	local counters = Util.frame(card, {
		Name = "Counters",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 24),
		Size = UDim2.fromOffset(70, 22),
	})
	Util.list(counters, "x", 4, "Right", "Center")
	local function counter(icon: string, color: Color3, order: number)
		local box = Util.frame(counters, { Size = UDim2.fromOffset(34, 22), LayoutOrder = order })
		local ic = Util.frame(box, { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(0, 3) })
		Icons.make(ic, icon, Icons.flatColors(color, C.parchment))
		local n = Widgets.label(box, {
			text = "0",
			font = "chunky",
			size = 16,
			color = C.textDark,
			sizeUDim = UDim2.fromOffset(18, 22),
			position = UDim2.fromOffset(17, 0),
		})
		return n
	end
	local coins = counter("coin", C.brassDark, 1)
	local cardsN = counter("book", C.woodDark, 2)

	-- statuses
	local statusRow = Util.frame(card, {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(130, 20),
	})
	Util.list(statusRow, "x", 3, "Right", "Center")
	local statusIcons = {}
	for i, s in STATUS do
		local holder = Util.frame(statusRow, { Name = s.key, Size = UDim2.fromOffset(20, 20), LayoutOrder = i, Visible = false })
		Icons.medallion(holder, s.icon, s.color, { Size = UDim2.fromScale(1, 1) })
		statusIcons[s.key] = holder
	end

	-- whose-turn glow + timer bar
	local glow = Util.new("Frame", {
		Name = "TurnGlow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = card,
	})
	Util.corner(glow, 12)
	local glowStroke = Util.stroke(glow, C.brass, 4)
	local timer = Widgets.progress(card, {
		name = "Timer",
		size = UDim2.new(1, -20, 0, 5),
		position = UDim2.new(0, 12, 1, -4),
		value = 1,
		color = C.brass,
		z = 6,
	})
	timer.root.Visible = false

	local entry = {
		root = card,
		stroke = stroke,
		slots = slotFrames,
		coins = coins,
		cards = cardsN,
		status = statusIcons,
		glow = glow,
		glowStroke = glowStroke,
		timer = timer,
		name = name,
		sub = sub,
		info = info,
		treasures = 0,
	}
	card.Activated:Connect(function()
		if self.onClick then
			self.onClick(info.seat)
		end
	end)
	return entry
end

function PlayersPanel:update(snap)
	for _, p in snap.players do
		local e = self.cards[p.seat]
		if e then
			for i, slot in e.slots do
				local filled = i <= p.treasures
				slot.BackgroundColor3 = if filled then C.gold else C.parchmentDark
				if filled and i > e.treasures then
					Util.bump(slot, 0.5)
				end
			end
			e.treasures = p.treasures
			local coinsLabel = e.coins :: TextLabel
			if coinsLabel.Text ~= tostring(p.coins) then
				coinsLabel.Text = tostring(p.coins)
				Util.bump(coinsLabel, 0.3)
			end
			(e.cards :: TextLabel).Text = tostring(p.handCount)
			e.status.burning.Visible = p.burning
			e.status.frozen.Visible = p.frozen
			e.status.boots.Visible = p.boots
			e.status.held.Visible = p.held
			e.status.skip.Visible = p.skip > 0
			e.status.anchor.Visible = (p.anchor or 0) > 0
			if p.finished then
				e.sub.Text = "FINISHED  ·  helping the team"
			end
			if p.isBot and not e.info.isBot then
				e.info.isBot = true
				e.name.Text = p.name
			end
		end
	end
end

function PlayersPanel:setCurrent(seat: number?, deadline: number?)
	for s, e in self.cards do
		local on = s == seat
		e.glow.Visible = on
		e.timer.root.Visible = on and deadline ~= nil and deadline > 0
		e.root.BackgroundColor3 = if on then Color3.fromHex("FFF6D6") else Color3.fromHex("FBF3DD")
	end
	self.currentSeat = seat
	self.deadline = deadline
	self.timerStart = workspace:GetServerTimeNow()
end

-- Called every frame by the match screen to drain the turn timer bar.
function PlayersPanel:tick(now: number)
	local seat = self.currentSeat
	if not seat or not self.deadline or self.deadline <= 0 then
		return
	end
	local e = self.cards[seat]
	if not e then
		return
	end
	local total = math.max(1, self.deadline - (self.timerStart or now))
	local left = math.clamp((self.deadline - now) / total, 0, 1)
	e.timer:set(left, true)
	e.timer.fill.BackgroundColor3 = if left < 0.25 then C.bad else C.brass
end

-- Lets the player click someone (Telepathy, Hex...). Returns a cancel function.
function PlayersPanel:pick(seats: { number }, onPick: (number) -> ())
	self:clearPick()
	local glows = {}
	for _, s in seats do
		local e = self.cards[s]
		if e then
			local g = Util.new("Frame", {
				Name = "PickGlow",
				BackgroundColor3 = C.brassLight,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 9,
				Parent = e.root,
			})
			Util.corner(g, 12)
			Util.stroke(g, C.brass, 3)
			table.insert(glows, g)
			task.spawn(function()
				while g.Parent do
					Util.tween(g, 0.45, { BackgroundTransparency = 0.82 }, Enum.EasingStyle.Sine)
					task.wait(0.45)
					if not g.Parent then
						break
					end
					Util.tween(g, 0.45, { BackgroundTransparency = 0.6 }, Enum.EasingStyle.Sine)
					task.wait(0.45)
				end
			end)
		end
	end
	self._pick = glows
	self.onClick = function(seat)
		if table.find(seats, seat) then
			self:clearPick()
			onPick(seat)
		end
	end
	return function()
		self:clearPick()
	end
end

function PlayersPanel:clearPick()
	if self._pick then
		for _, g in self._pick do
			g:Destroy()
		end
		self._pick = nil
	end
	self.onClick = nil
end

function PlayersPanel:cardOf(seat: number): Frame?
	local e = self.cards[seat]
	return e and e.root
end

function PlayersPanel:emote(seat: number, emoteId: string)
	local e = self.cards[seat]
	if not e then
		return
	end
	local bubble = CosmeticArt.emoteBubble(e.root, emoteId, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		ZIndex = 30,
	})
	if bubble then
		Util.popIn(bubble, 0.3, 0.4)
		task.delay(2.6, function()
			Util.tween(Util.scaler(bubble), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.22)
			bubble:Destroy()
		end)
	end
end

function PlayersPanel:shake(seat: number)
	local e = self.cards[seat]
	if e then
		Util.shake(e.root, 6, 0.3)
	end
end

function PlayersPanel:flash(seat: number, color: Color3)
	local e = self.cards[seat]
	if not e then
		return
	end
	local f = Util.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = e.root,
	})
	Util.corner(f, 12)
	Util.tween(f, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.62, function()
		f:Destroy()
	end)
end

return PlayersPanel
