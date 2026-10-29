--[[
	CombatService: the one place damage, knockback, stun and KOs are applied.

	Every attack builds a HitSpec and calls applyHit. That keeps blocking, spawn
	protection, safe zones, low-health knockback scaling, KO credit and all of
	the hit feedback (damage numbers, hitmarkers, combo counter) consistent.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local State = require(script.Parent.State)
local World = require(script.Parent.World)

export type HitSpec = {
	damage: number,
	knockback: Vector3?, -- launch velocity before low-health scaling
	ragdoll: number?, -- seconds of tumbling
	stun: number?, -- seconds unable to act
	guardBreak: boolean?, -- ignores and breaks blocks
	heavy: boolean?, -- bigger hit feedback
	noScaling: boolean?, -- exact knockback (pulls), skips low-health scaling
	position: Vector3?, -- where to show the hit (defaults to the victim)
}

local CombatService = {}

local COMBO_WINDOW = 2

local DEATH_VERBS = {
	void = "fell into the void",
	rinse = "got rinsed",
	washout = "was washed away by the storm",
	reset = "reset",
}

-- Spawn protection and the safe zone both make a player untouchable.
function CombatService.isProtected(player: Player): boolean
	local st = State.get(player)
	if st and os.clock() < st.spawnProtectedUntil then
		return true
	end
	local _, _, root = World.alive(player)
	return root ~= nil and Zones.contains(Zones.SAFE, root.Position)
end

function CombatService.canAct(player: Player): boolean
	local st = State.get(player)
	if not st or os.clock() < st.stunUntil then
		return false
	end
	local _, humanoid = World.alive(player)
	return humanoid ~= nil
end

local function isBlockingFrom(victimRoot: BasePart, from: Vector3?): boolean
	if not from then
		return true
	end
	local toAttacker = from - victimRoot.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 0.5 then
		return true
	end
	-- Blocks cover the front half of the character.
	return toAttacker.Unit:Dot(victimRoot.CFrame.LookVector) > -0.1
end

--[[
	Applies a hit from `attacker` (nil for environmental hazards) to `victim`.
	Returns true if the hit landed.
]]
function CombatService.applyHit(attacker: Player?, victim: Player, spec: HitSpec): boolean
	if attacker == victim then
		return false
	end
	local victimState = State.get(victim)
	local _, humanoid, root = World.alive(victim)
	if not victimState or not humanoid or not root then
		return false
	end
	if CombatService.isProtected(victim) then
		return false
	end
	local attackerState = attacker and State.get(attacker)
	local attackerRoot: BasePart? = nil
	if attacker then
		local _, _, aRoot = World.alive(attacker)
		attackerRoot = aRoot
		-- Nobody gets to snipe out of the safe zone.
		if aRoot and Zones.contains(Zones.SAFE, aRoot.Position) then
			return false
		end
		if attackerState then
			-- Attacking ends your own spawn protection.
			attackerState.spawnProtectedUntil = 0
		end
	end

	local now = os.clock()
	local damage = spec.damage
	local knockback = spec.knockback or Vector3.zero
	local ragdoll = spec.ragdoll or 0
	local stun = spec.stun or 0
	local blocked = false

	if victimState.blocking then
		if spec.guardBreak then
			victimState.blocking = false
			if victim.Character then
				victim.Character:SetAttribute("Blocking", false)
			end
			stun += Config.GUARD_BREAK_STUN
			Remotes.Notify:FireClient(victim, "GUARD BROKEN", "guardbreak")
		elseif isBlockingFrom(root, if attackerRoot then attackerRoot.Position else nil) then
			blocked = true
			damage *= Config.BLOCK_DAMAGE_MULT
			knockback *= Config.BLOCK_KNOCKBACK_MULT
			ragdoll = 0
			stun = 0
		end
	end

	damage = math.floor(damage + 0.5)
	local newHealth = math.max(humanoid.Health - damage, 0)
	humanoid.Health = newHealth

	-- Hurt players fly further: the core of ring-outs.
	if not spec.noScaling then
		local missing = 1 - newHealth / math.max(humanoid.MaxHealth, 1)
		local kit = Characters.get(victimState.kit)
		knockback *= (1 + missing * Config.LOW_HP_KNOCKBACK) * kit.knockbackTaken
	end

	victimState.lastDamagedAt = now
	if attacker then
		victimState.lastHitBy = attacker
		victimState.lastHitAt = now
	end
	victimState.stunUntil = math.max(victimState.stunUntil, now + stun + ragdoll)

	if knockback.Magnitude > 1 or stun > 0 or ragdoll > 0 then
		Remotes.Knockback:FireClient(victim, knockback, ragdoll, stun)
	end

	local attackerColor = if attackerState then attackerState.colorId else 0
	Remotes.Hit:FireAllClients(
		victim.Character,
		spec.position or root.Position,
		damage,
		attackerColor,
		spec.heavy == true,
		blocked
	)

	if attacker and attackerState then
		if now - attackerState.comboAt > COMBO_WINDOW then
			attackerState.combo = 0
		end
		attackerState.combo += 1
		attackerState.comboAt = now
		Remotes.HitConfirm:FireClient(attacker, damage, attackerState.combo, newHealth <= 0)
	end
	return true
end

-- Damage with no knockback or feedback (paint ticks, storms). It never counts
-- as a hit, though a KO from it still credits whoever hit the victim last.
function CombatService.drain(victim: Player, amount: number, floor: number?, cause: string?)
	local st = State.get(victim)
	local _, humanoid = World.alive(victim)
	if not st or not humanoid then
		return
	end
	local target = math.max(humanoid.Health - amount, floor or 0)
	if target < humanoid.Health then
		if target <= 0 then
			st.deathCause = cause
		end
		humanoid.Health = target
		st.lastDamagedAt = os.clock()
	end
end

function CombatService.kill(victim: Player, cause: string)
	local st = State.get(victim)
	local _, humanoid = World.alive(victim)
	if st and humanoid then
		st.deathCause = cause
		humanoid.Health = 0
	end
end

local function addStat(player: Player, name: string, delta: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		value.Value += delta
	end
end

local function setStat(player: Player, name: string, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		value.Value = amount
	end
end

-- Called by PlayerService when a character dies.
function CombatService.onDied(victim: Player)
	local st = State.get(victim)
	if not st then
		return
	end
	local now = os.clock()
	local killer = st.lastHitBy
	if killer and (now - st.lastHitAt > Config.KO_CREDIT_WINDOW or killer.Parent ~= Players or killer == victim) then
		killer = nil
	end

	local killerState = killer and State.get(killer)
	if killer and killerState then
		killerState.streak += 1
		addStat(killer, "Splashes", 1)
		setStat(killer, "Streak", killerState.streak)
		local _, killerHumanoid = World.alive(killer)
		if killerHumanoid then
			killerHumanoid.Health = math.min(killerHumanoid.Health + Config.KO_HEAL, killerHumanoid.MaxHealth)
		end
		Remotes.Notify:FireClient(killer, "SPLASHED " .. string.upper(victim.DisplayName), "ko")
		if killerState.streak >= 3 then
			Remotes.Feed:FireAllClients(
				killer.DisplayName,
				killerState.colorId,
				"",
				0,
				"is on a " .. killerState.streak .. " splash streak!"
			)
		end
		Remotes.Feed:FireAllClients(killer.DisplayName, killerState.colorId, victim.DisplayName, st.colorId, "splashed")
	else
		local verb = DEATH_VERBS[st.deathCause or ""] or "was splashed"
		Remotes.Feed:FireAllClients("", 0, victim.DisplayName, st.colorId, verb)
	end

	st.streak = 0
	setStat(victim, "Streak", 0)
	st.lastHitBy = nil
	st.deathCause = nil
end

return CombatService
