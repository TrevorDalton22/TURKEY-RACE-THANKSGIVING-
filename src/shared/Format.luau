-- Text formatting shared by the server and HUD.

local Format = {}

-- 1 -> "1st", 2 -> "2nd", 11 -> "11th"
function Format.ordinal(n: number): string
	local suffix = if n % 100 >= 11 and n % 100 <= 13 then "th" else ({ "st", "nd", "rd" })[n % 10] or "th"
	return n .. suffix
end

-- Countdown clock, rounded up: 83.2 -> "1:24"
function Format.clock(seconds: number): string
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Finish time with tenths: 83.25 -> "1:23.2"
function Format.raceTime(seconds: number): string
	return string.format("%d:%04.1f", seconds // 60, seconds % 60)
end

return Format
