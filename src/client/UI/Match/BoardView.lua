--[[
	BoardView
	Draws a Trapisque map (a pirate island, a sea fortress, a swamp: MapArt paints the
	scene BoardLayout works out) and animates everything on it.

	The map is built once in "world" pixels (U px per map unit), seen a little from the
	side: the ground is squashed top to bottom (BoardLayout.Style.squash; MapArt.project),
	so a round tile is an ellipse with a short side under it, and the pieces stand up on
	the tiles, the middle of each one's base on its tile's middle. A camera fits the
	tiles into the part of the screen the HUD leaves free (setFocus) and lets players
	zoom (wheel, pinch, buttons) and pan (drag); the map runs on under the HUD.

	Reading order, bottom to top, is deliberate: the scene, then the tiles (stepping
	stones or slabs; whatever is on a tile sits on it: tokens, hazards, board pieces on
	their owner's colour, your own hidden traps see-through), then the characters
	standing on their tiles, the ones lower on the screen in front.

		view = BoardView.new(parent, mapId, { rotate = bool, board = "full" | "short" })
		view:setFocus(rect)                 -- stage rect the tiles should fill
		view:applySnapshot(snap)            -- tokens, placed items, natural traps, pawns
		view:hop(seat, path, kind)          -- animate a move (yields)
		view:moveToken(from, to)            -- a used token jumps to its new tile
		view:highlight(tiles, color, onPick, opts) -- let the player pick a tile
		view:showPath(path, opts)            -- where a die would take you (nil clears)
		view:setTraps(map) / addTrap / removeTrap -- the hidden traps you can see
		view:setMood(seat, mood, seconds)    -- a piece reacts (a hop, a shake, a wobble)
		view:tileWorld(tile) -> Vector2     -- centre of a tile in world pixels
		view:toStage(world) -> Vector2      -- world pixels -> stage pixels (for overlays)
		view:buildIntro()                   -- tiles drop into place one by one
		view:setGhosts(tiles) / driftGhosts(moves, speed) / boo(tile)   -- Haunted Hollow
		view:erupt(speed) / setRumble(on)   -- Mount Kaboom's volcano
		view:crackIce(tile, state) / refreeze(tiles) -- Frostbite Floes' thin ice
		view:setKraken(mark) / krakenSlam(speed) -- Kraken's Reach's arm (and its lair)
		view:setBridges(bridges, animate) / turnCogs(speed) -- Clockwork Cove
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Board = require(Shared.Game.Board)
local Rng = require(Shared.Game.Rng)
local Config = require(Shared.Config)
local Pacing = require(Shared.Game.Pacing)
local Items = require(Shared.Game.Items)
local Engine = require(Shared.Game.Engine)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local CosmeticArt = require(UI.CosmeticArt)
local BaseArt = require(UI.BaseArt)
local PieceArt = require(UI.PieceArt)
local Widgets = require(UI.Widgets)
local Art = require(UI.Art)
local BoardLayout = require(script.Parent.BoardLayout)
local MapArt = require(script.Parent.MapArt)
local StickerArt = require(UI.StickerArt)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local U = 46 -- world pixels per map unit
-- a Wanted poster's paper and ink
local POSTER = hex("F3E2B3")
local POSTER_INK = hex("6E2A18")
local S = BoardLayout.Style
local K = S.squash -- the ground, seen a little from the side, is this much shorter top to bottom
local PAWN = S.pawn -- a piece's square (map units) when it has a tile to itself
local PIECE_H = 1.04 -- the piece's height, in that square
local PIECE_FOOT = 0.95 -- where its foot is (on its own; a mastery stand lifts it)
local PIECE_BASE = 0.86 -- where the middle of its base (or its stand's) is: on the tile's middle
local MAX_ZOOM = 3
local HIT = 1.55 -- a tile's click area: this many map units wide (and as deep, squashed)
local BEVEL = 0.075 -- the lit / shaded rim round a tile's top (map units)

local NEUTRAL_ITEMS = { teleporter = true, spore_warper = true, conveyor = true, sands = true }

local BoardView = {}
BoardView.__index = BoardView

local function px(v: Vector2): UDim2
	return UDim2.fromOffset(v.X, v.Y)
end

-- Pieces (and ghosts) lower on the screen stand in front of the ones above.
local function depthZ(y: number): number
	return 10 + math.floor(y / 4)
end

-- A shape's see-through-ness and colour, whether it's a sprite or a frame.
local function alphaOf(obj: GuiObject): string
	return if obj:IsA("ImageLabel") then "ImageTransparency" else "BackgroundTransparency"
end
local function paint(obj: GuiObject, color: Color3)
	if obj:IsA("ImageLabel") then
		(obj :: ImageLabel).ImageColor3 = color
	else
		obj.BackgroundColor3 = color
	end
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function BoardView.new(parent: Frame, mapId: string, opts: { [string]: any }?)
	local self = setmetatable({}, BoardView)
	-- (a house rule can cut the trail short: opts.board = "short")
	local def = Maps.variant(Maps.get(mapId), opts and opts.board)
	self.def = def
	self.mapId = mapId
	self.board = Board.get(def)
	self.layout = BoardLayout.build(self.board, def, Rng, { rotate = opts ~= nil and opts.rotate == true })
	self.mySeat = opts and opts.mySeat
	self.round = 1 -- Shifting Sands show which way they slide this round
	-- the scene's inks for the tiles
	local col = {}
	for k, v in self.layout.scene.colors do
		col[k] = hex(string.sub(v, 2))
	end
	self.inks = col
	self.tileShape = self.layout.scene.tile or "stone"
	self.tileColors = {
		normal = col.tile,
		branch = Util.shade(col.tile, -0.18),
		start = col.start or C.sky,
		treasure = C.sun,
		shortcutGate = Util.shade(col.tile, -0.1),
	}
	self.maid = Util.maid()

	local L = self.layout
	self.worldW, self.worldH = L.w * U, L.h * U * K
	self.pos = {}
	self.ground = {} -- [tile] = where it is on the ground (map units)
	for _, t in L.tiles do
		self.pos[t.id] = MapArt.project(L, U, t.x, t.y)
		self.ground[t.id] = Vector2.new(t.x, t.y)
	end
	-- what the camera fits: the tiles on screen, with room above them for the pieces
	local v = L.view
	self.tileBox = {
		x0 = (v.x0 - L.x0) * U,
		y0 = (v.y0 - L.y0 * K) * U,
		x1 = (v.x1 - L.x0) * U,
		y1 = (v.y1 - L.y0 * K) * U,
	}

	-- the container covers the whole screen; the camera moves the world inside it
	self.container = Util.frame(parent, { Name = "Board" })
	self.world = Util.frame(self.container, {
		Name = "World",
		Size = UDim2.fromOffset(self.worldW, self.worldH),
	})
	self.scale = Util.new("UIScale", { Parent = self.world })
	-- screen-space bits that follow world things (name tags) but stay readable
	self.overlay = Util.frame(self.container, { Name = "Tags", ZIndex = 5 })

	self.layers = {}
	for i, name in { "Water", "Land", "Trail", "Props", "Tiles", "Pieces", "Pawns", "Fx", "Hits" } do
		self.layers[name] = Util.frame(self.world, { Name = name, ZIndex = i })
	end

	self.tileParts = {} -- [tile] = { root, side, rim, top, label, icon, skin, inlay, plaque, trap, ember }
	self.cover = {} -- [tile] = pawns resting on it
	self.belt = {} -- [tile] = which way the conveyor belt over it runs (degrees, on the ground)
	self.beltOf = {} -- [conveyor origin tile] = the tiles it covers
	self.tokens = {} -- [tile] = kind
	self.placed = {} -- [tile] = entry { item, owner, dir, tiles }
	self.natural = {} -- [tile] = kind
	self.traps = {} -- [tile] = { { item, owner, team, public } } hidden traps I can see
	self.embers = {} -- [tile] = owner seat
	self.cracks = {} -- Frostbite Floes: [tile] = true where the thin ice has cracked
	self.span = {} -- Clockwork Cove: [tile] = { angle (the way the trail crosses it, on the ground), up }
	self.leaves = {} -- [tile] = a raised drawbridge's leaf standing over it
	self.bandTiles = {} -- [tile] = { grad, spec, offset }: a conveyor's ridges, sands' ripples (moving)
	self.cogs = {} -- Clockwork Cove: [tile] = how far its cog carries you (tiles, + forward)
	self.pawns = {} -- [seat] = { frame, lift, share, tile, ring, seat, info, mascot (the piece), foot }
	self.seatInfo = {}

	-- camera
	self.focus = { x = 0, y = 0, w = 800, h = 600 }
	self.fitScale = 1
	local cx, cy = (self.tileBox.x0 + self.tileBox.x1) / 2, (self.tileBox.y0 + self.tileBox.y1) / 2
	self.cam = { x = cx, y = cy, zoom = 1 }
	self.goal = { x = cx, y = cy, zoom = 1 }
	self.manualUntil = 0

	MapArt.draw(self.layers, L, U)
	self:_buildTiles()
	self:_buildHits()
	self:_buildLair()

	self:_bindInput()
	self.bubbles = {} -- [seat] = { holder, w, h, token }
	self.bubbleZ = 20
	self.ghostSprites = {} -- Haunted Hollow: [ghost] = { holder, lift, tile }
	self.maid:add(RunService.RenderStepped:Connect(function(dt)
		self:_stepCamera(dt)
		self:_stepTags()
		self:_stepBubbles()
		self:_stepGhosts()
		self:_stepKraken()
		self:_stepBands()
	end))
	return self
end

---------------------------------------------------------------------------
-- Haunted Hollow's ghosts and Mount Kaboom's volcano
---------------------------------------------------------------------------

-- A ghost hovers just off its tile's top corner, so the tile and whoever stands on it
-- stay readable.
function BoardView:_ghostSpot(tile: number): Vector2
	return self:tileWorld(tile) + Vector2.new(0.55 * U, -1.05 * U)
end

function BoardView:setGhosts(tiles: { number })
	for i, tile in tiles do
		local g = self.ghostSprites[i]
		if not g then
			local holder = Util.frame(self.layers.Pawns, {
				Name = "Ghost" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(1.15 * U, 1.15 * U),
				ZIndex = 30,
			})
			local lift = Util.frame(holder, { Name = "Lift", ZIndex = 30 })
			Icons.sticker(lift, StickerArt.misc.ghost, { ZIndex = 31 }, 0.07)
			g = { holder = holder, lift = lift, tile = tile, phase = i * 1.7 }
			self.ghostSprites[i] = g
		end
		g.tile = tile
		if not g.moving then
			local holder = g.holder :: Frame
			holder.Position = px(self:_ghostSpot(tile))
			holder.ZIndex = depthZ(self:tileWorld(tile).Y) - 1
		end
	end
	for i = #tiles + 1, #self.ghostSprites do
		self.ghostSprites[i].holder:Destroy()
		self.ghostSprites[i] = nil
	end
end

function BoardView:_stepGhosts()
	if #self.ghostSprites == 0 then
		return
	end
	local t = os.clock()
	for _, g in self.ghostSprites do
		g.lift.Position = UDim2.fromOffset(0, math.sin(t * 2.2 + g.phase) * 0.08 * U)
	end
end

-- The ghosts float down the trail: { { ghost, from, path } }. A ghost that reaches the
-- Start fades out and comes back near the treasure. Yields until they've arrived.
function BoardView:driftGhosts(moves, speed: number?)
	local step = Pacing.GhostStep / math.max(speed or 1, 0.25)
	local longest = 0
	for _, m in moves do
		local g = self.ghostSprites[m.ghost]
		if g then
			g.moving = true
			longest = math.max(longest, #m.path)
			task.spawn(function()
				local prev = m.from
				for _, tile in m.path do
					local a, b = self:_ghostSpot(prev), self:_ghostSpot(tile)
					;(g.holder :: Frame).ZIndex = depthZ(math.max(self:tileWorld(prev).Y, self:tileWorld(tile).Y)) - 1
					if (b - a).Magnitude > 3 * U then
						-- back up the trail: vanish and reappear
						Util.tween(Util.scaler(g.holder), step * 0.5, { Scale = 0 })
						task.wait(step * 0.5)
						local frame = g.holder :: Frame
						frame.Position = px(b)
						Util.tween(Util.scaler(g.holder), step * 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
						task.wait(step * 0.5)
					else
						Util.tween(g.holder, step, { Position = px(b) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
						task.wait(step)
					end
					prev = tile
				end
				g.tile = prev
				g.moving = false
			end)
		end
	end
	if longest > 0 then
		Sound.play("whoosh", 0.7)
		task.wait(step * longest + 0.05)
	end
end

-- The ghost on `tile` lunges at whoever walked into it.
function BoardView:boo(tile: number)
	for _, g in self.ghostSprites do
		if g.tile == tile then
			local s = Util.scaler(g.holder)
			Util.tween(s, 0.12, { Scale = 1.45 }, Enum.EasingStyle.Back)
			task.delay(0.35, function()
				Util.tween(s, 0.25, { Scale = 1 })
			end)
		end
	end
	self:floatText(self:tileWorld(tile), "Boo!", C.white, 34)
end

-- The middle of the volcano (its landmark), if this map has one.
function BoardView:volcanoWorld(): Vector2?
	for _, p in self.layout.props do
		if p.kind == "volcano" then
			return MapArt.propCenter(self.layout, U, p)
		end
	end
	return nil
end

-- KABOOM: the board shakes, the crater spits fire and every lava stream flares up.
function BoardView:erupt(speed: number?)
	local k = math.max(speed or 1, 0.25)
	self:shake(0.22, 0.6 / k)
	Sound.play("bonk", 0.55)
	Sound.play("fire")
	local at = self:volcanoWorld()
	if at then
		self:floatText(at, "Kaboom!", C.orange, 40)
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			local rock = Util.new("Frame", {
				Name = "Rock",
				BackgroundColor3 = if i % 2 == 0 then C.orange else C.sun,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = px(at - Vector2.new(0, 1.6 * U)),
				Size = UDim2.fromOffset(0.34 * U, 0.34 * U),
				ZIndex = 44,
				Parent = self.layers.Fx,
			})
			Util.corner(rock, 0.5)
			Util.stroke(rock, C.line, 2)
			Util.tween(rock, 0.7 / k, { Position = px(at + Vector2.new(math.cos(a) * 2.6 * U, math.sin(a) * 1.6 * U)), BackgroundTransparency = 0.6 }, Enum.EasingStyle.Quad)
			task.delay(0.72 / k, function()
				rock:Destroy()
			end)
		end
	end
	for tile, kind in self.natural do
		if kind == "lava" then
			self:puff(self:tileWorld(tile), C.orange)
		end
	end
end

-- The lava tiles throb while the volcano is due to blow at the end of this round.
function BoardView:setRumble(on: boolean)
	if self.rumbling == on then
		return
	end
	self.rumbling = on
	if not on then
		return
	end
	task.spawn(function()
		while self.rumbling and self.container.Parent do
			for tile, kind in self.natural do
				local parts = self.tileParts[tile]
				local lava = parts and (parts.cover or parts.icon)
				if kind == "lava" and lava then
					Util.bump(lava, 0.12)
				end
			end
			task.wait(0.8)
		end
	end)
end

function BoardView:destroy()
	self.maid:clean()
	self.container:Destroy()
end

function BoardView:tileWorld(tile: number): Vector2
	return self.pos[tile] or Vector2.zero
end

-- world pixels -> stage pixels (the container sits at the stage's origin)
function BoardView:toStage(world: Vector2): Vector2
	local s = self.fitScale * self.cam.zoom
	local f = self.focus
	return Vector2.new(f.x + f.w / 2 + (world.X - self.cam.x) * s, f.y + f.h / 2 + (world.Y - self.cam.y) * s)
end

function BoardView:toWorld(stage: Vector2): Vector2
	local s = self.fitScale * self.cam.zoom
	local f = self.focus
	return Vector2.new(self.cam.x + (stage.X - f.x - f.w / 2) / s, self.cam.y + (stage.Y - f.y - f.h / 2) / s)
end

-- how many stage pixels one hex unit takes right now
function BoardView:unitPixels(): number
	return U * self.fitScale * self.cam.zoom
end

---------------------------------------------------------------------------
-- camera
---------------------------------------------------------------------------

-- The tiles are fitted into `rect` (stage pixels); the rest of the map runs under the HUD.
function BoardView:setFocus(rect, instant: boolean?)
	self.focus = { x = rect.x, y = rect.y, w = math.max(10, rect.w), h = math.max(10, rect.h) }
	local box = self.tileBox
	self.fitScale = math.min(self.focus.w / (box.x1 - box.x0), self.focus.h / (box.y1 - box.y0))
	self:_clampGoal()
	if instant then
		self.cam = table.clone(self.goal)
		self:_applyCamera()
	end
end

function BoardView:_clampGoal()
	local g = self.goal
	g.zoom = math.clamp(g.zoom, 1, MAX_ZOOM)
	local box = self.tileBox
	local s = self.fitScale * g.zoom
	-- how far the centre can move while the tiles still cover the focus area
	local halfW = self.focus.w / 2 / s
	local halfH = self.focus.h / 2 / s
	local minX, maxX = box.x0 + halfW, box.x1 - halfW
	local minY, maxY = box.y0 + halfH, box.y1 - halfH
	local mx, my = (box.x0 + box.x1) / 2, (box.y0 + box.y1) / 2
	g.x = if minX > maxX then mx else math.clamp(g.x, minX, maxX)
	g.y = if minY > maxY then my else math.clamp(g.y, minY, maxY)
end

function BoardView:_applyCamera()
	local s = self.fitScale * self.cam.zoom
	local f = self.focus
	local jolt = self.jolt or Vector2.zero
	self.scale.Scale = s
	self.world.Position = UDim2.fromOffset(f.x + f.w / 2 - self.cam.x * s + jolt.X, f.y + f.h / 2 - self.cam.y * s + jolt.Y)
end

function BoardView:_stepCamera(dt: number)
	local c, g = self.cam, self.goal
	local k = 1 - math.exp(-dt * 9)
	if math.abs(c.x - g.x) + math.abs(c.y - g.y) + math.abs(c.zoom - g.zoom) * 100 < 0.05 then
		if c.x ~= g.x or c.y ~= g.y or c.zoom ~= g.zoom then
			self.cam = table.clone(g)
			self:_applyCamera()
		end
		return
	end
	c.x += (g.x - c.x) * k
	c.y += (g.y - c.y) * k
	c.zoom += (g.zoom - c.zoom) * k
	self:_applyCamera()
end

-- Zoom by `factor`, keeping the stage point `around` (or the focus centre) where it is.
function BoardView:zoomBy(factor: number, around: Vector2?)
	local g = self.goal
	local before = g.zoom
	local after = math.clamp(before * factor, 1, MAX_ZOOM)
	if after == before then
		return
	end
	if around then
		local f = self.focus
		local s0 = self.fitScale * before
		local s1 = self.fitScale * after
		local ox, oy = around.X - f.x - f.w / 2, around.Y - f.y - f.h / 2
		g.x += ox / s0 - ox / s1
		g.y += oy / s0 - oy / s1
	end
	g.zoom = after
	self:_clampGoal()
end

function BoardView:setZoom(z: number)
	self:zoomBy(z / self.goal.zoom)
end

function BoardView:fit()
	local box = self.tileBox
	self.goal = { x = (box.x0 + box.x1) / 2, y = (box.y0 + box.y1) / 2, zoom = 1 }
	self:_clampGoal()
end

function BoardView:isZoomed(): boolean
	return self.goal.zoom > 1.05
end

-- Keep a world point in view: when zoomed in, slide so it sits in the middle area.
function BoardView:followPoint(world: Vector2, force: boolean?)
	if not force and os.clock() < self.manualUntil then
		return
	end
	if self.goal.zoom <= 1.02 then
		return
	end
	local s = self.fitScale * self.goal.zoom
	local f = self.focus
	local dx = (world.X - self.goal.x) * s
	local dy = (world.Y - self.goal.y) * s
	local mx, my = f.w * 0.3, f.h * 0.3
	if force or math.abs(dx) > mx or math.abs(dy) > my then
		self.goal.x = world.X
		self.goal.y = world.Y
		self:_clampGoal()
	end
end

function BoardView:follow(tile: number, force: boolean?)
	self:followPoint(self:tileWorld(tile), force)
end

function BoardView:_bindInput()
	-- wheel to zoom, drag to pan (mouse or one finger), pinch to zoom
	local dragging: { [string]: any }? = nil
	local touches = {}
	local pinchStart = nil

	-- positions here are screen pixels from Util.inputPos (top bar included)
	local function insideBoard(pos: Vector2): boolean
		local abs = self.container.AbsolutePosition
		local size = self.container.AbsoluteSize
		return pos.X >= abs.X and pos.Y >= abs.Y and pos.X <= abs.X + size.X and pos.Y <= abs.Y + size.Y
	end
	local function toStage(pos: Vector2): Vector2
		local abs = self.container.AbsolutePosition
		local k = Util.inheritedScale(self.container, true)
		return Vector2.new((pos.X - abs.X) / k, (pos.Y - abs.Y) / k)
	end

	self.maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			touches[input] = true
		end
		if processed or not insideBoard(Util.inputPos(input)) then
			return
		end
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 or t == Enum.UserInputType.Touch then
			dragging = { input = input, last = toStage(Util.inputPos(input)), moved = 0 }
		end
	end))
	self.maid:add(UserInputService.InputChanged:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel then
			if not processed and insideBoard(Util.inputPos(input)) then
				self.manualUntil = os.clock() + 6
				self:zoomBy(if input.Position.Z > 0 then 1.18 else 1 / 1.18, toStage(Util.inputPos(input)))
			end
			return
		end
		local d = dragging
		if not d then
			return
		end
		local moving = (t == Enum.UserInputType.MouseMovement and d.input.UserInputType ~= Enum.UserInputType.Touch)
			or (input == d.input)
		if not moving then
			return
		end
		-- a second finger means a pinch, not a pan
		local count = 0
		for _ in touches do
			count += 1
		end
		if count > 1 then
			return
		end
		local now = toStage(Util.inputPos(input))
		local delta = now - d.last
		d.last = now
		d.moved += delta.Magnitude
		if d.moved > 6 then
			self.manualUntil = os.clock() + 6
			self.dragMoved = true
			local s = self.fitScale * self.goal.zoom
			self.goal.x -= delta.X / s
			self.goal.y -= delta.Y / s
			self:_clampGoal()
			-- follow the finger exactly while dragging
			self.cam.x, self.cam.y = self.goal.x, self.goal.y
			self:_applyCamera()
		end
	end))
	self.maid:add(UserInputService.InputEnded:Connect(function(input)
		touches[input] = nil
		local d = dragging
		if d and (input == d.input or input.UserInputType == d.input.UserInputType) then
			dragging = nil
			task.delay(0.05, function()
				self.dragMoved = false
			end)
		end
	end))
	self.maid:add(UserInputService.TouchPinch:Connect(function(positions, scale, _velocity, state, processed)
		if state == Enum.UserInputState.Begin then
			pinchStart = if processed then nil else self.goal.zoom
			dragging = nil
		elseif state == Enum.UserInputState.Change and pinchStart then
			self.manualUntil = os.clock() + 6
			local around = nil
			if #positions >= 2 then
				around = toStage(Util.inputPos((positions[1] + positions[2]) / 2))
			end
			self:zoomBy((pinchStart * scale) / self.goal.zoom, around)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			pinchStart = nil
		end
	end))
end

---------------------------------------------------------------------------
-- static layers
---------------------------------------------------------------------------

-- A tile's top as it's seen: a round stepping stone (an ellipse: the ground is squashed)
-- or a square slab (a rounded rectangle), `radius` pixels across its middle.
function BoardView:_tileShape(parent: Instance, center: Vector2, radius: number, color: Color3, z: number, name: string): GuiObject
	if self.tileShape == "slab" then
		return MapArt.roundRect(parent, center, 2 * radius, 2 * radius * K, color, z, name)
	end
	return MapArt.ellipse(parent, center, 2 * radius, 2 * radius * K, color, z, name)
end

function BoardView:_buildTiles()
	local layer = self.layers.Tiles
	-- tiles lower on the screen draw over the ones above
	local order = {}
	for _, t in self.layout.tiles do
		table.insert(order, t)
	end
	table.sort(order, function(a, b)
		return a.y < b.y
	end)
	local D = S.tileDepth * U
	local slab = self.tileShape == "slab"
	self.sideColor = Util.shade(self.tileColors.normal, -0.34)
	for i, t in order do
		local center = self:tileWorld(t.id)
		local root = Util.frame(layer, {
			Name = "Tile" .. t.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(center),
			Size = UDim2.fromOffset(2 * U, 2 * U),
			ZIndex = i,
		})
		local mid = Vector2.new(U, U)
		local r = S.tileR * U * (t.scale or 1)
		-- a stone with a little thickness, seen from the front a little like the pieces:
		-- its soft shadow on the ground, its side (its top's outline lowered, and the band
		-- between), its top lit from the upper left with a bevel round the edge. No outline.
		Art.label(root, "ground/soft", mid + Vector2.new(0.12 * U, 0.16 * U), Vector2.new(2.5 * r, 2.5 * r * K), false, {
			Name = "Shadow",
			ImageColor3 = C.black,
			ImageTransparency = 0.6,
			ZIndex = 1,
		})
		local sideColor = self.sideColor
		local side = Util.frame(root, { Name = "Side", ZIndex = 2 })
		local bottom = self:_tileShape(side, mid + Vector2.new(0, D), r, sideColor, 2, "Bottom")
		local band = Util.new("Frame", {
			Name = "Band",
			BackgroundColor3 = sideColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = px(mid),
			Size = UDim2.fromOffset(2 * r, D),
			ZIndex = 2,
			Parent = side,
		})
		for _, part in { bottom, band } do
			Util.grad(part, { Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72) }, 0)
		end
		local top = self:_tileShape(root, mid, r, Util.shade(self.tileColors.normal, 0.4), 3, "Top")
		Util.grad(top, { Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6) }, 45)
		-- the face inside the bevel: worn stone (tinted the tile's colour, each one turned
		-- its own way round so they don't all wear the same pattern), or plain
		local faceR = r - BEVEL * U
		local spin = if t.id % 2 == 0 then 180 else 0
		local face = Art.label(root, if slab then "ground/slab" else "ground/stone", mid, Vector2.new(2 * faceR, 2 * faceR * K), false, {
			Name = "Face",
			ImageColor3 = self.tileColors.normal,
			Rotation = spin,
			ZIndex = 4,
		}) or self:_tileShape(root, mid, faceR, self.tileColors.normal, 4, "Face")
		Util.grad(face, { Color3.new(1, 1, 1), Color3.new(0.9, 0.9, 0.9) }, 45 - spin)
		-- every fifth tile carries its number, small: enough to count by, not a wall of digits
		local label = Widgets.label(root, {
			text = tostring(t.id),
			font = "chunky",
			size = math.floor(0.36 * U),
			color = self.inks.number or C.textFaint,
			align = "center",
			sizeUDim = UDim2.fromOffset(U, 0.5 * U),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(U, U),
			z = 9,
		})
		label.Visible = t.id % 5 == 0
		local parts = { root = root, side = side, top = top, face = face, label = label, kind = t.kind, branch = t.branch, angle = t.angle, scale = t.scale or 1, numbered = t.id % 5 == 0 }
		self.tileParts[t.id] = parts
		self:_paintTile(t.id)
	end
end

-- A board piece as a sticker: its card art on a disc in its owner's colour.
local function plaque(parent: Instance, item: string, owner: number?, at: UDim2, size: number, z: number): Frame
	local color = if owner and owner > 0 then Theme.seatColor(owner) else C.panelRaised
	-- the card's badge, ringed in its owner's colour
	local disc = Util.new("Frame", {
		Name = "Plaque",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	Util.corner(disc, 0.5)
	Util.stroke(disc, C.line, 0.05 * U)
	Icons.cardBadge(disc, item, Theme.Category[(Items.get(item) or {}).category or ""] or C.panelRaised, {
		Size = UDim2.fromScale(0.9, 0.9),
		ZIndex = z + 1,
	})
	return disc
end
BoardView.plaque = plaque

--[[
	A hidden trap you're allowed to see (yours, a teammate's, or seen with X-Ray / the
	Overseer's eye): its art on a dark disc rimmed in the owner's colour, see-through
	so it reads as "hidden". Map traps everyone can see are solid.
]]
local function trapMark(parent: Instance, trap, at: UDim2, size: number, z: number): GuiObject
	-- the owner's ring scales with the mark, and the group leaves room for it (a
	-- CanvasGroup clips whatever sticks out)
	local ring = math.max(1, math.min(0.08 * U, size * 0.12))
	local box = size + 2 * ring + 2
	local g = Util.new("CanvasGroup", {
		Name = "Trap",
		BackgroundTransparency = 1,
		GroupTransparency = if trap.public then 0 else 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(box, box),
		ZIndex = z,
		Parent = parent,
	})
	local owner = trap.owner or 0
	local color = if owner > 0 then Theme.seatColor(owner) else C.coral
	local disc = Util.new("Frame", {
		Name = "Disc",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = g,
	})
	Util.corner(disc, 0.5)
	Util.stroke(disc, color, ring)
	Icons.cardBadge(disc, trap.item, C.coral, { Size = UDim2.fromScale(0.94, 0.94), ZIndex = 2 })
	return g
end
BoardView.trapMark = trapMark

-- What's on a tile is drawn as the thing itself, not an icon (BoardLayout.TileLooks).
local LOOKS = BoardLayout.TileLooks
local THING_FOOT = 0.8 -- where a standing thing's foot is, down its canvas
local HIDDEN = 0.4 -- how see-through a hidden trap you can see is

local facingTurn = BoardLayout.facingTurn

-- `look` on a tile whose middle is `mid` in `parent` (r: the tile's radius, pixels;
-- `angle`: which way the trail runs there, for something that faces it): one image, or
-- nil without the art. A face is the tile's own shape (it turns into it); a thing
-- stands with its foot on the middle.
function BoardView:_drawLook(parent: Instance, look, r: number, z: number, alpha: number?, mid: Vector2?, angle: number?): ImageLabel?
	local at = mid or Vector2.new(U, U)
	local k = r / (S.tileR * U)
	if look.face then
		local fr = r - BEVEL * U
		local shape = if self.tileShape == "slab" then "square" else "round"
		return Art.label(parent, "tiles/" .. look.face .. "_" .. shape, at, Vector2.new(2 * fr, 2 * fr * K), false, {
			Name = "Face",
			ImageTransparency = alpha or 0,
			ZIndex = z,
		})
	end
	local size = look.size * U * k
	if look.facing and Art.has("tiles/" .. look.stand .. "_0") then
		-- (a 100 x 125 canvas, its foot 80 down it)
		local turn = facingTurn(angle or 0)
		return Art.label(parent, "tiles/" .. look.stand .. "_" .. turn, at - Vector2.new(0, 0.175 * size + 0.03 * U), Vector2.new(size, 1.25 * size), false, {
			Name = "Thing",
			ImageTransparency = alpha or 0,
			ZIndex = z,
		})
	end
	return Art.label(parent, "items/" .. look.stand, at - Vector2.new(0, (THING_FOOT - 0.5) * size - 0.03 * U), size, false, {
		Name = "Thing",
		ImageTransparency = alpha or 0,
		ZIndex = z,
	})
end

--[[
	Bands across a tile's face, cut to its shape: a conveyor's ridges, the Shifting
	Sands' ripples, a drawbridge deck's seams. One transparency gradient on the tile's
	own outline (so nothing spills over its edge), `period` apart along the gradient,
	each opaque for `duty` of it, at `phase` (0..1) of the way to the next. `sharp`: the
	front edge is that much of a period (a ridge reads as moving even in a still frame);
	without it a band rises and falls evenly.
]]
local function bands(phase: number, spec): NumberSequence
	local period, duty, sharp, a = spec.period, spec.duty, spec.sharp, spec.alpha
	local rise = if sharp then duty - sharp else duty / 2
	-- the band at u (0..1 along its period): clear, fading in to `a`, then out
	local function at(u: number): number
		u %= 1
		if u >= duty then
			return 1
		elseif u < rise then
			return 1 - (1 - a) * (u / rise)
		end
		return a + (1 - a) * ((u - rise) / math.max(duty - rise, 1e-4))
	end
	local times = { 0, 1 }
	local n = math.ceil(1 / period) + 1
	for i = -1, n do
		for _, u in { 0, rise, duty } do
			local t = (i + u + phase) * period
			if t > 0.002 and t < 0.998 then
				table.insert(times, t)
			end
		end
	end
	table.sort(times)
	local keys = {}
	local last = -1
	for _, t in times do
		if t - last > 0.004 and #keys < 20 then
			table.insert(keys, NumberSequenceKeypoint.new(t, at(t / period - phase)))
			last = t
		end
	end
	if keys[#keys].Time < 1 then
		keys[#keys] = NumberSequenceKeypoint.new(1, at(1 / period - phase))
	end
	return NumberSequence.new(keys)
end

-- A small pill on a tile saying what it does to you (+3, -10): Shifting Sands, the cogs.
local function badge(root: Instance, text: string, color: Color3): Frame
	local mid = Vector2.new(U, U)
	local way = Util.new("Frame", {
		Name = "Way",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(mid + Vector2.new(0.52 * U, 0.3 * U)),
		Size = UDim2.fromOffset((0.36 + 0.12 * #text) * U, 0.38 * U),
		ZIndex = 10,
		Parent = root,
	})
	Util.corner(way, 0.5)
	Util.stroke(way, C.line, 0.04 * U)
	Widgets.label(way, {
		text = text,
		font = "chunky",
		size = math.floor(0.28 * U),
		color = C.white,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = 11,
	})
	return way
end

-- A token: a chip in its colour standing up `lift` pixels over the tile's middle
-- (`ground`), its symbol facing you, its shadow on the tile under it.
local function chip(parent: Instance, token: string, ground: Vector2, lift: number, z: number): Frame
	local color = Theme.Category[token] or C.panelRaised
	local size = 0.74 * U
	local holder = Util.frame(parent, {
		Name = "Token",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = px(ground - Vector2.new(0, lift)),
		Size = UDim2.fromOffset(size, size * 1.1),
		ZIndex = z,
	})
	Art.label(holder, "ground/soft", Vector2.new(size / 2, size * 1.1 + lift + 0.02 * U), Vector2.new(0.8 * U, 0.8 * U * K * 0.6), false, {
		Name = "Shadow",
		ImageColor3 = C.black,
		ImageTransparency = 0.55,
		ZIndex = z - 1,
	})
	local function face(name: string, y: number, c: Color3, zz: number): Frame
		local f = Util.new("Frame", {
			Name = name,
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(size, size),
			ZIndex = zz,
			Parent = holder,
		})
		Util.corner(f, 0.5)
		return f
	end
	-- its edge (the chip's thickness), then its face: the token's badge
	face("Edge", 0.1 * size, Util.shade(color, -0.45), z)
	local top = Util.frame(holder, { Name = "Face", Size = UDim2.fromOffset(size, size), ZIndex = z + 1 })
	Icons.cardBadge(top, "token_" .. token, color, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	return holder
end


-- Is anything on the tile (its number hides)?
local function busyTile(parts): boolean
	return parts.cover ~= nil or parts.thing ~= nil or parts.token ~= nil or parts.icon ~= nil
end

--[[
	What a tile shows right now. It turns into what covers it (its face: the map's own
	hazard > a conveyor > a drawbridge's deck > a board piece > a hidden trap I can see >
	a cog > embers), and whatever stands on it stands on that (a wall, a spike, the
	chest...). A face in full view takes the tile's rim and side too, in its own colours;
	a hidden trap I can see is see-through, in its owner's ring. A token floats over
	everything. A hidden trap I can't see is never in self.traps, so it never shows.
]]
function BoardView:_paintTile(tile: number)
	local parts = self.tileParts[tile]
	if not parts then
		return
	end
	for _, key in { "cover", "thing", "ring", "token", "badge", "glow", "icon", "extra", "bands" } do
		if parts[key] then
			parts[key]:Destroy()
			parts[key] = nil
		end
	end
	self.bandTiles[tile] = nil
	parts.trapShown = nil
	local kind = parts.kind
	local natural = self.natural[tile]
	local beltAngle = self.belt[tile]
	local span = self.span[tile]
	local cog = self.cogs[tile]
	local entry = self.placed[tile]
	local token = self.tokens[tile]
	local traps = self.traps[tile]
	local trap = traps and traps[1]
	local root = parts.root
	local r = S.tileR * U * parts.scale
	local mid = Vector2.new(U, U)
	local fr = r - BEVEL * U

	-- the two slots: what the tile turns into, and what stands on it
	local face, faceAlpha, thing, thingAlpha = nil, 0, nil, 0
	local owner, trapHere = nil, false
	local function take(look, alpha: number): boolean
		if not look then
			return false
		end
		if look.face then
			if face then
				return false
			end
			face, faceAlpha = look, alpha
		else
			if thing then
				return false
			end
			thing, thingAlpha = look, alpha
		end
		return true
	end
	if natural then
		take(LOOKS[if natural == "thinice" and self.cracks[tile] then "thinice_cracked" else natural], 0)
	end
	if beltAngle then
		take(LOOKS.conveyor, 0)
		if entry and entry.item == "conveyor" then
			owner = entry.owner
		end
	end
	if span then
		take(LOOKS[if span.up then "gap" else "deck"], 0)
	end
	if entry and entry.item ~= "conveyor" and take(LOOKS[entry.item], 0) then
		owner = entry.owner
	end
	if trap and take(LOOKS[trap.item], if trap.public then 0 else HIDDEN) then
		owner = trap.owner or 0
		trapHere = true
	end
	if kind == "start" or kind == "treasure" or kind == "shortcutGate" then
		take(LOOKS[kind], 0)
	end
	if cog then
		take(LOOKS.cog, 0)
	end
	local ember = self.embers[tile]
	local emberGlow = ember ~= nil and not take(LOOKS.embers, 0)

	-- the tile itself: the stuff's own rim and side when it's in full view
	local topColor = if kind == "normal" and parts.branch then self.tileColors.branch else (self.tileColors[kind] or self.tileColors.normal)
	local solid = face ~= nil and faceAlpha == 0
	paint(parts.top, if solid then hex(string.sub(face.rim, 2)) else Util.shade(topColor, 0.4))
	paint(parts.face, topColor)
	local sideColor = if solid then hex(string.sub(face.side, 2)) else self.sideColor
	for _, part in parts.side:GetChildren() do
		if part:IsA("GuiObject") then
			paint(part, sideColor)
		end
	end
	if face then
		parts.cover = self:_drawLook(root, face, r, 5, faceAlpha)
		if trapHere and face == LOOKS[trap.item] then
			parts.trapShown = parts.cover
		end
		-- (the stone's worn face under it only shows through a see-through one)
		parts.face.Visible = not (solid and parts.cover ~= nil)
		local spec = face.bands
		if solid and parts.cover and spec then
			local angle = if beltAngle then beltAngle elseif span then span.angle else (parts.angle or 0)
			if spec.slides then
				-- the Shifting Sands ripple the way they slide you this round
				angle += if Engine.sandsForward(self.round) then 0 else 180
			end
			local band = self:_tileShape(root, mid, fr, hex(string.sub(spec.color, 2)), 6, "Bands")
			local grad = Util.new("UIGradient", { Rotation = angle, Transparency = bands(0, spec), Parent = band })
			parts.bands = band
			if (spec.speed or 0) > 0 then
				self.bandTiles[tile] = { grad = grad, spec = spec, offset = (tile * 0.37) % 1 }
			end
		end
	else
		parts.face.Visible = true
	end
	if thing then
		parts.thing = self:_drawLook(root, thing, r, 8, thingAlpha, nil, parts.angle)
		if trapHere and thing == LOOKS[trap.item] then
			parts.trapShown = parts.thing
		end
	end
	if emberGlow then
		-- (embers under something that covers the tile: it glows)
		parts.glow = Art.label(root, "ground/soft", mid, Vector2.new(2.2 * fr, 2.2 * fr * K), false, {
			Name = "Glow",
			ImageColor3 = C.orange,
			ImageTransparency = 0.35,
			ZIndex = 6,
		})
	end
	if owner and (owner > 0 or trapHere) then
		parts.ring = Art.label(root, "ground/ring", mid, Vector2.new(2 * fr, 2 * fr * K), false, {
			Name = "Owner",
			ImageColor3 = if owner > 0 then Theme.seatColor(owner) else C.coral,
			ZIndex = 7,
		})
	end
	-- a trap I can see on a tile that already shows something: small, to one side
	if trap and not trapHere then
		local small = LOOKS[trap.item]
		local holder = Util.frame(root, {
			Name = "Extra",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(mid + Vector2.new(0.45 * U, -0.15 * U)),
			Size = UDim2.fromOffset(2 * U, 2 * U),
			ZIndex = 9,
		})
		Util.new("UIScale", { Scale = 0.55, Parent = holder })
		if small and self:_drawLook(holder, small, S.tileR * U, 9, if trap.public then 0 else HIDDEN, nil, parts.angle) then
			parts.extra = holder
			parts.trapShown = holder
		else
			holder:Destroy()
		end
	end
	if token then
		parts.token = chip(root, token, mid, (if parts.thing then 0.6 else 0.14) * U, 11)
	end
	if entry and entry.item == "sands" then
		-- which way it slides you this round: +3 or -3
		local fwd = Engine.sandsForward(self.round)
		parts.badge = badge(root, (if fwd then "+" else "-") .. tostring(Config.Rules.SandsSlide), if fwd then C.lime else C.coral)
	elseif cog then
		-- where the gears carry you when the round ends
		parts.badge = badge(root, (if cog > 0 then "+" else "") .. tostring(cog), if cog > 0 then C.lime else C.coral)
	end
	-- without the art: the stickers
	local missing = (face ~= nil and parts.cover == nil) or (thing ~= nil and parts.thing == nil)
	if missing then
		parts.icon = self:_stickerLook(root, natural, beltAngle, entry, trapHere and trap or nil, if span and span.up then "gap" elseif cog then "cog" else kind)
	end
	parts.label.Visible = parts.numbered and not busyTile(parts) and (self.cover[tile] or 0) == 0
end

-- What a tile shows when the art isn't there: its sticker (a board piece on a disc in
-- its owner's colour, a hidden trap on a dark one, a belt as a steel band).
function BoardView:_stickerLook(root: Instance, natural: string?, beltAngle: number?, entry, trap, kind: string): GuiObject?
	local mid = UDim2.fromOffset(U, U)
	local function holder(size: number, z: number): Frame
		return Util.frame(root, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = mid,
			Size = UDim2.fromOffset(size * U, size * U),
			ZIndex = z,
		})
	end
	if natural then
		local art = StickerArt.hazards[natural]
		if art then
			local h = holder(1.2, 7)
			Icons.sticker(h, art, nil, 0.06)
			return h
		end
	elseif beltAngle then
		local h = holder(1.6, 6)
		local a = math.rad(beltAngle)
		local c = Shapes.canvas(h, { Rotation = math.deg(math.atan2(math.sin(a) * K, math.cos(a))) })
		local band = Shapes.rect(c, 0.5, 0.5, 0.82, 0.36, hex("8792AD"), { r = 0.2 })
		Util.scaledStroke(band, C.line, 0.04, 2)
		Shapes.chevron(c, 0.38, 0.5, 0.2, 0.07, C.sun, { dir = 90 })
		Shapes.chevron(c, 0.62, 0.5, 0.2, 0.07, C.sun, { dir = 90 })
		return h
	elseif entry then
		return plaque(root, entry.item, entry.owner, mid, 0.86 * U, 7)
	elseif trap then
		return trapMark(root, trap, mid, 0.8 * U, 8)
	else
		local art = if kind == "start"
			then StickerArt.misc.flag
			elseif kind == "treasure" then StickerArt.misc.chest
			elseif kind == "gap" then StickerArt.hazards.drawbridge
			elseif kind == "cog" then StickerArt.hazards.cog
			elseif kind == "shortcutGate" then StickerArt.hazards.gate
			else nil
		if not art then
			return nil
		end
		local h = holder(if kind == "treasure" then 1.25 else 1, 7)
		Icons.sticker(h, art, nil, 0.06)
		return h
	end
	return nil
end

-- Invisible buttons for picking tiles: a box over each tile's top and side.
function BoardView:_buildHits()
	self.hits = {}
	for _, t in self.layout.tiles do
		local hit = Util.new("TextButton", {
			Name = "Hit" .. t.id,
			Text = "",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(self:tileWorld(t.id) + Vector2.new(0, S.tileDepth / 2 * U)),
			Size = UDim2.fromOffset(HIT * U, (HIT * K + S.tileDepth) * U),
			Visible = false,
			Parent = self.layers.Hits,
		})
		self.hits[t.id] = hit
	end
end

---------------------------------------------------------------------------
-- dynamic things: tokens, placed items, natural traps
---------------------------------------------------------------------------

function BoardView:setToken(tile: number, kind: string?)
	if self.tokens[tile] == kind then
		return
	end
	self.tokens[tile] = kind
	self:_paintTile(tile)
	local parts = self.tileParts[tile]
	if kind and parts and parts.token then
		Util.popIn(parts.token, 0.3, 0.3)
	end
end

-- A used token lifts off its tile and lands on its new one.
function BoardView:moveToken(from: number, to: number, kind: string?)
	local k = kind or self.tokens[from]
	if not k then
		return
	end
	self.tokens[from] = nil
	self:_paintTile(from)
	local a, b = self:tileWorld(from), self:tileWorld(to)
	local flyer = Util.frame(self.layers.Fx, {
		Name = "TokenFly",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(a),
		Size = UDim2.fromOffset(1.18 * U, 1.18 * U),
		ZIndex = 45,
	})
	local color = Theme.Category[k] or C.panelRaised
	Icons.cardBadge(flyer, "token_" .. k, color, { Size = UDim2.fromScale(0.82, 0.82), ZIndex = 3 })
	local s = Util.scaler(flyer)
	local dist = (b - a).Magnitude
	local t = math.clamp(dist / (U * 14), 0.35, 0.7)
	Sound.play("whoosh", 1.1)
	Util.tween(s, t * 0.5, { Scale = 1.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Util.tween(flyer, t, { Position = px(b) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	task.delay(t * 0.5, function()
		Util.tween(s, t * 0.5, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	task.delay(t, function()
		flyer:Destroy()
		self.tokens[to] = k
		self:_paintTile(to)
		local parts = self.tileParts[to]
		if parts and parts.token then
			Util.bump(parts.token, 0.25)
		end
		self:puff(b, color)
	end)
end

function BoardView:setNatural(tile: number, kind: string?)
	if self.natural[tile] == kind then
		return
	end
	self.natural[tile] = kind
	self:_paintTile(tile)
	local parts = self.tileParts[tile]
	local shown = parts and (parts.cover or parts.thing)
	if kind and shown then
		Util.popIn(shown, 0.35, 0.4)
	end
end

-- A new round: Shifting Sands turn around.
function BoardView:setRound(round: number)
	if self.round == round then
		return
	end
	self.round = round
	for tile, entry in self.placed do
		if entry.item == "sands" then
			self:_paintTile(tile)
		end
	end
end

--[[
	A card placed on the board turns its tile into it (or lays the conveyor over its
	three tiles). animate: true = a cover spreads out over the tile, a thing drops onto
	it; "settle" = it was already shown (a preview), so just a small bump.
]]
function BoardView:placeItem(entry, animate: (boolean | string)?)
	local tile = entry.tile
	local existing = self.placed[tile]
	if existing and existing.item == entry.item then
		return
	end
	if existing then
		self:_clearPlaced(tile)
	end
	self.placed[tile] = { tile = tile, item = entry.item, owner = entry.owner, dir = entry.dir, tiles = entry.tiles }
	if entry.item == "conveyor" and entry.tiles then
		self:_setBelt(tile, entry.tiles, entry.dir)
	end
	self:_paintTile(tile)
	if animate == "settle" then
		local parts = self.tileParts[tile]
		if parts then
			Util.bump(parts.root, 0.06)
		end
	elseif animate then
		-- a cover spreads out from the middle; a thing (or a sticker) drops onto the tile
		local parts = self.tileParts[tile]
		if parts then
			for _, t in self.beltOf[tile] or { tile } do
				local cover = self.tileParts[t] and self.tileParts[t].cover
				if cover then
					local s = Util.scaler(cover)
					s.Scale = 0.25
					Util.tween(s, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				end
			end
			local drop = (parts.thing or parts.icon) :: GuiObject?
			if drop then
				local base = drop.Position
				drop.Position = base - UDim2.fromOffset(0, 0.7 * U)
				local s = Util.scaler(drop)
				s.Scale = 1.3
				Util.tween(drop, 0.3, { Position = base }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0.08)
				Util.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.08)
			end
			Util.bump(parts.root, 0.14)
		end
	end
end

function BoardView:_clearPlaced(tile: number)
	self.placed[tile] = nil
	if self.beltOf[tile] then
		self:_setBelt(tile, nil, nil)
	end
	self:_paintTile(tile)
end

function BoardView:removePlaced(tile: number)
	local parts = self.tileParts[tile]
	if not self.placed[tile] then
		return
	end
	-- what was there shrinks away (it's left out of the tile's parts, so repainting it
	-- doesn't take it at once)
	for _, key in { "thing", "cover", "icon", "ring" } do
		local old = parts and parts[key]
		if old then
			parts[key] = nil
			Util.tween(Util.scaler(old), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.26, function()
				old:Destroy()
			end)
		end
	end
	self:_clearPlaced(tile)
end

function BoardView:_setBelt(origin: number, tiles: { number }?, dir: string?)
	for _, t in self.beltOf[origin] or {} do
		self.belt[t] = nil
		self:_paintTile(t)
	end
	self.beltOf[origin] = tiles
	for i, t in tiles or {} do
		local list = tiles :: { number }
		local from, to = t, list[i + 1]
		if not to then
			from, to = list[i - 1] or t, t
		end
		-- (which way it runs on the ground; it's drawn squashed like the ground)
		local v = self.ground[to] - self.ground[from]
		self.belt[t] = math.deg(math.atan2(v.Y, v.X)) + (if dir == "back" then 180 else 0)
		self:_paintTile(t)
	end
end

---------------------------------------------------------------------------
-- Frostbite Floes' thin ice, Kraken's Reach's tentacle, Clockwork Cove's drawbridge
-- and cogs
---------------------------------------------------------------------------

local KRAKEN_SHADE = hex("2A1838")
local KRAKEN_PINK = hex("D86A8A")
local FROST = hex("E6F7FF")

-- The thin ice that has cracked (a second landing breaks it): [tile] = true.
function BoardView:setCracks(map: { [number]: boolean })
	local changed = {}
	for tile in self.cracks do
		if not map[tile] then
			changed[tile] = true
		end
	end
	for tile in map do
		if not self.cracks[tile] then
			changed[tile] = true
		end
	end
	self.cracks = map
	for tile in changed do
		self:_paintTile(tile)
	end
end

-- Someone landed on thin ice: it cracks ("cracked"), gives way under them ("broken"),
-- or they walked into the open water where it already had ("splash").
function BoardView:crackIce(tile: number, state: string)
	local at = self:tileWorld(tile)
	if state == "cracked" then
		self.cracks[tile] = true
		self:_paintTile(tile)
		local parts = self.tileParts[tile]
		local cover = parts and (parts.cover or parts.icon)
		if cover then
			Util.bump(cover, 0.1)
		end
		Sound.play("ice", 1.2)
		self:floatText(at, "Crack!", C.sky, 28)
		return
	end
	if state == "broken" then
		self.cracks[tile] = nil
		self:setNatural(tile, "hole")
	end
	Sound.play("splash")
	Sound.play("ice", 0.8)
	for i = 1, 3 do
		task.delay(i * 0.12, function()
			self:_ring(at, FROST, 0.4, 1.9, 0.55)
		end)
	end
	self:puff(at - Vector2.new(0, 0.3 * U), FROST)
	self:floatText(at, "Splash!", C.sky, 32)
end

-- The open water freezes over again when the round ends.
function BoardView:refreeze(tiles: { number })
	for _, tile in tiles do
		self.cracks[tile] = nil
		self.natural[tile] = nil
		self:setNatural(tile, "thinice")
		self:puff(self:tileWorld(tile), FROST)
	end
	if #tiles > 0 then
		Sound.play("ice", 1.4)
	end
end

-- An expanding ring on the ground (a splash, a ripple).
function BoardView:_ring(at: Vector2, color: Color3, from: number, to: number, life: number)
	local r = Util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(at),
		Size = UDim2.fromOffset(from * U, from * U * K),
		ZIndex = 40,
		Parent = self.layers.Fx,
	})
	Util.corner(r, 0.5)
	local st = Util.stroke(r, color, 3)
	Util.tween(r, life, { Size = UDim2.fromOffset(to * U, to * U * K) }, Enum.EasingStyle.Quad)
	Util.tween(st, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(life + 0.02, function()
		r:Destroy()
	end)
end

--[[
	Kraken's Reach. The Kraken's arm (art/kraken.py, frames on one canvas, its foot where
	it leaves the water): it rises out of the sea beside its mark, sways there, then
	rears back, arches over and slams down across the mark, and sinks. ARM: that canvas,
	map units round the foot.
]]
local ARM = { x0 = -4.6, x1 = 4.6, y0 = -6.8, y1 = 3.2 }
local ARM_REACH = 2.8 -- how far from its foot a slammed arm lies across (art: kraken.py)
local ARM_FPS = 8

-- The arm's canvas on the board: its size and its middle, for a foot at `foot` (world
-- pixels) and the arm `scale` x its drawn size.
local function armBox(foot: Vector2, scale: number): (Vector2, Vector2)
	local w, h = (ARM.x1 - ARM.x0) * U * scale, (ARM.y1 - ARM.y0) * U * scale
	local mid = foot + Vector2.new(((ARM.x0 + ARM.x1) / 2) * U * scale, ((ARM.y0 + ARM.y1) / 2) * U * scale)
	return Vector2.new(w, h), mid
end

--[[
	Where the arm rises for its mark: open water near the tile (never out of the land, a
	beach or a cliff), clear of the other tiles and the lair, its arm on screen, about as
	far from the mark as a slammed arm reaches; off to the side if it can be, so it
	strikes across the screen. Ground coordinates (map units).
]]
function BoardView:_krakenFoot(tile: number): Vector2
	local L = self.layout
	local g = self.ground[tile]
	local depth = L.landDepth
	local lair = nil
	for _, p in L.props do
		if p.kind == "whirlpool" then
			lair = p
		end
	end
	local v = L.view
	local best, bestScore = nil, math.huge
	for _, d in { 2.8, 2.5, 3.1, 3.4, 2.2, 3.8 } do
		for k = 0, 23 do
			local a = k * math.pi / 12
			local x, y = g.X + math.cos(a) * d, g.Y + math.sin(a) * d
			-- open water, and water a little up the screen too (not under a cliff's face)
			local ok = depth(x, y) < -0.6 and depth(x, y - 0.8) < -0.25 and depth(x, y + 0.5) < -0.3
			if ok then
				for _, t in L.tiles do
					if t.id ~= tile and (x - t.x) ^ 2 + (y - t.y) ^ 2 < 1.7 ^ 2 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, p in L.props do
					local keep = if p.kind == "whirlpool" then p.size * 0.62 else p.size * 0.45
					if (not p.ground or p.kind == "whirlpool") and (x - p.x) ^ 2 + (y - p.y) ^ 2 < keep * keep then
						ok = false
						break
					end
				end
			end
			if ok then
				-- on screen, with room above for the arm, and not standing in front of a
				-- tile (or whoever is on it) while it waits there
				local at = MapArt.project(L, 1, x, y) + Vector2.new(L.x0, L.y0 * K)
				local scr = MapArt.project(L, 1, g.X, g.Y) + Vector2.new(L.x0, L.y0 * K)
				local off = (at.Y - 5.2 < v.y0 - 0.6) or at.X < v.x0 + 1.2 or at.X > v.x1 - 1.2 or at.Y > v.y1 - 0.6
				local covers = false
				for _, t in L.tiles do
					local ts = MapArt.project(L, 1, t.x, t.y) + Vector2.new(L.x0, L.y0 * K)
					if math.abs(ts.X - at.X) < 1.7 and ts.Y < at.Y + 0.6 and ts.Y > at.Y - 5.4 then
						covers = true
						break
					end
				end
				local across = scr - at
				local side = math.abs(across.Y / K) / math.max(1e-3, across.Magnitude)
				local score = math.abs(d - ARM_REACH) + 0.4 * side + (if off then 4 else 0) + (if covers then 3 else 0)
				if lair then
					-- (it lives in the lagoon, round its lair)
					score += 0.12 * math.sqrt((x - lair.x) ^ 2 + (y - lair.y) ^ 2)
				end
				if score < bestScore then
					best, bestScore = Vector2.new(x, y), score
				end
			end
		end
		if best and bestScore < 1.5 then
			break
		end
	end
	if not best then
		-- (no open water near: the side of the lair, or just behind the tile)
		local dir = if lair then Vector2.new(lair.x, lair.y) - g else Vector2.new(0, -1)
		if dir.Magnitude < 1e-3 then
			dir = Vector2.new(0, -1)
		end
		best = g + dir.Unit * 2.4
	end
	return best
end

function BoardView:_clearKraken()
	local k = self.krakenSprite
	if not k then
		return
	end
	self.krakenSprite = nil
	for _, img in k.shades do
		img:Destroy()
	end
	k.holder:Destroy()
end

-- Shows frame `name` of the arm (mirrored if `flip`), `scale` x its drawn size,
-- turned `turn` degrees round its foot.
function BoardView:_armFrame(k, name: string, flip: boolean?, scale: number?, turn: number?)
	local sc = scale or k.scale
	local size, mid = armBox(Vector2.zero, sc)
	local center = k.half + mid
	if k.img then
		Art.frame(k.img, "kraken/" .. name, center, size, flip)
	end
	k.holder.Rotation = turn or 0
	k.frame = name
end

--[[
	Kraken's Reach: the arm over its mark ({ tile, zone } or nil), rising out of the
	water beside it and swaying there, its shadow over the tiles it will come down on.
]]
function BoardView:setKraken(mark)
	local tile = mark and mark.tile
	local k = self.krakenSprite
	if k and k.tile == tile and not k.busy then
		return
	end
	self:_clearKraken()
	if not tile or not self.tileParts[tile] then
		return
	end
	local shades = {}
	for _, t in mark.zone or { tile } do
		local parts = self.tileParts[t]
		if parts then
			local r = S.tileR * U * parts.scale
			local img = Art.label(parts.root, "ground/soft", Vector2.new(U, U), Vector2.new(2.4 * r, 2.4 * r * K), false, {
				Name = "KrakenShade",
				ImageColor3 = KRAKEN_SHADE,
				ImageTransparency = 0.4,
				ZIndex = 6,
			})
			if img then
				table.insert(shades, img)
			end
		end
	end
	local L = self.layout
	local ground = self:_krakenFoot(tile)
	local foot = MapArt.project(L, U, ground.X, ground.Y)
	local target = self:tileWorld(tile)
	-- (the arm faces its mark: mirrored when the mark is to its left)
	local flip = target.X < foot.X - 0.2 * U
	local scale = 1
	local size = armBox(Vector2.zero, scale)
	-- a frame round the foot: the arm turns round it
	local span = 2 * math.max(size.X, size.Y)
	local holder = Util.frame(self.layers.Pawns, {
		Name = "Kraken",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(foot),
		Size = UDim2.fromOffset(span, span),
		ZIndex = depthZ(foot.Y) - 1,
	})
	local half = Vector2.new(span / 2, span / 2)
	local k2 = { tile = tile, foot = foot, ground = ground, holder = holder, shades = shades, flip = flip, scale = scale, half = half, t0 = os.clock(), phase = math.random() * 6 }
	k2.img = Art.label(holder, "kraken/rise_0", half, size, flip, { Name = "Arm", ZIndex = holder.ZIndex })
	if not k2.img then
		-- (no art: the old sticker, swaying)
		local h = Util.frame(holder, {
			Name = "Arm",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(span / 2, span / 2),
			Size = UDim2.fromOffset(1.8 * U, 1.8 * U),
		})
		Icons.sticker(h, StickerArt.hazards.kraken, nil, 0.06)
	end
	self.krakenSprite = k2
	self:_ring(foot, FROST, 0.5, 2.2, 0.6)
end

-- A conveyor's ridges run along it and the Shifting Sands ripple the way they slide.
function BoardView:_stepBands()
	if next(self.bandTiles) == nil then
		return
	end
	local now = os.clock()
	for _, b in self.bandTiles do
		b.grad.Transparency = bands((now * b.spec.speed + b.offset) % 1, b.spec)
	end
end

-- The arm rises out of the water (three frames), then sways (a loop); the lair's water
-- turns, its arms bob and its head watches the mark.
function BoardView:_stepKraken()
	self:_stepLair()
	local k = self.krakenSprite
	if not k or k.busy or not k.img then
		return
	end
	local t = os.clock() - k.t0
	local name
	if t < 0.36 then
		name = "rise_" .. math.min(2, math.floor(t / 0.12))
	else
		name = "arm_" .. (math.floor((t - 0.36) * ARM_FPS) % 6)
	end
	if name ~= k.frame then
		self:_armFrame(k, name, k.flip, nil, nil)
	end
end

--[[
	The arm rears back, arches over its mark and slams down across it, the dust flying,
	then sinks back into the water (yields until the hit lands). Its frames are drawn
	eight ways round on the ground; the nearest is turned the rest of the way and
	stretched to reach the mark.
]]
function BoardView:krakenSlam(speed: number?)
	local k = self.krakenSprite
	if not k then
		return
	end
	local pace = 1 / math.max(speed or 1, 0.25)
	k.busy = true
	self.lairAngry = os.clock() + 1.6 * pace
	local target = self:tileWorld(k.tile)
	local v = target - k.foot
	-- the way it strikes, on the ground (seen from straight above), and how far
	local gx, gy = v.X, v.Y / K
	local dist = math.sqrt(gx * gx + gy * gy) / U
	local angle = math.deg(math.atan2(gy, gx))
	local dir = math.floor(angle / 45 + 0.5) % 8
	local rest = angle - dir * 45
	if rest > 180 then
		rest -= 360
	elseif rest < -180 then
		rest += 360
	end
	local reach = math.clamp(dist / ARM_REACH, 0.8, 1.3)
	;(k.holder :: Frame).ZIndex = 400
	local img = k.img :: ImageLabel?
	if img then
		img.ZIndex = 400
		-- rearing back, away from its mark
		self:_armFrame(k, if gx >= 0 then "rear_l" else "rear_r", false, nil, nil)
		Util.tween(Util.scaler(img), 0.3 * pace, { Scale = 1.06 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	Sound.play("whoosh", 0.6)
	task.wait(0.32 * pace)
	if img then
		Util.scaler(img).Scale = 1
		self:_armFrame(k, "arc_" .. dir, false, reach, rest * 0.6)
	end
	task.wait(0.1 * pace)
	if img then
		self:_armFrame(k, "hit_" .. dir, false, reach, rest)
	else
		Util.tween(k.holder, 0.14 * pace, { Rotation = math.clamp(angle + 90, -80, 80) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	self:shake(0.25, 0.5)
	Sound.play("splash")
	Sound.play("bonk", 0.55)
	for _, shade in k.shades do
		local tile = shade.Parent
		if tile and tile:IsA("GuiObject") then
			Util.bump(tile, 0.08)
		end
	end
	self:_ring(target, KRAKEN_PINK, 0.6, 3.2, 0.5)
	self:puff(target, FROST)
	self:floatText(target, "SLAM!", KRAKEN_PINK, 38)
	task.spawn(function()
		task.wait(0.5 * pace)
		if self.krakenSprite ~= k then
			return
		end
		-- it sinks back into the deep
		if img then
			for _, name in { "arc_" .. dir, "rise_2", "rise_1", "rise_0" } do
				self:_armFrame(k, name, if string.sub(name, 1, 4) == "rise" then gx < 0 else false, if name == "arc_" .. dir then reach else nil, if name == "arc_" .. dir then rest * 0.6 else 0)
				task.wait(0.09)
				if self.krakenSprite ~= k then
					return
				end
			end
			Util.tween(img, 0.2, { ImageTransparency = 1 })
			task.wait(0.2)
		end
		if self.krakenSprite == k then
			self:_clearKraken()
		end
	end)
	task.wait(0.3 * pace)
end

--[[
	The Kraken's lair, in the middle of the lagoon (the whirlpool prop): its white water
	turning round and down (four frames, faded one into the next), a few of its arms
	arching out of the water round it, and its head rising out of the middle, watching
	the mark, blinking now and then, and glaring when it strikes.
]]
local SWIRL_STEP = 0.24 -- seconds a swirl frame (each turns 18 degrees)
local HEAD = { x0 = -2.2, x1 = 2.2, y0 = -3.6, y1 = 0.7 } -- its canvas, its waterline at 0
local COIL = { x0 = -1.6, x1 = 1.6, y0 = -2.0, y1 = 0.5 }

function BoardView:_buildLair()
	local lair = nil
	for _, p in self.layout.props do
		if p.kind == "whirlpool" then
			lair = p
		end
	end
	if not lair or not self.def.kraken or not Art.has("kraken/head_ahead") then
		return
	end
	local L = self.layout
	local mid = MapArt.project(L, U, lair.x, lair.y)
	local size = lair.size * U
	local swirls = {}
	for i = 1, 2 do
		swirls[i] = Art.label(self.layers.Trail, "kraken/swirl_0", mid, Vector2.new(size * 0.94, size * 0.94 * K), false, {
			Name = "Swirl",
			ImageTransparency = if i == 1 then 0 else 1,
			ZIndex = 120,
		})
	end
	-- its arms arching out of the water round it
	local coils = {}
	for i, at in { { -0.36, -0.06, false }, { 0.33, -0.2, true }, { 0.18, 0.3, false } } do
		local x, y = lair.x + at[1] * lair.size, lair.y + at[2] * lair.size
		local foot = MapArt.project(L, U, x, y)
		local s = 0.62 * lair.size / 6.2
		local w, h = (COIL.x1 - COIL.x0) * U * s, (COIL.y1 - COIL.y0) * U * s
		local center = foot + Vector2.new(0, ((COIL.y0 + COIL.y1) / 2) * U * s)
		local img = Art.label(self.layers.Props, "kraken/coil_" .. ((i - 1) % 2), center, Vector2.new(w, h), at[3], {
			Name = "Coil",
			ZIndex = 300 + math.floor(foot.Y / 4),
		})
		if img then
			table.insert(coils, { img = img, center = center, phase = i * 2.1 })
		end
	end
	local s = 1.05 * lair.size / 6.2
	local hw, hh = (HEAD.x1 - HEAD.x0) * U * s, (HEAD.y1 - HEAD.y0) * U * s
	local hcenter = mid + Vector2.new(0, ((HEAD.y0 + HEAD.y1) / 2) * U * s + 0.15 * U)
	local head = Art.label(self.layers.Props, "kraken/head_ahead", hcenter, Vector2.new(hw, hh), false, {
		Name = "KrakenHead",
		ZIndex = 300 + math.floor(mid.Y / 4),
	})
	self.lair = {
		swirls = swirls,
		coils = coils,
		head = head,
		headCenter = hcenter,
		headSize = Vector2.new(hw, hh),
		headAt = head and head.Position, -- (where its frame puts it, before it bobs)
		look = "ahead",
		blinkAt = os.clock() + 2 + math.random() * 3,
		mid = mid,
	}
end

function BoardView:_stepLair()
	local lair = self.lair
	if not lair then
		return
	end
	local now = os.clock()
	-- the water turning: frame i fading into frame i + 1
	local f = now / SWIRL_STEP
	local i = math.floor(f)
	local a, b = lair.swirls[1], lair.swirls[2]
	if a and b then
		local size = a.Size
		if lair.swirlFrame ~= i then
			lair.swirlFrame = i
			local box = Vector2.new(size.X.Offset, size.Y.Offset)
			Art.frame(a, "kraken/swirl_" .. (i % 4), lair.mid, box)
			Art.frame(b, "kraken/swirl_" .. ((i + 1) % 4), lair.mid, box)
		end
		local t = f - i
		a.ImageTransparency = 0.15 + 0.85 * t
		b.ImageTransparency = 1 - 0.85 * t
	end
	for _, c in lair.coils do
		c.img.Position = UDim2.fromOffset(c.center.X, c.center.Y + math.sin(now * 1.3 + c.phase) * 0.08 * U)
	end
	if lair.head then
		-- it watches the arm's mark; blinks; glares as it strikes
		local look = "ahead"
		local k = self.krakenSprite
		if self.lairAngry and now < self.lairAngry then
			look = "angry"
		elseif now >= lair.blinkAt then
			look = "blink"
			if now >= lair.blinkAt + 0.14 then
				lair.blinkAt = now + 2.5 + math.random() * 3.5
			end
		elseif k then
			local dx = self:tileWorld(k.tile).X - lair.mid.X
			look = if dx < -1.5 * U then "left" elseif dx > 1.5 * U then "right" else "ahead"
		end
		if look ~= lair.look then
			lair.look = look
			Art.frame(lair.head, "kraken/head_" .. look, lair.headCenter, lair.headSize)
			lair.headAt = lair.head.Position
		end
		-- (bobbing in the water)
		lair.head.Position = lair.headAt + UDim2.fromOffset(0, math.sin(now * 0.9) * 0.07 * U)
	end
end

--[[
	Clockwork Cove's drawbridges ({ { tiles, up } }): down, their tiles are a deck of
	planks laid across the trail; up, they're the canal's water, and each tile's leaf
	stands raised on its hinge at the bank, leaning out over the gap. animate: they swing
	up or down.
]]
function BoardView:setBridges(list, animate: boolean?)
	local span = {}
	for _, b in list or {} do
		local tiles = b.tiles or {}
		local first, last = tiles[1], tiles[#tiles]
		if first and last and self.ground[first] and self.ground[last] then
			local p, q = self.ground[first], self.ground[last]
			if first == last then
				local nxt = self.board.nextMain[first]
				q = if nxt and self.ground[nxt] then self.ground[nxt] else p + Vector2.new(1, 0)
			end
			local angle = math.deg(math.atan2(q.Y - p.Y, q.X - p.X))
			for i, t in tiles do
				-- (the first tile's leaf leans on along the trail, the last one's back)
				span[t] = { angle = angle, up = b.up == true, lean = if i == 1 then angle else angle + 180 }
			end
		end
	end
	local changed = {}
	for t, old in self.span do
		local new = span[t]
		if not new or new.up ~= old.up or new.angle ~= old.angle then
			changed[t] = true
		end
	end
	for t in span do
		if not self.span[t] then
			changed[t] = true
		end
	end
	if next(changed) == nil then
		return
	end
	self.span = span
	local rising, first = false, nil
	for t in changed do
		self:_paintTile(t)
		self:_setLeaf(t, span[t], animate)
		local parts = self.tileParts[t]
		if animate and parts then
			Util.bump(parts.root, 0.08)
			first = first or t
			rising = rising or (span[t] ~= nil and span[t].up)
		end
	end
	if animate and first then
		Sound.play("place", if rising then 0.7 else 0.9)
		Sound.play("whoosh", 0.8)
	end
end

-- A raised drawbridge's leaf over `tile` (or none): hinged at the tile's outer edge,
-- leaning out over the gap (art/tiles.py leaf_<k>, 100 x 125, its hinge 92 down it).
function BoardView:_setLeaf(tile: number, span, animate: boolean?)
	local old = self.leaves[tile]
	if old then
		self.leaves[tile] = nil
		if animate then
			Util.tween(Util.scaler(old), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.26, function()
				old:Destroy()
			end)
		else
			old:Destroy()
		end
	end
	if not (span and span.up) or not self.ground[tile] then
		return
	end
	local lean = math.rad(span.lean)
	local reach = 0.5 * (self.layout.spacing or 2)
	local g = self.ground[tile] - Vector2.new(math.cos(lean), math.sin(lean)) * reach
	local hinge = MapArt.project(self.layout, U, g.X, g.Y)
	local turn = math.floor((span.lean % 360) / 22.5 + 0.5) % 16
	local size = 2.6 * U
	local holder = Util.frame(self.layers.Pawns, {
		Name = "Leaf" .. tile,
		AnchorPoint = Vector2.new(0.5, 0.736),
		Position = px(hinge),
		Size = UDim2.fromOffset(size, 1.25 * size),
		ZIndex = depthZ(hinge.Y),
	})
	if not Art.label(holder, "tiles/leaf_" .. turn, Vector2.new(size / 2, 0.625 * size), Vector2.new(size, 1.25 * size), false, { Name = "Leaf" }) then
		holder:Destroy()
		return
	end
	self.leaves[tile] = holder
	if animate then
		-- it swings up off the deck
		local sc = Util.scaler(holder)
		sc.Scale = 0.2
		Util.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Clockwork Cove's two cogs ({ a, b } or nil): each shows how far it carries you.
function BoardView:setCogs(gears: { number }?)
	local cogs = {}
	if gears and gears[1] and gears[2] then
		local a, b = gears[1], gears[2]
		local pa, pb = self.board.pathFromStart[a], self.board.pathFromStart[b]
		local gain = if pa and pb then #pb - #pa else b - a
		cogs[a], cogs[b] = gain, -gain
	end
	local changed = {}
	for t in self.cogs do
		if cogs[t] == nil then
			changed[t] = true
		end
	end
	for t, n in cogs do
		if self.cogs[t] ~= n then
			changed[t] = true
		end
	end
	self.cogs = cogs
	for t in changed do
		self:_paintTile(t)
	end
end

-- The gears turn with a clank: the cogs jolt twice (the riders follow as moves).
function BoardView:turnCogs(speed: number?)
	local pace = 1 / math.max(speed or 1, 0.25)
	for t in self.cogs do
		local parts = self.tileParts[t]
		if parts then
			Util.bump(parts.root, 0.08)
			task.delay(0.22 * pace, function()
				Util.bump(parts.root, 0.06)
			end)
			self:puff(self:tileWorld(t), C.sun)
		end
	end
	Sound.play("place", 1.4)
	task.delay(0.22 * pace, function()
		Sound.play("place", 1.2)
	end)
end

function BoardView:applySnapshot(snap)
	-- natural traps (permanent, or placed by the Naturalist)
	local natural = {}
	for _, n in snap.natural do
		natural[n.tile] = n.kind
	end
	for tile in self.natural do
		if not natural[tile] then
			self:setNatural(tile, nil)
		end
	end
	for tile, kind in natural do
		self:setNatural(tile, kind)
	end
	-- tokens
	local tokens = {}
	for _, t in snap.tokens do
		tokens[t.tile] = t.kind
	end
	for tile in self.tokens do
		if not tokens[tile] then
			self:setToken(tile, nil)
		end
	end
	for tile, kind in tokens do
		self:setToken(tile, kind)
	end
	-- placed items
	local placed = {}
	for _, e in snap.placed do
		placed[e.tile] = e
	end
	for tile in self.placed do
		if not placed[tile] then
			self:removePlaced(tile)
		end
	end
	for _, e in placed do
		self:placeItem(e)
	end
	-- hidden traps this player can see, and the embers of a Blast Off
	local traps = {}
	for _, t in snap.traps or {} do
		traps[t.tile] = traps[t.tile] or {}
		table.insert(traps[t.tile], t)
	end
	self:setTraps(traps)
	local embers = {}
	for _, e in snap.embers or {} do
		embers[e.tile] = e.owner or 0
	end
	self:setEmbers(embers)
	if snap.ghosts and #snap.ghosts > 0 then
		self:setGhosts(snap.ghosts)
	end
	-- the new maps: cracked ice, the Kraken's mark, the drawbridge, the cogs
	local cracks = {}
	for _, tile in snap.cracks or {} do
		cracks[tile] = true
	end
	self:setCracks(cracks)
	self:setKraken(snap.kraken)
	self:setBridges(snap.bridges)
	self:setCogs(snap.gears)
	-- pawns
	for _, p in snap.players do
		local pawn = self.pawns[p.seat]
		if pawn and not pawn.moving then
			pawn.tile = p.tile
		end
		if pawn then
			pawn.burning = (p.burning or 0) > 0
			pawn.frozen = (p.frozen or 0) > 0
			pawn.skip = (p.skip or 0) > 0
			local w = snap.wanted
			pawn.bounty = if w and w.seat == p.seat then w.pot else nil
			pawn.mostWanted = w ~= nil and w.seat == p.seat and w.most == true
			self:_statusMarks(p.seat)
		end
	end
	self:_arrange()
end

local function trapKey(list): string
	if not list then
		return ""
	end
	local out = {}
	for _, t in list do
		table.insert(out, tostring(t.item) .. ":" .. tostring(t.owner) .. ":" .. tostring(t.public))
	end
	return table.concat(out, ",")
end

-- The hidden traps this player can see: [tile] = { { item, owner, team, public } }.
function BoardView:setTraps(map)
	local changed = {}
	for tile in self.traps do
		if not map[tile] then
			changed[tile] = true
		end
	end
	for tile, list in map do
		if trapKey(self.traps[tile]) ~= trapKey(list) then
			changed[tile] = true
		end
	end
	self.traps = map
	for tile in changed do
		self:_paintTile(tile)
	end
end

-- A trap I can see was just hidden: it fades into its tile.
function BoardView:addTrap(tile: number, trap)
	self.traps[tile] = self.traps[tile] or {}
	table.insert(self.traps[tile], trap)
	self:_paintTile(tile)
	local parts = self.tileParts[tile]
	if parts and parts.trapShown then
		Util.popIn(parts.trapShown, 0.3, 0.3)
	end
end

-- A trap went off or was replaced (the first one of that kind on the tile).
function BoardView:removeTrap(tile: number, item: string?)
	local list = self.traps[tile]
	if not list then
		return
	end
	for i, t in list do
		if item == nil or t.item == item then
			table.remove(list, i)
			break
		end
	end
	if #list == 0 then
		self.traps[tile] = nil
	end
	self:_paintTile(tile)
end

-- Burning tiles: [tile] = owner seat.
function BoardView:setEmbers(map)
	local changed = {}
	for tile in self.embers do
		if map[tile] == nil then
			changed[tile] = true
		end
	end
	for tile in map do
		if self.embers[tile] == nil then
			changed[tile] = true
		end
	end
	self.embers = map
	for tile in changed do
		self:_paintTile(tile)
	end
end

---------------------------------------------------------------------------
-- pawns
---------------------------------------------------------------------------

function BoardView:addPawn(seat: number, info, tile: number)
	-- each player is a playing piece in their character's colour (that colour is their
	-- player's everywhere), with a soft shadow under it; it's placed (and shrinks to
	-- share a tile) by the middle of its base
	local color = Theme.playerColor(info.character)
	local root = Util.frame(self.layers.Pawns, {
		Name = "Pawn" .. seat,
		AnchorPoint = Vector2.new(0.5, PIECE_BASE),
		Size = UDim2.fromOffset(PAWN * U, PAWN * U),
		ZIndex = seat,
	})
	local share = Util.new("UIScale", { Name = "ShareScale", Parent = root })
	local lift = Util.frame(root, { Name = "Lift" })
	-- the stand their mastery earned, under the piece (it hops along with it)
	local tier = info.look and info.look.base
	local foot = PIECE_FOOT
	local onStand = false
	if type(tier) == "number" and tier > 0 then
		local _, standFoot = BaseArt.draw(lift, info.character or "mage", tier, { ZIndex = 2 })
		foot = standFoot or foot
		onStand = true
	end
	local shadow = Util.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = C.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.54, if onStand then 0.95 else foot - 0.03),
		Size = UDim2.fromScale(if onStand then 0.9 else 0.66, if onStand then 0.24 else 0.18),
		ZIndex = 0,
		Parent = root,
	})
	Util.corner(shadow, 0.5)
	local pawn = {
		frame = root,
		lift = lift,
		share = share,
		shadow = shadow,
		tile = tile,
		seat = seat,
		info = info,
		color = color,
		foot = foot,
	}
	self.pawns[seat] = pawn
	self.seatInfo[seat] = info
	pawn.mascot = PieceArt.stand(lift, info.character or "mage", info.look and info.look.finish, {
		Position = UDim2.fromScale(0.5, foot),
		Size = UDim2.fromScale(2 * PIECE_H, 2 * PIECE_H),
		ZIndex = 3,
	})
	self:_arrange(true)
	return root
end

--[[
	A pawn's piece reacts: "happy" (treasure, a gotcha) hops, "shock" (a trap) jumps
	and shakes, "dizzy" (bonked) wobbles, "sad" (sent home) droops, "angry" shakes.
]]
function BoardView:setMood(seat: number, mood: string, _seconds: number?)
	local pawn = self.pawns[seat]
	if pawn and pawn.mascot then
		PieceArt.react(pawn.mascot, mood)
	end
end

local SLOTS = BoardLayout.PawnSlots

-- Where pawn `seat` rests on its tile, and its scale there.
function BoardView:_restPosition(seat: number): (Vector2, number)
	local pawn = self.pawns[seat]
	local here = {}
	for s, p in self.pawns do
		if p.tile == pawn.tile and (not p.moving or s == seat) then
			table.insert(here, s)
		end
	end
	table.sort(here)
	local layout = SLOTS[math.clamp(#here, 1, #SLOTS)]
	local slot = layout[table.find(here, seat) or 1] or layout[1]
	return self:tileWorld(pawn.tile) + Vector2.new(slot[1], slot[2] * K) * U, layout.scale
end

function BoardView:_arrange(instant: boolean?)
	local count = {}
	for seat, pawn in self.pawns do
		if not pawn.moving then
			count[pawn.tile] = (count[pawn.tile] or 0) + 1
			local pos, scale = self:_restPosition(seat)
			pawn.frame.ZIndex = depthZ(pos.Y)
			if instant then
				pawn.frame.Position = px(pos)
				pawn.share.Scale = scale
			else
				Util.tween(pawn.frame, 0.25, { Position = px(pos) }, Enum.EasingStyle.Quad)
				Util.tween(pawn.share, 0.25, { Scale = scale }, Enum.EasingStyle.Quad)
			end
		end
	end
	-- a tile's number hides under pawns
	for tile, parts in self.tileParts do
		local n = count[tile] or 0
		if (self.cover[tile] or 0) ~= n then
			self.cover[tile] = n
			parts.label.Visible = parts.numbered and not busyTile(parts) and n == 0
		end
	end
end

function BoardView:setCurrent(seat: number?)
	self.currentSeat = seat
	for s, pawn in self.pawns do
		local on = s == seat
		if on and not pawn.bobbing then
			-- whoever's turn it is bobs on the spot
			pawn.bobbing = true
			task.spawn(function()
				while self.currentSeat == s and pawn.frame.Parent do
					if not pawn.moving then
						Util.tween(pawn.mascot, 0.35, { Position = UDim2.fromScale(0.5, pawn.foot - 0.08) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					end
					task.wait(0.35)
					if pawn.mascot then
						Util.tween(pawn.mascot, 0.35, { Position = UDim2.fromScale(0.5, pawn.foot) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
					end
					task.wait(0.35)
				end
				pawn.bobbing = false
			end)
		end
	end
	self:_ensureTag()
end

-- The name tag that floats over the current player's pawn (screen space, always readable).
function BoardView:_ensureTag()
	local seat = self.currentSeat
	local pawn = seat and self.pawns[seat]
	if not pawn then
		if self.tag then
			self.tag.Visible = false
		end
		return
	end
	if not self.tag then
		local tag = Util.new("Frame", {
			Name = "NameTag",
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			ZIndex = 6,
			Parent = self.overlay,
		})
		Util.corner(tag, 0.5)
		Util.pad(tag, 10, 0, 10, 0)
		local label = Widgets.label(tag, {
			text = "",
			font = "heavy",
			size = 15,
			color = C.white,
			sizeUDim = UDim2.fromOffset(0, 24),
			z = 7,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		self.tag = tag
		self.tagLabel = label
		self.tagStroke = Util.stroke(tag, C.line, 2.5)
	end
	-- a little flag in the player's colour
	local info = self.seatInfo[seat] or {}
	self.tagLabel.Text = info.tagName or info.name or ""
	self.tag.BackgroundColor3 = pawn.color
	self.tagLabel.TextColor3 = Theme.textOn(pawn.color)
	self.tag.Visible = true
end

function BoardView:_stepTags()
	local pathTag = self.pathTag
	if pathTag and self.pathTagTile then
		-- (over the ghost of your piece standing there)
		local at = self:toStage(self:tileWorld(self.pathTagTile) - Vector2.new(0, 1.45 * U))
		-- keep the whole row of badges over the board, even at its edges
		local list = pathTag:FindFirstChildOfClass("UIListLayout")
		local k = math.max(0.01, Util.inheritedScale(self.overlay, true))
		local half = (if list then list.AbsoluteContentSize.X / k else 260) / 2 + 6
		local f = self.focus
		local x = math.clamp(at.X, f.x + half, math.max(f.x + half, f.x + f.w - half))
		local y = math.max(at.Y, f.y + 30)
		pathTag.Position = UDim2.fromOffset(x, y)
	end
	local tag = self.tag
	if not tag or not tag.Visible then
		return
	end
	local pawn = self.currentSeat and self.pawns[self.currentSeat]
	if not pawn then
		return
	end
	local pos = pawn.frame.Position
	local lift = pawn.lift.Position
	local top = Vector2.new(pos.X.Offset, pos.Y.Offset + lift.Y.Offset - PAWN * U * (PIECE_BASE + 0.12) * pawn.share.Scale)
	local at = self:toStage(top)
	tag.Position = UDim2.fromOffset(at.X, at.Y - 4)
end

-- Persistent status marks on a pawn: flames (Burning), an ice block (Frozen), Zzz (Snared).
function BoardView:_statusMarks(seat: number)
	local pawn = self.pawns[seat]
	if not pawn then
		return
	end
	local function mark(name: string, on: boolean, build: () -> Instance)
		local existing = pawn.lift:FindFirstChild(name)
		if on and not existing then
			local m = build()
			m.Name = name
			m.Parent = pawn.lift
			if m:IsA("GuiObject") then
				Util.popIn(m, 0.25, 0.4)
			end
		elseif not on and existing then
			existing:Destroy()
		end
	end
	mark("Burning", pawn.burning == true, function()
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.56, 0.56),
			ZIndex = 9,
		})
		Icons.sticker(holder, StickerArt.misc.flame, nil, 0.08)
		task.spawn(function()
			while holder.Parent do
				Util.tween(holder, 0.25, { Size = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Sine)
				task.wait(0.25)
				Util.tween(holder, 0.25, { Size = UDim2.fromScale(0.6, 0.52) }, Enum.EasingStyle.Sine)
				task.wait(0.25)
			end
		end)
		return holder
	end)
	mark("Frozen", pawn.frozen == true, function()
		-- a see-through block of ice over the piece, with a snowflake on it
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.86, 0.86),
			ZIndex = 8,
		})
		local block = Util.new("Frame", {
			Name = "Ice",
			BackgroundColor3 = hex("BFEFFF"),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
			Parent = holder,
		})
		Util.corner(block, 0.22)
		Util.stroke(block, hex("45C3FF"), 0.06 * U)
		local flake = Util.frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.12),
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 9,
		})
		Icons.sticker(flake, StickerArt.misc.snowflake, nil, 0.08)
		return holder
	end)
	mark("Wanted", pawn.bounty ~= nil, function()
		-- a Wanted poster nailed up beside the piece, with the price on their head
		local poster = Util.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.1, 0.18),
			Size = UDim2.fromScale(0.62, 0.74),
			BackgroundColor3 = POSTER,
			BorderSizePixel = 0,
			Rotation = -8,
			ZIndex = 9,
		})
		Util.corner(poster, 0.08)
		Util.stroke(poster, C.ink, 0.05 * U)
		Util.new("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.06, 0.05),
			Size = UDim2.fromScale(0.88, 0.24),
			Text = "WANTED",
			TextScaled = true,
			FontFace = Theme.Font.Display,
			TextColor3 = POSTER_INK,
			ZIndex = 10,
			Parent = poster,
		})
		local face = Util.frame(poster, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.44, 0.44),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 10,
		})
		Icons.make(face, "skull", Icons.flatColors(POSTER_INK, POSTER), { Size = UDim2.fromScale(1, 1) })
		Util.new("TextLabel", {
			Name = "Price",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.06, 0.73),
			Size = UDim2.fromScale(0.88, 0.22),
			Text = "",
			TextScaled = true,
			FontFace = Theme.Font.Chunky,
			TextColor3 = POSTER_INK,
			ZIndex = 10,
			Parent = poster,
		})
		return poster
	end)
	local poster = pawn.lift:FindFirstChild("Wanted") :: Frame?
	if poster and pawn.bounty then
		local price = poster:FindFirstChild("Price") :: TextLabel?
		local title = poster:FindFirstChild("Title") :: TextLabel?
		if price then
			price.Text = pawn.bounty .. (if pawn.bounty == 1 then " coin" else " coins")
		end
		if title then
			title.Text = if pawn.mostWanted then "MOST WANTED" else "WANTED"
		end
		-- (the Most Wanted's poster is gold)
		poster.BackgroundColor3 = if pawn.mostWanted then C.sunLight else POSTER
	end
	mark("Snared", pawn.skip == true, function()
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.88, 0.08),
			Size = UDim2.fromScale(0.5, 0.5),
			ZIndex = 9,
		})
		Icons.sticker(holder, StickerArt.misc.zzz, nil, 0.08)
		return holder
	end)
end

-- The Wanted poster: on `seat` with the price `pot` (nil: nobody is Wanted).
function BoardView:setWanted(seat: number?, pot: number?, most: boolean?)
	for s, pawn in self.pawns do
		local on = s == seat and pot ~= nil
		pawn.bounty = if on then pot else nil
		pawn.mostWanted = on and most == true
		self:_statusMarks(s)
	end
end

function BoardView:setStatus(seat: number, status: string, on: boolean)
	local pawn = self.pawns[seat]
	if pawn then
		pawn[status] = on
		self:_statusMarks(seat)
	end
end

---------------------------------------------------------------------------
-- speech bubbles
---------------------------------------------------------------------------

--[[
	A speech bubble over pawn `seat`'s head: a chat line or an emote, big and in front
	of everything on the board, with its speaker's name on a tab in their colour. It
	stays on screen (pinned to the edge when the speaker is off it) and the character
	bobs as it talks. A new line from the same player replaces their last one.
		opts: { name, color (the tab), rim (the outline, an emote's colour), staff, emote }
]]
function BoardView:say(seat: number, text: string, opts: { [string]: any }?)
	local pawn = self.pawns[seat]
	if not pawn or type(text) ~= "string" or text == "" then
		return
	end
	local o = opts or {}
	local old = self.bubbles[seat]
	if old then
		old.holder:Destroy()
		self.bubbles[seat] = nil
	end
	local emote = o.emote == true
	local size = if emote then 24 else 20
	local maxW = if emote then 220 else 240
	local bounds = TextService:GetTextSize(text, size, Enum.Font.Nunito, Vector2.new(maxW / 1.12, 1000))
	local textW = math.clamp(math.ceil(bounds.X * 1.12) + 2, 40, maxW)
	local textH = math.max(size + 2, math.ceil(bounds.Y) + 2)
	local name = o.name or ""
	if o.staff then
		name = name .. "  ·  " .. o.staff
	end
	local tabW = math.min(maxW, math.ceil(TextService:GetTextSize(name, 14, Enum.Font.Nunito, Vector2.new(1000, 40)).X) + 22)
	local bodyW = math.max(textW + 26, tabW + 20)
	local bodyH = textH + 22
	local tail = 12
	local tabUp = 13
	self.bubbleZ += 3
	local z = self.bubbleZ
	local holder = Util.frame(self.overlay, {
		Name = "Bubble" .. seat,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(bodyW, bodyH + tail + tabUp),
		ZIndex = z,
	})
	local tip = Util.new("Frame", {
		Name = "Tail",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -tail - 2),
		Size = UDim2.fromOffset(20, 20),
		Rotation = 45,
		ZIndex = z,
		Parent = holder,
	})
	Util.stroke(tip, C.line, 3)
	local rim = o.rim or C.line
	local body = Util.new("Frame", {
		Name = "Body",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, tabUp),
		Size = UDim2.fromOffset(bodyW, bodyH),
		ZIndex = z + 1,
		Parent = holder,
	})
	Util.corner(body, 12)
	Util.stroke(body, rim, if emote then 4 else 3)
	-- hide the body's outline where the tail joins it
	Util.new("Frame", {
		Name = "Joint",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, if emote then -4 else -3),
		Size = UDim2.fromOffset(20, 8),
		ZIndex = z + 2,
		Parent = body,
	})
	local label = Widgets.label(body, {
		text = text,
		font = if emote then "chunky" else "heavy",
		size = size,
		color = C.text,
		align = if textH > size + 6 then "left" else "center",
		wrap = true,
		sizeUDim = UDim2.new(1, -24, 1, -14),
		position = UDim2.fromOffset(12, 10),
		z = z + 3,
	})
	label.TextYAlignment = Enum.TextYAlignment.Center
	if name ~= "" then
		local color = o.color or C.steelDark
		local tab = Util.new("Frame", {
			Name = "Name",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(tabW, 24),
			ZIndex = z + 4,
			Parent = holder,
		})
		Util.corner(tab, 6)
		Util.stroke(tab, C.line, 2.5)
		local nameLabel = Widgets.label(tab, {
			text = name,
			font = "heavy",
			size = 14,
			color = Theme.textOn(color),
			align = "center",
			sizeUDim = UDim2.fromScale(1, 1),
			z = z + 5,
		})
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local entry = { holder = holder, w = bodyW, h = bodyH + tail + tabUp }
	self.bubbles[seat] = entry
	self:_stepBubbles()
	Util.popIn(holder, 0.3, 0.5)
	-- the character talks: a bob per word or so
	local words = 0
	for _ in string.gmatch(text, "%S+") do
		words += 1
	end
	task.spawn(function()
		for _ = 1, math.clamp(words, 2, 7) do
			if not holder.Parent then
				break
			end
			Util.bump(pawn.lift, 0.07)
			task.wait(0.24)
		end
	end)
	local seconds = math.clamp(Config.Chat.BubbleSeconds + #text / 25, 3, 9)
	task.delay(seconds, function()
		if self.bubbles[seat] == entry then
			self.bubbles[seat] = nil
		end
		if holder.Parent then
			Util.tween(Util.scaler(holder), 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.2)
			holder:Destroy()
		end
	end)
end

function BoardView:_stepBubbles()
	local f = self.focus
	for seat, b in self.bubbles do
		local pawn = self.pawns[seat]
		if not pawn or not b.holder.Parent then
			continue
		end
		local pos = pawn.frame.Position
		local lift = pawn.lift.Position
		local top = Vector2.new(pos.X.Offset, pos.Y.Offset + lift.Y.Offset - PAWN * U * (PIECE_BASE + 0.05) * pawn.share.Scale)
		local at = self:toStage(top)
		-- clear the name tag over the player whose turn it is
		local lifted = if seat == self.currentSeat and self.tag and self.tag.Visible then 28 else 0
		local half = b.w / 2 + 6
		local x = math.clamp(at.X, f.x + half, math.max(f.x + half, f.x + f.w - half))
		local y = math.clamp(at.Y - 2 - lifted, f.y + b.h + 4, math.max(f.y + b.h + 4, f.y + f.h - 4))
		b.holder.Position = UDim2.fromOffset(x, y)
	end
end

-- The middle of pawn `seat`'s piece (where effects aim; it stands on its base).
function BoardView:pawnWorld(seat: number): Vector2
	local pawn = self.pawns[seat]
	if not pawn then
		return Vector2.zero
	end
	local pos = pawn.frame.Position
	return Vector2.new(pos.X.Offset, pos.Y.Offset - (PIECE_BASE - 0.5) * PAWN * U * pawn.share.Scale)
end

--[[
	Animates pawn `seat` along `path` (tile ids). Walk-like kinds hop tile by tile;
	the rest (respawn, teleport...) vanish and reappear. Yields until done; `speed`
	below 1 hurries it (a screen catching up with the server).
]]
function BoardView:hop(seat: number, path: { number }, kind: string, trailId: string?, speed: number?)
	local pawn = self.pawns[seat]
	if not pawn or #path == 0 then
		return
	end
	pawn.moving = true
	self:_arrange()
	Util.tween(pawn.share, 0.15, { Scale = 1 }, Enum.EasingStyle.Quad)
	local pace = math.clamp(speed or 1, 0.25, 1)
	local step = Config.Timing.StepTime * pace
	if Pacing.walkKinds[kind] then
		for _, tile in path do
			pawn.tile = tile
			local target = self:tileWorld(tile) + Vector2.new(SLOTS[1][1][1], SLOTS[1][1][2] * K) * U
			local frame = pawn.frame :: Frame
			frame.ZIndex = depthZ(math.max(target.Y, frame.Position.Y.Offset))
			Util.tween(pawn.frame, step, { Position = px(target) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			-- arc up and back down
			Util.tween(pawn.lift, step * 0.5, { Position = UDim2.fromOffset(0, -0.5 * U) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(step * 0.5)
			Util.tween(pawn.lift, step * 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(step * 0.5)
			Sound.play("step", 0.92 + math.random() * 0.16)
			-- squash on landing
			local s = Util.scaler(pawn.lift)
			s.Scale = 0.9
			Util.tween(s, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
			CosmeticArt.trailBurst(self.layers.Fx, trailId, target + Vector2.new(0, 0.04 * U), U)
			self:follow(tile)
		end
	elseif Pacing.fastKinds[kind] then
		-- knocked back, launched or sliding: the pawn zips along the path
		local fstep = Pacing.FastStep * pace
		local total = fstep * #path
		local arc = kind == "blast"
		if arc then
			Util.tween(pawn.lift, total * 0.5, { Position = UDim2.fromOffset(0, -1.6 * U) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(total * 0.5, function()
				Util.tween(pawn.lift, total * 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end)
			Sound.play("whoosh", 1.05)
		end
		if kind == "bonk" then
			local liftFrame = pawn.lift :: Frame
			liftFrame.Rotation = -18
			Util.tween(pawn.lift, total + 0.1, { Rotation = 0 }, Enum.EasingStyle.Back)
		end
		for _, tile in path do
			pawn.tile = tile
			local target = self:tileWorld(tile) + Vector2.new(SLOTS[1][1][1], SLOTS[1][1][2] * K) * U
			local frame = pawn.frame :: Frame
			frame.ZIndex = depthZ(math.max(target.Y, frame.Position.Y.Offset))
			Util.tween(pawn.frame, fstep, { Position = px(target) }, Enum.EasingStyle.Linear)
			task.wait(fstep)
			if not arc then
				CosmeticArt.trailBurst(self.layers.Fx, trailId, target + Vector2.new(0, 0.04 * U), U)
			end
			self:follow(tile)
		end
		local s = Util.scaler(pawn.lift)
		s.Scale = 0.85
		Util.tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.play("step", 0.8)
	elseif kind == "gears" then
		-- Clockwork Cove: the gears swing you over to the other cog in one arc
		local tile = path[#path]
		pawn.tile = tile
		local target = self:_restPosition(seat)
		local t = 0.7 * pace
		local frame = pawn.frame :: Frame
		frame.ZIndex = depthZ(math.max(target.Y, frame.Position.Y.Offset))
		Util.tween(pawn.frame, t, { Position = px(target) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Util.tween(pawn.lift, t * 0.5, { Position = UDim2.fromOffset(0, -2 * U) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Sound.play("whoosh", 0.9)
		task.wait(t * 0.5)
		Util.tween(pawn.lift, t * 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(t * 0.5)
		local s = Util.scaler(pawn.lift)
		s.Scale = 0.85
		Util.tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.play("step", 0.8)
		self:follow(tile)
	else
		local tile = path[#path]
		local s = Util.scaler(pawn.lift)
		self:puff(self:pawnWorld(seat), hex("FFFFFF"))
		Util.tween(s, 0.25 * pace, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.27 * pace)
		pawn.tile = tile
		local restPos = self:_restPosition(seat)
		;(pawn.frame :: Frame).Position = px(restPos)
		self:puff(self:tileWorld(tile), hex("FFFFFF"))
		Util.tween(s, 0.3 * pace, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.wait(0.3 * pace)
		self:follow(tile)
	end
	pawn.moving = false
	self:_arrange()
end

-- Two pawns trade places with a swirl.
function BoardView:swap(a: number, b: number, ta: number, tb: number)
	local pa, pb = self.pawns[a], self.pawns[b]
	if not pa or not pb then
		return
	end
	pa.moving, pb.moving = true, true
	local posA, posB = (pa.frame :: Frame).Position, (pb.frame :: Frame).Position
	self:swirl(self:pawnWorld(a), Theme.Category.neutral)
	self:swirl(self:pawnWorld(b), Theme.Category.neutral)
	Util.tween(pa.frame, 0.6, { Position = posB }, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
	Util.tween(pb.frame, 0.6, { Position = posA }, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
	task.wait(0.62)
	pa.tile, pb.tile = ta, tb
	pa.moving, pb.moving = false, false
	self:_arrange()
end

---------------------------------------------------------------------------
-- small world-space effects (bigger ones live in Effects.lua)
---------------------------------------------------------------------------

-- A quick jolt of the whole board (a card slammed down, something heavy landed).
function BoardView:shake(amount: number?, time: number?)
	local strength = (amount or 0.08) * U
	local length = time or 0.22
	local token = {}
	self.shaking = token
	task.spawn(function()
		local t0 = os.clock()
		while self.shaking == token and os.clock() - t0 < length do
			local k = 1 - (os.clock() - t0) / length
			self.jolt = Vector2.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2) * strength * k
			self:_applyCamera()
			task.wait()
		end
		if self.shaking == token then
			self.shaking = nil
			self.jolt = nil
			self:_applyCamera()
		end
	end)
end

-- The tile under a stage point (only among `tiles` when given), or nil. Uses the same
-- box as the tile's click area, so pointing and clicking always agree.
function BoardView:tileAt(stage: Vector2, tiles: { number }?): number?
	local world = self:toWorld(stage)
	local halfW, halfH = HIT / 2 * U, (HIT * K + S.tileDepth) / 2 * U
	local best, bestD = nil, math.huge
	local function try(id: number)
		local d = self:tileWorld(id) + Vector2.new(0, S.tileDepth / 2 * U) - world
		if math.abs(d.X) <= halfW and math.abs(d.Y) <= halfH and d.Magnitude < bestD then
			best, bestD = id, d.Magnitude
		end
	end
	if tiles then
		for _, id in tiles do
			try(id)
		end
	else
		for id in self.pos do
			try(id)
		end
	end
	return best
end

--[[
	What a card would look like on `tile`, see-through and lifted a touch: a board
	piece's sticker on your colour, or a hidden trap as only you will see it. nil
	clears it. Used while choosing where to place.
]]
function BoardView:previewTile(tile: number?, item: string?, color: Color3?)
	if self.ghostTile == tile and self.ghostItem == item then
		return
	end
	if self.ghost then
		local g = self.ghost
		self.ghost = nil
		Util.tween(g, 0.1, { GroupTransparency = 1 })
		task.delay(0.11, function()
			g:Destroy()
		end)
	end
	self.ghostTile, self.ghostItem = tile, item
	if not tile or not item then
		return
	end
	-- (a group tall enough for a thing standing on the tile: the tile's middle is 0.4
	-- above its own)
	local g = Util.new("CanvasGroup", {
		Name = "Ghost",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(self:tileWorld(tile) - Vector2.new(0, 0.4 * U)),
		Size = UDim2.fromOffset(2.4 * U, 3.2 * U),
		ZIndex = 36,
		Parent = self.layers.Fx,
	})
	local mid = Vector2.new(1.2 * U, 2 * U)
	local def = Items.get(item)
	local hidden = def ~= nil and (def :: any).hidden == true
	local parts = self.tileParts[tile]
	local r = S.tileR * U * ((parts and parts.scale) or 1)
	-- the tile lit in your colour, and the thing on it as it will look (a hidden trap as
	-- only you will see it, in your ring)
	self:_tileShape(g, mid, r * 1.12, color or C.sun, 1, "GhostRim")
	local look = LOOKS[item]
	local shown = nil
	if item == "conveyor" then
		-- the tile turned into a belt, its ridges running on along the trail
		local conveyor = LOOKS.conveyor
		local ahead = self.board.forward[tile] and self.board.forward[tile][1]
		local v = if ahead then self.ground[ahead] - self.ground[tile] else Vector2.new(1, 0)
		shown = self:_drawLook(g, conveyor, r, 2, 0, mid, nil)
		if shown then
			local band = self:_tileShape(g, mid, r - BEVEL * U, hex(string.sub(conveyor.bands.color, 2)), 3, "Bands")
			Util.new("UIGradient", { Rotation = math.deg(math.atan2(v.Y, v.X)), Transparency = bands(0, conveyor.bands), Parent = band })
		end
	elseif look then
		if hidden then
			local fr = r - BEVEL * U
			Art.label(g, "ground/ring", mid, Vector2.new(2 * fr, 2 * fr * K), false, {
				Name = "Owner",
				ImageColor3 = if self.mySeat then Theme.seatColor(self.mySeat) else C.coral,
				ZIndex = 2,
			})
		end
		shown = self:_drawLook(g, look, r, if look.face then 2 else 4, if hidden then HIDDEN else 0, mid, parts and parts.angle)
	end
	if not shown then
		local at = UDim2.fromOffset(mid.X, mid.Y)
		if hidden then
			trapMark(g, { item = item, owner = self.mySeat or 0 }, at, 0.8 * U, 3)
		else
			plaque(g, item, self.mySeat, at, 0.86 * U, 3)
		end
	end
	self.ghost = g
	Util.tween(g, 0.12, { GroupTransparency = 0.2 })
	local s = Util.scaler(g)
	s.Scale = 0.85
	Util.tween(s, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
end

--[[
	Where a move would take you: a trail of dots along the path, a ghost of your
	piece on the tile it ends on, and what happens there as little tags over it.
		o = { character, finish, color, badges = { { text, color } } }
	nil (or an empty path) clears it.
]]
function BoardView:showPath(path: { number }?, o: { [string]: any }?)
	self:clearPath()
	if not path or #path == 0 then
		return
	end
	local opts = o or {}
	local color = opts.color or C.sun
	-- over the board pieces but under the pawns, so nobody is hidden by the dots
	local layer = Util.frame(self.layers.Pieces, { Name = "PathPreview", ZIndex = 32 })
	self.pathLayer = layer
	for i, tile in path do
		if i < #path then
			-- a dot lying on each tile on the way, ringed in ink
			local dot = Util.frame(layer, {
				Name = "Dot" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = px(self:tileWorld(tile)),
				Size = UDim2.fromOffset(0.42 * U, 0.42 * U * K),
				ZIndex = 33,
			})
			local mid = Vector2.new(0.21 * U, 0.21 * U * K)
			MapArt.ellipse(dot, mid, 0.42 * U, 0.42 * U * K, C.line, 33, "Rim")
			MapArt.ellipse(dot, mid, 0.32 * U, 0.32 * U * K, color, 34, "Fill")
			local sc = Util.scaler(dot)
			sc.Scale = 0
			Util.tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, (i - 1) * 0.025)
		end
	end
	local land = path[#path]
	local at = self:tileWorld(land)
	-- a glowing ring lying on the landing tile
	local w = 1.5 * U * ((self.tileParts[land] and self.tileParts[land].scale) or 1)
	MapArt.ellipse(layer, at, w, w * K, color, 33, "Landing", 0.7)
	local ring = Art.label(layer, "ground/ring", at, Vector2.new(w, w * K), false, {
		Name = "LandingRing",
		ImageColor3 = color,
		ZIndex = 33,
	})
	if ring then
		task.spawn(function()
			while ring.Parent do
				Util.tween(ring, 0.4, { ImageTransparency = 0.6 }, Enum.EasingStyle.Sine)
				task.wait(0.4)
				Util.tween(ring, 0.4, { ImageTransparency = 0 }, Enum.EasingStyle.Sine)
				task.wait(0.4)
			end
		end)
	end
	-- a ghost of your piece standing there
	if opts.character then
		local ghost = Util.new("CanvasGroup", {
			Name = "Ghost",
			BackgroundTransparency = 1,
			GroupTransparency = 0.4,
			AnchorPoint = Vector2.new(0.5, PIECE_BASE),
			Position = px(at),
			Size = UDim2.fromOffset(PAWN * U, PAWN * U),
			ZIndex = 34,
			Parent = layer,
		})
		PieceArt.stand(ghost, opts.character, opts.finish, {
			Position = UDim2.fromScale(0.5, PIECE_FOOT),
			Size = UDim2.fromScale(2 * PIECE_H, 2 * PIECE_H),
		})
		local sc = Util.scaler(ghost)
		sc.Scale = 0.6
		Util.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, math.min(0.25, #path * 0.025))
	end
	-- what happens there, in screen space so it reads at any zoom
	local badges = opts.badges or {}
	if #badges > 0 then
		local tag = Util.frame(self.overlay, {
			Name = "PathTags",
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(260, 26),
			ZIndex = 8,
		})
		Util.list(tag, "x", 4, "Center", "Bottom")
		for i, b in badges do
			local badge = Widgets.badge(tag, {
				text = b.text,
				color = b.color or C.sun,
				height = 24,
				textSize = 14,
				layoutOrder = i,
				z = 9,
			})
			Util.popIn(badge, 0.2, 0.5)
		end
		self.pathTag = tag
		self.pathTagTile = land
		self:_stepTags()
	end
end

function BoardView:clearPath()
	if self.pathLayer then
		self.pathLayer:Destroy()
		self.pathLayer = nil
	end
	if self.pathTag then
		self.pathTag:Destroy()
		self.pathTag = nil
	end
	self.pathTagTile = nil
end

function BoardView:puff(at: Vector2, color: Color3)
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local dot = Util.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(at),
			Size = UDim2.fromOffset(0.22 * U, 0.22 * U),
			ZIndex = 40,
			Parent = self.layers.Fx,
		})
		Util.corner(dot, 0.5)
		Util.tween(dot, 0.4, {
			Position = px(at + Vector2.new(math.cos(a), math.sin(a)) * 0.7 * U),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0.08 * U, 0.08 * U),
		}, Enum.EasingStyle.Quad)
		task.delay(0.42, function()
			dot:Destroy()
		end)
	end
end

function BoardView:swirl(at: Vector2, color: Color3)
	for i = 1, 3 do
		local ring = Util.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(at),
			Size = UDim2.fromOffset(0.3 * U, 0.3 * U),
			ZIndex = 40,
			Parent = self.layers.Fx,
		})
		Util.corner(ring, 0.5)
		local st = Util.stroke(ring, color, 3)
		task.delay((i - 1) * 0.12, function()
			Util.tween(ring, 0.5, { Size = UDim2.fromOffset(1.8 * U, 1.8 * U) }, Enum.EasingStyle.Quad)
			Util.tween(st, 0.5, { Transparency = 1 })
			task.delay(0.52, function()
				ring:Destroy()
			end)
		end)
	end
end

-- Pop-up text over the board. Sized in stage pixels (not world) so it stays readable
-- however far the camera is zoomed out. It starts above the character's head, clear of
-- the name tag over the player whose turn it is.
function BoardView:floatText(at: Vector2, text: string, color: Color3, size: number?)
	local k = math.max(0.4, self:unitPixels() / U)
	local label = Widgets.label(self.layers.Fx, {
		text = text,
		font = "chunky",
		size = math.floor((size or 26) / k),
		color = color,
		align = "center",
		sizeUDim = UDim2.fromOffset(8 * U, 1.4 * U),
		anchor = Vector2.new(0.5, 0.5),
		position = px(at - Vector2.new(0, 1.05 * U)),
		outline = C.ink,
		outlineThickness = 3 / k,
		z = 60,
	})
	Util.popIn(label, 0.3, 0.4)
	Util.tween(label, 1.2, { Position = px(at - Vector2.new(0, 1.9 * U)) }, Enum.EasingStyle.Quad)
	task.delay(0.9, function()
		Util.tween(label, 0.35, { TextTransparency = 1 })
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			Util.tween(st, 0.35, { Transparency = 1 })
		end
	end)
	task.delay(1.3, function()
		label:Destroy()
	end)
end

---------------------------------------------------------------------------
-- picking tiles
---------------------------------------------------------------------------

--[[
	Lights up `tiles` and calls onPick(tile) when one is chosen. With opts.confirm
	(touch screens), the first tap only selects a tile (onSelect(tile) lets the caller
	show a "place here" button) and a second tap on it confirms. opts.preview = item id
	shows the tile under the pointer as it will look (previewTile); opts.onHover(tile?)
	hears about it too. Returns a cancel function.
]]
function BoardView:highlight(tiles: { number }, color: Color3, onPick: (number) -> (), opts: { [string]: any }?)
	self:clearHighlight()
	local o = opts or {}
	local marks: { GuiObject } = {}
	local conns = {}
	local selected: number? = nil
	local function showPreview(tile: number?)
		if o.preview then
			self:previewTile(tile, o.preview, color)
		end
		if o.onHover then
			o.onHover(tile)
		end
	end
	for _, tile in tiles do
		local center = self:tileWorld(tile) + Vector2.new(0, S.tileDepth / 2 * U)
		local parts = self.tileParts[tile]
		local glow = self:_tileShape(self.layers.Fx, center, S.tileR * U * 1.22 * (parts and parts.scale or 1), color, 30, "Glow")
		;(glow :: any)[alphaOf(glow)] = 0.5
		table.insert(marks, glow)
		local hit = self.hits[tile]
		hit.Visible = true
		table.insert(conns, hit.MouseEnter:Connect(function()
			if not o.confirm then
				showPreview(tile)
				if o.preview then
					Sound.play("hover")
				end
			end
		end))
		table.insert(conns, hit.MouseLeave:Connect(function()
			if not o.confirm then
				showPreview(nil)
			end
		end))
		table.insert(conns, hit.Activated:Connect(function()
			if self.dragMoved then
				return -- that was a pan, not a tap
			end
			if o.confirm and selected ~= tile then
				selected = tile
				showPreview(tile)
				Sound.play("click")
				if o.onSelect then
					o.onSelect(tile)
				end
				return
			end
			Sound.play("click")
			onPick(tile)
		end))
	end
	-- glow pulse
	local alive = true
	task.spawn(function()
		while alive do
			for _, f in marks do
				Util.tween(f, 0.5, { [alphaOf(f)] = 0.72 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.5)
			if not alive then
				break
			end
			for _, f in marks do
				Util.tween(f, 0.5, { [alphaOf(f)] = 0.45 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.5)
		end
	end)
	self._highlight = {
		marks = marks,
		conns = conns,
		tiles = tiles,
		stop = function()
			alive = false
			showPreview(nil)
		end,
		selected = function()
			return selected
		end,
	}
	return function()
		self:clearHighlight()
	end
end

function BoardView:selectedTile(): number?
	local h = self._highlight
	return if h then h.selected() else nil
end

function BoardView:clearHighlight()
	local h = self._highlight
	if not h then
		return
	end
	self._highlight = nil
	h.stop()
	for _, m in h.marks do
		m:Destroy()
	end
	for _, c in h.conns do
		c:Disconnect()
	end
	for _, tile in h.tiles do
		self.hits[tile].Visible = false
	end
end

---------------------------------------------------------------------------
-- intro: the board snaps together like building pieces
---------------------------------------------------------------------------

function BoardView:buildIntro(duration: number)
	local tiles = self.layout.tiles
	local per = math.min(0.06, (duration * 0.6) / math.max(1, #tiles))
	self.layers.Pawns.Visible = false
	for _, t in tiles do
		local root = self.tileParts[t.id].root :: Frame
		root.Visible = false
	end
	task.spawn(function()
		for i, t in tiles do
			local root = self.tileParts[t.id].root :: Frame
			local base = root.Position
			root.Position = base - UDim2.fromOffset(0, 0.9 * U)
			root.Visible = true
			local s = Util.scaler(root)
			s.Scale = 1.25
			Util.tween(root, 0.22, { Position = base }, Enum.EasingStyle.Bounce)
			Util.tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Quad)
			if i % 3 == 0 then
				Sound.play("tick", 0.8 + (i / #tiles) * 0.8)
			end
			task.wait(per)
		end
		task.wait(0.3)
		self.layers.Pawns.Visible = true
		for _, pawn in self.pawns do
			local s = Util.scaler(pawn.lift)
			s.Scale = 0
			Util.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			pawn.lift.Position = UDim2.fromOffset(0, -U)
			Util.tween(pawn.lift, 0.35, { Position = UDim2.new() }, Enum.EasingStyle.Bounce)
		end
		Sound.play("step")
	end)
end

-- Is this item one of the neutral cards? (for colouring)
function BoardView.isNeutral(item: string): boolean
	return NEUTRAL_ITEMS[item] == true or (Items.get(item) ~= nil and (Items.get(item) :: any).category == "neutral")
end

BoardView.UNIT = U
BoardView.pixel = px

return BoardView
