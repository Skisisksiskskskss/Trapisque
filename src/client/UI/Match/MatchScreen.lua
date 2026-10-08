--[[
	MatchScreen
	The whole match: the treasure map in the middle, the players down the right and
	your hand along the bottom.

	The server sends batches of events ("match.events"). They're queued and played back
	one by one at the pace the server expects (Shared/Game/Pacing), then the snapshot
	that came with the batch is applied, so the screen always ends up exactly in sync.

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
local CosmeticArt = require(UI.CosmeticArt)
local Root = require(UI.Root)
local BoardView = require(script.Parent.BoardView)
local PlayersPanel = require(script.Parent.PlayersPanel)
local HandBar = require(script.Parent.HandBar)
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

local SIDE_W = 270
local HAND_H = 178
local TOP_H = 46
local GAP = 10

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

local function toHex(c: Color3): string
	return c:ToHex()
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
	if not payload.resync then
		-- the opening cards are dealt by animation; show an empty hand until then
		self.snap = table.clone(payload.snapshot)
		self.snap.hand = {}
	end
	self.deadline = payload.deadline or 0
	self.queue = {}
	self.holding = false -- true while the intro plays (events wait their turn)
	self.playing = false
	self.busy = false
	self.alive = true
	self.speed = 1
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
		if self.alive and data.id == self.id then
			self.players:emote(data.seat, data.emote)
		end
	end))
	self.maid:add(Net.on("match.end", function(data)
		if self.alive and data.id == self.id then
			self:_showResults(data)
		end
	end))

	if payload.resync then
		self:_applySnapshot(payload)
	else
		task.spawn(function()
			self:_intro(payload)
		end)
	end
	return self
end

function MatchScreen:_build(container: Frame)
	local root = Util.frame(container, { Name = "Match" })
	self.root = root
	local top = Root.topInset()

	-- right column: the players
	local side = Util.frame(root, {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -GAP, 0, top),
		Size = UDim2.new(0, SIDE_W, 1, -(top + GAP)),
	})
	self.players = PlayersPanel.new(side, self:_seatList(), self.target, self.mySeat, self.isTeam)

	-- left: top bar, board, hand
	local leftW = -(SIDE_W + 3 * GAP)
	local topBar = Util.frame(root, {
		Name = "TopBar",
		Position = UDim2.new(0, GAP, 0, top),
		Size = UDim2.new(1, leftW, 0, TOP_H),
	})
	self:_buildTopBar(topBar)

	local boardHolder = Util.frame(root, {
		Name = "BoardArea",
		Position = UDim2.new(0, GAP, 0, top + TOP_H + 6),
		Size = UDim2.new(1, leftW, 1, -(top + TOP_H + 6 + HAND_H + 2 * GAP)),
	})
	self.boardHolder = boardHolder
	self.board = BoardView.new(boardHolder, self.mapDef.id)

	local handHolder = Util.frame(root, {
		Name = "HandArea",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, GAP, 1, -GAP),
		Size = UDim2.new(1, leftW, 0, HAND_H),
	})
	local me = self.seats[self.mySeat]
	self.hand = HandBar.new(handHolder, { character = me and me.character, seat = self.mySeat })
	self.hand.onRoll = function()
		self:_roll()
	end
	self.hand.onCard = function(id, index)
		self:_cardClicked(id, index)
	end
	self.hand.onAbility = function()
		self:_abilityClicked()
	end
	self.hand.onRecall = function()
		self:_cmd({ type = "recall" })
	end
	self.hand.onPortrait = function()
		if me and me.character then
			Inspector.character(self.popups, me.character)
		end
	end

	-- layers above everything: board-area effects, things flying across the screen, popups
	self.fx = Util.frame(root, {
		Name = "Fx",
		Position = boardHolder.Position,
		Size = boardHolder.Size,
		ZIndex = 50,
	})
	self.fly = Util.frame(root, { Name = "Fly", ZIndex = 60 })
	self.popups = Util.frame(root, { Name = "Popups", ZIndex = 80 })
	self.log = Overlays.log(self.fx)

	-- pawns
	for _, p in self.snap.players do
		local info = self.seats[p.seat] or {}
		self.board:addPawn(p.seat, { look = info.look, character = p.character, name = p.name }, p.tile)
	end
	self.board:applySnapshot(self.snap)
	self.players:update(self.snap)
	self:_refreshControls()

	-- timers, keys
	self.maid:add(RunService.RenderStepped:Connect(function()
		self.players:tick(workspace:GetServerTimeNow())
	end))
	self.maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and self.cancelTarget then
			self.cancelTarget()
		elseif (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.R) and self:_myTurn() then
			self:_roll()
		end
	end))
