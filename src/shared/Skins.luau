-- Turkey skins: shop prices, colors, and the suit pieces each skin is built from.
-- The server welds the pieces onto characters, and the shop builds its previews from the same pieces.

local Skins = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Skins.Default = "Classic"

-- Rarity tiers, in order, with the color the shop shows them in.
Skins.Rarities = {
	Common = { Order = 1, Color = rgb(190, 190, 190) },
	Rare = { Order = 2, Color = rgb(70, 150, 255) },
	Epic = { Order = 3, Color = rgb(180, 90, 255) },
	Legendary = { Order = 4, Color = rgb(255, 175, 30) },
	Mythic = { Order = 5, Color = rgb(255, 70, 130) },
}

-- In shop order. How a skin is unlocked:
--   Price = n      bought with n Feathers
--   Robux = true   a game pass (its id goes in Config.Robux.Skins)
--   Pass = true    a Harvest Pass reward (shared/Season says which tier)
-- Looks: anything a skin leaves out comes from Classic.
--   Tail: 3 colors (center feather first, mirrored) or 5 (left to right)
--   Transparency: see-through suit and legs (0..1)   Shine: reflectance of the body, head and wings
--   Sparkle: glitter drifting off the body in this color   Extra: a hat or other add-on, built in Skins.pieces
Skins.List = {
	{
		Id = "Classic",
		Name = "Classic Turkey",
		Rarity = "Common",
		Price = 0,
		Body = rgb(120, 72, 40),
		Head = rgb(170, 120, 90),
		Legs = rgb(240, 150, 40),
		Beak = rgb(245, 170, 40),
		Wattle = rgb(210, 30, 40),
		Tail = { rgb(150, 80, 35), rgb(205, 120, 45), rgb(235, 175, 70) },
		Transparency = 0,
		Shine = 0,
	},
	{
		Id = "Cool",
		Name = "Cool Turkey",
		Rarity = "Common",
		Price = 100,
		Body = rgb(55, 105, 185),
		Head = rgb(150, 200, 240),
		Tail = { rgb(35, 70, 150), rgb(60, 160, 215), rgb(170, 235, 255) },
		Extra = "Shades",
	},
	{
		Id = "Pilgrim",
		Name = "Pilgrim Turkey",
		Rarity = "Common",
		Price = 150,
		Body = rgb(55, 50, 50),
		Tail = { rgb(95, 65, 45), rgb(150, 100, 60), rgb(205, 165, 110) },
		Extra = "PilgrimHat",
	},
	{
		Id = "Lava",
		Name = "Lava Turkey",
		Rarity = "Rare",
		Price = 250,
		Body = rgb(50, 30, 28),
		BodyMaterial = Enum.Material.CrackedLava,
		Head = rgb(90, 35, 25),
		Tail = { rgb(255, 60, 20), rgb(255, 130, 20), rgb(255, 210, 60) },
		TailMaterial = Enum.Material.Neon,
	},
	{
		Id = "Ghost",
		Name = "Ghost Turkey",
		Rarity = "Rare",
		Price = 350,
		Body = rgb(225, 232, 255),
		Head = rgb(235, 240, 255),
		Legs = rgb(215, 225, 245),
		Beak = rgb(190, 200, 225),
		Wattle = rgb(160, 180, 225),
		Tail = { rgb(150, 185, 255), rgb(185, 210, 255), rgb(225, 235, 255) },
		TailMaterial = Enum.Material.Neon,
		Transparency = 0.4,
	},
	{
		Id = "King",
		Name = "King Turkey",
		Rarity = "Epic",
		Price = 500,
		Body = rgb(95, 45, 140),
		Head = rgb(190, 150, 120),
		Tail = { rgb(120, 50, 170), rgb(215, 165, 40), rgb(255, 225, 90) },
		Extra = "Crown",
	},
	{
		-- Dressed up as the villain who's chasing everyone.
		Id = "Chef",
		Name = "Chef Turkey",
		Rarity = "Epic",
		Price = 750,
		Body = rgb(245, 245, 245),
		Extra = "ChefHat",
	},
	{
		Id = "Golden",
		Name = "Golden Turkey",
		Rarity = "Legendary",
		Price = 1000,
		Body = rgb(255, 190, 40),
		Head = rgb(255, 210, 80),
		Legs = rgb(235, 170, 30),
		Beak = rgb(255, 140, 20),
		Tail = { rgb(230, 150, 20), rgb(255, 200, 40), rgb(255, 240, 140) },
		TailMaterial = Enum.Material.Neon,
		Shine = 0.25,
		Sparkle = rgb(255, 230, 120),
	},

	-- Robux skins ------------------------------------------------------------------------------------
	{
		Id = "Rainbow",
		Name = "Rainbow Turkey",
		Rarity = "Legendary",
		Robux = true,
		Body = rgb(250, 250, 255),
		Head = rgb(255, 225, 240),
		Tail = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(70, 210, 90), rgb(70, 140, 255) },
		TailMaterial = Enum.Material.Neon,
		Sparkle = rgb(255, 255, 255),
		Extra = "Shades",
	},
	{
		Id = "Galaxy",
		Name = "Galaxy Turkey",
		Rarity = "Mythic",
		Robux = true,
		Body = rgb(45, 25, 100),
		Head = rgb(80, 45, 150),
		Legs = rgb(120, 80, 220),
		Beak = rgb(255, 200, 255),
		Wattle = rgb(255, 90, 200),
		Tail = { rgb(150, 60, 255), rgb(255, 80, 220), rgb(80, 200, 255), rgb(255, 80, 220), rgb(150, 60, 255) },
		TailMaterial = Enum.Material.Neon,
		Shine = 0.1,
		Sparkle = rgb(220, 230, 255),
	},
	{
		Id = "Diamond",
		Name = "Diamond Turkey",
		Rarity = "Mythic",
		Robux = true,
		Body = rgb(170, 235, 255),
		BodyMaterial = Enum.Material.Glass,
		Head = rgb(205, 245, 255),
		Legs = rgb(150, 220, 245),
		Beak = rgb(120, 200, 255),
		Wattle = rgb(90, 170, 255),
		Tail = { rgb(110, 210, 255), rgb(170, 235, 255), rgb(235, 252, 255) },
		TailMaterial = Enum.Material.Neon,
		Shine = 0.35,
		Sparkle = rgb(230, 250, 255),
		Extra = "Crown",
	},

	-- Harvest Pass skins -----------------------------------------------------------------------------
	{
		Id = "Cranberry",
		Name = "Cranberry Turkey",
		Rarity = "Rare",
		Pass = true,
		Body = rgb(165, 20, 50),
		Head = rgb(225, 125, 135),
		Tail = { rgb(120, 10, 35), rgb(200, 30, 60), rgb(245, 95, 115) },
	},
	{
		Id = "Harvest",
		Name = "Harvest Turkey",
		Rarity = "Rare",
		Pass = true,
		Body = rgb(205, 110, 40),
		Head = rgb(230, 175, 115),
		Tail = { rgb(200, 45, 30), rgb(240, 140, 30), rgb(250, 210, 60), rgb(240, 140, 30), rgb(200, 45, 30) },
		Extra = "PilgrimHat",
	},
	{
		Id = "Pie",
		Name = "Pumpkin Pie Turkey",
		Rarity = "Epic",
		Pass = true,
		Body = rgb(225, 150, 70),
		Head = rgb(245, 205, 145),
		Tail = { rgb(205, 125, 55), rgb(235, 170, 90), rgb(250, 225, 175) },
		Extra = "Cream",
	},
	{
		Id = "Pumpkin",
		Name = "Pumpkin Turkey",
		Rarity = "Epic",
		Pass = true,
		Body = rgb(255, 135, 25),
		Head = rgb(255, 170, 60),
		Tail = { rgb(75, 135, 40), rgb(110, 170, 50), rgb(160, 205, 75) },
		Extra = "Stem",
	},
	{
		Id = "Feast",
		Name = "Feast King Turkey",
		Rarity = "Legendary",
		Pass = true,
		Body = rgb(205, 120, 45),
		Head = rgb(235, 175, 115),
		Tail = { rgb(230, 150, 20), rgb(255, 200, 40), rgb(255, 240, 140) },
		TailMaterial = Enum.Material.Neon,
		Shine = 0.1,
		Sparkle = rgb(255, 215, 110),
		Extra = "Crown",
	},
}

