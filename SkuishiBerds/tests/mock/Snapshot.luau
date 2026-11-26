--!nocheck
--[[
	Snapshot: paints a player's PlayerGui as an HTML page (approximate Roblox
	rendering) so the UI can be looked at without Roblox Studio.

	Layout follows Roblox rules: Size/Position as scale+offset of the parent,
	AnchorPoint, UIPadding, UIListLayout, UIGridLayout, UISizeConstraint,
	UIAspectRatioConstraint, AutomaticSize, ZIndex (sibling mode), Rotation
	(children rotate with their parent), ClipsDescendants, CanvasGroup.
	Painting: background colors/transparency, UICorner, UIStroke, UIGradient,
	TextScaled text with UITextSizeConstraint, text strokes. Images are drawn
	as placeholders (asset ids can't be fetched here).
]]

local Snapshot = {}

local Enum
local TOP_INSET = 58 -- Roblox top bar height for ScreenGuis that don't ignore the inset

local function child(inst, cls)
	for _, c in inst:GetChildren() do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end

local function enabledChild(inst, cls)
	for _, c in inst:GetChildren() do
		if c.ClassName == cls and (c.ClassName ~= "UIStroke" and c.ClassName ~= "UIGradient" or c.Enabled) then
			return c
		end
	end
	return nil
end

local GUI = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	CanvasGroup = true,
	ViewportFrame = true,
}

local function rgba(c, transparency)
	return string.format(
		"rgba(%d,%d,%d,%.3f)",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5),
		math.clamp(1 - (transparency or 0), 0, 1)
	)
end

