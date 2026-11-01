--!strict
-- Number and time formatting for UI.

local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15 -> "15", 999999 -> "1M"
function Format.Short(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	if n < 1000 then
		local text = if n >= 100 or n == math.floor(n) then tostring(math.floor(n)) else string.format("%.1f", n)
		return (if negative then "-" else "") .. text
	end
	local index = 1
	while n >= 999.5 and index < #suffixes do
		n /= 1000
		index += 1
	end
	local text
	if n >= 100 then
		text = string.format("%d", math.floor(n + 0.5))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10 + 0.5) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100 + 0.5) / 100)
	end
	text = string.gsub(text, "%.?0+$", "")
	return (if negative then "-" else "") .. text .. suffixes[index]
end

function Format.Cash(value: number): string
	return "$" .. Format.Short(value)
end

function Format.Commas(value: number): string
	local text = tostring(math.floor(value))
	local result = string.reverse(text)
	result = string.gsub(result, "(%d%d%d)", "%1,")
	result = string.reverse(result)
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return result
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- 3725 -> "1h 2m", 75 -> "1m 15s"
function Format.Duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, sec)
	end
	return string.format("%ds", sec)
end

function Format.Percent(fraction: number): string
	local pct = fraction * 100
	if pct >= 10 then
		return string.format("%d%%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return string.format("%.1f%%", pct)
	elseif pct >= 0.01 then
		return string.format("%.2f%%", pct)
	end
	return string.format("%.4f%%", pct)
end

return Format
