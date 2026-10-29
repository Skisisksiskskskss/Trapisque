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
	scenery_1 = { id = 137758988666662, version = "f7b102c49726" },
	scenery_2 = { id = 75613331100483, version = "bfd491c61b81" },
	scenery_3 = { id = 114458018925808, version = "6280ee4734d3" },
	pieces_1 = { id = 86856771255019, version = "f5d0b79e9fee" },
	pieces_2 = { id = 103690998359771, version = "00922546c219" },
	pieces_3 = { id = 108930293665274, version = "5ac8c70b204f" },
	icons_1 = { id = 130011418411297, version = "4c41186e6efb" },
	icons_2 = { id = 92014138360421, version = "4bdbba8e54b2" },
	icons_3 = { id = 82942990014553, version = "5ec65d2c8d2d" },
	extras_1 = { id = 88835193670165, version = "12811230d118" },
	fish_1 = { id = 120604847864264, version = "13f3f29bd3c7" },
	ui_1 = { id = 0, version = "7942206e8fc2" },
}
