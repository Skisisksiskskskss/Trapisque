--[[
	BoardView
	Draws a Trapisque board as a parchment treasure map and animates everything on it.

	The whole map is built once in "world" pixels (U px per hex unit) inside a frame
	that is scaled with a UIScale to fit the screen, so strokes and text scale together.

	view = BoardView.new(parent, mapId)
	view:applySnapshot(snap)            -- tokens, placed items, natural traps, pawns
	view:hop(seat, path, kind)          -- animate a move (yields)
	view:highlight(tiles, onPick)       -- let the player pick a tile
	view:tileWorld(tile) -> Vector2     -- centre of a tile in world pixels
	view:buildIntro()                   -- tiles snap into place one by one
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Board = require(Shared.Game.Board)
local Rng = require(Shared.Game.Rng)
local Config = require(Shared.Config)
local Pacing = require(Shared.Game.Pacing)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Shapes = require(UI.Shapes)
local Icons = require(UI.Icons)
local IconData = require(UI.IconData)
local DecorData = require(UI.DecorData)
local CosmeticArt = require(UI.CosmeticArt)
local Widgets = require(UI.Widgets)
local BoardLayout = require(script.Parent.BoardLayout)
local Sound = require(UI.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local U = 46 -- world pixels per hex unit
local S = BoardLayout.Style

local THEMES = {
	water = { paper = hex("F2E2BD"), wash = hex("93C6C4"), washA = 0.55, ink = hex("3C6E8F"), acc = hex("E6D3A3"), acc2 = hex("C2513B"), rock = hex("8FA7A8") },
	dungeon = { paper = hex("EBDDBE"), wash = hex("A39B8E"), washA = 0.5, ink = hex("5A4A3A"), acc = hex("CDBFA6"), acc2 = hex("E0732C") },
	swamp = { paper = hex("EEE4BC"), wash = hex("9DB271"), washA = 0.55, ink = hex("4E6B34"), acc = hex("B9C98B"), acc2 = hex("9C4A2E") },
}

local TILE_COLORS = {
	normal = { hex("CB955C"), hex("DBAA72") },
	branch = { hex("B7A48A"), hex("C9B79C") },
	start = { hex("E4DCCB"), hex("F3EEE2") },
	treasure = { hex("E9B53A"), hex("F7CF5E") },
	shortcutGate = { hex("7E858D"), hex("98A0A8") },
	river = { hex("6FA8CF"), hex("8DBFE0") },
	gate = { hex("79818A"), hex("959DA6") },
	slime = { hex("7DB843"), hex("97CE57") },
}
local NATURAL_ICON = { river = "river_trap", gate = "lock", slime = "slime_trap" }
local TOKEN_ICON = { trap = "token_trap", assist = "token_assist", neutral = "token_neutral", potion = "token_potion" }

local BoardView = {}
BoardView.__index = BoardView

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function BoardView.new(parent: Frame, mapId: string)
	local self = setmetatable({}, BoardView)
	local def = Maps.get(mapId)
	self.def = def
	self.board = Board.get(def)
	self.layout = BoardLayout.build(self.board, def, Rng)
	self.theme = THEMES[def.theme] or THEMES.water
	self.maid = Util.maid()
	self.zoom = 1
	self.pan = Vector2.zero

	local L = self.layout
	self.worldW, self.worldH = L.w * U, L.h * U

	self.container = Util.frame(parent, { Name = "Board", ClipsDescendants = true })
	self.world = Util.frame(self.container, {
		Name = "World",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.worldW, self.worldH),
	})
	self.scale = Util.new("UIScale", { Parent = self.world })

	self.layers = {}
	for i, name in { "Paper", "Land", "Decor", "Links", "Tiles", "Marks", "Pieces", "Pawns", "Fx", "Hits" } do
		self.layers[name] = Util.frame(self.world, { Name = name, ZIndex = i })
	end

	self.tileParts = {} -- [tile] = { root, top, inner, label, icon }
	self.tokens = {} -- [tile] = frame
	self.placed = {} -- [tile] = frame
	self.natural = {} -- [tile] = kind
	self.pawns = {} -- [seat] = { frame, tile, lift }
	self.seatInfo = {}

	self:_buildPaper()
	self:_buildLand()
	self:_buildDecor()
	self:_buildLinks()
	self:_buildTiles()
	self:_buildHits()

	self.maid:add(self.container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	self:_bindZoom()
	task.defer(function()
		self:_fit()
	end)
	return self
end

function BoardView:destroy()
	self.maid:clean()
	self.container:Destroy()
end

function BoardView:tileWorld(tile: number): Vector2
	local t = self.board.tiles[tile]
	local L = self.layout
	return Vector2.new((t.x - L.x0) * U, (t.y - L.y0) * U)
end

local function px(v: Vector2): UDim2
	return UDim2.fromOffset(v.X, v.Y)
end

-- Product of every UIScale above `inst` (the stage scales the whole UI).
local function inheritedScale(inst: Instance): number
	local s = 1
	local node = inst.Parent
	while node do
		local u = node:FindFirstChildOfClass("UIScale")
		if u then
			s *= u.Scale
		end
		node = node.Parent
	end
	return s
end

-- fit the world into the container (times the player's zoom), clamped panning
function BoardView:_fit()
	local abs = self.container.AbsoluteSize
	local outer = inheritedScale(self.world)
	self.outerScale = outer
	local cw, ch = abs.X / outer, abs.Y / outer
	local fitScale = math.min(cw / self.worldW, ch / self.worldH) * 0.98
	self.fitScale = fitScale
	local s = fitScale * self.zoom
	self.scale.Scale = s
	-- clamp pan so the map can't be dragged off screen
	local maxX = math.max(0, (self.worldW * s - cw) / 2)
	local maxY = math.max(0, (self.worldH * s - ch) / 2)
	self.pan = Vector2.new(math.clamp(self.pan.X, -maxX, maxX), math.clamp(self.pan.Y, -maxY, maxY))
	self.world.Position = UDim2.new(0.5, self.pan.X, 0.5, self.pan.Y)
end

function BoardView:_bindZoom()
	local dragging = false
	local last = nil
	self.maid:add(self.container.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			dragging = true
			last = input.Position
		end
	end))
	self.maid:add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			dragging = false
		end
	end))
	self.maid:add(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and last then
			local delta = input.Position - last
			last = input.Position
			local outer = self.outerScale or 1
			self.pan += Vector2.new(delta.X, delta.Y) / outer
			self:_fit()
		end
	end))
	self.maid:add(self.container.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:setZoom(self.zoom * (if input.Position.Z > 0 then 1.15 else 1 / 1.15))
		end
	end))
	self.maid:add(UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, state)
		if state == Enum.UserInputState.Change then
			self:setZoom(self.zoom * (1 + (scale - 1) * 0.05))
		end
	end))
