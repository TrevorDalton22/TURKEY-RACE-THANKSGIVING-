-- The outsides of the dining room and the kitchen, from assets/lowpoly/build_outsides.py, so from the lobby they look
-- like wings of the house instead of plain boxes. Run this after importing asset 80596866132221 as
-- ReplicatedStorage.LowPolyOutsides; see Kit.luau for how.
--
-- It goes in Workspace.Outsides, loaded for everyone whatever the distance, like the forest. It sits just outside the
-- rooms' old walls, which stay as they are, so nothing changes inside the rooms, and nothing in it can be touched. It
-- also adds smoke to both chimneys.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Everything in the file is where it goes, but an import can land moved and turned, so each mesh keeps its place
-- relative to this one, whose middle is known.
local REFERENCE, REFERENCE_CENTER = "Outside_Kitchen_Roof", Vector3.new(-700, 233.163, -39.45)

-- The tops of the chimney pots: the fireplace's, through the dining room's roof, and the one built around the oven.
local SMOKE = {
	Outside_Dining_Walls = { Vector3.new(-14, 488, 776.5), Vector3.new(14, 488, 776.5) },
	Outside_Kitchen_Walls = { Vector3.new(-463.25, 342, 114), Vector3.new(-463.25, 342, 146) },
}

local function smoke(mesh: BasePart, position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Smoke"
	attachment.Position = mesh.CFrame:PointToObjectSpace(position)
	attachment.Parent = mesh
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(236, 233, 228), Color3.fromRGB(196, 194, 190))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 30) })
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = 2
	emitter.Speed = NumberRange.new(5, 8)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Acceleration = Vector3.new(1.5, 0.4, 0) -- a light breeze
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-12, 12)
	emitter.Parent = attachment
end

local source = ReplicatedStorage:FindFirstChild("LowPolyOutsides")
if not source then
	return "nothing to do: import the asset as ReplicatedStorage.LowPolyOutsides first"
end

local old = workspace:FindFirstChild("Outsides")
if old then
	old:Destroy()
end
local outsides = Instance.new("Model")
outsides.Name = "Outsides"
outsides.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

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
		pcall(function()
			mesh.CollisionFidelity = Enum.CollisionFidelity.Box
			mesh.RenderFidelity = Enum.RenderFidelity.Precise
		end)
		for _, position in SMOKE[name] or {} do
			smoke(mesh, position)
		end
		mesh.Parent = outsides
	end
end
source:Destroy()
outsides.Parent = workspace

print("Outsides placed:", #outsides:GetChildren(), "meshes")
return #outsides:GetChildren()
