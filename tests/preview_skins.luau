-- Preview helper (bundle it before a dump script). The board no longer reskins tiles
-- (TileSkins isn't used by the game any more), so this file now only holds what every
-- dump shares:
--   PreviewJson(v)  JSON for the dumps (art ops keep their positional args in "__args")
--   PreviewTheme()  the game's own Theme module (colours, seat / category / character
--                   colours), loaded with tiny stand-ins for the Roblox types it touches
--                   so the offline previews use exactly the palette the game does

function PreviewJson(v)
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) and math.abs(v) < 2 ^ 53 then
			return string.format("%d", v)
		end
		return string.format("%.6g", v)
	elseif t == "string" then
		local s = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
		return '"' .. s .. '"'
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
		local keys = {}
		for k, x in pairs(v) do
			if (type(k) ~= "number" or k > n or k < 1) and type(x) ~= "function" then
				table.insert(keys, tostring(k))
			end
		end
		table.sort(keys)
		for _, k in keys do
			local x = v[k]
			if x == nil then
				x = v[tonumber(k)]
			end
			table.insert(parts, '"' .. k .. '":' .. PreviewJson(x))
		end
		if n > 0 then
			table.insert(parts, '"__args":[' .. table.concat(args, ",") .. "]")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

-- Theme.lua builds Color3s and Fonts; here a colour is just its "#RRGGBB".
function PreviewTheme()
	Color3 = Color3 or {
		fromHex = function(s: string)
			return "#" .. string.upper(s)
		end,
		new = function(r: number, g: number, b: number)
			return string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
		end,
	}
	Enum = Enum or setmetatable({}, {
		__index = function(_, group)
			return setmetatable({}, {
				__index = function(_, item)
					return tostring(group) .. "." .. tostring(item)
				end,
			})
		end,
	})
	Font = Font or {
		fromEnum = function(e)
			return { Family = e }
		end,
		new = function(family, weight)
			return { Family = family, Weight = weight }
		end,
	}
	local Theme = requireModule("Client/UI/Theme")
	return {
		C = Theme.C,
		Seat = Theme.Seat,
		SeatName = Theme.SeatName,
		Team = Theme.Team,
		TeamName = Theme.TeamName,
		Category = Theme.Category,
		CategoryName = Theme.CategoryName,
		Character = Theme.Character,
	}
end