end

function BoardView:setZoom(z: number)
	self.zoom = math.clamp(z, 1, 2.6)
	if self.zoom == 1 then
		self.pan = Vector2.zero
	end
	self:_fit()
end

-- Keep the given tile on screen when zoomed in.
function BoardView:follow(tile: number)
	if self.zoom <= 1.01 then
		return
	end
	local p = self:tileWorld(tile)
	local s = self.scale.Scale
	local target = Vector2.new((self.worldW / 2 - p.X) * s, (self.worldH / 2 - p.Y) * s)
	self.pan = target
	self:_fit()
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
	task.defer(function()
		if paper.Parent then
			Util.shadow(paper, { offset = 10, blur = 22, transparency = 0.45 })
		end
	end)
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
	local coastColor = Util.mix(T.ink, T.wash, 0.35)
	local land = self.layers.Land
	for pass = 1, 2 do
		for _, t in self.layout.tiles do
			local p = self:tileWorld(t.id)
			local r = if pass == 1 then 1.29 * U else 1.22 * U
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
		local cl = colors
		if d.kind == "rocks" and T.rock then
			cl = table.clone(colors)
			cl.acc = T.rock
		end
		Icons.draw(c, { { "group", fx = d.flip, ops = DecorData[d.kind] } }, cl)
	end
	-- compass rose
	local cp = L.compass
	local size = cp.size * U
	local holder = Util.frame(layer, {
		Name = "Compass",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((cp.x - L.x0) * U, (cp.y - L.y0) * U),
		Size = UDim2.fromOffset(size, size),
	})
	Icons.draw(Shapes.canvas(holder), DecorData.compass_rose, { ink = hex("6B4A2E"), bg = T.paper, acc2 = C.inkRed, acc = hex("6B4A2E"), hi = T.paper })
	self.compass = holder
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
			BackgroundColor3 = if ln.shortcut then C.inkRed else hex("6B4A2E"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(mid),
			Size = UDim2.fromOffset(0.34 * U, 0.1 * U),
			Rotation = math.deg(math.atan2(dir.Y, dir.X)),
			Parent = layer,
		})
		Util.corner(dash, 0.5)
	end
