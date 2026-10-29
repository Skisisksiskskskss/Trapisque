--[[
	Paint colors. Every player owns one ColorId (an index into this list) for as
	long as they are in the server. Surfaces are near-white so every color reads.
]]

local Palette = {
	{ name = "Tangerine", color = Color3.fromRGB(255, 128, 32) },
	{ name = "Grape", color = Color3.fromRGB(140, 70, 255) },
	{ name = "Lime", color = Color3.fromRGB(140, 225, 30) },
	{ name = "Cyan", color = Color3.fromRGB(0, 200, 230) },
	{ name = "Magenta", color = Color3.fromRGB(240, 40, 170) },
	{ name = "Lemon", color = Color3.fromRGB(245, 210, 20) },
	{ name = "Cobalt", color = Color3.fromRGB(40, 90, 255) },
	{ name = "Crimson", color = Color3.fromRGB(225, 30, 60) },
	{ name = "Mint", color = Color3.fromRGB(50, 230, 150) },
	{ name = "Bubblegum", color = Color3.fromRGB(255, 120, 200) },
	{ name = "Teal", color = Color3.fromRGB(0, 150, 140) },
	{ name = "Coral", color = Color3.fromRGB(255, 100, 90) },
	{ name = "Violet", color = Color3.fromRGB(190, 80, 230) },
	{ name = "Sky", color = Color3.fromRGB(100, 185, 255) },
	{ name = "Olive", color = Color3.fromRGB(150, 160, 40) },
	{ name = "Rust", color = Color3.fromRGB(190, 80, 30) },
	{ name = "Indigo", color = Color3.fromRGB(80, 50, 190) },
	{ name = "Chartreuse", color = Color3.fromRGB(195, 250, 50) },
	{ name = "Rose", color = Color3.fromRGB(255, 60, 110) },
	{ name = "Aqua", color = Color3.fromRGB(70, 245, 225) },
}

local NEUTRAL = Color3.fromRGB(235, 235, 235)

function Palette.color(colorId: number?): Color3
	local entry = colorId and Palette[colorId]
	return if entry then entry.color else NEUTRAL
end

function Palette.name(colorId: number?): string
	local entry = colorId and Palette[colorId]
	return if entry then entry.name else "Neutral"
end

return Palette
