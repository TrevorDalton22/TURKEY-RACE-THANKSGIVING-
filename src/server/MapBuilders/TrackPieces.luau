-- Puts the pieces modeled in Blender (assets/props) on every map: item boxes, boost pads, start marks and track items.
-- The old blocks stay where they are, invisible, as the collision, so racing around them hasn't changed. Everything
-- new is scenery. Run this after importing asset 106245382635523 as ReplicatedStorage.TrackPropsImport; see Kit.luau for how.

local Kit = loadstring(game:GetService("ServerScriptService").Server.MapBuilders.Kit.Source)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Material = Enum.Material
local rgb = Color3.fromRGB

local FLOOR = 40 -- the racing surface on every map, away from Pumpkin Hill

-- Glowing pieces are Neon in the game, whatever they were in Blender.
local GLOW_COLORS = {
	ItemBox_Glow = rgb(255, 225, 110),
	ItemBox_Halo_Glow = rgb(255, 180, 60),
	BoostPad_Chevron_Glow = rgb(255, 150, 40),
}

-- The import is a Model of Models, each holding one mesh. This flattens it into the TrackProps folder of meshes named
-- after each piece, without the package link, and sets them up as scenery. Anything else in the folder (the chef's
-- meshes, from assets/lowpoly) stays. With no import waiting, it just uses what's in the folder.
local function prepareTemplates(): Folder
	local folder = ReplicatedStorage:FindFirstChild("TrackProps")
	local source = ReplicatedStorage:FindFirstChild("TrackPropsImport")
	if not source then
		return folder
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TrackProps"
		folder.Parent = ReplicatedStorage
	end
	local bodyY, glowY
	for _, model in source:GetChildren() do
		local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			if model.Name == "ItemBox_Body" then
				bodyY = mesh.Position.Y
			elseif model.Name == "ItemBox_Glow" then
				glowY = mesh.Position.Y
			end
			mesh.Name = model.Name
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.Massless = true
			if GLOW_COLORS[model.Name] then
				local look = mesh:FindFirstChildOfClass("SurfaceAppearance")
				if look then
					look:Destroy()
				end
				mesh.TextureID = ""
				mesh.Material = Material.Neon
				mesh.Color = GLOW_COLORS[model.Name]
				mesh.CastShadow = false
			end
			local old = folder:FindFirstChild(model.Name)
			if old then
				old:Destroy()
			end
			mesh.Parent = folder
		end
	end
	-- The body's mesh is centered with its feathers in, so its middle is above the middle of the box.
	folder.ItemBox_Body:SetAttribute("OffsetY", bodyY - glowY)
	source:Destroy()
	return folder
end

local templates = prepareTemplates()

local function place(parent: Instance, name: string, cframe: CFrame, size: Vector3?): MeshPart
	local mesh = templates[name]:Clone()
	mesh.CFrame = cframe
	if size then
		mesh.Size = size
	end
	mesh.Parent = parent
	return mesh
end

local function hidePart(part: BasePart)
	part.Transparency = 1
	part.CastShadow = false
end

-- Hides the old pieces with these names, and calls `each` with every one.
local function swap(folder: Instance, names, each: ((Instance) -> ())?)
	for _, child in folder:GetChildren() do
		if table.find(names, child.Name) then
			if child:IsA("BasePart") then
				hidePart(child)
			else
				for _, d in child:GetDescendants() do
					if d:IsA("BasePart") then
						hidePart(d)
					end
				end
			end
			if each then
				each(child)
			end
		end
	end
end