-- What a skin can borrow from Classic. Not the price, rarity or how it's unlocked.
local LOOKS = { "Body", "Head", "Legs", "Beak", "Wattle", "Tail", "Transparency", "Shine" }

Skins.byId = {}
for _, skin in Skins.List do
	for _, key in LOOKS do
		if skin[key] == nil then
			skin[key] = Skins.List[1][key]
		end
	end
	Skins.byId[skin.Id] = skin
end

-- Unknown or missing ids fall back to the default skin.
function Skins.get(id: string?)
	return Skins.byId[id] or Skins.byId[Skins.Default]
end

-- How a skin is unlocked: "Feathers", "Robux" or "Pass".
function Skins.source(skin): string
	return if skin.Robux then "Robux" elseif skin.Pass then "Pass" else "Feathers"
end

-- The turkey you ride. Its pieces are laid out around the center of its body ("body space": -Z is
-- forward, +Y is up). The body, head, each wing and each leg are separate groups joined at the pivots
-- in Skins.Joints, so clients can animate them (running legs, a bobbing head, flapping wings).
Skins.Joints = {
	Body = CFrame.new(),
	Head = CFrame.new(0, 1.1, -2.2), -- base of the neck
	WingL = CFrame.new(-2, 0.7, -0.4), -- shoulders
	WingR = CFrame.new(2, 0.7, -0.4),
	LegL = CFrame.new(-0.85, -1.4, 0.3), -- hips
	LegR = CFrame.new(0.85, -1.4, 0.3),
}
-- From the center of the body down to the soles of the feet.
Skins.FootDepth = 3.85
-- Where the head sits, for hats and the like.
local HEAD = CFrame.new(0, 3.1, -2.95)

