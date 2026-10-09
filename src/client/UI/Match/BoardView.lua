--[[
	BoardView
	Draws a Trapisque board as a parchment treasure map and animates everything on it.

	The map is built once in "world" pixels (U px per hex unit). A camera fits the tiles
	into the part of the screen the HUD leaves free (setFocus) and lets players zoom
	(wheel, pinch, buttons) and pan (drag); the parchment runs on under the HUD.

	Reading order, bottom to top, is deliberate: the map, then tiles (their colour
	changes with whatever is on them: tokens are bold coloured inlays, traps and other
	cards reskin the tile), then pawns, which are the biggest, brightest things on the
	board and show each player's avatar.

		view = BoardView.new(parent, mapId, { rotate = bool })
		view:setFocus(rect)                 -- stage rect the tiles should fill
		view:applySnapshot(snap)            -- tokens, placed items, natural traps, pawns
		view:hop(seat, path, kind)          -- animate a move (yields)
		view:moveToken(from, to)            -- a used token jumps to its new tile
		view:highlight(tiles, color, onPick, opts) -- let the player pick a tile
		view:tileWorld(tile) -> Vector2     -- centre of a tile in world pixels
		view:toStage(world) -> Vector2      -- world pixels -> stage pixels (for overlays)
		view:buildIntro()                   -- tiles snap into place one by one
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Board = require(Shared.Game.Board)
local Rng = require(Shared.Game.Rng)
local Config = require(Shared.Config)
local Pacing = require(Shared.Game.Pacing)
local Items = require(Shared.Game.Items)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local DecorData = require(UI.DecorData)
local CosmeticArt = require(UI.CosmeticArt)
local Widgets = require(UI.Widgets)
local Avatars = require(UI.Avatars)
local BoardLayout = require(script.Parent.BoardLayout)
local TileSkins = require(script.Parent.TileSkins)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local U = 46 -- world pixels per hex unit
local S = BoardLayout.Style
local PAWN = S.pawn -- pawn diameter (hex units) when it has a tile to itself
local MAX_ZOOM = 3

local THEMES = {
	water = { paper = hex("F2E2BD"), wash = hex("6FB1B6"), washA = 0.62, ink = hex("2F5F7A"), acc = hex("E6D3A3"), acc2 = hex("C2513B") },
	dungeon = { paper = hex("EBDDBE"), wash = hex("8C8478"), washA = 0.58, ink = hex("4A3C2E"), acc = hex("A99E8A"), acc2 = hex("E0732C") },
	swamp = { paper = hex("EEE4BC"), wash = hex("86A15A"), washA = 0.62, ink = hex("3F5A2A"), acc = hex("93AA62"), acc2 = hex("9C4A2E") },
}

-- tile tops; the side is the same colour, darker; every tile has a dark rim
local TILE_COLORS = {
	normal = hex("E9BE84"),
	branch = hex("CDBB9C"),
	start = hex("F4EFE3"),
	treasure = hex("F7C948"),
	shortcutGate = hex("8F969E"),
}
local RIM = hex("4A2C14")
local NATURAL_ICON = { river = "river_trap", gate = "lock", slime = "slime_trap" }
local TOKEN_ICON = { trap = "token_trap", assist = "token_assist", neutral = "token_neutral", potion = "token_potion" }
local NEUTRAL_ITEMS = { teleporter = true, spore_warper = true, conveyor = true, shifting_sands = true }

local BoardView = {}
BoardView.__index = BoardView

local function px(v: Vector2): UDim2
	return UDim2.fromOffset(v.X, v.Y)
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function BoardView.new(parent: Frame, mapId: string, opts: { [string]: any }?)
	local self = setmetatable({}, BoardView)
	local def = Maps.get(mapId)
	self.def = def
	self.mapId = mapId
	self.board = Board.get(def)
	self.layout = BoardLayout.build(self.board, def, Rng, { rotate = opts ~= nil and opts.rotate == true })
	self.flat = self.layout.rotated == true
	self.theme = THEMES[def.theme] or THEMES.water
	self.maid = Util.maid()

	local L = self.layout
	self.worldW, self.worldH = L.w * U, L.h * U
	self.pos = {}
	for _, t in L.tiles do
		self.pos[t.id] = Vector2.new((t.x - L.x0) * U, (t.y - L.y0) * U)
	end
	local tb = L.tileBounds
	self.tileBox = {
		x0 = (tb.x0 - L.x0) * U,
		y0 = (tb.y0 - L.y0) * U,
		x1 = (tb.x1 - L.x0) * U,
		y1 = (tb.y1 - L.y0) * U,
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
	for i, name in { "Paper", "Land", "Decor", "Links", "Tiles", "Pieces", "Pawns", "Fx", "Hits" } do
		self.layers[name] = Util.frame(self.world, { Name = name, ZIndex = i })
	end

	self.tileParts = {} -- [tile] = { root, side, rim, top, label, icon, skin, inlay, plaque }
	self.cover = {} -- [tile] = pawns resting on it
	self.belt = {} -- [tile] = direction (degrees) of the conveyor belt over it
	self.beltOf = {} -- [conveyor origin tile] = the tiles it covers
	self.tokens = {} -- [tile] = kind
	self.placed = {} -- [tile] = entry { item, owner, dir, tiles }
	self.natural = {} -- [tile] = kind
	self.pawns = {} -- [seat] = { frame, lift, share, tile, ring, seat, info }
	self.seatInfo = {}

	-- camera
	self.focus = { x = 0, y = 0, w = 800, h = 600 }
	self.fitScale = 1
	local cx, cy = (self.tileBox.x0 + self.tileBox.x1) / 2, (self.tileBox.y0 + self.tileBox.y1) / 2
	self.cam = { x = cx, y = cy, zoom = 1 }
	self.goal = { x = cx, y = cy, zoom = 1 }
	self.manualUntil = 0

	self:_buildPaper()
	self:_buildLand()
	self:_buildDecor()
	self:_buildLinks()
	self:_buildTiles()
	self:_buildHits()

	self:_bindInput()
	self.maid:add(RunService.RenderStepped:Connect(function(dt)
		self:_stepCamera(dt)
		self:_stepTags()
	end))
	return self
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
	self.scale.Scale = s
	self.world.Position = UDim2.fromOffset(f.x + f.w / 2 - self.cam.x * s, f.y + f.h / 2 - self.cam.y * s)
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

	local function insideBoard(pos: Vector3 | Vector2): boolean
		local abs = self.container.AbsolutePosition
		local size = self.container.AbsoluteSize
		return pos.X >= abs.X and pos.Y >= abs.Y and pos.X <= abs.X + size.X and pos.Y <= abs.Y + size.Y
	end
	local function toStage(pos: Vector3 | Vector2): Vector2
		local abs = self.container.AbsolutePosition
		local k = Util.inheritedScale(self.container, true)
		return Vector2.new((pos.X - abs.X) / k, (pos.Y - abs.Y) / k)
	end

	self.maid:add(UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			touches[input] = true
		end
		if processed or not insideBoard(input.Position) then
			return
		end
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 or t == Enum.UserInputType.Touch then
			dragging = { input = input, last = toStage(input.Position), moved = 0 }
		end
	end))
	self.maid:add(UserInputService.InputChanged:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel then
			if not processed and insideBoard(input.Position) then
				self.manualUntil = os.clock() + 6
				self:zoomBy(if input.Position.Z > 0 then 1.18 else 1 / 1.18, toStage(input.Position))
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
		local now = toStage(input.Position)
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
				around = toStage((positions[1] + positions[2]) / 2)
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

function BoardView:_buildPaper()
	local T = self.theme
	local paper = Util.new("Frame", {
		Name = "Parchment",
		BackgroundColor3 = T.paper,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(self.worldW, self.worldH),
		Parent = self.layers.Paper,
	})
	Util.corner(paper, 0.35 * U)
	Util.stroke(paper, hex("6B4423"), 3)
	-- sea / stone / swamp wash inside the frame
	local inset = 0.55 * U
	local wash = Util.new("Frame", {
		Name = "Wash",
		BackgroundColor3 = T.wash,
		BackgroundTransparency = 1 - T.washA,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.fromOffset(self.worldW - 2 * inset, self.worldH - 2 * inset),
		ZIndex = 2,
		Parent = paper,
	})
	Util.corner(wash, 0.3 * U)
	-- double neatline frame
	for i, spec in { { 0.3, 3, 0.25 }, { 0.45, 1.5, 0.45 } } do
		local o = spec[1] * U
		local line = Util.new("Frame", {
			Name = "Neatline" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(o, o),
			Size = UDim2.fromOffset(self.worldW - 2 * o, self.worldH - 2 * o),
			ZIndex = 3,
			Parent = paper,
		})
		Util.corner(line, (0.25 - i * 0.03) * U)
		Util.stroke(line, hex("6B4A2E"), spec[2], spec[3])
	end
	self.paper = paper
end

-- Pale "land" under the path with an inked coastline: one ring of circles for the
-- coast, a slightly smaller ring of paper circles on top.
function BoardView:_buildLand()
	local T = self.theme
	local coastColor = Util.mix(T.ink, T.wash, 0.25)
	local land = self.layers.Land
	for pass = 1, 2 do
		for _, t in self.layout.tiles do
			local p = self:tileWorld(t.id)
			local r = if pass == 1 then S.coast * U else (S.coast - 0.07) * U
			local dot = Util.new("Frame", {
				Name = if pass == 1 then "Coast" else "Shore",
				BackgroundColor3 = if pass == 1 then coastColor else T.paper,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = px(p),
				Size = UDim2.fromOffset(2 * r, 2 * r),
				ZIndex = pass,
				Parent = land,
			})
			Util.corner(dot, 0.5)
		end
	end
end

function BoardView:_buildDecor()
	local T = self.theme
	local layer = self.layers.Decor
	local L = self.layout
	local inkMix = Util.mix(T.ink, T.wash, 0.22)
	local colors = { ink = inkMix, bg = Util.mix(T.paper, T.wash, T.washA), acc = T.acc, acc2 = T.acc2, hi = T.paper }
	for _, d in L.decor do
		local size = d.size * U
		local holder = Util.frame(layer, {
			Name = "Doodle_" .. d.kind,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((d.x - L.x0) * U, (d.y - L.y0) * U),
			Size = UDim2.fromOffset(size, size),
			Rotation = d.rot,
		})
		local c = Shapes.canvas(holder)
		Icons.draw(c, { { "group", fx = d.flip, ops = DecorData[d.kind] } }, colors)
	end
	-- compass rose (left out when no corner has room for it)
	local cp = L.compass
	if cp then
		local size = cp.size * U
		local holder = Util.frame(layer, {
			Name = "Compass",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((cp.x - L.x0) * U, (cp.y - L.y0) * U),
			Size = UDim2.fromOffset(size, size),
		})
		local ink = hex("6B4A2E")
		Icons.draw(Shapes.canvas(holder), DecorData.compass_rose, { ink = ink, bg = colors.bg, acc2 = C.inkRed, acc = ink, hi = colors.bg })
		self.compass = holder
	end
	-- title ribbon
	local title = L.title
	local ribbonHolder = Util.frame(layer, {
		Name = "TitleSpot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((title.x - L.x0) * U, (title.y - L.y0) * U),
		Size = UDim2.fromOffset(title.w * U, title.h * U),
	})
	local r = Widgets.ribbon(ribbonHolder, self.def.name, { width = title.w * U })
	r.Size = UDim2.fromOffset(title.w * U, title.h * U)
	r.Position = UDim2.fromScale(0.5, 0.5)
	local label = r:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MaxTextSize = math.floor(title.h * U * 0.62)
		end
	end
end

function BoardView:_buildLinks()
	local layer = self.layers.Links
	for _, ln in self.layout.links do
		local a = self:tileWorld(ln.from)
		local b = self:tileWorld(ln.to)
		local mid = (a + b) / 2
		local dir = (b - a).Unit
		local dash = Util.new("Frame", {
			Name = "Dash",
			BackgroundColor3 = if ln.shortcut then C.inkRed else hex("4A3020"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(mid),
			Size = UDim2.fromOffset(0.32 * U, 0.12 * U),
			Rotation = math.deg(math.atan2(dir.Y, dir.X)),
			Parent = layer,
		})
		Util.corner(dash, 0.5)
	end
end

-- A hexagon from three rotated rectangles (pointy-top, or flat-top when `flat`).
local function hexagon(parent: Instance, center: Vector2, radius: number, color: Color3, z: number, name: string, flat: boolean): { Frame }
	local parts = {}
	local base = if flat then 90 else 0
	for i, rot in { 0, 60, 120 } do
		local f = Util.new("Frame", {
			Name = name .. i,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(center),
			Size = UDim2.fromOffset(math.sqrt(3) * radius, radius),
			Rotation = rot + base,
			ZIndex = z,
			Parent = parent,
		})
		parts[i] = f
	end
	return parts
end

local function setHexColor(parts: { Frame }, color: Color3)
	for _, f in parts do
		f.BackgroundColor3 = color
	end
end

function BoardView:_buildTiles()
	local layer = self.layers.Tiles
	-- tiles lower on the map draw over the ones above (their wooden sides hang down)
	local order = {}
	for _, t in self.layout.tiles do
		table.insert(order, t)
	end
	table.sort(order, function(a, b)
		return a.y < b.y
	end)
	for i, t in order do
		local center = self:tileWorld(t.id)
		local root = Util.frame(layer, {
			Name = "Tile" .. t.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(center),
			Size = UDim2.fromOffset(2 * U, 2 * U),
			ZIndex = i,
		})
		local local0 = Vector2.new(U, U)
		local r = S.tileScale * U
		local side = hexagon(root, local0 + Vector2.new(0, S.tileDepth * U), r + 0.05 * U, RIM, 1, "Side", self.flat)
		local rim = hexagon(root, local0, r + 0.05 * U, RIM, 2, "Rim", self.flat)
		local top = hexagon(root, local0, r, TILE_COLORS.normal, 3, "Top", self.flat)
		local label = Widgets.label(root, {
			text = tostring(t.id),
			font = "chunky",
			size = math.floor(0.3 * U),
			color = hex("9A6A3C"),
			align = "center",
			sizeUDim = UDim2.fromOffset(U, 0.4 * U),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(U, U + 0.5 * U),
			z = 8,
		})
		local parts = { root = root, side = side, rim = rim, top = top, label = label, kind = t.kind, branch = t.branch }
		self.tileParts[t.id] = parts
		self:_paintTile(t.id)
	end
end

-- What a tile shows right now: natural hazard > belt > placed card > token > plain.
function BoardView:_paintTile(tile: number)
	local parts = self.tileParts[tile]
	if not parts then
		return
	end
	for _, key in { "skin", "icon", "inlay", "plaque" } do
		if parts[key] then
			parts[key]:Destroy()
			parts[key] = nil
		end
	end
	local kind = parts.kind
	local natural = self.natural[tile]
	local beltAngle = self.belt[tile]
	local entry = self.placed[tile]
	local token = self.tokens[tile]
	local topColor = TILE_COLORS[kind] or (if parts.branch then TILE_COLORS.branch else TILE_COLORS.normal)
	local skinKind = nil
	if natural then
		skinKind = natural
	elseif beltAngle then
		skinKind = "conveyor"
	elseif entry and entry.item ~= "conveyor" then
		skinKind = entry.item
	end
	if skinKind and TileSkins.top(skinKind) then
		topColor = TileSkins.top(skinKind) :: Color3
	end
	setHexColor(parts.top, topColor)
	setHexColor(parts.side, Util.shade(topColor, -0.5))

	local root = parts.root
	local function holder(name: string, size: number, z: number, y: number?): Frame
		return Util.frame(root, {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(U, U + (y or 0) * U),
			Size = UDim2.fromOffset(size * U, size * U),
			ZIndex = z,
		})
	end
	if skinKind then
		local h = holder("Skin", 2, 4)
		parts.skin = h
		TileSkins.draw(h, skinKind, { flat = self.flat, r = S.tileScale / 2, dir = beltAngle })
		local spin = h:FindFirstChild("Spin", true)
		if spin then
			task.spawn(function()
				while spin.Parent do
					(spin :: Frame).Rotation = ((spin :: Frame).Rotation + 1.5) % 360
					task.wait(1 / 30)
				end
			end)
		end
	end

	-- the card on the tile: a round plaque rimmed in its owner's colour
	if entry then
		local plaque = holder("Plaque", 0.74, 6)
		local rimColor = if entry.owner and entry.owner > 0 then Theme.Seat[((entry.owner - 1) % 6) + 1] else C.inkSoft
		local disc = Shapes.circle(plaque, 0.5, 0.5, 1, hex("2A1C13"))
		Util.scaledStroke(disc, rimColor, 0.1, 3)
		Icons.make(plaque, entry.item, Icons.flatColors(C.white, hex("2A1C13"), C.white), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.66, 0.66),
			ZIndex = 3,
		})
		parts.plaque = plaque
	elseif natural and NATURAL_ICON[natural] then
		local icon = holder("Icon", 0.72, 6)
		Icons.make(icon, NATURAL_ICON[natural], Icons.flatColors(C.white, topColor, C.white))
		parts.icon = icon
	elseif token then
		-- tokens are bold coloured inlays you can spot across the board
		local inlay = holder("Token", 1.18, 5)
		local color = Theme.Category[token] or C.inkSoft
		local disc = Shapes.circle(inlay, 0.5, 0.5, 1, color)
		Util.scaledStroke(disc, C.white, 0.07, 3)
		Icons.make(inlay, TOKEN_ICON[token] or "info", Icons.flatColors(C.white, color, C.white), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.64, 0.64),
			ZIndex = 3,
		})
		parts.inlay = inlay
	elseif kind == "start" or kind == "treasure" or kind == "shortcutGate" then
		local iconId, color, size = "flag", C.inkRed, 0.86
		if kind == "treasure" then
			iconId, color, size = "x_mark", C.inkRed, 1.05
		elseif kind == "shortcutGate" then
			iconId, color = "gate_trap", hex("3A3F45")
		end
		local icon = holder("Icon", size, 6)
		Icons.make(icon, iconId, Icons.flatColors(color, topColor, color))
		parts.icon = icon
	end
	local busy = parts.skin ~= nil or parts.icon ~= nil or parts.inlay ~= nil or parts.plaque ~= nil
	parts.label.Visible = not busy and (self.cover[tile] or 0) == 0