local function at(x: number, y: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- Item boxes ----------------------------------------------------------------------------------------------------------

local function itemBoxes(map: Instance)
	for _, box in map.ItemBoxes:GetChildren() do
		box:ClearAllChildren()
		box.Position = Vector3.new(box.Position.X, FLOOR + 6.5, box.Position.Z)
		hidePart(box)
		local middle = CFrame.new(box.Position)
		local body = place(box, "ItemBox_Body", middle * CFrame.new(0, templates.ItemBox_Body:GetAttribute("OffsetY"), 0))
		body.Name = "Body"
		local glow = place(box, "ItemBox_Glow", middle)
		glow.Name = "Glow"
		local halo = place(box, "ItemBox_Halo_Glow", middle)
		halo.Name = "Halo"

		Kit.light(glow, rgb(255, 210, 120), 16, 1.2)
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(rgb(255, 215, 110))
		sparkles.LightEmission = 1
		sparkles.Rate = 5
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Speed = NumberRange.new(3, 7)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Parent = glow
	end
end

-- Boost pads ----------------------------------------------------------------------------------------------------------

local function boostPads(map: Instance, spots)
	local folder = Kit.fresh(map, "BoostPads")
	for i, spot in spots do
		local x, z, dx, dz = spot[1], spot[2], spot[3], spot[4]
		local position = Vector3.new(x, FLOOR + 0.5, z)
		local frame = CFrame.lookAt(position, position + Vector3.new(dx, 0, dz))
		local pad = Kit.box(folder, "BoostPad" .. i, Vector3.new(16, 1, 26), frame, Color3.new(1, 1, 1), nil, { Transparency = 1, CastShadow = false })
		local base = place(pad, "BoostPad_Base", frame * CFrame.new(0, -0.5 + 0.3, 0))
		base.Name = "Base"
		-- Chevron1 at the back. The slots they sit in are part of the base.
		for k, offset in { 7.05, 0.05, -6.95 } do
			local chevron = place(pad, "BoostPad_Chevron_Glow", frame * CFrame.new(0, -0.5 + 0.44, offset))
			chevron.Name = "Chevron" .. k
		end
	end
end

-- Start marks replace the yellow pads, which looked like they ought to do something.
local function startMarks(map: Instance, group: Instance)
	local p1, p2 = map.Path.P1.Position, map.Path.P2.Position
	local forward = Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z).Unit
	for _, pad in map.StartPads:GetChildren() do
		hidePart(pad)
		local position = Vector3.new(pad.Position.X, FLOOR + 0.12, pad.Position.Z)
		place(group, "StartMark", CFrame.lookAt(position, position + forward))
	end
end

-- Each map's track items -----------------------------------------------------------------------------------------------

local function dinnerDash(map: Instance)
	local group = Kit.fresh(map, "TrackPieces")
	local obstacles = map.Obstacles
	swap(obstacles, { "Fork" }, function(old)
		place(group, "Fork", at(old.Position.X, FLOOR + 17.5, old.Position.Z))
	end)
	swap(obstacles, { "ForkHead", "Tine", "KnifeHandle", "PumpkinStem", "ButterPat", "PotatoUp", "PotatoDown" })
	swap(obstacles, { "Knife" }, function(old)
		place(group, "Knife", at(old.Position.X, FLOOR + 16, old.Position.Z))
	end)
	swap(obstacles, { "Plate" }, function(old)
		place(group, "DinnerPlate", at(old.Position.X, FLOOR + 0.78, old.Position.Z))
	end)
	swap(obstacles, { "Gravy" }, function(old)
		local across = old.Size.Y
		place(group, "GravyPuddle", at(old.Position.X, FLOOR + 0.24, old.Position.Z), Vector3.new(across * 1.03, 0.4, across * 0.97))
	end)
	swap(obstacles, { "CornCob" }, function(old)
		-- The husk at one end sticks out past the old block, so the mesh's middle is a little off the cob's.
		place(group, "CornCob", at(old.Position.X + 1.35, old.Position.Y, old.Position.Z))
	end)
	swap(obstacles, { "Cranberry" }, function(old)
		place(group, "Cranberry", at(old.Position.X, FLOOR + 4.15, old.Position.Z))
	end)
	swap(obstacles, { "Pumpkin" }, function(old)
		place(group, "Pumpkin", at(old.Position.X, FLOOR + 6.4, old.Position.Z), templates.Pumpkin.Size * 1.03)
	end)
	-- The mashed potato ramp, over the old wedges.
	place(group, "PotatoMound", at(0, FLOOR + 3, 395))

	startMarks(map, group)
	itemBoxes(map)
	boostPads(map, {
		{ 175, 470, 0, 1 },
		-- Just before the gap in the table at x -60 to -48, so it helps you across.
		{ -20, 605, -1, 0 },
		{ -175, 430, 0, -1 },
		{ 95, 395, 1, 0 },
	})
end

