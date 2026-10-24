--[[
	ArtNotice
	A note for the game's owner (and anyone playing in Studio) when some of the art
	sheets couldn't be loaded, so plainer stand-ins are drawn: which, why, and how to
	fix it. The owner pastes the ids of the uploaded sheets into it (any order, image or
	decal ids); the server matches them to the sheets and keeps them for every server
	(ArtService), and the art loads straight away. Players never see it.

		ArtNotice.show(layer)
]]

local ArtIds = require(game:GetService("ReplicatedStorage").Shared.ArtIds)

local Client = script.Parent.Parent
local Net = require(Client.Net)

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
	local content, close = Widgets.modal(layer, {
		title = "Some art isn't showing",
		titleWidth = math.min(380, roomW - 60),
		width = math.min(660, roomW),
		height = 600,
	})
	local column = Util.frame(content, { Name = "Column", Size = UDim2.new(1, 0, 1, -64) })
	Util.list(column, "y", 8, "Center", "Top")
	local function para(text: string, o: { [string]: any }?): TextLabel
		local p = o or {}
		return Widgets.label(column, {
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
		string.format("%d of the %d art images couldn't be loaded, so plain stand-ins are drawn in their place. Only you see this note.", #missing, #ArtAtlas.sheets),
		{ color = C.text, size = 16, order = 1 }
	)
	para("Why: " .. reasons[1] .. ".", { order = 2 })
	para(
		"To fix it for everyone, upload the 9 images (the PNG files from the art zip, also in art/sheets) to Roblox: as Decals on create.roblox.com (Creations > Decals > Upload Asset), or in Studio with the Asset Manager's import. Then paste their ids here, in any order:",
		{ order = 3 }
	)
	local box = Widgets.textBox(column, {
		name = "Ids",
		placeholder = "Paste the ids (or links) here",
		textSize = 16,
		size = UDim2.new(1, -8, 0, 56),
		layoutOrder = 4,
	})
	box.MultiLine = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6),
		Parent = box,
	})
	local status = para("", { size = 14, color = C.text, order = 5 })
	para(
		"Or, if your Roblox account is ID-verified, turn on File > Experience Settings > Security > Allow Mesh / Image APIs.",
		{ size = 14, order = 6 }
	)
	para("Missing: " .. table.concat(names, ", "), { font = "body", size = 13, color = C.textFaint, order = 7 })

	local saving = false
	local function save()
		if saving then
			return
		end
		local ids = ArtIds.parse(box.Text)
		if #ids == 0 then
			status.Text = "Paste the ids of the uploaded images first."
			return
		end
		saving = true
		status.Text = "Looking the ids up..."
		local ok, result = Net.request("art.set", { ids = ids, sheets = ArtAtlas.sheets, versions = (ArtAtlas :: any).versions })
		saving = false
		if not ok then
			status.Text = tostring(result)
			return
		end
		local n = 0
		for _ in result.saved or {} do
			n += 1
		end
		local text = string.format("Saved %d of the %d images. The art is loading now.", n, #ArtAtlas.sheets)
		if result.problems and #result.problems > 0 then
			text ..= " Not used: " .. table.concat(result.problems, "; ") .. "."
		end
		if not result.stored then
			text ..= " They're only kept until the game closes: in Studio, turn on Game Settings > Security > Enable Studio Access to API Services, then paste them again."
		end
		status.Text = text
		-- (the server hands the ids to everyone, this client too: Main loads the art and
		-- redraws the lobby with it)
		if n >= #ArtAtlas.sheets and result.stored then
			task.delay(2.5, close)
		end
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			task.spawn(save)
		end
	end)
	Widgets.button(content, {
		text = "Later",
		style = "panel",
		textSize = 18,
		size = UDim2.fromOffset(150, 48),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(0.5, -8, 1, 0),
		onClick = close,
	})
	Widgets.button(content, {
		text = "Save ids",
		style = "green",
		textSize = 18,
		size = UDim2.fromOffset(170, 48),
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0.5, 8, 1, 0),
		onClick = function()
			task.spawn(save)
		end,
	})
end

return ArtNotice
