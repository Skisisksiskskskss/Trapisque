--[[
	ArtAssets
	The Roblox image id each art sheet (art/sheets/<sheet>.png) was uploaded as, and the
	version of the sheet it was (ArtAtlas.versions). An upload is used only while its
	version is the sheet's current one: after the art changes, the sheets that changed
	need uploading again (their sprites moved). id = 0: not uploaded, so the game builds
	that sheet itself from ArtData (Art.lua).

	To fill an id in: upload the sheet (tools/upload_art.py, or the import button of
	Studio's Asset Manager) and put its image id where this says id = 0, leaving the
	version as it is (tools/upload_art.py sheet=id does that for an id uploaded by hand).
]]

return {
	scenery_1 = { id = 0, version = "f7b102c49726" },
	scenery_2 = { id = 0, version = "bfd491c61b81" },
	scenery_3 = { id = 0, version = "6280ee4734d3" },
	pieces_1 = { id = 0, version = "f5d0b79e9fee" },
	pieces_2 = { id = 0, version = "00922546c219" },
	pieces_3 = { id = 0, version = "5ac8c70b204f" },
	icons_1 = { id = 0, version = "4c41186e6efb" },
	icons_2 = { id = 0, version = "4bdbba8e54b2" },
	icons_3 = { id = 0, version = "5ec65d2c8d2d" },
}
