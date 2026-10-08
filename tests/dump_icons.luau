-- Prints IconData as JSON (used by tools/preview_icons.py)
local I = requireModule("Client/UI/IconData")

local function enc(v)
	local t = type(v)
	if t == "number" then
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('"', '\\"') .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local n = #v
		local parts = {}
		local isArray = true
		for k in pairs(v) do
			if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				isArray = false
			end
		end
		if isArray then
			for i = 1, n do
				table.insert(parts, enc(v[i]))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		-- op tables mix positional args and named options
		local args = {}
		for i = 1, n do
			table.insert(args, enc(v[i]))
		end
		for k, x in pairs(v) do
			if type(k) == "string" then
				table.insert(parts, '"' .. k .. '":' .. enc(x))
			end
		end
		table.insert(parts, '"__args":[' .. table.concat(args, ",") .. "]")
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local names = {}
for name in pairs(I) do
	table.insert(names, name)
end
table.sort(names)
local parts = {}
for _, name in names do
	table.insert(parts, '"' .. name .. '":' .. enc(I[name]))
end
print("{" .. table.concat(parts, ",") .. "}")
