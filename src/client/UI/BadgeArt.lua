--[[
	BadgeArt
	A badge as a medal: a cream disc with a heavy rim in the badge's colour and its
	picture in the middle (sticker art from around the game). Unearned badges show a
	dark silhouette, so there's something to aim for. The same drawing makes the
	512 x 512 icons for the Creator Dashboard (tools/shots.sh badges).

		BadgeArt.medal(parent, key, earned, props?) -> Frame
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Badges = require(ReplicatedStorage.Shared.Meta.Badges)

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local StickerArt = require(UI.StickerArt)
local MapProps = require(UI.MapProps)
local FishArt = require(UI.FishArt)

local C = Theme.C

local BadgeArt = {}

local INK = "#1C1A24"
local CREAM = "#FFF8E7"
local WOOD = "#B87333"
local WOOD_DARK = "#7A4A1F"
local GOLD = "#F5B700"

local function die(cx: number, cy: number, s: number, rot: number, face: string, pips: { { number } })
	local ops = { { "rect", cx, cy, s, s, r = 0.22, rot = rot, c = face } }
	for _, p in pips do
		table.insert(ops, { "circle", cx + p[1] * s, cy + p[2] * s, s * 0.16, c = INK, ol = false })
	end
	return ops
end

local SIX = { { -0.24, -0.26 }, { -0.24, 0 }, { -0.24, 0.26 }, { 0.24, -0.26 }, { 0.24, 0 }, { 0.24, 0.26 } }

local function join(...)
	local out = {}
	for _, list in { ... } do
		for _, op in list do
			table.insert(out, op)
		end
	end
	return out
end

-- The picture for each badge's icon name.
local PICTURES: { [string]: () -> { any } } = {
	compass = function()
		return {
			{ "circle", 0.5, 0.5, 0.8, c = GOLD },
			{ "circle", 0.5, 0.5, 0.62, c = CREAM, ol = false },
			{ "tri", 0.5, 0.36, 0.16, dir = 0, c = "#D7263D", ol = false },
			{ "tri", 0.5, 0.64, 0.16, dir = 180, c = "#2B4C7E", ol = false },
			{ "circle", 0.5, 0.5, 0.08, c = INK, ol = false },
		}
	end,
	plank = function()
		return {
			{ "rect", 0.5, 0.56, 0.86, 0.2, r = 0.2, rot = -8, c = WOOD },
			{ "line", 0.2, 0.6, 0.8, 0.52, 0.03, c = WOOD_DARK, ol = false },
			{ "rect", 0.2, 0.74, 0.08, 0.26, r = 0.3, c = WOOD_DARK },
			{ "arc", 0.82, 0.86, 0.3, 0.05, dir = 0, keep = 0.42, c = "#8FD3EE", ol = false },
		}
	end,
	pins = function()
		return {
			{ "pill", 0.36, 0.56, 0.14, 0.5, rot = -16, c = CREAM },
			{ "pill", 0.64, 0.56, 0.14, 0.5, rot = 22, c = CREAM },
			{ "line", 0.31, 0.44, 0.41, 0.47, 0.03, c = "#D7263D", ol = false },
			{ "line", 0.6, 0.47, 0.7, 0.43, 0.03, c = "#D7263D", ol = false },
			{ "circle", 0.5, 0.78, 0.3, c = INK },
			{ "circle", 0.45, 0.74, 0.05, c = CREAM, ol = false },
		}
	end,
	trap = function()
		-- a hat trick: a captain's tricorn over three sprung spikes
		return {
			{ "tri", 0.3, 0.86, 0.18, dir = 0, c = "#B8BCC6" },
			{ "tri", 0.7, 0.86, 0.18, dir = 0, c = "#B8BCC6" },
			{ "tri", 0.5, 0.84, 0.22, dir = 0, c = "#D5D8DF" },
			{ "half", 0.5, 0.58, 0.52, dir = 0, c = INK },
			{ "tri", 0.2, 0.52, 0.24, dir = -35, c = INK },
			{ "tri", 0.8, 0.52, 0.24, dir = 35, c = INK },
			{ "pill", 0.5, 0.6, 0.78, 0.13, c = INK },
			{ "line", 0.2, 0.58, 0.8, 0.58, 0.03, c = GOLD, ol = false },
			{ "circle", 0.5, 0.44, 0.1, c = CREAM, ol = false },
			{ "text", 0.5, 0.18, 0.6, 0.22, "x3", c = "#D7263D", font = "chunky" },
		}
	end,
	golddie = function()
		return die(0.5, 0.52, 0.56, 12, GOLD, SIX)
	end,
	snake = function()
		return join(die(0.34, 0.54, 0.38, -12, CREAM, { { 0, 0 } }), die(0.66, 0.5, 0.38, 14, CREAM, { { 0, 0 } }))
	end,
	sixes = function()
		return join(die(0.34, 0.54, 0.38, -12, CREAM, SIX), die(0.66, 0.5, 0.38, 14, CREAM, SIX))
	end,
	shield = function()
		return StickerArt.cards.shield or {}
	end,
	ghost = function()
		return StickerArt.misc.ghost
	end,
	volcano = function()
		return MapProps.volcano
	end,
	phoenix = function()
		return StickerArt.cards.phoenix_potion or {}
	end,
	grog = function()
		return StickerArt.cards.grog or {}
	end,
	jackpot = function()
		return {
			{ "circle", 0.36, 0.66, 0.32, c = GOLD },
			{ "circle", 0.62, 0.7, 0.3, c = GOLD },
			{ "circle", 0.5, 0.48, 0.34, c = GOLD },
			{ "star", 0.5, 0.48, 0.18, c = "#C98F00", ol = false },
			{ "text", 0.5, 0.18, 0.6, 0.22, "x2", c = "#13A398", font = "chunky" },
		}
	end,
	cannonball = function()
		return MapProps.cannon
	end,
	fish = function()
		return FishArt.ops("golden")
	end,
	crown = function()
		return {
			{ "rect", 0.5, 0.68, 0.64, 0.2, r = 0.1, c = GOLD },
			{ "tri", 0.26, 0.52, 0.2, dir = 0, c = GOLD },
			{ "tri", 0.5, 0.46, 0.22, dir = 0, c = GOLD },
			{ "tri", 0.74, 0.52, 0.2, dir = 0, c = GOLD },
			{ "circle", 0.5, 0.68, 0.08, c = "#D7263D", ol = false },
		}
	end,
	people = function()
		return {
			{ "circle", 0.3, 0.42, 0.2, c = "#D94C9C" },
			{ "half", 0.3, 0.72, 0.3, dir = 0, c = "#D94C9C" },
			{ "circle", 0.7, 0.42, 0.2, c = "#1E7FD6" },
			{ "half", 0.7, 0.72, 0.3, dir = 0, c = "#1E7FD6" },
			{ "circle", 0.5, 0.36, 0.24, c = GOLD },
			{ "half", 0.5, 0.7, 0.36, dir = 0, c = GOLD },
		}
	end,
	chest = function()
		return StickerArt.misc.chest
	end,
	crew = function()
		-- two of the crew's emblems: the Mage's snowflake and the Fire Starter's flame
		return {
			{ "circle", 0.33, 0.52, 0.5, c = "#2F7FD0" },
			{ "sparkle", 0.33, 0.52, 0.3, c = "#FFF6E6" },
			{ "circle", 0.67, 0.48, 0.5, c = "#D64545" },
			{ "drop", 0.67, 0.5, 0.13, dir = 0, c = "#FFF6E6" },
			{ "drop", 0.67, 0.54, 0.065, dir = 0, c = "#F5C14B", ol = false },
		}
	end,
	star = function()
		return StickerArt.misc.star
	end,
}

function BadgeArt.picture(icon: string): { any }
	local fn = PICTURES[icon]
	return if fn then fn() else StickerArt.misc.star
end

-- Every op drawn in one flat ink (the unearned silhouette).
local function silhouette(ops, color: string)
	local out = {}
	for _, op in ops do
		local copy = table.clone(op)
		if op[1] == "group" then
			copy.ops = silhouette(op.ops, color)
		else
			copy.c = color
		end
		table.insert(out, copy)
	end
	return out
end

function BadgeArt.medal(parent: Instance, key: string, earned: boolean, props: { [string]: any }?): Frame
	local def = Badges.byKey[key]
	local rim = if def then Color3.fromHex(string.sub(def.color, 2)) else C.sun
	local holder = Util.frame(parent, props)
	holder.Name = "Badge_" .. key
	local z = holder.ZIndex
	local disc = Util.new("Frame", {
		Name = "Rim",
		BackgroundColor3 = if earned then rim else C.panelDeep,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = holder,
	})
	Util.corner(disc, 0.5)
	Util.scaledStroke(disc, C.line, 0.035, 3)
	local inner = Util.new("Frame", {
		Name = "Face",
		BackgroundColor3 = if earned then C.cream else C.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = z + 1,
		Parent = disc,
	})
	Util.corner(inner, 0.5)
	Util.scaledStroke(inner, C.line, 0.03, 2)
	local ops = BadgeArt.picture(def and def.icon or "star")
	if not earned then
		ops = silhouette(ops, "#3A3846")
	end
	Icons.sticker(inner, ops, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = z + 2,
	}, 0.05)
	return holder
end

return BadgeArt
