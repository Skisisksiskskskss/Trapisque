--[[
	ArtService
	The Roblox image ids of the art sheets (art/sheets/*.png) once the owner has uploaded
	them, kept in a DataStore so every server has them, and every place file built later
	too. The owner pastes the ids into the art note in the lobby (ArtNotice), in any
	order, as image ids or decal ids (the website uploads images as decals): each is
	matched to its sheet by the name it was uploaded under ("scenery_1", "icons_2"...),
	or else by the order the note lists the sheets in, and a decal's id is turned into
	its image's.

	Requests: "art.set" { ids = { number }, sheets = { name }, versions = { [name] = v },
	          want = { name }? (the sheets the note asked for: ids whose name doesn't say
	          their sheet go to these) } (owner only)
	          -> { saved = { [sheet] = { id, version } }, stored = boolean }
	Pushes:   "art.ids" { [sheet] = { id, version } } to everyone when they change
	ArtService.ids() is what "hello" hands each client.
]]

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")

local ArtIds = require(game:GetService("ReplicatedStorage").Shared.ArtIds)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)

local ArtService = {}

local STORE = "TrapisqueArt_v1"
local KEY = "sheets"
local TOPIC = "TrapisqueArt"

local IMAGE, DECAL = 1, 13 -- Roblox asset type ids

local store: DataStore? = nil
local ids: { [string]: { id: number, version: string } } = {}

-- Asks for the owner's role (set by Main: AdminService.role).
ArtService.roleOf = function(_player: Player): string?
	return nil
end

function ArtService.ids()
	return table.clone(ids)
end

-- The image an id shows, and the name it was uploaded under: an image's own id, or a
-- decal's image (what the decal loads as, or the image Roblox made just before it).
local function resolve(id: number): (number?, string?, string?)
	local okInfo, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if not okInfo or type(info) ~= "table" then
		return nil, nil, "Roblox doesn't know the id " .. id
	end
	local name = info.Name
	if info.AssetTypeId == IMAGE then
		return id, name
	end
	if info.AssetTypeId ~= DECAL then
		return nil, name, "the id " .. id .. " isn't an image or a decal"
	end
	local okLoad, model = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if okLoad and model then
		local decal = model:FindFirstChildWhichIsA("Decal", true)
		local image = decal and tonumber(string.match(decal.Texture, "(%d+)%D*$"))
		model:Destroy()
		if image then
			return image, name
		end
	end
	-- (uploading a decal makes its image first, usually with the id just before)
	local okPrev, prev = pcall(function()
		return MarketplaceService:GetProductInfo(id - 1, Enum.InfoType.Asset)
	end)
	if okPrev and type(prev) == "table" and prev.AssetTypeId == IMAGE then
		return id - 1, name
	end
	return nil, name, "couldn't find the image of the decal " .. id
end

local function save(changes): boolean
	if not store then
		return false
	end
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(KEY, function(old)
			local all = if type(old) == "table" then old else {}
			for sheet, entry in changes do
				all[sheet] = entry
			end
			return all
		end)
	end)
	return ok
end

local function set(player: Player, payload)
	if ArtService.roleOf(player) ~= "owner" then
		return false, "Only the game's owner can set the art."
	end
	if type(payload) ~= "table" or type(payload.ids) ~= "table" or type(payload.sheets) ~= "table" or type(payload.versions) ~= "table" then
		return false, "Bad request."
	end
	local sheets, versions = {}, {}
	for i, sheet in payload.sheets do
		if i > 32 or type(sheet) ~= "string" or not string.match(sheet, "^[%l%d_]+$") then
			return false, "Bad request."
		end
		local v = payload.versions[sheet]
		if type(v) ~= "string" or not string.match(v, "^%x+$") then
			return false, "Bad request."
		end
		table.insert(sheets, sheet)
		versions[sheet] = v
	end
	-- the sheets an id whose name doesn't say goes to (the ones the note asked for)
	local want = nil
	if type(payload.want) == "table" then
		want = {}
		for i, sheet in payload.want do
			if i > 32 or type(sheet) ~= "string" or not versions[sheet] then
				return false, "Bad request."
			end
			table.insert(want, sheet)
		end
	end
	local found, problems = {}, {}
	for i, raw in payload.ids do
		local id = tonumber(raw)
		if i > 32 or not id or id <= 0 or id ~= math.floor(id) then
			return false, "Those don't look like ids."
		end
		local image, name, problem = resolve(id)
		if image then
			table.insert(found, { image = image, name = name })
		else
			table.insert(problems, problem or tostring(id))
		end
	end
	if #found == 0 then
		return false, if #problems > 0 then problems[1] else "No ids found."
	end
	local changes = {}
	for sheet, image in ArtIds.match(found, sheets, want) do
		changes[sheet] = { id = image, version = versions[sheet] }
		ids[sheet] = changes[sheet]
	end
	local stored = save(changes)
	Net.pushAll("art.ids", ids)
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { origin = game.JobId })
	end)
	return true, { saved = changes, stored = stored, problems = problems }
end

-- Reads the saved ids again and hands them to everyone here.
local function refresh()
	if not store then
		return
	end
	local ok, value = pcall(function()
		return (store :: DataStore):GetAsync(KEY)
	end)
	if ok and type(value) == "table" then
		local fresh = {}
		for sheet, entry in value do
			if type(sheet) == "string" and type(entry) == "table" and type(entry.id) == "number" and type(entry.version) == "string" then
				fresh[sheet] = { id = entry.id, version = entry.version }
			end
		end
		ids = fresh
		if next(ids) then
			Net.pushAll("art.ids", ids)
		end
	end
end

function ArtService.init()
	Net.handle("art.set", set)
	-- the DataStore and the other servers come in the background (slow or missing in Studio)
	task.spawn(function()
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(STORE)
		end)
		if ok then
			local usable = true
			if ServerInfo.isStudio then
				usable = pcall(function()
					ds:GetAsync("__probe")
				end)
			end
			if usable then
				store = ds
				refresh()
			end
		end
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message and message.Data
				if type(data) == "table" and data.origin ~= game.JobId then
					refresh()
				end
			end)
		end)
	end)
end

return ArtService
