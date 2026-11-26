--[[
	Item events: every bird gets an item it keeps until it takes damage
	(original rule). The items themselves are implemented in Physics/Projectiles.
]]

return {
	{
		name = "ROCKET_BOOTS",
		applyBird = function(_w, _ev, bird)
			bird.rocketBoots = true
		end,
	},
	{
		name = "SPEED_BOOTS",
		applyBird = function(_w, _ev, bird)
			bird.speedBoots = true
		end,
	},
	{
		name = "HOVER_DRONE",
		applyBird = function(_w, _ev, bird)
			bird.hoverDrone = true
		end,
	},
	{
		name = "GRAVITY_SHOE",
		applyBird = function(_w, _ev, bird)
			bird.gravityShoe = true
		end,
	},
	{
		-- flapping fires eggs (see Projectiles); kept until hit
		name = "BLASTERS",
		applyBird = function(_w, _ev, bird)
			bird.gun = true
		end,
	},
}
