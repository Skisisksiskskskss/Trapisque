--[[
	Art
	The game's image art: the illustrations in art/ (in the repository), built by
	tools/art.py into a few sheets. Art.image draws one sprite from those sheets; Art.has
	says whether it can.

	Each sheet comes from the first of these that works:
	  - its uploaded image, while that upload is of the sheet's current version
	    (ArtAtlas.versions): works in every game, on every device. The ids come from
	    ArtAssets (built into the place) or from the owner, pasted into the art note in
	    the lobby and kept by the server (ArtService; Art.setUploads)
	  - the sheet built in the game itself from its pixels in ArtData, as an
	    EditableImage: needs nothing uploaded, but Roblox only allows it once the owner
	    (an ID-verified account) turns on Experience Settings > Security > Allow Mesh /
	    Image APIs, and a phone has little memory for it
	When neither works, callers draw their code-built version instead. Art.missing() says
	which sheets and why (in the Output too; ArtNotice shows the owner).

		Art.has(name) -> boolean                         -- "props/palm", "pieces/paint_mage"
		Art.image(parent, name, props) -> Frame?         -- nil when it can't
		Art.label(parent, name, center, size, flip?, props?) -> ImageLabel?   -- just the image
		                                                 -- (size: px, or a Vector2 to stretch)
		Art.frame(image, name, center, size, flip?) -> boolean   -- the image, another sprite
		Art.preload(timeout?)                            -- loads / builds the sheets
		Art.missing() -> { { sheet, why } }              -- the sheets that couldn't be had
		Art.uploadedId(sheet) -> number?                 -- its upload, if that's current
		Art.setUploads({ [sheet] = { id, version } }) -> boolean   -- the owner's uploads
		                                                 -- (true if any changed: preload again)

	Art.image's frame is the sprite's whole canvas (props size and place it; it keeps the
	canvas's shape); the image inside covers just the part that's drawn (the sheets hold
	sprites trimmed to that).
]]

local ArtAtlas = require(script.Parent.ArtAtlas)
local ArtAssets = require(script.Parent.ArtAssets)

local Art = {}

-- Offline (the test suite's fake Roblox draws its screenshots from the sheet files).
Art.localSheets = false
-- Build sheets that have no upload from ArtData (the fake Roblox can't).
Art.builtIn = true

type Source = { image: string?, content: Content? }

local sources: { [string]: Source } = {}
local failed: { [string]: boolean } = {} -- uploads that Roblox wouldn't load
local why: { [string]: string } = {} -- why a sheet couldn't be had
local blocked: string? = nil -- why the game can't make images at all (so it stops trying)
local keep: { EditableImage } = {} -- the built sheets, held so they stay alive
local uploads: { [string]: { id: number, version: string } } = {} -- the owner's (ArtService)
local busy = false -- a preload is running

-- The image id `sheet` was uploaded as, if that upload is of its current version (an id
-- written in by hand without its version is taken as current). `assets` and `versions`
-- default to ArtAssets and ArtAtlas.versions.
function Art.uploadedId(sheet: string, assets: { [string]: any }?, versions: { [string]: string }?): number?
	local current = (versions or (ArtAtlas :: any).versions or {})[sheet]
	local function check(entry: any): number?
		if type(entry) == "number" then
			return if entry > 0 then entry else nil
		end
		if type(entry) == "table" and type(entry.id) == "number" and entry.id > 0 and entry.version == current then
			return entry.id
		end
		return nil
	end
	if assets then
		return check(assets[sheet])
	end
	-- the owner's own uploads first, then the ones built into the place
	return check(uploads[sheet]) or check((ArtAssets :: any)[sheet])
end

-- The owner's uploads (from the server: ArtService), each { id, version }. True if any
-- changed, so the sheets want loading again (Art.preload).
function Art.setUploads(entries: any): boolean
	if type(entries) ~= "table" then
		return false
	end
	local changed = false
	for sheet, entry in entries do
		if type(sheet) == "string" and type(entry) == "table" and type(entry.id) == "number" and type(entry.version) == "string" then
			local old = uploads[sheet]
			if not old or old.id ~= entry.id or old.version ~= entry.version then
				uploads[sheet] = { id = entry.id, version = entry.version }
				failed[sheet] = nil
				why[sheet] = nil
				changed = true
			end
		end
	end
	return changed
end

-- Whether `sheet` was uploaded, but before its art last changed.
local function outdated(sheet: string): boolean
	if Art.uploadedId(sheet) then
		return false
	end
	for _, entry in { uploads[sheet], (ArtAssets :: any)[sheet] } do
		if type(entry) == "table" and type(entry.id) == "number" and entry.id > 0 then
			return true
		end
	end
	return false
end

local function sourceOf(sheet: string): Source?
	if Art.localSheets then
		return { image = "art:" .. sheet }
	end
	local id = Art.uploadedId(sheet)
	if id and not failed[sheet] then
		return { image = "rbxassetid://" .. tostring(id) }
	end
	return sources[sheet]
end

-- The sheet as an EditableImage, from its pixels in ArtData; or why it can't be.
local function build(sheet: string): (Content?, string?)
	if blocked then
		return nil, blocked
	end
	local folder = script.Parent:FindFirstChild("ArtData")
	local module = folder and folder:FindFirstChild(sheet)
	if not (module and module:IsA("ModuleScript")) then
		return nil, "its pixels aren't in the place (ArtData), since it was uploaded"
	end
	local okData, data = pcall(require, module)
	if not okData or type(data) ~= "table" then
		return nil, "its pixels couldn't be read (" .. tostring(data) .. ")"
	end
	local okMake, image = pcall(function()
		return game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(data.width, data.height) })
	end)
	if not okMake then
		-- (Roblox refuses EditableImage outright: every sheet would fail the same way)
		blocked = "Roblox doesn't let this game make images (" .. tostring(image) .. ")"
		return nil, blocked
	end
	if not image then
		return nil, "this device is out of memory for images"
	end
	local okFill, err = pcall(function()
		local EncodingService = game:GetService("EncodingService")
		-- strip by strip, top to bottom
		for i, chunks in data.strips do
			local top = (i - 1) * data.strip
			local packed = EncodingService:Base64Decode(buffer.fromstring(table.concat(chunks)))
			local pixels = EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd)
			image:WritePixelsBuffer(Vector2.new(0, top), Vector2.new(data.width, math.min(data.strip, data.height - top)), pixels)
		end
	end)
	if not okFill then
		image:Destroy()
		return nil, "its pixels couldn't be unpacked (" .. tostring(err) .. ")"
	end
	table.insert(keep, image)
	return Content.fromObject(image)
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