end

local function hexagon(parent: Instance, center: Vector2, radius: number, color: Color3, z: number, name: string): { Frame }
	local parts = {}
	for i, rot in { 0, 60, 120 } do
		local f = Util.new("Frame", {
			Name = name .. i,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(center),
			Size = UDim2.fromOffset(math.sqrt(3) * radius, radius),
			Rotation = rot,
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

function BoardView:_tileKind(t): string
	if t.kind ~= "normal" then
		return t.kind
	end
	if self.natural[t.id] then
		return self.natural[t.id]
	end
	if t.branch then
		return "branch"
	end
	return "normal"
end

function BoardView:_buildTiles()
	local layer = self.layers.Tiles
	for _, t in self.layout.tiles do
		local center = self:tileWorld(t.id)
		local root = Util.frame(layer, {
			Name = "Tile" .. t.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(center),
			Size = UDim2.fromOffset(2 * U, 2 * U),
		})
		local local0 = Vector2.new(U, U)
		local colors = TILE_COLORS[t.kind] or TILE_COLORS.normal
		if t.branch then
			colors = TILE_COLORS.branch
		end
		local side = hexagon(root, local0 + Vector2.new(0, S.tileDepth * U), S.tileScale * U, Util.shade(colors[1], -0.38), 1, "Side")
		local top = hexagon(root, local0, S.tileScale * U, colors[1], 2, "Top")
		local inner = {}
		local label = Widgets.label(root, {
			text = tostring(t.id),
			font = "chunky",
			size = math.floor(0.3 * U),
			color = hex("8A5A2E"),
			align = "center",
			sizeUDim = UDim2.fromOffset(U, 0.4 * U),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(U, U + 0.55 * U),
			z = 4,
		})
		label.TextTransparency = 0.3
		local parts = { root = root, side = side, top = top, inner = inner, label = label, icon = nil }
		self.tileParts[t.id] = parts
		self:_paintTile(t)
	end
end

-- (re)colours a tile and its built-in icon for its current kind
function BoardView:_paintTile(t)
	local parts = self.tileParts[t.id]
	local kind = self:_tileKind(t)
	local colors = TILE_COLORS[kind] or TILE_COLORS.normal
	setHexColor(parts.side, Util.shade(colors[1], -0.38))
	setHexColor(parts.top, colors[1])
	if parts.icon then
		parts.icon:Destroy()
		parts.icon = nil
	end
	local iconId, iconColor, size = nil, nil, 0.85
	if kind == "start" then
		iconId, iconColor = "flag", C.inkRed
	elseif kind == "treasure" then
		iconId, iconColor, size = "x_mark", C.inkRed, 1.05
	elseif kind == "shortcutGate" then
		iconId, iconColor = "gate_trap", hex("3A3F45")
	elseif NATURAL_ICON[kind] then
		iconId, iconColor = NATURAL_ICON[kind], C.white
	end
	parts.label.Visible = iconId == nil
	if iconId then
		local holder = Util.frame(parts.root, {
			Name = "TileIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(U, U - 0.02 * U),
			Size = UDim2.fromOffset(size * U, size * U),
			ZIndex = 5,
		})
		Icons.make(holder, iconId, Icons.flatColors(iconColor, colors[1], iconColor))
		parts.icon = holder
	end
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
			Size = UDim2.fromOffset(1.5 * U, 1.5 * U),
			Visible = false,
			Parent = self.layers.Hits,
		})
		self.hits[t.id] = hit
	end
