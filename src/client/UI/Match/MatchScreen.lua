--[[
	MatchScreen
	The whole match. The board fills the screen; the HUD (players, your cards, your dice
	tray, your Power panel, the top bar) sits around it wherever Layout puts it for this
	screen, and moves when the screen changes shape (an upright phone stands the board
	up as well).

	A turn: your two dice are rolled for you as it starts. Hover a die (tap it on a
	phone) and the board shows where it takes you and what happens there (a bonk, a
	token, a hazard, a trap you know about); click it to go. The die you don't use
	charges your Power. Before moving you may play one card (hide a trap near you, a
	boost for this move...) and, once your Power bar is full, your ability.

	The server sends batches of events ("match.events"). They're queued and played back
	one by one at the pace the server expects (Shared/Game/Pacing). Each batch also says
	when the server thinks it ends; a screen that has fallen behind plays faster (or
	skips ahead) so your turn never starts after your time is already running out.
	A display state (self.view) changes as each animation lands: a drawn card joins your
	hand when it arrives there, coins tick up as the coin flies in. The snapshot that
	came with the batch then corrects anything that drifted, so the screen always ends
	up in sync.

		MatchScreen.show(payload)  -- from "match.start" or a resync
		MatchScreen.current()      -- the running screen, if any
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Game.Items)
local Characters = require(Shared.Game.Characters)
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)
local Engine = require(Shared.Game.Engine)
local Pacing = require(Shared.Game.Pacing)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local CosmeticArt = require(UI.CosmeticArt)
local Avatars = require(UI.Avatars)
local Layout = require(UI.Layout)
local Root = require(UI.Root)
local CardStyle = require(UI.CardStyle)
local BoardView = require(script.Parent.BoardView)
local PlayerChips = require(script.Parent.PlayerChips)
local HandView = require(script.Parent.HandView)
local ActionDock = require(script.Parent.ActionDock)
local Feed = require(script.Parent.Feed)
local Overlays = require(script.Parent.Overlays)
local Effects = require(script.Parent.Effects)
local Inspector = require(script.Parent.Inspector)
local CardTip = require(script.Parent.CardTip)
local VolumeRows = require(UI.VolumeRows)
local Shop = require(script.Parent.Shop)
local Results = require(script.Parent.Results)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C
local Rules = Config.Rules
local CharCfg = Config.Characters

local MatchScreen = {}
MatchScreen.__index = MatchScreen

local active = nil

local DEATH_TEXT = {
	spike = "was spiked",
	grog = "was eaten by a Grog",
}

local NATURAL_TEXT = {
	river = "fell in the river",
	gate = "is stuck at a locked gate",
	slime = "got stuck in the slime",
}

local WHEEL_NAME = { trap = "Trap", assist = "Assist", neutral = "Board Piece" }
local LENGTH_NAME = { quick = "Quick", standard = "Standard", classic = "Classic" }
local DIE_KEYS = { [Enum.KeyCode.Q] = 1, [Enum.KeyCode.W] = 2, [Enum.KeyCode.E] = 3 }

local function toHex(c: Color3): string
	return c:ToHex()
end

-- "a Spike", "an Ice", "an X-Ray Potion"
local function aName(name: string): string
	local first = string.upper(string.sub(name, 1, 1))
	local an = string.find("AEIOU", first, 1, true) ~= nil or string.upper(string.sub(name, 1, 2)) == "X-"
	return (if an then "an " else "a ") .. name
end

local function copy(list)
	local out = {}
	for i, v in list or {} do
		out[i] = v
	end
	return out
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function MatchScreen.current()
	return active
end

function MatchScreen.show(payload)
	if active then
		active:_destroy()
	end
	local self = setmetatable({}, MatchScreen)
	active = self
	self.id = payload.id
	self.mySeat = payload.seat
	self.kind = payload.kind
	self.mode = Modes.get(payload.mode)
	self.isTeam = self.mode ~= nil and self.mode.isTeam == true
	self.mapDef = Maps.get(payload.map)
	self.target = payload.target
	self.length = payload.length
	self.seats = {}
	for _, s in payload.seats do
		self.seats[s.seat] = s
	end
	self.snap = payload.snapshot
	-- the opening cards are dealt by animation; start with an empty hand unless resyncing
	self.view = self:_viewFrom(payload.snapshot, not payload.resync)
	self.deadline = payload.deadline or 0
	self.queue = {}
	self.holding = false -- true while the intro plays (events wait their turn)
	self.playing = false
	self.busy = false
	self.alive = true
	self.speed = 1
	self.epoch = 0 -- bumped by every snapshot
	self.inflight = 0 -- cards and coins still flying
	self.maid = Util.maid()
	if not payload.resync then
		-- the opening batch plays first, after the intro; anything newer queues behind it
		self.holding = true
		table.insert(self.queue, payload)
	end

	Root.show("match", function(container)
		self:_build(container)
		return function()
			self:_destroy()
		end
	end)

	-- server pushes for this match
	self.maid:add(Net.on("match.events", function(data)
		if self.alive and data.id == self.id then
			self:_setAway(data.auto == true)
			self:_enqueue(data)
		end
	end))
	self.maid:add(Net.on("match.auto", function(data)
		if self.alive and data.id == self.id then
			self:_setAway(data.on == true)
		end
	end))
	self.maid:add(Net.on("match.emote", function(data)
		if self.alive and data.id == self.id and self.chips then
			self.chips:emote(data.seat, data.emote)
			Sound.play("pop")
		end
	end))
	self.maid:add(Net.on("match.end", function(data)
		if self.alive and data.id == self.id then
			self:_showResults(data)
		end
	end))

	if payload.resync then
		self:_reconcile(payload)
	else
		task.spawn(function()
			self:_intro(payload)
		end)
	end
	self:_setAway(payload.auto == true)
	self:_updateMood()
	return self
end

-- The match music: calm, or the endgame once a player (or a team) is a treasure away.
function MatchScreen:_updateMood()
	local v = self.view
	if v.phase == "over" then
		return
	end
	local have, teamSize = {}, {}
	for _, p in v.players do
		local team = p.team or p.seat
		have[team] = (have[team] or 0) + (p.treasures or 0)
		teamSize[team] = (teamSize[team] or 0) + 1
	end
	local close = false
	for team, n in have do
		local need = (self.target or 0) * (if self.isTeam then teamSize[team] else 1)
		if need - n <= 1 then
			close = true
		end
	end
	Sound.music(if close then "tension" else "match")
end

-- The display state, from a snapshot. `noHand` starts with an empty hand (the deal fills it).
function MatchScreen:_viewFrom(snap, noHand: boolean?)
	local players = {}
	local characters = {}
	for _, p in snap.players do
		characters[p.seat] = p.character
	end
	Theme.setSeatCharacters(characters)
	for _, p in snap.players do
		local copyOf = table.clone(p)
		if noHand then
			copyOf.handCount = 0
		end
		copyOf.underdog = snap.underdog == p.seat
		players[p.seat] = copyOf
	end
	local tokens, placed, natural, embers = {}, {}, {}, {}
	for _, t in snap.tokens or {} do
		tokens[t.tile] = t.kind
	end
	for _, e in snap.placed or {} do
		placed[e.tile] = table.clone(e)
	end
	for _, n in snap.natural or {} do
		natural[n.tile] = n.kind
	end
	for _, e in snap.embers or {} do
		embers[e.tile] = e.owner or 0
	end
	local traps = {}
	for _, t in snap.traps or {} do
		table.insert(traps, table.clone(t))
	end
	return {
		round = snap.round or 1,
		current = snap.current,
		phase = snap.phase,
		abilityUsed = snap.abilityUsed == true,
		cardsPlayed = snap.cardsPlayed or 0,
		boost = snap.boost,
		dice = copy(snap.dice),
		gold = snap.gold,
		chosen = nil,
		hand = if noHand then {} else copy(snap.hand),
		trail = copy(snap.trail),
		pick = snap.pick and copy(snap.pick) or nil,
		mutator = snap.mutator or {},
		stock = table.clone(snap.stock or {}),
		players = players,
		tokens = tokens,
		placed = placed,
		natural = natural,
		embers = embers,
		traps = traps,
	}
end

-- The display state shaped like a snapshot (for the board and placement checks).
function MatchScreen:_viewAsSnap()
	local v = self.view
	local players, tokens, placed, natural, embers = {}, {}, {}, {}, {}
	for _, p in v.players do
		table.insert(players, p)
	end
	for tile, kind in v.tokens do
		table.insert(tokens, { tile = tile, kind = kind })
	end
	for _, e in v.placed do
		table.insert(placed, e)
	end
	for tile, kind in v.natural do
		table.insert(natural, { tile = tile, kind = kind })
	end
	for tile, owner in v.embers do
		table.insert(embers, { tile = tile, owner = owner })
	end
	return { players = players, tokens = tokens, placed = placed, natural = natural, embers = embers, traps = v.traps }
end

function MatchScreen:_build(container: Frame)
	local root = Util.frame(container, { Name = "Match" })
	self.root = root
	self.boardLayer = Util.frame(root, { Name = "BoardLayer", ZIndex = 1 })
	self.hud = Util.frame(root, { Name = "Hud", ZIndex = 10 })
	self.fx = Util.frame(root, { Name = "Fx", ZIndex = 50 })
	self.fly = Util.frame(root, { Name = "Fly", ZIndex = 60 })
	self.popups = Util.frame(root, { Name = "Popups", ZIndex = 80 })

	local touch = Root.metrics.touch
	local me = self.seats[self.mySeat]
	self.chips = PlayerChips.new(self.hud, self:_seatList(), { target = self.target, mySeat = self.mySeat, isTeam = self.isTeam })
	self.chips.onClick = function(seat)
		self:_inspectPlayer(seat)
	end
	self.hand = HandView.new(self.hud, { touch = touch })
	self.hand.onCard = function(id, index)
		self:_cardClicked(id, index)
	end
	self.hand.onHover = function(id, index)
		self:_cardHover(id, index)
	end
	self.hand.onDragStart = function(id, index, pos)
		return self:_dragStart(id, index, pos)
	end
	self.hand.onDragMove = function(pos)
		if self.dragging then
			self.dragging.point(pos)
		end
	end
	self.hand.onDragEnd = function(pos)
		if self.dragging then
			self.dragging.release(pos)
		end
	end
	self.tip = CardTip.new(self.popups)
	self.dock = ActionDock.new(self.hud, {
		character = me and me.character,
		touch = touch,
		diceSkin = me and me.look and me.look.dice,
	})
	self.dock.onDie = function(key)
		self:_move(key)
	end
	self.dock.onDieHover = function(key)
		self:_previewDie(key)
	end
	self.dock.onAbility = function()
		self:_abilityClicked()
	end
	self.dock.onRecall = function()
		self:_recall()
	end
	self.dock.onPortrait = function()
		if me and me.character then
			Inspector.character(self.popups, me.character)
		end
	end
	self.feed = Feed.new(self.hud)
	self.info = Util.frame(self.hud, { Name = "Info" })
	self.buttons = Util.frame(self.hud, { Name = "Buttons" })

	self.maid:add(Root.onResize(function(_vw, _vh, m)
		if self.alive then
			self:_relayout(m)
		end
	end))

	-- timers, keys
	self.maid:add(RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		self.chips:tick(now)
		self.dock:setClock(self:_timeLeft(now))
	end))
	self.maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		-- clicks on buttons count too: they're "processed" by the UI
		self:_noteActivity(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and self.cancelTarget then
			-- right-click puts a card you're placing back in your hand
			self.cancelTarget()
			return
		end
		if processed then
			return
		end
		self:_key(input.KeyCode)
	end))
end

-- Seconds left on my turn (nil when it isn't my turn, or the game has no timer).
function MatchScreen:_timeLeft(now: number): number?
	local v = self.view
	if v.current ~= self.mySeat or (v.phase ~= "action" and v.phase ~= "shop" and v.phase ~= "pick") then
		return nil
	end
	if (self.deadline or 0) <= 0 or self.playing or #self.queue > 0 then
		return nil
	end
	return self.deadline - now
end

local ACTIVE_INPUT = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.Gamepad1] = true,
}

--[[
	Lets the server know I'm here (now and then, on a tap, click or key). A player who
	is here is never treated as away, and if a bot was playing for me, this ends it.
]]
function MatchScreen:_noteActivity(input: InputObject)
	if not ACTIVE_INPUT[input.UserInputType] then
		return
	end
	local now = os.clock()
	local gap = if self.awayBar then 1 else 4
	if now - (self.lastPing or -math.huge) < gap then
		return
	end
	self.lastPing = now
	task.spawn(function()
		local ok = Net.request("match.active")
		if ok and self.alive then
			self:_setAway(false)
		end
	end)
