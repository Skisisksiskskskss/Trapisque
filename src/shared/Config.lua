--[[
	Config
	Every tunable number in Trapisque lives here so the game can be balanced without
	digging through the rules engine. Values marked (rulebook) come straight from the
	Trapisque rulebook; values marked (digital) are choices made for the Roblox version.
]]

local Config = {}

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------
Config.Rules = {
	TreasuresToWin = 4, -- Classic length; World War Four uses 3 (see Modes)
	StartingCoins = 1, -- so the Potion Seller is useful early
	CoinsPerTreasure = 2, -- banking a treasure pays out
	CoinsPerGotcha = 1, -- your hidden trap caught someone...
	PowerPerGotcha = 2, -- ...which also charges your Power
	HandLimit = 5, -- max cards in hand
	CardsPerTurn = 1, -- cards you may play each turn (passive cards don't count)
	PotionStock = 6, -- of each potion at the Potion Seller, per match

	TrapRange = 5, -- traps and board pieces go on a tile within this many tiles of you
	TrapCap = 3, -- hidden traps you can have out at once (placing another removes your oldest)
	BonkBack = 2, -- landing on someone knocks them back this many tiles...
	BonkBounce = 1, -- ...and bounces you forward this many (which keeps players from bunching up)
	BonkChain = false, -- only your own move bonks; being knocked onto someone doesn't
	WallPassMin = 5, -- you can't move past a wall unless you move 5 or more
	GrogSurviveMin = 4, -- roll 4+ or the Grog gets you
	TeleporterMinDistance = 8, -- teleporters must be 8+ tiles from the treasure
	ConveyorLength = 3, -- a conveyor covers 3 tiles
	MudslideBack = 3,
	BananaBack = 2,
	SlimeDrag = 5, -- slime pools eat this many steps (with no more left than that, you're stuck in it)
	TrampolineForward = 3,
	TelepathyMax = 3,
	JeopardySteps = 6,
	FrozenTurns = 2, -- Frozen: roll one die, halved (no choice, no Power), for this many turns
	BurningTurns = 2, -- Burning: hop back 1 at the start of this many turns

	-- Durability of things placed on the board (number of triggers before they vanish).
	-- nil means one trigger for traps, permanent for teleporters.
	PlacedUses = {
		wall = 1,
		conveyor = 3,
		trampoline = 2,
	},

	-- safety valve per match length; the highest score wins if it's reached
	MaxRounds = { quick = 40, standard = 60, classic = 80 },
}

-- Character numbers (Power costs and passives). Tuned with bot simulations so that
-- every character wins about as often on every map (see tests/balance.luau).
Config.Characters = {
	mage = { cost = 7, turns = 1, skate = 1 },
	trapper = { cost = 6, trapCap = 4, bounty = 2 },
	fire_starter = { cost = 10, blast = 4 },
	naturalist = { cost = 6, range = 5, cap = 2 },
	warper = { cost = 10, range = 7 },
	overseer = { cost = 4, steps = 2 },
}

-- Relative chances for a token spot to become each token type at setup.
-- (digital) The rulebook says "random token"; Potion Sellers are a little rarer.
Config.TokenWeights = {
	{ "trap", 34 },
	{ "assist", 30 },
	{ "neutral", 22 },
	{ "potion", 14 },
}
Config.MinPotionSellers = 1

---------------------------------------------------------------------------
-- Pacing (seconds). The server waits roughly this long for clients to animate.
---------------------------------------------------------------------------
Config.Timing = {
	TurnTime = 45, -- human decision time per turn (practice games have no timer)
	ShopTime = 30,
	AwayAfter = 2, -- turns in a row with no input at all before a bot plays for someone
	AwayGrace = 5, -- an away player's turn waits this long for them before the bot moves
	BotThinkMin = 0.45,
	BotThinkMax = 1.0,
	StepTime = 0.17, -- per tile when walking
	DiceTime = 0.85,
	SpinTime = 1.9,
	EventTime = 0.9, -- generic popup / effect
	TurnBanner = 0.4, -- the banner keeps sliding while the dice roll
	IntroTime = 4.5,
	ResultsTime = 25, -- results screen before the server sends everyone home
}

---------------------------------------------------------------------------
-- Matchmaking / parties / servers
---------------------------------------------------------------------------
Config.Party = {
	MaxSize = 6,
	CodeLength = 6,
	CodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789", -- no 0/O/1/I to avoid confusion
	CodeTTL = 600, -- seconds a code stays registered without a refresh
	CodeRefresh = 120,
	InviteExpiry = 60,
}

Config.Matchmaking = {
	PollInterval = 3, -- how often each lobby server polls for assignments
	MatchmakerInterval = 4, -- how often the elected matchmaker forms matches
	TicketTTL = 120, -- tickets expire if their server stops refreshing them
	TicketRefresh = 30,
	LockTTL = 12,
	-- Chaos starts as soon as this many players are found...
	ChaosTarget = 4,
	-- ...or with at least ChaosMin players once the oldest ticket waited this long:
	ChaosMin = 2,
	ChaosWait = 25,
	-- (digital) if a human waits this long, empty seats are filled with bots
	BotFillAfter = 45,
	AssignmentTTL = 60,
	MatchInfoTTL = 600,
}

Config.Server = {
	-- When true, a match whose players are all on this server runs right here instead
	-- of teleporting to a reserved server (always true in Studio, where teleports fail).
	PreferLocalMatches = false,
	RequestRateLimit = 12, -- remote requests per player per second
}

---------------------------------------------------------------------------
-- Meta game: gems, levels, gamepasses
---------------------------------------------------------------------------
-- Create these gamepasses on the Creator Dashboard (Monetization > Passes) and paste
-- their ids here. A pass left at 0 is simply hidden from the Shop.
Config.GamePasses = {
	VIP = 0,
	DoubleGems = 0,
	LuckyCharm = 0,
	EmotePack = 0,
}

Config.Rewards = {
	MatchGems = 15, -- for finishing a match
	TreasureGems = 6, -- per treasure you collected
	WinGems = 30, -- your team won
	MatchXP = 40,
	TreasureXP = 15,
	WinXP = 60,
	PracticeMultiplier = 0.5, -- matches vs bots only
	VIPGemBonus = 0.25,
	DoubleGemsMultiplier = 2,
	LevelUpGems = 50,
	DailyGems = 40,
	StartingGems = 300,
	StartingFreeChests = 1,
}

function Config.xpForLevel(level: number): number
	return 100 + 40 * (level - 1)
end

Config.Data = {
	StoreName = "TrapisqueProfiles_v1",
	AutosaveInterval = 120,
	LockTimeout = 90, -- a session lock older than this is considered dead
}

-- In Studio, pretend the player owns every gamepass so all features can be tested.
Config.StudioOwnsAllPasses = true

Config.Version = "1.0.0"

return Config
