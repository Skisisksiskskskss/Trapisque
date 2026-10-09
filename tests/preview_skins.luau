-- Preview helper (bundle it before a dump script): runs the game's own TileSkins code
-- against a recording Shapes, so the offline previews draw exactly what the board does.
-- Defines the global RecordSkin(kind, flat, r, dir) -> icon ops, and SkinTop(kind).
-- the few Roblox datatypes TileSkins touches while building (only their shapes matter)
local function value(...)
	return { ... }
end
Vector2 = Vector2 or { new = value }
UDim2 = UDim2 or { new = value, fromScale = value, fromOffset = value }
Enum = Enum or setmetatable({}, {
	__index = function(_, group)
		return setmetatable({}, {
			__index = function(_, item)
				return group .. "." .. item
			end,
		})
	end,
})

local recorded = {}
local function push(op)
	table.insert(recorded, op)
end
local function tr(o)
	return if o then o.t else nil
end
__cache["Client/UI/Shapes"] = {
	canvas = function()
		return {}
	end,
	circle = function(_, cx, cy, d, color, o)
		push({ "circle", cx, cy, d, c = color, t = tr(o) })
	end,
	rect = function(_, cx, cy, w, h, color, o)
		push({ "rect", cx, cy, w, h, c = color, r = o and o.r, rot = o and o.rot, t = tr(o) })
	end,
	pill = function(_, cx, cy, w, h, color, o)
		push({ "pill", cx, cy, w, h, c = color, rot = o and o.rot })
	end,
	line = function(_, x1, y1, x2, y2, th, color, o)
		push({ "line", x1, y1, x2, y2, th, c = color, square = o and o.square, t = tr(o) })
	end,
	taper = function(_, pts, th0, th1, color, o)
		push({ "taper", pts, th0, th1, c = color, steps = o and o.steps })
	end,
	ring = function(_, cx, cy, d, th, color, o)
		if o and o.cut then
			-- a cut ring is an arc whose middle faces (cut rotation - 90 + frame rotation)
			push({ "arc", cx, cy, d, th, c = color, dir = o.cut[1] - 90 + (o.rot or 0), keep = o.cut[2], t = tr(o) })
		else
			push({ "ring", cx, cy, d, th, c = color, t = tr(o) })
		end
	end,
	arc = function(_, cx, cy, d, th, color, o)
		push({ "arc", cx, cy, d, th, c = color, dir = o and o.dir or 0, keep = o and o.keep or 0.5, t = tr(o) })
	end,
	hex = function(_, cx, cy, d, color, o)
		push({ "hex", cx, cy, d, c = color, rot = o and o.rot })
	end,
	half = function(_, cx, cy, d, color, o)
		push({ "half", cx, cy, d, c = color, dir = o and o.dir })
	end,
	sparkle = function(_, cx, cy, d, color)
		push({ "sparkle", cx, cy, d, c = color })
	end,
	chevron = function(_, cx, cy, size, th, color, o)
		push({ "chevron", cx, cy, size, th, c = color, dir = o and o.dir })
	end,
}
__cache["Client/UI/Util"] = {
	frame = function()
		return {}
	end,
}
__cache["Client/UI/Theme"] = {
	hex = function(h)
		return "#" .. h
	end,
}
local TileSkins = requireModule("Client/UI/Match/TileSkins")
-- the real modules again for anything required after this
__cache["Client/UI/Shapes"] = nil
__cache["Client/UI/Util"] = nil
__cache["Client/UI/Theme"] = nil

function RecordSkin(kind, flat, r, dir)
	recorded = {}
	TileSkins.draw({}, kind, { flat = flat, r = r, dir = dir })
	return recorded
end

function SkinTop(kind)
	return TileSkins.top(kind)
end

-- JSON for the dumps (icon ops keep their positional args in "__args")
function PreviewJson(v)
	local t = type(v)
	if t == "number" then
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local n = #v
		local isArray = true
		for k in pairs(v) do
			if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				isArray = false
			end
		end
		local parts = {}
		if isArray then
			for i = 1, n do
				table.insert(parts, PreviewJson(v[i]))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local args = {}
		for i = 1, n do
			table.insert(args, PreviewJson(v[i]))
		end
		for k, x in pairs(v) do
			if type(k) ~= "number" or k > n or k < 1 then
				table.insert(parts, '"' .. tostring(k) .. '":' .. PreviewJson(x))
			end
		end
		if n > 0 then
			table.insert(parts, '"__args":[' .. table.concat(args, ",") .. "]")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end
