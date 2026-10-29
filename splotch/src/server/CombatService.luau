--[[
	CombatService: the one place damage, knockback, stun, ragdolls and KOs are
	applied, for players and training dummies alike.

	Every attack builds a HitSpec and calls applyHit. That keeps blocking,
	i-frames, wake-up immunity, low-health knockback scaling, the evasive and
	awakening meters, KO credit and all hit feedback consistent.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local Ragdoll = require(script.Parent.Ragdoll)
local State = require(script.Parent.State)
local World = require(script.Parent.World)

export type HitSpec = {
	damage: number,
	knockback: Vector3?, -- launch velocity before low-health scaling
	ragdoll: number?, -- seconds of ragdoll after landing
	stun: number?, -- seconds unable to act
	melee: boolean?, -- M1s and dash jabs: fully blocked, no stun during wake-up immunity
	guardBreak: boolean?, -- breaks blocks
	unblockable: boolean?,
	bypassRagdoll: boolean?, -- can hit someone who is already ragdolled
	heavy: boolean?, -- bigger hit feedback
	noScaling: boolean?, -- exact knockback (pulls), skips low-health scaling
	position: Vector3?, -- where to show the hit (defaults to the victim)
}

local CombatService = {}

local COMBO_WINDOW = 2.5
local GRAVITY = 196.2

local DEATH_VERBS = {
	void = "was rinsed into the sea",
	rinse = "fell in the rinse canal",
	washout = "was washed away by the storm",
}

-- Meters ------------------------------------------------------------------------------

local function syncMeters(st: State.PlayerState)
	if World.isPlayer(st.key) then
		local player = st.key :: Player
		player:SetAttribute("Evasive", math.floor(st.evasive))
		player:SetAttribute("Awakening", math.floor(st.awakening))
	end
end
CombatService.syncMeters = syncMeters

local function lowHealth(key: World.Combatant): boolean
	local _, humanoid = World.alive(key)
	return humanoid ~= nil and humanoid.Health <= humanoid.MaxHealth / 2
end

function CombatService.addEvasiveFromTaken(st: State.PlayerState, damage: number)
	local full = if lowHealth(st.key) then Config.EVASIVE_TAKEN_FULL_LOW else Config.EVASIVE_TAKEN_FULL
	st.evasive = math.min(st.evasive + damage / full * 100, 100)
end

function CombatService.addEvasiveFromDealt(st: State.PlayerState, damage: number)
	local full = if lowHealth(st.key) then Config.EVASIVE_DEALT_FULL_LOW else Config.EVASIVE_DEALT_FULL
	st.evasive = math.min(st.evasive + damage / full * 100, 100)
end

-- Ragdolls -----------------------------------------------------------------------------

local function sendState(key: World.Combatant, kind: string, ...)
	if World.isPlayer(key) then
		Remotes.State:FireClient(key :: Player, kind, ...)
	end
end

function CombatService.isRagdolled(st: State.PlayerState): boolean
	return os.clock() < st.ragdollUntil
end

local function endRagdoll(st: State.PlayerState)
	local character, humanoid = World.alive(st.key)
	st.ragdollUntil = 0
	st.meleeImmuneUntil = os.clock() + Config.WAKEUP_IMMUNITY
	if character then
		Ragdoll.set(character, false)
	end
	if humanoid and not World.isPlayer(st.key) then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	sendState(st.key, "RagdollEnd")
end

local function beginRagdoll(st: State.PlayerState, duration: number)
	local character, humanoid = World.alive(st.key)
	if not character or not humanoid then
		return
	end
	st.ragdollToken += 1
	local token = st.ragdollToken
	st.ragdollUntil = os.clock() + duration
	Ragdoll.set(character, true)
	if not World.isPlayer(st.key) then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	task.delay(duration, function()
		if st.ragdollToken == token and st.ragdollUntil > 0 then
			endRagdoll(st)
		end
	end)
end

-- Ragdoll or stun cancel (JJS "evasive"): needs a full bar.
function CombatService.evasive(key: World.Combatant): boolean
	local st = State.get(key)
	local character = World.alive(key)
	if not st or not character then
		return false
	end
	local now = os.clock()
	local trapped = CombatService.isRagdolled(st) or now < st.stunUntil
	if not trapped or st.evasive < 100 then
		return false
	end
	st.evasive = 0
	st.ragdollToken += 1
	st.stunUntil = 0
	st.invulnerableUntil = now + Config.EVASIVE_IFRAMES
	if st.ragdollUntil > 0 then
		endRagdoll(st)
	end
	syncMeters(st)
	Remotes.Fx:FireAllClients("Evasive", character, st.colorId)
	sendState(key, "Evasive")
	return true
end

-- Movement on hit -------------------------------------------------------------------

local function launch(st: State.PlayerState, velocity: Vector3, ragdoll: number, stun: number)
	if World.isPlayer(st.key) then
		Remotes.Knockback:FireClient(st.key :: Player, velocity, ragdoll, stun)
		return
	end
	-- Dummies are simulated by the server.
	local _, humanoid, root = World.alive(st.key)
	if humanoid and root then
		if ragdoll <= 0 and velocity.Magnitude > 20 then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		root.AssemblyLinearVelocity = velocity
	end
end

-- Protection ------------------------------------------------------------------------

-- Spawn protection, i-frames and the safe zone all make a combatant untouchable.
function CombatService.isProtected(key: World.Combatant): boolean
	local st = State.get(key)
	local now = os.clock()
	if st and (now < st.spawnProtectedUntil or now < st.invulnerableUntil) then
		return true
	end
	local _, _, root = World.alive(key)
	return root ~= nil and World.isPlayer(key) and Zones.contains(Zones.SAFE, root.Position)
end

function CombatService.canAct(key: World.Combatant): boolean
	local st = State.get(key)
	if not st then
		return false
	end
	local now = os.clock()
	if now < st.stunUntil or CombatService.isRagdolled(st) then
		return false
	end
	local _, humanoid = World.alive(key)
	return humanoid ~= nil
end

local function facing(victimRoot: BasePart, from: Vector3?): boolean
	if not from then
		return true
	end
	local toAttacker = from - victimRoot.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 0.5 then
		return true
	end
	return toAttacker.Unit:Dot(victimRoot.CFrame.LookVector) > Config.BLOCK_ARC
end

-- Hits --------------------------------------------------------------------------------

--[[
	Applies a hit from `attacker` (nil for hazards) to `victim`. Returns
	"hit", "blocked" or nil when nothing happened.
]]
function CombatService.applyHit(attacker: World.Combatant?, victim: World.Combatant, spec: HitSpec): string?
	if attacker == victim then
		return nil
	end
	local victimState = State.get(victim)
	local character, humanoid, root = World.alive(victim)
	if not victimState or not character or not humanoid or not root then
		return nil
	end
	if CombatService.isProtected(victim) then
		return nil
	end
	if CombatService.isRagdolled(victimState) and not spec.bypassRagdoll then
		return nil
	end
	local attackerState = if attacker then State.get(attacker) else nil
	local attackerRoot: BasePart? = nil
	if attacker then
		local _, _, aRoot = World.alive(attacker)
		attackerRoot = aRoot
		-- Nobody gets to fight out of the safe zone.
		if aRoot and World.isPlayer(attacker) and Zones.contains(Zones.SAFE, aRoot.Position) then
			return nil
		end
		if attackerState then
			attackerState.spawnProtectedUntil = 0
		end
	end

	local now = os.clock()
	local damage = spec.damage
	local knockback = spec.knockback or Vector3.zero
	local ragdoll = spec.ragdoll or 0
	local stun = spec.stun or 0
	local blocked = false

	if attackerState and State.isAwakened(attackerState) then
		damage *= Config.AWAKEN_DAMAGE_MULT
	end

	if victimState.blocking and not spec.unblockable then
		if spec.guardBreak then
			victimState.blocking = false
			character:SetAttribute("Blocking", false)
			stun += Config.GUARD_BREAK_STUN
			sendState(victim, "GuardBroken")
			Remotes.Fx:FireAllClients("GuardBreak", character, root.Position)
		elseif facing(root, if attackerRoot then attackerRoot.Position else nil) then
			blocked = true
			damage = if spec.melee then 0 else damage * Config.BLOCK_SKILL_DAMAGE_MULT
			knockback *= 0.2
			ragdoll = 0
			stun = 0
		end
	end

	-- Right after getting up, melee can still hurt but can't stun-lock.
	if spec.melee and now < victimState.meleeImmuneUntil then
		stun = 0
	end

	damage = math.floor(damage + 0.5)
	local newHealth = math.max(humanoid.Health - damage, 0)
	humanoid.Health = newHealth

	if not spec.noScaling then
		local missing = 1 - newHealth / math.max(humanoid.MaxHealth, 1)
		local kitName = if World.isPlayer(victim) then victimState.kit else "Tagger"
		knockback *= (1 + missing * Config.LOW_HP_KNOCKBACK) * Characters.get(kitName).knockbackTaken
	end

	if damage > 0 then
		victimState.lastDamagedAt = now
		CombatService.addEvasiveFromTaken(victimState, damage)
		if attackerState then
			CombatService.addEvasiveFromDealt(attackerState, damage)
			if not State.isAwakened(attackerState) then
				attackerState.awakening =
					math.min(attackerState.awakening + damage / Config.AWAKEN_DAMAGE_FULL * 100, 100)
			end
			syncMeters(attackerState)
		end
		syncMeters(victimState)
	end
	if attacker then
		victimState.lastHitBy = attacker :: any
		victimState.lastHitAt = now
	end

	local ragdollTotal = 0
	if ragdoll > 0 and newHealth > 0 then
		-- The ragdoll timer runs after landing, so add the expected airtime.
		local airtime = math.max(knockback.Y, 0) * 2 / GRAVITY
		ragdollTotal = math.min(ragdoll + airtime, Config.MAX_RAGDOLL)
		beginRagdoll(victimState, ragdollTotal)
	end
	victimState.stunUntil = math.max(victimState.stunUntil, now + stun)

	if knockback.Magnitude > 1 or stun > 0 or ragdollTotal > 0 then
		launch(victimState, knockback, ragdollTotal, stun)
	end

	local attackerColor = if attackerState then attackerState.colorId else 0
	Remotes.Hit:FireAllClients(
		character,
		spec.position or root.Position,
		damage,
		attackerColor,
		spec.heavy == true,
		blocked
	)

	if attacker and attackerState and World.isPlayer(attacker) then
		if now - attackerState.comboAt > COMBO_WINDOW then
			attackerState.comboDamage = 0
		end
		attackerState.comboDamage += damage
		attackerState.comboAt = now
		Remotes.HitConfirm:FireClient(attacker :: Player, damage, attackerState.comboDamage, newHealth <= 0, blocked)
	end
	return if blocked then "blocked" else "hit"
end

-- Damage with no knockback or feedback (paint ticks, storms). It never counts
-- as a hit, though a KO from it still credits whoever hit the victim last.
function CombatService.drain(victim: World.Combatant, amount: number, floor: number?, cause: string?)
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

function CombatService.heal(key: World.Combatant, amount: number)
	local _, humanoid = World.alive(key)
	if humanoid then
		humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
	end
end

function CombatService.kill(victim: World.Combatant, cause: string)
	local st = State.get(victim)
	local _, humanoid = World.alive(victim)
	if st and humanoid then
		st.deathCause = cause
		humanoid.Health = 0
	end
end

-- Awakening ---------------------------------------------------------------------------

function CombatService.awaken(key: World.Combatant): boolean
	local st = State.get(key)
	local character = World.alive(key)
	if not st or not character or st.awakening < 100 or State.isAwakened(st) then
		return false
	end
	local now = os.clock()
	st.awakening = 0
	st.awakenedUntil = now + Config.AWAKEN_DURATION
	st.invulnerableUntil = math.max(st.invulnerableUntil, now + Config.AWAKEN_IFRAMES)
	CombatService.heal(key, Config.AWAKEN_HEAL)
	character:SetAttribute("Awakened", true)
	if World.isPlayer(key) then
		(key :: Player):SetAttribute("AwakenEnds", workspace:GetServerTimeNow() + Config.AWAKEN_DURATION)
	end
	syncMeters(st)
	Remotes.Fx:FireAllClients("Awaken", character, st.colorId)
	task.delay(Config.AWAKEN_DURATION, function()
		if character.Parent and os.clock() >= st.awakenedUntil - 0.05 then
			character:SetAttribute("Awakened", false)
		end
	end)
	return true
end

-- KOs ---------------------------------------------------------------------------------

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

-- Called when a combatant's humanoid dies.
function CombatService.onDied(victim: World.Combatant)
	local st = State.get(victim)
	if not st then
		return
	end
	st.ragdollToken += 1
	local character = World.characterOf(victim)
	if character then
		Ragdoll.set(character, true)
	end
	if not World.isPlayer(victim) then
		return
	end
	local player = victim :: Player
	local now = os.clock()
	local killer = st.lastHitBy
	if
		killer
		and (
			now - st.lastHitAt > Config.KO_CREDIT_WINDOW
			or not World.isPlayer(killer)
			or (killer :: Player).Parent ~= Players
			or killer == player
		)
	then
		killer = nil
	end

	local killerState = if killer then State.get(killer) else nil
	if killer and killerState then
		local killerPlayer = killer :: Player
		killerState.streak += 1
		killerState.evasive = 100
		addStat(killerPlayer, "Kills", 1)
		setStat(killerPlayer, "Streak", killerState.streak)
		CombatService.heal(killerPlayer, Config.KO_HEAL)
		syncMeters(killerState)
		Remotes.Notify:FireClient(killerPlayer, "SPLASHED " .. string.upper(player.DisplayName), "ko")
		Remotes.Feed:FireAllClients(
			killerPlayer.DisplayName,
			killerState.colorId,
			player.DisplayName,
			st.colorId,
			"splashed"
		)
		if killerState.streak >= 3 then
			Remotes.Feed:FireAllClients(
				killerPlayer.DisplayName,
				killerState.colorId,
				"",
				0,
				"is on a " .. killerState.streak .. " splash streak!"
			)
		end
	else
		local verb = DEATH_VERBS[st.deathCause or ""] or "was splashed"
		Remotes.Feed:FireAllClients("", 0, player.DisplayName, st.colorId, verb)
	end

	st.streak = 0
	setStat(player, "Streak", 0)
	st.lastHitBy = nil
	st.deathCause = nil
end

return CombatService
