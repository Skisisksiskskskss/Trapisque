--[[
	BadgeService
	Awards the badges in Shared/Meta/Badges: stored in the profile (the lobby's BADGES
	page shows them) and on Roblox for those with an id in Config.Badges. Match moments
	come from Match (matchFeats); the rest from wherever they happen (fishing).

		BadgeService.award(player, key)
		BadgeService.matchFeats(player, { won, stats, feats, tutorial, staffAboard, partySize })
		BadgeService.roleOf = AdminService.role   -- set by Main (who counts as the crew)
]]

local RobloxBadges = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Badges = require(Shared.Meta.Badges)
local Characters = require(Shared.Game.Characters)
local Progress = require(Shared.Meta.Progress)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)

local BadgeService = {}

BadgeService.roleOf = nil :: ((Player) -> string?)?

function BadgeService.isStaff(player: Player): boolean
	local roleOf = BadgeService.roleOf
	if not roleOf then
		return false
	end
	local ok, role = pcall(roleOf, player)
	return ok and role ~= nil
end

function BadgeService.award(player: Player, key: string)
	local def = Badges.byKey[key]
	local data = DataService.get(player)
	if not def or not data then
		return
	end
	if data.badges[key] then
		return
	end
	data.badges[key] = os.time()
	Net.push(player, "badge", { key = key })
	DataService.pushProfile(player)
	local id = Config.Badges[key]
	if type(id) == "number" and id > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				RobloxBadges:AwardBadge(player.UserId, id)
			end)
			if not ok then
				warn("[Trapisque] couldn't award badge " .. key .. ": " .. tostring(err))
			end
		end)
	end
end

-- After a match: everything it could have earned.
function BadgeService.matchFeats(player: Player, r)
	local s = r.stats or {}
	local f = r.feats or {}
	local function give(key: string, yes: any)
		if yes then
			BadgeService.award(player, key)
		end
	end
	give("first_voyage", r.tutorial)
	give("walk_the_plank", (s.deaths or 0) >= 3)
	give("bowling", f.multiBonk)
	give("hat_trick", (s.gotchas or 0) >= 3)
	give("comeback", r.won and (s.underdog or 0) > 0)
	give("snake_eyes", f.snakeEyes)
	give("boxcars", f.boxcars)
	give("untouchable", r.won and (s.bonked or 0) == 0)
	give("boo_who", (f.scared or 0) >= 3)
	give("hot_feet", f.scorched)
	give("phoenix", f.phoenix)
	give("grog_dodger", f.grog)
	give("jackpot", f.jackpot)
	give("human_cannonball", f.cannonBonk)
	give("captains_table", r.staffAboard)
	give("full_crew", (r.partySize or 1) >= 6)
	-- lifetime goals
	local data = DataService.get(player)
	if data then
		give("hoarder", (data.stats.treasures or 0) >= 100)
		local all, top = true, 1
		for _, id in Characters.ids do
			local xp = data.mastery[id] or 0
			if xp <= 0 then
				all = false
			end
			top = math.max(top, Progress.masteryLevel(xp))
		end
		give("meet_the_crew", all)
		give("master", top >= Progress.masteryMax)
	end
end

return BadgeService