end

---------------------------------------------------------------------------
-- dynamic things: tokens, placed items, natural traps
---------------------------------------------------------------------------

function BoardView:_makeToken(tile: number, kind: string)
	local center = self:tileWorld(tile) - Vector2.new(0, 0.14 * U)
	local holder = Util.frame(self.layers.Marks, {
		Name = "Token" .. tile,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(center),
		Size = UDim2.fromOffset(0.8 * U, 0.8 * U),
	})
	Shapes.circle(holder, 0.5, 0.6, 0.98, C.black, { t = 0.7, name = "Shadow" })
	Icons.medallion(holder, TOKEN_ICON[kind] or "info", Theme.Category[kind] or C.inkSoft, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	-- slow idle bob so the board feels alive
	local phase = tile * 0.7
	local base = center
	task.spawn(function()
		local t0 = os.clock()
		while holder.Parent do
			local t = os.clock() - t0 + phase
			holder.Position = UDim2.fromOffset(base.X, base.Y + math.sin(t * 1.8) * 1.5)
			task.wait(1 / 20)
		end
	end)
	return holder
end

local OWNER_FALLBACK = C.inkSoft

function BoardView:_makePlaced(entry)
	local tile = entry.tile
	local center = self:tileWorld(tile) - Vector2.new(0, 0.14 * U)
	local item = entry.item
	local category = if item == "teleporter" or item == "spore_warper" or item == "conveyor" or item == "shifting_sands" then "neutral" else "trap"
	local holder = Util.frame(self.layers.Pieces, {
		Name = "Placed" .. tile,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(center),
		Size = UDim2.fromOffset(0.6 * U, 0.6 * U),
	})
	local shadow = Util.new("Frame", {
		BackgroundColor3 = C.black,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Util.corner(shadow, 0.18)
	local plaque = Util.new("Frame", {
		Name = "Plaque",
		BackgroundColor3 = C.wood,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	})
	Util.corner(plaque, 0.18)
	Util.stroke(plaque, Theme.Category[category], 3)
	Icons.engraved(plaque, item, C.wood, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = 4,
	})
	if entry.owner and entry.owner > 0 then
		local pip = Util.new("Frame", {
			Name = "Owner",
			BackgroundColor3 = Theme.Seat[((entry.owner - 1) % 6) + 1] or OWNER_FALLBACK,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.92, 0.04),
			Size = UDim2.fromScale(0.34, 0.34),
			ZIndex = 6,
			Parent = holder,
		})
		Util.corner(pip, 0.5)
		Util.stroke(pip, C.white, 2)
	end
	-- conveyors show arrows along their 3 tiles
	if item == "conveyor" and entry.tiles then
		for _, t in entry.tiles do
			local p = self:tileWorld(t)
			local nextTile = self.board.nextMain[t]
			local dirVec = if nextTile then (self:tileWorld(nextTile) - p).Unit else Vector2.new(1, 0)
			if entry.dir == "back" then
				dirVec = -dirVec
			end
			local arrow = Util.frame(holder, {
				Name = "BeltArrow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.X - center.X + 0.3 * U, p.Y - center.Y + 0.42 * U),
				Size = UDim2.fromOffset(0.5 * U, 0.5 * U),
				Rotation = math.deg(math.atan2(dirVec.Y, dirVec.X)) + 90,
				ZIndex = 7,
			})
			Icons.make(arrow, "up", Icons.flatColors(Theme.Category.neutral, C.white))
		end
	end
	if item == "teleporter" then
		local ring = Shapes.ring(holder, 0.5, 0.5, 1.6, 0.1, Theme.Category.neutral, { px = 30 })
		ring.ZIndex = 1
		task.spawn(function()
			while ring.Parent do
				ring.Rotation = (ring.Rotation + 2) % 360
				task.wait(1 / 30)
			end
		end)
	end
	Util.popIn(holder, 0.35, 0.3)
	return holder
end

function BoardView:applySnapshot(snap)
	-- natural traps (permanent, or placed by the Naturalist)
	local natural = {}
	for _, n in snap.natural do
		natural[n.tile] = n.kind
	end
	for tile, kind in natural do
		if self.natural[tile] ~= kind then
			self.natural[tile] = kind
			self:_paintTile(self.board.tiles[tile])
		end
	end
	-- tokens
	local tokens = {}
	for _, t in snap.tokens do
		tokens[t.tile] = t.kind
	end
	for tile, kind in tokens do
		if not self.tokens[tile] then
			self.tokens[tile] = self:_makeToken(tile, kind)
		end
	end
	for tile, f in self.tokens do
		if not tokens[tile] then
			f:Destroy()
			self.tokens[tile] = nil
		end
	end
	-- placed items
	local placed = {}
	for _, e in snap.placed do
		placed[e.tile] = e
	end
	for tile, e in placed do
		local existing = self.placed[tile]
		if not existing or existing:GetAttribute("Item") ~= e.item then
			if existing then
				existing:Destroy()
			end
			local f = self:_makePlaced(e)
			f:SetAttribute("Item", e.item)
			self.placed[tile] = f
		end
	end
	for tile, f in self.placed do
		if not placed[tile] then
			self:_removePlacedVisual(tile)
		end
	end
	-- pawns
	local occupancy = {}
	for _, p in snap.players do
		occupancy[p.tile] = occupancy[p.tile] or {}
		table.insert(occupancy[p.tile], p.seat)
	end
	for _, p in snap.players do
		local pawn = self.pawns[p.seat]
		if pawn and pawn.tile ~= p.tile then
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

function BoardView:_removePlacedVisual(tile: number)
	local f = self.placed[tile]
	if not f then
		return
	end
	self.placed[tile] = nil
	Util.tween(Util.scaler(f), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.26, function()
		f:Destroy()
	end)
end

---------------------------------------------------------------------------
-- pawns
---------------------------------------------------------------------------

function BoardView:addPawn(seat: number, info, tile: number)
	local seatColor = Theme.Seat[((seat - 1) % 6) + 1]
	local root = Util.frame(self.layers.Pawns, {
		Name = "Pawn" .. seat,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0.86 * U, 0.86 * U),
		ZIndex = seat,
	})
	local lift = Util.frame(root, { Name = "Lift" })
	CosmeticArt.pawn(lift, info.look and info.look.pawn, seatColor, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	if info.character then
		CosmeticArt.characterBadge(lift, info.character, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.8),
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 8,
		})
	end
	local ring = Util.new("Frame", {
		Name = "TurnRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.3, 1.3),
		Visible = false,
		ZIndex = 0,
		Parent = lift,
	})
	Util.corner(ring, 0.5)
	local st = Util.stroke(ring, C.brassLight, 3)
	self.pawns[seat] = { frame = root, lift = lift, tile = tile, ring = ring, ringStroke = st, seat = seat, info = info }
	self.seatInfo[seat] = info
	self:_arrange(true)
	return root
