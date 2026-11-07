-- Escape the Oven: refits the home kitchen as a professional restaurant kitchen. The chef stands at a cook station in
-- the middle of the floor, under a big extractor hood, with crates of things to throw. See Kit.luau for how to run this.

local Kit = loadstring(game:GetService("ServerScriptService").Server.MapBuilders.Kit.Source)()
local box, ball, post, pipe = Kit.box, Kit.ball, Kit.post, Kit.pipe
local rgb = Color3.fromRGB
local Material = Enum.Material

local map = workspace.Maps.OvenEscape
local room = Kit.fresh(map, "Room")

local CENTER_X, CENTER_Z = -700, -40 -- the middle of the room
local STATION = Vector3.new(-700, 0, 0) -- the middle of the track's loop
local HEIGHT = 170

local STEEL, STEEL_LIGHT, STEEL_DARK = rgb(172, 178, 184), rgb(204, 208, 212), rgb(112, 118, 124)
local RUBBER = rgb(38, 38, 42)
local COPPER = rgb(196, 112, 62)
local TILE, GROUT = rgb(236, 238, 234), rgb(198, 202, 200)
local QUARRY_A, QUARRY_B = rgb(150, 62, 46), rgb(126, 50, 38)
local RED = rgb(205, 40, 40)
local YELLOW = rgb(245, 200, 40)
local HEAT = rgb(255, 80, 40)
local WARM = rgb(235, 195, 135)
local CREAM = rgb(250, 244, 226)
local WOOD = rgb(176, 124, 74)

local SHELL = { CastShadow = false }

-- What was already there ----------------------------------------------------------------------------------------------

local function each(folder: Instance, names, fn)
	for _, child in folder:GetChildren() do
		if table.find(names, child.Name) then
			fn(child)
		end
	end
end

local function remove(part: Instance)
	part:Destroy()
end

local function setLook(color: Color3, material: Enum.Material?)
	return function(part: BasePart)
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = 0
	end
end

local function restyle()
	each(map.Ground, { "Floor" }, function(tile)
		local odd = (math.round(tile.Position.X / 48) + math.round(tile.Position.Z / 48)) % 2 == 1
		tile.Color = if odd then QUARRY_A else QUARRY_B
		tile.Material = Material.Slate
	end)
	each(map.Ground, { "WallN", "WallS", "WallE", "WallW" }, setLook(TILE))
	each(map.Ground, { "Baseboard" }, setLook(STEEL_DARK, Material.Metal))

	-- Stainless steel everywhere, keeping the one butcher-block island.
	each(map.Counters, { "CabinetN", "CabinetE", "CabinetW", "Island" }, setLook(STEEL, Material.Metal))
	each(map.Counters, { "ToeKick" }, setLook(RUBBER))
	each(map.Counters, { "Top" }, setLook(STEEL_LIGHT, Material.Metal))
	each(map.Counters, { "IslandTop" }, setLook(WOOD, Material.WoodPlanks))
	each(map.Fixtures, { "SinkCabinet" }, setLook(STEEL, Material.Metal))
	each(map.Fixtures, { "Rim" }, setLook(STEEL_LIGHT, Material.Metal))
	each(map.Oven, { "Cabinet", "Band", "Jamb", "Threshold" }, setLook(STEEL_DARK, Material.Metal))

	-- The roasting pan comes out of the oven to make room for the start grid.
	each(map.Oven, { "Pan" }, remove)

	-- Out with the home kitchen.
	each(map.Decor, { "Rug", "Window", "Curtain", "Pantry", "Sign", "Calendar", "Magnet", "Note", "UpperCabinet" }, remove)
	for _, part in map.Decor:GetChildren() do
		if (part.Name == "Door" or part.Name == "Handle") and part.Position.Y > 90 then
			part:Destroy()
		end
	end
	each(map.Decor, { "Door" }, setLook(STEEL_LIGHT, Material.Metal))
	each(map.Decor, { "Handle" }, setLook(RUBBER))
	each(map.Decor, { "Backsplash" }, setLook(STEEL, Material.Metal))
	each(map.Decor, { "Hood" }, setLook(STEEL_LIGHT, Material.Metal))
	each(map.Decor, { "RangeFront", "GriddleFront" }, setLook(STEEL_DARK, Material.Metal))
	each(map.Decor, { "Fridge" }, setLook(STEEL, Material.Metal))
