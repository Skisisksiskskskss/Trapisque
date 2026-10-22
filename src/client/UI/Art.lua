--[[
	Art
	The game's image art: the illustrations in art/ (in the repository), built by
	tools/art.py into a few sheets that are uploaded to Roblox once. Art.image draws one
	sprite from those sheets; Art.has says whether it can. Until a sheet's id is in
	ArtAssets, or if Roblox can't load it, callers draw their code-built version instead.

		Art.has(name) -> boolean                         -- "props/palm", "pieces/paint_mage"
		Art.image(parent, name, props) -> Frame?         -- nil when it can't
		Art.preload(timeout?)                            -- loads the sheets, notes failures

	Art.image's frame is the sprite's whole canvas (props size and place it; it keeps the
	canvas's shape); the image inside covers just the part that's drawn (the sheets hold
	sprites trimmed to that).
]]

local ContentProvider = game:GetService("ContentProvider")

local ArtAtlas = require(script.Parent.ArtAtlas)
local ArtAssets = require(script.Parent.ArtAssets)

local Art = {}

-- Offline (the test suite's fake Roblox draws its screenshots from the sheet files).
Art.localSheets = false

local failed: { [string]: boolean } = {}

local function idOf(sheet: string): string?
	if Art.localSheets then
		return "art:" .. sheet
	end
	local id = (ArtAssets :: any)[sheet]
	if type(id) == "number" and id > 0 and not failed[sheet] then
		return "rbxassetid://" .. tostring(id)
	end
	return nil
end

function Art.has(name: string): boolean
	local s = ArtAtlas.sprites[name]
	return s ~= nil and idOf(s.sheet) ~= nil
end

function Art.image(parent: Instance?, name: string, props: { [string]: any }?): Frame?
	local s = ArtAtlas.sprites[name]
	local id = s and idOf(s.sheet)
	if not s or not id then
		return nil
	end
	local box = Instance.new("Frame")
	box.Name = "Art"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do
		(box :: any)[k] = v
	end
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = s.ow / s.oh
	shape.Parent = box
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = id
	img.ImageRectOffset = Vector2.new(s.x, s.y)
	img.ImageRectSize = Vector2.new(s.w, s.h)
	img.ScaleType = Enum.ScaleType.Stretch
	img.Position = UDim2.fromScale(s.ox / s.ow, s.oy / s.oh)
	img.Size = UDim2.fromScale(s.w / s.ow, s.h / s.oh)
	img.ZIndex = box.ZIndex
	img.Parent = box
	box.Parent = parent
	return box
end

-- Loads the sheets that have ids (with a time limit). One Roblox can't load (still in
-- moderation, or removed) falls back to the code-built art from then on.
function Art.preload(timeout: number?)
	if Art.localSheets then
		return
	end
	local list, sheetOf = {}, {}
	for _, sheet in ArtAtlas.sheets do
		local id = idOf(sheet)
		if id then
			table.insert(list, id)
			sheetOf[id] = sheet
		end
	end
	if #list == 0 then
		return
	end
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure and sheetOf[contentId] then
					failed[sheetOf[contentId]] = true
				end
			end)
		end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < (timeout or 8) do
		task.wait(0.1)
	end
end

return Art
