--[[
	ArtNotice
	A note for the game's owner (and anyone playing in Studio) when some of the art
	sheets couldn't be loaded, so plainer stand-ins are drawn: which, why, and how to
	fix it. Players never see it.

		ArtNotice.show(layer)
]]

local UI = script.Parent
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Widgets = require(UI.Widgets)
local Art = require(UI.Art)
local ArtAtlas = require(UI.ArtAtlas)

local C = Theme.C

local ArtNotice = {}

function ArtNotice.show(layer: Instance)
	local missing = Art.missing()
	if #missing == 0 then
		return
	end
	-- the reason most of them share, first
	local counts, reasons = {}, {}
	local names = {}
	for _, m in missing do
		if not counts[m.why] then
			table.insert(reasons, m.why)
		end
		counts[m.why] = (counts[m.why] or 0) + 1
		table.insert(names, m.sheet)
	end
	table.sort(reasons, function(a, b)
		return counts[a] > counts[b]
	end)
	local roomW = Widgets.room()
	local width = math.min(640, roomW)
	local content, close = Widgets.modal(layer, {
		title = "Some art isn't showing",
		titleWidth = math.min(380, roomW - 60),
		width = width,
		height = 500,
	})
	local column = Util.frame(content, { Name = "Column", Size = UDim2.new(1, 0, 1, -64) })
	Util.list(column, "y", 10, "Center", "Top")
	local function para(text: string, o: { [string]: any }?)
		local p = o or {}
		Widgets.label(column, {
			text = text,
			font = p.font or "heavy",
			size = p.size or 15,
			color = p.color or C.textSoft,
			wrap = true,
			align = "left",
			valign = "top",
			sizeUDim = UDim2.new(1, -8, 0, 0),
			autoY = true,
			layoutOrder = p.order,
		})
	end
	para(
		string.format("%d of the %d art sheets couldn't be loaded, so plain stand-ins are drawn in their place. Only you see this note.", #missing, #ArtAtlas.sheets),
		{ color = C.text, size = 16, order = 1 }
	)
	para("Why: " .. reasons[1] .. ".", { order = 2 })
	para(
		"To fix it for everyone, upload the sheets: in Studio, open the Asset Manager (Window menu or Home tab), import the nine files in art/sheets, then put each image's id (right-click > Copy Asset ID) in ArtAssets (StarterPlayerScripts > Client > UI), where its sheet says id = 0.",
		{ order = 3 }
	)
	para(
		"Or, if your Roblox account is ID-verified, turn on File > Experience Settings > Security > Allow Mesh / Image APIs.",
		{ order = 4 }
	)
	para("Sheets: " .. table.concat(names, ", "), { font = "body", size = 14, color = C.textFaint, order = 5 })
	Widgets.button(content, {
		text = "Got it",
		style = "panel",
		textSize = 20,
		size = UDim2.fromOffset(180, 50),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = close,
	})
end

return ArtNotice
