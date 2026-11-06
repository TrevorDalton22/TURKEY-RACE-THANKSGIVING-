-- Thanksgiving Dinner Dash: turns the table into the middle of a grand dining room, with the chef standing on a silver
-- cake stand in the center of the table. See Kit.luau for how to run this.

local Kit = loadstring(game:GetService("ServerScriptService").Server.MapBuilders.Kit.Source)()
local box, ball, post, pipe = Kit.box, Kit.ball, Kit.post, Kit.pipe
local rgb = Color3.fromRGB
local Material = Enum.Material

local map = workspace.Maps.DinnerDash
local room = Kit.fresh(map, "Room")

local HALF_X, NEAR_Z, FAR_Z, HEIGHT = 430, 220, 780, 280
local MID_Z = (NEAR_Z + FAR_Z) / 2
local WIDTH_X, WIDTH_Z = HALF_X * 2, FAR_Z - NEAR_Z

local PAPER, PAPER_STRIPE = rgb(34, 72, 66), rgb(44, 86, 78)
local MAHOGANY, MAHOGANY_DARK = rgb(96, 48, 30), rgb(62, 30, 20)
local GOLD = rgb(226, 182, 72)
local CREAM = rgb(244, 236, 218)
local BURGUNDY, BURGUNDY_DARK = rgb(140, 32, 46), rgb(104, 22, 36)
local IVORY = rgb(250, 245, 232)
-- The cloth is the track, so it's darker than it would really be: bright white washes out everything on it.
local LINEN = rgb(224, 208, 178)
local CHAMPAGNE = rgb(204, 184, 146)
local SILVER = rgb(205, 210, 218)
local SKY = rgb(205, 232, 252)
local FLAME = rgb(255, 170, 60)
local CANDLE = rgb(250, 240, 215)
local LEAF = rgb(60, 120, 70)

local SHELL = { CastShadow = false }

-- The table -----------------------------------------------------------------------------------------------------------

local function restyleTable()
	local tableFolder = map.Table
	for _, name in { "South", "NorthA", "NorthB", "West", "East" } do
		tableFolder[name].Color = LINEN
	end
	tableFolder.Runner.Color = BURGUNDY
	for _, tile in tableFolder.Checks:GetChildren() do
		tile.Color = CHAMPAGNE
	end
	for _, stripe in tableFolder.RunnerStripes:GetChildren() do
		stripe.Color = GOLD
	end

	local group = Kit.folder(room, "Table")
	for _, leg in tableFolder:GetChildren() do
		if leg.Name == "Leg" then
			leg.Color = MAHOGANY_DARK
			ball(group, "LegTurn", 22, leg.Position + Vector3.new(0, -8, 0), MAHOGANY)
			post(group, "LegRing", 3, 18, leg.Position + Vector3.new(0, -2, 0), GOLD, Material.Metal)
			post(group, "LegFoot", 3, 20, Vector3.new(leg.Position.X, 1.8, leg.Position.Z), GOLD, Material.Metal)
		end
	end

	-- The cloth hangs over all four edges.
	for _, side in { -1, 1 } do
		local z = MID_Z + side * 140.5
		box(group, "ClothSkirt", Vector3.new(422, 20, 1), CFrame.new(0, 29.5, z), LINEN, Material.Fabric)
		box(group, "ClothHem", Vector3.new(422, 1.6, 1.3), CFrame.new(0, 20, z), GOLD)
		local x = side * 210.5
		box(group, "ClothSkirt", Vector3.new(1, 20, 282), CFrame.new(x, 29.5, MID_Z), LINEN, Material.Fabric)
		box(group, "ClothHem", Vector3.new(1.3, 1.6, 282), CFrame.new(x, 20, MID_Z), GOLD)
	end
end