end

function MatchScreen:_seatList()
	local list = {}
	for _, p in self.snap.players do
		local info = self.seats[p.seat] or {}
		table.insert(list, {
			seat = p.seat,
			name = p.name,
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

function MatchScreen:_buildTopBar(bar: Frame)
	local plate = Util.new("Frame", {
		Name = "Plate",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 360, 1, 0),
		Parent = bar,
	})
	Util.corner(plate, 10)
	Util.stroke(plate, C.burn, 2)
	local lengthName = ({ quick = "Quick", standard = "Standard", classic = "Classic" })[self.length or ""] or ""
	local modeName = if self.mode then self.mode.name else ""
	self.roundLabel = Widgets.label(plate, {
		text = "",
		font = "chunky",
		size = 20,
		color = C.ink,
		sizeUDim = UDim2.new(0, 110, 1, 0),
		position = UDim2.fromOffset(12, 0),
	})
	Widgets.label(plate, {
		text = modeName .. (if lengthName ~= "" then "  ·  " .. lengthName else "") .. "  ·  First to " .. tostring(self.target),
		font = "heavy",
		size = 15,
		color = C.inkSoft,
		sizeUDim = UDim2.new(1, -130, 1, 0),
		position = UDim2.fromOffset(122, 0),
	}).TextTruncate = Enum.TextTruncate.AtEnd

	local buttons = Util.frame(bar, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 260, 1, 0),
	})
	Util.list(buttons, "x", 8, "Right", "Center")
	local function iconButton(order: number, icon: string, style: string, onClick: () -> ())
		Widgets.iconButton(buttons, {
			icon = icon,
			style = style,
			size = UDim2.fromOffset(44, 44),
			layoutOrder = order,
			onClick = onClick,
		})
	end
	iconButton(1, "minus", "parchment", function()
		self.board:setZoom(self.board.zoom / 1.25)
	end)
	iconButton(2, "plus", "parchment", function()
		self.board:setZoom(self.board.zoom * 1.25)
	end)
	iconButton(3, "smile", "brass", function()
		self:_emotePicker()
	end)
	iconButton(4, "gear", "wood", function()
		self:_menu()
	end)
	self:_updateRound()
end

function MatchScreen:_updateRound()
	if self.roundLabel then
		self.roundLabel.Text = "Round " .. tostring(math.max(1, self.snap.round or 1))
	end
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
	for _, p in self.snap.players do
		if p.seat == seat then
			return p
		end
	end
	return nil
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

-- "<font color=...>Name</font>" for the log
function MatchScreen:_tag(seat: number?): string
	if not seat then
		return "?"
	end
	local color = Theme.Seat[((seat - 1) % 6) + 1]
	return string.format('<font color="#%s">%s</font>', toHex(color), self:_name(seat))
end

function MatchScreen:_seatColor(seat: number): Color3
	return Theme.Seat[((seat - 1) % 6) + 1]
end

function MatchScreen:_myTurn(): boolean
	local s = self.snap
	return s.current == self.mySeat
		and s.phase == "action"
		and not self.playing
		and not self.holding
		and #self.queue == 0
		and not self.busy
		and not self.targeting
end

-- absolute screen position -> position inside the match root (virtual pixels)
function MatchScreen:_toRoot(abs: Vector2): Vector2
	local root = self.root :: Frame
	return (abs - root.AbsolutePosition) / Util.inheritedScale(root, true)
end

function MatchScreen:_worldToRoot(world: Vector2): Vector2
	local w = self.board.world
	local k = w.AbsoluteSize.X / math.max(1, self.board.worldW)
	return self:_toRoot(w.AbsolutePosition + world * k)
end

