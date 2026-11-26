--[[
	Theme: colors and fonts. The game keeps the original notebook look: off-white
	graph paper, #222 ink outlines, pastel birds; menus use chunky rounded
	Roblox-style buttons in the same palette.
]]

local Theme = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
Theme.hex = hex

Theme.Paper = hex("#fafafa")
Theme.PaperDark = hex("#f0f0f0")
Theme.Ink = hex("#222222")
Theme.InkSoft = hex("#666666")
Theme.Grid = hex("#000000")
Theme.White = Color3.new(1, 1, 1)
Theme.Black = Color3.new(0, 0, 0)

Theme.Pink = hex("#ffb3ba")
Theme.Mint = hex("#a8e6cf")
Theme.Blue = hex("#bae1ff")
Theme.Yellow = hex("#ffd166")
Theme.Purple = hex("#d4b5ff")
Theme.Orange = hex("#ffdfba")
Theme.Coin = hex("#ffcc33")
Theme.Danger = hex("#e74c3c")
Theme.Good = hex("#2ecc71")
Theme.Beak = hex("#ffcc66")
Theme.SpikeFill = hex("#cccccc")
Theme.SpikeMerged = hex("#e91e63")
Theme.ZapLeft = hex("#bae1ff")
Theme.ZapRight = hex("#ffb3ba")
Theme.Letterbox = hex("#1b1b22")

Theme.FontTitle = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.GothamBold
Theme.FontMono = Enum.Font.RobotoMono
Theme.FontHand = Enum.Font.PatrickHand

-- Original mode button accent colors
Theme.ModeColors = {
	SOLO = hex("#ffb3ba"),
	BOT = hex("#bae1ff"),
	COUCH_COOP = hex("#a8e6cf"),
	COUCH_DUEL = hex("#ffd166"),
	DUOS = hex("#84fab0"),
	VERSUS = hex("#ff9a9e"),
}

return Theme