local function dressCenterpiece()
	local center = map.Centerpiece
	for _, part in center:GetChildren() do
		if part.Name == "Garnish" then
			part:Destroy()
		end
	end

	-- The roast moves over to make room for the chef.
	local ROAST_X = -92
	center.RoastBody.Position = Vector3.new(ROAST_X, 64, MID_Z)
	for _, part in center:GetChildren() do
		if part.Name == "Drumstick" or part.Name == "Bone" then
			-- They start 14 either side of the middle of the table, or of the roast if this has run before.
			local from = if part.Position.X < -50 then ROAST_X else 0
			part.Position = Vector3.new(ROAST_X + math.sign(part.Position.X - from) * 14, part.Position.Y, part.Position.Z)
		end
	end

	local group = Kit.folder(room, "Centerpiece")
	post(group, "RoastPlatter", 1.6, 84, Vector3.new(ROAST_X, 44.8, MID_Z), SILVER, Material.Metal)
	post(group, "RoastWell", 1.7, 72, Vector3.new(ROAST_X, 44.9, MID_Z), IVORY)

	-- A pie on the other side, so the table stays balanced.
	post(group, "PiePlatter", 1.6, 84, Vector3.new(92, 44.8, MID_Z), SILVER, Material.Metal)
	post(group, "PieCrust", 9, 62, Vector3.new(92, 50, MID_Z), rgb(222, 165, 90))
	post(group, "PieFilling", 9.4, 52, Vector3.new(92, 50.1, MID_Z), rgb(232, 125, 45))
	for i = 1, 8 do
		local a = i * math.pi / 4
		ball(group, "PieCream", 7, Vector3.new(92 + math.cos(a) * 19, 55.4, MID_Z + math.sin(a) * 19), rgb(255, 250, 235))
	end

	-- The chef's cake stand.
	post(group, "StandBase", 2.5, 40, Vector3.new(0, 46.8, MID_Z), SILVER, Material.Metal)
	post(group, "StandStem", 10, 13, Vector3.new(0, 52, MID_Z), SILVER, Material.Metal)
	ball(group, "StandKnob", 16, Vector3.new(0, 52, MID_Z), GOLD, Material.Metal)
	post(group, "StandPlate", 2.4, 62, Vector3.new(0, 58.2, MID_Z), SILVER, Material.Metal)
	post(group, "StandRim", 1, 66, Vector3.new(0, 57.4, MID_Z), GOLD, Material.Metal)
	Kit.chefSpot(map, Vector3.new(0, 59.4, MID_Z), Vector3.new(0, 0, -1))

	-- Candelabras in front of and behind him.
	for _, z in { MID_Z - 50, MID_Z + 50 } do
		post(group, "CandelabraBase", 2, 18, Vector3.new(0, 45, z), GOLD, Material.Metal)
		post(group, "CandelabraStem", 26, 3, Vector3.new(0, 58, z), GOLD, Material.Metal)
		box(group, "CandelabraArm", Vector3.new(30, 2, 2), CFrame.new(0, 68, z), GOLD, Material.Metal)
		for _, x in { -15, 0, 15 } do
			local top = if x == 0 then 74 else 69
			if x ~= 0 then
				post(group, "CandleCup", 2, 6, Vector3.new(x, 70, z), GOLD, Material.Metal)
			end
			post(group, "Candle", 10, 3, Vector3.new(x, top + 6, z), CANDLE)
			ball(group, "Flame", 3.4, Vector3.new(x, top + 12.6, z), FLAME, Material.Neon)
		end
	end
end

local function chair(group: Instance, x: number, z: number, toward: Vector3)
	local position = Vector3.new(x, 0, z)
	local frame = CFrame.lookAt(position, position + toward)
	for _, cx in { -15, 15 } do
		for _, cz in { -15, 15 } do
			post(group, "ChairLeg", 24, 3.6, (frame * CFrame.new(cx, 12, cz)).Position, MAHOGANY_DARK, Material.Wood)
		end
		box(group, "ChairStile", Vector3.new(3.6, 66, 3.6), frame * CFrame.new(cx * 1.05, 59, 16.5), MAHOGANY_DARK, Material.Wood)
		ball(group, "ChairFinial", 5, (frame * CFrame.new(cx * 1.05, 94, 16.5)).Position, GOLD, Material.Metal)
	end
	box(group, "ChairSeat", Vector3.new(37, 4, 37), frame * CFrame.new(0, 26, 0), MAHOGANY, Material.Wood)
	box(group, "ChairCushion", Vector3.new(33, 3.4, 33), frame * CFrame.new(0, 29.5, 0), BURGUNDY, Material.Fabric)
	box(group, "ChairRail", Vector3.new(36, 6, 3.6), frame * CFrame.new(0, 89, 16.5), MAHOGANY, Material.Wood)
	box(group, "ChairPad", Vector3.new(26, 44, 2.4), frame * CFrame.new(0, 61, 16.5), BURGUNDY, Material.Fabric)