end

-- The room ------------------------------------------------------------------------------------------------------------

local function ceilingAndWalls()
	local group = Kit.folder(room, "Shell")
	box(group, "Ceiling", Vector3.new(404, 4, 404), CFrame.new(CENTER_X, HEIGHT + 2, CENTER_Z), rgb(228, 228, 222), nil, SHELL)
	for _, x in { -825, -575 } do
		for _, z in { -190, -90, 10, 110 } do
			box(group, "Light", Vector3.new(90, 1.2, 16), CFrame.new(x, HEIGHT - 0.6, z), rgb(250, 250, 240), Material.Neon, SHELL)
		end
	end
	for _, z in { -200, 110 } do
		box(group, "Light", Vector3.new(90, 1.2, 16), CFrame.new(-700, HEIGHT - 0.6, z), rgb(250, 250, 240), Material.Neon, SHELL)
	end

	-- A duct along the top of the south wall.
	pipe(group, "Duct", Vector3.new(-888, 156, -222), Vector3.new(-516, 156, -222), 18, STEEL, Material.Metal, SHELL)
	for _, x in { -820, -700, -580 } do
		-- Its own CFrame replaces post's upright one: this duct runs along X, which is a cylinder's natural axis.
		post(group, "DuctBand", 3, 21, Vector3.new(x, 156, -222), STEEL_DARK, Material.Metal, { CFrame = CFrame.new(x, 156, -222), CastShadow = false })
	end

	-- Tile lines above the steel, up to the ceiling.
	local walls = {
		{ frame = CFrame.lookAt(Vector3.new(-700, 0, 151.5), Vector3.new(-700, 0, 0)), width = 384, low = 100 },
		{ frame = CFrame.lookAt(Vector3.new(-700, 0, -231.5), Vector3.new(-700, 0, 0)), width = 384, low = 0 },
		{ frame = CFrame.lookAt(Vector3.new(-891.5, 0, -40), Vector3.new(0, 0, -40)), width = 384, low = 100 },
		{ frame = CFrame.lookAt(Vector3.new(-507.5, 0, -72), Vector3.new(0, 0, -72)), width = 320, low = 100 },
	}
	for _, wall in walls do
		local y = wall.low + 14
		while y < HEIGHT do
			box(group, "Grout", Vector3.new(wall.width, 0.5, 0.3), wall.frame * CFrame.new(0, y, -0.2), GROUT, nil, SHELL)
			y += 14
		end
		local x = -wall.width / 2 + 32
		while x < wall.width / 2 do
			box(group, "Grout", Vector3.new(0.5, HEIGHT - wall.low, 0.3), wall.frame * CFrame.new(x, (HEIGHT + wall.low) / 2, -0.2), GROUT, nil, SHELL)
			x += 32
		end
	end

	-- The outside of the building, so it matches the house from the lobby.
	local outside = rgb(238, 225, 200)
	box(group, "Outside", Vector3.new(404, HEIGHT + 6, 1), CFrame.new(-704, HEIGHT / 2 + 3, 160.6), outside, nil, SHELL)
	box(group, "Outside", Vector3.new(404, HEIGHT + 6, 1), CFrame.new(-700, HEIGHT / 2 + 3, -240.6), outside, nil, SHELL)
	box(group, "Outside", Vector3.new(1, HEIGHT + 6, 404), CFrame.new(-900.6, HEIGHT / 2 + 3, -40), outside, nil, SHELL)
	box(group, "Outside", Vector3.new(1, HEIGHT + 6, 336), CFrame.new(-499.4, HEIGHT / 2 + 3, -72), outside, nil, SHELL)
end

