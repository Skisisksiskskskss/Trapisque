--[[
	Screenshots of the game running on the fake Roblox. Bundle after
	tests/fake/roblox.luau.

		Fake.shot(name)

	prints everything on screen, in the order Roblox draws it, as one line:
	"@@SHOT <json>". tools/preview/shot.py turns those lines into PNGs, so previews
	show exactly the frames, colours, corners, outlines, gradients and text the game's
	own Lua builds (no second copy of the art to keep in step).

	Each op: { c = class, x, y, w, h, r = rotation, a = group alpha, bg = {r,g,b},
	bt = BackgroundTransparency, cr = corner radius, st = { strokes }, gr = gradient,
	clip = {x0, y0, x1, y1}, text = {...}, img = {...} }, all in screen pixels.
]]

local F = Fake

local function rgb(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function familyName(family: string): string
	return (family:match("families/([%w_]+)%.json") or family:match("([%w_]+)%.json") or family)
end

local function gradientOf(inst)
	for _, c in inst:GetChildren() do
		if c:IsA("UIGradient") and c.Enabled then
			local kps = {}
			for _, k in c.Color.Keypoints do
				table.insert(kps, { k.Time, table.unpack(rgb(k.Value)) })
			end
			local tps = {}
			for _, k in c.Transparency.Keypoints do
				table.insert(tps, { k.Time, k.Value })
			end
			return { c = kps, t = tps, rot = c.Rotation, ox = c.Offset.X, oy = c.Offset.Y }
		end
	end
	return nil
end

local function intersect(a, b)
	if not a then
		return b
	end
	if not b then
		return a
	end
	return { math.max(a[1], b[1]), math.max(a[2], b[2]), math.min(a[3], b[3]), math.min(a[4], b[4]) }
end

local function opFor(inst, alpha: number, clip)
	local pos, size = inst.AbsolutePosition, inst.AbsoluteSize
	local s = F.scaleOf(inst)
	local op = {
		c = inst.ClassName,
		n = inst.Name,
		x = pos.X,
		y = pos.Y,
		w = size.X,
		h = size.Y,
		r = inst.AbsoluteRotation,
		a = alpha,
		bg = rgb(inst.BackgroundColor3),
		bt = inst.BackgroundTransparency,
		clip = clip,
	}
	local strokes = {}
	for _, c in inst:GetChildren() do
		if c:IsA("UICorner") then
			local cr = c.CornerRadius
			op.cr = cr.Scale * math.min(size.X, size.Y) + cr.Offset * s
		elseif c:IsA("UIStroke") and c.Enabled then
			table.insert(strokes, {
				color = rgb(c.Color),
				th = c.Thickness * s,
				t = c.Transparency,
				mode = if c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then "text" else "border",
				gr = gradientOf(c), -- arcs: a ring whose outline is cut by a gradient
			})
		end
	end
	if #strokes > 0 then
		op.st = strokes
	end
	op.gr = gradientOf(inst)
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local text = inst.Text
		if text ~= "" then
			local maxSize = 100
			for _, c in inst:GetChildren() do
				if c:IsA("UITextSizeConstraint") then
					maxSize = c.MaxTextSize
				end
			end
			local face = inst.FontFace
			op.text = {
				s = text,
				rich = inst.RichText,
				font = familyName(face.Family),
				weight = face.Weight.Name,
				size = inst.TextSize * s,
				scaled = inst.TextScaled,
				max = maxSize * s,
				color = rgb(inst.TextColor3),
				t = inst.TextTransparency,
				xa = inst.TextXAlignment.Name,
				ya = inst.TextYAlignment.Name,
				wrap = inst.TextWrapped,
				trunc = inst.TextTruncate.Name,
				lh = inst.LineHeight,
				ls = if inst.TextStrokeTransparency < 1 then { rgb(inst.TextStrokeColor3), inst.TextStrokeTransparency } else nil,
			}
		end
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		op.img = { id = inst.Image, color = rgb(inst.ImageColor3), t = inst.ImageTransparency }
	end
	return op
end

local function childAlpha(inst, alpha: number): number
	if inst:IsA("CanvasGroup") then
		return alpha * (1 - inst.GroupTransparency)
	end
	return alpha
end

local function childClip(inst, clip)
	if inst.ClipsDescendants or inst:IsA("ScrollingFrame") or inst:IsA("CanvasGroup") then
		local p, z = inst.AbsolutePosition, inst.AbsoluteSize
		return intersect(clip, { p.X, p.Y, p.X + z.X, p.Y + z.Y })
	end
	return clip
end

local function visibleKids(inst)
	local kids = {}
	for i, c in inst:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			table.insert(kids, { c, i })
		end
	end
	table.sort(kids, function(a, b)
		if a[1].ZIndex ~= b[1].ZIndex then
			return a[1].ZIndex < b[1].ZIndex
		end
		return a[2] < b[2]
	end)
	return kids
end

-- Sibling ZIndexBehavior: a parent, then its children by ZIndex, each with theirs.
local function walkSibling(inst, alpha: number, clip, ops)
	for _, k in visibleKids(inst) do
		local c = k[1]
		if alpha > 0.004 then
			table.insert(ops, opFor(c, alpha, clip))
		end
		walkSibling(c, childAlpha(c, alpha), childClip(c, clip), ops)
	end
end

-- Global ZIndexBehavior: every element sorted by ZIndex, tree order breaking ties.
local function walkGlobal(gui, ops)
	local all = {}
	local function collect(inst, alpha, clip)
		for _, k in visibleKids(inst) do
			local c = k[1]
			table.insert(all, { c = c, a = alpha, clip = clip, order = #all })
			collect(c, childAlpha(c, alpha), childClip(c, clip))
		end
	end
	collect(gui, 1, nil)
	table.sort(all, function(a, b)
		if a.c.ZIndex ~= b.c.ZIndex then
			return a.c.ZIndex < b.c.ZIndex
		end
		return a.order < b.order
	end)
	for _, e in all do
		if e.a > 0.004 then
			table.insert(ops, opFor(e.c, e.a, e.clip))
		end
	end
end

function F.shot(name: string)
	local player = game:GetService("Players").LocalPlayer
	local pg = player and player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local guis = {}
	for i, g in pg:GetChildren() do
		if g:IsA("LayerCollector") and g.Enabled then
			table.insert(guis, { g, i })
		end
	end
	table.sort(guis, function(a, b)
		if a[1].DisplayOrder ~= b[1].DisplayOrder then
			return a[1].DisplayOrder < b[1].DisplayOrder
		end
		return a[2] < b[2]
	end)
	local ops = {}
	for _, entry in guis do
		local gui = entry[1]
		if gui.ZIndexBehavior == Enum.ZIndexBehavior.Global then
			walkGlobal(gui, ops)
		else
			walkSibling(gui, 1, nil, ops)
		end
	end
	local json = game:GetService("HttpService"):JSONEncode({ name = name, w = F.screen.w, h = F.screen.h, ops = ops })
	F.print("@@SHOT " .. json)
end
