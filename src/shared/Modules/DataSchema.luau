--!strict
-- Player save schema: template, versioned migrations and reconciliation. Pure (no Roblox APIs) and unit-tested.

export type BrainrotRecord = {
	Uid: string,
	Id: string,
	Mutation: string,
	Size: string,
	Obtained: number,
	StolenAt: number?,
}

export type PlayerData = {
	Version: number,
	Cash: number,
	LifetimeCash: number,
	Tier: number,
	CrystalLevel: number,
	DoorLevel: number,
	Rebirths: number,
	Brainrots: { [string]: BrainrotRecord },
	Slots: { [string]: string },
	NextUid: number,
	Index: { [string]: boolean },
	IndexClaimed: { [string]: boolean },
	Boosts: { [string]: number },
	Daily: { Streak: number, LastClaim: number },
	Codes: { [string]: boolean },
	Stats: { [string]: number },
	Tutorial: number,
	LastOnline: number,
	FirstJoin: number,
	Receipts: { string },
	Settings: { Music: boolean, Sfx: boolean },
	PlaytimeGiftDay: number,
	PlaytimeClaimed: { [string]: boolean },
}

local DataSchema = {}

DataSchema.CurrentVersion = 2
DataSchema.MaxReceipts = 100

local function template(): PlayerData
	return {
		Version = DataSchema.CurrentVersion,
		Cash = 0,
		LifetimeCash = 0,
		Tier = 1,
		CrystalLevel = 1,
		DoorLevel = 1,
		Rebirths = 0,
		Brainrots = {},
		Slots = {},
		NextUid = 1,
		Index = {},
		IndexClaimed = {},
		Boosts = { Overcharge = 0, IronDoor = 0, LuckyWave = 0, GoldenWave = 0, InstantRepair = 0 },
		Daily = { Streak = 0, LastClaim = 0 },
		Codes = {},
		Stats = { Captures = 0, Steals = 0, Stolen = 0, Bosses = 0, Playtime = 0, DoorsBroken = 0 },
		Tutorial = 0,
		LastOnline = 0,
		FirstJoin = 0,
		Receipts = {},
		Settings = { Music = true, Sfx = true },
		PlaytimeGiftDay = 0,
		PlaytimeClaimed = {},
	}
end

DataSchema.Template = template

-- Migrations[n] upgrades a version-n save to version n+1.
local migrations: { [number]: (any) -> any } = {
	[1] = function(data: any): any
		-- v1 -> v2: adds per-day playtime gift tracking.
		data.PlaytimeGiftDay = 0
		data.PlaytimeClaimed = {}
		data.Version = 2
		return data
	end,
}
DataSchema.Migrations = migrations

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
DataSchema.DeepCopy = deepCopy

-- Fills any missing keys from the template without touching existing values. Only recurses into
-- dictionary-shaped template tables that have keys (empty template tables are treated as opaque maps).
local function reconcile(target: any, source: any)
	for key, value in source do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(target[key], value)
		end
	end
end

function DataSchema.Migrate(raw: any): (PlayerData, boolean)
	-- Returns the migrated data and whether it was upgraded from an older version.
	if type(raw) ~= "table" then
		return template(), false
	end
	local data = raw
	local version = tonumber(data.Version) or 1
	local upgraded = false
	while version < DataSchema.CurrentVersion do
		local step = migrations[version]
		assert(step ~= nil, "missing migration from version " .. version)
		data = step(data)
		version = tonumber(data.Version) or version + 1
		upgraded = true
	end
	reconcile(data, template())
	return data :: PlayerData, upgraded
end

function DataSchema.IsNewer(raw: any): boolean
	-- True when a save was written by a newer build than this server knows. Such saves must not be touched.
	return type(raw) == "table" and (tonumber(raw.Version) or 0) > DataSchema.CurrentVersion
end

function DataSchema.AddReceipt(data: PlayerData, purchaseId: string)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > DataSchema.MaxReceipts do
		table.remove(data.Receipts, 1)
	end
end

function DataSchema.HasReceipt(data: PlayerData, purchaseId: string): boolean
	return table.find(data.Receipts, purchaseId) ~= nil
end

function DataSchema.NewUid(data: PlayerData): string
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	return uid
end

function DataSchema.CountBrainrots(data: PlayerData): number
	local count = 0
	for _ in data.Brainrots do
		count += 1
	end
	return count
end

return DataSchema
