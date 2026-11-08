-- The shop's skin of the day: one Feathers skin a day at a discount, the same for everyone. The day changes at
-- midnight UTC. The server charges this price too (server/Shop), so pass the server's time: os.time() there,
-- workspace:GetServerTimeNow() on clients.

local Skins = require(script.Parent.Skins)

local Featured = {}

Featured.Discount = 0.2

local DAY = 86400

-- Skins bought with Feathers that cost something.
local pool = {}
for _, skin in Skins.List do
	if Skins.source(skin) == "Feathers" and (skin.Price or 0) > 0 then
		table.insert(pool, skin)
	end
end

local function day(now: number): number
	return math.floor(now / DAY)
end

-- Today's skin. Consecutive days jump around the list rather than walking down it.
function Featured.skin(now: number)
	local hash = (day(now) * 2654435761) % 4294967296
	return pool[hash % #pool + 1]
end

-- What a Feathers skin costs right now: the skin of the day is cheaper, rounded to 5.
function Featured.price(skin, now: number): number
	if Featured.skin(now).Id == skin.Id then
		return math.floor(skin.Price * (1 - Featured.Discount) / 5 + 0.5) * 5
	end
	return skin.Price
end

-- Seconds until the next skin of the day.
function Featured.secondsLeft(now: number): number
	return DAY - now % DAY
end

return Featured
