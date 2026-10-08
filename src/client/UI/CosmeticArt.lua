--[[
	CosmeticArt
	Draws pawns, dice, trail particles, titles and emote bubbles from the cosmetic
	definitions in Shared/Meta/Cosmetics. All shapes, no images.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Meta.Cosmetics)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Shapes = require(script.Parent.Shapes)
local Icons = require(script.Parent.Icons)
local IconData = require(script.Parent.IconData)
local PawnPatterns = require(script.Parent.PawnPatterns)

local CosmeticArt = {}

local function hex(s: string?, fallback: Color3): Color3
	if type(s) == "string" and string.sub(s, 1, 1) == "#" then
		return Color3.fromHex(s)
	end
	return fallback
end

local RAINBOW = Util.seq({
	Color3.fromHex("FF5E5E"),
	Color3.fromHex("FFB13B"),
	Color3.fromHex("FFE45C"),
	Color3.fromHex("5EE07A"),
	Color3.fromHex("4FC3FF"),
	Color3.fromHex("8E7CFF"),
	Color3.fromHex("FF6FD8"),
})
CosmeticArt.RAINBOW = RAINBOW

-- Keeps a UIGradient slowly rotating (used for "spin" skins and mythic glows).
local spinning = {}
RunService.RenderStepped:Connect(function(dt)
	for g, speed in spinning do
		if g.Parent == nil then
			spinning[g] = nil
		else
			g.Rotation = (g.Rotation + dt * speed) % 360
		end
	end
end)
function CosmeticArt.spin(g: UIGradient, speed: number?)
	spinning[g] = speed or 60
end

function CosmeticArt.rarityColor(rarity: string): Color3
	local r = Cosmetics.rarityById[rarity]
	return if r then Color3.fromHex(r.color) else Theme.C.inkSoft
end

---------------------------------------------------------------------------
-- Pawn
---------------------------------------------------------------------------

--[[
	A pawn token: a coloured chip with a painted design, ringed in the player's seat
	colour so everyone can tell pawns apart whatever skin they wear.
	props go on the root frame (Size, Position...). Returns root.
]]
function CosmeticArt.pawn(parent: Instance?, skinId: string?, seatColor: Color3, props: { [string]: any }?): Frame
	local def = Cosmetics.get(skinId or "") or Cosmetics.get(Cosmetics.defaults.pawn)
	local look = def.look
	local fill = if look.fill == "seat" then seatColor elseif look.fill == "rainbow" then Color3.fromHex("FFFFFF") else hex(look.fill, seatColor)
	local fill2 = if look.fill == "seat" then Util.shade(seatColor, -0.22) else hex(look.fill2, Util.shade(fill, -0.2))
	local accent = hex(look.accent, Theme.C.white)

	local root = Util.frame(nil, {
		Name = "Pawn",
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end

	-- soft shadow
	Shapes.pill(root, 0.5, 0.92, 0.8, 0.2, Theme.C.black, { t = 0.65, name = "Shadow" })

	if look.glow then
		local glow = Shapes.circle(root, 0.5, 0.5, 1.1, hex(look.glow, accent), { t = 0.72, name = "Glow" })
		local s = Util.scaler(glow)
		task.spawn(function()
			while glow.Parent do
				Util.tween(s, 0.9, { Scale = 1.08 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
				if not glow.Parent then
					break
				end
				Util.tween(s, 0.9, { Scale = 0.96 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
			end
		end)
	end

	-- chip edge (gives the pawn some thickness, like a real game piece)
	Shapes.circle(root, 0.5, 0.57, 0.88, Util.shade(seatColor, -0.45), { name = "Side" })

	local face = Shapes.circle(root, 0.5, 0.5, 0.88, fill, { name = "Face" })
	if look.gradient then
		-- only skins whose whole idea is a colour blend get one
		local g = Util.grad(face, if look.fill == "rainbow" then RAINBOW else Util.seq({ fill, fill2 }), 60)
		if look.spin then
			CosmeticArt.spin(g, if look.fill == "rainbow" then 90 else 45)
		end
	end
	Util.scaledStroke(face, seatColor, 0.09, 3)

	local pattern = PawnPatterns[look.pattern or "ring"]
	if pattern then
		local canvas = Shapes.canvas(face, { Name = "Pattern", ZIndex = 2 })
		Icons.draw(canvas, pattern, { ink = accent, acc = accent, acc2 = fill2, bg = fill, hi = fill })
	end

	root.Parent = parent
	return root
end

-- Small character badge that sits on a pawn's corner.
function CosmeticArt.characterBadge(parent: Instance, character: string, props: { [string]: any }?): Frame
	local color = Theme.Character[character] or Theme.C.inkSoft
	return Icons.medallion(parent, character, color, props)
end

---------------------------------------------------------------------------
-- Dice
---------------------------------------------------------------------------

function CosmeticArt.dieLook(skinId: string?)
	local def = Cosmetics.get(skinId or "") or Cosmetics.get(Cosmetics.defaults.dice)
	local look = def.look
	return {
		face = hex(look.face, Theme.C.parchment),
		face2 = hex(look.face2, Theme.C.parchmentMid),
		pip = hex(look.pip, Theme.C.ink),
		edge = hex(look.edge, Theme.C.inkSoft),
		glow = if look.glow then hex(look.glow, Theme.C.white) else nil,
		spin = look.spin == true,
		gradient = look.gradient == true,
	}
end

--[[
	A die face showing `value` (1-6). Returns root and a setter:
		local die, setValue = CosmeticArt.die(parent, "dice_gold", 4)
]]
function CosmeticArt.die(parent: Instance?, skinId: string?, value: number, props: { [string]: any }?): (Frame, (number) -> ())
	local look = CosmeticArt.dieLook(skinId)
	local root = Util.frame(nil, {
		Name = "Die",
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end
	if look.glow then
		local glow = Shapes.rect(root, 0.5, 0.5, 1.1, 1.1, look.glow, { r = 0.24, t = 0.6, name = "Glow" })
		glow.ZIndex = 1
	end
	Shapes.rect(root, 0.5, 0.56, 0.92, 0.92, Util.shade(look.face2, -0.35), { r = 0.22, name = "Side" })
	local face = Shapes.rect(root, 0.5, 0.5, 0.92, 0.92, look.face, { r = 0.22, name = "Face" })
	if look.gradient then
		local g = Util.grad(face, { look.face, look.face2 }, 70)
		if look.spin then
			CosmeticArt.spin(g, 70)
		end
	end
	Util.scaledStroke(face, look.edge, 0.05, 2)
	local pips = Shapes.canvas(face, { Name = "Pips", ZIndex = 3 })

	local function setValue(v: number)
		Util.clear(pips)
		pips:SetAttribute("Z", 0)
		for _, p in PawnPatterns.pips[math.clamp(math.floor(v), 1, 6)] do
			Shapes.circle(pips, p[1], p[2], 0.19, look.pip)
		end
	end
	setValue(value)
	root.Parent = parent
	return root, setValue
end

---------------------------------------------------------------------------
-- Trails (particles behind a hopping pawn)
---------------------------------------------------------------------------

local function particle(layer: Instance, pos: Vector2, size: number, draw: (Frame) -> (), life: number, drift: Vector2, spin: number?)
	local f = Util.frame(layer, {
		Name = "Particle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(size, size),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ZIndex = 30,
	})
	local c = Shapes.canvas(f)
	draw(c)
	Util.tween(f, life, {
		Position = UDim2.fromOffset(pos.X + drift.X, pos.Y + drift.Y),
		Rotation = spin or 0,
		Size = UDim2.fromOffset(size * 0.4, size * 0.4),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, child in c:GetChildren() do
		if child:IsA("Frame") then
			Util.tween(child, life, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local st = child:FindFirstChildOfClass("UIStroke")
			if st then
				Util.tween(st, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
	end
	task.delay(life, function()
		f:Destroy()
	end)
end

--[[
	Spawns a puff of the trail's particles at `pos` (pixels in `layer`).
	`unit` is roughly a tile's size in pixels.
]]
function CosmeticArt.trailBurst(layer: Instance, trailId: string?, pos: Vector2, unit: number)
	local def = Cosmetics.get(trailId or "")
	if not def or def.look.kind == "none" then
		return
	end
	local look = def.look
	local color = hex(look.color, Theme.C.white)
	local color2 = hex(look.color2, color)
	local kind = look.kind
	local n = if kind == "puff" then 3 else 4
	for i = 1, n do
		local a = math.random() * math.pi * 2
		local spread = unit * 0.25
		local p = pos + Vector2.new(math.cos(a), math.sin(a) * 0.5) * spread * math.random()
		local drift = Vector2.new((math.random() - 0.5) * unit * 0.5, -unit * (0.2 + math.random() * 0.4))
		local size = unit * (0.16 + math.random() * 0.12)
		local life = 0.6 + math.random() * 0.4
		local pick = if i % 2 == 0 then color2 else color
		if kind == "puff" then
			particle(layer, p, size * 1.3, function(c)
				Shapes.circle(c, 0.5, 0.5, 1, pick, { t = 0.25 })
			end, life, drift * 0.5)
		elseif kind == "bubble" then
			particle(layer, p, size, function(c)
				Shapes.ring(c, 0.5, 0.5, 1, 0.14, pick, { px = size })
				Shapes.circle(c, 0.35, 0.35, 0.2, Theme.C.white, { t = 0.3 })
			end, life, drift)
		elseif kind == "leaf" then
			particle(layer, p, size, function(c)
				Icons.draw(c, { { "drop", 0.5, 0.55, 0.3, dir = 45 } }, { ink = pick })
			end, life, drift + Vector2.new(0, unit * 0.6), (math.random() - 0.5) * 220)
		elseif kind == "sparkle" then
			particle(layer, p, size, function(c)
				Shapes.sparkle(c, 0.5, 0.5, 1, pick)
			end, life, drift, 90)
		elseif kind == "ember" then
			particle(layer, p, size * 0.6, function(c)
				Shapes.circle(c, 0.5, 0.5, 1, pick)
			end, life, drift * 1.4)
		elseif kind == "heart" then
			particle(layer, p, size, function(c)
				Icons.draw(c, IconData.heart, { ink = pick })
			end, life, drift)
		elseif kind == "star" then
			particle(layer, p, size, function(c)
				Shapes.star(c, 0.5, 0.5, 1, pick)
			end, life, drift, 120)
		elseif kind == "rainbow" then
			local hue = ((os.clock() * 0.5) + i / n) % 1
			particle(layer, p, size, function(c)
				Shapes.circle(c, 0.5, 0.5, 1, Color3.fromHSV(hue, 0.6, 1))
			end, life, drift)
		end
	end
end

---------------------------------------------------------------------------
-- Titles & emotes
---------------------------------------------------------------------------

function CosmeticArt.title(parent: Instance, titleId: string?, props: { [string]: any }?): TextLabel?
	local def = Cosmetics.get(titleId or "")
	if not def or def.look.text == "" then
		return nil
	end
	local label = Util.new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = def.look.text,
		TextColor3 = if def.look.rainbow then Theme.C.white else Color3.fromHex(string.sub(def.look.color, 2)),
		FontFace = Theme.Font.BodyHeavy,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	})
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	if def.look.rainbow then
		CosmeticArt.spin(Util.grad(label, RAINBOW, 0), 80)
	end
	label.Parent = parent
	return label
end

function CosmeticArt.emoteBubble(parent: Instance, emoteId: string, props: { [string]: any }?): Frame?
	local def = Cosmetics.get(emoteId)
	if not def then
		return nil
	end
	local color = Color3.fromHex(string.sub(def.look.color, 2))
	local bubble = Util.new("Frame", {
		Name = "Emote",
		BackgroundColor3 = Theme.C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
	})
	Util.corner(bubble, 12)
	Util.stroke(bubble, color, 3)
	Util.pad(bubble, 12, 4, 12, 4)
	Util.new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = def.look.text,
		TextColor3 = Theme.C.textDark,
		FontFace = Theme.Font.Chunky,
		TextSize = 20,
		Parent = bubble,
	})
	if props then
		for k, v in props do
			(bubble :: any)[k] = v
		end
	end
	bubble.Parent = parent
	return bubble
end

-- A preview tile for any cosmetic (locker grid, chest reveals, shop).
function CosmeticArt.preview(parent: Instance, itemId: string, seatColor: Color3?, props: { [string]: any }?): Frame
	local def = Cosmetics.get(itemId)
	local holder = Util.frame(parent, props)
	holder.Name = "Preview"
	if not def then
		return holder
	end
	local seat = seatColor or Theme.Seat[2]
	if def.category == "pawn" then
		CosmeticArt.pawn(holder, itemId, seat, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8) })
	elseif def.category == "dice" then
		CosmeticArt.die(holder, itemId, 5, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7) })
	elseif def.category == "trail" then
		local look = def.look
		local color = hex(look.color, Theme.C.white)
		local c = Shapes.canvas(holder, { Size = UDim2.fromScale(0.8, 0.8) })
		if look.kind == "none" then
			Icons.draw(c, IconData.close, { ink = Theme.C.inkFaint })
		elseif look.kind == "rainbow" then
			for i = 0, 5 do
				Shapes.circle(c, 0.18 + i * 0.13, 0.62 - math.sin(i * 0.9) * 0.18, 0.16 - i * 0.012, Color3.fromHSV(i / 6, 0.6, 1))
			end
		else
			local glyph = ({ puff = "circle", bubble = "ring", leaf = "drop", sparkle = "sparkle", ember = "circle", heart = "heart", star = "star" })[look.kind]
			for i = 0, 2 do
				local x, y, d = 0.24 + i * 0.27, 0.66 - i * 0.18, 0.3 - i * 0.05
				if glyph == "heart" then
					Icons.draw(c, { { "group", s = d, dx = x - 0.5, dy = y - 0.5, ops = IconData.heart } }, { ink = color })
				elseif glyph == "ring" then
					Shapes.ring(c, x, y, d, d * 0.15, color)
				elseif glyph == "drop" then
					Icons.draw(c, { { "drop", x, y, d * 0.45, dir = 45 } }, { ink = if i == 1 then hex(look.color2, color) else color })
				elseif glyph == "sparkle" then
					Shapes.sparkle(c, x, y, d, color)
				elseif glyph == "star" then
					Shapes.star(c, x, y, d, if i == 1 then hex(look.color2, color) else color)
				else
					Shapes.circle(c, x, y, d * 0.8, if i == 1 then hex(look.color2, color) else color)
				end
			end
		end
	elseif def.category == "emote" then
		local b = CosmeticArt.emoteBubble(holder, itemId, { Position = UDim2.fromScale(0.5, 0.75) })
		if b then
			b.Size = UDim2.fromOffset(0, 30)
		end
	elseif def.category == "title" then
		CosmeticArt.title(holder, itemId, { Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.35) })
	end
	return holder
end

return CosmeticArt
