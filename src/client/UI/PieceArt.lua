--[[
	PieceArt
	The playing pieces on the board: one shape for every player, like a set of chess
	pieces, in their character's colour with the character's emblem on top, in the
	finish they've equipped (a Cosmetics "finish"). The illustrations from art/pieces.py
	once their sheets are uploaded (Art); until then the same piece built from code
	shapes, the character's glyph on a disc on top.

		PieceArt.stand(parent, character, finishId, props) -> Frame
			A square frame whose middle is the piece's foot: the piece stands in its top
			half, so turning the frame rocks the piece on its base. props give Position
			(where the foot is), Size (twice the piece's height), ZIndex...
		PieceArt.icon(parent, character, finishId, props) -> Frame
			The piece filling a frame (lists, previews, the chest reveal), foot at the bottom.
		PieceArt.plinth(parent, character, tier, props) -> Frame?
			The stand mastery earns (BaseArt): its image, foot of the frame at its bottom.
		PieceArt.react(stand, mood)        -- a hop, a shake, a wobble or a droop
		PieceArt.finishKey(finishId) -> string  -- "oak" for "fin_oak" ("paint" if none)
]]

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Art = require(UI.Art)
local StickerArt = require(UI.StickerArt)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Meta.Cosmetics)

local PieceArt = {}

-- the piece's sprite is 128 x 160; its foot (the bottom of its base) is 3 px above the
-- bottom edge
local ASPECT = 128 / 160
local FOOT = 3 / 160

function PieceArt.finishKey(finishId: string?): string
	local def = Cosmetics.get(finishId or "")
	if def and def.category == "finish" and def.look and def.look.finish then
		return def.look.finish
	end
	return "paint"
end

-- How the code-built piece takes a finish: its two inks (nil: the character's own).
local FALLBACK: { [string]: { string } } = {
	pearl = { "#F4EFE6", "#CFC6B6" },
	marble = { "#EEEAE2", "#C9C2B6" },
	porcelain = { "#FFFFFF", "#D9DDE6" },
	obsidian = { "#3A3540", "#1E1B22" },
	gold = { "#F2C94C", "#C9962B" },
	glow = { "#3A302C", "#221C1A" },
}

local function fallbackOps(character: string, finish: string): { any }
	local own = StickerArt.bodyColor[character] or StickerArt.bodyColor.mage
	local inks = FALLBACK[finish] or own
	local main, dark = inks[1], inks[2]
	local t = if finish == "glass" then 0.35 else nil
	-- the body first: the base hides its round foot
	return {
		{ "taper", { { 0.5, 0.8 }, { 0.5, 0.54 } }, 0.36, 0.16, c = main, t = t },
		{ "pill", 0.5, 0.93, 0.62, 0.11, c = dark, t = t },
		{ "pill", 0.5, 0.9, 0.62, 0.11, c = main, t = t },
		{ "pill", 0.5, 0.53, 0.28, 0.07, c = dark, t = t },
		{ "circle", 0.5, 0.34, 0.34, c = own[1] },
	}
end

-- The piece drawn into `holder` (sized to the piece's height, foot at its bottom).
local function drawPiece(holder: Frame, character: string, finish: string, z: number)
	local name = "pieces/" .. finish .. "_" .. character
	if not Art.has(name) then
		name = "pieces/paint_" .. character
	end
	if Art.image(holder, name, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1 + FOOT),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}) then
		return
	end
	local canvas = Icons.sticker(holder, fallbackOps(character, finish), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		ZIndex = z,
	}, 0.03)
	-- the character's glyph on the disc at the top
	Icons.make(canvas, character, Icons.flatColors(Theme.C.white, Theme.C.white), {
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.22, 0.22),
		ZIndex = z + 1,
	})
end

function PieceArt.stand(parent: Instance?, character: string, finishId: string?, props: { [string]: any }?): Frame
	local z = (props and props.ZIndex) or 1
	local stand = Util.frame(nil, {
		Name = "Piece",
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = z,
	})
	for k, v in props or {} do
		(stand :: any)[k] = v
	end
	-- the top half holds the piece; it's a little narrower than tall
	local holder = Util.frame(stand, {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = z,
	})
	Util.new("UIAspectRatioConstraint", { AspectRatio = ASPECT, Parent = holder })
	drawPiece(holder, character, PieceArt.finishKey(finishId), z)
	stand.Parent = parent
	return stand
end

function PieceArt.icon(parent: Instance?, character: string, finishId: string?, props: { [string]: any }?): Frame
	local z = (props and props.ZIndex) or 1
	local holder = Util.frame(nil, { Name = "PieceIcon", ZIndex = z })
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	local body = Util.frame(holder, {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		ZIndex = z,
	})
	Util.new("UIAspectRatioConstraint", { AspectRatio = ASPECT, Parent = body })
	drawPiece(body, character, PieceArt.finishKey(finishId), z)
	holder.Parent = parent
	return holder
end

-- the plinth's sprite is 128 x 48: the piece's width, its top's middle 30 px up
PieceArt.PLINTH_ASPECT = 128 / 48
PieceArt.PLINTH_TOP = 30 / 48

function PieceArt.plinth(parent: Instance?, character: string, tier: number, props: { [string]: any }?): Frame?
	local name = if tier >= 2 then "pieces/plinth_gold" else "pieces/plinth_" .. character
	local img = Art.image(nil, name, props)
	if img then
		img.Name = "Plinth"
		img.Parent = parent
	end
	return img
end

--[[
	A piece reacting, instead of pulling a face: "happy" hops ("smug" and "cheeky" hop a
	little), "shock" jumps and shakes, "angry" shakes, "dizzy" wobbles, "sad" droops.
]]
function PieceArt.react(stand: GuiObject, mood: string)
	local token = (stand:GetAttribute("React") or 0) + 1
	stand:SetAttribute("React", token)
	local home = stand.Position
	local function live(): boolean
		return stand.Parent ~= nil and stand:GetAttribute("React") == token
	end
	task.spawn(function()
		local hop = ({ happy = 0.12, shock = 0.07, smug = 0.05, cheeky = 0.05 } :: { [string]: number })[mood]
		if hop then
			local up = home - UDim2.fromScale(0, hop)
			Util.tweenWait(stand, 0.12, { Position = up }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			if not live() then
				return
			end
			Util.tweenWait(stand, 0.16, { Position = home }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		if mood == "shock" or mood == "angry" then
			for i = 1, 6 do
				if not live() then
					return
				end
				Util.tweenWait(stand, 0.05, { Rotation = (if i % 2 == 0 then 1 else -1) * 7 * (1 - i / 7) })
			end
		elseif mood == "dizzy" then
			for i = 1, 4 do
				if not live() then
					return
				end
				Util.tweenWait(stand, 0.14, { Rotation = (if i % 2 == 0 then 1 else -1) * 13 }, Enum.EasingStyle.Sine)
			end
		elseif mood == "sad" then
			Util.tweenWait(stand, 0.25, { Rotation = -9 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
		end
		if live() then
			Util.tween(stand, 0.18, { Rotation = 0, Position = home }, Enum.EasingStyle.Sine)
		end
	end)
end

return PieceArt
