--[[
	MatchScreen
	The whole match. The treasure map fills the screen; the HUD (players, your cards,
	ROLL, your ability, the top bar) sits around it wherever Layout puts it for this
	screen, and moves when the screen changes shape (an upright phone stands the board
	up as well).

	The server sends batches of events ("match.events"). They're queued and played back
	one by one at the pace the server expects (Shared/Game/Pacing). A display state
	(self.view) changes as each animation lands: a drawn card joins your hand when it
	arrives there, coins tick up as the coin flies in. The snapshot that came with the
	batch then corrects anything that drifted, so the screen always ends up in sync.

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

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local CosmeticArt = require(UI.CosmeticArt)
local Avatars = require(UI.Avatars)
local Layout = require(UI.Layout)
local Root = require(UI.Root)
local BoardView = require(script.Parent.BoardView)
local PlayerChips = require(script.Parent.PlayerChips)
local HandView = require(script.Parent.HandView)
local ActionDock = require(script.Parent.ActionDock)
local Feed = require(script.Parent.Feed)
local Overlays = require(script.Parent.Overlays)
local Effects = require(script.Parent.Effects)
local Inspector = require(script.Parent.Inspector)
local Shop = require(script.Parent.Shop)
local Results = require(script.Parent.Results)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C
local hex = Theme.hex
local Rules = Config.Rules

local MatchScreen = {}
MatchScreen.__index = MatchScreen

local active = nil

local DEATH_TEXT = {
	spike = "was spiked",
	grog = "was eaten by a Grog",
	fire = "burned up",
}

local NATURAL_TEXT = {
	river = "fell in the river",
	gate = "is stuck at a locked gate",
	slime = "got slimed",
}

local WHEEL_NAME = { trap = "Trap", assist = "Assist", neutral = "Neutral" }
local LENGTH_NAME = { quick = "Quick", standard = "Standard", classic = "Classic" }

-- Cards a roll uses up when they were armed (they show in the roll's mods).
local ROLL_CARDS = { speed_boost = true, speed_potion = true, bounce_pad = true, boots = true }

local function toHex(c: Color3): string
	return c:ToHex()
end

-- Remembers a sound setting on the server (the lobby's Settings page shows the same).
local function saveSetting(key: string, value: boolean)
	local profile = State.get("profile")
	local settings = table.clone(profile and profile.settings or {})
	settings[key] = value
	task.spawn(Net.request, "settings.save", { settings = settings })
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
			self:_enqueue(data)
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
	Sound.music("match")
	return self
end

-- The display state, from a snapshot. `noHand` starts with an empty hand (the deal fills it).
function MatchScreen:_viewFrom(snap, noHand: boolean?)
	local players = {}
	for _, p in snap.players do
		local copyOf = table.clone(p)
		if noHand then
			copyOf.handCount = 0
		end
		players[p.seat] = copyOf
	end
	local tokens, placed, natural = {}, {}, {}
	for _, t in snap.tokens or {} do
		tokens[t.tile] = t.kind
	end
	for _, e in snap.placed or {} do
		placed[e.tile] = table.clone(e)
	end
	for _, n in snap.natural or {} do
		natural[n.tile] = n.kind
	end
	local armed = {}
	for _, id in snap.armed or {} do
		armed[id] = true
	end
	return {
		round = snap.round or 1,
		current = snap.current,
		phase = snap.phase,
		abilityUsed = snap.abilityUsed == true,
		hand = if noHand then {} else copy(snap.hand),
		armed = armed,
		stock = table.clone(snap.stock or {}),
		players = players,
		tokens = tokens,
		placed = placed,
		natural = natural,
	}
end

-- The display state shaped like a snapshot (for the board).
function MatchScreen:_viewAsSnap()
	local v = self.view
	local players, tokens, placed, natural = {}, {}, {}, {}
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
	return { players = players, tokens = tokens, placed = placed, natural = natural }
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
	self.dock = ActionDock.new(self.hud, { character = me and me.character, touch = touch })
	self.dock.onRoll = function()
		self:_roll()
	end
	self.dock.onAbility = function()
		self:_abilityClicked()
	end
	self.dock.onRecall = function()
		self:_cmd({ type = "recall" })
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
		self.chips:tick(workspace:GetServerTimeNow())
	end))
	self.maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		self:_key(input.KeyCode)
	end))
end