-- Group: which of Skins.Joints the piece moves with. Mesh "Sphere" makes a block an ellipsoid.
-- Sparkle: set on the body when its skin glitters; the mount adds the particles.
export type Piece = { Group: string, Props: { [string]: any }, Offset: CFrame, Mesh: string?, Sparkle: Color3? }

-- The parts that make up a skin's turkey, in body space.
function Skins.pieces(id: string?): { Piece }
	local skin = Skins.get(id)
	local ball, cylinder = Enum.PartType.Ball, Enum.PartType.Cylinder
	-- A cylinder's axis is its X, so this turns it upright.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local list = {}
	local function add(group: string, props, offset: CFrame, mesh: string?): Piece
		local piece = { Group = group, Props = props, Offset = offset, Mesh = mesh }
		table.insert(list, piece)
		return piece
	end
	-- Head pieces are placed relative to the middle of the head.
	local function head(props, offset: CFrame): Piece
		return add("Head", props, HEAD * offset)
	end
	-- The turkey's own feathers and skin, as opposed to the saddle, hats and other add-ons.
	local function turkey(props, shiny: boolean?)
		props.Transparency = skin.Transparency
		if shiny then
			props.Reflectance = skin.Shine
		end
		return props
	end

	-- Body, and a saddle for the rider.
	local body = add("Body", turkey({ Size = Vector3.new(4.4, 3.8, 5.6), Color = skin.Body, Material = skin.BodyMaterial }, true), CFrame.new(), "Sphere")
	body.Sparkle = skin.Sparkle
	add("Body", { Size = Vector3.new(3.8, 0.15, 3.2), Color = rgb(200, 45, 40) }, CFrame.new(0, 1.82, 0.25))
	add("Body", { Size = Vector3.new(3, 0.6, 2.6), Color = rgb(125, 65, 30) }, CFrame.new(0, 2, 0.25))
	add("Body", { Size = Vector3.new(3.1, 0.2, 0.5), Color = rgb(255, 200, 60), Reflectance = 0.15 }, CFrame.new(0, 2.2, -1.05))

	-- Tail fan, leaning back behind the rider.
	for i = -2, 2 do
		local feather = CFrame.new(0, 0.9, 2.5) * CFrame.Angles(math.rad(15), 0, 0) * CFrame.Angles(0, 0, math.rad(i * 24)) * CFrame.new(0, 2.3, 0)
		local color = if #skin.Tail >= 5 then skin.Tail[i + 3] else skin.Tail[math.abs(i) + 1]
		add("Body", turkey({ Size = Vector3.new(1.5, 4.6, 0.3), Color = color, Material = skin.TailMaterial }), feather)
	end

	-- Wings fold against the sides.
	for _, side in { -1, 1 } do
		local joint = if side < 0 then "WingL" else "WingR"
		add(joint, turkey({ Size = Vector3.new(0.5, 2.4, 3.8), Color = skin.Body, Material = skin.BodyMaterial }, true), CFrame.new(side * 2.1, 0.1, 0.5), "Sphere")
	end

	-- Legs and feet.
	for _, side in { -1, 1 } do
		local joint = if side < 0 then "LegL" else "LegR"
		local hip = Skins.Joints[joint]
		add(joint, turkey({ Size = Vector3.new(0.45, 2.3, 0.45), Color = skin.Legs }), hip * CFrame.new(0, -1.15, 0))
		add(joint, turkey({ Size = Vector3.new(1.1, 0.3, 1.4), Color = skin.Legs }), hip * CFrame.new(0, -2.3, -0.35))
	end

	-- Neck and head.
	add("Head", turkey({ Size = Vector3.new(1.1, 2.4, 1.1), Color = skin.Head }, true), CFrame.new(0, 2.05, -2.6) * CFrame.Angles(math.rad(-16), 0, 0))
	head(turkey({ Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = skin.Head }, true), CFrame.new())
	head(turkey({ Size = Vector3.new(0.5, 0.4, 0.7), Color = skin.Beak }), CFrame.new(0, -0.1, -1))
	head(turkey({ Size = Vector3.new(0.35, 0.9, 0.35), Color = skin.Wattle }), CFrame.new(0.15, -0.65, -0.95))
	for _, x in { -0.4, 0.4 } do
		head({ Shape = ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = rgb(0, 0, 0) }, CFrame.new(x, 0.25, -0.85))
	end

	if skin.Extra == "Shades" then
		head({ Size = Vector3.new(1.5, 0.4, 0.2), Color = rgb(20, 20, 25), Reflectance = 0.3 }, CFrame.new(0, 0.28, -0.9))
	elseif skin.Extra == "Crown" then
		local gold = rgb(255, 200, 40)
		head({ Shape = cylinder, Size = Vector3.new(0.5, 1.3, 1.3), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, 0) * upright)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			local spike = CFrame.new(math.sin(angle) * 0.5, 1.45, math.cos(angle) * 0.5) * CFrame.Angles(0, angle, math.pi / 4)
			head({ Size = Vector3.new(0.3, 0.3, 0.3), Color = gold, Reflectance = 0.2 }, spike)
		end
		head({ Shape = ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = rgb(220, 30, 50) }, CFrame.new(0, 1.05, -0.66))
	elseif skin.Extra == "PilgrimHat" then
		-- A tall black hat with a brim, a band and a gold buckle on the front.
		local hat, band, gold = rgb(40, 36, 36), rgb(15, 15, 18), rgb(255, 200, 40)
		head({ Shape = cylinder, Size = Vector3.new(0.15, 2.3, 2.3), Color = hat }, CFrame.new(0, 0.82, 0.05) * upright)
		head({ Shape = cylinder, Size = Vector3.new(1.4, 1.25, 1.25), Color = hat }, CFrame.new(0, 1.6, 0.05) * upright)
		head({ Shape = cylinder, Size = Vector3.new(0.3, 1.32, 1.32), Color = band }, CFrame.new(0, 1.05, 0.05) * upright)
		head({ Size = Vector3.new(0.5, 0.42, 0.1), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, -0.62))
		head({ Size = Vector3.new(0.26, 0.2, 0.1), Color = band }, CFrame.new(0, 1.05, -0.65))
	elseif skin.Extra == "ChefHat" then
		-- A puffy white toque, plus two rows of buttons down the front of the body.
		local white = rgb(250, 250, 250)
		head({ Shape = cylinder, Size = Vector3.new(0.7, 1.5, 1.5), Color = white }, CFrame.new(0, 1.15, 0) * upright)
		head({ Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = white }, CFrame.new(0, 2.05, 0))
		for _, x in { -0.6, 0.6 } do
			head({ Shape = ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = white }, CFrame.new(x, 1.85, 0))
		end
		for _, x in { -0.6, 0.6 } do
			for _, y in { 0.4, -0.5 } do
				-- On the front of the body (an ellipsoid with half-sizes 2.2, 1.9, 2.8), poking out a little.
				local z = -2.8 * math.sqrt(1 - (x / 2.2) ^ 2 - (y / 1.9) ^ 2) - 0.05
				add("Body", { Shape = ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = rgb(40, 40, 45) }, CFrame.new(x, y, z))
			end
		end
	elseif skin.Extra == "Cream" then
		-- A dollop of whipped cream with a cherry on top.
		local cream = rgb(255, 250, 240)
		head({ Shape = ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = cream }, CFrame.new(0, 0.95, 0))
		head({ Shape = ball, Size = Vector3.new(1.1, 1.1, 1.1), Color = cream }, CFrame.new(0, 1.55, 0))
		head({ Shape = ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = rgb(210, 20, 40) }, CFrame.new(0, 2.15, 0))
	elseif skin.Extra == "Stem" then
		-- A pumpkin stem with a curly leaf.
		local green = rgb(90, 125, 40)
		head({ Shape = cylinder, Size = Vector3.new(1, 0.45, 0.45), Color = green }, CFrame.new(0.05, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-12)) * upright)
		head({ Size = Vector3.new(1, 0.12, 0.6), Color = rgb(110, 170, 50) }, CFrame.new(0.55, 1.05, 0) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	return list
end

return Skins
