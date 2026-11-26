--[[
	EventViews: the look of every event. Each event name maps to
	{ build(ctx, world, ev), update(ctx, world, ev, now, frames) } defined in the
	group modules. The registry adds the event banner and testing countdown.

	ctx: view (ArenaView), space, W, H, rng, back/mid/over containers, maps, data
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Kit = require(script.Parent.ViewKit)

local EventViews = {}

local REG = {}
for _, mod in { script.Screens, script.HazardViews, script.SceneViews } do
	for name, def in require(mod) do
		REG[name] = def
	end
end
EventViews.REG = REG

function EventViews.create(view, world, ev)
	local def = REG[ev.name]
	local ctx = {
		view = view,
		space = view.space,
		W = GameConfig.W,
		H = GameConfig.H,
		rng = Random.new(ev.seed % 2147483647),
		back = Kit.container(view.layers.eventBack, 2),
		mid = Kit.container(view.layers.hazards, 12),
		over = Kit.container(view.layers.overlay, 40),
		maps = {},
		data = {},
	}
	if def and def.build then
		local ok, err = pcall(def.build, ctx, world, ev)
		if not ok then
			warn("[EventViews] build " .. ev.name .. ": " .. tostring(err))
		end
	end

	local handle = {}
	local meta = ev.meta
	local color = Color3.fromHex(meta.color)
	if meta.color == "#000000" or meta.color == "#2d3436" or meta.color == "#2c3e50" then
		color = Color3.fromHex("#333344")
	end

	function handle.update(_self, w, e, now, frames)
		if def and def.update then
			local ok, err = pcall(def.update, ctx, w, e, now, frames)
			if not ok and not ctx.warned then
				ctx.warned = true
				warn("[EventViews] update " .. e.name .. ": " .. tostring(err))
			end
		end
		-- banner: fades during the last second of timed events
		local alpha = 1
		if not meta.openEnded then
			local remaining = e.endTick - w.tick
			alpha = math.clamp(remaining / 60, 0.2, 1)
		end
		local text = if view.showEventText == false then "" else meta.display
		view:setBanner(text, color, alpha, view.opts.couch == true)
		-- testing-powers countdown
		if w.tick < w.testPhaseUntil then
			local remaining = math.ceil((w.testPhaseUntil - w.tick) / 60)
			local pulse = 1 + math.sin(now * 10) * 0.1
			view:setCenter(tostring(remaining), "TESTING POWERS", pulse)
			ctx.showedTest = true
		elseif ctx.showedTest then
			ctx.showedTest = false
			view:setCenter("", nil)
		end
	end

	function handle.destroy(_self)
		if def and def.destroy then
			pcall(def.destroy, ctx)
		end
		ctx.back:Destroy()
		ctx.mid:Destroy()
		ctx.over:Destroy()
		view:setBanner("", nil, 0, false)
		if ctx.showedTest then
			view:setCenter("", nil)
		end
		view:setLineStyle("normal")
		view.page.Position = UDim2.fromScale(0.5, 0.5)
	end

	return handle
end

return EventViews
