-- The race maps, and conversions between positions and distance along the current map's loop.
--
-- Each map is a folder in Workspace.Maps holding:
--   Path         P1, P2, ... marker parts around the loop, each centered 2 studs above the racing surface
--                (so a hill is just markers at different heights). Distance 0 is P1, the finish line,
--                and the loop runs P1, P2, ... back to P1.
--   Checkpoints  CP1..CPn gates, in order around the loop.
--   StartPads    one pad per racer, with an Order attribute.
--   ItemBoxes    power-up boxes.
--   Hazards      optional; see Hazards.luau.
--   ChefSpot     a marker part in the middle of the map, centered where the chef's feet go.
-- and the attributes DisplayName, Order (rotation order), LaneWidth (the narrowest lane, in studs),
-- and optionally Laps (overrides Config.Laps) and ChefStartsAt (overrides Config.Chef.StartsAtSeconds).

local Track = {}

local MARKER_HEIGHT = 2

export type Map = {
	Folder: Folder,
	DisplayName: string,
	LaneWidth: number,
	Laps: number?,
	ChefStartsAt: number?,
	ChefSpot: CFrame,
	points: { Vector3 }, -- flat (Y = 0)
	heights: { number }, -- racing surface height at each point
	starts: { number }, -- distance at each point
	Length: number,
	Gates: { number },
	StartPads: { BasePart },
	ItemBoxes: { BasePart },
}

local function load(folder: Folder): Map
	local points, heights = {}, {}
	-- Numeric loops keep the arrays in order whatever order GetChildren returns.
	for i = 1, #folder.Path:GetChildren() do
		local p = folder.Path["P" .. i].Position
		points[i] = Vector3.new(p.X, 0, p.Z)
		heights[i] = p.Y - MARKER_HEIGHT
	end
	local starts, length = {}, 0
	for i, a in points do
		starts[i] = length
		length += (points[i % #points + 1] - a).Magnitude
	end

	local pads = folder.StartPads:GetChildren()
	table.sort(pads, function(a, b)
		return a:GetAttribute("Order") < b:GetAttribute("Order")
	end)

	return {
		Folder = folder,
		DisplayName = folder:GetAttribute("DisplayName") or folder.Name,
		LaneWidth = folder:GetAttribute("LaneWidth") or 70,
		Laps = folder:GetAttribute("Laps"),
		ChefStartsAt = folder:GetAttribute("ChefStartsAt"),
		ChefSpot = folder.ChefSpot.CFrame,
		points = points,
		heights = heights,
		starts = starts,
		Length = length,
		Gates = {}, -- filled in once distanceAt works for this map
		StartPads = pads,
		ItemBoxes = folder.ItemBoxes:GetChildren(),
	}
end

local current: Map

-- Distance along the loop of the point on the path closest to `position`.
function Track.distanceAt(position: Vector3): number
	local points, starts = current.points, current.starts
	local flat = Vector3.new(position.X, 0, position.Z)
	local bestS, bestD = 0, math.huge
	for i, a in points do
		local ab = points[i % #points + 1] - a
		local t = math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (a + ab * t - flat).Magnitude
		if d < bestD then
			bestD, bestS = d, starts[i] + ab.Magnitude * t
		end
	end
	return bestS
end

-- Point on the racing surface at distance `s`, plus the (flat) direction of travel there.
function Track.pointAt(s: number): (Vector3, Vector3)
	local points, heights, starts = current.points, current.heights, current.starts
	s %= current.Length
	for i, a in points do
		local j = i % #points + 1
		local ab = points[j] - a
		if s <= starts[i] + ab.Magnitude or i == #points then
			local along = s - starts[i]
			local p = a + ab.Unit * along
			local height = heights[i] + (heights[j] - heights[i]) * math.clamp(along / ab.Magnitude, 0, 1)
			return Vector3.new(p.X, height, p.Z), ab.Unit
		end
	end
	error("unreachable")
end

-- Switches every Track function and field to `map`.
function Track.use(map: Map)
	current = map
	Track.Current = map
	Track.Folder = map.Folder
	Track.DisplayName = map.DisplayName
	Track.LaneWidth = map.LaneWidth
	Track.Length = map.Length
	Track.Gates = map.Gates
	Track.StartPads = map.StartPads
	Track.ItemBoxes = map.ItemBoxes
end

-- Every map, in rotation order.
Track.Maps = {} :: { Map }
for _, folder in workspace:WaitForChild("Maps"):GetChildren() do
	table.insert(Track.Maps, load(folder))
end
table.sort(Track.Maps, function(a, b)
	return (a.Folder:GetAttribute("Order") or 0) < (b.Folder:GetAttribute("Order") or 0)
end)

-- Gate distances in order: checkpoints CP1..CPn, then the finish line at the end of the loop.
for _, map in Track.Maps do
	Track.use(map)
	local checkpoints = map.Folder.Checkpoints
	for i = 1, #checkpoints:GetChildren() do
		map.Gates[i] = Track.distanceAt(checkpoints["CP" .. i].Position)
	end
	table.insert(map.Gates, map.Length)
end
Track.use(Track.Maps[1])

return Track
