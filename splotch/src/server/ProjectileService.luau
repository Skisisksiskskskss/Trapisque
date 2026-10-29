--[[
	ProjectileService: server-simulated ballistic projectiles.

	The server owns every projectile's flight and decides what it hits. Clients
	get a "Projectile" Fx event at launch and draw the same arc themselves, then a
	"ProjectileEnd" event with the authoritative impact point. The shooter's own
	primary fire is drawn instantly on their client and matched up by shotId.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)

local Hitbox = require(script.Parent.Hitbox)
local World = require(script.Parent.World)

export type Spec = {
	owner: Player,
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	lifetime: number,
	hitRadius: number,
	style: string, -- how clients draw it: "Paint", "Can", "Stencil", "Hook"
	size: number,
	colorId: number,
	shotId: number?,
	onHitCharacter: ((target: Hitbox.Target, position: Vector3, velocity: Vector3) -> ())?,
	onHitSurface: ((result: RaycastResult, velocity: Vector3) -> ())?,
	onExpire: ((position: Vector3) -> ())?,
}

type Projectile = {
	id: number,
	spec: Spec,
	position: Vector3,
	velocity: Vector3,
	age: number,
}

local ProjectileService = {}

local active: { Projectile } = {}
local nextId = 0

local function finish(p: Projectile, position: Vector3, normal: Vector3?, hitCharacter: boolean)
	local spec = p.spec
	Remotes.Fx:FireAllClients(
		"ProjectileEnd",
		p.id,
		spec.owner.UserId,
		spec.shotId or 0,
		position,
		normal or Vector3.new(0, 1, 0),
		spec.style,
		spec.colorId,
		hitCharacter
	)
end

local function step(dt: number)
	for index = #active, 1, -1 do
		local p = active[index]
		local spec = p.spec
		local newVelocity = p.velocity - Vector3.new(0, spec.gravity * dt, 0)
		local delta = (p.velocity + newVelocity) * 0.5 * dt
		local a = p.position
		local b = a + delta
		p.age += dt

		local surface = World.raycastMap(a, delta)
		local surfaceT = if surface then (surface.Position - a).Magnitude / math.max(delta.Magnitude, 1e-6) else math.huge
		local target, targetT = Hitbox.sweep(spec.owner, a, b, spec.hitRadius)

		if target and targetT <= surfaceT then
			table.remove(active, index)
			local position = a + delta * targetT
			finish(p, position, nil, true)
			if spec.onHitCharacter then
				spec.onHitCharacter(target, position, newVelocity)
			end
		elseif surface then
			table.remove(active, index)
			finish(p, surface.Position, surface.Normal, false)
			if spec.onHitSurface then
				spec.onHitSurface(surface, newVelocity)
			end
		elseif p.age >= spec.lifetime then
			table.remove(active, index)
			finish(p, b, nil, false)
			if spec.onExpire then
				spec.onExpire(b)
			end
		else
			p.position = b
			p.velocity = newVelocity
		end
	end
end

function ProjectileService.init()
	RunService.Heartbeat:Connect(step)
end

function ProjectileService.launch(spec: Spec): number
	nextId += 1
	table.insert(active, {
		id = nextId,
		spec = spec,
		position = spec.origin,
		velocity = spec.velocity,
		age = 0,
	})
	Remotes.Fx:FireAllClients(
		"Projectile",
		nextId,
		spec.owner.UserId,
		spec.shotId or 0,
		spec.origin,
		spec.velocity,
		spec.gravity,
		spec.lifetime,
		spec.style,
		spec.size,
		spec.colorId
	)
	return nextId
end

return ProjectileService
