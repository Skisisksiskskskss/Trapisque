--[[
	PlayerChips
	One chip per player: their avatar (with their seat colour around it), name and
	@username, character, treasures, coins, cards and any status they're under. Whose
	turn it is shows as a brass rim and a draining timer bar.

	Three shapes, picked by the layout:
		"full"   PC: a dark card with every detail
		"band"   landscape phone: a slim chip that rides in Roblox's top bar
		"stack"  upright phone: avatar on top, treasures underneath

		local chips = PlayerChips.new(parent, seats, { target, mySeat, isTeam })
		chips:layout(L.players)        -- { rect, dir, chip = { w, h, kind }, gap }
		chips:update(players)          -- [seat] = { treasures, coins, handCount, burning, ... }
		chips:setCurrent(seat, deadline) ; chips:tick(now)
		chips:pick(seats, onPick) ; chips:clearPick()
		chips:center(seat) -> Vector2  -- stage pixels
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)
local Avatars = require(UI.Avatars)

local C = Theme.C
local hex = Theme.hex

local PlayerChips = {}
PlayerChips.__index = PlayerChips

local CHIP_BG = hex("1F150E")
local CHIP_BG_TURN = hex("3A2A14")
local TEXT_FAINT = hex("BFA98A")

local STATUS = {
	{ key = "burning", icon = "fire", color = hex("E2622B") },
	{ key = "frozen", icon = "ice", color = hex("5DADE2") },
	{ key = "held", icon = "lock", color = hex("8A9099") },
	{ key = "skip", icon = "snare", color = hex("A0522D") },
	{ key = "boots", icon = "boots", color = hex("8B6B3E") },
	{ key = "anchor", icon = "hourglass", color = hex("8E6CEF") },
}

local function seatColor(seat: number): Color3
	return Theme.Seat[((seat - 1) % 6) + 1]
end

function PlayerChips.new(parent: Instance, seats, opts)
	local self = setmetatable({}, PlayerChips)
	self.parent = parent
	self.seats = seats
	self.target = opts.target or 3
	self.mySeat = opts.mySeat
	self.isTeam = opts.isTeam == true
	self.chips = {} -- [seat] = entry
	self.order = {}
	self.state = {}
	self.root = Util.frame(parent, { Name = "Players" })
	for _, info in seats do
		table.insert(self.order, info.seat)
	end
	table.sort(self.order)
	return self
end

function PlayerChips:destroy()
	self.root:Destroy()
end

-- (Re)builds every chip for the given layout spec. Cheap enough to do on rotation.
function PlayerChips:layout(spec)
	self.spec = spec
	local root = self.root :: Frame
	Util.clear(root)
	self.chips = {}
	local r = spec.rect
	root.Position = UDim2.fromOffset(r.x, r.y)
	root.Size = UDim2.fromOffset(r.w, r.h)
	for i, seat in self.order do
		local info = nil
		for _, s in self.seats do
			if s.seat == seat then
				info = s
			end
		end
		if info then
			local x = if spec.dir == "x" then (i - 1) * (spec.chip.w + spec.gap) else 0
			local y = if spec.dir == "y" then (i - 1) * (spec.chip.h + spec.gap) else 0
			self.chips[seat] = self:_build(info, x, y, spec.chip)
		end
	end
	self:update(self.state)
	if self.currentSeat then
		-- keep the turn timer where it was
		local started = self.timerStart
		self:setCurrent(self.currentSeat, self.deadline)
		self.timerStart = started
	end
end

function PlayerChips:_build(info, x: number, y: number, chip)
	local w, h, kind = chip.w, chip.h, chip.kind
	local color = seatColor(info.seat)
	local root = Util.new("TextButton", {
		Name = "Player" .. info.seat,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CHIP_BG,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Parent = self.root,
	})
	Util.corner(root, math.min(12, h * 0.3))
	local rim = Util.stroke(root, Util.shade(color, -0.35), 2)
	local e = { root = root, rim = rim, info = info, kind = kind, w = w, h = h, color = color }

	local name = info.name .. (if info.seat == self.mySeat then " (you)" else "")
	local charDef = Characters.get(info.character or "")
	local charName = if charDef then charDef.name else ""
	local sub = if info.isBot then ("Bot · " .. charName) elseif info.username and info.username ~= info.name then ("@" .. info.username .. " · " .. charName) else charName

	local function pips(parent: Instance, px: number, py: number, size: number, gap: number)
		local holder = Util.frame(parent, { Name = "Treasures", Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(self.target * (size + gap), size) })
		Util.list(holder, "x", gap, "Left", "Center")
		local list = {}
		for i = 1, self.target do
			local pip = Util.new("Frame", {
				Name = "Pip" .. i,
				BackgroundColor3 = hex("4A3A28"),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(size, size),
				LayoutOrder = i,
				Parent = holder,
			})
			Util.corner(pip, 0.5)
			list[i] = pip
		end
		return list, holder
	end

	local function counter(parent: Instance, icon: string, iconColor: Color3, order: number, size: number)
		local box = Util.frame(parent, { Name = icon, Size = UDim2.fromOffset(size + 20, size + 2), LayoutOrder = order })
		local ic = Util.frame(box, { Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(0, 1) })
		Icons.make(ic, icon, Icons.flatColors(iconColor, CHIP_BG))
		local n = Widgets.label(box, {
			text = "0",
			font = "chunky",
			size = size,
			color = C.white,
			sizeUDim = UDim2.fromOffset(20, size + 2),
			position = UDim2.fromOffset(size + 2, 0),
		})
		return n
	end

	if kind == "full" then
		local avatarSize = h - 16
		e.avatar = Avatars.portrait(root, info, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(avatarSize, avatarSize),
		}, { ring = color, ringPx = 3 })
		local tx = 8 + avatarSize + 10
		local tagRoom = if self.isTeam then 34 else 0
		e.name = Widgets.label(root, {
			name = "Name",
			text = name,
			font = "heavy",
			size = 16,
			color = if info.look and info.look.vip then hex("F2C445") else C.white,
			sizeUDim = UDim2.fromOffset(w - tx - 8 - tagRoom, 18),
			position = UDim2.fromOffset(tx, 5),
		})
		e.name.TextTruncate = Enum.TextTruncate.AtEnd
		if h >= 56 then
			local s = Widgets.label(root, {
				name = "Sub",
				text = sub,
				font = "body",
				size = 12,
				color = Util.shade(Theme.Character[info.character] or TEXT_FAINT, 0.35),
				sizeUDim = UDim2.fromOffset(w - tx - 8, 14),
				position = UDim2.fromOffset(tx, 23),
			})
			s.TextTruncate = Enum.TextTruncate.AtEnd
		end
		local rowY = h - 20
		e.pips = pips(root, tx, rowY + 2, 14, 4)
		local counters = Util.frame(root, {
			Name = "Counters",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, rowY),
			Size = UDim2.fromOffset(80, 18),
		})
		Util.list(counters, "x", 4, "Right", "Center")
		e.coins = counter(counters, "coin", C.brass, 1, 14)
		e.cards = counter(counters, "book", C.woodLight, 2, 14)
		-- statuses sit to the right of the name line
		local st = Util.frame(root, {
			Name = "Status",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8 - tagRoom, 0, 5),
			Size = UDim2.fromOffset(90, 16),
		})
		Util.list(st, "x", 3, "Right", "Center")
		e.statusRow = st
		e.statusSize = 16
		if self.isTeam then
			local teamColor = Theme.Team[info.team] or color
			local tag = Widgets.badge(root, {
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
	elseif kind == "band" then
		local avatarSize = h - 6
		e.avatar = Avatars.portrait(root, info, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(avatarSize, avatarSize),
		}, { ring = color, ringPx = 2 })
		local tx = 3 + avatarSize + 5
		e.name = Widgets.label(root, {
			name = "Name",
			text = info.name,
			font = "heavy",
			size = 11,
			color = C.white,
			sizeUDim = UDim2.fromOffset(w - tx - 4, 13),
			position = UDim2.fromOffset(tx, 3),
		})
		e.name.TextTruncate = Enum.TextTruncate.AtEnd
		local pipSize = math.clamp(math.floor((w - tx - 6 - (self.target - 1) * 3) / self.target), 6, 11)
		e.pips = pips(root, tx, h - pipSize - 5, pipSize, 3)
		e.statusSize = math.floor(avatarSize * 0.42)
	else -- "stack"
		local avatarSize = math.min(h - 30, w - 12)
		e.avatar = Avatars.portrait(root, info, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(avatarSize, avatarSize),
		}, { ring = color, ringPx = 2 })
		e.name = Widgets.label(root, {
			name = "Name",
			text = info.name,
			font = "heavy",
			size = 11,
			color = C.white,
			align = "center",
			sizeUDim = UDim2.fromOffset(w - 6, 13),
			position = UDim2.fromOffset(3, 4 + avatarSize + 1),
		})
		e.name.TextTruncate = Enum.TextTruncate.AtEnd
		local pipSize = math.clamp(math.floor((w - 10 - (self.target - 1) * 3) / self.target), 6, 10)
		local pw = self.target * pipSize + (self.target - 1) * 3
		e.pips = pips(root, (w - pw) / 2, h - pipSize - 5, pipSize, 3)
		e.statusSize = math.floor(avatarSize * 0.42)
	end
	if kind ~= "full" then
		-- one status badge on the avatar's corner (the most important one)
		local badge = Util.frame(e.avatar, {
			Name = "StatusBadge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.14),
			Size = UDim2.fromOffset(e.statusSize, e.statusSize),
			ZIndex = 10,
			Visible = false,
		})
		e.statusBadge = badge
		if self.isTeam then
			local bar = Util.new("Frame", {
				Name = "Team",
				BackgroundColor3 = Theme.Team[info.team] or color,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 6, 1, -3),
				Size = UDim2.new(1, -12, 0, 2),
				Parent = root,
			})
			Util.corner(bar, 0.5)
		end
	end

	-- whose-turn rim and timer bar
	e.timer = Widgets.progress(root, {
		name = "Timer",
		size = UDim2.new(1, -16, 0, 3),
		position = UDim2.new(0, 8, 1, -4),
		value = 1,
		color = C.brass,
		z = 6,
	})
	e.timer.root.Visible = false

	root.Activated:Connect(function()
		if self.onPick and self.pickable and self.pickable[info.seat] then
			self.onPick(info.seat)
		elseif self.onClick then
			self.onClick(info.seat)
		end
	end)
	root.MouseEnter:Connect(function()
		if self.pickable and self.pickable[info.seat] then
			Util.tween(root, 0.1, { BackgroundColor3 = hex("4A3A20") })
		end
	end)
	root.MouseLeave:Connect(function()
		if self.pickable and self.pickable[info.seat] then
			Util.tween(root, 0.1, { BackgroundColor3 = CHIP_BG })
		end
	end)
	return e
