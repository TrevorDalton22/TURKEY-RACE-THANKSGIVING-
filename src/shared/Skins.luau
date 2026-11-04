-- Turkey skins: shop prices, colors, and the suit pieces each skin is built from.
-- The server welds the pieces onto characters, and the shop builds its previews from the same pieces.

local Skins = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Skins.Default = "Classic"

-- In shop order. Anything a skin leaves out comes from Classic.
--   Transparency: see-through suit and legs (0..1)   Shine: reflectance of the body, head and wings
--   Sparkle: glitter drifting off the body in this color   Extra: a hat or other add-on, built in Skins.pieces
Skins.List = {
	{
		Id = "Classic",
		Name = "Classic Turkey",
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
		Price = 100,
		Body = rgb(55, 105, 185),
		Head = rgb(150, 200, 240),
		Tail = { rgb(35, 70, 150), rgb(60, 160, 215), rgb(170, 235, 255) },
		Extra = "Shades",
	},
	{
		Id = "Pilgrim",
		Name = "Pilgrim Turkey",
		Price = 150,
		Body = rgb(55, 50, 50),
		Tail = { rgb(95, 65, 45), rgb(150, 100, 60), rgb(205, 165, 110) },
		Extra = "PilgrimHat",
	},
	{
		Id = "Lava",
		Name = "Lava Turkey",
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
		Price = 750,
		Body = rgb(245, 245, 245),
		Extra = "ChefHat",
	},
	{
		Id = "Golden",
		Name = "Golden Turkey",
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
}

Skins.byId = {}
for _, skin in Skins.List do
	for key, value in Skins.List[1] do
		if skin[key] == nil then
			skin[key] = value
		end
	end
	Skins.byId[skin.Id] = skin
end

-- Unknown or missing ids fall back to the default skin.
function Skins.get(id: string?)
	return Skins.byId[id] or Skins.byId[Skins.Default]
end

-- Sparkle: set on the body piece when its skin glitters; the suit adds the particles.
export type Piece = { Host: string, Props: { [string]: any }, Offset: CFrame, Sparkle: Color3? }

-- The parts that make up a skin's suit. Host is the body part a piece rides on:
-- "Torso" (UpperTorso or Torso), "Head", or "Wing" (one per upper arm).
function Skins.pieces(id: string?): { Piece }
	local skin = Skins.get(id)
	local ball, cylinder = Enum.PartType.Ball, Enum.PartType.Cylinder
	-- A cylinder's axis is its X, so this turns it upright.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local list = {}
	local function add(host: string, props, offset: CFrame): Piece
		local piece = { Host = host, Props = props, Offset = offset }
		table.insert(list, piece)
		return piece
	end
	-- The turkey's own feathers and skin, as opposed to hats and other add-ons.
	local function turkey(props, shiny: boolean?)
		props.Transparency = skin.Transparency
		if shiny then
			props.Reflectance = skin.Shine
		end
		return props
	end

	local body = add("Torso", turkey({ Shape = ball, Size = Vector3.new(4.2, 4.2, 4.2), Color = skin.Body, Material = skin.BodyMaterial }, true), CFrame.new(0, -0.3, 0.2))
	body.Sparkle = skin.Sparkle
	for i = -2, 2 do
		local feather = CFrame.new(0, 0.6, 1.9) * CFrame.Angles(0, 0, math.rad(i * 25)) * CFrame.new(0, 1.6, 0)
		add("Torso", turkey({ Size = Vector3.new(1.2, 3.6, 0.3), Color = skin.Tail[math.abs(i) + 1], Material = skin.TailMaterial }), feather)
	end

	-- Wings ride on the upper arms, so the normal arm animations flap them.
	add("Wing", turkey({ Size = Vector3.new(0.5, 2.2, 1.6), Color = skin.Body, Material = skin.BodyMaterial }, true), CFrame.new(0, -0.3, 0.2))

	add("Head", turkey({ Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = skin.Head }, true), CFrame.new())
	add("Head", turkey({ Size = Vector3.new(0.5, 0.4, 0.7), Color = skin.Beak }), CFrame.new(0, -0.1, -1))
	add("Head", turkey({ Size = Vector3.new(0.35, 0.9, 0.35), Color = skin.Wattle }), CFrame.new(0.15, -0.65, -0.95))
	for _, x in { -0.4, 0.4 } do
		add("Head", { Shape = ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = rgb(0, 0, 0) }, CFrame.new(x, 0.25, -0.85))
	end

	if skin.Extra == "Shades" then
		add("Head", { Size = Vector3.new(1.5, 0.4, 0.2), Color = rgb(20, 20, 25), Reflectance = 0.3 }, CFrame.new(0, 0.28, -0.9))
	elseif skin.Extra == "Crown" then
		local gold = rgb(255, 200, 40)
		add("Head", { Shape = cylinder, Size = Vector3.new(0.5, 1.3, 1.3), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, 0) * upright)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			local spike = CFrame.new(math.sin(angle) * 0.5, 1.45, math.cos(angle) * 0.5) * CFrame.Angles(0, angle, math.pi / 4)
			add("Head", { Size = Vector3.new(0.3, 0.3, 0.3), Color = gold, Reflectance = 0.2 }, spike)
		end
		add("Head", { Shape = ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = rgb(220, 30, 50) }, CFrame.new(0, 1.05, -0.66))
	elseif skin.Extra == "PilgrimHat" then
		-- A tall black hat with a brim, a band and a gold buckle on the front.
		local hat, band, gold = rgb(40, 36, 36), rgb(15, 15, 18), rgb(255, 200, 40)
		add("Head", { Shape = cylinder, Size = Vector3.new(0.15, 2.3, 2.3), Color = hat }, CFrame.new(0, 0.82, 0.05) * upright)
		add("Head", { Shape = cylinder, Size = Vector3.new(1.4, 1.25, 1.25), Color = hat }, CFrame.new(0, 1.6, 0.05) * upright)
		add("Head", { Shape = cylinder, Size = Vector3.new(0.3, 1.32, 1.32), Color = band }, CFrame.new(0, 1.05, 0.05) * upright)
		add("Head", { Size = Vector3.new(0.5, 0.42, 0.1), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, -0.62))
		add("Head", { Size = Vector3.new(0.26, 0.2, 0.1), Color = band }, CFrame.new(0, 1.05, -0.65))
	elseif skin.Extra == "ChefHat" then
		-- A puffy white toque, plus two rows of buttons down the chef's coat.
		local white = rgb(250, 250, 250)
		add("Head", { Shape = cylinder, Size = Vector3.new(0.7, 1.5, 1.5), Color = white }, CFrame.new(0, 1.15, 0) * upright)
		add("Head", { Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = white }, CFrame.new(0, 2.05, 0))
		for _, x in { -0.6, 0.6 } do
			add("Head", { Shape = ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = white }, CFrame.new(x, 1.85, 0))
		end
		for _, x in { -0.55, 0.55 } do
			for _, y in { 0.6, -0.3 } do
				-- On the front of the body ball (radius 2.1, centered at 0, -0.3, 0.2), poking out a little.
				local z = 0.2 - math.sqrt(2.1 ^ 2 - x ^ 2 - y ^ 2) + 0.05
				add("Torso", { Shape = ball, Size = Vector3.new(0.32, 0.32, 0.32), Color = rgb(40, 40, 45) }, CFrame.new(x, y - 0.3, z))
			end
		end
	end
	return list
end

return Skins
