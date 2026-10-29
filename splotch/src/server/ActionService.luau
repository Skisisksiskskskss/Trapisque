--[[
	ActionService: validates every player input that arrives over Remotes.Action
	and routes it to the right system. Clients predict their own movement,
	animations and hit detection; the server decides whether things happened.

	Actions
		M1(step, variant)            start a swing of the 4-hit chain
		M1Hit(step, characters)      the swing's hitbox touched these characters
		Dash(kind, animation)        "Front" or "Side"
		DashHit(character, early)    a front dash's jab connected
		Evasive()                    break out of a ragdoll or stun (full bar)
		Awaken()                     use a full awakening bar
		Skill(slot, payload) / SkillEvent(slot, name, data)
		Block(bool) / Form(name) / SelectKit(name)
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local PaintService = require(script.Parent.PaintService)
local PlayerService = require(script.Parent.PlayerService)
local State = require(script.Parent.State)
local World = require(script.Parent.World)
local Common = require(script.Parent.Kits.Common)

local KITS = {
	Tagger = require(script.Parent.Kits.Tagger),
	Plaster = require(script.Parent.Kits.Plaster),
}

-- Cooldowns are enforced with a little slack so honest players on high ping
-- never get their inputs eaten.
local LATENCY_SLACK = 0.12
local KIT_SWITCH_COMBAT_LOCK = 5
local M1_HIT_WINDOW = 0.75 -- a swing's hit report must arrive this soon after it started
local M1_CHAIN_SLACK = 0.35
local M1_MAX_TARGETS = 4
local MELEE_RANGE_SLACK = 6 -- extra distance allowed for latency
local FORMS = { Normal = true, Swim = true, WallSwim = true }
local VARIANTS = { Neutral = true, Uppercut = true, Downslam = true }
local DASH_ANIMATIONS = { DashFront = true, DashLeft = true, DashRight = true, DashBack = true }

local ActionService = {}

local function context(player: Player): Common.Context?
	local st = State.get(player)
	local character, humanoid, root = World.alive(player)
	if not st or not character or not humanoid or not root then
		return nil
	end
	return {
		player = player,
		state = st,
		character = character,
		humanoid = humanoid,
		root = root,
		colorId = st.colorId,
		kit = Characters.get(st.kit),
	}
end

local function setForm(ctx: Common.Context, form: string)
	ctx.state.form = form
	ctx.character:SetAttribute("Form", form)
end

local function setBlocking(ctx: Common.Context, blocking: boolean)
	ctx.state.blocking = blocking
	ctx.character:SetAttribute("Blocking", blocking)
end

local function surface(ctx: Common.Context)
	if ctx.state.form ~= "Normal" then
		setForm(ctx, "Normal")
	end
end

-- Plays an animation on everyone else's screen (the sender already played it).
local function broadcastAnimation(ctx: Common.Context, animation: string)
	Remotes.Fx:FireAllClients("Anim", ctx.character, animation, ctx.player.UserId)
end

local function cooldownScale(st: State.PlayerState): number
	return if State.isAwakened(st) then Config.AWAKEN_COOLDOWN_MULT else 1
end

local handlers: { [string]: (Common.Context, ...any) -> () } = {}

-- M1 chain ---------------------------------------------------------------------------

function handlers.M1(ctx, step, variant)
	local st = ctx.state
	local now = os.clock()
	if typeof(step) ~= "number" or not CombatService.canAct(ctx.player) or st.blocking then
		return
	end
	if now < st.m1ReadyAt - LATENCY_SLACK then
		return
	end
	-- The client counts the chain itself; accept its step when it is plausible
	-- (a restart, or the next hit within the reset window plus latency) so
	-- jitter near the reset boundary never desyncs the two.
	local continuing = st.m1Step < 4 and now - st.m1At <= Config.M1_CHAIN_RESET + M1_CHAIN_SLACK
	local expected = if step == 1 or (continuing and step == st.m1Step + 1)
		then step
		elseif continuing then st.m1Step + 1
		else 1
	st.m1Step = expected
	st.m1At = now
	st.m1Hit = false
	st.m1Variant = if expected == 4 and typeof(variant) == "string" and VARIANTS[variant] then variant else "Neutral"
	st.m1ReadyAt = now + (if expected == 4 then Config.M1_CHAIN_COOLDOWN else Config.M1_INTERVAL)
	surface(ctx)

	local animation = ctx.kit.weapon .. (if expected == 4 then st.m1Variant else "M1_" .. expected)
	broadcastAnimation(ctx, animation)
	Remotes.Fx:FireAllClients("Swing", ctx.character, ctx.kit.weapon, expected, ctx.colorId)
	task.delay(Config.M1_STARTUP, function()
		local _, _, root = World.alive(ctx.player)
		if root then
			PaintService.splatInFront(ctx.colorId, root, Config.SWING_SPLAT_RADIUS)
		end
	end)
end

local function m1Spec(st: State.PlayerState, step: number, look: Vector3): CombatService.HitSpec
	local spec: CombatService.HitSpec = { damage = Config.M1_DAMAGE[step], melee = true }
	if step < 4 then
		spec.stun = Config.M1_STUN
		spec.knockback = look * 8
		return spec
	end
	local finisher = Config.M1_FINISHER[st.m1Variant]
	spec.knockback = look * finisher.knockback + Vector3.new(0, finisher.up, 0)
	spec.ragdoll = finisher.ragdoll
	spec.heavy = true
	if st.m1Variant == "Downslam" then
		spec.unblockable = true
		spec.bypassRagdoll = true
	end
	return spec
end

function handlers.M1Hit(ctx, _step, characters)
	local st = ctx.state
	local now = os.clock()
	if st.m1Step == 0 or st.m1Hit or now - st.m1At > M1_HIT_WINDOW or typeof(characters) ~= "table" then
		return
	end
	st.m1Hit = true
	local step = st.m1Step
	local look = ctx.root.CFrame.LookVector
	local maxDistance = Config.M1_REACH + Config.M1_HITBOX.Z / 2 + MELEE_RANGE_SLACK
	local blockedAny = false
	for index, character in characters do
		if index > M1_MAX_TARGETS then
			break
		end
		local victim = World.combatantFromCharacter(character)
		local victimRoot = World.rootOf(victim)
		if victim and victim ~= ctx.player and victimRoot then
			if (victimRoot.Position - ctx.root.Position).Magnitude <= maxDistance then
				local result = CombatService.applyHit(ctx.player, victim, m1Spec(st, step, look))
				if result == "blocked" then
					blockedAny = true
				elseif result == "hit" then
					PaintService.splatGround(ctx.colorId, victimRoot.Position, Config.HIT_SPLAT_RADIUS, 6)
				end
			end
		end
	end
	if blockedAny then
		st.m1ReadyAt = math.max(st.m1ReadyAt, now + Config.M1_BLOCKED_ENDLAG)
	end
end

-- Dashes -----------------------------------------------------------------------------

function handlers.Dash(ctx, kind, animation)
	local st = ctx.state
	local now = os.clock()
	if kind ~= "Front" and kind ~= "Side" then
		return
	end
	if CombatService.isRagdolled(st) then
		return
	end
	if kind == "Front" then
		if now < st.frontDashReadyAt - LATENCY_SLACK then
			return
		end
		st.frontDashReadyAt = now + Config.FRONT_DASH_COOLDOWN
		st.frontDashAt = now
		st.frontDashHit = false
	else
		if now < st.sideDashReadyAt - LATENCY_SLACK then
			return
		end
		st.sideDashReadyAt = now + Config.SIDE_DASH_COOLDOWN
	end
	surface(ctx)
	if typeof(animation) == "string" and DASH_ANIMATIONS[animation] then
		broadcastAnimation(ctx, animation)
	end
	Remotes.Fx:FireAllClients("Dash", ctx.character, ctx.colorId)
end

function handlers.DashHit(ctx, character, early)
	local st = ctx.state
	if st.frontDashHit or os.clock() - st.frontDashAt > Config.FRONT_DASH_TIME + 0.35 then
		return
	end
	local victim = World.combatantFromCharacter(character)
	local victimRoot = World.rootOf(victim)
	if not victim or victim == ctx.player or not victimRoot then
		return
	end
	if (victimRoot.Position - ctx.root.Position).Magnitude > 6 + MELEE_RANGE_SLACK then
		return
	end
	st.frontDashHit = true
	local look = ctx.root.CFrame.LookVector
	local spec: CombatService.HitSpec = { damage = Config.FRONT_DASH_DAMAGE, melee = true }
	if early == true then
		-- Caught early in the dash: knocked flying.
		spec.knockback = look * 45 + Vector3.new(0, 25, 0)
		spec.ragdoll = 0.8
		spec.heavy = true
	else
		spec.stun = Config.M1_STUN
		spec.knockback = look * 6
	end
	CombatService.applyHit(ctx.player, victim, spec)
end

-- Meters ------------------------------------------------------------------------------

function handlers.Evasive(ctx)
	CombatService.evasive(ctx.player)
end

function handlers.Awaken(ctx)
	if CombatService.awaken(ctx.player) then
		broadcastAnimation(ctx, "Awaken")
	end
end

-- Skills -------------------------------------------------------------------------------

function handlers.Skill(ctx, slot, payload)
	local st = ctx.state
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > #ctx.kit.skills then
		return
	end
	if st.blocking or not CombatService.canAct(ctx.player) then
		return
	end
	local now = os.clock()
	if now < st.skillReadyAt[slot] - LATENCY_SLACK then
		return
	end
	local skill = ctx.kit.skills[slot]
	st.skillReadyAt[slot] = now + skill.cooldown * cooldownScale(st)
	st.spawnProtectedUntil = 0
	surface(ctx)
	broadcastAnimation(ctx, skill.animation)
	local kit = KITS[ctx.kit.name]
	kit[slot](ctx, if typeof(payload) == "table" then payload else {})
end

function handlers.SkillEvent(ctx, slot, eventName, data)
	local kit = KITS[ctx.kit.name]
	local events = kit.events
	if typeof(slot) ~= "number" or typeof(eventName) ~= "string" or not events or not events[eventName] then
		return
	end
	events[eventName](ctx, data)
end

-- Stances ------------------------------------------------------------------------------

function handlers.Block(ctx, wantsBlock)
	if wantsBlock == true and CombatService.canAct(ctx.player) then
		setBlocking(ctx, true)
		surface(ctx)
	else
		setBlocking(ctx, false)
	end
end

function handlers.Form(ctx, form)
	if typeof(form) ~= "string" or not FORMS[form] then
		return
	end
	if form ~= "Normal" and ctx.state.blocking then
		return
	end
	setForm(ctx, form)
end

local function selectKit(player: Player, kitName: any)
	local st = State.get(player)
	if not st or typeof(kitName) ~= "string" or not Characters.DEFS[kitName] then
		return
	end
	local _, humanoid = World.alive(player)
	if humanoid and os.clock() - st.lastDamagedAt < KIT_SWITCH_COMBAT_LOCK then
		Remotes.Notify:FireClient(player, "Can't switch characters mid-fight", "error")
		return
	end
	st.kit = kitName
	player:SetAttribute("Kit", kitName)
	PlayerService.respawn(player)
end

function ActionService.init()
	Remotes.Action.OnServerEvent:Connect(function(player, action, ...)
		if typeof(action) ~= "string" then
			return
		end
		-- Picking a character is allowed while dead; breaking out of a ragdoll
		-- happens while you can't otherwise act.
		if action == "SelectKit" then
			selectKit(player, ...)
			return
		end
		local handler = handlers[action]
		local ctx = handler and context(player)
		if handler and ctx then
			handler(ctx, ...)
		end
	end)
end

return ActionService
