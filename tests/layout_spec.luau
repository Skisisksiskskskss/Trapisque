-- Treasure-map layout tests: nothing drawn on the map may overlap anything else.
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local DecorData = requireModule("Client/UI/DecorData")

local S = BoardLayout.Style
local EPS = 1e-6

local function dist(ax, ay, bx, by)
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- distance from (x, y) to the nearest tile centre, in the layout's own (maybe rotated) space
local function nearestTile(L, x, y)
	local best = math.huge
	for _, t in L.tiles do
		best = math.min(best, dist(x, y, t.x, t.y))
	end
	return best
end

for _, def in Maps.list do
	for _, rotate in { false, true } do
	local board = Board.get(def)
	local L = BoardLayout.build(board, def, Rng, { rotate = rotate })
	local x0, y0, x1, y1 = L.x0, L.y0, L.x0 + L.w, L.y0 + L.h
	local tb = L.title
	local name = def.id .. (if rotate then " (upright)" else "")

	test(name .. ": doodles stay off the path and inside the frame", function()
		truthy(#L.decor >= 6, "expected a few doodles, got " .. #L.decor)
		for _, d in L.decor do
			truthy(DecorData[d.kind] ~= nil, "unknown doodle " .. d.kind)
			local reach = d.size * S.decorReach
			truthy(nearestTile(L, d.x, d.y) - reach >= S.coast + S.gap - EPS, d.kind .. " touches the path")
			local half = d.size / 2
			truthy(d.x - half >= x0 + S.washInset - EPS and d.x + half <= x1 - S.washInset + EPS, d.kind .. " pokes out sideways")
			truthy(d.y - half >= y0 + S.washInset - EPS and d.y + half <= y1 - S.washInset + EPS, d.kind .. " pokes out vertically")
		end
	end)

	test(name .. ": doodles keep clear of the title, the compass and each other", function()
		for i, d in L.decor do
			local half = d.size / 2
			local apartX = math.abs(d.x - tb.x) >= tb.w / 2 + half - EPS
			local apartY = math.abs(d.y - tb.y) >= tb.h / 2 + half - EPS
			truthy(apartX or apartY, d.kind .. " overlaps the title")
			if L.compass then
				local gap = dist(d.x, d.y, L.compass.x, L.compass.y) - d.size * S.decorReach - L.compass.size * S.compassReach
				truthy(gap >= -EPS, d.kind .. " overlaps the compass")
			end
			for j, e in L.decor do
				if j > i then
					local gap = dist(d.x, d.y, e.x, e.y) - (d.size + e.size) * S.decorReach
					truthy(gap >= -EPS, d.kind .. " overlaps " .. e.kind)
				end
			end
		end
	end)

	test(name .. ": compass sits in open water, clear of the path and title", function()
		local c = L.compass
		truthy(c ~= nil, "no compass")
		local reach = c.size * S.compassReach
		truthy(nearestTile(L, c.x, c.y) - reach >= S.coast + S.gap - EPS, "compass touches the path")
		local apartX = math.abs(c.x - tb.x) >= tb.w / 2 + reach - EPS
		local apartY = math.abs(c.y - tb.y) >= tb.h / 2 + reach - EPS
		truthy(apartX or apartY, "compass overlaps the title")
	end)

	test(name .. ": title sits above every tile's land", function()
		for _, t in L.tiles do
			truthy(t.y - S.coast >= tb.y + tb.h / 2 - EPS, "tile " .. t.id .. " reaches the title")
		end
	end)

	test(name .. ": the camera box holds every tile", function()
		local box = L.tileBounds
		for _, t in L.tiles do
			truthy(t.x - 1 >= box.x0 and t.x + 1 <= box.x1 and t.y - 1 >= box.y0 and t.y + 1 <= box.y1, "tile " .. t.id .. " outside the camera box")
		end
	end)
	end
end

test("shared-tile pawn slots never overlap and stay inside the hex", function()
	local S = BoardLayout.Style
	local halfWidth = S.tileScale * math.cos(math.rad(30)) -- a pointy hex's flat-to-flat half width
	for n, layout in BoardLayout.PawnSlots do
		local r = S.pawn * layout.scale * S.pawnDisc / 2
		eq(#layout, n, "slot count")
		for i, a in ipairs(layout) do
			truthy(math.abs(a[1]) + r <= halfWidth + 0.01, "slot " .. n .. "/" .. i .. " leaves the hex")
			for j, b in ipairs(layout) do
				if j > i then
					truthy(dist(a[1], a[2], b[1], b[2]) >= 2 * r - 0.01, "slots " .. n .. ":" .. i .. "/" .. j .. " overlap")
				end
			end
		end
	end
end)