end

-- While a bot plays my turns: a bar over the board ("I'M BACK"; any tap works too).
function MatchScreen:_setAway(on: boolean)
	if on == (self.awayBar ~= nil) then
		return
	end
	if not on then
		local bar = self.awayBar
		self.awayBar = nil
		Util.tween(Util.scaler(bar), 0.15, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			bar:Destroy()
		end)
		return
	end
	if not self.root then
		return
	end
	local bar = Util.new("Frame", {
		Name = "AwayBar",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		ZIndex = 75,
		Parent = self.root,
	})
	Util.corner(bar, 12)
	Util.stroke(bar, C.line, 3)
	local label = Widgets.label(bar, {
		text = "A bot is playing your turns while you're away.",
		font = "heavy",
		size = 16,
		color = C.text,
		wrap = true,
		z = 76,
	})
	local back = Widgets.button(bar, {
		text = "I'M BACK",
		style = "green",
		textSize = 16,
		z = 77,
		onClick = function()
			self.lastPing = os.clock()
			task.spawn(function()
				local ok = Net.request("match.active")
				if ok and self.alive then
					self:_setAway(false)
				end
			end)
		end,
	})
	self.awayBar = bar
	self.awayLayout = function()
		local r = self.L and self.L.hint or Layout.rect(0, 0, 400, 48)
		local h = math.max(44, r.h)
		local bw = if r.w < 420 then 96 else 120
		bar.Position = UDim2.fromOffset(r.x, r.y)
		bar.Size = UDim2.fromOffset(r.w, h)
		back.root.AnchorPoint = Vector2.new(1, 0.5)
		back.root.Position = UDim2.new(1, -6, 0.5, 0)
		back.root.Size = UDim2.fromOffset(bw, h - 12)
		label.Position = UDim2.fromOffset(12, 0)
		label.Size = UDim2.new(1, -(30 + bw), 1, 0)
		label.TextSize = if r.w < 420 then 13 else 16
	end
	self.awayLayout()
	Util.popIn(bar, 0.25, 0.7)
	Sound.play("error")
end

