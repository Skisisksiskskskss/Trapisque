--[[
	BaseArt
	Each character's own stand: the low plinth their piece stands on on the board, earned
	with mastery (Progress.baseTier: the stand at mastery 5, gilded at 10). Not something
	you can buy; it shows everyone how well you know that character.

	The plinth illustration (art/pieces.py) in that character's colour (the colour that
	is its player's everywhere), or gold; until its sheet is uploaded, the same disc from
	code shapes.

		BaseArt.draw(parent, character, tier, props) -> (frame?, foot?)
			the stand at the bottom of `parent` (a pawn's square), and how high up that
			square (a fraction of it) the piece's foot then goes; nil at tier 0
]]

local Icons = require(script.Parent.Icons)
local StickerArt = require(script.Parent.StickerArt)
local PieceArt = require(script.Parent.PieceArt)

local BaseArt = {}

local GOLD = { "#F2C94C", "#C9962B" }

-- the stand is as wide as the piece (0.8 of its 1.04 height), its bottom near the
-- square's
local WIDTH = 0.832
local BOTTOM = 0.99

local function ops(character: string, tier: number): { any }
	local colors = if tier >= 2 then GOLD else (StickerArt.bodyColor[character] or StickerArt.bodyColor.mage)
	return {
		{ "pill", 0.5, 0.91, 0.86, 0.2, c = colors[2] },
		{ "pill", 0.5, 0.86, 0.86, 0.2, c = colors[1] },
	}
end

function BaseArt.draw(parent: Instance, character: string, tier: number, props: { [string]: any }?): (GuiObject?, number?)
	if tier <= 0 then
		return nil, nil
	end
	local h = WIDTH / PieceArt.PLINTH_ASPECT
	local img = PieceArt.plinth(parent, character, tier, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, BOTTOM),
		Size = UDim2.fromScale(WIDTH, h),
		ZIndex = props and props.ZIndex or 1,
	})
	if img then
		-- the piece stands just in front of the middle of the stand's top
		return img, BOTTOM - h * PieceArt.PLINTH_TOP + 0.02
	end
	local canvas = Icons.sticker(parent, ops(character, tier), props, 0.025)
	canvas.Name = "Base"
	return canvas, 0.88
end

return BaseArt