-- Puts sprite `s` (from `source`) on `img`: its whole canvas `size` pixels across (a
-- Vector2 stretches it), centred on `center`, mirrored if `flip`.
local function place(img: ImageLabel, s, source: Source, center: Vector2, size: number | Vector2, flip: boolean?)
	local kx, ky
	if typeof(size) == "Vector2" then
		kx, ky = size.X / s.ow, size.Y / s.oh
	else
		kx = (size :: number) / math.max(s.ow, s.oh)
		ky = kx
	end
	if source.content then
		img.ImageContent = source.content
	else
		img.Image = source.image or ""
	end
	-- where the drawn part's middle is, from the canvas's middle
	local mx, my = (s.ox + s.w / 2 - s.ow / 2) * kx, (s.oy + s.h / 2 - s.oh / 2) * ky
	if flip then
		-- the rect read right to left
		img.ImageRectOffset = Vector2.new(s.x + s.w, s.y)
		img.ImageRectSize = Vector2.new(-s.w, s.h)
		mx = -mx
	else
		img.ImageRectOffset = Vector2.new(s.x, s.y)
		img.ImageRectSize = Vector2.new(s.w, s.h)
	end
	img.Position = UDim2.fromOffset(center.X + mx, center.Y + my)
	img.Size = UDim2.fromOffset(s.w * kx, s.h * ky)
end

