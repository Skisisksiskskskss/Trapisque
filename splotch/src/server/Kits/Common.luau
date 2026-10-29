--[[
	Helpers shared by every kit: input sanitising and the primary paint shot.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Geometry = require(Shared.Geometry)

local CombatService = require(script.Parent.Parent.CombatService)
local PaintService = require(script.Parent.Parent.PaintService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local State = require(script.Parent.Parent.State)

export type Context = {
	player: Player,
	state: State.PlayerState,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	colorId: number,
	kit: Characters.Character,
}

local Common = {}

local MAX_ORIGIN_OFFSET = 12

-- A finite Vector3 from the network, or nil.
function Common.vector(value: any): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	if value ~= value or value.Magnitude > 1e5 then
		return nil
	end
	return value
end

-- Unit direction from the network, or the character's facing.
function Common.direction(ctx: Context, value: any): Vector3
	local v = Common.vector(value)
	if v and v.Magnitude > 0.5 then
		return v.Unit
	end
	return ctx.root.CFrame.LookVector
end

-- Horizontal unit direction from the network, or the character's facing.
function Common.flatDirection(ctx: Context, value: any): Vector3
	return Geometry.flat(Common.direction(ctx, value), Geometry.flat(ctx.root.CFrame.LookVector))
end

-- Launch point the client asked for, as long as it is near the character.
function Common.origin(ctx: Context, value: any): Vector3
	local v = Common.vector(value)
	if v and (v - ctx.root.Position).Magnitude <= MAX_ORIGIN_OFFSET then
		return v
	end
	return ctx.root.Position + Vector3.new(0, 1.5, 0)
end

function Common.primary(ctx: Context, origin: Vector3, direction: Vector3, shotId: number)
	local def = ctx.kit.primary
	local player = ctx.player
	local colorId = ctx.colorId
	ProjectileService.launch({
		owner = player,
		origin = origin,
		velocity = direction * def.speed,
		gravity = def.gravity,
		lifetime = def.lifetime,
		hitRadius = def.hitRadius,
		style = "Paint",
		size = def.size,
		colorId = colorId,
		shotId = shotId,
		onHitCharacter = function(target, position, velocity)
			CombatService.applyHit(player, target.player, {
				damage = def.damage,
				knockback = Geometry.flat(velocity) * def.knockback,
				position = position,
			})
			PaintService.splatGround(colorId, target.root.Position, def.splatRadius * 0.6, 6)
		end,
		onHitSurface = function(result)
			PaintService.splat(colorId, result.Position, result.Normal, def.splatRadius, result.Instance :: BasePart)
		end,
	})
end

return Common
