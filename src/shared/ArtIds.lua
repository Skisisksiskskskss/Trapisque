--[[
	ArtIds
	Reading the ids of the uploaded art sheets the owner pastes into the art note
	(ArtNotice), and working out which sheet each is (ArtService does the asking Roblox).

		ArtIds.parse(text) -> { number }          -- every run of 5+ digits (links work too)
		ArtIds.sheetNamed(name, sheets) -> string?   -- "Images/scenery_1" -> "scenery_1"
		ArtIds.match(found, sheets) -> { [sheet] = image id }
			found = { { image, name? } } in the order pasted: those whose name says their
			sheet go there, the rest fill the sheets left over in the order given
]]

local ArtIds = {}

function ArtIds.parse(text: string): { number }
	local out = {}
	for digits in string.gmatch(text, "%d+") do
		if #digits >= 5 and #out < 32 then
			table.insert(out, tonumber(digits) :: number)
		end
	end
	return out
end

function ArtIds.sheetNamed(name: string, sheets: { string }): string?
	local lower = string.lower(name)
	for _, sheet in sheets do
		local at, stop = string.find(lower, sheet, 1, true)
		if at and stop then
			local before = if at > 1 then string.sub(lower, at - 1, at - 1) else ""
			local after = string.sub(lower, stop + 1, stop + 1)
			if not string.match(before, "%w") and not string.match(after, "%d") then
				return sheet
			end
		end
	end
	return nil
end

function ArtIds.match(found: { { image: number, name: string? } }, sheets: { string }): { [string]: number }
	local out = {}
	local rest = {}
	for _, f in found do
		local sheet = f.name and ArtIds.sheetNamed(f.name, sheets)
		if sheet and out[sheet] == nil then
			out[sheet] = f.image
		else
			table.insert(rest, f.image)
		end
	end
	local i = 1
	for _, sheet in sheets do
		if out[sheet] == nil and rest[i] then
			out[sheet] = rest[i]
			i += 1
		end
	end
	return out
end

return ArtIds