-- Yellow lines along the inside of the counters, so the edge of the track is easy to see.
local function safetyLines()
	local group = Kit.folder(room, "SafetyLines")
	local y = 40.08
	box(group, "Line", Vector3.new(296, 0.1, 1.6), CFrame.new(-700, y, 109), YELLOW)
	box(group, "Line", Vector3.new(296, 0.1, 1.6), CFrame.new(-700, y, -109), YELLOW)
	box(group, "Line", Vector3.new(1.6, 0.1, 218), CFrame.new(-849, y, 0), YELLOW)
	box(group, "Line", Vector3.new(1.6, 0.1, 218), CFrame.new(-551, y, 0), YELLOW)
end

local function hangingPan(group: Instance, position: Vector3, diameter: number, color: Color3, turned: number)
	local down = CFrame.new(position) * CFrame.Angles(0, turned, 0)
	box(group, "PanHook", Vector3.new(0.8, 6, 0.8), down * CFrame.new(0, -3, 0), STEEL_DARK, Material.Metal)
	box(group, "PanHandle", Vector3.new(1.4, 12, 0.8), down * CFrame.new(0, -11, 0), RUBBER)
	local center = (down * CFrame.new(0, -17 - diameter / 2, 0)).Position
	local look = down.LookVector
	pipe(group, "Pan", center, center + look * 1.6, diameter, color, Material.Metal)
end

-- A rail hung over a lane, high enough that nobody's head reaches the pans.
local function potRack(group: Instance, from: Vector3, to: Vector3)
	pipe(group, "RackRail", from, to, 2.2, STEEL_DARK, Material.Metal)
	for _, t in { 0.1, 0.9 } do
		local top = from:Lerp(to, t)
		post(group, "RackChain", HEIGHT - top.Y, 1, Vector3.new(top.X, (HEIGHT + top.Y) / 2, top.Z), STEEL_DARK, Material.Metal)
	end
	local turned = math.atan2((to - from).X, (to - from).Z) + math.pi / 2
	local count = 7
	for i = 1, count do
		local color = if i % 2 == 0 then COPPER else RUBBER
		hangingPan(group, from:Lerp(to, i / (count + 1)), 8 + (i * 3) % 7, color, turned)
	end
end

local function potRacks()
	local group = Kit.folder(room, "PotRacks")
	potRack(group, Vector3.new(-860, 106, 130), Vector3.new(-770, 106, 130))
	potRack(group, Vector3.new(-600, 106, 130), Vector3.new(-540, 106, 130))
	potRack(group, Vector3.new(-760, 106, -130), Vector3.new(-640, 106, -130))
	potRack(group, Vector3.new(-530, 106, -90), Vector3.new(-530, 106, 0))
	potRack(group, Vector3.new(-870, 106, -110), Vector3.new(-870, 106, -40))
end