local function esc(s)
	return (string.gsub(s, '[<>&"]', { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;" }))
end

-- Roblox RichText subset -> HTML (everything else stays escaped)
local function richText(text)
	local out = esc(text)
	for _, tag in { "b", "i", "u", "s" } do
		out = string.gsub(out, "&lt;" .. tag .. "&gt;", "<" .. tag .. ">")
		out = string.gsub(out, "&lt;/" .. tag .. "&gt;", "</" .. tag .. ">")
	end
	out = string.gsub(out, "&lt;br%s*/?&gt;", "<br>")
	out = string.gsub(out, "&lt;font color=&quot;(#?%w+)&quot;&gt;", '<span style="color:%1">')
	out = string.gsub(out, "&lt;font [^&]-&gt;", "<span>")
	out = string.gsub(out, "&lt;/font&gt;", "</span>")
	return out
end

local function px(v)
	return string.format("%.1fpx", v)
end

-- size of a GuiObject inside a parent content box of pw x ph
local function sizeOf(inst, pw, ph)
	local s = inst.Size
	local w = pw * s.X.Scale + s.X.Offset
	local h = ph * s.Y.Scale + s.Y.Offset
	local sc = child(inst, "UISizeConstraint")
	if sc then
		w = math.clamp(w, sc.MinSize.X, math.max(sc.MinSize.X, sc.MaxSize.X))
		h = math.clamp(h, sc.MinSize.Y, math.max(sc.MinSize.Y, sc.MaxSize.Y))
	end
	local ar = child(inst, "UIAspectRatioConstraint")
	if ar and h > 0 and w > 0 then
		local ratio = ar.AspectRatio
		if ar.AspectType == Enum.AspectType.ScaleWithParentSize then
			if ar.DominantAxis == Enum.DominantAxis.Height then
				w = h * ratio
			else
				h = w / ratio
			end
		elseif w / h > ratio then
			w = h * ratio
		else
			h = w / ratio
		end
	end
	return math.max(0, w), math.max(0, h)
end

local function padding(inst, w, h)
	local p = child(inst, "UIPadding")
	if not p then
		return 0, 0, 0, 0
	end
	return w * p.PaddingLeft.Scale + p.PaddingLeft.Offset,
		w * p.PaddingRight.Scale + p.PaddingRight.Offset,
		h * p.PaddingTop.Scale + p.PaddingTop.Offset,
		h * p.PaddingBottom.Scale + p.PaddingBottom.Offset
end

local function sortedKids(inst, layout)
	local kids = {}
	for i, c in inst:GetChildren() do
		if GUI[c.ClassName] and c.Visible then
			table.insert(kids, { inst = c, i = i })
		end
	end
	if layout and layout.SortOrder == Enum.SortOrder.Name then
		table.sort(kids, function(a, b)
			return a.inst.Name < b.inst.Name
		end)
	elseif layout then
		table.sort(kids, function(a, b)
			if a.inst.LayoutOrder ~= b.inst.LayoutOrder then
				return a.inst.LayoutOrder < b.inst.LayoutOrder
			end
			return a.i < b.i
		end)
	end
	return kids
end

local applyAutomaticSize

-- children boxes relative to the parent's top-left: { inst, x, y, w, h }, plus content height
local function layoutChildren(inst, w, h)
	local pl, pr, pt, pb = padding(inst, w, h)
	local cw, ch = math.max(0, w - pl - pr), math.max(0, h - pt - pb)
	local list = child(inst, "UIListLayout")
	local grid = child(inst, "UIGridLayout")
	local out = {}
	local extent = 0
	if list then
		local horizontal = list.FillDirection == Enum.FillDirection.Horizontal
		local gap = if horizontal
			then cw * list.Padding.Scale + list.Padding.Offset
			else ch * list.Padding.Scale + list.Padding.Offset
		local items, total = {}, 0
		for _, k in sortedKids(inst, list) do
			local kw, kh = applyAutomaticSize(k.inst, sizeOf(k.inst, cw, ch))
			table.insert(items, { k.inst, kw, kh })
			total += if horizontal then kw else kh
		end
		total += gap * math.max(0, #items - 1)
		local start = 0
		if horizontal then
			if list.HorizontalAlignment == Enum.HorizontalAlignment.Center then
				start = (cw - total) / 2
			elseif list.HorizontalAlignment == Enum.HorizontalAlignment.Right then
				start = cw - total
			end
		else
			if list.VerticalAlignment == Enum.VerticalAlignment.Center then
				start = (ch - total) / 2
			elseif list.VerticalAlignment == Enum.VerticalAlignment.Bottom then
				start = ch - total
			end
		end
		local pos = start
		for _, it in items do
			local k, kw, kh = it[1], it[2], it[3]
			local x, y
			if horizontal then
				x = pos
				pos += kw + gap
				y = if list.VerticalAlignment == Enum.VerticalAlignment.Center
					then (ch - kh) / 2
					elseif list.VerticalAlignment == Enum.VerticalAlignment.Bottom then ch - kh
					else 0
			else
				y = pos
				pos += kh + gap
				x = if list.HorizontalAlignment == Enum.HorizontalAlignment.Center
					then (cw - kw) / 2
					elseif list.HorizontalAlignment == Enum.HorizontalAlignment.Right then cw - kw
					else 0
			end
			table.insert(out, { inst = k, x = pl + x, y = pt + y, w = kw, h = kh })
		end
		extent = pt + math.max(0, start) + total + pb
	elseif grid then
		local cellW = cw * grid.CellSize.X.Scale + grid.CellSize.X.Offset
		local cellH = ch * grid.CellSize.Y.Scale + grid.CellSize.Y.Offset
		local gx = cw * grid.CellPadding.X.Scale + grid.CellPadding.X.Offset
		local gy = ch * grid.CellPadding.Y.Scale + grid.CellPadding.Y.Offset
		local cols = math.max(1, math.floor((cw + gx) / math.max(1, cellW + gx)))
		if grid.FillDirectionMaxCells > 0 then
			cols = math.min(cols, grid.FillDirectionMaxCells)
		end
		local kids = sortedKids(inst, grid)
		local used = math.min(cols, #kids)
		local blockW = used * cellW + math.max(0, used - 1) * gx
		local ox = 0
		if grid.HorizontalAlignment == Enum.HorizontalAlignment.Center then
			ox = (cw - blockW) / 2
		elseif grid.HorizontalAlignment == Enum.HorizontalAlignment.Right then
			ox = cw - blockW
		end
		local rows = 0
		for i, k in kids do
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			rows = row + 1
			table.insert(
				out,
				{ inst = k.inst, x = pl + ox + col * (cellW + gx), y = pt + row * (cellH + gy), w = cellW, h = cellH }
			)
		end
		extent = pt + rows * (cellH + gy) - (if rows > 0 then gy else 0) + pb
	else
		for _, k in sortedKids(inst, nil) do
			local c = k.inst
			local kw, kh = applyAutomaticSize(c, sizeOf(c, cw, ch))
			local pos, a = c.Position, c.AnchorPoint
			local x = pl + cw * pos.X.Scale + pos.X.Offset - a.X * kw
			local y = pt + ch * pos.Y.Scale + pos.Y.Offset - a.Y * kh
			table.insert(out, { inst = c, x = x, y = y, w = kw, h = kh })
			extent = math.max(extent, y + kh + pb)
		end
	end
	return out, extent
end

local FONTS = {
	FredokaOne = "'Fredoka One','Fredoka','Arial Rounded MT Bold','Trebuchet MS',sans-serif",
	PatrickHand = "'Patrick Hand','Comic Sans MS',cursive",
	GothamSSm = "'Montserrat','Gotham','Helvetica Neue',Arial,sans-serif",
	Montserrat = "'Montserrat',Arial,sans-serif",
	BuilderSans = "'Nunito Sans','Helvetica Neue',Arial,sans-serif",
	SourceSansPro = "'Source Sans Pro',Arial,sans-serif",
	LuckiestGuy = "'Luckiest Guy','Impact',sans-serif",
	Bangers = "'Bangers','Impact',sans-serif",
	Arial = "Arial,sans-serif",
}
local WEIGHTS = {
	Thin = 100,
	ExtraLight = 200,
	Light = 300,
	Regular = 400,
	Medium = 500,
	SemiBold = 600,
	Bold = 700,
	ExtraBold = 800,
	Heavy = 900,
}

local function fontCss(inst)
	local ok, face = pcall(function()
		return inst.FontFace
	end)
	local family, weight = "FredokaOne", 400
	if ok and face then
		family = string.match(face.Family, "families/([%w]+)%.json") or family
		weight = WEIGHTS[face.Weight.Name] or 400
	end
	return string.format("font-family:%s;font-weight:%d;", FONTS[family] or ("'" .. family .. "',sans-serif"), weight)
end

local function lineCount(text, size, w, wrapped)
	local count = 0
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		local width = utf8.len(line) or #line
		width *= size * 0.52
		count += if wrapped and w > 0 then math.max(1, math.ceil(width / w)) else 1
	end
	return count
end

local function textSize(inst, w, h)
	if not inst.TextScaled then
		return inst.TextSize
	end
	local maxSize, minSize = 100, 1
	local tsc = child(inst, "UITextSizeConstraint")
	if tsc then
		maxSize, minSize = tsc.MaxTextSize, tsc.MinTextSize
	end
	local text = inst.Text
	local best = minSize
	for size = math.floor(maxSize), math.max(1, minSize), -1 do
		local lines = lineCount(text, size, w, true)
		local widest = 0
		for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
			widest = math.max(widest, (utf8.len(line) or #line) * size * 0.52)
		end
		if lines * size * 1.15 <= h + 0.5 and (lines > 1 or widest <= w + 0.5) then
			best = size
			break
		end
	end
	return best
end

-- color/transparency sequences sampled at the union of their keypoint times
local function gradientCss(g, baseColor, baseTransparency, angleOffset)
	local times = {}
	local seen = {}
	for _, kp in g.Color.Keypoints do
		if not seen[kp.Time] then
			seen[kp.Time] = true
			table.insert(times, kp.Time)
		end
	end
	for _, kp in g.Transparency.Keypoints do
		if not seen[kp.Time] then
			seen[kp.Time] = true
			table.insert(times, kp.Time)
		end
	end
	table.sort(times)
	local function sampleColor(t)
		local kps = g.Color.Keypoints
		for i = 1, #kps - 1 do
			local a, b = kps[i], kps[i + 1]
			if t >= a.Time and t <= b.Time then
				local k = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
				return a.Value:Lerp(b.Value, k)
			end
		end
		return kps[#kps].Value
	end
	local function sampleT(t)
		local kps = g.Transparency.Keypoints
		for i = 1, #kps - 1 do
			local a, b = kps[i], kps[i + 1]
			if t >= a.Time and t <= b.Time then
				local k = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
				return a.Value + (b.Value - a.Value) * k
			end
		end
		return kps[#kps].Value
	end
	local stops = {}
	for _, t in times do
		local c = sampleColor(t)
		local mixed = { R = c.R * baseColor.R, G = c.G * baseColor.G, B = c.B * baseColor.B }
		local tr = 1 - (1 - baseTransparency) * (1 - sampleT(t))
		table.insert(stops, string.format("%s %.1f%%", rgba(mixed, tr), t * 100))
	end
	return string.format("linear-gradient(%.1fdeg,%s)", 90 + g.Rotation + (angleOffset or 0), table.concat(stops, ","))
end

local function cornerRadius(inst, w, h)
	local c = child(inst, "UICorner")
	if not c then
		return nil
	end
	local r = math.min(w, h) * c.CornerRadius.Scale + c.CornerRadius.Offset
	return math.clamp(r, 0, math.min(w, h) / 2)
end

local function emit(buf, inst, box, depth)
	local cls = inst.ClassName
	local w, h = box.w, box.h
	local style = {
		string.format("left:%s;top:%s;width:%s;height:%s;z-index:%d;", px(box.x), px(box.y), px(w), px(h), inst.ZIndex),
	}
	local transforms = {}
	if inst.Rotation ~= 0 then
		table.insert(transforms, string.format("rotate(%.2fdeg)", inst.Rotation))
	end
	local scale = child(inst, "UIScale")
	if scale and scale.Scale ~= 1 then
		table.insert(transforms, string.format("scale(%.3f)", scale.Scale))
	end
	if #transforms > 0 then
		table.insert(style, "transform:" .. table.concat(transforms, " ") .. ";")
	end
	local radius = cornerRadius(inst, w, h)
	if radius then
		table.insert(style, "border-radius:" .. px(radius) .. ";")
	end
	local isText = cls == "TextLabel" or cls == "TextButton" or cls == "TextBox"
	local gradient = enabledChild(inst, "UIGradient")
	if inst.BackgroundTransparency < 1 then
		if gradient and not isText then
			table.insert(
				style,
				"background:" .. gradientCss(gradient, inst.BackgroundColor3, inst.BackgroundTransparency) .. ";"
			)
		else
			table.insert(style, "background:" .. rgba(inst.BackgroundColor3, inst.BackgroundTransparency) .. ";")
		end
	end
	local stroke = enabledChild(inst, "UIStroke")
	if stroke and (not isText or stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then
		table.insert(
			style,
			string.format("box-shadow:0 0 0 %s %s;", px(stroke.Thickness), rgba(stroke.Color, stroke.Transparency))
		)
	end
	if cls == "CanvasGroup" then
		table.insert(style, string.format("opacity:%.3f;overflow:hidden;", 1 - inst.GroupTransparency))
	elseif inst.ClipsDescendants or cls == "ScrollingFrame" then
		table.insert(style, "overflow:hidden;")
	end
	if (cls == "ImageLabel" or cls == "ImageButton") and inst.Image ~= "" then
		table.insert(
			style,
			"background-image:repeating-linear-gradient(45deg,rgba(0,0,0,.12) 0 6px,transparent 6px 12px);outline:1px dashed rgba(0,0,0,.35);"
		)
	end
	table.insert(buf, string.format('<div class="g" data-n="%s" style="%s">', esc(inst.Name), table.concat(style)))

	if isText and inst.Text ~= "" then
		local size = textSize(inst, w, h)
		local alignX = ({ Left = "flex-start", Center = "center", Right = "flex-end" })[inst.TextXAlignment.Name]
			or "center"
		local alignY = ({ Top = "flex-start", Center = "center", Bottom = "flex-end" })[inst.TextYAlignment.Name]
			or "center"
		local tstyle = {
			fontCss(inst),
			string.format("font-size:%s;justify-content:%s;align-items:%s;", px(size), alignX, alignY),
			string.format("text-align:%s;", string.lower(inst.TextXAlignment.Name)),
			if inst.TextWrapped or inst.TextScaled then "white-space:pre-wrap;" else "white-space:pre;",
		}
		local textColor = rgba(inst.TextColor3, inst.TextTransparency)
		if gradient then
			table.insert(
				tstyle,
				"background:"
					.. gradientCss(gradient, inst.TextColor3, inst.TextTransparency, 0)
					.. ";-webkit-background-clip:text;background-clip:text;color:transparent;"
			)
		else
			table.insert(tstyle, "color:" .. textColor .. ";")
		end
		if stroke and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			-- outline as its own layer underneath, so gradient fills stay visible
			local under = table.clone(tstyle)
			table.insert(
				under,
				string.format(
					"color:%s;-webkit-text-stroke:%s %s;",
					rgba(stroke.Color, stroke.Transparency),
					px(stroke.Thickness * 2),
					rgba(stroke.Color, stroke.Transparency)
				)
			)
			table.insert(buf, string.format('<div class="t" style="%s">%s</div>', table.concat(under), esc(inst.Text)))
		elseif inst.TextStrokeTransparency < 1 then
			local c = rgba(inst.TextStrokeColor3, inst.TextStrokeTransparency)
			table.insert(
				tstyle,
				string.format("text-shadow:1px 1px 0 %s,-1px 1px 0 %s,1px -1px 0 %s,-1px -1px 0 %s;", c, c, c, c)
			)
		end
		local body = if inst.RichText then richText(inst.Text) else esc(inst.Text)
		table.insert(buf, string.format('<div class="t" style="%s"><span>%s</span></div>', table.concat(tstyle), body))
	end

	local kids, extent = layoutChildren(inst, w, h)
	local _ = extent
	local offsetY = 0
	if cls == "ScrollingFrame" then
		offsetY = -inst.CanvasPosition.Y
	end
	for _, k in kids do
		if offsetY ~= 0 then
			k.y += offsetY
		end
		emit(buf, k.inst, k, depth + 1)
	end
	table.insert(buf, "</div>")
end

-- AutomaticSize: grow boxes to fit their content
function applyAutomaticSize(inst, w, h)
	if inst.AutomaticSize == Enum.AutomaticSize.Y or inst.AutomaticSize == Enum.AutomaticSize.XY then
		local _, extent = layoutChildren(inst, w, h)
		h = math.max(h, extent)
	end
	return w, h
end

local function emitRoot(buf, gui, viewport)
	if not gui.Enabled then
		return
	end
	local top = if gui.IgnoreGuiInset then 0 else TOP_INSET
	local w, h = viewport.X, viewport.Y - top
	table.insert(
		buf,
		string.format(
			'<div class="g" data-n="%s" style="left:0;top:%s;width:%s;height:%s;z-index:%d;">',
			esc(gui.Name),
			px(top),
			px(w),
			px(h),
			gui.DisplayOrder + 1
		)
	)
	local kids = layoutChildren(gui, w, h)
	for _, k in kids do
		emit(buf, k.inst, k, 1)
	end
	table.insert(buf, "</div>")
end

function Snapshot.html(Mock, side, title: string): string
	Enum = Mock.Enum
	local pg = side.playerRaw:FindFirstChild("PlayerGui")
	local vp = side.viewport
	local buf = {
		"<!doctype html><html><head><meta charset='utf-8'><title>" .. esc(title) .. "</title>",
		"<link rel='stylesheet' href='https://fonts.googleapis.com/css2?family=Fredoka+One&family=Patrick+Hand&family=Montserrat:wght@400;700;900&display=swap'>",
		"<style>html,body{margin:0;background:#222}#vp{position:relative;overflow:hidden;background:#fff;",
		string.format("width:%dpx;height:%dpx}", vp.X, vp.Y),
		".g{position:absolute;box-sizing:border-box}",
		".t{position:absolute;inset:0;display:flex;line-height:1.1;overflow:visible}",
		"#bar{position:absolute;left:0;top:0;right:0;height:"
			.. TOP_INSET
			.. "px;background:rgba(0,0,0,.15);z-index:9999;pointer-events:none}</style></head><body>",
		"<div id='vp'><div id='bar'></div>",
	}
	local guis = {}
	for _, g in pg:GetChildren() do
		if g.ClassName == "ScreenGui" then
			table.insert(guis, g)
		end
	end
	table.sort(guis, function(a, b)
		return a.DisplayOrder < b.DisplayOrder
	end)
	for _, g in guis do
		emitRoot(buf, g, vp)
	end
	table.insert(buf, "</div></body></html>")
	return table.concat(buf)
end

return Snapshot