end

-- players: [seat] = { treasures, coins, handCount, burning, frozen, held, skip, boots, anchor, finished }
function PlayerChips:update(players)
	self.state = players
	for seat, e in self.chips do
		local p = players[seat]
		if p then
			for i, pip in e.pips do
				local filled = i <= (p.treasures or 0)
				local was = pip:GetAttribute("Filled") == true
				pip.BackgroundColor3 = if filled then C.gold else hex("4A3A28")
				if filled and not was then
					Util.bump(pip, 0.6)
				end
				pip:SetAttribute("Filled", filled)
			end
			if e.coins then
				local text = tostring(p.coins or 0)
				if e.coins.Text ~= text then
					e.coins.Text = text
					Util.bump(e.coins, 0.3)
				end
			end
			if e.cards then
				e.cards.Text = tostring(p.handCount or 0)
			end
			local active = {}
			for _, s in STATUS do
				local v = p[s.key]
				if v == true or (type(v) == "number" and v > 0) then
					table.insert(active, s)
				end
			end
			if e.statusRow then
				Util.clear(e.statusRow, true)
				for i, s in active do
					local holder = Util.frame(e.statusRow, { Name = s.key, Size = UDim2.fromOffset(e.statusSize, e.statusSize), LayoutOrder = i })
					Icons.medallion(holder, s.icon, s.color, { Size = UDim2.fromScale(1, 1) })
				end
			elseif e.statusBadge then
				Util.clear(e.statusBadge)
				local s = active[1]
				e.statusBadge.Visible = s ~= nil
				if s then
					Icons.medallion(e.statusBadge, s.icon, s.color, { Size = UDim2.fromScale(1, 1) })
				end
			end
			if p.finished and e.name then
				e.name.TextTransparency = 0.35
			end
		end
	end