end

-- Invisible square buttons for picking tiles (rotated frames don't take clicks well).
function BoardView:_buildHits()
	self.hits = {}
	for _, t in self.layout.tiles do
		local hit = Util.new("TextButton", {
			Name = "Hit" .. t.id,
			Text = "",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(self:tileWorld(t.id)),
			Size = UDim2.fromOffset(1.55 * U, 1.55 * U),
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
	if kind and parts and parts.inlay then
		Util.popIn(parts.inlay, 0.3, 0.3)
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
	local color = Theme.Category[k] or C.inkSoft
	local disc = Shapes.circle(flyer, 0.5, 0.5, 1, color)
	Util.scaledStroke(disc, C.white, 0.07, 3)
	Icons.make(flyer, TOKEN_ICON[k] or "info", Icons.flatColors(C.white, color, C.white), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.64, 0.64),
		ZIndex = 3,
	})
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
		if parts and parts.inlay then
			Util.bump(parts.inlay, 0.25)
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
	if kind and parts and parts.skin then
		Util.popIn(parts.skin, 0.35, 0.4)
	end
end

-- A card placed on the board reskins its tile (or the conveyor's three tiles).
function BoardView:placeItem(entry, animate: boolean?)
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
	if animate then
		local parts = self.tileParts[tile]
		if parts then
			for _, key in { "skin", "plaque" } do
				if parts[key] then
					Util.popIn(parts[key], 0.35, 0.3)
				end
			end
			Util.bump(parts.root, 0.12)
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
	if parts and parts.plaque then
		local plaque = parts.plaque
		parts.plaque = nil
		plaque.Parent = self.layers.Fx
		plaque.Position = px(self:tileWorld(tile))
		Util.tween(Util.scaler(plaque), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.26, function()
			plaque:Destroy()
		end)
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
		local v = self:tileWorld(to) - self:tileWorld(from)
		self.belt[t] = math.deg(math.atan2(v.Y, v.X)) + (if dir == "back" then 180 else 0)
		self:_paintTile(t)
	end
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
	-- pawns
	for _, p in snap.players do
		local pawn = self.pawns[p.seat]
		if pawn and not pawn.moving then
			pawn.tile = p.tile
		end
		if pawn then
			pawn.burning = p.burning
			pawn.frozen = p.frozen
			self:_statusMarks(p.seat)
		end
	end
	self:_arrange()
end

---------------------------------------------------------------------------
-- pawns
---------------------------------------------------------------------------

function BoardView:addPawn(seat: number, info, tile: number)
	local seatColor = Theme.Seat[((seat - 1) % 6) + 1]
	local root = Util.frame(self.layers.Pawns, {
		Name = "Pawn" .. seat,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(PAWN * U, PAWN * U),
		ZIndex = seat,
	})
	local share = Util.new("UIScale", { Name = "ShareScale", Parent = root })
	local lift = Util.frame(root, { Name = "Lift" })
	-- a flat shadow on the tile so the pawn stands out from the board
	local shadow = Util.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = hex("1A120C"),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.54, 0.6),
		Size = UDim2.fromScale(0.94, 0.94),
		ZIndex = 0,
		Parent = root,
	})
	Util.corner(shadow, 0.5)
	CosmeticArt.pawn(lift, info.look and info.look.pawn, seatColor, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	})
	-- the player's own face in the middle: no mistaking a pawn for anything else
	Avatars.portrait(lift, info, {
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
	}, { ring = C.white, ringPx = 2, back = Util.shade(seatColor, 0.45) })
	local ring = Util.new("Frame", {
		Name = "TurnRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(1.2, 1.2),
		Visible = false,
		ZIndex = 0,
		Parent = lift,
	})
	Util.corner(ring, 0.5)
	local st = Util.stroke(ring, C.brassLight, 4)
	self.pawns[seat] = {
		frame = root,
		lift = lift,
		share = share,
		shadow = shadow,
		tile = tile,
		ring = ring,
		ringStroke = st,
		seat = seat,
		info = info,
		color = seatColor,
	}
	self.seatInfo[seat] = info
	self:_arrange(true)
	return root
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
	return self:tileWorld(pawn.tile) + Vector2.new(slot[1], slot[2]) * U, layout.scale
