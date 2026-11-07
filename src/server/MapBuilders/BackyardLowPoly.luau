-- Pumpkin Patch Panic: swaps the backyard's scenery for the low-poly models from assets/lowpoly. Run this after importing
-- asset 79302216326457 as ReplicatedStorage.LowPolyYard; see Kit.luau for how.
--
-- The old track surface, corn blocks and fence stay where they are, invisible, as the collision, so racing hasn't
-- changed. To go back: run Backyard.luau and TrackPieces.luau, set the parts hidden below back to Transparency 0, and
-- destroy the map's LowPoly folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Material = Enum.Material
local rgb = Color3.fromRGB

local map = workspace.Maps.PumpkinPatch

-- Everything in the file is where it goes in the map, but the import can land anywhere, so this one piece's known
-- place says how far to move them all.
local BED_CENTER = Vector3.new(-15, 32, -567)

-- Where each chef mesh's middle is from his feet and from his shoulder, printed by build_backyard.py.
local CHEF_OFFSETS = {
	Chef_Body = Vector3.new(-9.3, 47.507, -13.175),
	Chef_Arm = Vector3.new(0, -10.445, 0.01),
}

-- Far off, so they're loaded whatever the distance, and they don't need to cast shadows on anything.
local FAR = { Hill1 = true, Hill2 = true, Hill3 = true, Hill4 = true, Hill5 = true, Hill6 = true, Clouds = true }
local NO_SHADOW = { Lawn = true, LawnFront = true, Bed = true, Pebbles = true, Neighbors = true }

local function setUp(mesh: MeshPart)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Massless = true
	-- These can only be set while editing. Keeping every facet up close matters more than the small saving from
	-- letting Roblox simplify them.
	pcall(function()
		mesh.CollisionFidelity = Enum.CollisionFidelity.Box
		mesh.RenderFidelity = Enum.RenderFidelity.Precise
	end)
end

local function placeModels(source: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LowPoly"
	local far = Instance.new("Model")
	far.Name = "Far"
	far.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	far.Parent = folder

	local bed = source.Bed:FindFirstChildWhichIsA("MeshPart", true)
	local move = BED_CENTER - bed.Position
	local props = ReplicatedStorage.TrackProps

	for _, model in source:GetChildren() do
		local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			local name = model.Name
			mesh.Name = name
			mesh.Position += move
			setUp(mesh)
			mesh.CastShadow = not (FAR[name] or NO_SHADOW[name])
			if CHEF_OFFSETS[name] then
				mesh:SetAttribute("Offset", CHEF_OFFSETS[name])
				local old = props:FindFirstChild(name)
				if old then
					old:Destroy()
				end
				mesh.Parent = props
			elseif name == "BBQ_Coals_Glow" then
				local look = mesh:FindFirstChildOfClass("SurfaceAppearance")
				if look then
					look:Destroy()
				end
				mesh.TextureID = ""
				mesh.Material = Material.Neon
				mesh.Color = rgb(255, 120, 40)
				mesh.CastShadow = false
				mesh.Parent = folder
			else
				mesh.Parent = if FAR[name] then far else folder
			end
		end
	end
	source:Destroy()
	folder.Parent = map
end

local function hide(part: Instance)
	if part:IsA("BasePart") then
		part.Transparency = 1
		part.CastShadow = false
	end
end

local function hideAll(folder: Instance)
	for _, d in folder:GetDescendants() do
		hide(d)
	end
end

local source = ReplicatedStorage:FindFirstChild("LowPolyYard")
if not source then
	return "nothing to do: import the asset as ReplicatedStorage.LowPolyYard first"
end

local old = map:FindFirstChild("LowPoly")
if old then
	old:Destroy()
end
placeModels(source)

-- The block-built room is replaced outright; Backyard.luau can rebuild it.
local room = map:FindFirstChild("Room")
if room then
	room:Destroy()
end

for _, name in { "Mesa", "MesaWestN", "MesaWestS", "HillTop", "HillUp", "HillDown", "Field", "Pond" } do
	hide(map.Ground[name])
end
for _, name in { "CornA", "CornB", "CornC", "CornD" } do
	hide(map.Corn[name])
end
hideAll(map.Decor.Fence)
hideAll(map.Decor.Stalks)
map.Ground.CreekBed.Color = rgb(127, 122, 114)

local count = 0
for _, d in map.LowPoly:GetDescendants() do
	if d:IsA("MeshPart") then
		count += 1
	end
end
print("Low-poly backyard placed:", count, "meshes")
return count