end

-- Where pawn `seat` rests on its tile (spread out when tiles are shared).
function BoardView:_restPosition(seat: number): Vector2
	local pawn = self.pawns[seat]
	local here = {}
	for s, p in self.pawns do
		if p.tile == pawn.tile then
			table.insert(here, s)
		end
	end
	table.sort(here)
	local n = #here
	local i = table.find(here, seat) or 1
	local base = self:tileWorld(pawn.tile) - Vector2.new(0, 0.3 * U)
	if n <= 1 then
		return base
	end
	local a = math.rad(-90 + 360 * (i - 1) / n)
	local r = if n == 2 then 0.3 * U else 0.38 * U
	return base + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.85)
end

function BoardView:_arrange(instant: boolean?)
	for seat, pawn in self.pawns do
		if not pawn.moving then
			local target = px(self:_restPosition(seat))
			if instant then
				pawn.frame.Position = target
			else
				Util.tween(pawn.frame, 0.25, { Position = target }, Enum.EasingStyle.Quad)
			end
		end
	end
end

function BoardView:setCurrent(seat: number?)
	for s, pawn in self.pawns do
		local on = s == seat
		pawn.ring.Visible = on
		pawn.frame.ZIndex = if on then 20 else s
		if on and not pawn.ringPulse then
			pawn.ringPulse = true
			task.spawn(function()
				while pawn.ring.Visible and pawn.ring.Parent do
					Util.tween(pawn.ring, 0.6, { Size = UDim2.fromScale(1.45, 1.45) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					Util.tween(pawn.ringStroke, 0.6, { Transparency = 0.6 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.6)
					Util.tween(pawn.ring, 0.6, { Size = UDim2.fromScale(1.25, 1.25) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					Util.tween(pawn.ringStroke, 0.6, { Transparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.6)
				end
				pawn.ringPulse = false
			end)
		end
	end
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
			Position = UDim2.fromScale(0.5, 0.35),
			Size = UDim2.fromScale(0.7, 0.7),
			ZIndex = 9,
		})
		Icons.make(holder, "fire", Icons.flatColors(hex("FF7B2E"), hex("FFD166"), hex("FFD166")))
		task.spawn(function()
			while holder.Parent do
				Util.tween(holder, 0.25, { Size = UDim2.fromScale(0.62, 0.78) }, Enum.EasingStyle.Sine)
				task.wait(0.25)
				Util.tween(holder, 0.25, { Size = UDim2.fromScale(0.74, 0.66) }, Enum.EasingStyle.Sine)
				task.wait(0.25)
			end
		end)
		return holder
	end)
	mark("Frozen", pawn.frozen == true, function()
		local holder = Util.frame(nil, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.15, 0.2),
			Size = UDim2.fromScale(0.5, 0.5),
			ZIndex = 9,
		})
		Icons.medallion(holder, "ice", hex("5DADE2"), { Size = UDim2.fromScale(1, 1) })
		return holder
	end)
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
	local step = Config.Timing.StepTime
	if Pacing.walkKinds[kind] then
		for _, tile in path do
			pawn.tile = tile
			local target = self:tileWorld(tile) - Vector2.new(0, 0.3 * U)
			Util.tween(pawn.frame, step, { Position = px(target) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			-- arc up and back down
			Util.tween(pawn.lift, step * 0.5, { Position = UDim2.fromOffset(0, -0.42 * U) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(step * 0.5)
			Util.tween(pawn.lift, step * 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(step * 0.5)
			Sound.play("hop", 0.9 + math.random() * 0.2)
			-- squash on landing
			local s = Util.scaler(pawn.lift)
			s.Scale = 0.88
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
		pawn.frame.Position = px(self:_restPosition(seat))
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
			Position = px(at + Vector2.new(math.cos(a), math.sin(a)) * 0.6 * U),
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
			Util.tween(ring, 0.5, { Size = UDim2.fromOffset(1.6 * U, 1.6 * U) }, Enum.EasingStyle.Quad)
			Util.tween(st, 0.5, { Transparency = 1 })
			task.delay(0.52, function()
				ring:Destroy()
			end)
		end)
	end
end

function BoardView:floatText(at: Vector2, text: string, color: Color3, size: number?)
	local label = Widgets.label(self.layers.Fx, {
		text = text,
		font = "chunky",
		size = size or math.floor(0.62 * U),
		color = color,
		align = "center",
		sizeUDim = UDim2.fromOffset(6 * U, U),
		anchor = Vector2.new(0.5, 0.5),
		position = px(at),
		outline = C.ink,
		outlineThickness = 3,
		z = 60,
	})
	Util.popIn(label, 0.3, 0.4)
	Util.tween(label, 1.2, { Position = px(at - Vector2.new(0, 1.1 * U)) }, Enum.EasingStyle.Quad)
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

-- Glows the given tiles and calls onPick(tile) when one is clicked. Returns a cancel fn.
function BoardView:highlight(tiles: { number }, color: Color3, onPick: (number) -> ())
	self:clearHighlight()
	local marks = {}
	local conns = {}
	for _, tile in tiles do
		local center = self:tileWorld(tile)
		local glow = hexagon(self.layers.Fx, center, S.tileScale * U * 1.06, color, 30, "Glow")
		for _, f in glow do
			f.BackgroundTransparency = 0.55
			table.insert(marks, f)
			task.spawn(function()
				while f.Parent do
					Util.tween(f, 0.5, { BackgroundTransparency = 0.75 }, Enum.EasingStyle.Sine)
					task.wait(0.5)
					if not f.Parent then
						break
					end
					Util.tween(f, 0.5, { BackgroundTransparency = 0.5 }, Enum.EasingStyle.Sine)
					task.wait(0.5)
				end
			end)
		end
		local hit = self.hits[tile]
		hit.Visible = true
		table.insert(conns, hit.MouseEnter:Connect(function()
			for _, part in self.tileParts[tile].top do
				Util.tween(part, 0.1, { BackgroundColor3 = Util.shade(color, 0.3) })
			end
			Sound.play("hover")
		end))
		table.insert(conns, hit.MouseLeave:Connect(function()
			self:_paintTile(self.board.tiles[tile])
		end))
		table.insert(conns, hit.Activated:Connect(function()
			Sound.play("click")
			onPick(tile)
		end))
	end
	self._highlight = { marks = marks, conns = conns, tiles = tiles }
	return function()
		self:clearHighlight()
	end
end

function BoardView:clearHighlight()
	local h = self._highlight
	if not h then
		return
	end
	self._highlight = nil
	for _, m in h.marks do
		m:Destroy()
	end
	for _, c in h.conns do
		c:Disconnect()
	end
	for _, tile in h.tiles do
		self.hits[tile].Visible = false
		self:_paintTile(self.board.tiles[tile])
	end
end

---------------------------------------------------------------------------
-- intro: the board snaps together like building pieces
---------------------------------------------------------------------------

function BoardView:buildIntro(duration: number)
	local tiles = self.layout.tiles
	local per = math.min(0.06, (duration * 0.6) / math.max(1, #tiles))
	for _, layerName in { "Marks", "Pieces", "Pawns" } do
		self.layers[layerName].Visible = false
	end
	for _, t in tiles do
		local root = self.tileParts[t.id].root
		root.Visible = false
	end
	task.spawn(function()
		for i, t in tiles do
			local root = self.tileParts[t.id].root
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
		task.wait(0.15)
		for _, layerName in { "Marks", "Pieces" } do
			self.layers[layerName].Visible = true
		end
		for _, f in self.layers.Marks:GetChildren() do
			if f:IsA("GuiObject") then
				Util.popIn(f, 0.3, 0.2)
			end
		end
		task.wait(0.25)
		self.layers.Pawns.Visible = true
		for _, pawn in self.pawns do
			local s = Util.scaler(pawn.lift)
			s.Scale = 0
			Util.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			pawn.lift.Position = UDim2.fromOffset(0, -U)
			Util.tween(pawn.lift, 0.35, { Position = UDim2.new() }, Enum.EasingStyle.Bounce)
		end
		Sound.play("hop")
	end)
end

BoardView.UNIT = U
BoardView.pixel = px

return BoardView
