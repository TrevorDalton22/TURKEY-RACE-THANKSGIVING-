-- Turkey skins: shop prices, colors, and the suit pieces each skin is built from.
-- The server welds the pieces onto characters, and the shop builds its previews from the same pieces.

local Skins = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Skins.Default = "Classic"

-- In shop order. Anything a skin leaves out comes from Classic.
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
		Id = "King",
		Name = "King Turkey",
		Price = 500,
		Body = rgb(95, 45, 140),
		Head = rgb(190, 150, 120),
		Tail = { rgb(120, 50, 170), rgb(215, 165, 40), rgb(255, 225, 90) },
		Extra = "Crown",
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

export type Piece = { Host: string, Props: { [string]: any }, Offset: CFrame }

-- The parts that make up a skin's suit. Host is the body part a piece rides on:
-- "Torso" (UpperTorso or Torso), "Head", or "Wing" (one per upper arm).
function Skins.pieces(id: string?): { Piece }
	local skin = Skins.get(id)
	local ball = Enum.PartType.Ball
	local list = {}
	local function add(host: string, props, offset: CFrame)
		table.insert(list, { Host = host, Props = props, Offset = offset })
	end

	add("Torso", { Shape = ball, Size = Vector3.new(4.2, 4.2, 4.2), Color = skin.Body, Material = skin.BodyMaterial }, CFrame.new(0, -0.3, 0.2))
	for i = -2, 2 do
		local feather = CFrame.new(0, 0.6, 1.9) * CFrame.Angles(0, 0, math.rad(i * 25)) * CFrame.new(0, 1.6, 0)
		add("Torso", { Size = Vector3.new(1.2, 3.6, 0.3), Color = skin.Tail[math.abs(i) + 1], Material = skin.TailMaterial }, feather)
	end

	-- Wings ride on the upper arms, so the normal arm animations flap them.
	add("Wing", { Size = Vector3.new(0.5, 2.2, 1.6), Color = skin.Body, Material = skin.BodyMaterial }, CFrame.new(0, -0.3, 0.2))

	add("Head", { Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = skin.Head }, CFrame.new())
	add("Head", { Size = Vector3.new(0.5, 0.4, 0.7), Color = skin.Beak }, CFrame.new(0, -0.1, -1))
	add("Head", { Size = Vector3.new(0.35, 0.9, 0.35), Color = skin.Wattle }, CFrame.new(0.15, -0.65, -0.95))
	for _, x in { -0.4, 0.4 } do
		add("Head", { Shape = ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = rgb(0, 0, 0) }, CFrame.new(x, 0.25, -0.85))
	end

	if skin.Extra == "Shades" then
		add("Head", { Size = Vector3.new(1.5, 0.4, 0.2), Color = rgb(20, 20, 25), Reflectance = 0.3 }, CFrame.new(0, 0.28, -0.9))
	elseif skin.Extra == "Crown" then
		local gold = rgb(255, 200, 40)
		-- A cylinder's axis is its X, so turn it upright.
		add("Head", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.3, 1.3), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.pi / 2))
		for i = 0, 3 do
			local angle = i * math.pi / 2
			local spike = CFrame.new(math.sin(angle) * 0.5, 1.45, math.cos(angle) * 0.5) * CFrame.Angles(0, angle, math.pi / 4)
			add("Head", { Size = Vector3.new(0.3, 0.3, 0.3), Color = gold, Reflectance = 0.2 }, spike)
		end
		add("Head", { Shape = ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = rgb(220, 30, 50) }, CFrame.new(0, 1.05, -0.66))
	end
	return list
end

return Skins
