--[[
	Helpers shared by every kit: input sanitising and the dash-lane routine
	used by charging skills.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Geometry = require(Shared.Geometry)

local Hitbox = require(script.Parent.Parent.Hitbox)
local PaintService = require(script.Parent.Parent.PaintService)
local State = require(script.Parent.Parent.State)
local World = require(script.Parent.Parent.World)

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
-- The server sees a dashing player slightly late, so keep checking a bit past
-- the dash itself.
local LANE_LAG_GRACE = 0.2

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

--[[
	Follows a dashing player for `duration`, painting a lane under them and
	calling onTarget once per enemy that comes within `radius`. Stops early if
	onTarget returns true ("only the first one").
]]
function Common.lane(
	ctx: Context,
	duration: number,
	radius: number,
	paintRadius: number,
	onTarget: (target: Hitbox.Target, root: BasePart) -> boolean?
)
	local player = ctx.player
	local colorId = ctx.colorId
	local alreadyHit: { [any]: boolean } = {}
	local started = os.clock()
	local lastPaint = 0
	task.spawn(function()
		while os.clock() - started < duration + LANE_LAG_GRACE do
			local _, _, root = World.alive(player)
			if not root then
				return
			end
			local now = os.clock()
			if now - lastPaint >= 0.05 then
				lastPaint = now
				PaintService.splatGround(colorId, root.Position, paintRadius, 6)
			end
			for _, target in Hitbox.sphere(player, root.Position, radius) do
				if not alreadyHit[target.key] then
					alreadyHit[target.key] = true
					if onTarget(target, root) then
						return
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

return Common
