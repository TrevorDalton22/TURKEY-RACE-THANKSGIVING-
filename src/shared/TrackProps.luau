-- The item box, boost pad and track pieces modeled in Blender (assets/props). They live in the place at
-- ReplicatedStorage.TrackProps, one MeshPart per piece, already anchored with nothing colliding.
-- Each one's -Z side is its front.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackProps = {}

local folder = ReplicatedStorage:WaitForChild("TrackProps", 30)
assert(folder, "[TurkeyRace] ReplicatedStorage.TrackProps is missing from this place, so there are no track pieces")

-- A new copy of a piece, not yet parented. scale: bigger or smaller than it was modeled.
function TrackProps.new(name: string, scale: number?): MeshPart
	local mesh = folder:WaitForChild(name):Clone() :: MeshPart
	if scale then
		mesh.Size *= scale
	end
	return mesh
end

return TrackProps