-- Lays the HUD out for this screen (and stands the board up on upright phones).
function MatchScreen:_relayout(m)
	local L = Layout.match(m, #self:_seatList())
	self.L = L
	local rotate = m.form == "tall"
	local first = self.board == nil
	-- a card held over the board belongs to the old layout
	if self.dragging and self.dragging.cancel then
		self.dragging.cancel()
	end
	if first or self.boardRotated ~= rotate then
		if self.board then
			-- a tile pick in progress belongs to the old board
			if self.cancelTarget then
				self.cancelTarget()
			end
			self.board:destroy()
		end
		self.board = BoardView.new(self.boardLayer, self.mapDef.id, { rotate = rotate, mySeat = self.mySeat })
		self.boardRotated = rotate
		for _, p in self.view.players do
			local info = self.seats[p.seat] or {}
			self.board:addPawn(p.seat, {
				look = info.look,
				character = p.character,
				name = p.name,
				tagName = if p.seat == self.mySeat then "You" else p.name,
				userId = info.userId,
				isBot = p.isBot,
			}, p.tile)
		end
		self.board:applySnapshot(self:_viewAsSnap())
		self.board:setCurrent(if self.view.phase ~= "over" then self.view.current else nil)
		self.board:setFocus(L.focus, true)
	else
		self.board:setFocus(L.focus, false)
	end
	-- effects play over the board area
	self.fx.Position = UDim2.fromOffset(L.focus.x, L.focus.y)
	self.fx.Size = UDim2.fromOffset(L.focus.w, L.focus.h)

	self.chips:layout(L.players)
	self:_closeTip()
	self.hand:layout(L.hand)
	self.dock:layout(L.ability, L.roll, m.form)
	self.feed:layout(L.feed)
	self:_layoutTop(L, m)
	self:_refresh()
	if self.cancelTarget and self.hintLayout then
		self.hintLayout()
	end
	if self.awayBar and self.awayLayout then
		self.awayLayout()
	end
end

function MatchScreen:_layoutTop(L, m)
	-- round / mode plate
	Util.clear(self.info)
	local info = L.info
	self.info.Visible = info ~= nil
	if info then
		self.info.Position = UDim2.fromOffset(info.x, info.y)
		self.info.Size = UDim2.fromOffset(info.w, info.h)
		local plate = Util.new("Frame", {
			Name = "Plate",
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = self.info,
		})
		Util.corner(plate, math.min(10, info.h / 2))
		Util.stroke(plate, C.line, 2.5)
		self.roundLabel = Widgets.label(plate, {
			text = "",
			font = "heavy",
			size = math.clamp(math.floor(info.h * 0.5), 11, 16),
			color = C.text,
			sizeUDim = UDim2.new(1, -16, 1, 0),
			position = UDim2.fromOffset(8, 0),
		})
		self.roundLabel.TextTruncate = Enum.TextTruncate.AtEnd
	else
		self.roundLabel = nil
	end
	self:_updateRound()

	-- icon buttons
	Util.clear(self.buttons)
	local b = L.buttons
	self.buttons.Position = UDim2.fromOffset(b.rect.x, b.rect.y)
	self.buttons.Size = UDim2.fromOffset(b.rect.w, b.rect.h)
	Util.list(self.buttons, "x", b.gap, "Right", "Center")
	local list = {
		{ icon = "people", style = "panel", onClick = function()
			self:_scoreboard()
		end, key = "scores" },
		{ icon = "map", style = "panel", onClick = function()
			if self.board then
				self.board:fit()
			end
		end, key = "fit" },
		{ icon = "smile", style = "brass", onClick = function()
			self:_emotePicker()
		end, key = "emote" },
		{ icon = "gear", style = "panel", onClick = function()
			self:_menu()
		end, key = "menu" },
	}
	-- fewer buttons on narrow screens: the scoreboard moves into the menu
	local start = #list - b.count + 1
	for i = start, #list do
		local item = list[i]
		Widgets.iconButton(self.buttons, {
			icon = item.icon,
			style = item.style,
			size = UDim2.fromOffset(b.size, b.size),
			layoutOrder = i,
			onClick = item.onClick,
		})
	end
	self.hasScoresButton = start <= 1
	local _ = m
end

function MatchScreen:_updateRound()
	if not self.roundLabel then
		return
	end
	local round = math.max(1, self.view.round or 1)
	local modeName = if self.mode then self.mode.short else ""
	local event = self.mode and self.mode.isEvent and Progress.currentEvent()
	if event then
		modeName = event.name
	end
	local lengthName = LENGTH_NAME[self.length or ""] or ""
	local mapName = if self.mapDef then self.mapDef.name else ""
	local w = self.L and self.L.info and self.L.info.w or 300
	if w >= 460 then
		self.roundLabel.Text = string.format("Round %d  ·  %s  ·  %s%s  ·  First to %d", round, mapName, modeName, if lengthName ~= "" then ("  ·  " .. lengthName) else "", self.target or 0)
	elseif w >= 300 then
		self.roundLabel.Text = string.format("Round %d  ·  %s  ·  First to %d", round, mapName, self.target or 0)
	elseif w >= 160 then
		self.roundLabel.Text = string.format("Round %d  ·  First to %d", round, self.target or 0)
	else
		self.roundLabel.Text = "Round " .. round
	end
end

function MatchScreen:_seatList()
	local list = {}
	for _, p in self.view.players do
		local info = self.seats[p.seat] or {}
		table.insert(list, {
			seat = p.seat,
			name = p.name,
			username = info.username,
			userId = info.userId,
			isBot = p.isBot,
			team = p.team,
			character = p.character,
			look = info.look,
		})
	end
	table.sort(list, function(a, b)
		return a.seat < b.seat
	end)
	return list
end

function MatchScreen:_destroy()
	if not self.alive then
		return
	end
	self.alive = false
	if self.cancelTarget then
		self.cancelTarget()
	end
	if self.shop then
		self.shop:close()
		self.shop = nil
	end
	if self.closePick then
		self.closePick()
		self.closePick = nil
	end
	self.maid:clean()
	if self.tip then
		self.tip:destroy()
	end
	if self.board then
		self.board:destroy()
	end
	if self.hand then
		self.hand:destroy()
	end
	if active == self then
		active = nil
	end
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

function MatchScreen:_player(seat: number)
	return self.view.players[seat]
end

function MatchScreen:_name(seat: number?): string
	if not seat then
		return "?"
	end
	if seat == self.mySeat then
		return "You"
	end
	local p = self:_player(seat)
	return if p then p.name else "?"
end

-- "<font color=...>Name</font>" for the feed
function MatchScreen:_tag(seat: number?): string
	if not seat then
		return "?"
	end
	local color = Theme.inkOf(Theme.seatColor(seat))
	return string.format('<font color="#%s">%s</font>', toHex(color), self:_name(seat))
end

-- "Pip's" / "your" ("Your" to start a line), in the player's colour
function MatchScreen:_poss(seat: number?, capital: boolean?): string
	if seat ~= nil and seat == self.mySeat then
		local color = Theme.inkOf(Theme.seatColor(seat))
		return string.format('<font color="#%s">%s</font>', toHex(color), if capital then "Your" else "your")
	end
	return self:_tag(seat) .. "'s"
end

-- "s" after a verb for others ("You bonk" / "Pip bonks")
function MatchScreen:_s(seat: number?): string
	return if seat == self.mySeat then "" else "s"
end

function MatchScreen:_seatColor(seat: number): Color3
	return Theme.seatColor(seat)
end

-- Nothing is animating, nothing is pending, and it's my move.
function MatchScreen:_myTurn(): boolean
	local v = self.view
	return v.current == self.mySeat
		and v.phase == "action"
		and not self.playing
		and not self.holding
		and #self.queue == 0
		and not self.busy
		and not self.targeting
end

function MatchScreen:_cardsLeft(): number
	return math.max(0, Rules.CardsPerTurn - (self.view.cardsPlayed or 0))
end

-- absolute screen position -> stage position
function MatchScreen:_toRoot(abs: Vector2): Vector2
	local root = self.root :: Frame
	return (abs - root.AbsolutePosition) / Util.inheritedScale(root, true)
end

function MatchScreen:_pawnSpot(seat: number): Vector2
	return self.board:toStage(self.board:pawnWorld(seat))
end

function MatchScreen:_tileSpot(tile: number): Vector2
	return self.board:toStage(self.board:tileWorld(tile))
end

function MatchScreen:_chipSpot(seat: number): Vector2
	return self.chips:center(seat) or self:_boardCenter()
end

function MatchScreen:_handSpot(index: number?): Vector2
	return self:_toRoot(self.hand:slotCenter(index))
end

function MatchScreen:_boardCenter(): Vector2
	local f = self.L and self.L.focus
	if not f then
		return Vector2.new(Root.vw / 2, Root.vh / 2)
	end
	return Vector2.new(f.x + f.w / 2, f.y + f.h / 2)
end

local function cosmeticOf(info, category: string): string?
	local look = info and info.look
	return look and look[category] or Cosmetics.defaults[category]
end

-- Can `seat` see this hidden trap? (the server only sends what I may see)
function MatchScreen:_trapsAt(tile: number)
	local out = {}
	for _, t in self.view.traps do
		if t.tile == tile then
			table.insert(out, t)
		end
	end
	return out
end

---------------------------------------------------------------------------
-- display state -> HUD
---------------------------------------------------------------------------

-- The dice tray: whose dice, which can be picked, and what each would charge.
function MatchScreen:_refreshDice()
	local v = self.view
	local mine = v.current == self.mySeat
	local dice = v.dice or {}
	local mult = (v.mutator and v.mutator.powerMult) or 1
	local power, back = {}, {}
	for i in dice do
		local _, gain, backDie = self:_moveOption(i)
		power[i] = (gain or 0) * mult
		back[i] = backDie == true
	end
	local hint = nil
	if v.phase == "over" then
		hint = "Game over!"
	elseif not mine then
		hint = self:_name(v.current) .. " is thinking..."
	elseif v.phase == "shop" then
		hint = "Shopping at the Potion Seller"
	elseif v.phase == "pick" then
		hint = "Pick a card!"
	end
	local me = self:_player(self.mySeat)
	self.dock:setDice({
		dice = dice,
		mine = mine,
		owner = if mine then nil else self:_name(v.current),
		frozen = #dice == 1,
		chosen = v.chosen,
		enabled = mine and self:_myTurn() and #dice > 0,
		power = power,
		back = back,
		gold = v.gold,
		hint = hint,
		over = v.phase == "over",
	})
	self.dock:setRecall(mine and me ~= nil and (me.anchor or 0) > 0 and v.phase == "action", self:_myTurn())
end

function MatchScreen:_refresh()
	if not self.chips or not self.L then
		return
	end
	local v = self.view
	self.chips:update(v.players)
	local me = self:_player(self.mySeat)
	local mine = self:_myTurn()
	self:_refreshDice()
	if me then
		local cap = me.powerCap or Characters.cost(me.character or "")
		local full = cap > 0 and (me.power or 0) >= cap
		self.dock:setPower(me.power or 0, cap, {
			usable = mine and full and not v.abilityUsed,
			used = v.abilityUsed == true,
			mine = v.current == self.mySeat,
		})
	end
	self.hand:setSpent(v.current == self.mySeat and v.phase ~= "over" and self:_cardsLeft() <= 0)
	-- a tip that's open says what a click does now (that changes with the turn)
	local tf = self.tipFor
	if tf and self.tip and self.tip.visible then
		self:_showTip(tf.id, tf.index, tf.actions)
	end
	-- the Potion Seller opens on your turn in the shop phase
	if v.phase == "shop" and v.current == self.mySeat and not self.playing and not self.shop then
		self:_openShop()
	elseif self.shop and me then
		self.shop:update(me.coins, v.stock or {}, v.hand or {})
	end
	-- Scavenge: your two cards to pick from (not again while the one you took is on its
	-- way: the phase only moves on once the server's answer has played)
	if v.phase ~= "pick" or v.current ~= self.mySeat then
		self.pickSent = nil
	end
	if v.phase == "pick" and v.current == self.mySeat and v.pick and not self.playing and not self.closePick and not self.pickSent then
		self:_openPick(v.pick)
	end
end

-- One field of one player changed mid-batch (coins, treasures, statuses...).
function MatchScreen:_patch(seat: number, field: string, value: any)
	if value == nil then
		return
	end
	local p = self:_player(seat)
	if p then
		p[field] = value
		self.chips:update(self.view.players)
		if seat == self.mySeat then
			self:_refresh()
		end
	end
end

function MatchScreen:_handCount(seat: number, delta: number)
	local p = self:_player(seat)
	if p then
		p.handCount = math.max(0, (p.handCount or 0) + delta)
		self.chips:update(self.view.players)
	end
end

-- My hand gains a card (at the moment its flight lands).
function MatchScreen:_handAdd(item: string)
	table.insert(self.view.hand, item)
	self.hand:add(item)
	self:_handCount(self.mySeat, 1)
end

-- My hand loses a card (played, placed, used up automatically, given away).
function MatchScreen:_handRemove(item: string)
	local i = table.find(self.view.hand, item)
	if i then
		table.remove(self.view.hand, i)
		self.hand:remove(item)
		self:_handCount(self.mySeat, -1)
	end
end

-- Someone loses a card: my hand if it's me, a count otherwise.
function MatchScreen:_lose(seat: number, item: string?)
	if seat == self.mySeat and item then
		self:_handRemove(item)
	else
		self:_handCount(seat, -1)
	end
end

---------------------------------------------------------------------------
-- event playback
---------------------------------------------------------------------------

--[[
	Wraps what should happen when a flying card or coin arrives. The batch's snapshot
	waits for it (so a card is never added twice), and if a snapshot got there first
	anyway, the state it was going to change is already right and it does nothing.
]]
function MatchScreen:_landing(fn: () -> ()): () -> ()
	self.inflight += 1
	local epoch = self.epoch
	local done = false
	return function()
		if done then
			return
		end
		done = true
		-- a snapshot since then already counted it (and reset the count)
		if self.alive and self.epoch == epoch then
			self.inflight -= 1
			fn()
		end
	end
end

function MatchScreen:_intro(payload)
	local intro = payload.intro or 0
	-- wait for the first layout (the board exists from then on)
	while self.alive and not self.board do
		task.wait()
	end
	if intro > 0 and self.alive then
		self.playing = true
		self:_refresh()
		local t0 = os.clock()
		self.board:buildIntro(intro)
		Overlays.reveal(self.fx, self:_seatList(), intro * 0.85)
		task.wait(math.max(0, intro - (os.clock() - t0)))
	end
	self.holding = false
	self:_kick()
end

function MatchScreen:_enqueue(payload)
	table.insert(self.queue, payload)
	self:_kick()
end

function MatchScreen:_kick()
	if not self.draining and not self.holding and self.alive then
		task.spawn(function()
			self:_drain()
		end)
	end
end

function MatchScreen:_drain()
	if self.draining or self.holding then
		return
	end
	self.draining = true
	self.playing = true
	self:_previewDie(nil)
	self:_refresh()
	while self.alive and #self.queue > 0 do
		local payload = table.remove(self.queue, 1)
		local events = payload.events or {}
		self.speed = self:_catchUp(payload, events)
		if self.speed > 0 then
			local t0 = os.clock()
			local due = 0
			for _, e in events do
				if not self.alive then
					return
				end
				local ok, err = pcall(self._play, self, e)
				if not ok then
					warn("[Trapisque] event '" .. tostring(e.t) .. "' failed to animate: " .. tostring(err))
				end
				-- keep to the batch's schedule: an animation that ran long shortens the next wait
				due += Pacing.duration(e) * self.speed
				local left = t0 + due - os.clock()
				if left > 0 then
					task.wait(left)
				end
			end
			-- let the last cards and coins land before the snapshot settles everything
			local limit = os.clock() + 0.6
			while self.alive and self.inflight > 0 and os.clock() < limit do
				task.wait()
			end
		end
		if self.alive then
			self:_reconcile(payload)
		end
	end
	self.draining = false
	self.playing = false
	if self.alive then
		self:_refresh()
	end
end

--[[
	How fast to play a batch (1 = normal, 0 = skip to the result). The server moves on
	when it thinks a batch has played out (payload.endAt, on the shared server clock),
	so a screen that's behind (lag, a slow device, a minimised window) plays faster, and
	one that's far behind jumps to the result. Your turn never starts late.
]]
function MatchScreen:_catchUp(payload, events): number
	local total = Pacing.total(events)
	local endAt = payload.endAt
	if total <= 0 or type(endAt) ~= "number" or endAt <= 0 then
		return 1
	end
	local now = workspace:GetServerTimeNow()
	local startAt = if type(payload.startAt) == "number" then payload.startAt else endAt - total
	-- a little network delay is fine
	if now - startAt <= 0.35 then
		return 1
	end
	-- far behind: everything queued is old news
	local last = endAt
	for _, p in self.queue do
		if type(p.endAt) == "number" and p.endAt > last then
			last = p.endAt
		end
	end
	if now > last + 4 then
		return 0
	end
	return math.clamp((endAt + 0.35 - now) / total, 0.25, 1)
end

-- The batch's snapshot: the truth. Anything the animations got wrong is fixed here.
function MatchScreen:_reconcile(payload)
	local snap = payload.snapshot
	if not snap then
		return
	end
	self.snap = snap
	self.deadline = payload.deadline or 0
	-- flights still in the air belong to the old state now
	self.epoch += 1
	self.inflight = 0
	local chosen = self.view.chosen
	local sameTurn = self.view.current == snap.current and (self.view.round or 0) == (snap.round or 0)
	self.view = self:_viewFrom(snap, false)
	if sameTurn and snap.phase ~= "action" then
		self.view.chosen = chosen
	end
	if self.board then
		self.board:applySnapshot(snap)
		self.board:setCurrent(if snap.phase ~= "over" then snap.current else nil)
	end
	if self.chips then
		self.chips:setCurrent(if snap.phase ~= "over" then snap.current else nil, self.deadline)
		self.hand:setHand(self.view.hand)
		-- a placement the server never confirmed (it was refused, or lost): undo it
		local pending = self.pendingPlace
		if pending and os.clock() - (pending.at or 0) > 2.5 then
			self.pendingPlace = nil
			if self.board then
				self.board:previewTile(nil, nil, nil)
			end
		end
		if not self.targeting and not self.pendingPlace then
			self.hand:setHeld(nil)
		end
	end
	self:_updateRound()
	self:_updateMood()
	if self.shop and not (snap.phase == "shop" and snap.current == self.mySeat) then
		self.shop:close()
		self.shop = nil
	end
	if self.closePick and not (snap.phase == "pick" and snap.current == self.mySeat) then
		self.closePick()
		self.closePick = nil
	end
	self:_refresh()
end

-- Plays one event; may yield (dice, hops, spins). The caller pads to Pacing time.
function MatchScreen:_play(e)
	local speed = self.speed
	local t = e.t
	local board = self.board
	local feed = self.feed
	local v = self.view

	if t == "setup" then
		-- one of each character per match: say so if someone else got yours first
		for _, sp in e.players or {} do
			if sp.seat == self.mySeat and sp.wanted and sp.wanted ~= sp.character then
				local wanted, got = Characters.get(sp.wanted), Characters.get(sp.character or "")
				if wanted and got then
					Widgets.toast(string.format("Someone else picked the %s first, so you're the %s this match!", wanted.name, got.name), "info")
				end
			end
		end
		return
	elseif t == "deal" then
		local items = e.items or {}
		local n = if e.items then #items else (e.count or 0)
		feed:add(self:_tag(e.p) .. " start" .. self:_s(e.p) .. " with " .. n .. " card" .. (if n == 1 then "" else "s"), nil, "book", C.sky)
		for i = 1, n do
			local item = if e.p == self.mySeat then items[i] else nil
			local land = self:_landing(function()
				if item then
					self:_handAdd(item)
				else
					self:_handCount(e.p, 1)
				end
			end)
			task.delay((i - 1) * 0.15 * speed, function()
				if not self.alive then
					land()
				elseif item then
					Overlays.flyCard(self.fly, item, self:_boardCenter(), self:_handSpot(nil), speed, land)
				else
					Overlays.flyIcon(self.fly, "book", C.sky, self:_boardCenter(), self:_chipSpot(e.p), speed, land)
				end
			end)
		end
	elseif t == "turn" then
		v.round = e.round
		v.current = e.p
		v.phase = "action"
		v.abilityUsed = false
		v.cardsPlayed = 0
		v.boost = nil
		v.dice = {}
		v.gold = nil
		v.chosen = nil
		self:_updateRound()
		board:setCurrent(e.p)
		self.chips:setCurrent(e.p, nil)
		self.dock:clearSelection()
		local mine = e.p == self.mySeat
		Overlays.turnBanner(self.fx, if mine then "Your turn!" else (self:_name(e.p) .. "'s turn"), self:_seatColor(e.p), mine, speed)
		local p = self:_player(e.p)
		if p then
			board:follow(p.tile)
		end
		self:_refresh()
	elseif t == "skip" then
		local p = self:_player(e.p)
		if p then
			p.skip = math.max(0, (p.skip or 0) - 1)
			board:setStatus(e.p, "skip", p.skip > 0)
		end
		feed:add(self:_tag(e.p) .. " skip" .. self:_s(e.p) .. " a turn (snared)", nil, "zzz", C.grape)
		board:floatText(self:_pawnWorld(e.p), "ZZZ... SKIP!", C.textSoft)
	elseif t == "burn" then
		self:_patch(e.p, "burning", e.left)
		board:floatText(self:_pawnWorld(e.p), "HOT HOT HOT!", C.orange)
	elseif t == "roll" then
		v.dice = copy(e.dice)
		v.gold = e.gold
		v.chosen = nil
		self:_refreshDice()
		self.dock:rollDice(e.dice, e.frozen == true, speed)
		if e.reroll then
			feed:add(self:_tag(e.p) .. " rolled again!", nil, "clover", C.lime)
		end
		if e.underdog and not e.reroll then
			-- clearly last: an extra die to pick from
			board:floatText(self:_pawnWorld(e.p) + Vector2.new(0, -0.45 * BoardView.UNIT), "UNDERDOG: GOLD DIE!", C.sun, 20)
			feed:add(self:_tag(e.p) .. (if e.p == self.mySeat then " are" else " is") .. " the underdog: an extra gold die!", nil, "dice", C.sun)
		end
		if #e.dice == 2 and e.dice[1] == e.dice[2] then
			board:floatText(self:_pawnWorld(e.p), "DOUBLES!", C.sun)
		end
		self:_refreshDice()
	elseif t == "choose" then
		v.chosen = e.die
		self.dock:choose(e.die)
		self:_refreshDice()
		self:_previewDie(nil)
		local how = if e.die == "sum" then ("the total: " .. e.move) else tostring(e.move)
		feed:add(self:_tag(e.p) .. " move" .. self:_s(e.p) .. " " .. how .. (if e.back then " backwards!" else ""), nil, "dice", C.sun)
	elseif t == "power" then
		local p = self:_player(e.p)
		if p then
			p.power = e.power
		end
		if (e.gain or 0) > 0 then
			board:floatText(self:_pawnWorld(e.p) + Vector2.new(0, -0.3 * BoardView.UNIT), "+" .. e.gain .. " POWER", C.sun, 20)
		end
		self.chips:update(v.players)
		if e.p == self.mySeat then
			self:_refresh()
			if e.full then
				local me = self:_player(self.mySeat)
				local cdef = Characters.get(me and me.character or "")
				feed:add("Power full! " .. (if cdef and cdef.ability then (cdef.ability.name .. " is ready.") else ""), C.sun, "bolt", C.sun)
				Sound.play("magic", 1.3)
			end
		end
	elseif t == "move" then
		local info = self.seats[e.p]
		local p = self:_player(e.p)
		if p and #e.path > 0 then
			p.tile = e.path[#e.path]
		end
		-- (my trail, used to preview a Moonwalk, comes with each batch's snapshot)
		board:hop(e.p, e.path, e.kind, cosmeticOf(info, "trail"), speed)
	elseif t == "spin" then
		local segments = Overlays.wheelSegments(e.wheel, self.mapDef)
		Overlays.spin(self.fx, e.wheel, segments, e.index, speed)
		local def = Items.get(e.result)
		feed:add(self:_tag(e.p) .. " spun the " .. (WHEEL_NAME[e.wheel] or "") .. " wheel: " .. (if e.result == "coin" then "a coin" elseif def then def.name else "?"), nil, "token_" .. (e.wheel or "trap"), Theme.Category[e.wheel] or C.sun)
	elseif t == "gain" then
		if e.p == self.mySeat then
			Overlays.flyCard(self.fly, e.item, self:_pawnSpot(e.p), self:_handSpot(nil), speed, self:_landing(function()
				self:_handAdd(e.item)
			end))
		else
			Overlays.flyIcon(self.fly, "book", C.sky, self:_pawnSpot(e.p), self:_chipSpot(e.p), speed, self:_landing(function()
				self:_handCount(e.p, 1)
			end))
		end
	elseif t == "handFull" then
		board:floatText(self:_pawnWorld(e.p), "HAND FULL", C.bad)
		feed:add(self:_poss(e.p, true) .. " hand is full (" .. Rules.HandLimit .. " cards)")
	elseif t == "coin" then
		Sound.play("coin")
		board:floatText(self:_pawnWorld(e.p), "+" .. tostring(e.gain or 1) .. " COIN", C.sun)
		Overlays.flyIcon(self.fly, "coin", C.sun, self:_pawnSpot(e.p), self:_chipSpot(e.p), speed, self:_landing(function()
			self:_patch(e.p, "coins", e.coins)
		end))
	elseif t == "tokenMove" then
		v.tokens[e.from] = nil
		v.tokens[e.to] = e.token
		board:moveToken(e.from, e.to, e.token)
	elseif t == "trigger" then
		Effects.trap(board, e.item, e.tile)
		local def = Items.get(e.item)
		local name = if def then def.name else "trap"
		if e.hidden then
			-- a hidden trap is used up when it goes off
			self:_removeTrap(e.tile, e.item)
			local what = if e.owner and e.owner > 0 then (self:_poss(e.owner) .. " hidden " .. name) else aName("hidden " .. name)
			feed:add(self:_tag(e.p) .. " stepped on " .. what .. "!", nil, e.item, C.trap)
		elseif e.item ~= "wall" then
			feed:add(self:_tag(e.p) .. " hit " .. (if e.owner and e.owner > 0 then (self:_poss(e.owner) .. " " .. name) else aName(name)), nil, e.item, Theme.Category[if BoardView.isNeutral(e.item) then "neutral" else "trap"])
		end
	elseif t == "gotcha" then
		Effects.gotcha(board, e.p, e.target)
		self.chips:flash(e.p, C.coral)
		self.chips:shake(e.target)
		local def = Items.get(e.item)
		feed:add("GOTCHA! " .. self:_tag(e.p) .. " caught " .. self:_tag(e.target) .. " with " .. aName(if def then def.name else "trap") .. " (+1 coin, +" .. Rules.PowerPerGotcha .. " Power)", C.sun, e.item, C.trap)
	elseif t == "bounty" then
		Effects.bounty(board, e.p)
	elseif t == "shield" then
		self:_lose(e.p, "shield")
		Effects.shield(board, e.p)
		local what = if e.item == "bonk" then "a bonk" elseif e.item == "wall" then "a Wall" else aName((Items.get(e.item) or {}).name or "trap")
		feed:add(self:_tag(e.p) .. " blocked " .. what .. " with a Shield", nil, "shield", C.assist)
	elseif t == "bonk" then
		Effects.bonk(board, e.p, e.target)
		self.chips:shake(e.target)
		feed:add("BOING! " .. self:_tag(e.p) .. " bonked " .. self:_tag(e.target) .. " back " .. ((v.mutator and v.mutator.bonkBack) or Rules.BonkBack) .. "!", C.sun, "star", C.sun)
	elseif t == "death" then
		Effects.death(board, e.p)
		self.chips:shake(e.p)
		local why = DEATH_TEXT[e.cause] or "was knocked out"
		feed:add(self:_tag(e.p) .. " " .. why .. (if e.by and e.by ~= e.p then (" by " .. self:_tag(e.by)) else "") .. " and went back to the Start!", C.badSoft, "skull", C.bad)
	elseif t == "phoenix" then
		self:_lose(e.p, "phoenix_potion")
		Effects.phoenix(board, e.p)
		feed:add(self:_tag(e.p) .. " rose from the ashes! (Phoenix Potion)", C.sun, "phoenix_potion", C.potion)
	elseif t == "treasure" then
		Effects.treasure(board, self.board.board.treasure, e.p)
		local who = self:_name(e.p)
		local goal = if self.isTeam then (self.target or 0) * self:_teamSize(e.p) else (self.target or 0)
		local have = if self.isTeam then (e.team or e.treasures) else e.treasures
		local sub = tostring(have) .. " / " .. tostring(goal)
		Overlays.shout(self.fx, if e.p == self.mySeat then "TREASURE!" else (who .. " found a treasure!"), C.sun, speed, sub)
		feed:add(self:_tag(e.p) .. " found a treasure! (" .. sub .. ")", C.sun, "chest", C.sun)
		self:_patch(e.p, "treasures", e.treasures)
		self.chips:flash(e.p, C.sun)
		-- the music steps back so the moment lands (and turns tense if this was a big one)
		Sound.duck(0.35, 1.8)
		self:_updateMood()
	elseif t == "gameover" then
		v.phase = "over"
		local winners = {}
		for _, p in v.players do
			if p.team == e.team then
				table.insert(winners, self:_name(p.seat))
			end
		end
		local text = if self.isTeam then ((Theme.TeamName[e.team] or "A team") .. " wins!") else (table.concat(winners, " & ") .. (if #winners == 1 and winners[1] == "You" then " win!" else " wins!"))
		Overlays.shout(self.fx, text, C.sun, speed * 1.4, if e.reason == "rounds" then "Out of rounds" else nil)
		local me = self:_player(self.mySeat)
		Sound.play(if me and me.team == e.team then "win" else "lose")
		for _, p in v.players do
			board:setMood(p.seat, if p.team == e.team then "happy" else "sad", 6)
		end
		-- the music bows out under the fanfare
		Sound.duck(0.2, 2.5)
		task.delay(1.2, function()
			Sound.music(nil)
		end)
		self:_refresh()
	elseif t == "natural" then
		Effects.natural(board, e.kind, e.tile, e.drag)
		if e.drag then
			feed:add(self:_tag(e.p) .. " waded through slime (-" .. e.drag .. " steps)", nil, "slime_trap", C.natural)
		else
			feed:add(self:_tag(e.p) .. " " .. (NATURAL_TEXT[e.kind] or "hit a hazard"), nil, ({ river = "river_trap", gate = "lock", slime = "slime_trap" })[e.kind], C.natural)
		end
	elseif t == "blocked" then
		Effects.blocked(board, e.tile)
		feed:add("A Wall stops " .. self:_tag(e.p), nil, "wall", C.trap)
	elseif t == "grog" then
		local p = self:_player(e.p)
		Effects.grogRoll(board, if p then p.tile else 1, e.roll, e.survived)
		feed:add(self:_tag(e.p) .. (if e.survived then (" outran the Grog with a " .. e.roll .. "!") else (" rolled " .. e.roll .. "... the Grog wins")), nil, "grog", C.trap)
	elseif t == "snared" then
		local p = self:_player(e.p)
		if p then
			p.skip = (p.skip or 0) + 1
			board:setStatus(e.p, "skip", true)
			self.chips:update(v.players)
		end
		Effects.snared(board, e.p)
		feed:add(self:_tag(e.p) .. " is snared and will skip a turn", nil, "snare", C.trap)
	elseif t == "drop" then
		self:_lose(e.p, e.item)
		Effects.drop(board, e.p)
		feed:add(self:_tag(e.p) .. " slipped and dropped a card", nil, "banana", C.trap)
	elseif t == "status" then
		local on = e.on ~= false
		self:_patch(e.p, e.status, if on then (e.turns or 1) else 0)
		board:setStatus(e.p, e.status, on)
		if on then
			Effects.status(board, e.p, e.status)
			local turns = e.turns or 1
			feed:add(self:_tag(e.p) .. (if e.status == "burning" then " is burning" else " is frozen") .. " (" .. turns .. " turn" .. (if turns == 1 then "" else "s") .. ")", nil, if e.status == "burning" then "flame" else "snowflake", if e.status == "burning" then C.orange else C.sky)
		end
	elseif t == "immune" then
		board:floatText(self:_pawnWorld(e.p), "IMMUNE!", C.info)
	elseif t == "place" then
		self:_playPlace(e, speed)
	elseif t == "hide" then
		-- someone else hid a trap: you only see a puff of smoke
		self:_lose(e.p, nil)
		v.cardsPlayed = (v.cardsPlayed or 0) + (if e.p == v.current then 1 else 0)
		Effects.hide(board, e.p)
		Overlays.flyIcon(self.fly, "book", C.trap, self:_chipSpot(e.p), self:_pawnSpot(e.p), speed)
		feed:add(self:_tag(e.p) .. " hid a trap somewhere near them...", nil, "token_trap", C.trap)
	elseif t == "removed" then
		if v.placed[e.tile] and (e.item == nil or v.placed[e.tile].item == e.item) then
			v.placed[e.tile] = nil
			board:removePlaced(e.tile)
		else
			self:_removeTrap(e.tile, e.item)
		end
		if e.reason == "replaced" then
			feed:add("An old trap crumbled away (too many out)", C.textSoft, e.item, C.trap)
		end
	elseif t == "play" then
		self:_playCardEvent(e, speed)
	elseif t == "useCard" then
		local def = Items.get(e.item)
		self:_lose(e.p, e.item)
		local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_chipSpot(e.p)
		Overlays.flyCard(self.fly, e.item, from, self:_pawnSpot(e.p), speed)
		feed:add(self:_tag(e.p) .. " used " .. (if def then def.name else "a card") .. (if e.why == "shortcut" then " on a shortcut" else ""), nil, e.item, Theme.Category[def and def.category or "assist"])
	elseif t == "xray" then
		-- my X-Ray: every hidden trap shows up
		self:_lose(e.p, "xray_potion")
		v.cardsPlayed = (v.cardsPlayed or 0) + 1
		local tiles = {}
		for _, tr in e.traps or {} do
			table.insert(v.traps, { tile = tr.tile, item = tr.item, owner = tr.owner })
			board:addTrap(tr.tile, { item = tr.item, owner = tr.owner })
			table.insert(tiles, tr.tile)
		end
		Effects.xray(board, e.p, tiles)
		feed:add("X-Ray! You can see " .. #tiles .. " hidden trap" .. (if #tiles == 1 then "" else "s") .. " now", C.mint, "xray_potion", C.potion)
	elseif t == "handSwap" then
		self.chips:flash(e.a, C.neutral)
		self.chips:flash(e.b, C.neutral)
		local a, b = self:_player(e.a), self:_player(e.b)
		if e.handA or e.handB then
			-- I'm one of the two: my new hand is the other one's old one
			local mine = if e.a == self.mySeat then e.handA else e.handB
			if a then
				a.handCount = #(e.handA or {})
			end
			if b then
				b.handCount = #(e.handB or {})
			end
			if mine then
				v.hand = copy(mine)
				self.hand:setHand(v.hand)
			end
		else
			if a and e.countA then
				a.handCount = e.countA
			end
			if b and e.countB then
				b.handCount = e.countB
			end
		end
		self.chips:update(v.players)
		feed:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped hands!", nil, "jeopardy_potion", C.potion)
	elseif t == "give" then
		self:_lose(e.p, e.item)
		if e.p == v.current then
			v.cardsPlayed = (v.cardsPlayed or 0) + 1
		end
		Overlays.flyIcon(self.fly, "book", C.sky, self:_chipSpot(e.p), self:_chipSpot(e.target), speed, self:_landing(function()
			if e.target == self.mySeat then
				self:_handAdd(e.item)
			else
				self:_handCount(e.target, 1)
			end
		end))
		feed:add(self:_tag(e.p) .. " gave a card to " .. self:_tag(e.target), nil, "plus", C.good)
	elseif t == "recall" then
		self:_patch(e.p, "anchor", 0)
		Effects.recall(board, e.p)
		feed:add(self:_tag(e.p) .. " traveled back in time", nil, "time_potion", C.potion)
	elseif t == "offer" then
		if e.p == self.mySeat and e.options then
			v.phase = "pick"
			v.pick = copy(e.options)
		else
			feed:add(self:_tag(e.p) .. " is scavenging for a trap...", nil, "trapper", Theme.Character.trapper)
		end
	elseif t == "picked" then
		v.pick = nil
		if v.phase == "pick" then
			v.phase = "action"
		end
	elseif t == "ability" then
		local p = self:_player(e.p)
		local cdef = Characters.get(p and p.character or "")
		local ab = cdef and cdef.ability
		if p then
			p.power = 0
		end
		if e.p == v.current then
			v.abilityUsed = true
		end
		Overlays.abilityBanner(self.fx, p and p.character or "mage", ab and ab.name or "Ability", self:_name(e.p), speed)
		if e.ability ~= "blizzard" and e.ability ~= "blast" then
			Effects.ability(board, e.ability, e.p, e.target)
		end
		local target = if e.target then (" on " .. self:_tag(e.target)) else ""
		local option = if e.option == "fwd" then " (forward)" elseif e.option == "back" then " (back)" else ""
		feed:add(self:_tag(e.p) .. " used " .. (if ab then ab.name else "an ability") .. target .. option, nil, p and p.character or "star", Theme.Character[p and p.character or ""] or C.sun)
		self:_refresh()
	elseif t == "blizzard" then
		Effects.blizzard(board, e.p, e.targets or {})
	elseif t == "embers" then
		for _, tile in e.tiles or {} do
			v.embers[tile] = e.p
		end
		board:setEmbers(table.clone(v.embers))
		Effects.blast(board, e.p)
		Effects.embers(board, e.tiles or {})
	elseif t == "embersOut" then
		for _, tile in e.tiles or {} do
			v.embers[tile] = nil
		end
		board:setEmbers(table.clone(v.embers))
	elseif t == "scorch" then
		Effects.scorch(board, e.p)
	elseif t == "grow" then
		v.natural[e.tile] = e.kind
		board:setNatural(e.tile, e.kind)
		Effects.grow(board, e.tile)
		feed:add(self:_tag(e.p) .. " grew a " .. tostring(e.kind) .. " out of the ground!", nil, "naturalist", C.lime)
	elseif t == "wither" then
		v.natural[e.tile] = nil
		board:setNatural(e.tile, nil)
	elseif t == "swap" then
		local a, b = self:_player(e.a), self:_player(e.b)
		if a then
			a.tile = e.ta
		end
		if b then
			b.tile = e.tb
		end
		feed:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped places", nil, "warper", C.neutral)
		board:swap(e.a, e.b, e.ta, e.tb)
	elseif t == "fizzle" then
		board:floatText(board:tileWorld(e.tile), "FIZZLE", C.textSoft)
	elseif t == "buy" then
		local def = Items.get(e.item)
		self:_patch(e.p, "coins", e.coins)
		if v.stock[e.item] then
			v.stock[e.item] = math.max(0, v.stock[e.item] - 1)
		end
		if e.p == self.mySeat then
			self:_handAdd(e.item)
			if self.shop then
				self.shop:bought(e.item)
			end
		else
			self:_handCount(e.p, 1)
		end
		feed:add(self:_tag(e.p) .. " bought " .. (if def then def.name else "a potion"), nil, e.item, C.potion)
		self:_refresh()
	elseif t == "shop" then
		v.phase = "shop"
		feed:add(self:_tag(e.p) .. " visit" .. self:_s(e.p) .. " the Potion Seller", nil, "token_potion", C.potion)
	elseif t == "shopClose" then
		v.phase = "action"
		if self.shop and e.p == self.mySeat then
			self.shop:close()
			self.shop = nil
		end
	elseif t == "left" then
		local p = self:_player(e.p)
		if p then
			p.isBot = true
			p.name = e.name or p.name
		end
		feed:add((e.name or "A player") .. " left. A bot takes over.", nil, "exit", C.textFaint)
	end
end

function MatchScreen:_teamSize(seat: number): number
	local p = self:_player(seat)
	if not p then
		return 1
	end
	local n = 0
	for _, o in self.view.players do
		if o.team == p.team then
			n += 1
		end
	end
	return math.max(1, n)
end

-- A hidden trap I could see is gone (it went off, or was replaced).
function MatchScreen:_removeTrap(tile: number, item: string?)
	local list = self.view.traps
	for i, tr in list do
		if tr.tile == tile and (item == nil or tr.item == item) then
			table.remove(list, i)
			break
		end
	end
	self.board:removeTrap(tile, item)
end

--[[
	A card placed on the board: it arcs over from its owner and is slapped onto the
	tile (yours is already there: you stamped it down yourself), the tile changes look
	with a thud, a ring and a little jolt. A hidden trap only shows for its team (and
	the Overseer); everyone else gets a "hide" event instead. The snapshot that follows
	confirms it.
]]
function MatchScreen:_playPlace(e, speed: number)
	local def = Items.get(e.item)
	local v = self.view
	local mine = e.p == self.mySeat
	local pending = self.pendingPlace
	local stamped = mine and pending ~= nil and pending.tile == e.tile and pending.item == e.item
	if mine then
		self.pendingPlace = nil
		self.board:previewTile(nil, nil, nil)
	end
	self:_lose(e.p, e.item)
	if e.p == v.current then
		v.cardsPlayed = (v.cardsPlayed or 0) + 1
	end
	if mine then
		self.hand:setHeld(nil)
	end
	local board = self.board
	local color = Theme.Category[def and def.category or "trap"] or C.sun
	local land = self:_landing(function()
		if e.hidden then
			local trap = { tile = e.tile, item = e.item, owner = e.p, team = self:_player(e.p) and self:_player(e.p).team }
			table.insert(v.traps, trap)
			board:addTrap(e.tile, trap)
		else
			local entry = { tile = e.tile, item = e.item, owner = e.p, dir = e.dir, tiles = nil }
			if e.item == "conveyor" then
				entry.tiles = board.board:span(e.tile, Rules.ConveyorLength)
			end
			v.placed[e.tile] = entry
			-- yours already hit the board (and its look was there): it just settles in
			board:placeItem(entry, if stamped then "settle" else true)
		end
		if not stamped then
			Effects.place(board, e.item, e.tile, color)
		end
	end)
	if stamped then
		land()
	else
		local from = if mine then self:_handSpot(nil) else self:_chipSpot(e.p)
		Overlays.flyCard(self.fly, e.item, from, self:_tileSpot(e.tile), speed, land, { slam = true })
	end
	local verb = if e.hidden then " hid " else " placed "
	self.feed:add(self:_tag(e.p) .. verb .. (if def then aName(def.name) else "a card") .. (if e.hidden then " (only your team sees it)" else ""), nil, e.item, Theme.Category[def and def.category or "trap"])
end

-- A card that's played (not placed): it flies from the hand to its player's pawn.
function MatchScreen:_playCardEvent(e, speed: number)
	local v = self.view
	local def = Items.get(e.item)
	self:_lose(e.p, e.item)
	if e.p == v.current then
		v.cardsPlayed = (v.cardsPlayed or 0) + 1
	end
	if def and def.use == "boost" then
		v.boost = e.item
	end
	if e.item == "time_potion" then
		self:_patch(e.p, "anchor", e.tile or 0)
	end
	local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_chipSpot(e.p)
	Overlays.flyCard(self.fly, e.item, from, self:_pawnSpot(e.target or e.p), speed)
	Sound.play("card")
	local extra = ""
	if e.target and e.target ~= e.p then
		extra = " on " .. self:_tag(e.target)
	elseif e.target then
		extra = " on themselves"
	end
	if e.steps then
		extra ..= " (" .. (if e.steps > 0 then "+" else "") .. e.steps .. ")"
	end
	self.feed:add(self:_tag(e.p) .. " played " .. (if def then def.name else "a card") .. extra, nil, e.item, Theme.Category[def and def.category or "neutral"])
	if e.p == self.mySeat then
		self:_refresh()
	end
end

function MatchScreen:_pawnWorld(seat: number): Vector2
	return self.board:pawnWorld(seat)
end

---------------------------------------------------------------------------
-- your move: pick a die
---------------------------------------------------------------------------

-- Steps, Power and backwards-or-not for die `key` (1, 2, 3 or "sum"), like Engine:moveOption.
function MatchScreen:_moveOption(key: any): (number?, number?, boolean?)
	return Engine.dieOption(self.view.dice or {}, key, self.view.gold)
end

-- The walk a die would make for me right now (nil if it can't).
function MatchScreen:_planFor(key: any)
	local v = self.view
	local me = self:_player(self.mySeat)
	if not me then
		return nil
	end
	local m, _, backDie = self:_moveOption(key)
	if not m then
		return nil
	end
	local steps, back = Engine.boosted(m :: number, v.boost)
	if back or backDie then
		return Engine.backPlan({ trail = v.trail }, steps), steps, true
	end
	local state = { board = self.board.board, natural = v.natural, placed = v.placed }
	local walker = { tile = me.tile, hand = v.hand, character = me.character }
	return Engine.walkPlan(state, walker, steps), steps, false
end

--[[
	What the landing tile of a plan holds for me, as little tags: a bonk, a token, a
	shop, a hazard that stops me, a trap I know is there, a board piece, the treasure...
]]
function MatchScreen:_outcome(plan): { any }
	local v = self.view
	local me = self:_player(self.mySeat)
	local tags = {}
	if not plan or not me then
		return tags
	end
	local tile = plan.tile
	local board = self.board.board
	local function add(text: string, color: Color3)
		table.insert(tags, { text = text, color = color })
	end
	if plan.result == "treasure" then
		add("TREASURE!", C.sun)
		return tags
	end
	if plan.result == "blocked" then
		add("WALL!", C.coral)
	elseif plan.result == "stopped" then
		add(string.upper(plan.hazard or "hazard") .. " STOPS YOU", C.sky)
	end
	if plan.slowed then
		add("SLIME -" .. tostring(Rules.SlimeDrag or 0), C.slime)
	end
	for _, u in plan.uses or {} do
		local def = Items.get(u.item)
		add("USES " .. string.upper(if def then def.name else u.item), C.mint)
	end
	if tile == board.start then
		return tags
	end
	-- rivals there get bonked
	for _, p in v.players do
		if p.seat ~= self.mySeat and p.tile == tile and p.team ~= me.team then
			add("BONK " .. string.upper(p.name) .. "!", C.sun)
		end
	end
	for _, tr in v.traps do
		if tr.tile == tile and (tr.public or tr.team ~= me.team) then
			add("TRAP!", C.coral)
			break
		end
	end
	local embers = v.embers[tile]
	if embers and embers ~= self.mySeat then
		add("HOT!", C.orange)
	end
	local piece = v.placed[tile]
	if piece then
		local names = { teleporter = "TELEPORT", trampoline = "BOING +" .. Rules.TrampolineForward, spore_warper = "SWAP!", wall = "WALL" }
		local def = Items.get(piece.item)
		add(names[piece.item] or string.upper(if def then def.name else piece.item), C.grape)
	end
	local token = v.tokens[tile]
	if token == "potion" then
		add("SHOP", C.orange)
	elseif token then
		add("+CARD", Theme.Category[token] or C.lime)
	end
	return tags
end

-- Shows (or with nil, hides) where die `key` would take me.
function MatchScreen:_previewDie(key: any)
	if not self.board then
		return
	end
	if key == nil or not self:_myTurn() then
		self.board:showPath(nil)
		return
	end
	local plan = self:_planFor(key)
	if not plan or #plan.path == 0 then
		self.board:showPath(nil)
		return
	end
	local me = self:_player(self.mySeat)
	local tags = self:_outcome(plan)
	local _, gain, backDie = self:_moveOption(key)
	local mult = (self.view.mutator and self.view.mutator.powerMult) or 1
	if backDie then
		table.insert(tags, 1, { text = "BACKWARDS", color = C.coral })
	end
	if (gain or 0) > 0 then
		table.insert(tags, { text = "+" .. tostring((gain :: number) * mult) .. " POWER", color = C.sun })
	end
	self.board:showPath(plan.path, { character = me and me.character, color = C.sun, badges = tags })
	self.board:follow(plan.tile)
end

function MatchScreen:_move(key: any)
	if not self:_myTurn() then
		return
	end
	if not self:_moveOption(key) then
		return
	end
	self:_previewDie(nil)
	self:_closeTip()
	Sound.play("click")
	self:_cmd({ type = "move", die = key })
end

function MatchScreen:_recall()
	if not self:_myTurn() then
		return
	end
	self:_previewDie(nil)
	self:_cmd({ type = "recall" })
end

function MatchScreen:_cmd(cmd): boolean
	if self.busy then
		return false
	end
	self.busy = true
	self:_refresh()
	local ok, err = Net.request("match.cmd", { cmd = cmd })
	self.busy = false
	if not ok then
		Widgets.toast(tostring(err), "error")
	end
	self:_refresh()
	return ok
end

function MatchScreen:_key(key: Enum.KeyCode)
	if key == Enum.KeyCode.Escape then
		if self.cancelTarget then
			self.cancelTarget()
		end
		return
	end
	if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
		if self.confirmTarget then
			self.confirmTarget()
		end
		return
	end
	if key == Enum.KeyCode.F then
		self.board:fit()
		return
	end
	if key == Enum.KeyCode.Equals or key == Enum.KeyCode.KeypadPlus then
		self.board:zoomBy(1.25)
		return
	end
	if key == Enum.KeyCode.Minus or key == Enum.KeyCode.KeypadMinus then
		self.board:zoomBy(1 / 1.25)
		return
	end
	if key == Enum.KeyCode.Tab then
		self:_scoreboard()
		return
	end
	if self.targeting then
		return
	end
	local die = DIE_KEYS[key]
	if die then
		local dice = self.view.dice or {}
		-- E is the third die, or the TOTAL of doubles
		if die == 3 and #dice == 2 and dice[1] == dice[2] then
			self:_move("sum")
		elseif dice[die] then
			self:_move(die)
		end
		return
	end
	if key == Enum.KeyCode.Space then
		self:_abilityClicked()
		return
	end
	local numbers = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
		[Enum.KeyCode.Nine] = 9,
	}
	local n = numbers[key]
	local ids = self.hand:ids()
	if n and ids[n] then
		self:_cardClicked(ids[n], n)
	end
end

--[[
	A hint strip across the top of the board ("Pick a tile for Spike") with Cancel
	(Esc works too) and, on touch screens, a Place button once a tile is chosen.
	Returns close() and setConfirm(text?, onConfirm?).
]]
function MatchScreen:_hint(text: string, onCancel: () -> ())
	local strip = Util.new("Frame", {
		Name = "Hint",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		ZIndex = 70,
		Parent = self.root,
	})
	Util.corner(strip, 12)
	Util.stroke(strip, C.line, 3)
	local label = Widgets.label(strip, {
		text = text,
		font = "heavy",
		size = 16,
		color = C.text,
		wrap = true,
		z = 71,
	})
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		self.hintLayout = nil
		self.confirmTarget = nil
		strip:Destroy()
	end
	local cancel = Widgets.button(strip, {
		text = "CANCEL",
		style = "red",
		textSize = 15,
		z = 72,
		onClick = function()
			close()
			onCancel()
		end,
	})
	local confirm = Widgets.button(strip, {
		text = "PLACE",
		style = "green",
		textSize = 15,
		z = 72,
	})
	confirm.root.Visible = false
	local function layout()
		local r = self.L and self.L.hint or Layout.rect(0, 0, 400, 48)
		local h = math.max(44, r.h)
		strip.Position = UDim2.fromOffset(r.x, r.y)
		strip.Size = UDim2.fromOffset(r.w, h)
		local bw = if r.w < 420 then 86 else 110
		local buttons = if confirm.root.Visible then 2 else 1
		cancel.root.AnchorPoint = Vector2.new(1, 0.5)
		cancel.root.Position = UDim2.new(1, -6, 0.5, 0)
		cancel.root.Size = UDim2.fromOffset(bw, h - 12)
		confirm.root.AnchorPoint = Vector2.new(1, 0.5)
		confirm.root.Position = UDim2.new(1, -12 - bw, 0.5, 0)
		confirm.root.Size = UDim2.fromOffset(bw, h - 12)
		label.Position = UDim2.fromOffset(12, 0)
		label.Size = UDim2.new(1, -(24 + buttons * (bw + 6)), 1, 0)
		label.TextSize = if r.w < 420 then 13 else 16
	end
	self.hintLayout = layout
	layout()
	Util.popIn(strip, 0.25, 0.7)
	local function setConfirm(newText: string?, onConfirm: (() -> ())?, confirmText: string?)
		if newText then
			label.Text = newText
		end
		confirm.root.Visible = onConfirm ~= nil
		if onConfirm then
			confirm:setOnClick(onConfirm)
			confirm:setText(confirmText or "PLACE")
		end
		self.confirmTarget = onConfirm
		layout()
	end
	return close, setConfirm
end

-- My placement context (how far from me I may place), as the engine sees it.
function MatchScreen:_placeContext()
	local me = self:_player(self.mySeat)
	if not me then
		return {}
	end
	return Engine.placeContext({ tile = me.tile, character = me.character, index = self.mySeat, team = me.team }, self.view.mutator)
end

--[[
	Placing a card. It comes up out of your hand and follows the pointer (or the finger
	dragging it) over the board; the tiles the rules allow glow (traps hide within a few
	tiles of you), and the one under the card shows what it will look like. Click (or
	let go) over a glowing tile and the card is stamped onto it. Esc, right-click or
	CANCEL put it back in your hand. On touch screens without a drag: tap a tile to see
	it there, then PLACE.

		opts.index = the card's place in your hand (where it flies from / back to)
		opts.drag  = the screen point a drag started at (the hand calls dragging.point /
		             dragging.release as the finger moves)
	Returns false if there's nowhere to put it.
]]
function MatchScreen:_placeFlow(itemId: string, opts: { [string]: any }?): boolean
	if self.targeting then
		return false -- already placing or picking something
	end
	local o = opts or {}
	local def = Items.get(itemId)
	local hidden = def.hidden == true
	local boardData = self.board.board
	local layers = Engine.layersFromSnapshot(boardData, self:_viewAsSnap())
	local ctx = self:_placeContext()
	local valid = {}
	for id in boardData.tiles do
		if Engine.checkPlacement(boardData, layers, itemId, id, "fwd", ctx) then
			table.insert(valid, id)
		end
	end
	if #valid == 0 then
		Widgets.toast("There's nowhere to put that right now.", "error")
		return false
	end
	table.sort(valid)
	local color = Theme.Category[def.category] or C.sun
	local touch = Root.metrics.touch
	local index = o.index
	self.targeting = true
	self:_previewDie(nil)
	self:_closeTip()
	self:_refresh()

	-- the card itself, picked up out of the hand
	local startPos = if index then self:_handSpot(index) else self:_boardCenter()
	local cardW = if self.L and self.L.hand then self.L.hand.card.w else 90
	local held = Overlays.heldCard(self.fly, itemId, startPos, cardW)
	if index then
		self.hand:setHeld(index)
	end
	Sound.play("card")
	local hovered: number? = nil
	local function point(stage: Vector2)
		held:moveTo(stage)
		local tile = self.board:tileAt(stage, valid)
		if tile ~= hovered then
			hovered = tile
			self.board:previewTile(tile, itemId, color)
			if tile then
				Sound.play("hover")
			end
		end
		held:over(tile ~= nil)
	end
	local mouseConn: RBXScriptConnection? = nil
	if o.drag then
		point(self:_toRoot(o.drag))
	elseif not touch then
		-- PC: the card rides on the mouse until you click a tile
		mouseConn = RunService.RenderStepped:Connect(function()
			point(self:_toRoot(UserInputService:GetMouseLocation()))
		end)
	else
		-- touch, after tapping PLACE: the card waits over the board for a tile
		held:moveTo(self:_boardCenter())
	end

	local closeHint, setConfirm
	local done = false
	local function putBack()
		held:back(if index then self:_handSpot(index) else startPos, function()
			if self.alive and not self.pendingPlace then
				self.hand:setHeld(nil)
			end
		end)
	end
	local function finish(cancelled: boolean)
		if done then
			return
		end
		done = true
		self.targeting = false
		self.cancelTarget = nil
		self.dragging = nil
		if mouseConn then
			mouseConn:Disconnect()
		end
		self.board:clearHighlight()
		if cancelled then
			self.board:previewTile(nil, nil, nil)
		end
		if closeHint then
			closeHint()
		end
		if cancelled then
			putBack()
		end
		self:_refresh()
	end
	local function stamp(tile: number, dir: string?)
		-- the card goes down at once (its look stays on the tile); the server's "place"
		-- event then makes it real, and if the move is refused it comes back to your hand
		self.pendingPlace = { tile = tile, item = itemId, at = os.clock() }
		self.board:previewTile(tile, itemId, color)
		local spot: Vector2 = self:_tileSpot(tile)
		local board = self.board
		held:drop(spot, function()
			-- the thud, the dust and the jolt happen as it hits, not when the server answers
			if self.alive and self.board == board then
				Effects.place(board, itemId, tile, color)
			end
		end)
		task.spawn(function()
			local ok = self:_cmd({ type = "play", item = itemId, tile = tile, dir = dir })
			if not ok and self.alive then
				self.pendingPlace = nil
				self.hand:setHeld(nil)
				self.board:previewTile(nil, nil, nil)
			end
		end)
	end
	local function commit(tile: number)
		if done then
			return
		end
		finish(false)
		if itemId == "conveyor" then
			-- the card hovers over the tile while you pick the belt's direction
			local spot: Vector2 = self:_tileSpot(tile)
			held:hoverAt(spot)
			self.board:previewTile(tile, itemId, color)
			local picked = false
			Inspector.choose(self.popups, "Conveyor Belt", "Which way should the belt carry people?", {
				{ text = "FORWARD", value = "fwd", style = "green", width = 150 },
				{ text = "BACKWARD", value = "back", style = "red", width = 150 },
			}, function(dir)
				picked = true
				self.board:previewTile(nil, nil, nil)
				stamp(tile, dir)
			end, function()
				if not picked then
					self.board:previewTile(nil, nil, nil)
					putBack()
				end
			end)
		else
			stamp(tile, nil)
		end
	end

	local verb = if hidden then "hide" else "place"
	local reach = if ctx.range then (" within " .. ctx.range .. " tiles") else ""
	local prompt
	if o.drag then
		prompt = "Drop " .. def.name .. " on a glowing tile" .. reach
	elseif touch then
		prompt = "Tap a glowing tile to " .. verb .. " " .. def.name
	else
		prompt = "Click a glowing tile to " .. verb .. " " .. def.name .. " (right-click: cancel)"
	end
	if hidden then
		prompt ..= ". Only your team will see it!"
	end
	closeHint, setConfirm = self:_hint(prompt, function()
		finish(true)
	end)
	self.cancelTarget = function()
		finish(true)
	end
	self.board:highlight(valid, color, commit, {
		confirm = touch and not o.drag,
		-- with a pointer or a dragging finger, `point` shows the preview; after a tap, the
		-- picked tile does
		preview = if touch and not o.drag then itemId else nil,
		onSelect = function(tile)
			local spot: Vector2 = self:_tileSpot(tile)
			held:hoverAt(spot)
			setConfirm(string.upper(verb) .. " " .. def.name .. " here?", function()
				commit(tile)
			end, string.upper(verb))
		end,
	})
	if o.drag then
		self.dragging = {
			point = function(pos: Vector2)
				if not done then
					point(self:_toRoot(pos))
				end
			end,
			cancel = function()
				finish(true)
			end,
			release = function(pos: Vector2)
				if done then
					return
				end
				local tile = self.board:tileAt(self:_toRoot(pos), valid)
				if tile then
					commit(tile)
				else
					finish(true)
				end
			end,
		}
	end
	return true
end

-- Pick a tile on the board (Overgrow). onPick gets the tile.
function MatchScreen:_pickTile(prompt: string, tiles: { number }, color: Color3, onPick: (number) -> ())
	if self.targeting then
		return
	end
	if #tiles == 0 then
		Widgets.toast("There's nowhere to do that right now.", "error")
		return
	end
	local touch = Root.metrics.touch
	self.targeting = true
	self:_previewDie(nil)
	self:_refresh()
	local closeHint, setConfirm
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		self.targeting = false
		self.cancelTarget = nil
		self.board:clearHighlight()
		if closeHint then
			closeHint()
		end
		self:_refresh()
	end
	closeHint, setConfirm = self:_hint(prompt, finish)
	self.cancelTarget = finish
	self.board:highlight(tiles, color, function(tile)
		finish()
		onPick(tile)
	end, {
		confirm = touch,
		onSelect = function(tile)
			setConfirm(nil, function()
				finish()
				onPick(tile)
			end, "HERE!")
		end,
	})
end

-- Pick a player from the chips.
function MatchScreen:_pickPlayer(prompt: string, seats: { number }, onPick: (number) -> ())
	if self.targeting then
		return
	end
	if #seats == 0 then
		Widgets.toast("There's nobody you can pick right now.", "error")
		return
	end
	self.targeting = true
	self:_previewDie(nil)
	self:_refresh()
	local closeHint
	local function finish()
		self.targeting = false
		self.cancelTarget = nil
		self.chips:clearPick()
		if closeHint then
			closeHint()
		end
		self:_refresh()
	end
	closeHint = self:_hint(prompt, finish)
	self.cancelTarget = finish
	self.chips:pick(seats, function(seat)
		finish()
		onPick(seat)
	end)
end

function MatchScreen:_allSeats(exceptMe: boolean): { number }
	local out = {}
	for seat in self.view.players do
		if not (exceptMe and seat == self.mySeat) then
			table.insert(out, seat)
		end
	end
	table.sort(out)
	return out
end

---------------------------------------------------------------------------
-- your cards: hover to read, click (or drag onto the board) to play
---------------------------------------------------------------------------

-- What clicking a card will do right now, in a line (shown on its tip).
function MatchScreen:_cardHint(itemId: string): (string, boolean)
	local def = Items.get(itemId)
	if not def then
		return "", false
	end
	local touch = Root.metrics.touch
	local click = if touch then "Tap" else "Click"
	if def.use == "passive" or def.use == "none" then
		return "Works by itself: just keep it in your hand.", false
	end
	if not self:_myTurn() then
		return if self.view.current == self.mySeat then "Wait for the board to settle..." else "You can play it on your turn.", false
	end
	if self:_cardsLeft() <= 0 then
		return "You've played your card this turn.", false
	end
	if def.use == "place" then
		local ctx = self:_placeContext()
		local reach = if ctx.range then (" within " .. ctx.range .. " tiles of you") else " anywhere"
		if def.hidden then
			return (if touch then "Tap HIDE" else "Click it") .. ", or drag it onto a tile" .. reach .. ". Rivals won't see it!", true
		end
		return (if touch then "Tap PLACE" else "Click it") .. ", or drag it onto a tile" .. reach .. ".", true
	elseif def.use == "boost" then
		return click .. " to play it, then pick your die.", true
	elseif def.use == "juice" then
		local me = self:_player(self.mySeat)
		if me and (me.power or 0) >= (me.powerCap or 1) then
			return "Your Power is already full.", false
		end
		return click .. " to fill your Power bar.", true
	elseif def.use == "reroll" then
		return click .. " to roll your dice again.", true
	elseif def.use == "anchor" then
		return click .. " to drop your time anchor here. RECALL brings you back.", true
	elseif def.use == "telepathy" then
		return click .. " to move any player up to " .. Rules.TelepathyMax .. " tiles.", true
	elseif def.use == "jeopardy" then
		return click .. " to pick a rival to swap hands with.", true
	elseif def.use == "xray" then
		return click .. " to see every hidden trap.", true
	end
	return "", false
end

-- The tip for hand card `index` (with the card's buttons on touch screens).
function MatchScreen:_showTip(itemId: string, index: number, actions: { any }?)
	local pos, size = self.hand:slotRect(index)
	if not pos or not size or not self.tip then
		return
	end
	local p0 = self:_toRoot(pos)
	local k = Util.inheritedScale(self.root, true)
	local anchor = { x = p0.X, y = p0.Y, w = size.X / k, h = size.Y / k }
	local side = "up"
	if self.L and self.L.hand and self.L.hand.dir == "y" then
		-- a column of cards down one side: the tip opens towards the board
		side = if anchor.x + anchor.w / 2 > Root.vw / 2 then "left" else "right"
	end
	local hint, ready = self:_cardHint(itemId)
	self.tipFor = { id = itemId, index = index, actions = actions }
	self.tip:show(itemId, { anchor = anchor, side = side, hint = hint, ready = ready, actions = actions })
end

function MatchScreen:_closeTip()
	self.tipFor = nil
	self.tipPinned = nil
	if self.tip then
		self.tip:hide()
	end
end

-- The pointer moved onto a card in your hand (nil: off the hand).
function MatchScreen:_cardHover(itemId: string?, index: number?)
	if self.tipPinned then
		return
	end
	if not itemId or not index or self.targeting or self.dragging then
		self:_closeTip()
		return
	end
	self:_showTip(itemId, index, nil)
end

-- A click (PC, or a number key) plays the card; a tap (touch) opens its tip with buttons.
function MatchScreen:_cardClicked(itemId: string, index: number)
	if not Items.get(itemId) or self.targeting then
		return
	end
	if Root.metrics.touch then
		if self.tipPinned == index and self.tip.visible then
			self:_closeTip()
			return
		end
		-- one tap does it: a second tap while the tip closes would play the card twice
		local used = false
		local actions = {}
		for _, a in self:_cardActions(itemId, index) do
			if a.onClick then
				local run = a.onClick
				a.onClick = function()
					if used then
						return
					end
					used = true
					self:_closeTip()
					run()
				end
			end
			table.insert(actions, a)
		end
		table.insert(actions, { text = "CLOSE", style = "wood", onClick = function()
			self:_closeTip()
		end })
		self:_closeTip()
		self.tipPinned = index
		self:_showTip(itemId, index, actions)
		return
	end
	self:_closeTip()
	self:_playCard(itemId, index)
end

-- Does what a click on the card does (asks only when there's a real choice).
function MatchScreen:_playCard(itemId: string, index: number)
	local playable = {}
	for _, a in self:_cardActions(itemId, index) do
		if a.onClick and not a.disabled then
			table.insert(playable, a)
		end
	end
	if #playable == 0 then
		self.hand:nudge(index)
		Sound.play("error")
		local hint = self:_cardHint(itemId)
		if hint ~= "" then
			Widgets.toast(hint, "error")
		end
		return
	end
	if #playable == 1 then
		task.spawn(playable[1].onClick)
		return
	end
	-- e.g. play it, or give it to a teammate: ask which
	local options = {}
	for i, a in playable do
		table.insert(options, { text = a.text, value = i, style = a.style, width = 170 })
	end
	local def = Items.get(itemId)
	Inspector.choose(self.popups, def and def.name or "Card", nil, options, function(i)
		task.spawn(playable[i].onClick)
	end)
end

--[[
	A card pulled up out of the hand. Cards that go on a tile start placing at once;
	the rest are played by letting go anywhere over the board.
]]
function MatchScreen:_dragStart(itemId: string, index: number, pos: Vector2): boolean
	local def = Items.get(itemId)
	if not def or self.targeting or not self:_myTurn() or self:_cardsLeft() <= 0 then
		return false
	end
	self:_closeTip()
	if def.use == "place" then
		return self:_placeFlow(itemId, { index = index, drag = pos })
	end
	local playable = false
	for _, a in self:_cardActions(itemId, index) do
		if a.onClick and not a.disabled then
			playable = true
		end
	end
	if not playable then
		return false
	end
	local startPos = self:_handSpot(index)
	local cardW = if self.L and self.L.hand then self.L.hand.card.w else 90
	local held = Overlays.heldCard(self.fly, itemId, startPos, cardW)
	self.hand:setHeld(index)
	Sound.play("card")
	local function overBoard(stage: Vector2): boolean
		local f = self.L and self.L.focus
		local h = self.L and self.L.hand and self.L.hand.rect
		if not f then
			return false
		end
		local inFocus = stage.X >= f.x and stage.X <= f.x + f.w and stage.Y >= f.y and stage.Y <= f.y + f.h
		local inHand = h ~= nil and stage.X >= h.x and stage.X <= h.x + h.w and stage.Y >= h.y and stage.Y <= h.y + h.h
		return inFocus and not inHand
	end
	local function point(p: Vector2)
		local stage = self:_toRoot(p)
		held:moveTo(stage)
		held:over(false)
		held:glow(overBoard(stage))
	end
	point(pos)
	self.dragging = {
		point = point,
		cancel = function()
			self.dragging = nil
			held:back(self:_handSpot(index), function()
				if self.alive then
					self.hand:setHeld(nil)
				end
			end)
		end,
		release = function(p: Vector2)
			self.dragging = nil
			local stage = self:_toRoot(p)
			if overBoard(stage) then
				held:use(stage, function()
					if self.alive then
						self.hand:setHeld(nil)
					end
				end)
				self:_playCard(itemId, index)
			else
				held:back(self:_handSpot(index), function()
					if self.alive then
						self.hand:setHeld(nil)
					end
				end)
			end
		end,
	}
	return true
end

--[[
	What a card can do right now, as buttons: { text, style, onClick?, disabled? }.
	The first one is what a click (or a drag onto the board) does.
]]
function MatchScreen:_cardActions(itemId: string, index: number?): { any }
	local def = Items.get(itemId)
	if not def then
		return {}
	end
	local mine = self:_myTurn()
	local actions = {}
	local use = def.use
	local v = self.view
	local spent = self:_cardsLeft() <= 0
	local function play(extra: { [string]: any }?)
		local cmd = { type = "play", item = itemId }
		for k, x in extra or {} do
			cmd[k] = x
		end
		self:_cmd(cmd)
	end
	if use == "passive" then
		table.insert(actions, { text = "Works automatically. Keep it in your hand.", disabled = true })
	elseif not mine then
		table.insert(actions, { text = "You can play this on your turn.", disabled = true })
	elseif spent then
		table.insert(actions, { text = "You've played your card this turn.", disabled = true })
	elseif use == "place" then
		table.insert(actions, { text = if def.hidden then "HIDE IT" else "PLACE IT", icon = "map", style = "green", onClick = function()
			self:_placeFlow(itemId, { index = index })
		end })
	elseif use == "boost" or use == "reroll" or use == "anchor" or use == "xray" then
		table.insert(actions, { text = "PLAY IT", style = "brass", onClick = function()
			play(nil)
		end })
	elseif use == "juice" then
		local me = self:_player(self.mySeat)
		table.insert(actions, { text = "FILL POWER", style = "brass", disabled = me ~= nil and (me.power or 0) >= (me.powerCap or 1), onClick = function()
			play(nil)
		end })
	elseif use == "telepathy" then
		table.insert(actions, { text = "MOVE A PLAYER", style = "purple", width = 230, onClick = function()
			self:_pickPlayer("Telepathy: who do you want to move?", self:_allSeats(false), function(seat)
				local options = {}
				local target = self:_player(seat)
				for n = -Rules.TelepathyMax, Rules.TelepathyMax do
					if n ~= 0 then
						table.insert(options, {
							text = (if n > 0 then "+" else "") .. n,
							value = n,
							style = if n > 0 then "green" else "red",
							width = 66,
							disabled = n < 0 and target ~= nil and (target.trailLength or 0) <= 1,
						})
					end
				end
				Inspector.choose(self.popups, "Telepathy", "Move " .. self:_name(seat) .. " back (-) or forward (+)", options, function(n)
					play({ target = seat, steps = n })
				end)
			end)
		end })
	elseif use == "jeopardy" then
		table.insert(actions, { text = "PICK A RIVAL", style = "red", onClick = function()
			self:_pickPlayer("Double Jeopardy: swap hands with who?", self:_allSeats(true), function(seat)
				play({ target = seat })
			end)
		end })
	end
	-- team modes: pass a card to a teammate (it counts as your card this turn)
	local me = self:_player(self.mySeat)
	if mine and not spent and self.isTeam and me then
		local mates, full = {}, 0
		for seat, p in v.players do
			if p.team == me.team and seat ~= self.mySeat then
				if (p.handCount or 0) >= Rules.HandLimit then
					full += 1
				else
					table.insert(mates, seat)
				end
			end
		end
		if #mates > 0 then
			table.insert(actions, { text = "GIVE", icon = "plus", style = "blue", onClick = function()
				self:_pickPlayer("Give " .. def.name .. " to which teammate?", mates, function(seat)
					self:_cmd({ type = "give", item = itemId, target = seat })
				end)
			end })
		elseif full > 0 then
			table.insert(actions, { text = "Your teammate's hand is full.", disabled = true })
		end
	end
	return actions
end

---------------------------------------------------------------------------
-- your ability
---------------------------------------------------------------------------

-- Tiles a Naturalist can grow a hazard on (the engine's canGrow, from what I can see).
function MatchScreen:_growTiles(): { number }
	local me = self:_player(self.mySeat)
	local board = self.board.board
	local v = self.view
	local out = {}
	if not me then
		return out
	end
	local cover = {}
	for _, e in v.placed do
		for _, t in e.tiles or {} do
			cover[t] = true
		end
	end
	for id, tile in board.tiles do
		local ok = board:raceDistance(me.tile, id) <= CharCfg.naturalist.range
			and not board:isSpecial(id)
			and tile.kind ~= "shortcutGate"
			and v.tokens[id] == nil
			and v.natural[id] == nil
			and v.placed[id] == nil
			and not cover[id]
		if ok then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function MatchScreen:_abilityClicked()
	if not self:_myTurn() then
		return
	end
	local me = self:_player(self.mySeat)
	local cdef = Characters.get(me and me.character or "")
	local ab = cdef and cdef.ability
	if not me or not ab then
		return
	end
	if self.view.abilityUsed then
		Widgets.toast("You already used your ability this turn.", "error")
		return
	end
	if (me.power or 0) < (me.powerCap or ab.cost) then
		Widgets.toast("Your Power bar isn't full yet. The die you don't move with charges it.", "error")
		return
	end
	local function send(extra: { [string]: any }?)
		local cmd = { type = "ability" }
		for k, x in extra or {} do
			cmd[k] = x
		end
		self:_previewDie(nil)
		self:_cmd(cmd)
	end
	if ab.target == "none" then
		send(nil)
		return
	end
	if ab.target == "tile" then
		self:_pickTile(ab.name .. ": pick a tile within " .. (ab.range or 0) .. " tiles", self:_growTiles(), C.lime, function(tile)
			send({ tile = tile })
		end)
		return
	end
	local seats = {}
	for seat, p in self.view.players do
		local ok = true
		if ab.target ~= "any" and seat == self.mySeat then
			ok = false
		end
		if ab.id == "warp" and (p.tile == me.tile or p.character == "warper") then
			ok = false
		end
		if ab.range and seat ~= self.mySeat and self.board.board:raceDistance(me.tile, p.tile) > ab.range then
			ok = false
		end
		if ok then
			table.insert(seats, seat)
		end
	end
	table.sort(seats)
	local prompt = ab.name .. ": pick a player" .. (if ab.range then (" within " .. ab.range .. " tiles") else "")
	self:_pickPlayer(prompt, seats, function(target: number)
		if not ab.options then
			send({ target = target })
			return
		end
		local t = self:_player(target)
		local steps = CharCfg.overseer.steps
		Inspector.choose(self.popups, ab.name, "Move " .. self:_name(target) .. " " .. steps .. " tiles:", {
			{ text = "BACK " .. steps, value = "back", style = "red", width = 150, disabled = t ~= nil and (t.trailLength or 0) <= 1 },
			{ text = "FORWARD " .. steps, value = "fwd", style = "green", width = 150 },
		}, function(opt)
			send({ target = target, option = opt })
		end)
	end)
end

---------------------------------------------------------------------------
-- shop, card pick, emotes, menu, scoreboard, results
---------------------------------------------------------------------------

function MatchScreen:_openShop()
	local me = self:_player(self.mySeat)
	if not me then
		return
	end
	local done = false
	self.shop = Shop.open(self.popups, {
		coins = me.coins,
		stock = self.view.stock or {},
		hand = self.view.hand or {},
		onBuy = function(itemId)
			if not done then
				self:_cmd({ type = "buy", item = itemId })
			end
		end,
		onDone = function()
			-- once: the shop stays up until the server's answer has played
			if done then
				return
			end
			done = true
			if not self:_cmd({ type = "shopDone" }) then
				done = false
			end
		end,
	})
end

-- Scavenge: two trap cards face up, keep one.
function MatchScreen:_openPick(options: { string })
	self.closePick = Overlays.pickCard(self.popups, "SCAVENGE: KEEP ONE", options, function(i)
		self.closePick = nil
		self.pickSent = true
		if not self:_cmd({ type = "pick", index = i }) then
			self.pickSent = nil
			self:_refresh()
		end
	end)
end

function MatchScreen:_emotePicker()
	local profile = State.get("profile")
	local emotes = profile and profile.equipped and profile.equipped.emotes or { "emote_gg" }
	local cols = if Root.metrics.form == "tall" then 2 else 3
	local content, close = Widgets.modal(self.popups, {
		title = "Emotes",
		titleWidth = 220,
		width = cols * 160 + 60,
		height = 150 + math.ceil(#emotes / cols) * 54,
	})
	local grid = Util.frame(content, {})
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 44),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, id in emotes do
		local def = Cosmetics.get(id)
		if def then
			local b = Util.new("TextButton", {
				Name = id,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = grid,
			})
			local bubble = CosmeticArt.emoteBubble(b, id, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
			if bubble then
				bubble.Active = false
			end
			b.Activated:Connect(function()
				close()
				local ok, err = Net.request("match.emote", { emote = id })
				if not ok then
					Widgets.toast(tostring(err), "error")
				end
			end)
			b.MouseEnter:Connect(function()
				Util.bump(b, 0.06)
			end)
		end
	end
end

-- Everyone at a glance: treasures, coins, cards, Power, bonks, gotchas.
function MatchScreen:_scoreboard()
	if self.scoreboardOpen then
		return
	end
	local players = {}
	for _, p in self.view.players do
		table.insert(players, p)
	end
	table.sort(players, function(a, b)
		if (a.treasures or 0) ~= (b.treasures or 0) then
			return (a.treasures or 0) > (b.treasures or 0)
		end
		return a.seat < b.seat
	end)
	local narrow = Root.metrics.form == "tall"
	local width = if narrow then 400 else 680
	local content, close = Widgets.modal(self.popups, {
		title = "Scores",
		titleWidth = 200,
		width = width,
		height = 120 + #players * 58,
		onClose = function()
			self.scoreboardOpen = false
		end,
	})
	self.scoreboardOpen = true
	local _ = close
	local list = Util.frame(content, {})
	Util.list(list, "y", 6, "Center", "Top")
	for i, p in players do
		local info = self.seats[p.seat] or {}
		local row = Util.new("Frame", {
			Name = "Row" .. i,
			BackgroundColor3 = if p.seat == self.mySeat then C.mine else C.panelRaised,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = i,
			Parent = list,
		})
		Util.corner(row, 10)
		Util.stroke(row, if p.seat == self.mySeat then C.sun else C.line, 2)
		Avatars.portrait(row, { userId = info.userId, character = p.character, isBot = p.isBot }, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
		}, { ring = self:_seatColor(p.seat), ringPx = 3 })
		local name = Widgets.label(row, {
			text = p.name .. (if p.seat == self.mySeat then " (you)" else ""),
			font = "heavy",
			size = 15,
			color = Theme.nameColor(info.look),
			sizeUDim = UDim2.new(if narrow then 0.5 else 0.34, -54, 0, 20),
			position = UDim2.fromOffset(54, 6),
		})
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local cdef = Characters.get(p.character or "")
		Widgets.label(row, {
			text = (if info.username and not p.isBot then ("@" .. info.username .. " · ") else "") .. (if cdef then cdef.name else ""),
			font = "body",
			size = 12,
			color = C.textSoft,
			sizeUDim = UDim2.new(if narrow then 0.5 else 0.34, -54, 0, 16),
			position = UDim2.fromOffset(54, 27),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local stats = Util.frame(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(if narrow then 0.5 else 0.64, -10, 1, 0),
		})
		Util.list(stats, "x", 10, "Right", "Center")
		local function stat(icon: string, color: Color3, value: any, order: number)
			local box = Util.frame(stats, { Size = UDim2.fromOffset(48, 24), LayoutOrder = order })
			local ic = Util.frame(box, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 1) })
			Icons.medallion(ic, icon, color, { Size = UDim2.fromScale(1, 1) })
			Widgets.label(box, {
				text = tostring(value),
				font = "chunky",
				size = 17,
				color = C.text,
				sizeUDim = UDim2.fromOffset(24, 24),
				position = UDim2.fromOffset(24, 0),
			})
		end
		local s = p.stats or {}
		stat("chest", C.sun, p.treasures or 0, 1)
		stat("coin", C.sun, p.coins or 0, 2)
		stat("book", C.sky, p.handCount or 0, 3)
		if not narrow then
			stat("bolt", C.sun, p.power or 0, 4)
			stat("star", C.sun, s.bonks or 0, 5)
			stat("token_trap", C.coral, s.gotchas or 0, 6)
		end
	end
end

function MatchScreen:_inspectPlayer(seat: number)
	local p = self:_player(seat)
	if p and p.character then
		Inspector.character(self.popups, p.character)
	end
end

function MatchScreen:_menu()
	local content, close = Widgets.modal(self.popups, {
		title = "Menu",
		titleWidth = 200,
		width = 420,
		height = 380,
	})
	local list = Util.frame(content, {})
	Util.list(list, "y", 12, "Center", "Center")
	VolumeRows.build(list, 1)
	if not self.hasScoresButton then
		Widgets.button(list, {
			text = "SCORES",
			icon = "people",
			style = "blue",
			textSize = 20,
			size = UDim2.fromOffset(280, 50),
			layoutOrder = 3,
			onClick = function()
				close()
				self:_scoreboard()
			end,
		})
	end
	Widgets.button(list, {
		text = "LEAVE MATCH",
		icon = "exit",
		style = "red",
		textSize = 20,
		size = UDim2.fromOffset(280, 50),
		layoutOrder = 4,
		onClick = function()
			close()
			local confirm, closeConfirm = Widgets.modal(self.popups, {
				title = "Leave?",
				titleWidth = 200,
				width = 440,
				height = 230,
			})
			Widgets.label(confirm, {
				text = if self.kind == "practice" then "End this practice game?" else "A bot will take your seat for the rest of the game.",
				font = "heavy",
				size = 18,
				color = C.text,
				align = "center",
				wrap = true,
				sizeUDim = UDim2.new(1, 0, 0, 56),
			})
			Widgets.button(confirm, {
				text = "LEAVE",
				style = "red",
				textSize = 20,
				size = UDim2.fromOffset(180, 50),
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, 0),
				onClick = function()
					closeConfirm()
					local ok, err = Net.request("match.leave")
					if not ok then
						Widgets.toast(tostring(err), "error")
					end
				end,
			})
		end,
	})
end

function MatchScreen:_showResults(data)
	task.spawn(function()
		-- let the last events finish first
		while self.alive and (self.playing or #self.queue > 0) do
			task.wait(0.2)
		end
		if not self.alive then
			return
		end
		task.wait(0.6)
		if self.shop then
			self.shop:close()
			self.shop = nil
		end
		Results.show(self.popups, data, self.mySeat, self.isTeam, function()
			Net.request("match.leave")
		end)
	end)
end

local _ = CardStyle

return MatchScreen
