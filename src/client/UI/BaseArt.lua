--[[
	BaseArt
	Each character's own base: the stand they're on on the board, earned with mastery
	(Progress.baseTier: the base at mastery 5, gilded at 10). Not something you can buy;
	it shows everyone how well you know that character.

	A low plinth seen from a little above, in that character's colour (the colour that
	is its player's everywhere), like the painted base of a tabletop miniature. The gold
	one is the same in gold.

		BaseArt.ops(character, tier, cy?) -> sticker ops (cy: the plinth's middle, 0.86 =
		                                     under a pawn's feet; 0.5 for an icon)
		BaseArt.draw(parent, character, tier, props) -> canvas (nil at tier 0)
		BaseArt.preview(parent, character, tier, props) -> canvas   -- an icon; faint
		                                     at tier 0 (what mastery 5 will bring)
]]

local Icons = require(script.Parent.Icons)
local StickerArt = require(script.Parent.StickerArt)

local BaseArt = {}

local GOLD = { "#F2C94C", "#C9962B" }

function BaseArt.ops(character: string, tier: number, cy: number?): { any }
	local mid = cy or 0.86
	local colors = if tier >= 2 then GOLD else (StickerArt.bodyColor[character] or StickerArt.bodyColor.mage)
	return {
		{ "pill", 0.5, mid + 0.05, 0.86, 0.2, c = colors[2] },
		{ "pill", 0.5, mid, 0.86, 0.2, c = colors[1] },
	}
end

function BaseArt.draw(parent: Instance, character: string, tier: number, props: { [string]: any }?): Frame?
	if tier <= 0 then
		return nil
	end
	local canvas = Icons.sticker(parent, BaseArt.ops(character, tier), props, 0.025)
	canvas.Name = "Base"
	return canvas
end

function BaseArt.preview(parent: Instance, character: string, tier: number, props: { [string]: any }?): Frame
	local ops = BaseArt.ops(character, math.max(1, tier), 0.56)
	if tier <= 0 then
		for i, op in ops do
			local faint = table.clone(op)
			faint.t = 0.7
			ops[i] = faint
		end
	end
	local canvas = Icons.sticker(parent, ops, props, if tier <= 0 then 0 else 0.04)
	canvas.Name = "BasePreview"
	return canvas
end

return BaseArt
