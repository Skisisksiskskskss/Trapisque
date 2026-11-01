--!nocheck
-- Pacing regression: simulates a typical active player against the REAL Economy + WaveRoll config and checks
-- that progression lands in the designed bands (see DECISIONS.md). If you retune Economy.luau, run this.

return function(t)
	local Economy = t.require("src/shared/Config/Economy")
	local GameConfig = t.require("src/shared/Config/GameConfig")
	local WaveRoll = t.require("src/shared/Modules/WaveRoll")

	local function simulate(seed, hours, rebirths)
		local rng = t.newRng(seed)
		local cash, tier, crystal, door = 0, 1, 1, 1
		local owned = {}
		local tierAt = {}
		local waves, captures, fails, breaks = 0, 0, 0, 0
		local cashMult = 1 + rebirths * Economy.RebirthCashBonus
		local powerMult = 1 + rebirths * Economy.RebirthPowerBonus
		local nextWave = GameConfig.FirstWaveDelay
		local function place(income)
			if #owned < Economy.Slots(tier) then
				table.insert(owned, income)
				return
			end
			local weakest, index = math.huge, nil
			for i, v in owned do
				if v < weakest then
					weakest, index = v, i
				end
			end
			if income > weakest then
				owned[index] = income
			end
		end
		for second = 1, hours * 3600 do
			for _, v in owned do
				cash += v * cashMult
			end
			if second >= nextWave then
				nextWave += GameConfig.WaveInterval
				waves += 1
				local params = { Tier = tier, Rebirths = rebirths, Luck = 1 }
				local crystalPower = Economy.CrystalPower(crystal, powerMult)
				local roll, threshold
				if waves % GameConfig.BossEvery == 0 then
					roll =
						WaveRoll.RollBoss(rng, params, crystalPower, GameConfig.BossPowerMin, GameConfig.BossPowerMax)
					local overcharge = if rng:NextNumber() < 0.3 then 0.5 else 0
					threshold = crystalPower * (1 + GameConfig.ChargeMax + overcharge)
				else
					roll = WaveRoll.RollNormal(rng, params)
					threshold = crystalPower * (1 + 0.22)
				end
				if roll.Power <= threshold then
					captures += 1
					place(roll.Income)
				else
					fails += 1
					if roll.Power > Economy.DoorStrength(door, powerMult) then
						breaks += 1
					end
				end
			end
			-- Greedy spending: cheapest available upgrade first.
			while true do
				local maxLevel = Economy.MaxLevelForTier(tier)
				local best, cost = nil, math.huge
				if crystal < maxLevel and Economy.CrystalCost(crystal) < cost then
					best, cost = "c", Economy.CrystalCost(crystal)
				end
				if door < maxLevel and door < crystal and Economy.DoorCost(door) < cost then
					best, cost = "d", Economy.DoorCost(door)
				end
				if Economy.CanTierUp(tier, crystal) and Economy.TierCost(tier) < cost then
					best, cost = "t", Economy.TierCost(tier)
				end
				if best == nil or cash < cost then
					break
				end
				cash -= cost
				if best == "c" then
					crystal += 1
				elseif best == "d" then
					door += 1
				else
					tier += 1
					tierAt[tier] = second
				end
			end
		end
		return { TierAt = tierAt, Waves = waves, Captures = captures, Fails = fails, Breaks = breaks, Tier = tier }
	end

	local function median(list)
		table.sort(list)
		return list[math.ceil(#list / 2)]
	end

	local runs = {}
	for seed = 1, 5 do
		table.insert(runs, simulate(seed * 101, 10, 0))
	end

	t.test("first upgrade tier arrives within 12 minutes", function()
		local times = {}
		for _, run in runs do
			table.insert(times, run.TierAt[2] or math.huge)
		end
		local m = median(times)
		t.expect(m < 12 * 60, string.format("tier 2 median at %.1f min", m / 60))
	end)

	t.test("tier 5 lands between 20 and 90 minutes", function()
		local times = {}
		for _, run in runs do
			table.insert(times, run.TierAt[5] or math.huge)
		end
		local m = median(times)
		t.expect(m > 20 * 60 and m < 90 * 60, string.format("tier 5 median at %.1f min", m / 60))
	end)

	t.test("max tier (first rebirth gate) lands between 3 and 9 hours", function()
		local times = {}
		for _, run in runs do
			table.insert(times, run.TierAt[10] or math.huge)
		end
		local m = median(times)
		t.expect(m > 3 * 3600 and m < 9 * 3600, string.format("tier 10 median at %.2f h", m / 3600))
	end)

	t.test("showdowns keep tension: 5-30% of waves are lost", function()
		for _, run in runs do
			local lossRate = run.Fails / run.Waves
			t.expect(lossRate > 0.05 and lossRate < 0.3, string.format("loss rate %.3f", lossRate))
		end
	end)

	t.test("doors break on some lost waves but not all of them", function()
		for _, run in runs do
			t.expect(
				run.Breaks > 0 and run.Breaks < run.Fails,
				string.format("breaks %d of %d fails", run.Breaks, run.Fails)
			)
		end
	end)

	t.test("rebirth makes the next climb faster (even before counting kept brainrots)", function()
		local base, reborn = {}, {}
		for seed = 1, 3 do
			table.insert(base, simulate(seed * 7, 10, 0).TierAt[10] or math.huge)
			table.insert(reborn, simulate(seed * 7, 10, 1).TierAt[10] or math.huge)
		end
		t.expect(
			median(reborn) < median(base),
			string.format("reborn %.0fm vs fresh %.0fm", median(reborn) / 60, median(base) / 60)
		)
	end)
end
