-- The dining room and kitchen: swaps their scenery for the low-poly models from assets/lowpoly/build_rooms.py. Run this
-- after importing asset 98629172377497 as ReplicatedStorage.LowPolyRooms; see Kit.luau for how.
--
-- The old solid parts stay where they are, invisible, as the collision, so racing hasn't changed. What can't be part of
-- a mesh stays or goes back in as real parts: the burners, which light up when hot; water; and anything with text on it.

local Kit = loadstring(game:GetService("ServerScriptService").Server.MapBuilders.Kit.Source)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Material = Enum.Material
local rgb = Color3.fromRGB

-- Everything in the file is where it goes in the map, but the import can land anywhere, so this one piece's known
-- place says how far to move them all.
local REFERENCE, REFERENCE_CENTER = "Dining_Shell", Vector3.new(0, 143, 500)

local GLOW_COLORS = {
	Dining_Windows_Glow = rgb(220, 239, 255),
	Dining_Candles_Glow = rgb(255, 215, 106),
	Dining_Fire_Glow = rgb(255, 130, 40),
	Kitchen_Lights_Glow = rgb(255, 255, 244),
	Kitchen_Pass_Glow = rgb(235, 195, 135),
	Kitchen_Heat_Glow = rgb(255, 80, 40),
	Kitchen_Flames_Glow = rgb(255, 130, 40),
}
local NO_SHADOW = { Dining_Floor = true, Dining_Rug = true, Dining_Shell = true, Kitchen_Floor = true, Kitchen_Walls = true }

local function hidePart(part: BasePart)
	part.Transparency = 1
	part.CastShadow = false
end

local function hideAll(folder: Instance, except: { [string]: boolean }?)
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and not (except and except[d.Name]) then
			hidePart(d)
		end
	end
end

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
	local dining = Kit.fresh(workspace.Maps.DinnerDash, "LowPoly")
	local kitchen = Kit.fresh(workspace.Maps.OvenEscape, "LowPoly")
	local reference = source[REFERENCE]:FindFirstChildWhichIsA("MeshPart", true)
	-- An import can land turned as well as moved, so each mesh keeps its place relative to the reference piece.
	local landed = reference.CFrame

	for _, model in source:GetChildren() do
		local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			local name = model.Name
			mesh.Name = name
			mesh.CFrame = CFrame.new(REFERENCE_CENTER) * landed:ToObjectSpace(mesh.CFrame)
			setUp(mesh)
			mesh.CastShadow = not NO_SHADOW[name]
			if GLOW_COLORS[name] then
				local look = mesh:FindFirstChildOfClass("SurfaceAppearance")
				if look then
					look:Destroy()
				end
				mesh.TextureID = ""
				mesh.Material = Material.Neon
				mesh.Color = GLOW_COLORS[name]
				mesh.CastShadow = false
			end
			mesh.Parent = if string.sub(name, 1, 6) == "Dining" then dining else kitchen
		end
	end
	source:Destroy()
	return dining, kitchen
end

-- A flat part with text on it, for what can't be baked into a mesh.
local function signPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, text: string, textColor: Color3, stroke: Color3?, font: Enum.Font?)
	local part = Kit.box(parent, name, size, cframe, color, nil, { CastShadow = false })
	Kit.sign(part, text, textColor, stroke, nil, font)
	return part
end

-- An invisible part to carry a fire, a light or some steam.
local function emitterPart(parent: Instance, name: string, position: Vector3): Part
	return Kit.box(parent, name, Vector3.one, CFrame.new(position), Color3.new(1, 1, 1), nil, { Transparency = 1, CastShadow = false })
end

