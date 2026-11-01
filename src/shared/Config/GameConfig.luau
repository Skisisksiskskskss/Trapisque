--!strict
-- Global tuning constants. Every number a designer might want to tweak lives here or in Economy.

local GameConfig = {
	MaxPlots = 8,

	-- Map geometry (studs)
	PortalRadius = 14,
	BaseFrontRadius = 92, -- distance from map centre to the base's front wall
	BaseSize = 64, -- square plot edge
	RingRoadRadius = 84, -- escaped brainrots run a lap on this circle
	BeamStopDistance = 9, -- brainrot stops this far in front of the door for the showdown

	-- Wave timing (seconds)
	WaveInterval = 50,
	EmergeTime = 1.4,
	WalkSpeed = 11, -- studs per second
	ShowdownTime = 2.2,
	BossEvery = 5,
	FirstWaveDelay = 6, -- newcomer personal wave
	BossPowerMin = 1.1, -- boss power relative to the player's crystal power
	BossPowerMax = 2.2,

	-- Charging
	ChargePerTap = 0.02,
	ChargeMax = 0.30,
	ChargeMinTapInterval = 0.05,

	-- Doors / raids
	DoorBrokenTime = 40,
	DoorRepairPerHoldSecond = 4, -- seconds removed from the broken timer per second of holding REPAIR
	NewbieShieldMinutes = 10,

	-- Stealing
	StealHoldDuration = 1.2,
	CarrySpeedMultiplier = 0.7,
	CarryTimeout = 45,
	StealImmunitySeconds = 60, -- a freshly stolen brainrot cannot be re-stolen for this long

	-- Bonk
	BonkRange = 9,
	BonkCooldown = 0.9,
	BonkKnockback = 55,

	-- Escaped brainrots
	EscapeSpeed = 16,
	EscapeLaps = 1,

	-- Storage
	StorageMax = 50,

	-- Offline
	OfflineRate = 0.5,
	OfflineCapHours = 8,
	OfflineCapHoursVip = 12,
	OfflineMinSeconds = 120,

	-- Saving
	AutosaveInterval = 60,
	DataStoreName = "BeamABrainrot_PlayerData_v1",

	-- Base character speed
	PlayerWalkSpeed = 20,
}

return GameConfig
