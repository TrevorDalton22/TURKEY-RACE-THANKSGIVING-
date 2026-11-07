-- The lobby and the wooden floor under the whole world: swaps them for the low-poly models from
-- assets/lowpoly/build_lobby.py. Run this after importing asset 120257377276742 as ReplicatedStorage.LowPolyLobby; see
-- Kit.luau for how.
--
-- The old parts stay where they are, invisible, so the floor, fence and stands still hold everyone up and the join
-- circle, podium and showroom code still finds the parts it uses. What can't be part of a mesh stays visible: anything
-- with text or a decal on it, anything that glows, and the Hall of Fame board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Everything in the file is where it goes, but an import can land moved and turned, so each mesh keeps its place
-- relative to this one, whose middle is known.
local REFERENCE, REFERENCE_CENTER = "Lobby_Floor4", Vector3.new(512, 0.12, 498.5)

local function staysVisible(part: BasePart): boolean
	if part.Name == "WinsBoard" or part.Material == Enum.Material.Neon then
		return true
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") or child:IsA("Decal") or child:IsA("Texture") then
			return true
		end
	end
	return false
end

local function hide(part: Instance)
	if part:IsA("BasePart") and not staysVisible(part) then
		part.Transparency = 1
		part.CastShadow = false
	end
end

local source = ReplicatedStorage:FindFirstChild("LowPolyLobby")
if not source then
	return "nothing to do: import the asset as ReplicatedStorage.LowPolyLobby first"
end

local lobby = workspace.Lobby
local old = lobby:FindFirstChild("LowPoly")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LowPoly"

local reference = source[REFERENCE]:FindFirstChildWhichIsA("MeshPart", true)
local landed = reference.CFrame
for _, model in source:GetChildren() do
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		mesh.Name = model.Name
		mesh.CFrame = CFrame.new(REFERENCE_CENTER) * landed:ToObjectSpace(mesh.CFrame)
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.Massless = true
		-- The floor doesn't need to cast shadows on anything; the lobby's things do.
		mesh.CastShadow = string.sub(model.Name, 1, 11) ~= "Lobby_Floor"
		pcall(function()
			mesh.CollisionFidelity = Enum.CollisionFidelity.Box
			mesh.RenderFidelity = Enum.RenderFidelity.Precise
		end)
		mesh.Parent = folder
	end
end
source:Destroy()

-- Hide what the meshes replace, before showing them, so nothing is drawn twice.
for _, part in lobby:GetDescendants() do
	hide(part)
end
for _, part in lobby:GetChildren() do
	hide(part)
end
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	hide(spawn)
end
for _, board in workspace.Floorboards:GetChildren() do
	hide(board)
end
folder.Parent = lobby

local shown = 0
for _, part in lobby:GetDescendants() do
	if part:IsA("BasePart") and not part:IsA("MeshPart") and part.Transparency < 1 then
		shown += 1
	end
end
print("Low-poly lobby placed:", #folder:GetChildren(), "meshes;", shown, "real parts still showing")
return `{#folder:GetChildren()} meshes, {shown} real parts still showing`