function MatchScreen:_pawnSpot(seat: number): Vector2
	local pawn = self.board.pawns[seat]
	if not pawn then
		return self:_boardCenter()
	end
	return self:_toRoot(pawn.frame.AbsolutePosition + pawn.frame.AbsoluteSize / 2)
end

function MatchScreen:_tileSpot(tile: number): Vector2
	return self:_worldToRoot(self.board:tileWorld(tile))
end

function MatchScreen:_playerSpot(seat: number): Vector2
	local card = self.players:cardOf(seat)
	if not card then
		return self:_boardCenter()
	end
	return self:_toRoot(card.AbsolutePosition + card.AbsoluteSize / 2)
end

function MatchScreen:_handSpot(index: number?): Vector2
	local abs = self.hand:cardCenter(index)
	return if abs then self:_toRoot(abs) else self:_boardCenter()
end

function MatchScreen:_boardCenter(): Vector2
	local h = self.boardHolder
	return self:_toRoot(h.AbsolutePosition + h.AbsoluteSize / 2)
end

local function cosmeticOf(info, category: string): string?
	local look = info and info.look
	return look and look[category] or Cosmetics.defaults[category]
end

---------------------------------------------------------------------------
-- event playback
---------------------------------------------------------------------------

function MatchScreen:_intro(payload)
	local intro = payload.intro or 0
	if intro > 0 then
		self.playing = true
		self:_refreshControls()
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
	self:_refreshControls()
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
		if self.alive then
			self:_applySnapshot(payload)
		end
	end
	self.draining = false
	self.playing = false
	if self.alive then
		self:_refreshControls()
	end
end

function MatchScreen:_applySnapshot(payload)
	local snap = payload.snapshot
	if not snap then
		return
	end
	self.snap = snap
	self.deadline = payload.deadline or 0
	self.board:applySnapshot(snap)
	self.board:setCurrent(if snap.phase ~= "over" then snap.current else nil)
	self.players:update(snap)
	self.players:setCurrent(if snap.phase ~= "over" then snap.current else nil, self.deadline)
	self:_updateRound()
	if self.shop and not (snap.phase == "shop" and snap.current == self.mySeat) then
		self.shop:close()
		self.shop = nil
	end
	self:_refreshControls()
end

function MatchScreen:_refreshControls()
	if not self.hand then
		return
	end
	local snap = self.snap
	local me = self:_player(self.mySeat)
	local mine = self:_myTurn()
	local armed = {}
	for _, id in snap.armed or {} do
		armed[id] = true
	end
	self.hand:setHand(snap.hand or {}, armed)
	self.hand:setTurn({
		mine = snap.current == self.mySeat,
		phase = snap.phase,
		waitingFor = if snap.current ~= self.mySeat then self:_name(snap.current) else nil,
		anchor = me and me.anchor or 0,
		busy = not mine,
	})
	if me then
		self.hand:setAbility(me.abilityReady, me.abilityProgress or 0, snap.abilityUsed == true, mine)
	end
	-- the Potion Seller opens on your turn in the shop phase
	if snap.phase == "shop" and snap.current == self.mySeat and not self.playing and not self.shop then
		self:_openShop()
	elseif self.shop and me then
		self.shop:update(me.coins, snap.stock or {}, snap.hand or {})
	end
end

