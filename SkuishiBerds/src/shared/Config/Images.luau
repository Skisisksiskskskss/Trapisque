--[[
	Optional art slots (for ForgeGUI exports or any other images you upload).

	Everything in the game is drawn with plain UI shapes, so all of these can
	stay empty. Fill one in ("rbxassetid://123...") and that image replaces the
	drawn version.
]]

return {
	Logo = "", -- title screen logo (wide, transparent PNG works best)
	MenuBackground = "", -- tiled/stretched behind the menus
	CoinIcon = "",
	PlayButton = "", -- background image for the big PLAY button
	ShopBanner = "",
	ModeIcons = {
		SOLO = "",
		BOT = "",
		COUCH_COOP = "",
		COUCH_DUEL = "",
		DUOS = "",
		VERSUS = "",
	},
	BirdPortraits = {
		-- berd = "rbxassetid://...",
	},
}
