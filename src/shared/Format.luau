-- Text formatting shared by the server and HUD.

local Format = {}

-- The Feathers icon. (The feather emoji itself doesn't show in Roblox, so it's autumn leaves.)
Format.FEATHER = "🍂"

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

-- Time left on something long, rounded down: 125 -> "2:05", 4000 -> "1:06:40"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, seconds // 60 % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

-- Finish time with tenths: 83.25 -> "1:23.2"
function Format.raceTime(seconds: number): string
	return string.format("%d:%04.1f", seconds // 60, seconds % 60)
end

return Format