end

function BoardView:_arrange(instant: boolean?)
	local count = {}
	for seat, pawn in self.pawns do
		if not pawn.moving then
			count[pawn.tile] = (count[pawn.tile] or 0) + 1
			local pos, scale = self:_restPosition(seat)
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
			local busy = parts.skin ~= nil or parts.icon ~= nil or parts.inlay ~= nil or parts.plaque ~= nil
			parts.label.Visible = not busy and n == 0
		end
	end
end

function BoardView:setCurrent(seat: number?)
	self.currentSeat = seat
	for s, pawn in self.pawns do
		local on = s == seat
		pawn.ring.Visible = on
		pawn.frame.ZIndex = if on then 20 else s
		if on and not pawn.ringPulse then
			pawn.ringPulse = true
			task.spawn(function()
				while pawn.ring.Visible and pawn.ring.Parent do
					Util.tween(pawn.ring, 0.6, { Size = UDim2.fromScale(1.32, 1.32) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					Util.tween(pawn.ringStroke, 0.6, { Transparency = 0.55 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.6)
					Util.tween(pawn.ring, 0.6, { Size = UDim2.fromScale(1.14, 1.14) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					Util.tween(pawn.ringStroke, 0.6, { Transparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.6)
				end
				pawn.ringPulse = false
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
			BackgroundColor3 = hex("1F150E"),
			BackgroundTransparency = 0.1,
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
		self.tagStroke = Util.stroke(tag, C.white, 2)
	end
	local info = self.seatInfo[seat] or {}
	self.tagLabel.Text = info.tagName or info.name or ""
	self.tagStroke.Color = pawn.color
	self.tag.Visible = true
end

function BoardView:_stepTags()
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
	local top = Vector2.new(pos.X.Offset, pos.Y.Offset + lift.Y.Offset - PAWN * U * 0.62 * pawn.share.Scale)
	local at = self:toStage(top)
	tag.Position = UDim2.fromOffset(at.X, at.Y - 4)
end

-- Persistent status marks (burning / frozen) on a pawn.
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
		elseif not on and existing then
			existing:Destroy()
		end
	end
	mark("Burning", pawn.burning == true, function()
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.fromScale(0.56, 0.56),
			ZIndex = 9,
		})
		Icons.make(holder, "fire", Icons.flatColors(hex("FF7B2E"), hex("FFD166"), hex("FFD166")))
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
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.16),
			Size = UDim2.fromScale(0.4, 0.4),
			ZIndex = 9,
		})
		Icons.medallion(holder, "ice", hex("5DADE2"), { Size = UDim2.fromScale(1, 1) })
		return holder
	end)
end

function BoardView:setStatus(seat: number, status: string, on: boolean)
	local pawn = self.pawns[seat]
	if pawn then
		pawn[status] = on
		self:_statusMarks(seat)
	end
end

function BoardView:pawnWorld(seat: number): Vector2
	local pawn = self.pawns[seat]
	if not pawn then
		return Vector2.zero
	end
	local pos = pawn.frame.Position
	return Vector2.new(pos.X.Offset, pos.Y.Offset)
end

--[[
	Animates pawn `seat` along `path` (tile ids). Walk-like kinds hop tile by tile;
	the rest (respawn, teleport...) vanish and reappear. Yields until done.
]]
function BoardView:hop(seat: number, path: { number }, kind: string, trailId: string?)
	local pawn = self.pawns[seat]
	if not pawn or #path == 0 then
		return
	end
	pawn.moving = true
	self:_arrange()
	Util.tween(pawn.share, 0.15, { Scale = 1 }, Enum.EasingStyle.Quad)
	local step = Config.Timing.StepTime
	if Pacing.walkKinds[kind] then
		for _, tile in path do
			pawn.tile = tile
			local target = self:tileWorld(tile) + Vector2.new(0, SLOTS[1][1][2] * U)
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
			CosmeticArt.trailBurst(self.layers.Fx, trailId, target + Vector2.new(0, 0.3 * U), U)
			self:follow(tile)
		end
	else
		local tile = path[#path]
		local s = Util.scaler(pawn.lift)
		self:puff(self:pawnWorld(seat), hex("FFFFFF"))
		Util.tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.27)
		pawn.tile = tile
		local restPos = self:_restPosition(seat)
		;(pawn.frame :: Frame).Position = px(restPos)
		self:puff(self:tileWorld(tile), hex("FFFFFF"))
		Util.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.wait(0.3)
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
	local posA, posB = self:pawnWorld(a), self:pawnWorld(b)
	self:swirl(posA, Theme.Category.neutral)
	self:swirl(posB, Theme.Category.neutral)
	Util.tween(pa.frame, 0.6, { Position = px(posB) }, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
	Util.tween(pb.frame, 0.6, { Position = px(posA) }, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
	task.wait(0.62)
	pa.tile, pb.tile = ta, tb
	pa.moving, pb.moving = false, false
	self:_arrange()
end

---------------------------------------------------------------------------
-- small world-space effects (bigger ones live in Effects.lua)
---------------------------------------------------------------------------

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
-- however far the camera is zoomed out.
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
		position = px(at - Vector2.new(0, 0.5 * U)),
		outline = C.ink,
		outlineThickness = 3 / k,
		z = 60,
	})
	Util.popIn(label, 0.3, 0.4)
	Util.tween(label, 1.2, { Position = px(at - Vector2.new(0, 1.5 * U)) }, Enum.EasingStyle.Quad)
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
	shows what the tile will look like. Returns a cancel function.
]]
function BoardView:highlight(tiles: { number }, color: Color3, onPick: (number) -> (), opts: { [string]: any }?)
	self:clearHighlight()
	local o = opts or {}
	local marks = {}
	local conns = {}
	local selected: number? = nil
	local preview: Frame? = nil
	local function showPreview(tile: number?)
		if preview then
			preview:Destroy()
			preview = nil
		end
		if not tile or not o.preview then
			return
		end
		local p = Util.frame(self.layers.Fx, {
			Name = "Preview",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(self:tileWorld(tile)),
			Size = UDim2.fromOffset(0.9 * U, 0.9 * U),
			ZIndex = 35,
		})
		local disc = Shapes.circle(p, 0.5, 0.5, 1, hex("2A1C13"), { t = 0.15 })
		Util.scaledStroke(disc, color, 0.1, 3)
		Icons.make(p, o.preview, Icons.flatColors(C.white, hex("2A1C13"), C.white), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = 3,
		})
		preview = p
	end
	for _, tile in tiles do
		local center = self:tileWorld(tile)
		local glow = hexagon(self.layers.Fx, center, S.tileScale * U * 1.1, color, 30, "Glow", self.flat)
		for _, f in glow do
			f.BackgroundTransparency = 0.5
			table.insert(marks, f)
		end
		local hit = self.hits[tile]
		hit.Visible = true
		table.insert(conns, hit.MouseEnter:Connect(function()
			if not o.confirm then
				showPreview(tile)
				Sound.play("hover")
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
				Util.tween(f, 0.5, { BackgroundTransparency = 0.72 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.5)
			if not alive then
				break
			end
			for _, f in marks do
				Util.tween(f, 0.5, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Sine)
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