end

function PlayerChips:setCurrent(seat: number?, deadline: number?)
	self.currentSeat = seat
	self.deadline = deadline
	self.timerStart = workspace:GetServerTimeNow()
	for s, e in self.chips do
		local on = s == seat
		e.rim.Color = if on then C.brass else Util.shade(e.color, -0.35)
		e.rim.Thickness = if on then 3 else 2
		e.root.BackgroundColor3 = if on then CHIP_BG_TURN else CHIP_BG
		e.timer.root.Visible = on and deadline ~= nil and deadline > 0
		if on then
			Util.bump(e.root, 0.06)
		end
	end
end

-- Drains the current player's timer bar (called every frame).
function PlayerChips:tick(now: number)
	local seat = self.currentSeat
	local e = seat and self.chips[seat]
	if not e or not self.deadline or self.deadline <= 0 then
		return
	end
	local total = math.max(1, self.deadline - (self.timerStart or now))
	local left = math.clamp((self.deadline - now) / total, 0, 1)
	e.timer:set(left, true)
	e.timer.fill.BackgroundColor3 = if left < 0.25 then C.bad else C.brass
end

function PlayerChips:center(seat: number): Vector2?
	local e = self.chips[seat]
	if not e then
		return nil
	end
	local r = self.spec.rect
	local pos = e.root.Position
	return Vector2.new(r.x + pos.X.Offset + e.w / 2, r.y + pos.Y.Offset + e.h / 2)
