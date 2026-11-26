--[[
	ViewKit: helpers shared by the event visual modules.
]]

local Canvas = require(script.Parent.Canvas)

local Kit = {}

Kit.Canvas = Canvas

function Kit.container(parent: Instance, z: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

-- Full-arena background (color or vertical gradient)
function Kit.background(ctx, top: Color3, bottom: Color3?, z: number?): Frame
	local W, H = ctx.W, ctx.H
	local f = Canvas.rect(ctx.back, ctx.space, W / 2, H / 2, W + 4, H + 4, { color = Color3.new(1, 1, 1), z = z or 2 })
	if bottom then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(top, bottom)
		g.Rotation = 90
		g.Parent = f
	else
		f.BackgroundColor3 = top
	end
	return f
end

function Kit.gradient(f: GuiObject, stops: { { number | Color3 } }, rotation: number?)
	local keys = {}
	for _, s in stops do
		table.insert(keys, ColorSequenceKeypoint.new(s[1] :: number, s[2] :: Color3))
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

function Kit.fadeGradient(f: GuiObject, fromAlpha: number, toAlpha: number, rotation: number?)
	local g = f:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(1 - fromAlpha, 1 - toAlpha)
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

--[[
	Keep one GuiObject per entity table in `list` (keyed by table identity).
	make(e) -> GuiObject, update(e, obj) each frame. Objects whose entity left
	the list (or is removed via ev.removed[e.id]) are destroyed.
]]
function Kit.sync(ctx, key: string, list: { any }?, make, update, ev)
	local map = ctx.maps[key]
	if not map then
		map = {}
		ctx.maps[key] = map
	end
	local seen = {}
	if list then
		for _, e in list do
			if ev and e.id and ev.removed[e.id] then
				continue
			end
			seen[e] = true
			local obj = map[e]
			if not obj then
				obj = make(e)
				map[e] = obj
			end
			if update then
				update(e, obj)
			end
		end
	end
	for e, obj in map do
		if not seen[e] then
			obj:Destroy()
			map[e] = nil
		end
	end
end

-- A pool of N frames created once; returns the list
function Kit.pool(_ctx, n: number, make: (i: number) -> GuiObject): { GuiObject }
	local out = {}
	for i = 1, n do
		out[i] = make(i)
	end
	return out
end

function Kit.hex(h: string): Color3
	return Color3.fromHex(h)
end

return Kit
