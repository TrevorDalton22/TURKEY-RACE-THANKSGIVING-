-- Pumpkin Patch Panic: turns the farm into the backyard garden behind the house. The track becomes gravel paths on a big
-- raised garden bed, and the chef stands at a brick barbecue in the middle of the corn. See Kit.luau for how to run this.

local Kit = loadstring(game:GetService("ServerScriptService").Server.MapBuilders.Kit.Source)()
local box, ball, post, pipe, wedge = Kit.box, Kit.ball, Kit.post, Kit.pipe, Kit.wedge
local rgb = Color3.fromRGB
local Material = Enum.Material

local map = workspace.Maps.PumpkinPatch
local room = Kit.fresh(map, "Room")

-- The yard, fenced on three sides with the house along the fourth.
local WEST, EAST, NORTH, HOUSE_Z = -515, 485, -1010, -262
local MID_X = (WEST + EAST) / 2
local BBQ = Vector3.new(-15, 68, -528) -- the top of the middle block of corn

local GRASS, GRASS_LIGHT = rgb(98, 160, 72), rgb(110, 172, 82)
local GRAVEL = rgb(190, 164, 128)
local TIMBER, TIMBER_DARK = rgb(120, 82, 50), rgb(92, 62, 38)
local FENCE_A, FENCE_B, FENCE_C = rgb(168, 122, 80), rgb(156, 112, 72), rgb(178, 132, 90)
local WHITE = rgb(250, 250, 245)
local SIDING, SIDING_LINE = rgb(240, 228, 205), rgb(218, 204, 180)
local ROOF = rgb(78, 72, 76)
local GLASS = rgb(150, 195, 225)
local SHUTTER = rgb(66, 104, 124)
local BRICK = rgb(170, 84, 62)
local STONE = rgb(176, 170, 160)
local TERRACOTTA = rgb(198, 104, 62)

local SHELL = { CastShadow = false }

-- What was already there ----------------------------------------------------------------------------------------------

local function restyle()
	for _, name in { "Mesa", "MesaWestN", "MesaWestS", "HillTop", "HillUp", "HillDown" } do
		local part = map.Ground[name]
		part.Color = GRAVEL
		part.Material = Material.Pebble
	end
	map.Ground.Field.Color = GRASS
	map.Ground.Field.Material = Material.Grass
	for _, name in { "CornA", "CornB", "CornC", "CornD" } do
		map.Corn[name].Material = Material.Grass
	end
	-- The little fence around the track becomes white picket.
	for _, part in map.Decor.Fence:GetChildren() do
		part.Color = WHITE
	end
	-- No barn or silo in a back garden, and those trees were toy-sized next to a house.
	local farm = map.Decor:FindFirstChild("Farm")
	if farm then
		farm:Destroy()
	end
end

-- The yard ------------------------------------------------------------------------------------------------------------

local function lawn()
	local group = Kit.folder(room, "Lawn")
	local depth = HOUSE_Z - NORTH
	box(group, "Lawn", Vector3.new(EAST - WEST + 60, 0.4, depth + 60), CFrame.new(MID_X, 0.2, (NORTH + HOUSE_Z) / 2), GRASS, Material.Grass, SHELL)
	-- Mowing stripes.
	local x = WEST + 50
	while x < EAST do
		box(group, "Stripe", Vector3.new(50, 0.1, depth), CFrame.new(x, 0.46, (NORTH + HOUSE_Z) / 2), GRASS_LIGHT, Material.Grass, SHELL)
		x += 100
	end
end