-- Lays the HUD out for this screen (and stands the board up on upright phones).
function MatchScreen:_relayout(m)
	local L = Layout.match(m, #self:_seatList())
	self.L = L
	local rotate = m.form == "tall"
	local first = self.board == nil
	if first or self.boardRotated ~= rotate then
		if self.board then
			-- a tile pick in progress belongs to the old board
			if self.cancelTarget then
				self.cancelTarget()
			end
			self.board:destroy()
		end
		self.board = BoardView.new(self.boardLayer, self.mapDef.id, { rotate = rotate })
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
	self.hand:layout(L.hand)
	self.dock:layout(L.ability, L.roll, m.form)
	self.feed:layout(L.feed)
	self:_layoutTop(L, m)
	self:_refresh()
	if self.cancelTarget and self.hintLayout then
		self.hintLayout()
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
			BackgroundColor3 = hex("1F150E"),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = self.info,
		})
		Util.corner(plate, math.min(10, info.h / 2))
		Util.stroke(plate, C.brassDark, 1.5)
		self.roundLabel = Widgets.label(plate, {
			text = "",
			font = "heavy",
			size = math.clamp(math.floor(info.h * 0.5), 11, 16),
			color = C.parchment,
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
		{ icon = "people", style = "dark", onClick = function()
			self:_scoreboard()
		end, key = "scores" },
		{ icon = "map", style = "dark", onClick = function()
			if self.board then
				self.board:fit()
			end
		end, key = "fit" },
		{ icon = "smile", style = "brass", onClick = function()
			self:_emotePicker()
		end, key = "emote" },
		{ icon = "gear", style = "dark", onClick = function()
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
	local lengthName = LENGTH_NAME[self.length or ""] or ""
	local w = self.L and self.L.info and self.L.info.w or 300
	if w >= 300 then
		self.roundLabel.Text = string.format("Round %d  ·  %s%s  ·  First to %d", round, modeName, if lengthName ~= "" then ("  ·  " .. lengthName) else "", self.target or 0)
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
	self.maid:clean()
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
	local color = Util.shade(Theme.Seat[((seat - 1) % 6) + 1], 0.25)
	return string.format('<font color="#%s">%s</font>', toHex(color), self:_name(seat))
end

function MatchScreen:_seatColor(seat: number): Color3
	return Theme.Seat[((seat - 1) % 6) + 1]
end

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

---------------------------------------------------------------------------
-- display state -> HUD
---------------------------------------------------------------------------

function MatchScreen:_refresh()
	if not self.chips or not self.L then
		return
	end
	local v = self.view
	self.chips:update(v.players)
	self.hand:setArmed(v.armed)
	local me = self:_player(self.mySeat)
	local mine = self:_myTurn()
	self.dock:setTurn({
		mine = v.current == self.mySeat,
		phase = v.phase,
		waitingFor = if v.current ~= self.mySeat then self:_name(v.current) else nil,
		anchor = me and me.anchor or 0,
		busy = not mine,
	})
	if me then
		self.dock:setAbility(me.abilityReady, me.abilityProgress or 0, v.abilityUsed == true, mine)
	end
	-- the Potion Seller opens on your turn in the shop phase
	if v.phase == "shop" and v.current == self.mySeat and not self.playing and not self.shop then
		self:_openShop()
	elseif self.shop and me then
		self.shop:update(me.coins, v.stock or {}, v.hand or {})
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
	self.view.armed[item] = nil
end

-- Someone loses a card: my hand if it's me, a count otherwise.
function MatchScreen:_lose(seat: number, item: string)
	if seat == self.mySeat then
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
		self.inflight -= 1
		if self.alive and self.epoch == epoch then
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
	self:_refresh()
	while self.alive and #self.queue > 0 do
		local payload = table.remove(self.queue, 1)
		-- if we've fallen behind (lag, tabbing out), play faster to catch up
		local backlog = 0
		for _, p in self.queue do
			backlog += Pacing.total(p.events or {})
		end
		self.speed = if backlog > 8 then 0.35 elseif backlog > 3 then 0.65 else 1
		for _, e in payload.events or {} do
			if not self.alive then
				return
			end
			local t0 = os.clock()
			local ok, err = pcall(self._play, self, e)
			if not ok then
				warn("[Trapisque] event '" .. tostring(e.t) .. "' failed to animate: " .. tostring(err))
			end
			local left = Pacing.duration(e) * self.speed - (os.clock() - t0)
			if left > 0 then
				task.wait(left)
			end
		end
		-- let the last cards and coins land before the snapshot settles everything
		local t0 = os.clock()
		while self.alive and self.inflight > 0 and os.clock() - t0 < 2.5 do
			task.wait()
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

-- The batch's snapshot: the truth. Anything the animations got wrong is fixed here.
function MatchScreen:_reconcile(payload)
	local snap = payload.snapshot
	if not snap then
		return
	end
	self.snap = snap
	self.deadline = payload.deadline or 0
	self.epoch += 1
	self.view = self:_viewFrom(snap, false)
	if self.board then
		self.board:applySnapshot(snap)
		self.board:setCurrent(if snap.phase ~= "over" then snap.current else nil)
	end
	if self.chips then
		self.chips:setCurrent(if snap.phase ~= "over" then snap.current else nil, self.deadline)
		self.hand:setHand(self.view.hand, self.view.armed)
	end
	self:_updateRound()
	if self.shop and not (snap.phase == "shop" and snap.current == self.mySeat) then
		self.shop:close()
		self.shop = nil
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
		return
	elseif t == "deal" then
		local items = e.items or {}
		local n = if e.items then #items else (e.count or 0)
		feed:add(self:_tag(e.p) .. " start" .. (if e.p == self.mySeat then "" else "s") .. " with " .. n .. " card" .. (if n == 1 then "" else "s"), nil, "book", C.wood)
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
					Overlays.flyIcon(self.fly, "book", C.wood, self:_boardCenter(), self:_chipSpot(e.p), speed, land)
				end
			end)
		end
	elseif t == "turn" then
		v.round = e.round
		v.current = e.p
		v.phase = "action"
		v.abilityUsed = false
		v.armed = {}
		self:_updateRound()
		board:setCurrent(e.p)
		self.chips:setCurrent(e.p, nil)
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
		end
		feed:add(self:_tag(e.p) .. " skip" .. (if e.p == self.mySeat then "" else "s") .. " a turn", nil, "snare", hex("A0522D"))
		board:floatText(self:_pawnWorld(e.p), "SKIP!", C.parchment)
	elseif t == "roll" then
		local info = self.seats[e.p]
		-- armed boosts (and boots) are used up by this roll
		for _, m in e.mods or {} do
			if ROLL_CARDS[m] then
				self:_lose(e.p, m)
			end
		end
		if e.p == self.mySeat then
			v.armed = {}
			self.hand:setArmed(v.armed)
		end
		if e.escaped then
			self:_patch(e.p, "held", false)
		end
		for _, m in e.mods or {} do
			if m == "boots" then
				self:_patch(e.p, "boots", true)
			end
		end
		Overlays.dice(self.fx, e, cosmeticOf(info, "dice"), speed)
		if e.held then
			feed:add(self:_tag(e.p) .. (if e.escaped then " broke free of the gate!" else " is still stuck at the gate"), nil, "lock", hex("8A9099"))
		else
			feed:add(self:_tag(e.p) .. " rolled a " .. e.die .. (if e.move ~= e.die then (", moving " .. e.move) else ""), nil, "dice", C.brassDark)
		end
	elseif t == "move" then
		local info = self.seats[e.p]
		local p = self:_player(e.p)
		if p and #e.path > 0 then
			p.tile = e.path[#e.path]
			if e.kind == "respawn" or e.kind == "home" then
				-- back at the start: cycle statuses wear off
				p.burning, p.frozen, p.boots, p.held = false, false, false, false
				board:setStatus(e.p, "burning", false)
				board:setStatus(e.p, "frozen", false)
				self.chips:update(v.players)
			end
		end
		board:hop(e.p, e.path, e.kind, cosmeticOf(info, "trail"))
	elseif t == "spin" then
		local p = self:_player(e.p)
		local segments = Overlays.wheelSegments(e.wheel, self.mapDef, p and p.character)
		Overlays.spin(self.fx, e.wheel, segments, e.index, speed)
		local def = Items.get(e.result)
		feed:add(self:_tag(e.p) .. " spun the " .. (WHEEL_NAME[e.wheel] or "") .. " wheel: " .. (if def then def.name else "?"), nil, "token_" .. (e.wheel or "trap"), Theme.Category[e.wheel] or C.brassDark)
	elseif t == "gain" then
		if e.p == self.mySeat then
			Overlays.flyCard(self.fly, e.item, self:_pawnSpot(e.p), self:_handSpot(nil), speed, self:_landing(function()
				self:_handAdd(e.item)
			end))
		else
			Overlays.flyIcon(self.fly, "book", C.wood, self:_pawnSpot(e.p), self:_chipSpot(e.p), speed, self:_landing(function()
				self:_handCount(e.p, 1)
			end))
		end
	elseif t == "handFull" then
		board:floatText(self:_pawnWorld(e.p), "HAND FULL", C.bad)
		feed:add(self:_tag(e.p) .. "'s hand is full")
	elseif t == "coin" then
		Sound.play("coin")
		board:floatText(self:_pawnWorld(e.p), "+1 COIN", C.gold)
		Overlays.flyIcon(self.fly, "coin", C.brassDark, self:_pawnSpot(e.p), self:_chipSpot(e.p), speed, self:_landing(function()
			self:_patch(e.p, "coins", e.coins)
		end))
	elseif t == "tokenMove" then
		v.tokens[e.from] = nil
		v.tokens[e.to] = e.token
		board:moveToken(e.from, e.to, e.token)
	elseif t == "trigger" then
		Effects.trap(board, e.item, e.tile)
		local def = Items.get(e.item)
		local owner = if e.owner and e.owner > 0 then (self:_tag(e.owner) .. "'s ") else "a "
		feed:add(self:_tag(e.p) .. " hit " .. owner .. (if def then def.name else "trap"), nil, e.item, Theme.Category[if BoardView.isNeutral(e.item) then "neutral" else "trap"])
	elseif t == "shield" then
		self:_lose(e.p, "shield")
		Effects.shield(board, e.p)
		local def = Items.get(e.item)
		feed:add(self:_tag(e.p) .. " shrugged off " .. (if def then def.name else "a trap") .. " with a Shield", nil, "shield", C.assist)
	elseif t == "death" then
		Effects.death(board, e.p)
		self.chips:shake(e.p)
		local why = DEATH_TEXT[e.cause] or "was knocked out"
		feed:add(self:_tag(e.p) .. " " .. why .. (if (e.lost or 0) > 0 then " and lost a treasure" else "") .. "!", C.bad, "skull", C.bad)
		self:_patch(e.p, "treasures", e.treasures)
	elseif t == "phoenix" then
		self:_lose(e.p, "phoenix_potion")
		Effects.phoenix(board, e.p)
		feed:add(self:_tag(e.p) .. " rose from the ashes! (Phoenix Potion)", C.gold, "phoenix_potion", C.potion)
	elseif t == "treasure" then
		Effects.treasure(board, self.board.board.treasure, e.p)
		local who = self:_name(e.p)
		local sub = tostring(e.treasures) .. " / " .. tostring(self.target)
		Overlays.shout(self.fx, if e.p == self.mySeat then "TREASURE!" else (who .. " found a treasure!"), C.gold, speed, sub)
		feed:add(self:_tag(e.p) .. " found a treasure! (" .. sub .. ")", C.gold, "x_mark", C.inkRed)
		self:_patch(e.p, "treasures", e.treasures)
		self:_patch(e.p, "coins", e.coins)
		self.chips:flash(e.p, C.gold)
	elseif t == "lap" then
		feed:add(self:_tag(e.p) .. " made it round again (finished, so it doesn't count)")
	elseif t == "finished" then
		self:_patch(e.p, "finished", true)
		Overlays.shout(self.fx, if e.p == self.mySeat then "ALL YOUR TREASURES!" else (self:_name(e.p) .. " has every treasure!"), C.gold, speed)
		feed:add(self:_tag(e.p) .. " has every treasure!", C.gold, "crown", C.brassDark)
	elseif t == "gameover" then
		v.phase = "over"
		local winners = {}
		for _, p in v.players do
			if p.team == e.team then
				table.insert(winners, self:_name(p.seat))
			end
		end
		local text = if self.isTeam then ((Theme.TeamName[e.team] or "A team") .. " wins!") else (table.concat(winners, " & ") .. (if #winners == 1 and winners[1] == "You" then " win!" else " wins!"))
		Overlays.shout(self.fx, text, C.gold, speed * 1.4, if e.reason == "rounds" then "Out of rounds" else nil)
		local me = self:_player(self.mySeat)
		Sound.play(if me and me.team == e.team then "win" else "lose")
	elseif t == "natural" then
		if e.kind == "gate" then
			self:_patch(e.p, "held", true)
		end
		Effects.natural(board, e.kind, e.tile)
		feed:add(self:_tag(e.p) .. " " .. (NATURAL_TEXT[e.kind] or "hit a natural trap"), nil, ({ river = "river_trap", gate = "lock", slime = "slime_trap" })[e.kind], C.natural)
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
			self.chips:update(v.players)
		end
		board:floatText(self:_pawnWorld(e.p), "SNARED!", C.trap)
		feed:add(self:_tag(e.p) .. " is snared and will skip a turn", nil, "snare", C.trap)
	elseif t == "status" then
		self:_patch(e.p, e.status, true)
		Effects.status(board, e.p, e.status)
		board:setStatus(e.p, e.status, true)
		feed:add(self:_tag(e.p) .. (if e.status == "burning" then " is burning!" else " is frozen!"), nil, if e.status == "burning" then "fire" else "ice", if e.status == "burning" then hex("E2622B") else hex("5DADE2"))
	elseif t == "immune" then
		board:floatText(self:_pawnWorld(e.p), "IMMUNE", C.info)
	elseif t == "place" then
		self:_playPlace(e, speed)
	elseif t == "useCard" then
		local def = Items.get(e.item)
		self:_lose(e.p, e.item)
		if e.item == "time_potion" then
			self:_patch(e.p, "anchor", e.tile or 0)
		end
		local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_chipSpot(e.p)
		Overlays.flyCard(self.fly, e.item, from, self:_pawnSpot(e.p), speed)
		local extra = ""
		if e.target then
			extra = " on " .. self:_tag(e.target)
		end
		feed:add(self:_tag(e.p) .. " used " .. (if def then def.name else "a card") .. extra, nil, e.item, Theme.Category[def and def.category or "neutral"])
	elseif t == "ability" then
		local p = self:_player(e.p)
		local cdef = Characters.get(p and p.character or "")
		local ab = cdef and cdef.ability
		if p and ab and ab.recharge ~= "perTurn" then
			p.abilityReady = false
			p.abilityProgress = 0
		end
		if e.p == self.mySeat then
			v.abilityUsed = true
		end
		Overlays.abilityBanner(self.fx, p and p.character or "mage", ab and ab.name or "Ability", self:_name(e.p), speed)
		Effects.ability(board, e.ability, e.p, e.target)
		feed:add(self:_tag(e.p) .. " used " .. (if ab then ab.name else "an ability") .. (if e.target then (" on " .. self:_tag(e.target)) else ""), nil, p and p.character or "info", Theme.Character[p and p.character or ""] or C.brassDark)
		self:_refresh()
	elseif t == "swap" then
		local a, b = self:_player(e.a), self:_player(e.b)
		if a then
			a.tile = e.ta
		end
		if b then
			b.tile = e.tb
		end
		feed:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped places", nil, "swap", C.neutral)
		board:swap(e.a, e.b, e.ta, e.tb)
	elseif t == "handSwap" then
		self.chips:flash(e.a, C.neutral)
		self.chips:flash(e.b, C.neutral)
		local a, b = self:_player(e.a), self:_player(e.b)
		if a and e.countA then
			a.handCount = e.countA
		end
		if b and e.countB then
			b.handCount = e.countB
		end
		if e.hand and (e.a == self.mySeat or e.b == self.mySeat) then
			v.hand = copy(e.hand)
			v.armed = {}
			self.hand:setHand(v.hand, v.armed)
		end
		self.chips:update(v.players)
		feed:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped hands!", nil, "jeopardy_potion", C.potion)
	elseif t == "give" then
		self:_lose(e.p, e.item)
		Overlays.flyIcon(self.fly, "book", C.wood, self:_chipSpot(e.p), self:_chipSpot(e.target), speed, self:_landing(function()
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
	elseif t == "recharge" then
		local p = self:_player(e.p)
		if p then
			p.abilityReady = true
			p.abilityProgress = 0
		end
		self.chips:flash(e.p, C.brass)
		if e.p == self.mySeat then
			feed:add("Your ability is charged!", C.gold, "sparkles", C.brass)
			self:_refresh()
		end
	elseif t == "removed" then
		v.placed[e.tile] = nil
		board:removePlaced(e.tile)
	elseif t == "fizzle" then
		board:floatText(board:tileWorld(e.tile), "FIZZLE", C.inkFaint)
	elseif t == "sands" then
		board:floatText(self:_pawnWorld(e.p), "SHIFTING SANDS", hex("B8862E"))
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
		feed:add(self:_tag(e.p) .. " visit" .. (if e.p == self.mySeat then "" else "s") .. " the Potion Seller", nil, "token_potion", C.potion)
	elseif t == "shopClose" then
		v.phase = "action"
		if self.shop and e.p == self.mySeat then
			self.shop:close()
			self.shop = nil
		end
	elseif t == "arm" then
		if e.p == self.mySeat then
			v.armed[e.item] = if e.on then true else nil
			self.hand:setArmed(v.armed)
			local def = Items.get(e.item)
			feed:add((if def then def.name else "Boost") .. (if e.on then " is ready for this roll" else " put away"), nil, e.item, C.assist)
		end
	elseif t == "left" then
		local p = self:_player(e.p)
		if p then
			p.isBot = true
			p.name = e.name or p.name
		end
		feed:add((e.name or "A player") .. " left. A bot takes over.", nil, "exit", C.inkFaint)
	end
end

-- Cards placed on the board appear as they land (the snapshot that follows confirms them).
function MatchScreen:_playPlace(e, speed: number)
	local def = Items.get(e.item)
	local v = self.view
	self:_lose(e.p, e.item)
	local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_chipSpot(e.p)
	local board = self.board
	Overlays.flyCard(self.fly, e.item, from, self:_tileSpot(e.tile), speed, self:_landing(function()
		if def and def.category == "natural" then
			v.natural[e.tile] = def.natural
			board:setNatural(e.tile, def.natural)
		else
			local entry = { tile = e.tile, item = e.item, owner = e.p, dir = e.dir, tiles = nil }
			if e.item == "conveyor" then
				entry.tiles = board.board:span(e.tile, Rules.ConveyorLength)
			end
			v.placed[e.tile] = entry
			board:placeItem(entry, true)
		end
		Sound.play("place")
	end))
	self.feed:add(self:_tag(e.p) .. " placed " .. (if def then def.name else "a card"), nil, e.item, Theme.Category[def and def.category or "trap"])
end

function MatchScreen:_pawnWorld(seat: number): Vector2
	return self.board:pawnWorld(seat)
end

---------------------------------------------------------------------------
-- your actions
---------------------------------------------------------------------------

function MatchScreen:_cmd(cmd)
	if self.busy then
		return
	end
	self.busy = true
	self:_refresh()
	local ok, err = Net.request("match.cmd", { cmd = cmd })
	self.busy = false
	if not ok then
		Widgets.toast(tostring(err), "error")
	end
	self:_refresh()
end

function MatchScreen:_roll()
	if not self:_myTurn() then
		return
	end
	Sound.play("click")
	self:_cmd({ type = "roll" })
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
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.R then
		self:_roll()
	elseif key == Enum.KeyCode.E or key == Enum.KeyCode.Q then
		self:_abilityClicked()
	else
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
end

--[[
	A hint strip across the top of the board ("Pick a tile for Spike") with Cancel
	(Esc works too) and, on touch screens, a Place button once a tile is chosen.
	Returns close() and setConfirm(text?, onConfirm?).
]]
function MatchScreen:_hint(text: string, onCancel: () -> ())
	local strip = Util.new("Frame", {
		Name = "Hint",
		BackgroundColor3 = hex("1F150E"),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 70,
		Parent = self.root,
	})
	Util.corner(strip, 12)
	Util.stroke(strip, C.brass, 2)
	local label = Widgets.label(strip, {
		text = text,
		font = "heavy",
		size = 16,
		color = C.parchment,
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
	local function setConfirm(newText: string?, onConfirm: (() -> ())?)
		if newText then
			label.Text = newText
		end
		confirm.root.Visible = onConfirm ~= nil
		if onConfirm then
			confirm:setOnClick(onConfirm)
		end
		self.confirmTarget = onConfirm
		layout()
	end
	return close, setConfirm
end

-- Choose a tile for `itemId` (only tiles the rules allow light up).
function MatchScreen:_placeFlow(itemId: string)
	local def = Items.get(itemId)
	local boardData = self.board.board
	local layers = Engine.layersFromSnapshot(boardData, self:_viewAsSnap())
	local valid = {}
	for id in boardData.tiles do
		if Engine.checkPlacement(boardData, layers, itemId, id, "fwd") then
			table.insert(valid, id)
		end
	end
	if #valid == 0 then
		Widgets.toast("There's nowhere to put that right now.", "error")
		return
	end
	table.sort(valid)
	self.targeting = true
	self:_refresh()
	-- show the whole board while choosing
	self.board:fit()
	local touch = Root.metrics.touch
	local closeHint, setConfirm
	local function finish()
		self.targeting = false
		self.cancelTarget = nil
		self.board:clearHighlight()
		if closeHint then
			closeHint()
		end
		self:_refresh()
	end
	local function commit(tile: number)
		finish()
		if itemId == "conveyor" then
			Inspector.choose(self.popups, "Conveyor Belt", "Which way should the belt carry people?", {
				{ text = "FORWARD", value = "fwd", style = "green", width = 150 },
				{ text = "BACKWARD", value = "back", style = "red", width = 150 },
			}, function(dir)
				self:_cmd({ type = "use", item = itemId, tile = tile, dir = dir })
			end)
		else
			self:_cmd({ type = "use", item = itemId, tile = tile })
		end
	end
	local prompt = if touch then ("Tap a glowing tile for " .. def.name) else ("Click a glowing tile for " .. def.name)
	closeHint, setConfirm = self:_hint(prompt, finish)
	self.cancelTarget = finish
	self.board:highlight(valid, Theme.Category[def.category] or C.brass, commit, {
		confirm = touch,
		preview = itemId,
		onSelect = function(tile)
			setConfirm("Place " .. def.name .. " on tile " .. tile .. "?", function()
				commit(tile)
			end)
		end,
	})
end

-- Pick a player from the chips.
function MatchScreen:_pickPlayer(prompt: string, seats: { number }, onPick: (number) -> ())
	if #seats == 0 then
		Widgets.toast("There's nobody you can pick right now.", "error")
		return
	end
	self.targeting = true
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

function MatchScreen:_cardClicked(itemId: string, _index: number)
	local def = Items.get(itemId)
	if not def or self.targeting then
		return
	end
	local mine = self:_myTurn()
	local actions = {}
	local use = def.use
	local v = self.view
	local armed = v.armed[itemId] == true
	if use == "passive" then
		table.insert(actions, { text = "Works automatically. Keep it in your hand.", disabled = true })
	elseif not mine then
		table.insert(actions, { text = "You can play this on your turn.", disabled = true })
	elseif use == "place" then
		table.insert(actions, { text = "PLACE IT", icon = "map", style = "green", onClick = function()
			self:_placeFlow(itemId)
		end })
	elseif use == "boost" then
		table.insert(actions, { text = if armed then "PUT IT AWAY" else "USE ON MY ROLL", style = "brass", width = 240, onClick = function()
			self:_cmd({ type = "arm", item = itemId })
		end })
	elseif use == "regen" then
		local me = self:_player(self.mySeat)
		table.insert(actions, { text = "RECHARGE", style = "green", disabled = me ~= nil and me.abilityReady, onClick = function()
			self:_cmd({ type = "use", item = itemId })
		end })
	elseif use == "anchor" then
		table.insert(actions, { text = "DROP ANCHOR", style = "purple", onClick = function()
			self:_cmd({ type = "use", item = itemId })
		end })
	elseif use == "moonwalk" then
		table.insert(actions, { text = "MOONWALK", style = "blue", onClick = function()
			local me = self:_player(self.mySeat)
			local max = Rules.MoonwalkMax
			if me and me.burning then
				max = math.max(1, max // 2)
			end
			local options = {}
			for n = 1, max do
				table.insert(options, { text = tostring(n), value = n, style = "blue", width = 80 })
			end
			Inspector.choose(self.popups, "Moonwalk", "How many tiles back?", options, function(n)
				self:_cmd({ type = "use", item = itemId, steps = n })
			end)
		end })
	elseif use == "telepathy" then
		table.insert(actions, { text = "MOVE A PLAYER", style = "purple", width = 230, onClick = function()
			self:_pickPlayer("Telepathy: who do you want to move?", self:_allSeats(false), function(seat)
				local options = {}
				for n = -Rules.TelepathyMax, Rules.TelepathyMax do
					if n ~= 0 then
						table.insert(options, { text = (if n > 0 then "+" else "") .. n, value = n, style = if n > 0 then "green" else "red", width = 66 })
					end
				end
				Inspector.choose(self.popups, "Telepathy", "Move " .. self:_name(seat) .. " back (-) or forward (+)", options, function(n)
					self:_cmd({ type = "use", item = itemId, target = seat, steps = n })
				end)
			end)
		end })
	elseif use == "jeopardy" then
		table.insert(actions, { text = "PICK A RIVAL", style = "red", onClick = function()
			self:_pickPlayer("Double Jeopardy: swap hands with who?", self:_allSeats(true), function(seat)
				self:_cmd({ type = "use", item = itemId, target = seat })
			end)
		end })
	end
	-- team modes: once you're finished, you can hand cards to teammates (free)
	local me = self:_player(self.mySeat)
	if mine and self.isTeam and me and me.finished then
		local mates = {}
		for seat, p in v.players do
			if p.team == me.team and seat ~= self.mySeat then
				table.insert(mates, seat)
			end
		end
		if #mates > 0 then
			table.insert(actions, { text = "GIVE", icon = "plus", style = "blue", onClick = function()
				self:_pickPlayer("Give " .. def.name .. " to which teammate?", mates, function(seat)
					self:_cmd({ type = "give", item = itemId, target = seat })
				end)
			end })
		end
	end
	Inspector.item(self.popups, itemId, actions)
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
	if not me.abilityReady or self.view.abilityUsed then
		Widgets.toast(if self.view.abilityUsed then "You already used your ability this turn." else "Your ability is still recharging.", "error")
		return
	end
	local function send(target: number?, option: string?)
		self:_cmd({ type = "ability", target = target, option = option })
	end
	local function withOption(target: number)
		if not ab.options then
			send(target, nil)
			return
		end
		local t = self:_player(target)
		local options = {}
		if ab.id == "hex" then
			options = {
				{ text = "FREEZE", value = "freeze", style = "blue", width = 150, disabled = t ~= nil and t.character == "mage" },
				{ text = "BURN", value = "burn", style = "red", width = 150 },
			}
		elseif ab.id == "nudge" then
			options = {
				{ text = "BACK 1", value = "back", style = "red", width = 150, disabled = t ~= nil and (t.trailLength or 0) <= 1 },
				{ text = "FORWARD 1", value = "fwd", style = "green", width = 150 },
			}
		end
		Inspector.choose(self.popups, ab.name, ab.text, options, function(opt)
			send(target, opt)
		end)
	end
	if ab.target == "none" then
		send(nil, nil)
		return
	end
	local seats = {}
	for seat, p in self.view.players do
		local ok = true
		if ab.target ~= "any" and seat == self.mySeat then
			ok = false
		end
		if ab.target == "sameTile" and p.tile ~= me.tile then
			ok = false
		end
		if ab.id == "warp" and p.tile == me.tile then
			ok = false
		end
		if ok then
			table.insert(seats, seat)
		end
	end
	table.sort(seats)
	if ab.target == "sameTile" and #seats == 0 then
		Widgets.toast("Nobody is standing on your tile.", "error")
		return
	end
	self:_pickPlayer(ab.name .. ": pick a player", seats, withOption)
end

---------------------------------------------------------------------------
-- shop, emotes, menu, scoreboard, results
---------------------------------------------------------------------------

function MatchScreen:_openShop()
	local me = self:_player(self.mySeat)
	if not me then
		return
	end
	self.shop = Shop.open(self.popups, {
		coins = me.coins,
		stock = self.view.stock or {},
		hand = self.view.hand or {},
		onBuy = function(itemId)
			self:_cmd({ type = "buy", item = itemId })
		end,
		onDone = function()
			self:_cmd({ type = "shopDone" })
		end,
	})
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

-- Everyone at a glance: treasures, coins, cards, deaths, traps placed.
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
	local width = if narrow then 400 else 640
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
			BackgroundColor3 = if p.seat == self.mySeat then hex("FFF1C4") else hex("FBF3DD"),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = i,
			Parent = list,
		})
		Util.corner(row, 10)
		Util.stroke(row, C.parchmentEdge, 1.5)
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
			sizeUDim = UDim2.new(if narrow then 0.5 else 0.38, -54, 0, 20),
			position = UDim2.fromOffset(54, 6),
		})
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local cdef = Characters.get(p.character or "")
		Widgets.label(row, {
			text = (if info.username and not p.isBot then ("@" .. info.username .. " · ") else "") .. (if cdef then cdef.name else ""),
			font = "body",
			size = 12,
			color = C.inkSoft,
			sizeUDim = UDim2.new(if narrow then 0.5 else 0.38, -54, 0, 16),
			position = UDim2.fromOffset(54, 27),
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local stats = Util.frame(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(if narrow then 0.5 else 0.6, -10, 1, 0),
		})
		Util.list(stats, "x", 10, "Right", "Center")
		local function stat(icon: string, color: Color3, value: any, order: number)
			local box = Util.frame(stats, { Size = UDim2.fromOffset(46, 24), LayoutOrder = order })
			local ic = Util.frame(box, { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 2) })
			Icons.medallion(ic, icon, color, { Size = UDim2.fromScale(1, 1) })
			Widgets.label(box, {
				text = tostring(value),
				font = "chunky",
				size = 17,
				color = C.ink,
				sizeUDim = UDim2.fromOffset(24, 24),
				position = UDim2.fromOffset(22, 0),
			})
		end
		stat("x_mark", C.inkRed, p.treasures or 0, 1)
		stat("coin", C.brassDark, p.coins or 0, 2)
		stat("book", C.woodDark, p.handCount or 0, 3)
		if not narrow and p.stats then
			stat("skull", C.bad, p.stats.deaths or 0, 4)
			stat("spike", C.trap, p.stats.placed or 0, 5)
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
	local soundOn = Sound.isEnabled()
	local soundButton
	soundButton = Widgets.button(list, {
		text = if soundOn then "SOUND: ON" else "SOUND: OFF",
		style = "wood",
		textSize = 20,
		size = UDim2.fromOffset(280, 50),
		layoutOrder = 1,
		onClick = function()
			soundOn = not soundOn
			Sound.setEnabled(soundOn)
			saveSetting("sfx", soundOn)
			soundButton:setText(if soundOn then "SOUND: ON" else "SOUND: OFF")
		end,
	})
	local musicOn = Sound.isMusicEnabled()
	local musicButton
	musicButton = Widgets.button(list, {
		text = if musicOn then "MUSIC: ON" else "MUSIC: OFF",
		style = "wood",
		textSize = 20,
		size = UDim2.fromOffset(280, 50),
		layoutOrder = 2,
		onClick = function()
			musicOn = not musicOn
			Sound.setMusicEnabled(musicOn)
			saveSetting("music", musicOn)
			musicButton:setText(if musicOn then "MUSIC: ON" else "MUSIC: OFF")
		end,
	})
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
				color = C.textDark,
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

return MatchScreen
