-- Reads Workspace.Track and converts positions to distance along the loop.
-- Distance 0 is the finish line; the loop runs through Track.Path P1, P2, ... back to P1.

local Track = {}

local folder = workspace:WaitForChild("Track")

Track.SurfaceY = 40

-- Built with numeric loops so the arrays stay in order whatever order GetChildren returns.
local points = {}
for i = 1, #folder.Path:GetChildren() do
	local p = folder.Path["P" .. i].Position
	points[i] = Vector3.new(p.X, 0, p.Z)
end

local starts = {}
local length = 0
for i, a in points do
	local b = points[i % #points + 1]
	starts[i] = length
	length += (b - a).Magnitude
end
Track.Length = length

-- Distance along the loop of the point on the path closest to `position`.
function Track.distanceAt(position: Vector3): number
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

-- Point on the path at distance `s`, plus the direction of travel there.
function Track.pointAt(s: number): (Vector3, Vector3)
	s %= length
	for i, a in points do
		local ab = points[i % #points + 1] - a
		if s <= starts[i] + ab.Magnitude or i == #points then
			local dir = ab.Unit
			local p = a + dir * (s - starts[i])
			return Vector3.new(p.X, Track.SurfaceY, p.Z), dir
		end
	end
	error("unreachable")
end

-- Gate distances in order: checkpoints CP1..CPn, then the finish line at Track.Length.
Track.Gates = {}
for i = 1, #folder.Checkpoints:GetChildren() do
	Track.Gates[i] = Track.distanceAt(folder.Checkpoints["CP" .. i].Position)
end
table.insert(Track.Gates, length)

Track.StartPads = folder.StartPads:GetChildren()
table.sort(Track.StartPads, function(a, b)
	return a:GetAttribute("Order") < b:GetAttribute("Order")
end)

Track.ItemBoxes = folder.ItemBoxes:GetChildren()

return Track