-- One ImageLabel and nothing else: sprite `name` with its whole canvas `size` pixels
-- across (a Vector2 stretches it: an ellipse from a circle), centred on `center`. For
-- the many small things on a map, where a frame round each would only cost. `flip`
-- mirrors it left to right by reading the rect backwards (a negative ImageRectSize).
function Art.label(parent: Instance?, name: string, center: Vector2, size: number | Vector2, flip: boolean?, props: { [string]: any }?): ImageLabel?
	local s = ArtAtlas.sprites[name]
	local source = s and sourceOf(s.sheet)
	if not s or not source then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = string.match(name, "[^/]+$") or name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Stretch
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	place(img, s, source, center, size, flip)
	for key, v in props or {} do
		(img :: any)[key] = v
	end
	img.Parent = parent
	return img
end

-- Turns an image Art.label made into another sprite in place (the next frame of an
-- animation: the Kraken's arm), placed the same way. False if it can't.
function Art.frame(img: ImageLabel, name: string, center: Vector2, size: number | Vector2, flip: boolean?): boolean
	local s = ArtAtlas.sprites[name]
	local source = s and sourceOf(s.sheet)
	if not s or not source then
		return false
	end
	place(img, s, source, center, size, flip)
	return true
end

-- Loads the uploaded sheets (with a time limit; one Roblox won't load is dropped), then
-- builds the rest from ArtData, and says in the Output which couldn't be had and why.
local function loadSheets(timeout: number?)
	local list, sheetOf = {}, {}
	for _, sheet in ArtAtlas.sheets do
		local id = Art.uploadedId(sheet)
		if id then
			local uri = "rbxassetid://" .. tostring(id)
			table.insert(list, uri)
			sheetOf[uri] = sheet
		end
	end
	if #list > 0 then
		local done = false
		task.spawn(function()
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
					local sheet = sheetOf[contentId]
					if status == Enum.AssetFetchStatus.Failure and sheet then
						failed[sheet] = true
						why[sheet] = "its uploaded image (" .. contentId .. ") didn't load: still being moderated, or not allowed in this game"
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
	for _, sheet in ArtAtlas.sheets do
		if Art.builtIn and not sourceOf(sheet) then
			local content, problem = build(sheet)
			if content then
				sources[sheet] = { content = content }
			elseif not failed[sheet] then
				why[sheet] = problem or "it couldn't be built"
			end
		end
	end
	local missing = Art.missing()
	if #missing > 0 then
		local lines = {}
		for _, m in missing do
			table.insert(lines, m.sheet .. ": " .. m.why)
		end
		warn(
			string.format("[Trapisque] %d of %d art sheets couldn't be loaded, so plainer stand-ins are drawn.\n  ", #missing, #ArtAtlas.sheets)
				.. table.concat(lines, "\n  ")
				.. "\nUpload those sheets (art/sheets in the repository; see art/README.md), or turn on "
				.. "Experience Settings > Security > Allow Mesh / Image APIs."
		)
	end
end

-- Gets the sheets ready (loadSheets): run before the first screen draws, and again when
-- the owner's uploads change.
function Art.preload(timeout: number?)
	if Art.localSheets then
		return
	end
	-- (one at a time: the owner's uploads can arrive while the first one runs)
	while busy do
		task.wait(0.1)
	end
	busy = true
	local ok, err = pcall(loadSheets, timeout)
	busy = false
	if not ok then
		warn("[Trapisque] loading the art failed: " .. tostring(err))
	end
end

-- The sheets that couldn't be had, and why: those Art.preload tried to load or build and
-- couldn't (so none offline, where the fake Roblox draws the stand-ins on purpose).
function Art.missing(): { { sheet: string, why: string } }
	local out = {}
	if Art.localSheets then
		return out
	end
	for _, sheet in ArtAtlas.sheets do
		if not sourceOf(sheet) and why[sheet] then
			local reason = why[sheet]
			if outdated(sheet) then
				reason ..= "; its upload is of older art, so it needs uploading again"
			end
			table.insert(out, { sheet = sheet, why = reason })
		end
	end
	return out
end

return Art