end

local function placeChairs()
	local group = Kit.folder(room, "Chairs")
	for _, x in { -150, -50, 50, 150 } do
		chair(group, x, 336, Vector3.new(0, 0, 1))
		chair(group, x, 664, Vector3.new(0, 0, -1))
	end
	chair(group, -234, MID_Z, Vector3.new(1, 0, 0))
	chair(group, 234, MID_Z, Vector3.new(-1, 0, 0))
end

-- Floor and ceiling ---------------------------------------------------------------------------------------------------

local function floorAndCeiling()
	local group = Kit.folder(room, "FloorCeiling")
	box(group, "Floor", Vector3.new(WIDTH_X + 16, 0.4, WIDTH_Z + 16), CFrame.new(0, 0.2, MID_Z), rgb(112, 66, 38), Material.WoodPlanks, SHELL)
	box(group, "RugBorder", Vector3.new(660, 0.3, 450), CFrame.new(0, 0.5, MID_Z), BURGUNDY_DARK, Material.Fabric)
	box(group, "RugLine", Vector3.new(632, 0.3, 422), CFrame.new(0, 0.56, MID_Z), GOLD, Material.Fabric)
	box(group, "RugField", Vector3.new(622, 0.3, 412), CFrame.new(0, 0.62, MID_Z), BURGUNDY, Material.Fabric)

	box(group, "Ceiling", Vector3.new(WIDTH_X + 24, 6, WIDTH_Z + 24), CFrame.new(0, HEIGHT + 3, MID_Z), CREAM, nil, SHELL)
	for z = NEAR_Z + 112, FAR_Z - 112, 112 do
		box(group, "CeilingBeam", Vector3.new(WIDTH_X, 7, 10), CFrame.new(0, HEIGHT - 3.5, z), rgb(226, 212, 184), nil, SHELL)
	end
	for x = -HALF_X + 143, HALF_X - 143, 143.5 do
		box(group, "CeilingBeam", Vector3.new(10, 7, WIDTH_Z), CFrame.new(x, HEIGHT - 3.5, MID_Z), rgb(226, 212, 184), nil, SHELL)
	end
end

-- Walls ---------------------------------------------------------------------------------------------------------------

-- `frame` sits on the floor in the middle of the wall's inside face, looking into the room, so into the room is -Z.
local function wall(group: Instance, frame: CFrame, width: number)
	box(group, "Wall", Vector3.new(width + 16, HEIGHT, 8), frame * CFrame.new(0, HEIGHT / 2, 4), PAPER, Material.Fabric, SHELL)
	box(group, "Outside", Vector3.new(width + 22, HEIGHT + 6, 1), frame * CFrame.new(0, HEIGHT / 2 + 3, 8.6), rgb(238, 225, 200), nil, SHELL)

	local stripeHeight = HEIGHT - 84 - 30
	local x = -width / 2 + 18
	while x < width / 2 do
		box(group, "Stripe", Vector3.new(16, stripeHeight, 0.4), frame * CFrame.new(x, 84 + stripeHeight / 2, -0.2), PAPER_STRIPE, Material.Fabric, SHELL)
		x += 36
	end

	box(group, "Wainscot", Vector3.new(width, 72, 2), frame * CFrame.new(0, 48, -1), MAHOGANY, Material.Wood, SHELL)
	box(group, "Baseboard", Vector3.new(width, 12, 3.4), frame * CFrame.new(0, 6, -1.7), MAHOGANY_DARK, Material.Wood, SHELL)
	box(group, "ChairRail", Vector3.new(width, 5, 4), frame * CFrame.new(0, 84, -2), GOLD, Material.Metal, SHELL)
	local count = math.floor(width / 62)
	local spacing = width / count
	for i = 1, count do
		box(group, "Panel", Vector3.new(spacing - 14, 50, 1.2), frame * CFrame.new(-width / 2 + (i - 0.5) * spacing, 46, -2.4), MAHOGANY_DARK, Material.Wood, SHELL)
	end
	box(group, "Frieze", Vector3.new(width, 22, 1.4), frame * CFrame.new(0, HEIGHT - 21, -0.7), CREAM, nil, SHELL)
	box(group, "FriezeGold", Vector3.new(width, 3, 2), frame * CFrame.new(0, HEIGHT - 33, -1), GOLD, Material.Metal, SHELL)
	box(group, "Crown", Vector3.new(width, 10, 5), frame * CFrame.new(0, HEIGHT - 5, -2.5), CREAM, nil, SHELL)
