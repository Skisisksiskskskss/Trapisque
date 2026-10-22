--[[
	Art
	The game's image art: the illustrations in art/ (in the repository), built by
	tools/art.py into a few sheets. Art.image draws one sprite from those sheets; Art.has
	says whether it can.

	Each sheet comes from one of two places:
	  - its uploaded image, once its id is in ArtAssets (works everywhere), or
	  - the sheet built in the game itself, from its pixels in ArtData, as an
	    EditableImage. That needs nothing uploaded: it works in Studio, and in a published
	    game once "Allow Mesh / Image APIs" is on (Experience Settings > Security).
	When neither works, callers draw their code-built version instead (and Art.problem
	says why, in the Output too).

		Art.has(name) -> boolean                         -- "props/palm", "pieces/paint_mage"
		Art.image(parent, name, props) -> Frame?         -- nil when it can't
		Art.label(parent, name, center, size, flip?, props?) -> ImageLabel?   -- just the image
		Art.preload(timeout?)                            -- builds / loads the sheets

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
-- Build sheets that have no upload from ArtData (the fake Roblox can't).
Art.builtIn = true
-- Why the built-in sheets couldn't be made, if they couldn't.
Art.problem = nil :: string?

type Source = { image: string?, content: Content? }

local sources: { [string]: Source } = {}
local failed: { [string]: boolean } = {}
local keep: { EditableImage } = {} -- the built sheets, held so they stay alive

local function uploadedId(sheet: string): number?
	local id = (ArtAssets :: any)[sheet]
	if type(id) == "number" and id > 0 then
		return id
	end
	return nil
end

local function sourceOf(sheet: string): Source?
	if Art.localSheets then
		return { image = "art:" .. sheet }
	end
	local id = uploadedId(sheet)
	if id and not failed[sheet] then
		return { image = "rbxassetid://" .. tostring(id) }
	end
	return sources[sheet]
end

-- The sheet as an EditableImage, from its pixels in ArtData.
local function build(sheet: string): Content?
	local folder = script.Parent:FindFirstChild("ArtData")
	local module = folder and folder:FindFirstChild(sheet)
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(function(): Content
		local data = require(module) :: any
		local EncodingService = game:GetService("EncodingService")
		local image = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(data.width, data.height) })
		if not image then
			error("not enough image memory on this device")
		end
		-- strip by strip, top to bottom
		for i, chunks in data.strips do
			local top = (i - 1) * data.strip
			local packed = EncodingService:Base64Decode(buffer.fromstring(table.concat(chunks)))
			local pixels = EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd)
			image:WritePixelsBuffer(Vector2.new(0, top), Vector2.new(data.width, math.min(data.strip, data.height - top)), pixels)
		end
		table.insert(keep, image)
		return Content.fromObject(image)
	end)
	if ok then
		return result
	end
	Art.problem = tostring(result)
	return nil
end

function Art.has(name: string): boolean
	local s = ArtAtlas.sprites[name]
	return s ~= nil and sourceOf(s.sheet) ~= nil
end

function Art.image(parent: Instance?, name: string, props: { [string]: any }?): Frame?
	local s = ArtAtlas.sprites[name]
	local source = s and sourceOf(s.sheet)
	if not s or not source then
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
	if source.content then
		img.ImageContent = source.content
	else
		img.Image = source.image or ""
	end
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

-- One ImageLabel and nothing else: sprite `name` with its whole canvas `size` pixels
-- across, centred on `center`. For the many small things on a map, where a frame round
-- each would only cost. `flip` mirrors it left to right by reading the rect backwards
-- (a negative ImageRectSize); only the offline store art uses that so far.
function Art.label(parent: Instance?, name: string, center: Vector2, size: number, flip: boolean?, props: { [string]: any }?): ImageLabel?
	local s = ArtAtlas.sprites[name]
	local source = s and sourceOf(s.sheet)
	if not s or not source then
		return nil
	end
	local k = size / math.max(s.ow, s.oh)
	local img = Instance.new("ImageLabel")
	img.Name = string.match(name, "[^/]+$") or name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	if source.content then
		img.ImageContent = source.content
	else
		img.Image = source.image or ""
	end
	-- where the drawn part's middle is, from the canvas's middle
	local mx, my = (s.ox + s.w / 2 - s.ow / 2) * k, (s.oy + s.h / 2 - s.oh / 2) * k
	if flip then
		-- the rect read right to left
		img.ImageRectOffset = Vector2.new(s.x + s.w, s.y)
		img.ImageRectSize = Vector2.new(-s.w, s.h)
		mx = -mx
	else
		img.ImageRectOffset = Vector2.new(s.x, s.y)
		img.ImageRectSize = Vector2.new(s.w, s.h)
	end
	img.ScaleType = Enum.ScaleType.Stretch
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromOffset(center.X + mx, center.Y + my)
	img.Size = UDim2.fromOffset(s.w * k, s.h * k)
	for key, v in props or {} do
		(img :: any)[key] = v
	end
	img.Parent = parent
	return img
end

-- Builds the sheets that weren't uploaded, then loads the uploaded ones (with a time
-- limit). An uploaded one Roblox can't load (still in moderation, or removed) falls back
-- to the code-built art from then on.
function Art.preload(timeout: number?)
	if Art.localSheets then
		return
	end
	if Art.builtIn then
		for _, sheet in ArtAtlas.sheets do
			if not uploadedId(sheet) then
				local content = build(sheet)
				if content then
					sources[sheet] = { content = content }
				end
			end
		end
		if Art.problem then
			warn(
				"[Trapisque] The illustrations couldn't be built in the game ("
					.. Art.problem
					.. "), so plainer stand-ins are drawn. In a published game, turn on Experience Settings > "
					.. "Security > Allow Mesh / Image APIs, or upload the art sheets (art/README.md)."
			)
		end
	end
	local list, sheetOf = {}, {}
	for _, sheet in ArtAtlas.sheets do
		local id = uploadedId(sheet)
		if id then
			local uri = "rbxassetid://" .. tostring(id)
			table.insert(list, uri)
			sheetOf[uri] = sheet
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
