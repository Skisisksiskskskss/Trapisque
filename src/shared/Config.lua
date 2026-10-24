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
	SnareEscapeMin = 4, -- snared: roll 4+ at the start of your turn or lose it
	TeleporterMinDistance = 8, -- teleporters must be 8+ tiles from the treasure
	ConveyorLength = 3, -- a conveyor covers 3 tiles
	MudslideBack = 3,
	BananaBack = 2,
	SlimeDrag = 5, -- slime pools eat this many steps (with no more left than that, you're stuck in it)
	-- Underdog: whoever is clearly last (behind everyone else by this many tiles, a whole
	-- lap counting for every treasure) rolls an extra die on their turn
	UnderdogGap = 8,
	-- Wanted: from the end of round WantedFrom, whoever leads the race by WantedLead tiles
	-- or more (a lap counting for every treasure) has a price on their head. It starts at
	-- WantedStart coins and goes up by 1 every round they stay ahead and with every rival
	-- they bonk or catch in a trap, up to WantedMax: then they're Most Wanted and their
	-- hidden traps are out in the open. Bonk them or catch them in your trap to claim it
	-- (the coins and one of their cards); reach the treasure with it and it's theirs.
	WantedFrom = 2,
	WantedLead = 4,
	WantedStart = 3,
	WantedMax = 8,
	SandsSlide = 3, -- Shifting Sands: forward in even rounds, back in odd ones
	-- Haunted Hollow: ghosts drift this many tiles toward the Start at the end of every
	-- round; walking into one stops you and scares you back this many tiles
	GhostDrift = 2,
	GhostScare = 1,
	-- Mount Kaboom: lava streams stop you like rivers (a Fire Cloak carries you across),
	-- and the volcano erupts at the end of every Nth round: anyone standing in a stream
	-- is scorched (Burning) and scrambles back this many tiles
	EruptEvery = 3,
	EruptBack = 2,
	-- Frostbite Floes: falling through the ice freezes you for this many turns, and the
	-- current under it carries you back this many tiles
	IceFrozen = 1,
	IceSlip = 1,
	-- Kraken's Reach: the tentacle rises this many tiles ahead of the leader (fewest,
	-- most), and drags whoever it hits back this many
	KrakenAhead = { 3, 6 },
	KrakenDrag = 3,
	-- Clockwork Cove: tipped off the rising drawbridge, you swim back this many tiles
	BridgeTip = 2,
	TelepathyMax = 3,
	JeopardySteps = 6,
	FrozenTurns = 2, -- Frozen: roll one die, halved (no choice, no Power), for this many turns
	BurningTurns = 2, -- Burning: hop back 1 at the start of this many turns

	-- Durability of things placed on the board (number of triggers before they vanish).
	-- nil means one trigger for traps, permanent for teleporters.
	PlacedUses = {
		wall = 1,
		conveyor = 3,
		sands = 3,
	},

	-- safety valve per match length; the highest score wins if it's reached
	MaxRounds = { blitz = 25, quick = 40, standard = 60, classic = 80 },
}

-- Character numbers (Power costs and passives). Tuned with bot simulations so that
-- every character wins about as often on every map (see tests/balance.luau).
Config.Characters = {
	mage = { cost = 8, turns = 1, skate = 1 },
	trapper = { cost = 6, trapCap = 4, bounty = 2 },
	fire_starter = { cost = 10, blast = 4 },
	naturalist = { cost = 12, charge = 2, trample = 2 },
	warper = { cost = 10, range = 7 },
	overseer = { cost = 4, steps = 2 },
	gambler = { cost = 17 },
	cannoneer = { cost = 8, range = 6, fly = 3, extraBack = 1 },
}

-- Four characters are free; the others unlock at these account levels (by playing).
Config.CharacterUnlocks = {
	warper = 3,
	overseer = 5,
	gambler = 7,
	cannoneer = 10,
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
	VoteTime = 10, -- Quick Play's map vote
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
	-- a free-for-all searcher can drop into a bot's seat in a running Quick Play match
	-- up to this round (and only before anyone has banked a treasure)
	DropInRounds = 6,
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
	Chat = 0, -- 10 Robux: type your own lines in the game chat
	VoicePack = 0,
	VictoryParade = 0,
	CaptainsChest = 0,
}

-- Staff: the owner (and admins the owner picks) get the staff panel. The game's creator
-- is always the owner (the group's owner, for a group game); list more owner ids here.
Config.Staff = {
	OwnerIds = {},
	StudioIsOwner = true, -- everyone testing in Studio is the owner
	AdminMaxBanHours = 72, -- admins can ban for up to this long; only the owner bans for good
	StoreName = "TrapisqueStaff_v1",
	Topic = "TrapisqueStaff",
	-- chat reports (a player taps someone's line in the chat > REPORT)
	ReportLines = 8, -- how many of the reported person's latest lines come with it
	Reports = 60, -- reports kept for the panel (oldest drop off)
	ReportCooldown = 30, -- seconds between one player's reports
}

-- Badges: create each one on the Creator Dashboard (the experience > Engagement >
-- Badges, with its icon from docs/store/badges) and paste its id here. A badge left at
-- 0 is still earned and shown in the game (the BADGES page); it just isn't awarded on
-- Roblox. See Shared/Meta/Badges for what each one is for.
Config.Badges = {
	first_voyage = 0,
	walk_the_plank = 0,
	bowling = 0,
	hat_trick = 0,
	comeback = 0,
	snake_eyes = 0,
	boxcars = 0,
	untouchable = 0,
	boo_who = 0,
	hot_feet = 0,
	phoenix = 0,
	grog_dodger = 0,
	jackpot = 0,
	human_cannonball = 0,
	golden_fish = 0,
	captains_table = 0,
	full_crew = 0,
	hoarder = 0,
	meet_the_crew = 0,
	master = 0,
}

-- The community reward: join the game's Roblox group (and like the game) for Gems,
-- once. GroupId 0 uses the group that owns the game, if a group does.
Config.Community = {
	GroupId = 0,
	Gems = 150,
}

-- The daily deals in the Shop: four chest cosmetics sold straight for Gems, new every
-- day (the same everywhere, 00:00 UTC).
Config.DailyShop = {
	Slots = { "common", "rare", "epic", "legendary" },
	Prices = { common = 120, rare = 280, epic = 650, legendary = 1400, mythic = 3000 },
}

-- The game chat (ChatService): quick lines for everyone, typed lines with the Chat pass.
Config.Chat = {
	MaxLength = 120,
	Cooldown = 1.2, -- seconds between lines
	Burst = 3, -- lines in a row before the cooldown bites
	History = 40, -- lines each chat window keeps
	BubbleSeconds = 5,
}

Config.Rewards = {
	MatchGems = 15, -- for finishing a match
	TreasureGems = 6, -- per treasure you collected
	WinGems = 30, -- your team won
	AwardGems = 10, -- everyone's end-of-match award (Shared/Game/Awards)
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

-- A dropped connection keeps your seat this long: a bot plays it until you're back (a
-- match with nobody else in it waits for you). The Leave button gives it up at once.
Config.Rejoin = {
	Seconds = 180,
}

Config.Data = {
	StoreName = "TrapisqueProfiles_v1",
	AutosaveInterval = 120,
	LockTimeout = 90, -- a session lock older than this is considered dead
}

-- In Studio, pretend the player owns every gamepass so all features can be tested.
Config.StudioOwnsAllPasses = true

Config.Version = "1.2.0"

return Config