-- Open steel shelves full of stock, where the wall cabinets used to be. `frame` is on the wall, looking into the room.
local function shelves(group: Instance, frame: CFrame, x: number, width: number, seed: number)
	local random = Random.new(seed)
	for _, y in { 112, 142 } do
		box(group, "Shelf", Vector3.new(width, 1.6, 15), frame * CFrame.new(x, y, -8), STEEL_LIGHT, Material.Metal)
		local cx = x - width / 2 + 9
		while cx < x + width / 2 - 7 do
			local at = (frame * CFrame.new(cx, y + 0.8, -8)).Position
			local kind = random:NextInteger(1, 4)
			local step
			if kind == 1 then
				local size = random:NextNumber(11, 15)
				local color = if random:NextNumber() < 0.5 then STEEL_LIGHT else COPPER
				post(group, "StockPot", size, size, at + Vector3.new(0, size / 2, 0), color, Material.Metal)
				post(group, "PotLid", 1, size + 1, at + Vector3.new(0, size + 0.5, 0), STEEL_DARK, Material.Metal)
				step = size + 3
			elseif kind == 2 then
				local colors = { rgb(205, 60, 40), rgb(235, 175, 60), rgb(110, 150, 70) }
				local color = colors[random:NextInteger(1, #colors)]
				post(group, "Jar", 11, 6.5, at + Vector3.new(0, 5.5, 0), color, Material.Glass)
				post(group, "JarLid", 1.4, 7, at + Vector3.new(0, 11.7, 0), STEEL_DARK, Material.Metal)
				step = 9
			elseif kind == 3 then
				for level = 0, 3 do
					post(group, "Bowl", 2.2, 13 - level, at + Vector3.new(0, 1.1 + level * 2.2, 0), CREAM)
				end
				step = 16
			else
				local color = if random:NextNumber() < 0.5 then RED else rgb(240, 225, 190)
				box(group, "Sack", Vector3.new(11, 15, 9), CFrame.new(at + Vector3.new(0, 7.5, 0)), color, Material.Fabric)
				step = 14
			end
			cx += step
		end
	end
end

local function wallShelves()
	local group = Kit.folder(room, "Shelves")
	local north = CFrame.lookAt(Vector3.new(-700, 0, 152), Vector3.new(-700, 0, 0))
	-- North's own right is toward the east wall, and the hood fills the middle.
	shelves(group, north, 130, 120, 1)
	shelves(group, north, -130, 100, 2)
	local east = CFrame.lookAt(Vector3.new(-508, 0, -28), Vector3.new(-700, 0, -28))
	shelves(group, east, 0, 240, 3)
	local west = CFrame.lookAt(Vector3.new(-892, 0, 0), Vector3.new(0, 0, 0))
	shelves(group, west, -125, 90, 4)
	shelves(group, west, 110, 90, 5)
end

-- The window food goes out through, with heat lamps, plates and order tickets. It's in the west wall, above the sinks.
local function pass()
	local group = Kit.folder(room, "Pass")
	local frame = CFrame.lookAt(Vector3.new(-892, 0, 0), Vector3.new(0, 0, 0))
	local at = function(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local WIDTH = 124
	box(group, "Opening", Vector3.new(WIDTH, 52, 0.8), at(0, 92, -0.6), WARM, Material.Neon, SHELL)
	box(group, "OpeningTop", Vector3.new(WIDTH + 8, 5, 3), at(0, 120, -1.5), STEEL_DARK, Material.Metal, SHELL)
	for _, side in { -1, 1 } do
		box(group, "OpeningSide", Vector3.new(4, 52, 3), at(side * (WIDTH / 2 + 2), 92, -1.5), STEEL_DARK, Material.Metal, SHELL)
	end
	box(group, "PassShelf", Vector3.new(WIDTH + 14, 3, 16), at(0, 64.5, -8), STEEL_LIGHT, Material.Metal)

	-- Plates waiting to go out, under the lamps.
	local plateX = -48
	for i = 1, 5 do
		local center = at(plateX, 66.6, -8).Position
		post(group, "Plate", 1.2, 14, center, CREAM)
		local foods = { rgb(190, 110, 50), rgb(230, 170, 60), rgb(120, 170, 70), rgb(205, 70, 40), rgb(190, 110, 50) }
		ball(group, "Food", 8, center + Vector3.new(0, 3, 0), foods[i])
		plateX += 24
	end
	for _, x in { -36, -12, 12, 36 } do
		box(group, "LampCord", Vector3.new(0.7, 12, 0.7), at(x, 111, -8), RUBBER)
		local lamp = at(x, 103, -8).Position
		post(group, "LampShade", 6, 9, lamp, RED, Material.Metal)
		ball(group, "LampBulb", 5, lamp + Vector3.new(0, -3, 0), HEAT, Material.Neon)
	end

	-- The ticket rail and the sign.
	box(group, "TicketRail", Vector3.new(WIDTH, 2.4, 1.6), at(0, 130, -1.4), STEEL_DARK, Material.Metal, SHELL)
	for i = 1, 7 do
		box(group, "Ticket", Vector3.new(9, 13, 0.3), at(-54 + i * 13.5 + (i % 2) * 1.5, 123 - (i % 3), -2.4), CREAM, nil, SHELL)
	end
	local sign = box(group, "OrderUp", Vector3.new(96, 17, 1.4), at(0, 148, -1), RED, nil, SHELL)
	Kit.sign(sign, "🔔 ORDER UP! 🔔", rgb(255, 245, 225), rgb(90, 15, 15))
end

-- The cook station in the middle, with the chef on top -----------------------------------------------------------------

local function station()
	local group = Kit.folder(room, "Station")
	local at = function(x, y, z)
		return CFrame.new(STATION + Vector3.new(x, y, z))
	end
	box(group, "Body", Vector3.new(192, 34, 118), at(0, 19, 0), STEEL, Material.Metal)
	box(group, "Kick", Vector3.new(186, 3, 112), at(0, 1.5, 0), RUBBER)
	box(group, "Top", Vector3.new(200, 3, 126), at(0, 37.5, 0), STEEL_LIGHT, Material.Metal)
	for _, side in { -1, 1 } do
		for x = -80, 80, 32 do
			box(group, "Door", Vector3.new(29, 26, 1), at(x, 20, side * 59.4), STEEL_LIGHT, Material.Metal)
			box(group, "Handle", Vector3.new(19, 1.4, 1.2), at(x, 29, side * 60.2), RUBBER)
		end
		box(group, "EndDoor", Vector3.new(1, 26, 96), at(side * 96.4, 20, 0), STEEL_LIGHT, Material.Metal)
		box(group, "EndHandle", Vector3.new(1.2, 1.4, 70), at(side * 97.2, 29, 0), RUBBER)
	end
	Kit.chefSpot(map, STATION + Vector3.new(0, 39, 0), Vector3.new(0, 0, 1))

	-- Two big stockpots on the burners at one end, steaming.
	for _, z in { -30, 30 } do
		local base = STATION + Vector3.new(-72, 39, z)
		post(group, "Burner", 1, 34, base + Vector3.new(0, 0.5, 0), RUBBER)
		post(group, "BurnerFlame", 1.4, 28, base + Vector3.new(0, 1.2, 0), rgb(255, 130, 40), Material.Neon)
		post(group, "StockPot", 24, 30, base + Vector3.new(0, 14, 0), COPPER, Material.Metal)
		post(group, "PotRim", 2, 32, base + Vector3.new(0, 26, 0), STEEL_LIGHT, Material.Metal)
		local soup = post(group, "Soup", 1, 28, base + Vector3.new(0, 26.4, 0), rgb(226, 150, 60))
		local steam = Instance.new("Smoke")
		steam.Color = rgb(245, 245, 245)
		steam.Opacity = 0.12
		steam.RiseVelocity = 8
		steam.Size = 12
		steam.Parent = soup
	end

	-- A griddle with burgers at the other end.
	box(group, "Griddle", Vector3.new(50, 1.4, 84), at(72, 39.7, 0), rgb(40, 38, 38), Material.Metal)
	for _, offset in { { 58, -26 }, { 84, -18 }, { 62, 8 }, { 86, 22 }, { 62, 30 } } do
		post(group, "Patty", 1.6, 11, STATION + Vector3.new(offset[1], 41.2, offset[2]), rgb(120, 66, 36))
	end

	-- What he throws: a crate of tomatoes, a stack of pies and a stack of pans, close to hand.
	local crate = at(-30, 44, 40)
	box(group, "Crate", Vector3.new(24, 9, 20), crate, WOOD, Material.Wood)
	for _, x in { -7, 0, 7 } do
		for _, z in { -5, 5 } do
			ball(group, "Tomato", 7.5, (crate * CFrame.new(x, 5, z)).Position, rgb(225, 45, 35))
		end
	end
	for level = 0, 3 do
		post(group, "Pie", 2.4, 18, STATION + Vector3.new(30, 40.2 + level * 2.5, 42), rgb(220, 160, 80))
		post(group, "PieFilling", 2.5, 14, STATION + Vector3.new(30, 40.2 + level * 2.5, 42), rgb(235, 130, 50))
	end
	for level = 0, 4 do
		post(group, "StackedPan", 1.4, 16, STATION + Vector3.new(30, 40 + level * 1.6, -42), RUBBER)
	end

	-- The extractor hood, hung high enough to clear his hat.
	box(group, "Hood", Vector3.new(214, 16, 140), at(0, 158, 0), STEEL_LIGHT, Material.Metal)
	box(group, "HoodLip", Vector3.new(218, 3, 144), at(0, 150, 0), STEEL_DARK, Material.Metal)
	for _, z in { -44, 44 } do
		box(group, "HoodLight", Vector3.new(170, 0.6, 7), at(0, 148.3, z), rgb(255, 245, 220), Material.Neon)
	end
	for _, x in { -96, 96 } do
		for _, z in { -60, 60 } do
			post(group, "HoodChain", 4, 2, STATION + Vector3.new(x, 168, z), STEEL_DARK, Material.Metal)
		end
	end
end

-- Along the south wall -------------------------------------------------------------------------------------------------

local function walkIn(group: Instance)
	local frame = CFrame.lookAt(Vector3.new(-700, 0, -232), Vector3.new(-700, 0, 0))
	box(group, "WalkInBox", Vector3.new(150, 140, 4), frame * CFrame.new(0, 70, -2), STEEL, Material.Metal)
	box(group, "WalkInDoor", Vector3.new(96, 116, 3), frame * CFrame.new(0, 58, -5), STEEL_LIGHT, Material.Metal)
	box(group, "WalkInHandle", Vector3.new(3, 26, 4), frame * CFrame.new(36, 60, -8), RUBBER)
	for _, y in { 22, 96 } do
		box(group, "WalkInHinge", Vector3.new(10, 8, 2), frame * CFrame.new(-46, y, -7), STEEL_DARK, Material.Metal)
	end
	local sign = box(group, "WalkInSign", Vector3.new(66, 15, 1), frame * CFrame.new(0, 126, -4.5), rgb(40, 110, 180))
	Kit.sign(sign, "❄️ WALK-IN ❄️", Color3.new(1, 1, 1))
end

local function chalkboard(group: Instance)
	-- Between the walk-in and the fridge.
	local frame = CFrame.lookAt(Vector3.new(-597, 0, -232), Vector3.new(-597, 0, 0))
	box(group, "BoardFrame", Vector3.new(50, 46, 1.4), frame * CFrame.new(0, 118, -0.8), WOOD, Material.Wood, SHELL)
	local board = box(group, "Board", Vector3.new(45, 41, 0.6), frame * CFrame.new(0, 118, -1.8), rgb(40, 48, 44), nil, SHELL)
	Kit.sign(board, "TODAY'S SPECIAL\nTURKEY 🦃\n(if you can catch one)", rgb(240, 240, 230))
end

local function dryStorage(group: Instance)
	local base = Vector3.new(-820, 0, -214)
	for _, x in { -44, 44 } do
		for _, z in { -14, 14 } do
			post(group, "RackPost", 120, 2.4, base + Vector3.new(x, 60, z), STEEL_DARK, Material.Metal)
		end
	end
	local random = Random.new(7)
	for _, y in { 14, 48, 82, 116 } do
		box(group, "RackShelf", Vector3.new(92, 1.6, 30), CFrame.new(base + Vector3.new(0, y, 0)), STEEL_LIGHT, Material.Metal)
		if y < 116 then
			for x = -32, 32, 21 do
				local color = if random:NextNumber() < 0.5 then rgb(240, 225, 190) else rgb(200, 160, 110)
				box(group, "Sack", Vector3.new(17, 20, 20), CFrame.new(base + Vector3.new(x, y + 10.8, 0)), color, Material.Fabric)
			end
		else
			for x = -32, 32, 21 do
				post(group, "Tin", 14, 13, base + Vector3.new(x, y + 7.8, 0), STEEL, Material.Metal)
			end
		end
	end
end

local function fireExtinguisher(group: Instance, position: Vector3)
	post(group, "Extinguisher", 20, 7, position, RED, Material.Metal)
	post(group, "ExtinguisherTop", 3, 3, position + Vector3.new(0, 11.5, 0), RUBBER)
	box(group, "ExtinguisherHandle", Vector3.new(6, 1, 2), CFrame.new(position + Vector3.new(0, 13.5, 0)), RUBBER)
end

-- On the floor around the station -------------------------------------------------------------------------------------

local function floorThings(group: Instance)
	-- Rubber mats where the cooks stand, and drains.
	box(group, "Mat", Vector3.new(214, 0.5, 26), CFrame.new(STATION + Vector3.new(0, 0.5, 80)), RUBBER)
	box(group, "Mat", Vector3.new(214, 0.5, 26), CFrame.new(STATION + Vector3.new(0, 0.5, -80)), RUBBER)
	for _, x in { -828, -572 } do
		box(group, "Drain", Vector3.new(22, 0.4, 150), CFrame.new(x, 0.5, 0), rgb(70, 72, 76), Material.DiamondPlate)
	end

	-- A mop bucket and a wet floor sign.
	local bucket = Vector3.new(-826, 0, 88)
	post(group, "Bucket", 18, 22, bucket + Vector3.new(0, 11, 0), YELLOW)
	post(group, "BucketWater", 1, 18, bucket + Vector3.new(0, 20, 0), rgb(120, 150, 150))
	pipe(group, "Mop", bucket + Vector3.new(2, 14, 0), bucket + Vector3.new(14, 66, -6), 2, rgb(190, 160, 110))
	local signFrame = CFrame.new(-790, 13, 88) * CFrame.Angles(math.rad(-14), math.rad(160), 0)
	local wet = box(group, "WetFloor", Vector3.new(16, 26, 1), signFrame, YELLOW)
	Kit.sign(wet, "⚠️\nWET\nFLOOR", rgb(30, 30, 30))

	-- Milk crates, stacked.
	for level = 0, 2 do
		box(group, "MilkCrate", Vector3.new(20, 13, 20), CFrame.new(-572, 7 + level * 13.4, 86 - level), if level == 1 then rgb(40, 90, 170) else RED)
	end
	box(group, "MilkCrate", Vector3.new(20, 13, 20), CFrame.new(-572, 7, 62), rgb(40, 90, 170))

	-- A bin.
	post(group, "Bin", 34, 26, Vector3.new(-572, 17, -86), rgb(70, 74, 80))
	post(group, "BinLid", 3, 29, Vector3.new(-572, 35.5, -86), rgb(50, 54, 60))

	-- A tall speed rack of trays.
	local rack = Vector3.new(-826, 0, -84)
	for _, x in { -13, 13 } do
		for _, z in { -13, 13 } do
			post(group, "RackPost", 66, 1.6, rack + Vector3.new(x, 33, z), STEEL_DARK, Material.Metal)
		end
	end
	for level = 0, 5 do
		local y = 8 + level * 11
		box(group, "Tray", Vector3.new(26, 1, 26), CFrame.new(rack + Vector3.new(0, y, 0)), STEEL_LIGHT, Material.Metal)
		if level % 2 == 0 then
			for _, x in { -6, 6 } do
				post(group, "Bun", 3.4, 9, rack + Vector3.new(x, y + 2.2, 0), rgb(214, 160, 90))
			end
		end
	end
end

restyle()
ceilingAndWalls()
safetyLines()
potRacks()
wallShelves()
pass()
station()
local south = Kit.folder(room, "SouthWall")
walkIn(south)
chalkboard(south)
dryStorage(south)
fireExtinguisher(south, Vector3.new(-632, 42, -226))
local floorGroup = Kit.folder(room, "Floor")
floorThings(floorGroup)

-- Three across fits a turkey's 11.5-stud width inside the oven, with the rows a turkey's length apart.
Kit.layPads(map, {
	{ -499, 117.5 }, { -499, 130 }, { -499, 142.5 },
	{ -486, 117.5 }, { -486, 130 }, { -486, 142.5 },
	{ -473, 124 }, { -473, 136 },
})

local count = 0
for _, d in room:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print("Kitchen built:", count, "parts")
return count
