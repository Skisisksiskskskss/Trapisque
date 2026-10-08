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
	TreasuresToWin = 5, -- (rulebook) World War Four overrides this to 4 in Modes
	StartingCoins = 1, -- (digital) so the Potion Seller is useful early
	CoinsPerTreasure = 1, -- (digital) reaching the treasure pays out one coin
	HandLimit = 8, -- (digital) max cards in hand
	PerItemLimit = 5, -- (rulebook) "at most 5 items" of one kind per player
	PotionStock = 9, -- (rulebook) 9 of each potion at the Potion Seller

	WallPassMin = 5, -- (rulebook) you can't move past a wall unless you move more than 4
	GrogSurviveMin = 4, -- (rulebook) roll 4+ or the Grog gets you
	GateEscapeMin = 4, -- (digital) locked gate: roll 4+ on a later turn to break free
	TeleporterMinDistance = 8, -- (rulebook) teleporters must be 8+ tiles from the treasure
	ConveyorLength = 3, -- (rulebook) conveyor covers 3 tiles
	MudBack = 1, -- (rulebook)
	MudslideBack = 2, -- (rulebook)
	BounceForward = 2, -- (rulebook)
	MoonwalkMax = 3, -- (rulebook)
	TelepathyMax = 3, -- (rulebook)
	JeopardySteps = 6, -- (rulebook)

	AbilityRechargeCycles = 2, -- (rulebook) Mage & Trapper recharge every 2 cycles
	QuickRechargeCycles = 1, -- (digital) ...but every cycle in 2-treasure games
	OverseerRechargeRounds = 2, -- (rulebook) Overseer recharges every 2 rounds
	TrapperStartingTraps = 2, -- (rulebook v1)
	FireStarterStartingFires = 2, -- (rulebook v1)

	-- Durability of things placed on the board (number of triggers before they vanish).
	-- nil means permanent.
	PlacedUses = {
		wall = 1,
		conveyor = 3,
		shifting_sands = 2,
		teleporter = nil,
	},

	-- (digital) safety valve per match length; the highest score wins if it's reached
	MaxRounds = { quick = 50, standard = 75, classic = 120 },
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
	TurnTime = 35, -- human decision time per turn
	ShopTime = 25,
	BotThinkMin = 0.7,
	BotThinkMax = 1.5,
	StepTime = 0.22, -- per tile when walking
	DiceTime = 1.25,
	SpinTime = 2.6,
	EventTime = 0.9, -- generic popup / effect
	TurnBanner = 0.8,
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