end

local function window(group: Instance, frame: CFrame, x: number)
	local WIDTH, BOTTOM, TOP = 100, 92, 226
	local height = TOP - BOTTOM
	local at = function(ox, oy, oz)
		return frame * CFrame.new(x + ox, oy, oz)
	end
	box(group, "WindowGlass", Vector3.new(WIDTH, height, 1), at(0, BOTTOM + height / 2, -0.8), SKY, Material.Neon, SHELL)
	for _, side in { -1, 1 } do
		box(group, "WindowFrame", Vector3.new(6, height + 4, 4), at(side * (WIDTH / 2 + 3), BOTTOM + height / 2, -2), CREAM, nil, SHELL)
		box(group, "WindowBar", Vector3.new(3, height, 2.4), at(side * WIDTH / 6, BOTTOM + height / 2, -2.6), CREAM, nil, SHELL)
	end
	box(group, "WindowSill", Vector3.new(WIDTH + 18, 4, 7), at(0, BOTTOM - 1, -3.5), CREAM, nil, SHELL)
	box(group, "WindowTop", Vector3.new(WIDTH + 12, 6, 4), at(0, TOP, -2), CREAM, nil, SHELL)
	for _, y in { BOTTOM + 45, BOTTOM + 90 } do
		box(group, "WindowBar", Vector3.new(WIDTH, 3, 2.4), at(0, y, -2.6), CREAM, nil, SHELL)
	end

	-- Floor-length curtains, drawn back with a gold tie, under a valance.
	for _, side in { -1, 1 } do
		for fold = 0, 2 do
			local color = if fold == 1 then BURGUNDY_DARK else BURGUNDY
			box(group, "Curtain", Vector3.new(9, 226, 5 + fold % 2 * 2), at(side * (WIDTH / 2 + 8 + fold * 8), 124, -7), color, Material.Fabric, SHELL)
		end
		box(group, "CurtainTie", Vector3.new(28, 4, 9), at(side * (WIDTH / 2 + 16), 92, -8), GOLD, Material.Metal, SHELL)
	end
	box(group, "Valance", Vector3.new(WIDTH + 62, 24, 8), at(0, 244, -8), BURGUNDY, Material.Fabric, SHELL)
	box(group, "ValanceHem", Vector3.new(WIDTH + 64, 3, 9), at(0, 232, -8), GOLD, Material.Metal, SHELL)
end

local function sconce(group: Instance, frame: CFrame, x: number)
	local at = function(ox, oy, oz)
		return frame * CFrame.new(x + ox, oy, oz)
	end
	box(group, "SconcePlate", Vector3.new(7, 15, 1.4), at(0, 130, -0.8), GOLD, Material.Metal, SHELL)
	box(group, "SconceArm", Vector3.new(2, 2, 10), at(0, 126, -5), GOLD, Material.Metal, SHELL)
	post(group, "SconceCup", 2, 7, at(0, 127, -10).Position, GOLD, Material.Metal, SHELL)
	post(group, "SconceCandle", 11, 3.4, at(0, 133, -10).Position, CANDLE, nil, SHELL)
	ball(group, "SconceFlame", 4, at(0, 140.6, -10).Position, FLAME, Material.Neon, SHELL)