-- Plays one event; may yield (dice, hops, spins). The caller pads to Pacing time.
function MatchScreen:_play(e)
	local speed = self.speed
	local t = e.t
	local board = self.board
	local log = self.log

	if t == "setup" then
		return
	elseif t == "deal" then
		local n = #(e.items or {})
		log:add(self:_tag(e.p) .. " start" .. (if e.p == self.mySeat then "" else "s") .. " with " .. n .. " card" .. (if n == 1 then "" else "s"))
		for i, item in e.items or {} do
			task.delay((i - 1) * 0.15 * speed, function()
				if e.p == self.mySeat then
					Overlays.flyCard(self.fly, item, self:_boardCenter(), self:_handSpot(nil), speed)
				else
					Overlays.flyIcon(self.fly, "book", C.wood, self:_boardCenter(), self:_playerSpot(e.p), speed)
				end
			end)
		end
	elseif t == "turn" then
		self.snap.round = e.round
		self.snap.current = e.p
		self:_updateRound()
		board:setCurrent(e.p)
		self.players:setCurrent(e.p, nil)
		local mine = e.p == self.mySeat
		Overlays.turnBanner(self.fx, if mine then "Your turn!" else (self:_name(e.p) .. "'s turn"), self:_seatColor(e.p), mine, speed)
		board:follow(self:_player(e.p) and self:_player(e.p).tile or 1)
	elseif t == "skip" then
		log:add(self:_tag(e.p) .. " skip" .. (if e.p == self.mySeat then "" else "s") .. " a turn")
		board:floatText(self:_pawnWorld(e.p), "SKIP!", C.parchment)
	elseif t == "roll" then
		local info = self.seats[e.p]
		Overlays.dice(self.fx, e, cosmeticOf(info, "dice"), speed)
		if e.held then
			log:add(self:_tag(e.p) .. (if e.escaped then " broke free of the gate!" else " is still stuck at the gate"))
		else
			log:add(self:_tag(e.p) .. " rolled a " .. e.die .. (if e.move ~= e.die then (", moving " .. e.move) else ""))
		end
	elseif t == "move" then
		local info = self.seats[e.p]
		board:hop(e.p, e.path, e.kind, cosmeticOf(info, "trail"))
	elseif t == "spin" then
		local p = self:_player(e.p)
		local segments = Overlays.wheelSegments(e.wheel, self.mapDef, p and p.character)
		Overlays.spin(self.fx, e.wheel, segments, e.index, speed)
		local def = Items.get(e.result)
		log:add(self:_tag(e.p) .. " spun the " .. (WHEEL_NAME[e.wheel] or "") .. " wheel: " .. (if def then def.name else "?"))
	elseif t == "gain" then
		if e.p == self.mySeat then
			Overlays.flyCard(self.fly, e.item, self:_pawnSpot(e.p), self:_handSpot(nil), speed)
		else
			Overlays.flyIcon(self.fly, "book", C.wood, self:_pawnSpot(e.p), self:_playerSpot(e.p), speed)
		end
	elseif t == "handFull" then
		board:floatText(self:_pawnWorld(e.p), "HAND FULL", C.bad)
		log:add(self:_tag(e.p) .. "'s hand is full")
	elseif t == "coin" then
		Sound.play("coin")
		board:floatText(self:_pawnWorld(e.p), "+1 COIN", C.gold)
		Overlays.flyIcon(self.fly, "coin", C.brassDark, self:_pawnSpot(e.p), self:_playerSpot(e.p), speed)
		self:_patch(e.p, "coins", e.coins)
	elseif t == "trigger" then
		Effects.trap(board, e.item, e.tile)
		local def = Items.get(e.item)
		local owner = if e.owner and e.owner > 0 then (self:_tag(e.owner) .. "'s ") else "a "
		log:add(self:_tag(e.p) .. " hit " .. owner .. (if def then def.name else "trap"))
	elseif t == "shield" then
		Effects.shield(board, e.p)
		local def = Items.get(e.item)
		log:add(self:_tag(e.p) .. " shrugged off " .. (if def then def.name else "a trap") .. " with a Shield")
	elseif t == "death" then
		Effects.death(board, e.p)
		self.players:shake(e.p)
		local why = DEATH_TEXT[e.cause] or "was knocked out"
		log:add(self:_tag(e.p) .. " " .. why .. (if (e.lost or 0) > 0 then " and lost a treasure" else "") .. "!", C.bad)
		self:_patch(e.p, "treasures", e.treasures)
	elseif t == "phoenix" then
		Effects.phoenix(board, e.p)
		log:add(self:_tag(e.p) .. " rose from the ashes! (Phoenix Potion)", C.gold)
	elseif t == "treasure" then
		Effects.treasure(board, self.board.board.treasure, e.by or e.p)
		Sound.play("treasure")
		local who = self:_name(e.p)
		local sub = tostring(e.treasures) .. " / " .. tostring(self.target)
		Overlays.shout(self.fx, if e.p == self.mySeat then "TREASURE!" else (who .. " found a treasure!"), C.gold, speed, sub)
		if e.by then
			log:add(self:_tag(e.by) .. " carried a treasure home for " .. self:_tag(e.p), C.gold)
		else
			log:add(self:_tag(e.p) .. " found a treasure! (" .. sub .. ")", C.gold)
		end
		self:_patch(e.p, "treasures", e.treasures)
		self.players:flash(e.p, C.gold)
	elseif t == "lap" then
		log:add(self:_tag(e.p) .. " made it round again")
	elseif t == "finished" then
		Overlays.shout(self.fx, if e.p == self.mySeat then "ALL YOUR TREASURES!" else (self:_name(e.p) .. " has every treasure!"), C.gold, speed)
		log:add(self:_tag(e.p) .. " has every treasure!", C.gold)
	elseif t == "gameover" then
		local winners = {}
		for _, p in self.snap.players do
			if p.team == e.team then
				table.insert(winners, self:_name(p.seat))
			end
		end
		local text = if self.isTeam then ((Theme.TeamName[e.team] or "A team") .. " wins!") else (table.concat(winners, " & ") .. (if #winners == 1 and winners[1] == "You" then " win!" else " wins!"))
		Overlays.shout(self.fx, text, C.gold, speed * 1.4, if e.reason == "rounds" then "Out of rounds" else nil)
		Sound.play("win")
	elseif t == "natural" then
		Effects.natural(board, e.kind, e.tile)
		log:add(self:_tag(e.p) .. " " .. (NATURAL_TEXT[e.kind] or "hit a natural trap"))
	elseif t == "blocked" then
		Effects.blocked(board, e.tile)
		log:add("A Wall stops " .. self:_tag(e.p))
	elseif t == "grog" then
		local pawn = board.pawns[e.p]
		Effects.grogRoll(board, if pawn then pawn.tile else 1, e.roll, e.survived)
		log:add(self:_tag(e.p) .. (if e.survived then (" outran the Grog with a " .. e.roll .. "!") else (" rolled " .. e.roll .. "... the Grog wins")))
	elseif t == "snared" then
		board:floatText(self:_pawnWorld(e.p), "SNARED!", C.trap)
		log:add(self:_tag(e.p) .. " is snared and will skip a turn")
	elseif t == "status" then
		Effects.status(board, e.p, e.status)
		local pawn = board.pawns[e.p]
		if pawn then
			pawn[e.status] = true
			board:_statusMarks(e.p)
		end
		log:add(self:_tag(e.p) .. (if e.status == "burning" then " is burning!" else " is frozen!"))
	elseif t == "immune" then
		board:floatText(self:_pawnWorld(e.p), "IMMUNE", C.info)
	elseif t == "place" then
		self:_playPlace(e, speed)
	elseif t == "useCard" then
		local def = Items.get(e.item)
		local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_playerSpot(e.p)
		task.spawn(Overlays.flyCard, self.fly, e.item, from, self:_pawnSpot(e.p), speed)
		local extra = ""
		if e.target then
			extra = " on " .. self:_tag(e.target)
		end
		log:add(self:_tag(e.p) .. " used " .. (if def then def.name else "a card") .. extra)
	elseif t == "ability" then
		local p = self:_player(e.p)
		local cdef = Characters.get(p and p.character or "")
		local ab = cdef and cdef.ability
		Overlays.abilityBanner(self.fx, p and p.character or "mage", ab and ab.name or "Ability", self:_name(e.p), speed)
		Effects.ability(board, e.ability, e.p, e.target)
		log:add(self:_tag(e.p) .. " used " .. (if ab then ab.name else "an ability") .. (if e.target then (" on " .. self:_tag(e.target)) else ""))
	elseif t == "swap" then
		log:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped places")
		board:swap(e.a, e.b, e.ta, e.tb)
	elseif t == "handSwap" then
		self.players:flash(e.a, C.neutral)
		self.players:flash(e.b, C.neutral)
		log:add(self:_tag(e.a) .. " and " .. self:_tag(e.b) .. " swapped hands!")
	elseif t == "give" then
		Overlays.flyIcon(self.fly, "book", C.wood, self:_playerSpot(e.p), self:_playerSpot(e.target), speed)
		log:add(self:_tag(e.p) .. " gave a card to " .. self:_tag(e.target))
	elseif t == "recall" then
		Effects.recall(board, e.p)
		log:add(self:_tag(e.p) .. " traveled back in time")
	elseif t == "recharge" then
		self.players:flash(e.p, C.brass)
		if e.p == self.mySeat then
			log:add("Your ability is charged!", C.gold)
		end
	elseif t == "removed" then
		board:_removePlacedVisual(e.tile)
	elseif t == "fizzle" then
		board:floatText(board:tileWorld(e.tile), "FIZZLE", C.inkFaint)
	elseif t == "sands" then
		board:floatText(self:_pawnWorld(e.p), "SHIFTING SANDS", hex("B8862E"))
	elseif t == "buy" then
		local def = Items.get(e.item)
		self:_patch(e.p, "coins", e.coins)
		if self.shop and e.p == self.mySeat then
			self.shop:bought(e.item)
		end
		log:add(self:_tag(e.p) .. " bought " .. (if def then def.name else "a potion"))
	elseif t == "shop" then
		log:add(self:_tag(e.p) .. " visit" .. (if e.p == self.mySeat then "" else "s") .. " the Potion Seller")
	elseif t == "shopClose" then
		if self.shop and e.p == self.mySeat then
			self.shop:close()
			self.shop = nil
		end
	elseif t == "arm" then
		if e.p == self.mySeat then
			local def = Items.get(e.item)
			log:add((if def then def.name else "Boost") .. (if e.on then " is ready for this roll" else " put away"))
		end
	elseif t == "left" then
		log:add((e.name or "A player") .. " left. A bot takes over.")
	end
end

-- Cards placed on the board appear as soon as they're played (the snapshot that
-- follows the batch confirms them).
function MatchScreen:_playPlace(e, speed: number)
	local def = Items.get(e.item)
	local from = if e.p == self.mySeat then self:_handSpot(nil) else self:_playerSpot(e.p)
	Overlays.flyCard(self.fly, e.item, from, self:_tileSpot(e.tile), speed)
	local board = self.board
	if def and def.category == "natural" then
		board.natural[e.tile] = def.natural
		board:_paintTile(board.board.tiles[e.tile])
	elseif not board.placed[e.tile] then
		local entry = { tile = e.tile, item = e.item, owner = e.p, dir = e.dir, tiles = nil }
		if e.item == "conveyor" then
			entry.tiles = board.board:span(e.tile, Rules.ConveyorLength)
		end
		local f = board:_makePlaced(entry)
		f:SetAttribute("Item", e.item)
		board.placed[e.tile] = f
	end
	self.log:add(self:_tag(e.p) .. " placed " .. (if def then def.name else "a card"))
end

function MatchScreen:_pawnWorld(seat: number): Vector2
	return self.board:pawnWorld(seat)
end

-- Keep the players column current between snapshots (coins, treasures).
function MatchScreen:_patch(seat: number, field: string, value: any)
	if value == nil then
		return
	end
	local p = self:_player(seat)
	if p then
		p[field] = value
		self.players:update(self.snap)
	end
end

---------------------------------------------------------------------------
-- your actions
---------------------------------------------------------------------------

function MatchScreen:_cmd(cmd)
	if self.busy then
		return
	end
	self.busy = true
	self:_refreshControls()
	local ok, err = Net.request("match.cmd", { cmd = cmd })
	self.busy = false
	if not ok then
		Widgets.toast(tostring(err), "error")
	end
	self:_refreshControls()
end

function MatchScreen:_roll()
	if not self:_myTurn() then
		return
	end
	Sound.play("click")
	self:_cmd({ type = "roll" })
end

-- A hint strip across the top of the board with a Cancel button (Esc works too).
function MatchScreen:_hint(text: string, onCancel: () -> ()): () -> ()
	local strip = Util.new("Frame", {
		Name = "Hint",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(520, 52),
		ZIndex = 70,
		Parent = self.fx,
	})
	Util.corner(strip, 12)
	Util.stroke(strip, C.brassDark, 3)
	Widgets.label(strip, {
		text = text,
		font = "heavy",
		size = 18,
		color = C.textDark,
		sizeUDim = UDim2.new(1, -150, 1, 0),
		position = UDim2.fromOffset(16, 0),
		z = 71,
	}).TextTruncate = Enum.TextTruncate.AtEnd
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		strip:Destroy()
	end
	Widgets.button(strip, {
		text = "CANCEL",
		style = "red",
		textSize = 17,
		size = UDim2.fromOffset(120, 40),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, -2),
		z = 72,
		onClick = function()
			close()
			onCancel()
		end,
	})
	Util.popIn(strip, 0.25, 0.7)
	return close
