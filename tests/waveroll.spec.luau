--!nocheck
-- Wave roll and catalog invariants.

return function(t)
	local Brainrots = t.require("src/shared/Config/Brainrots")
	local Rarities = t.require("src/shared/Config/Rarities")
	local Mutations = t.require("src/shared/Config/Mutations")
	local WaveRoll = t.require("src/shared/Modules/WaveRoll")
	local BrainrotStats = t.require("src/shared/Modules/BrainrotStats")

	t.test("every rarity has at least one brainrot", function()
		for _, rarity in Rarities.List do
			local bucket = Brainrots.ByRarity[rarity.Index]
			t.expect(bucket ~= nil and #bucket >= 3, "rarity " .. rarity.Name .. " needs >= 3 brainrots")
		end
	end)

	t.test("brainrot factors stay inside the documented band", function()
		for _, def in Brainrots.List do
			t.expect(def.Factor >= 0.75 and def.Factor <= 1.35, def.Id .. " factor out of band")
		end
	end)

	t.test("higher rarity always out-earns lower rarity at equal size", function()
		for i = 2, Rarities.Count do
			local weakestHigh = math.huge
			for _, def in Brainrots.ByRarity[i] do
				weakestHigh = math.min(weakestHigh, BrainrotStats.Income(def.Id, "None", "Normal"))
			end
			local strongestLow = 0
			for _, def in Brainrots.ByRarity[i - 1] do
				strongestLow = math.max(strongestLow, BrainrotStats.Income(def.Id, "None", "Normal"))
			end
			t.expect(weakestHigh > strongestLow, "income overlap between rarity " .. (i - 1) .. " and " .. i)
		end
	end)

	t.test("rarity odds sum to 1 for every tier and rebirth", function()
		for tier = 1, 10 do
			for rebirths = 0, 3 do
				local total = 0
				for _, entry in WaveRoll.RarityOdds(tier, rebirths, 1.5) do
					total += entry.Chance
				end
				t.near(total, 1, 1e-9, "odds for tier " .. tier)
			end
		end
	end)

	t.test("window never contains locked rarities", function()
		for tier = 1, 10 do
			local highest = Rarities.HighestUnlocked(tier, 0)
			for _, r in Rarities.Window(tier, 0) do
				t.expect(r <= highest, "locked rarity in window at tier " .. tier)
			end
		end
	end)

	t.test("late tiers drop commons", function()
		for _, r in Rarities.Window(5, 0) do
			t.expect(r >= 3, "tier 5 should not roll commons/uncommons")
		end
	end)

	t.test("normal rolls are valid and distribution follows weights", function()
		local rng = t.newRng(42)
		local counts = {}
		for _ = 1, 20000 do
			local roll = WaveRoll.RollNormal(rng, { Tier = 1, Rebirths = 0, Luck = 1 })
			t.expect(Brainrots.ById[roll.Id] ~= nil, "unknown id")
			t.expect(Mutations.ByName[roll.Mutation] ~= nil, "unknown mutation")
			counts[roll.Rarity] = (counts[roll.Rarity] or 0) + 1
		end
		local commonShare = counts[1] / 20000
		t.near(commonShare, 60 / 85, 0.02, "common share at tier 1")
	end)

	t.test("boss rolls land inside the power band when possible", function()
		local rng = t.newRng(7)
		local Economy = t.require("src/shared/Config/Economy")
		for tier = 1, 10 do
			local level = tier * 10
			local crystal = Economy.CrystalPower(level, 1)
			for _ = 1, 50 do
				local roll = WaveRoll.RollBoss(rng, { Tier = tier, Rebirths = 0, Luck = 1 }, crystal, 1.1, 2.2)
				local ratio = roll.Power / crystal
				t.expect(roll.Boss, "boss flag")
				t.expect(ratio >= 1.1 and ratio <= 2.2, string.format("tier %d boss ratio %.2f", tier, ratio))
			end
		end
	end)

	t.test("lucky odds sum to 1 and only include unlocked rarities", function()
		for tier = 1, 10 do
			local total = 0
			for _, entry in WaveRoll.LuckyOdds(tier, 0) do
				total += entry.Chance
				t.expect(entry.Rarity <= Rarities.HighestUnlocked(tier, 0), "locked lucky rarity")
			end
			t.near(total, 1, 1e-9, "lucky odds tier " .. tier)
		end
	end)

	t.test("tutorial roll is beamable by a level 1 crystal", function()
		local Economy = t.require("src/shared/Config/Economy")
		local roll = WaveRoll.Tutorial()
		t.expect(roll.Power <= Economy.CrystalPower(1, 1), "tutorial brainrot too strong")
	end)

	t.test("mutation roll respects multipliers", function()
		local rng = t.newRng(99)
		local gold = 0
		for _ = 1, 20000 do
			if WaveRoll.RollMutation(rng, { Gold = 5 }) == "Gold" then
				gold += 1
			end
		end
		t.near(gold / 20000, 0.2, 0.02, "gold x5 share")
	end)
end