local function fenceRun(group: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local face = CFrame.lookAt(from, from + direction)
	local HEIGHT, PLANK = 96, 24
	local count = math.ceil(length / PLANK)
	local colors = { FENCE_A, FENCE_B, FENCE_C, FENCE_B }
	for i = 1, count do
		local along = (i - 0.5) * length / count
		box(group, "Plank", Vector3.new(3, HEIGHT, length / count - 0.6), face * CFrame.new(0, HEIGHT / 2, -along), colors[i % #colors + 1], Material.Wood)
	end
	box(group, "FenceCap", Vector3.new(6, 3, length), face * CFrame.new(0, HEIGHT + 1.5, -length / 2), TIMBER, Material.Wood)
	for along = 0, length, 120 do
		box(group, "FencePost", Vector3.new(8, HEIGHT + 8, 8), face * CFrame.new(0, (HEIGHT + 8) / 2, -along), TIMBER_DARK, Material.Wood)
	end
end

local function fences()
	local group = Kit.folder(room, "Fence")
	fenceRun(group, Vector3.new(WEST, 0, HOUSE_Z), Vector3.new(WEST, 0, NORTH))
	fenceRun(group, Vector3.new(EAST, 0, HOUSE_Z), Vector3.new(EAST, 0, NORTH))
	fenceRun(group, Vector3.new(WEST, 0, NORTH), Vector3.new(EAST, 0, NORTH))
end

-- `frame` is on the outside of a wall, looking out from it, so outward is -Z.
local function houseWindow(group: Instance, frame: CFrame, x: number, y: number)
	local at = function(ox, oy, oz)
		return frame * CFrame.new(x + ox, y + oy, oz)
	end
	box(group, "WindowFrame", Vector3.new(76, 96, 2), at(0, 0, -1), WHITE, nil, SHELL)
	box(group, "WindowGlass", Vector3.new(64, 84, 0.6), at(0, 0, -2.2), GLASS, Material.Glass, SHELL)
	box(group, "WindowBar", Vector3.new(64, 3, 1), at(0, 0, -2.8), WHITE, nil, SHELL)
	box(group, "WindowBar", Vector3.new(3, 84, 1), at(0, 0, -2.8), WHITE, nil, SHELL)
	box(group, "WindowSill", Vector3.new(86, 4, 7), at(0, -49, -3.5), WHITE, nil, SHELL)
	for _, side in { -1, 1 } do
		box(group, "Shutter", Vector3.new(19, 96, 1.6), at(side * 49, 0, -1), SHUTTER, nil, SHELL)
	end
end

local function flowerBox(group: Instance, frame: CFrame, x: number, y: number)
	box(group, "FlowerBox", Vector3.new(72, 9, 11), frame * CFrame.new(x, y, -6), TERRACOTTA, nil, SHELL)
	local colors = { rgb(230, 70, 90), rgb(250, 200, 60), rgb(240, 130, 50), rgb(190, 90, 200) }
	for i = 1, 8 do
		ball(group, "Flower", 8, (frame * CFrame.new(x - 36 + i * 8, y + 7, -6)).Position, colors[i % #colors + 1], nil, SHELL)
	end
end

local function door(group: Instance, frame: CFrame, x: number)
	box(group, "DoorFrame", Vector3.new(76, 122, 2), frame * CFrame.new(x, 61, -1), WHITE, nil, SHELL)
	box(group, "Door", Vector3.new(64, 114, 1.6), frame * CFrame.new(x, 57, -2.4), rgb(160, 54, 44), nil, SHELL)
	box(group, "DoorPanel", Vector3.new(44, 44, 0.8), frame * CFrame.new(x, 82, -3.4), rgb(136, 44, 36), nil, SHELL)
	box(group, "DoorPanel", Vector3.new(44, 40, 0.8), frame * CFrame.new(x, 30, -3.4), rgb(136, 44, 36), nil, SHELL)
	ball(group, "DoorKnob", 5, (frame * CFrame.new(x + 24, 56, -4)).Position, rgb(226, 182, 72), Material.Metal, SHELL)
end

local function house()
	local group = Kit.folder(room, "House")
	local WALL_HEIGHT, DEPTH, WIDTH = 300, 70, 1040
	local FRONT_Z = HOUSE_Z + DEPTH
	local center = Vector3.new(MID_X, 0, HOUSE_Z + DEPTH / 2)
	box(group, "Body", Vector3.new(WIDTH, WALL_HEIGHT, DEPTH), CFrame.new(center + Vector3.new(0, WALL_HEIGHT / 2, 0)), SIDING, nil, SHELL)
	local backFrame = CFrame.lookAt(Vector3.new(MID_X, 0, HOUSE_Z), Vector3.new(MID_X, 0, HOUSE_Z - 100))
	local frontFrame = CFrame.lookAt(Vector3.new(MID_X, 0, FRONT_Z), Vector3.new(MID_X, 0, FRONT_Z + 100))

	-- Siding boards, and the roof with its gable running along the length of the house.
	for y = 24, WALL_HEIGHT - 12, 24 do
		box(group, "SidingLine", Vector3.new(WIDTH, 1.4, 0.6), backFrame * CFrame.new(0, y, -0.2), SIDING_LINE, nil, SHELL)
		box(group, "SidingLine", Vector3.new(WIDTH, 1.4, 0.6), frontFrame * CFrame.new(0, y, -0.2), SIDING_LINE, nil, SHELL)
	end
	box(group, "Eave", Vector3.new(WIDTH + 24, 6, DEPTH + 28), CFrame.new(center + Vector3.new(0, WALL_HEIGHT + 2, 0)), WHITE, nil, SHELL)
	local half = (DEPTH + 24) / 2
	local roofY = WALL_HEIGHT + 5 + 50
	wedge(group, "Roof", Vector3.new(WIDTH + 20, 100, half), CFrame.new(center + Vector3.new(0, roofY, -half / 2)), ROOF, nil, SHELL)
	wedge(group, "Roof", Vector3.new(WIDTH + 20, 100, half), CFrame.new(center + Vector3.new(0, roofY, half / 2)) * CFrame.Angles(0, math.pi, 0), ROOF, nil, SHELL)
	box(group, "Chimney", Vector3.new(58, 150, 48), CFrame.new(center + Vector3.new(260, WALL_HEIGHT + 70, 0)), BRICK, Material.Brick, SHELL)
	box(group, "ChimneyCap", Vector3.new(66, 7, 56), CFrame.new(center + Vector3.new(260, WALL_HEIGHT + 148, 0)), STONE, nil, SHELL)

	-- The back of the house, facing the yard, with sliding doors onto the patio.
	for x = -400, 400, 160 do
		houseWindow(group, backFrame, x, 222)
	end
	for _, x in { -390, -230, 240, 400 } do
		houseWindow(group, backFrame, x, 84)
		flowerBox(group, backFrame, x, 30)
	end
	box(group, "SliderFrame", Vector3.new(226, 134, 2), backFrame * CFrame.new(0, 67, -1), WHITE, nil, SHELL)
	for _, x in { -55, 55 } do
		box(group, "SliderGlass", Vector3.new(104, 122, 0.8), backFrame * CFrame.new(x, 66, -2.2), GLASS, Material.Glass, SHELL)
	end
	box(group, "SliderBar", Vector3.new(4, 124, 1.4), backFrame * CFrame.new(0, 66, -2.8), WHITE, nil, SHELL)
	box(group, "Step", Vector3.new(240, 7, 30), backFrame * CFrame.new(0, 3.5, -15), STONE, nil, SHELL)

	-- The front, which is what you see from the lobby.
	for x = -400, 400, 160 do
		houseWindow(group, frontFrame, x, 222)
	end
	for _, x in { -390, -230, 240, 400 } do
		houseWindow(group, frontFrame, x, 84)
	end
	door(group, frontFrame, 0)
	box(group, "Step", Vector3.new(110, 7, 30), frontFrame * CFrame.new(0, 3.5, -15), STONE, nil, SHELL)
end

local function patio()
	local group = Kit.folder(room, "Patio")
	local center = Vector3.new(MID_X, 0, HOUSE_Z - 60)
	box(group, "Pavers", Vector3.new(640, 0.8, 120), CFrame.new(center + Vector3.new(0, 0.6, 0)), STONE, Material.Slate, SHELL)
	for x = -280, 280, 80 do
		box(group, "PaverLine", Vector3.new(1, 0.2, 120), CFrame.new(center + Vector3.new(x, 1.05, 0)), rgb(146, 140, 130), nil, SHELL)
	end

	-- A table and chairs under a striped umbrella.
	local spot = center + Vector3.new(-190, 0, 0)
	post(group, "TableLeg", 38, 7, spot + Vector3.new(0, 20, 0), rgb(60, 60, 64), Material.Metal)
	post(group, "TableTop", 3, 80, spot + Vector3.new(0, 40, 0), rgb(245, 240, 230))
	post(group, "UmbrellaPole", 130, 3.4, spot + Vector3.new(0, 66, 0), WHITE)
	local shades = { rgb(220, 60, 50), WHITE }
	for level = 0, 3 do
		post(group, "Umbrella", 5, 124 - level * 34, spot + Vector3.new(0, 124 + level * 5, 0), shades[level % 2 + 1], Material.Fabric)
	end
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		local seat = spot + Vector3.new(math.cos(a) * 56, 0, math.sin(a) * 56)
		local frame = CFrame.lookAt(seat, spot)
		box(group, "ChairSeat", Vector3.new(26, 3, 26), frame * CFrame.new(0, 24, 0), rgb(240, 236, 226))
		box(group, "ChairBack", Vector3.new(26, 30, 3), frame * CFrame.new(0, 39, 13), rgb(240, 236, 226))
		for _, x in { -11, 11 } do
			for _, z in { -11, 11 } do
				box(group, "ChairLeg", Vector3.new(2.4, 23, 2.4), frame * CFrame.new(x, 11.5, z), rgb(60, 60, 64), Material.Metal)
			end
		end
	end

	-- A hose reel by the wall, and a row of flowerpots.
	local reel = center + Vector3.new(190, 0, 44)
	post(group, "ReelStand", 6, 40, reel + Vector3.new(0, 3, 0), rgb(50, 110, 70))
	pipe(group, "HoseReel", reel + Vector3.new(-16, 24, 0), reel + Vector3.new(16, 24, 0), 36, rgb(70, 150, 90))
	for x = 120, 280, 40 do
		local at = center + Vector3.new(x, 0, -52)
		post(group, "Pot", 20, 22, at + Vector3.new(0, 11, 0), TERRACOTTA)
		ball(group, "PotFlowers", 24, at + Vector3.new(0, 30, 0), if x % 80 == 0 then rgb(230, 80, 110) else rgb(250, 190, 60))
	end
end

-- Around the raised bed -----------------------------------------------------------------------------------------------

local function raisedBedSides()
	local group = Kit.folder(room, "RaisedBed")
	local WEST_SIDE, EAST_SIDE, NORTH_SIDE, SOUTH_SIDE = -178, 148, -712, -422
	local widthX, widthZ = EAST_SIDE - WEST_SIDE, SOUTH_SIDE - NORTH_SIDE
	local midX, midZ = (WEST_SIDE + EAST_SIDE) / 2, (NORTH_SIDE + SOUTH_SIDE) / 2
	for row = 0, 2 do
		local y = 6.5 + row * 13.5
		box(group, "Sleeper", Vector3.new(widthX + 4, 13, 2), CFrame.new(midX, y, NORTH_SIDE - 1), TIMBER, Material.Wood)
		box(group, "Sleeper", Vector3.new(widthX + 4, 13, 2), CFrame.new(midX, y, SOUTH_SIDE + 1), TIMBER, Material.Wood)
		box(group, "Sleeper", Vector3.new(2, 13, widthZ + 4), CFrame.new(EAST_SIDE + 1, y, midZ), TIMBER, Material.Wood)
		-- The west side has a gap where the creek runs through.
		box(group, "Sleeper", Vector3.new(2, 13, 141), CFrame.new(WEST_SIDE - 1, y, -642), TIMBER, Material.Wood)
		box(group, "Sleeper", Vector3.new(2, 13, 127), CFrame.new(WEST_SIDE - 1, y, -486), TIMBER, Material.Wood)
	end
	for x = WEST_SIDE, EAST_SIDE, 54 do
		box(group, "BedPost", Vector3.new(6, 40, 3), CFrame.new(x, 20, NORTH_SIDE - 2), TIMBER_DARK, Material.Wood)
		box(group, "BedPost", Vector3.new(6, 40, 3), CFrame.new(x, 20, SOUTH_SIDE + 2), TIMBER_DARK, Material.Wood)
	end
	for z = NORTH_SIDE, SOUTH_SIDE, 58 do
		box(group, "BedPost", Vector3.new(3, 40, 6), CFrame.new(EAST_SIDE + 2, 20, z), TIMBER_DARK, Material.Wood)
		if z < -575 or z > -545 then
			box(group, "BedPost", Vector3.new(3, 40, 6), CFrame.new(WEST_SIDE - 2, 20, z), TIMBER_DARK, Material.Wood)
		end
	end
end

local function sunflower(group: Instance, x: number, z: number, height: number)
	post(group, "SunflowerStem", height, 3, Vector3.new(x, height / 2, z), rgb(84, 140, 60))
	local head = Vector3.new(x, height, z)
	local face = CFrame.lookAt(head, Vector3.new(-15, height, -570)) -- they all face the middle of the garden
	pipe(group, "SunflowerPetals", head, head + face.LookVector * 1.2, 30, rgb(255, 205, 40))
	pipe(group, "SunflowerMiddle", head + face.LookVector * 0.6, head + face.LookVector * 1.8, 15, rgb(110, 66, 30))
	local leafAt = Vector3.new(x, height * 0.55, z)
	box(group, "SunflowerLeaf", Vector3.new(16, 1, 8), CFrame.new(leafAt) * CFrame.Angles(0, 0, math.rad(20)), rgb(84, 150, 66))
end

local function sunflowers()
	local group = Kit.folder(room, "Sunflowers")
	local i = 0
	for x = -165, 135, 44 do
		i += 1
		sunflower(group, x, -398, 66 + i % 3 * 12)
		sunflower(group, x + 12, -734, 72 + i % 3 * 12)
	end
	for z = -700, -430, 48 do
		i += 1
		sunflower(group, 170, z, 70 + i % 3 * 12)
	end
end

local function vegetablePatches()
	local group = Kit.folder(room, "Vegetables")

	-- Cabbages on the west side.
	local soil = rgb(92, 62, 40)
	box(group, "Soil", Vector3.new(90, 3, 150), CFrame.new(-262, 1.5, -720), soil, Material.Ground)
	for x = -290, -234, 28 do
		for z = -780, -660, 30 do
			ball(group, "Cabbage", 21, Vector3.new(x, 9, z), rgb(120, 180, 90))
			ball(group, "CabbageHeart", 12, Vector3.new(x, 16, z), rgb(170, 215, 130))
		end
	end

	-- Tomato plants in wire cages near the pond.
	box(group, "Soil", Vector3.new(70, 3, 110), CFrame.new(-250, 1.5, -450), soil, Material.Ground)
	for z = -490, -410, 40 do
		for _, x in { -266, -234 } do
			post(group, "Cage", 44, 16, Vector3.new(x, 22, z), rgb(90, 150, 70), Material.Grass, { Transparency = 0.1 })
			for i = 1, 4 do
				local a = i * 1.7
				ball(group, "Tomato", 6, Vector3.new(x + math.cos(a) * 8, 14 + i * 7, z + math.sin(a) * 8), rgb(225, 45, 35))
			end
		end
	end

	-- A carrot patch on the east side, with the tops showing.
	box(group, "Soil", Vector3.new(60, 3, 130), CFrame.new(226, 1.5, -640), soil, Material.Ground)
	for z = -695, -585, 22 do
		for _, x in { 212, 240 } do
			post(group, "CarrotTop", 5, 7, Vector3.new(x, 5, z), rgb(236, 120, 40))
			ball(group, "CarrotLeaves", 12, Vector3.new(x, 13, z), rgb(90, 170, 70), Material.Grass)
		end
	end
end

local function pond()
	local group = Kit.folder(room, "Pond")
	local center = map.Ground.Pond.Position
	local half = map.Ground.Pond.Size / 2
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local at = center + Vector3.new(math.cos(a) * (half.X + 3), 2, math.sin(a) * (half.Z + 3))
		ball(group, "PondStone", 8 + i % 3 * 3, at, if i % 2 == 0 then STONE else rgb(150, 145, 136))
	end
	for _, offset in { Vector3.new(-9, 0, -10), Vector3.new(8, 0, 6), Vector3.new(-5, 0, 13) } do
		post(group, "LilyPad", 0.3, 9, center + offset + Vector3.new(0, 0.5, 0), rgb(80, 165, 80))
		ball(group, "LilyFlower", 3.4, center + offset + Vector3.new(0, 1.6, 0), rgb(250, 170, 200))
	end
end

local function gnome(group: Instance, position: Vector3, facing: number)
	local scale = 1.6
	local frame = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local at = function(x, y, z)
		return (frame * CFrame.new(x * scale, y * scale, z * scale)).Position
	end
	post(group, "GnomeBoots", 2, 9 * scale, at(0, 1, 0), rgb(50, 40, 34))
	post(group, "GnomeBody", 10, 9 * scale, at(0, 7, 0), rgb(50, 90, 170))
	ball(group, "GnomeHead", 8 * scale, at(0, 15, 0), rgb(255, 205, 170))
	ball(group, "GnomeBeard", 7 * scale, at(0, 12.4, -2.4), WHITE)
	ball(group, "GnomeNose", 2.4 * scale, at(0, 15, -4), rgb(240, 150, 130))
	local RED = rgb(210, 45, 40)
	for level = 0, 3 do
		post(group, "GnomeHat", 3.2 * scale, (9 - level * 2.2) * scale, at(0, 19 + level * 3.1, 0), RED)
	end
end

local function wheelbarrow(group: Instance, position: Vector3, facing: number)
	local frame = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local green = rgb(60, 130, 90)
	box(group, "BarrowTub", Vector3.new(34, 14, 48), frame * CFrame.new(0, 24, 0), green, Material.Metal)
	box(group, "BarrowSoil", Vector3.new(30, 1.4, 44), frame * CFrame.new(0, 31, 0), rgb(92, 62, 40), Material.Ground)
	local wheel = (frame * CFrame.new(0, 10, -30)).Position
	pipe(group, "BarrowWheel", wheel - frame.RightVector * 3, wheel + frame.RightVector * 3, 20, rgb(40, 40, 44))
	for _, side in { -1, 1 } do
		local a = (frame * CFrame.new(side * 15, 18, -28)).Position
		local b = (frame * CFrame.new(side * 15, 28, 44)).Position
		pipe(group, "BarrowHandle", a, b, 2.6, rgb(150, 110, 70))
		box(group, "BarrowLeg", Vector3.new(2.4, 18, 2.4), frame * CFrame.new(side * 15, 9, 18), green, Material.Metal)
	end
end

local function birdbath(group: Instance, position: Vector3)
	post(group, "BathStem", 34, 11, position + Vector3.new(0, 17, 0), STONE)
	post(group, "BathBase", 3, 26, position + Vector3.new(0, 1.5, 0), STONE)
	post(group, "BathBowl", 5, 44, position + Vector3.new(0, 36, 0), STONE)
	post(group, "BathWater", 5.2, 36, position + Vector3.new(0, 36.1, 0), rgb(120, 190, 225), Material.Glass)
end

local function wateringCan(group: Instance, position: Vector3)
	local blue = rgb(70, 140, 180)
	post(group, "CanBody", 24, 22, position + Vector3.new(0, 12, 0), blue, Material.Metal)
	pipe(group, "CanSpout", position + Vector3.new(9, 8, 0), position + Vector3.new(28, 28, 0), 4, blue, Material.Metal)
	post(group, "CanRose", 2, 8, position + Vector3.new(29, 29, 0), blue, Material.Metal)
	box(group, "CanHandle", Vector3.new(2, 2, 22), CFrame.new(position + Vector3.new(0, 28, 0)), blue, Material.Metal)
end

local function shed(group: Instance)
	local origin = CFrame.new(360, 0, -900) -- its doors face the garden, which is +Z from here
	local green = rgb(116, 150, 118)
	box(group, "ShedBody", Vector3.new(170, 120, 130), origin * CFrame.new(0, 60, 0), green, Material.WoodPlanks)
	box(group, "ShedEave", Vector3.new(182, 4, 142), origin * CFrame.new(0, 121, 0), WHITE)
	wedge(group, "ShedRoof", Vector3.new(182, 56, 71), origin * CFrame.new(0, 151, -35.5), ROOF)
	wedge(group, "ShedRoof", Vector3.new(182, 56, 71), origin * CFrame.new(0, 151, 35.5) * CFrame.Angles(0, math.pi, 0), ROOF)
	for _, side in { -1, 1 } do
		local doorAt = origin * CFrame.new(side * 26, 48, 65.6)
		box(group, "ShedDoor", Vector3.new(50, 96, 1.2), doorAt, WHITE, Material.Wood)
		-- Crossed braces, like a barn door.
		box(group, "ShedBrace", Vector3.new(5, 104, 0.8), doorAt * CFrame.new(0, 0, 0.8) * CFrame.Angles(0, 0, math.rad(side * 27)), green)
	end
	box(group, "ShedWindow", Vector3.new(1, 44, 56), origin * CFrame.new(-85.5, 74, 0), GLASS, Material.Glass)
	box(group, "ShedWindowBar", Vector3.new(1.4, 3, 58), origin * CFrame.new(-85.7, 74, 0), WHITE)
	flowerBox(group, CFrame.lookAt((origin * CFrame.new(-85, 0, 0)).Position, (origin * CFrame.new(-185, 0, 0)).Position), 0, 46)
end

local function swingSet(group: Instance, position: Vector3)
	local red, yellow = rgb(215, 60, 50), rgb(245, 195, 50)
	local LENGTH, HEIGHT, SPREAD = 150, 112, 42
	for _, end_ in { -1, 1 } do
		local top = position + Vector3.new(0, HEIGHT, end_ * LENGTH / 2)
		pipe(group, "SwingLeg", top, position + Vector3.new(-SPREAD, 0, end_ * LENGTH / 2), 6, red, Material.Metal)
		pipe(group, "SwingLeg", top, position + Vector3.new(SPREAD, 0, end_ * LENGTH / 2), 6, red, Material.Metal)
	end
	pipe(group, "SwingBar", position + Vector3.new(0, HEIGHT, -LENGTH / 2), position + Vector3.new(0, HEIGHT, LENGTH / 2), 6, yellow, Material.Metal)
	for _, z in { -38, 38 } do
		for _, offset in { -9, 9 } do
			box(group, "SwingRope", Vector3.new(0.8, HEIGHT - 26, 0.8), CFrame.new(position + Vector3.new(0, (HEIGHT + 26) / 2, z + offset)), rgb(70, 70, 74))
		end
		box(group, "SwingSeat", Vector3.new(10, 2, 24), CFrame.new(position + Vector3.new(0, 26, z)), yellow)
	end
end

local function trampoline(group: Instance, position: Vector3)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		post(group, "TrampolineLeg", 26, 4, position + Vector3.new(math.cos(a) * 66, 13, math.sin(a) * 66), rgb(60, 60, 66), Material.Metal)
	end
	post(group, "TrampolineRim", 5, 150, position + Vector3.new(0, 27, 0), rgb(50, 120, 200))
	post(group, "TrampolineMat", 5.4, 124, position + Vector3.new(0, 27, 0), rgb(30, 30, 34))
end

local function tree(group: Instance, x: number, z: number, height: number, seed: number)
	local random = Random.new(seed)
	local colors = { rgb(226, 120, 40), rgb(205, 66, 42), rgb(240, 175, 50), rgb(190, 100, 40) }
	post(group, "Trunk", height, 36, Vector3.new(x, height / 2, z), rgb(92, 64, 44), Material.Wood, SHELL)
	ball(group, "Leaves", 150, Vector3.new(x, height + 50, z), colors[random:NextInteger(1, #colors)], Material.Grass, SHELL)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + random:NextNumber()
		local at = Vector3.new(x + math.cos(a) * 80, height + random:NextNumber(-10, 50), z + math.sin(a) * 80)
		ball(group, "Leaves", random:NextNumber(90, 125), at, colors[i % #colors + 1], Material.Grass, SHELL)
	end
end

local function neighbour(group: Instance, x: number, z: number, color: Color3)
	box(group, "NeighbourHouse", Vector3.new(320, 220, 170), CFrame.new(x, 110, z), color, nil, SHELL)
	wedge(group, "NeighbourRoof", Vector3.new(336, 80, 92), CFrame.new(x, 260, z - 46), ROOF, nil, SHELL)
	wedge(group, "NeighbourRoof", Vector3.new(336, 80, 92), CFrame.new(x, 260, z + 46) * CFrame.Angles(0, math.pi, 0), ROOF, nil, SHELL)
	for _, ox in { -90, 90 } do
		box(group, "NeighbourWindow", Vector3.new(60, 70, 1), CFrame.new(x + ox, 150, z + 85.6), GLASS, Material.Glass, SHELL)
	end
end

local function garden()
	raisedBedSides()
	sunflowers()
	vegetablePatches()
	pond()

	local things = Kit.folder(room, "GardenThings")
	shed(things)
	swingSet(things, Vector3.new(-400, 0, -600))
	trampoline(things, Vector3.new(340, 0, -420))
	wheelbarrow(things, Vector3.new(232, 0, -510), math.rad(-30))
	birdbath(things, Vector3.new(-262, 0, -590))
	wateringCan(things, Vector3.new(-212, 0, -392))
	gnome(things, Vector3.new(-196, 0, -420), math.rad(135))
	gnome(things, Vector3.new(170, 0, -400), math.rad(-140))
	gnome(things, Vector3.new(-212, 0, -700), math.rad(60))
	gnome(things, Vector3.new(180, 0, -730), math.rad(-60))

	local trees = Kit.folder(room, "Trees")
	tree(trees, -440, -900, 170, 1)
	tree(trees, -430, -400, 150, 2)
	tree(trees, -180, -950, 180, 3)
	tree(trees, 120, -950, 160, 4)
	tree(trees, 420, -700, 170, 5)
	tree(trees, 430, -340, 150, 6)
	tree(trees, -640, -720, 210, 7)
	tree(trees, 620, -560, 220, 8)
	tree(trees, -20, -1120, 200, 9)

	neighbour(trees, -330, -1230, rgb(214, 196, 170))
	neighbour(trees, 340, -1240, rgb(186, 200, 210))
end

-- The barbecue in the middle, with the chef on top -----------------------------------------------------------------------

local function barbecue()
	local group = Kit.folder(room, "Barbecue")
	local at = function(x, y, z)
		return CFrame.new(BBQ + Vector3.new(x, y, z))
	end
	box(group, "BBQPatio", Vector3.new(170, 0.6, 96), at(0, 0.3, 0), STONE, Material.Slate)
	box(group, "BBQBase", Vector3.new(112, 28, 78), at(0, 14, 0), BRICK, Material.Brick)
	box(group, "BBQSlab", Vector3.new(120, 3, 86), at(0, 29.5, 0), STONE)
	box(group, "BBQFireBox", Vector3.new(72, 1, 52), at(0, 31.4, 0), rgb(40, 34, 32))
	local coals = box(group, "BBQCoals", Vector3.new(66, 0.8, 46), at(0, 32, 0), rgb(255, 110, 30), Material.Neon)
	Kit.light(coals, rgb(255, 150, 70), 45, 2.5)
	for x = -30, 30, 10 do
		box(group, "BBQGrate", Vector3.new(1.4, 1, 54), at(x, 33, 0), rgb(50, 50, 54), Material.Metal)
	end
	for _, side in { -1, 1 } do
		box(group, "BBQGrateRail", Vector3.new(72, 1, 1.4), at(0, 33.4, side * 26), rgb(50, 50, 54), Material.Metal)
		-- Sausages either side of his boots.
		for i = 0, 2 do
			local start = BBQ + Vector3.new(side * (24 + i * 4 - 8), 35, -16 + i * 16)
			pipe(group, "Sausage", start - Vector3.new(7, 0, 0), start + Vector3.new(7, 0, 0), 4, rgb(150, 76, 44))
		end
	end
	Kit.chefSpot(map, BBQ + Vector3.new(0, 33.6, 0), Vector3.new(0, 0, 1))

	-- A chimney with smoke coming out, off to one side.
	box(group, "BBQChimney", Vector3.new(22, 74, 22), at(62, 36, -30), BRICK, Material.Brick)
	local cap = box(group, "BBQChimneyCap", Vector3.new(28, 4, 28), at(62, 75, -30), STONE)
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(220, 220, 220)
	smoke.Opacity = 0.2
	smoke.RiseVelocity = 10
	smoke.Size = 16
	smoke.Parent = cap

	-- What he throws, close to hand.
	local crate = at(-46, 35, 30)
	box(group, "Crate", Vector3.new(22, 8, 16), crate * CFrame.new(0, -1, 0), rgb(176, 124, 74), Material.Wood)
	for _, x in { -6, 0, 6 } do
		ball(group, "Tomato", 6.5, (crate * CFrame.new(x, 4, 0)).Position, rgb(225, 45, 35))
	end
	for level = 0, 3 do
		post(group, "Pie", 2.2, 15, BBQ + Vector3.new(46, 32 + level * 2.3, 30), rgb(220, 160, 80))
	end
end

restyle()
lawn()
fences()
house()
patio()
garden()
barbecue()

-- Rows a turkey's length apart, reaching back toward the corner behind the finish line.
Kit.layPads(map, {
	{ 106, -502 }, { 134, -502 },
	{ 106, -488 }, { 134, -488 },
	{ 106, -474 }, { 134, -474 },
	{ 106, -460 }, { 134, -460 },
})

local count = 0
for _, d in room:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print("Backyard built:", count, "parts")
return count