end

-- Choose a tile for `itemId` (only tiles the rules allow light up).
function MatchScreen:_placeFlow(itemId: string)
	local def = Items.get(itemId)
	local boardData = self.board.board
	local layers = Engine.layersFromSnapshot(boardData, self.snap)
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
	self:_refreshControls()
	local closeHint
	local function finish()
		self.targeting = false
		self.cancelTarget = nil
		self.board:clearHighlight()
		if closeHint then
			closeHint()
		end
		self:_refreshControls()
	end
	closeHint = self:_hint("Pick a tile for " .. def.name, finish)
	self.cancelTarget = finish
	self.board:highlight(valid, Theme.Category[def.category] or C.brass, function(tile)
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
	end)
end

-- Pick a player from the column on the right.
function MatchScreen:_pickPlayer(prompt: string, seats: { number }, onPick: (number) -> ())
	if #seats == 0 then
		Widgets.toast("There's nobody you can pick right now.", "error")
		return
	end
	self.targeting = true
	self:_refreshControls()
	local closeHint
	local function finish()
		self.targeting = false
		self.cancelTarget = nil
		self.players:clearPick()
		if closeHint then
			closeHint()
		end
		self:_refreshControls()
	end
	closeHint = self:_hint(prompt, finish)
	self.cancelTarget = finish
	self.players:pick(seats, function(seat)
		finish()
		onPick(seat)
	end)