local function dining(folder: Instance)
	local map = workspace.Maps.DinnerDash
	local tableFolder = map.Table
	for _, name in { "South", "NorthA", "NorthB", "West", "East", "Runner" } do
		hidePart(tableFolder[name])
	end
	for _, part in tableFolder:GetChildren() do
		if part.Name == "Leg" then
			hidePart(part)
		end
	end
	hideAll(tableFolder.Checks)
	hideAll(tableFolder.RunnerStripes)
	hideAll(map.Centerpiece)
	local room = map:FindFirstChild("Room")
	if room then
		room:Destroy()
	end

	-- The portraits go in the gold frames on the walls, and the fireplace's above the mantel.
	local art = Kit.folder(folder, "Art")
	local PAPER = rgb(52, 40, 34)
	local WHITE, GOLD, BROWN = Color3.new(1, 1, 1), rgb(226, 182, 72), rgb(60, 36, 16)
	local function portrait(frame: CFrame, x: number, y: number, width: number, height: number, picture: string, title: string)
		signPart(art, "Portrait", Vector3.new(width, height, 0.6), frame * CFrame.new(x, y, -2.7), PAPER, picture, WHITE)
		signPart(art, "Plaque", Vector3.new(width * 0.9, 6, 0.6), frame * CFrame.new(x, y - height / 2 - 11, -1), GOLD, title, BROWN, nil, Enum.Font.Garamond)
	end
	local east = CFrame.lookAt(Vector3.new(430, 0, 500), Vector3.new(0, 0, 500))
	local west = CFrame.lookAt(Vector3.new(-430, 0, 500), Vector3.new(0, 0, 500))
	local north = CFrame.lookAt(Vector3.new(0, 0, 780), Vector3.new(0, 0, 500))
	portrait(east, 0, 170, 44, 56, "🦃", "Sir Thomas Gobble")
	portrait(east, -249, 170, 44, 56, "👑", "The Queen Hen")
	portrait(west, 0, 170, 44, 56, "🍗", "Uncle Drumstick, Sadly Missed")
	portrait(west, -249, 170, 44, 56, "🥧", "Aunt Pumpkin")
	portrait(north, 0, 196, 104, 72, "🦃", "Great-Grandpa Gobbles, Founder")

	-- Real fire in the grate, and the warm light from it and the chandelier.
	local grate = emitterPart(folder, "FireEmitter", Vector3.new(0, 16, 760))
	local fire = Instance.new("Fire")
	fire.Size = 26
	fire.Heat = 12
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 225, 110)
	fire.Parent = grate
	Kit.light(grate, rgb(255, 150, 70), 60, 3)
	Kit.light(emitterPart(folder, "ChandelierLight", Vector3.new(0, 225, 500)), rgb(255, 225, 170), 60, 3)
end

local function kitchen(folder: Instance)
	local map = workspace.Maps.OvenEscape
	local keep = { Display = true, Sign = true, DoorWindow = true, Element = true, Water = true, Stream = true, Cooktop = true, Griddle = true, Label = true, HoodLight = true }
	hideAll(map.Ground)
	hideAll(map.Counters)
	hideAll(map.Decor, keep)
	hideAll(map.Fixtures, keep)
	hideAll(map.Oven, keep)
	hideAll(map.Obstacles, keep)
	local room = map:FindFirstChild("Room")
	if room then
		room:Destroy()
	end

	local signs = Kit.folder(folder, "Signs")
	local CREAM = rgb(255, 245, 225)
	local pass = CFrame.lookAt(Vector3.new(-892, 0, 0), Vector3.new(0, 0, 0))
	signPart(signs, "OrderUp", Vector3.new(96, 17, 1.4), pass * CFrame.new(0, 148, -1), rgb(205, 40, 40), "🔔 ORDER UP! 🔔", CREAM, rgb(90, 15, 15))
	local walk = CFrame.lookAt(Vector3.new(-700, 0, -232), Vector3.new(-700, 0, 0))
	signPart(signs, "WalkInSign", Vector3.new(66, 15, 1), walk * CFrame.new(0, 126, -4.5), rgb(40, 110, 180), "❄️ WALK-IN ❄️", Color3.new(1, 1, 1))
	local board = CFrame.lookAt(Vector3.new(-597, 0, -232), Vector3.new(-597, 0, 0))
	signPart(signs, "Chalkboard", Vector3.new(45, 41, 0.6), board * CFrame.new(0, 118, -1.8), rgb(40, 48, 44), "TODAY'S SPECIAL\nTURKEY 🦃\n(if you can catch one)", rgb(240, 240, 230))
	signPart(signs, "WetFloor", Vector3.new(16, 26, 1), CFrame.new(-790, 13, 88) * CFrame.Angles(math.rad(-14), math.rad(160), 0), rgb(245, 200, 40), "⚠️\nWET\nFLOOR", rgb(30, 30, 30))

	-- Steam off the two stockpots.
	for _, z in { -30, 30 } do
		local steam = Instance.new("Smoke")
		steam.Color = rgb(245, 245, 245)
		steam.Opacity = 0.12
		steam.RiseVelocity = 8
		steam.Size = 12
		steam.Parent = emitterPart(folder, "SteamEmitter", Vector3.new(-772, 66, z))
	end
end

local source = ReplicatedStorage:FindFirstChild("LowPolyRooms")
if not source then
	return "nothing to do: import the asset as ReplicatedStorage.LowPolyRooms first"
end
local diningFolder, kitchenFolder = placeModels(source)
dining(diningFolder)
kitchen(kitchenFolder)

local counts = {}
for _, folder in { diningFolder, kitchenFolder } do
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("MeshPart") then
			n += 1
		end
	end
	table.insert(counts, n)
end
print("Low-poly rooms placed:", counts[1], "dining meshes,", counts[2], "kitchen meshes")
return `{counts[1]} dining, {counts[2]} kitchen`
