--[[
	Abilities: one per bird, charged by strumming (crossing the middle line).

	UTURN  (Berd)   reverse direction + small hop                    cost 3
	DASH   (Zippy)  0.4 s at 2.6x speed, phases through event hazards cost 3
	BLINK  (Blinky) teleport 130 units against gravity               cost 3
	PUFF   (Puff)   1.5 s spike-proof, but bigger + heavier          cost 4
	PECK   (Pecky)  3 s: first spike touched shatters harmlessly     cost 4
	FOCUS  (Hoot)   3 s at 55% personal speed + flight path preview  cost 4
	HONK   (Honk)   shockwave: pops hazards, shoves rivals (Versus)  cost 5
	FLIP   (Flippy) toggle your own gravity                          cost 3

	The owning machine activates instantly; the server re-validates the charge
	(it counts strums itself) and relays the effect to everyone else.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Birds = require(script.Parent.Parent.Config.Birds)

local H = GameConfig.H

local Abilities = {}

Abilities.DURATION = {
	DASH = 24,
	PUFF = 90,
	PECK = 180,
	FOCUS = 180,
	BLINK = 12, -- brief afterimage / hazard grace
	UTURN = 8,
	HONK = 20,
	FLIP = 10,
}

Abilities.HONK_RADIUS = 170

function Abilities.defFor(bird)
	return Birds.get(bird.kind)
end

function Abilities.kind(bird): string
	return Abilities.defFor(bird).ability
end

function Abilities.cost(bird): number
	return Abilities.defFor(bird).cost
end

function Abilities.isActive(world, bird, kind: string?): boolean
	if world.tick >= bird.abilityUntil then
		return false
	end
	return kind == nil or Abilities.kind(bird) == kind
end

-- Called on every strum
function Abilities.addCharge(bird, amount: number)
	bird.charge = math.min(Abilities.cost(bird), bird.charge + amount)
end

function Abilities.ready(world, bird): boolean
	if bird.dead or world.tick < bird.frozenUntil then
		return false
	end
	if bird.charge < Abilities.cost(bird) then
		return false
	end
	-- duration abilities can't be re-triggered while running
	return world.tick >= bird.abilityUntil
end

-- Personal physics multipliers
function Abilities.mods(world, bird, m)
	if world.tick >= bird.abilityUntil then
		return
	end
	local kind = Abilities.kind(bird)
	if kind == "FOCUS" then
		m.time *= 0.55
	elseif kind == "PUFF" then
		m.gravity *= 1.2
	end
end

function Abilities.speedMult(world, bird): number
	if world.tick < bird.abilityUntil and Abilities.kind(bird) == "DASH" then
		return 2.6
	end
	return 1
end

function Abilities.sizeScale(world, bird): number
	if world.tick < bird.abilityUntil and Abilities.kind(bird) == "PUFF" then
		return 1.35
	end
	return 1
end

-- Event hazards (not spikes) can't touch a dashing / just-blinked bird
function Abilities.ignoresHazards(world, bird): boolean
	if world.tick >= bird.abilityUntil then
		return false
	end
	local kind = Abilities.kind(bird)
	return kind == "DASH" or kind == "BLINK"
end

-- "puff" = spikes harmless while active, "peck" = next spike shatters, nil = normal
function Abilities.spikeGuard(world, bird): string?
	if world.tick >= bird.abilityUntil then
		return nil
	end
	local kind = Abilities.kind(bird)
	if kind == "PUFF" then
		return "puff"
	elseif kind == "PECK" and bird.pecking then
		return "peck"
	end
	return nil
end

--[[
	Apply the ability to a bird we simulate. Returns true if it fired.
	`free` skips the charge check (used when the server replays a validated use).
]]
function Abilities.activate(world, bird, free: boolean?): boolean
	if not free and not Abilities.ready(world, bird) then
		return false
	end
	local kind = Abilities.kind(bird)
	local tick = world.tick
	if not free then
		bird.charge = 0
	end
	bird.abilityUses += 1
	bird.abilityUntil = tick + (Abilities.DURATION[kind] or 10)

	if kind == "UTURN" then
		bird.dir = -bird.dir
		local hop = GameConfig.FLAP * 0.55
		bird.vy = if bird.upside then hop else -hop
	elseif kind == "BLINK" then
		local dist = 130
		bird.y += if bird.upside then dist else -dist
		if bird.y < -bird.radius then
			bird.y += H + bird.radius * 2
		elseif bird.y > H + bird.radius then
			bird.y -= H + bird.radius * 2
		end
		bird.lastWrapTick = tick
	elseif kind == "PECK" then
		bird.pecking = true
	elseif kind == "FLIP" then
		bird.upside = not bird.upside
		bird.vy *= 0.5
	elseif kind == "HONK" then
		-- effects on hazards / rivals are resolved by the match layer
		world:call("onHonk", bird)
	end

	world:fx("ability", { bird = bird, kind = kind })
	return true
end

-- Called each tick for simulated birds to expire one-shot states
function Abilities.tick(world, bird)
	if bird.pecking and world.tick >= bird.abilityUntil then
		bird.pecking = false
	end
end

return Abilities