end

function MatchScreen:_allSeats(exceptMe: boolean): { number }
	local out = {}
	for _, p in self.snap.players do
		if not (exceptMe and p.seat == self.mySeat) then
			table.insert(out, p.seat)
		end
	end
	return out
end

function MatchScreen:_cardClicked(itemId: string, _index: number)
	local def = Items.get(itemId)
	if not def then
		return
	end
	local mine = self:_myTurn()
	local actions = {}
	local use = def.use
	local snap = self.snap
	local armed = table.find(snap.armed or {}, itemId) ~= nil
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
		for _, p in snap.players do
			if p.team == me.team and p.seat ~= self.mySeat then
				table.insert(mates, p.seat)
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
	for _, p in self.snap.players do
		local ok = true
		if ab.target ~= "any" and p.seat == self.mySeat then
			ok = false
		end
		if ab.target == "sameTile" and p.tile ~= me.tile then
			ok = false
		end
		if ab.id == "warp" and p.tile == me.tile then
			ok = false
		end
		if ok then
			table.insert(seats, p.seat)
		end
	end
	if ab.target == "sameTile" and #seats == 0 then
		Widgets.toast("Nobody is standing on your tile.", "error")
		return
	end
	self:_pickPlayer(ab.name .. ": pick a player", seats, withOption)
end

---------------------------------------------------------------------------
-- shop, emotes, menu, results
---------------------------------------------------------------------------

function MatchScreen:_openShop()
	local me = self:_player(self.mySeat)
	if not me then
		return
	end
	self.shop = Shop.open(self.popups, {
		coins = me.coins,
		stock = self.snap.stock or {},
		hand = self.snap.hand or {},
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
	local content, close = Widgets.modal(self.popups, {
		title = "Emotes",
		titleWidth = 220,
		width = 520,
		height = 150 + math.ceil(#emotes / 3) * 54,
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

function MatchScreen:_menu()
	local content, close = Widgets.modal(self.popups, {
		title = "Menu",
		titleWidth = 200,
		width = 420,
		height = 300,
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
			soundButton:setText(if soundOn then "SOUND: ON" else "SOUND: OFF")
		end,
	})
	Widgets.button(list, {
		text = "LEAVE MATCH",
		icon = "exit",
		style = "red",
		textSize = 20,
		size = UDim2.fromOffset(280, 50),
		layoutOrder = 2,
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