local function backyard(map: Instance)
	local group = Kit.fresh(map, "TrackPieces")
	local obstacles = map.Obstacles
	swap(obstacles, { "HayBale" }, function(old)
		local cf = old:GetBoundingBox()
		place(group, "HayBale", at(cf.X, FLOOR + templates.HayBale.Size.Y / 2, cf.Z))
	end)
	swap(obstacles, { "Scarecrow" }, function(old)
		-- They face whoever's coming up the lane. Its arms are narrower than the model, to stay over the old posts.
		local cf = old:GetBoundingBox()
		local yaw = if math.abs(cf.X + 130) < 1 then -90 else 0
		place(group, "Scarecrow", at(cf.X, FLOOR + 8.85, cf.Z, yaw), Vector3.new(18, 17.7, 7))
	end)
	swap(obstacles, { "Log" }, function(old)
		place(group, "Log", at(old.Position.X, old.Position.Y, old.Position.Z, 90))
	end)
	for _, old in obstacles:GetChildren() do
		if old.Name == "SteppingStone" then
			old.Color = rgb(127, 122, 114)
			place(group, "Stone", at(old.Position.X, FLOOR - 0.85, old.Position.Z))
		end
	end

	-- The pumpkins dotted around the garden and lanes.
	local random = Random.new(11)
	swap(map.Decor.Pumpkins, { "Pumpkin" }, function(old)
		local cf, size = old:GetBoundingBox()
		place(group, "Pumpkin", CFrame.new(cf.Position) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0), templates.Pumpkin.Size * (size.Y / templates.Pumpkin.Size.Y))
	end)

	startMarks(map, group)
	itemBoxes(map)
	boostPads(map, {
		{ 120, -620, 0, -1 },
		{ -40, -600, -1, 0 },
		{ -150, -600, 0, 1 },
		{ 90, -450, 1, 0 },
	})
end

local function kitchen(map: Instance)
	local group = Kit.fresh(map, "TrackPieces")
	local obstacles = map.Obstacles
	swap(obstacles, { "Mixer", "Microwave", "Flour", "KnifeBlock", "Pot", "Soup", "Toaster", "Toast", "RollingPin", "Onion", "Carrot", "CarrotTop", "Salt", "Pepper" })

	-- Each of these was built from several blocks, so they're placed by hand over the old ones.
	place(group, "StandMixer", at(-544.2, FLOOR + 11.5, -26, 180), templates.StandMixer.Size * 1.68)
	place(group, "Microwave", at(-519, FLOOR + 8, -65, 90), Vector3.new(30, 16, 22.8))
	place(group, "FlourSack", at(-804, FLOOR + 10, -144))
	place(group, "KnifeBlock", at(-516, FLOOR + 10, 98, 90), Vector3.new(12, 20, 13))
	place(group, "StockPot", at(-734, FLOOR + 9.25, 141, 90), Vector3.new(23, 18.5, 19.5))
	place(group, "Toaster", at(-584.5, FLOOR + 7.9, 118), templates.Toaster.Size * 1.35)
	place(group, "RollingPin", at(-825, 42.5, 129.6, 90), Vector3.new(43, 5, 5))
	place(group, "Onion", at(-788, FLOOR + 4.95, 122))
	place(group, "Carrot", at(-779.5, 43.3, 140), Vector3.new(29, 7, 7))
	place(group, "Salt", at(-780, FLOOR + 7, -116), Vector3.new(6.2, 14, 6.2))
	place(group, "Pepper", at(-770, FLOOR + 7, -119), Vector3.new(6.2, 14, 6.2))

	startMarks(map, group)
	itemBoxes(map)
	boostPads(map, {
		{ -755, 118, -1, 0 },
		{ -858, -100, 0, -1 },
		{ -580, -130, 1, 0 },
		{ -542, 60, 0, 1 },
	})
end

dinnerDash(workspace.Maps.DinnerDash)
backyard(workspace.Maps.PumpkinPatch)
kitchen(workspace.Maps.OvenEscape)

local count = 0
for _, map in workspace.Maps:GetChildren() do
	for _, name in { "TrackPieces", "BoostPads", "ItemBoxes" } do
		for _, d in map[name]:GetDescendants() do
			if d:IsA("MeshPart") then
				count += 1
			end
		end
	end
end
print("Track pieces placed:", count)
return count