end

local function portrait(group: Instance, frame: CFrame, x: number, y: number, width: number, height: number, picture: string, title: string)
	local at = function(oy, oz)
		return frame * CFrame.new(x, oy, oz)
	end
	box(group, "PortraitFrame", Vector3.new(width + 10, height + 10, 2.4), at(y, -1.2), GOLD, Material.Metal, SHELL)
	local canvas = box(group, "Portrait", Vector3.new(width, height, 0.6), at(y, -2.6), rgb(52, 40, 34), nil, SHELL)
	Kit.sign(canvas, picture, Color3.new(1, 1, 1))
	local plaque = box(group, "Plaque", Vector3.new(width * 0.9, 6, 0.6), at(y - height / 2 - 11, -1), GOLD, Material.Metal, SHELL)
	Kit.sign(plaque, title, rgb(60, 36, 16), nil, nil, Enum.Font.Garamond)
end

local function walls()
	local group = Kit.folder(room, "Walls")
	local windows = Kit.folder(room, "Windows")
	local art = Kit.folder(room, "Art")
	local titles = {
		{ "🦃", "Sir Thomas Gobble" },
		{ "👑", "The Queen Hen" },
		{ "🍗", "Uncle Drumstick, Sadly Missed" },
		{ "🥧", "Aunt Pumpkin" },
	}

	local east = CFrame.lookAt(Vector3.new(HALF_X, 0, MID_Z), Vector3.new(0, 0, MID_Z))
	local west = CFrame.lookAt(Vector3.new(-HALF_X, 0, MID_Z), Vector3.new(0, 0, MID_Z))
	for i, frame in { east, west } do
		wall(group, frame, WIDTH_Z)
		for _, x in { -140, 140 } do
			window(windows, frame, x)
		end
		-- A portrait between the windows with a sconce either side, and another out toward the corner.
		sconce(art, frame, -46)
		sconce(art, frame, 46)
		for j, x in { 0, -249 } do
			local entry = titles[(i - 1) * 2 + j]
			portrait(art, frame, x, 170, 44, 56, entry[1], entry[2])
		end
	end
	wall(group, CFrame.lookAt(Vector3.new(0, 0, NEAR_Z), Vector3.new(0, 0, MID_Z)), WIDTH_X)
	wall(group, CFrame.lookAt(Vector3.new(0, 0, FAR_Z), Vector3.new(0, 0, MID_Z)), WIDTH_X)
end

-- Furniture along the end walls ---------------------------------------------------------------------------------------

local function doors()
	local group = Kit.folder(room, "Doors")
	local frame = CFrame.lookAt(Vector3.new(0, 0, NEAR_Z), Vector3.new(0, 0, MID_Z))
	box(group, "DoorSurround", Vector3.new(156, 176, 3), frame * CFrame.new(0, 88, -1.5), CREAM, nil, SHELL)
	box(group, "DoorPediment", Vector3.new(176, 10, 8), frame * CFrame.new(0, 181, -4), GOLD, Material.Metal, SHELL)
	for _, side in { -1, 1 } do
		box(group, "Door", Vector3.new(66, 160, 3), frame * CFrame.new(side * 34, 80, -4), MAHOGANY, Material.Wood, SHELL)
		for _, y in { 44, 118 } do
			box(group, "DoorPanel", Vector3.new(46, 56, 1.2), frame * CFrame.new(side * 34, y, -6), MAHOGANY_DARK, Material.Wood, SHELL)
		end
		ball(group, "DoorKnob", 6, (frame * CFrame.new(side * 8, 76, -7)).Position, GOLD, Material.Metal, SHELL)
	end
end

