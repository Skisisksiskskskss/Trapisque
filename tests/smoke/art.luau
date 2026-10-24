--[[
	The art note, end to end, on the fake Roblox: in a place with no sheet uploaded yet,
	the game can't build its art sheets either (the fake has no EditableImage, like a
	game where Roblox doesn't allow it), so the owner gets the note in the lobby; they paste the ids of the nine sheets they
	uploaded as decals (in a muddled order); the server looks each one up, finds its
	image and its sheet by the name it was uploaded under, keeps them (DataStore) and
	hands them to the client, which loads the art and redraws the lobby with it.

	Bundle with tools/bundle.py --all after the fake (tools/smoke.sh art).
]]

local F = Fake
local cfg = SMOKE or {}

F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.mount(game:GetService("ServerScriptService"), "Server", getNode("Server"))
F.mount(game:GetService("ReplicatedFirst"), "First", getNode("First"))
requireModule("Shared/Config").Staff.OwnerIds = { 4242 }
F.messagingHangs = true
F.setScreen({ w = cfg.w or 1280, h = cfg.h or 720 })

local function fail(msg: string)
	error("[art] " .. msg .. "\n" .. F.problems(), 0)
end
local function check(cond, msg: string)
	if not cond then
		fail(msg)
	end
end

-- the nine sheets, uploaded as decals named after their files (each decal's image has
-- its own id), and how the screenshots draw those images: from the sheet files
local ArtAtlas = requireModule("Client/UI/ArtAtlas")
-- a place built before any sheet was uploaded
local ArtAssets = requireModule("Client/UI/ArtAssets")
for _, sheet in ArtAtlas.sheets do
	ArtAssets[sheet] = { id = 0, version = ArtAtlas.versions[sheet] }
end
F.assets = F.assets or {}
local decals, images = {}, {}
for i, sheet in ArtAtlas.sheets do
	local decal, image = 7000000100 + i, 7000000000 + i
	F.assetInfo[decal] = { Name = sheet, AssetTypeId = 13, Image = image }
	F.assetInfo[image] = { Name = "Images/" .. sheet, AssetTypeId = 1 }
	F.assets["rbxassetid://" .. image] = "art:" .. sheet
	F.assets[string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", image)] = "art:" .. sheet .. "@420"
	decals[i] = decal
	images[sheet] = image
end
-- one sheet's image won't load in this game (as if it weren't allowed here): its
-- thumbnail stands in (the sheet with the Mage's emblem, which the lobby shows)
F.failAssets["rbxassetid://" .. images[ArtAtlas.sprites["emblems/mage"].sheet]] = true

F.spawn(function()
	requireModule("Server/Main")
end)
F.run(1)
local player = F.addPlayer("Tester", 4242)
F.run(0.5)
F.spawn(function()
	requireModule("First/Loading")
end)
F.spawn(function()
	requireModule("Client/Main")
end)

local Root = requireModule("Client/UI/Root")
local State = requireModule("Client/State")
local Art = requireModule("Client/UI/Art")
check(F.run(20, function()
	return State.get("profile") ~= nil and Root.currentName() == "lobby"
end), "the lobby never showed up")
check(#Art.missing() == #ArtAtlas.sheets, "the fake should have built no sheets, not " .. (#ArtAtlas.sheets - #Art.missing()))

-- the note, with its box for the ids
local box
check(F.run(6, function()
	box = F.findAll(Root.gui, function(d)
		return d.Name == "Ids" and d:IsA("TextBox") and F.visible(d)
	end)[1]
	return box ~= nil
end), "the owner got no art note")
if cfg.shots then
	-- (once the loading screen has lifted)
	F.run(3)
	F.shot("art-note")
end
-- pasted backwards, with a link and some words thrown in
local pasted = {}
for i = #decals, 1, -1 do
	table.insert(pasted, if i == 3 then "https://create.roblox.com/store/asset/" .. decals[i] .. "/x" else tostring(decals[i]))
end
box.Text = table.concat(pasted, ", ") .. " (all nine)"
-- (the note's backdrop is a button too, holding all its text: not that one)
local save = F.findAll(Root.gui, function(d)
	return d:IsA("GuiButton") and d.Name ~= "Modal" and F.visible(d) and string.find(F.textOf(d) or "", "Save ids", 1, true) ~= nil
end)[1]
check(save ~= nil, "the note has no Save ids button")
F.click(save)
local loaded = F.run(15, function()
	return #Art.missing() == 0
end)
if not loaded then
	-- what the note said
	local said = {}
	for _, d in F.findAll(Root.gui, function(d)
		return d:IsA("TextLabel") and F.visible(d)
	end) do
		table.insert(said, F.textOf(d))
	end
	fail("the art never loaded after the ids were saved (" .. #Art.missing() .. " sheets missing); on screen: " .. table.concat(said, " | "))
end
for sheet, image in images do
	check(Art.uploadedId(sheet) == image, sheet .. " got " .. tostring(Art.uploadedId(sheet)) .. ", not its image " .. image)
end
local report = Art.report()
check(report.uploaded == #ArtAtlas.sheets - 1 and report.thumbnails == 1, string.format("expected %d uploaded and 1 thumbnail, got %d and %d", #ArtAtlas.sheets - 1, report.uploaded, report.thumbnails))
-- kept for every server
local ArtService = requireModule("Server/ArtService")
local kept = 0
for sheet, entry in ArtService.ids() do
	check(entry.id == images[sheet] and entry.version == ArtAtlas.versions[sheet], sheet .. " was kept wrong")
	kept += 1
end
check(kept == #ArtAtlas.sheets, "the server kept " .. kept .. " sheets")
local stored = nil
F.spawn(function()
	stored = game:GetService("DataStoreService"):GetDataStore("TrapisqueArt_v1"):GetAsync("sheets")
end)
F.run(3, function()
	return stored ~= nil
end)
check(type(stored) == "table" and stored.icons_3 and stored.icons_3.id == images.icons_3, "the ids weren't saved in the DataStore")
F.run(3)
check(Root.currentName() == "lobby", "the lobby didn't come back after the art loaded")
if cfg.shots then
	F.shot("art-lobby")
end
-- the owner's tag says how it went
local tag = F.findAll(Root.gui, function(d)
	return d.Name == "ArtTag" and d:IsA("TextLabel")
end)[1]
check(tag ~= nil and string.find(tag.Text, "art 9/9 (1 as thumbnails)", 1, true) ~= nil, "the owner's tag reads " .. tostring(tag and tag.Text))
check(tag.Visible, "the owner's tag is hidden in the lobby")
F.print(string.format("art: the note took %d decal ids, the server found their images and sheets, kept them, and the art loaded (%d of %d sheets, %d as a thumbnail); the tag reads %q", #decals, kept, #ArtAtlas.sheets, report.thumbnails, tag.Text))
