--[[
	BaseArt
	Each character's own base: the stand they're on on the board, earned with mastery
	(Progress.baseTier: the base at mastery 5, gilded at 10). Not something you can buy;
	it shows everyone how well you know that character.

	A low plinth seen from a little above, with that character's trim around it: embers
	for the Fire Starter, runes for the Mage, coiled rope for the Trapper, a mossy mound
	with a flower for the Naturalist, a portal swirl for the Warper, a compass for the
	Overseer, a poker chip for the Gambler, a deck with cannonballs for the Cannoneer.
	The gold one is the same in gold with a glint.

		BaseArt.ops(character, tier, cy?) -> sticker ops (cy: the plinth's middle, 0.86 =
		                                     under a pawn's feet; 0.5 for an icon)
		BaseArt.draw(parent, character, tier, props) -> canvas (nil at tier 0)
		BaseArt.preview(parent, character, tier, props) -> canvas   -- an icon; faint
		                                     at tier 0 (what mastery 5 will bring)
]]

local Icons = require(script.Parent.Icons)

local BaseArt = {}

local INK = "#1C1A24"
local GOLD = { top = "#F2C94C", side = "#C9962B", trim = "#FFF1B0" }

local STYLE = {
	fire_starter = { top = "#4A2C22", side = "#2E1B16", trim = "#FF8A3D" },
	mage = { top = "#3B2C6B", side = "#251A47", trim = "#B48CFF" },
	trapper = { top = "#C9A066", side = "#9C7444", trim = "#7A5530" },
	naturalist = { top = "#5DBB63", side = "#7A5233", trim = "#3E8E41" },
	warper = { top = "#1E2A4A", side = "#121A30", trim = "#5CE1E6" },
	overseer = { top = "#E8DCC0", side = "#8B6B3E", trim = "#3B2F22" },
	gambler = { top = "#13A398", side = "#0E7C73", trim = "#FFFFFF" },
	cannoneer = { top = "#9C6B3C", side = "#6E4626", trim = "#4A2E18" },
}

-- The trim: drawn over the plinth. `y` turns an offset from the middle into a y.
local function trim(character: string, y: (number) -> number)
	if character == "fire_starter" then
		return {
			{ "drop", 0.12, y(-0.06), 0.045, c = "#FF8A3D" },
			{ "drop", 0.12, y(-0.05), 0.022, c = "#FFD166", ol = false },
			{ "drop", 0.88, y(-0.06), 0.045, c = "#FF8A3D" },
			{ "drop", 0.88, y(-0.05), 0.022, c = "#FFD166", ol = false },
			{ "circle", 0.32, y(0.09), 0.035, c = "#FF8A3D", ol = false },
			{ "circle", 0.5, y(0.11), 0.03, c = "#FFD166", ol = false },
			{ "circle", 0.68, y(0.09), 0.035, c = "#FF8A3D", ol = false },
		}
	elseif character == "mage" then
		return {
			{ "star", 0.3, y(0.09), 0.07, c = "#FFE27A", ol = false },
			{ "star", 0.7, y(0.09), 0.07, c = "#FFE27A", ol = false },
			{ "circle", 0.5, y(0.11), 0.03, c = "#B48CFF", ol = false },
			{ "sparkle", 0.1, y(-0.09), 0.09, c = "#B48CFF" },
			{ "sparkle", 0.9, y(-0.07), 0.07, c = "#FFE27A" },
		}
	elseif character == "trapper" then
		local out = {}
		for i = 0, 6 do
			local x = 0.2 + i * 0.1
			table.insert(out, { "line", x, y(0.06), x + 0.04, y(0.13), 0.018, c = "#7A5530", ol = false })
		end
		-- a coil of rope at the end, seen from above
		table.insert(out, { "circle", 0.9, y(-0.03), 0.13, c = "#C9A066" })
		table.insert(out, { "circle", 0.9, y(-0.03), 0.075, c = "#9C7444", ol = false })
		table.insert(out, { "circle", 0.9, y(-0.03), 0.03, c = "#C9A066", ol = false })
		return out
	elseif character == "naturalist" then
		return {
			{ "tri", 0.12, y(-0.08), 0.07, c = "#3E8E41" },
			{ "tri", 0.18, y(-0.09), 0.06, c = "#5DBB63" },
			{ "tri", 0.07, y(-0.05), 0.05, c = "#3E8E41" },
			{ "circle", 0.86, y(-0.06), 0.08, c = "#FFD1E8" },
			{ "circle", 0.86, y(-0.06), 0.035, c = "#FFC83D", ol = false },
			{ "circle", 0.36, y(0.09), 0.04, c = "#A68A6B", ol = false },
			{ "circle", 0.62, y(0.11), 0.03, c = "#A68A6B", ol = false },
		}
	elseif character == "warper" then
		return {
			{ "oring", 0.5, y(0), 0.68, 0.15, 0.016, c = "#5CE1E6", ol = false },
			{ "oring", 0.5, y(0), 0.48, 0.1, 0.013, c = "#D94C9C", ol = false },
			{ "sparkle", 0.09, y(-0.08), 0.08, c = "#5CE1E6" },
			{ "sparkle", 0.91, y(-0.05), 0.065, c = "#D94C9C" },
			{ "circle", 0.5, y(0.1), 0.03, c = "#5CE1E6", ol = false },
		}
	elseif character == "overseer" then
		return {
			{ "tri", 0.04, y(0), 0.08, dir = -90, c = "#C0392B" },
			{ "tri", 0.96, y(0), 0.08, dir = 90, c = "#3B2F22" },
			{ "tri", 0.5, y(0.14), 0.07, dir = 180, c = "#3B2F22" },
			{ "line", 0.3, y(0.07), 0.3, y(0.12), 0.014, c = "#3B2F22", ol = false },
			{ "line", 0.7, y(0.07), 0.7, y(0.12), 0.014, c = "#3B2F22", ol = false },
		}
	elseif character == "gambler" then
		local out = {}
		for _, x in { 0.2, 0.4, 0.6, 0.8 } do
			table.insert(out, { "rect", x, y(0.09), 0.06, 0.06, c = "#FFFFFF", ol = false })
		end
		table.insert(out, { "rect", 0.11, y(-0.07), 0.1, 0.1, r = 0.25, rot = -12, c = "#FFFFFF" })
		table.insert(out, { "circle", 0.11, y(-0.07), 0.028, c = INK, ol = false })
		return out
	elseif character == "cannoneer" then
		return {
			{ "line", 0.3, y(0.06), 0.3, y(0.13), 0.014, c = "#4A2E18", ol = false },
			{ "line", 0.5, y(0.07), 0.5, y(0.14), 0.014, c = "#4A2E18", ol = false },
			{ "line", 0.7, y(0.06), 0.7, y(0.13), 0.014, c = "#4A2E18", ol = false },
			{ "circle", 0.11, y(-0.05), 0.11, c = "#2B2B33" },
			{ "circle", 0.09, y(-0.07), 0.03, c = "#6C6C7A", ol = false },
			{ "circle", 0.89, y(-0.04), 0.1, c = "#2B2B33" },
			{ "circle", 0.87, y(-0.06), 0.028, c = "#6C6C7A", ol = false },
		}
	end
	return {}
end

function BaseArt.ops(character: string, tier: number, cy: number?): { any }
	local mid = cy or 0.86
	local function y(dy: number): number
		return mid + dy
	end
	local style = if tier >= 2 then GOLD else (STYLE[character] or STYLE.mage)
	local ops = {
		{ "pill", 0.5, y(0.05), 0.86, 0.2, c = style.side },
		{ "pill", 0.5, y(0), 0.86, 0.2, c = style.top },
		{ "oring", 0.5, y(0), 0.86, 0.2, 0.018, c = style.trim, ol = false },
	}
	for _, op in trim(character, y) do
		table.insert(ops, op)
	end
	if tier >= 2 then
		table.insert(ops, { "sparkle", 0.24, y(-0.12), 0.07, c = GOLD.trim })
		table.insert(ops, { "sparkle", 0.78, y(-0.13), 0.06, c = GOLD.trim })
	end
	return ops
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