local function chinaCabinet(group: Instance, x: number)
	local frame = CFrame.lookAt(Vector3.new(x, 0, NEAR_Z), Vector3.new(x, 0, MID_Z))
	box(group, "CabinetBody", Vector3.new(124, 190, 30), frame * CFrame.new(0, 95, -15), MAHOGANY, Material.Wood)
	box(group, "CabinetCrown", Vector3.new(136, 10, 36), frame * CFrame.new(0, 195, -16), MAHOGANY_DARK, Material.Wood)
	box(group, "CabinetBack", Vector3.new(106, 116, 1), frame * CFrame.new(0, 132, -30.4), rgb(226, 214, 190))
	for _, y in { 88, 126, 164 } do
		box(group, "CabinetShelf", Vector3.new(106, 2.4, 1.4), frame * CFrame.new(0, y - 15, -31), MAHOGANY_DARK, Material.Wood)
		for px = -38, 38, 25.3 do
			local plate = (frame * CFrame.new(px, y, -31.5)).Position
			pipe(group, "Plate", plate, plate + frame.LookVector * 1, 22, IVORY)
			pipe(group, "PlateRim", plate + frame.LookVector * 1, plate + frame.LookVector * 1.3, 14, BURGUNDY)
		end
	end
	for _, side in { -1, 1 } do
		box(group, "CabinetFrame", Vector3.new(7, 190, 2), frame * CFrame.new(side * 58.5, 95, -31), MAHOGANY_DARK, Material.Wood)
		box(group, "CabinetDoor", Vector3.new(50, 54, 1.4), frame * CFrame.new(side * 27, 36, -30.6), MAHOGANY_DARK, Material.Wood)
		ball(group, "CabinetKnob", 4, (frame * CFrame.new(side * 6, 36, -32)).Position, GOLD, Material.Metal)
	end
end

local function fireplace()
	local group = Kit.folder(room, "Fireplace")
	local frame = CFrame.lookAt(Vector3.new(0, 0, FAR_Z), Vector3.new(0, 0, MID_Z))
	box(group, "Surround", Vector3.new(200, 118, 18), frame * CFrame.new(0, 59, -9), rgb(232, 226, 214), Material.Marble)
	box(group, "Firebox", Vector3.new(124, 78, 2), frame * CFrame.new(0, 39, -18.4), rgb(28, 22, 22))
	box(group, "Hearth", Vector3.new(232, 4, 44), frame * CFrame.new(0, 2, -22), rgb(190, 184, 172), Material.Marble)
	box(group, "Mantel", Vector3.new(226, 9, 32), frame * CFrame.new(0, 122, -14), MAHOGANY, Material.Wood)
	box(group, "MantelEdge", Vector3.new(232, 3, 34), frame * CFrame.new(0, 127.5, -14), MAHOGANY_DARK, Material.Wood)
	for _, side in { -1, 1 } do
		box(group, "Pilaster", Vector3.new(16, 118, 6), frame * CFrame.new(side * 84, 59, -20), rgb(244, 240, 230), Material.Marble)
		post(group, "MantelCandle", 16, 4, (frame * CFrame.new(side * 92, 136, -14)).Position, CANDLE)
		ball(group, "MantelFlame", 4.4, (frame * CFrame.new(side * 92, 146.5, -14)).Position, FLAME, Material.Neon)
	end

	-- Logs and a fire.
	for i, x in { -30, 0, 30 } do
		local a = (frame * CFrame.new(x - 16, 12 + i % 2 * 3, -20)).Position
		local b = (frame * CFrame.new(x + 16, 12 + i % 2 * 3, -20)).Position
		pipe(group, "Log", a, b, 9, rgb(84, 50, 28), Material.Wood)
	end
	local glow = box(group, "Embers", Vector3.new(96, 5, 6), frame * CFrame.new(0, 7, -20), rgb(255, 110, 30), Material.Neon)
	Kit.light(glow, rgb(255, 150, 70), 60, 3)
	for _, x in { -32, 0, 32 } do
		local height = if x == 0 then 38 else 26
		box(group, "Flame", Vector3.new(16, height, 2), frame * CFrame.new(x, 12 + height / 2, -20.5), rgb(255, 140, 40), Material.Neon)
		box(group, "FlameInner", Vector3.new(8, height * 0.65, 2), frame * CFrame.new(x, 12 + height * 0.33, -21.2), rgb(255, 225, 110), Material.Neon)
	end
	local fire = Instance.new("Fire")
	fire.Size = 26
	fire.Heat = 12
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 225, 110)
	fire.Parent = glow

	portrait(group, frame, 0, 196, 104, 72, "🦃", "Great-Grandpa Gobbles, Founder")
