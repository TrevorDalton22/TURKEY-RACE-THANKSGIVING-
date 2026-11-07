-- The autumn forest around the lobby, from assets/lowpoly/build_forest.py, so there's no empty floor or horizon in
-- view. Run this after importing asset 96324681610295 as ReplicatedStorage.LowPolyForest; see Kit.luau for how.
--
-- It goes in Workspace.Forest, loaded for everyone whatever the distance, since the far trees are the horizon. It also
-- turns the flat ground beyond the world's floor (Workspace.FloorBeyond) the forest floor's color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Everything in the file is where it goes, but an import can land moved and turned, so each mesh keeps its place
-- relative to this one, whose middle is known.
local REFERENCE, REFERENCE_CENTER = "Forest_Ground4", Vector3.new(511.5, 0.75, 511.5)

local source = ReplicatedStorage:FindFirstChild("LowPolyForest")
if not source then
	return "nothing to do: import the asset as ReplicatedStorage.LowPolyForest first"
end

local old = workspace:FindFirstChild("Forest")
if old then
	old:Destroy()
end
local forest = Instance.new("Model")
forest.Name = "Forest"
forest.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local reference = source[REFERENCE]:FindFirstChildWhichIsA("MeshPart", true)
local landed = reference.CFrame
for _, model in source:GetChildren() do
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		local name = model.Name
		mesh.Name = name
		mesh.CFrame = CFrame.new(REFERENCE_CENTER) * landed:ToObjectSpace(mesh.CFrame)
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.Massless = true
		-- Shadows only from the trees near the lobby, where they fall on things you can see.
		mesh.CastShadow = string.find(name, "Near") ~= nil or name == "Forest_Bushes"
		pcall(function()
			mesh.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		mesh.Parent = forest
	end
end
source:Destroy()
forest.Parent = workspace

local beyond = workspace:FindFirstChild("FloorBeyond")
if beyond then
	for _, part in beyond:GetChildren() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(118, 110, 52)
			part.Material = Enum.Material.SmoothPlastic
		end
	end
end

print("Forest placed:", #forest:GetChildren(), "meshes")
return #forest:GetChildren()