end

function PlayerChips:flash(seat: number, color: Color3)
	local e = self.chips[seat]
	if not e then
		return
	end
	local old = e.rim.Color
	e.rim.Color = color
	Util.bump(e.root, 0.1)
	task.delay(0.6, function()
		if e.root.Parent then
			e.rim.Color = if seat == self.currentSeat then C.brass else old
		end
	end)
end

function PlayerChips:shake(seat: number)
	local e = self.chips[seat]
	if e then
		Util.shake(e.root, 6, 0.3)
	end
end

-- An emote bubble pops out of the chip (towards the board).
function PlayerChips:emote(seat: number, emoteId: string)
	local e = self.chips[seat]
	if not e then
		return
	end
	local dir = self.spec and self.spec.dir or "y"
	local bubble = CosmeticArt.emoteBubble(e.root, emoteId, {
		AnchorPoint = if dir == "y" then Vector2.new(0, 0.5) else Vector2.new(0.5, 0),
		Position = if dir == "y" then UDim2.new(1, 8, 0.5, 0) else UDim2.new(0.5, 0, 1, 6),
		ZIndex = 40,
	})
	if bubble then
		Util.popIn(bubble, 0.3, 0.3)
		task.delay(2.4, function()
			if bubble.Parent then
				Util.tween(Util.scaler(bubble), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.wait(0.22)
				bubble:Destroy()
			end
		end)
	end
end

-- Lets the player click someone (Telepathy, Hex...).
function PlayerChips:pick(seats: { number }, onPick: (number) -> ())
	self.pickable = {}
	for _, s in seats do
		self.pickable[s] = true
	end
	self.onPick = onPick
	for s, e in self.chips do
		if self.pickable[s] then
			e.rim.Color = C.gold
			e.rim.Thickness = 3
			local pulse = Util.new("Frame", {
				Name = "PickPulse",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 20,
				Parent = e.root,
			})
			Util.corner(pulse, math.min(12, e.h * 0.3))
			local st = Util.stroke(pulse, C.gold, 3)
			task.spawn(function()
				while pulse.Parent do
					Util.tween(st, 0.45, { Transparency = 0.8 }, Enum.EasingStyle.Sine)
					task.wait(0.45)
					Util.tween(st, 0.45, { Transparency = 0 }, Enum.EasingStyle.Sine)
					task.wait(0.45)
				end
			end)
		else
			e.root.BackgroundTransparency = 0.5
		end
	end
end

function PlayerChips:clearPick()
	self.pickable = nil
	self.onPick = nil
	for _, e in self.chips do
		local pulse = e.root:FindFirstChild("PickPulse")
		if pulse then
			pulse:Destroy()
		end
		e.root.BackgroundTransparency = 0.06
	end
	self:setCurrent(self.currentSeat, self.deadline)
end

return PlayerChips