end

local function sideboard(group: Instance, x: number)
	local frame = CFrame.lookAt(Vector3.new(x, 0, FAR_Z), Vector3.new(x, 0, MID_Z))
	box(group, "SideboardBody", Vector3.new(130, 42, 30), frame * CFrame.new(0, 27, -15), MAHOGANY, Material.Wood)
	box(group, "SideboardTop", Vector3.new(136, 3, 34), frame * CFrame.new(0, 49.5, -16), rgb(232, 226, 214), Material.Marble)
	for _, ox in { -56, 56 } do
		post(group, "SideboardLeg", 8, 6, (frame * CFrame.new(ox, 4, -22)).Position, MAHOGANY_DARK, Material.Wood)
	end
	for _, ox in { -42, 0, 42 } do
		box(group, "Drawer", Vector3.new(36, 28, 1.4), frame * CFrame.new(ox, 28, -30.6), MAHOGANY_DARK, Material.Wood)
		ball(group, "DrawerKnob", 3.6, (frame * CFrame.new(ox, 28, -32)).Position, GOLD, Material.Metal)
	end
	-- A silver soup tureen.
	post(group, "TureenFoot", 2, 16, (frame * CFrame.new(0, 52, -16)).Position, SILVER, Material.Metal)
	ball(group, "Tureen", 24, (frame * CFrame.new(0, 63, -16)).Position, SILVER, Material.Metal)
	ball(group, "TureenKnob", 5, (frame * CFrame.new(0, 76.5, -16)).Position, GOLD, Material.Metal)
	for _, ox in { -46, 46 } do
		post(group, "Goblet", 12, 5, (frame * CFrame.new(ox, 57, -16)).Position, GOLD, Material.Metal)
		post(group, "GobletCup", 7, 10, (frame * CFrame.new(ox, 66, -16)).Position, BURGUNDY)
	end
end

local function grandfatherClock(group: Instance, x: number)
	local frame = CFrame.lookAt(Vector3.new(x, 0, FAR_Z), Vector3.new(x, 0, MID_Z))
	box(group, "ClockBase", Vector3.new(38, 34, 20), frame * CFrame.new(0, 17, -11), MAHOGANY_DARK, Material.Wood)
	box(group, "ClockBody", Vector3.new(28, 104, 15), frame * CFrame.new(0, 86, -10), MAHOGANY, Material.Wood)
	box(group, "ClockWindow", Vector3.new(16, 70, 1), frame * CFrame.new(0, 80, -18), rgb(40, 28, 22))
	box(group, "ClockRod", Vector3.new(1.4, 44, 1), frame * CFrame.new(0, 90, -18.7), GOLD, Material.Metal)
	local bob = (frame * CFrame.new(0, 66, -18.7)).Position
	pipe(group, "ClockBob", bob, bob + frame.LookVector, 11, GOLD, Material.Metal)
	box(group, "ClockHead", Vector3.new(38, 44, 20), frame * CFrame.new(0, 160, -11), MAHOGANY_DARK, Material.Wood)
	local face = (frame * CFrame.new(0, 160, -21)).Position
	pipe(group, "ClockFace", face, face + frame.LookVector, 30, IVORY)
	box(group, "ClockHandH", Vector3.new(1.6, 9, 0.5), frame * CFrame.new(0, 164.5, -22.3), rgb(30, 30, 30))
	box(group, "ClockHandM", Vector3.new(11, 1.2, 0.5), frame * CFrame.new(5.5, 160, -22.5), rgb(30, 30, 30))
	box(group, "ClockTop", Vector3.new(44, 6, 24), frame * CFrame.new(0, 185, -11), MAHOGANY, Material.Wood)
