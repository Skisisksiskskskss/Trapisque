--[[
	ActionService: validates every player input that arrives over Remotes.Action
	and routes it to the right system. Clients predict their own movement and
	effects; the server decides whether the action actually happened.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
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
local FORMS = { Normal = true, Swim = true, WallSwim = true }

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

local handlers: { [string]: (Common.Context, ...any) -> () } = {}

function handlers.Primary(ctx, origin, direction, shotId)
	local st = ctx.state
	local def = ctx.kit.primary
	local now = os.clock()
	if typeof(shotId) ~= "number" or not CombatService.canAct(ctx.player) then
		return
	end
	if st.blocking or now < st.nextPrimaryAt - LATENCY_SLACK or st.paint < def.cost then
		return
	end
	st.nextPrimaryAt = now + def.cooldown
	st.paint -= def.cost
	-- Firing always surfaces you from a dive.
	if st.form ~= "Normal" then
		setForm(ctx, "Normal")
	end
	Common.primary(ctx, Common.origin(ctx, origin), Common.direction(ctx, direction), shotId)
end

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
	st.skillReadyAt[slot] = now + ctx.kit.skills[slot].cooldown
	st.spawnProtectedUntil = 0
	if st.form ~= "Normal" then
		setForm(ctx, "Normal")
	end
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

function handlers.Dash(ctx)
	local st = ctx.state
	local now = os.clock()
	if now < st.dashReadyAt - LATENCY_SLACK or not CombatService.canAct(ctx.player) then
		return
	end
	st.dashReadyAt = now + Config.DASH_COOLDOWN
	Remotes.Fx:FireAllClients("Dash", ctx.character, ctx.colorId)
end

function handlers.Block(ctx, wantsBlock)
	if wantsBlock == true and CombatService.canAct(ctx.player) then
		setBlocking(ctx, true)
		if ctx.state.form ~= "Normal" then
			setForm(ctx, "Normal")
		end
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
	player:LoadCharacter()
end

function ActionService.init()
	Remotes.Action.OnServerEvent:Connect(function(player, action, ...)
		if typeof(action) ~= "string" then
			return
		end
		-- Picking a character is allowed while dead.
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