end

local function pottedFern(group: Instance, x: number, z: number)
	post(group, "Pot", 26, 34, Vector3.new(x, 13, z), rgb(226, 214, 190), Material.Marble)
	post(group, "PotRim", 4, 38, Vector3.new(x, 27, z), GOLD, Material.Metal)
	ball(group, "Fern", 40, Vector3.new(x, 48, z), LEAF, Material.Grass)
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5
		ball(group, "Fern", 26, Vector3.new(x + math.cos(a) * 18, 42 + i % 2 * 12, z + math.sin(a) * 18), rgb(72, 136, 78), Material.Grass)
	end
end

local function furniture()
	doors()
	local group = Kit.folder(room, "Furniture")
	chinaCabinet(group, -250)
	chinaCabinet(group, 250)
	fireplace()
	sideboard(group, -280)
	sideboard(group, 280)
	grandfatherClock(group, -152)
	pottedFern(group, 150, FAR_Z - 26)
	pottedFern(group, -392, NEAR_Z + 34)
	pottedFern(group, 392, NEAR_Z + 34)
	pottedFern(group, -392, FAR_Z - 34)
	pottedFern(group, 392, FAR_Z - 34)
end

-- The chandelier, hanging well above the chef's hat ---------------------------------------------------------------------

local function chandelier()
	local group = Kit.folder(room, "Chandelier")
	local center = Vector3.new(0, 0, MID_Z)
	local at = function(x, y, z)
		return center + Vector3.new(x, y, z)
	end
	post(group, "Medallion", 2, 70, at(0, HEIGHT - 1, 0), GOLD, Material.Metal, SHELL)
	post(group, "Chain", 34, 3, at(0, HEIGHT - 17, 0), GOLD, Material.Metal)
	local hub = ball(group, "Hub", 22, at(0, 232, 0), GOLD, Material.Metal)
	ball(group, "HubDrop", 13, at(0, 216, 0), GOLD, Material.Metal)
	ball(group, "HubCrystal", 7, at(0, 206, 0), rgb(235, 245, 255), Material.Glass)
	Kit.light(hub, rgb(255, 225, 170), 60, 3)

	local RADIUS, ARMS, SEGMENTS = 74, 12, 24
	local previous = at(RADIUS, 222, 0)
	for i = 1, SEGMENTS do
		local a = i / SEGMENTS * math.pi * 2
		local point = at(math.cos(a) * RADIUS, 222, math.sin(a) * RADIUS)
		pipe(group, "Ring", previous, point, 3.4, GOLD, Material.Metal)
		previous = point
	end
	for i = 1, ARMS do
		local a = i / ARMS * math.pi * 2
		local x, z = math.cos(a) * RADIUS, math.sin(a) * RADIUS
		pipe(group, "Arm", at(x * 0.1, 230, z * 0.1), at(x, 222, z), 2.6, GOLD, Material.Metal)
		post(group, "Cup", 2, 8, at(x, 224, z), GOLD, Material.Metal)
		post(group, "Candle", 11, 3.4, at(x, 230.5, z), CANDLE)
		ball(group, "Flame", 4.2, at(x, 238.4, z), FLAME, Material.Neon)
		ball(group, "Crystal", 3.4, at(x, 217, z), rgb(235, 245, 255), Material.Glass)
	end
end

restyleTable()
dressCenterpiece()
placeChairs()
floorAndCeiling()
walls()
furniture()
chandelier()

-- Rows a turkey's length apart, reaching back around the corner behind the finish line.
Kit.layPads(map, {
	{ 160, 430 }, { 190, 430 },
	{ 160, 416 }, { 190, 416 },
	{ 160, 402 }, { 190, 402 },
	{ 160, 388 }, { 190, 388 },
})

local count = 0
for _, d in room:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print("Dining room built:", count, "parts")
return count
