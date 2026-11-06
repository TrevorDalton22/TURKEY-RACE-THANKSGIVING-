-- Turkey skins: shop prices, how each looks on the rigged turkey (shared/TurkeyModel), and any add-ons it wears.

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
-- Looks:
--   Palette: the Roblox image of its colors. assets/turkey/make_palettes.py makes them from a few colors per skin.
--            Its shine and glow are set on its SurfaceAppearance in ReplicatedStorage.TurkeyRig.Skins.
--   Transparency: a see-through turkey (0..1)   Sparkle: glitter drifting off the body in this color
--   Extra: a hat or other add-on, built in Skins.pieces
Skins.List = {
	{ Id = "Classic", Name = "Classic Turkey", Rarity = "Common", Price = 0, Palette = 89849573616148 },
	{ Id = "Cool", Name = "Cool Turkey", Rarity = "Common", Price = 100, Palette = 97003162040902, Extra = "Shades" },
	{ Id = "Pilgrim", Name = "Pilgrim Turkey", Rarity = "Common", Price = 150, Palette = 86474545635084, Extra = "PilgrimHat" },
	{ Id = "Lava", Name = "Lava Turkey", Rarity = "Rare", Price = 250, Palette = 81510312765905 },
	{ Id = "Ghost", Name = "Ghost Turkey", Rarity = "Rare", Price = 350, Palette = 102045794659158, Transparency = 0.4 },
	{ Id = "King", Name = "King Turkey", Rarity = "Epic", Price = 500, Palette = 74379923751329, Extra = "Crown" },
	-- Dressed up as the villain who's chasing everyone.
	{ Id = "Chef", Name = "Chef Turkey", Rarity = "Epic", Price = 750, Palette = 87750107987977, Extra = "ChefHat" },
	{ Id = "Golden", Name = "Golden Turkey", Rarity = "Legendary", Price = 1000, Palette = 88959813752141, Sparkle = rgb(255, 230, 120) },

	-- Robux skins ------------------------------------------------------------------------------------
	{ Id = "Rainbow", Name = "Rainbow Turkey", Rarity = "Legendary", Robux = true, Palette = 111545350862054, Sparkle = rgb(255, 255, 255), Extra = "Shades" },
	{ Id = "Galaxy", Name = "Galaxy Turkey", Rarity = "Mythic", Robux = true, Palette = 122649017042638, Sparkle = rgb(220, 230, 255) },
	{ Id = "Diamond", Name = "Diamond Turkey", Rarity = "Mythic", Robux = true, Palette = 108355139130264, Sparkle = rgb(230, 250, 255), Extra = "Crown" },

	-- Harvest Pass skins -----------------------------------------------------------------------------
	{ Id = "Cranberry", Name = "Cranberry Turkey", Rarity = "Rare", Pass = true, Palette = 90721390953011 },
	{ Id = "Harvest", Name = "Harvest Turkey", Rarity = "Rare", Pass = true, Palette = 117000075618815, Extra = "PilgrimHat" },
	{ Id = "Pie", Name = "Pumpkin Pie Turkey", Rarity = "Epic", Pass = true, Palette = 80008457369812, Extra = "Cream" },
	{ Id = "Pumpkin", Name = "Pumpkin Turkey", Rarity = "Epic", Pass = true, Palette = 71703985947122, Extra = "Stem" },
	{ Id = "Feast", Name = "Feast King Turkey", Rarity = "Legendary", Pass = true, Palette = 99172873073515, Sparkle = rgb(255, 215, 110), Extra = "Crown" },
}

Skins.byId = {}
for _, skin in Skins.List do
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

-- The middle of the turkey's head, with it standing at the origin facing -Z.
local HEAD = CFrame.new(0, 8.95, -3.15)
-- Hats were sized for a head radius of 1; this fits them to the turkey's.
local HAT_SCALE = 1.7

-- A part made of Props, at CFrame with the turkey standing at the origin. Group "Head" moves with the head, and
-- "Body" with the body.
export type Piece = { Group: string, Props: { [string]: any }, CFrame: CFrame }

-- The add-on parts a skin wears.
function Skins.pieces(id: string?): { Piece }
	local skin = Skins.get(id)
	local ball, cylinder = Enum.PartType.Ball, Enum.PartType.Cylinder
	-- A cylinder's axis is its X, so this turns it upright.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local list = {}
	-- Placed relative to the middle of the head and scaled to fit it.
	local function hat(props, offset: CFrame)
		props.Size *= HAT_SCALE
		table.insert(list, { Group = "Head", Props = props, CFrame = HEAD * (offset - offset.Position) + HEAD:VectorToWorldSpace(offset.Position * HAT_SCALE) })
	end

	if skin.Extra == "Shades" then
		-- Wide enough for those eyes, which sit about 2 studs out in front of the middle of the head.
		local black = { Color = rgb(20, 20, 25), Reflectance = 0.3 }
		local function shades(size: Vector3, offset: CFrame)
			table.insert(list, { Group = "Head", Props = { Size = size, Color = black.Color, Reflectance = black.Reflectance }, CFrame = HEAD * offset })
		end
		shades(Vector3.new(4.1, 1.15, 0.22), CFrame.new(0, 0.42, -2.22))
		for _, x in { -2, 2 } do
			shades(Vector3.new(0.16, 0.22, 2.4), CFrame.new(x, 0.62, -1.05))
		end
	elseif skin.Extra == "Crown" then
		local gold = rgb(255, 200, 40)
		hat({ Shape = cylinder, Size = Vector3.new(0.5, 1.3, 1.3), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, 0) * upright)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			local spike = CFrame.new(math.sin(angle) * 0.5, 1.45, math.cos(angle) * 0.5) * CFrame.Angles(0, angle, math.pi / 4)
			hat({ Size = Vector3.new(0.3, 0.3, 0.3), Color = gold, Reflectance = 0.2 }, spike)
		end
		hat({ Shape = ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = rgb(220, 30, 50) }, CFrame.new(0, 1.05, -0.66))
	elseif skin.Extra == "PilgrimHat" then
		-- A tall black hat with a brim, a band and a gold buckle on the front.
		local black, band, gold = rgb(40, 36, 36), rgb(15, 15, 18), rgb(255, 200, 40)
		hat({ Shape = cylinder, Size = Vector3.new(0.15, 2.3, 2.3), Color = black }, CFrame.new(0, 0.82, 0.05) * upright)
		hat({ Shape = cylinder, Size = Vector3.new(1.4, 1.25, 1.25), Color = black }, CFrame.new(0, 1.6, 0.05) * upright)
		hat({ Shape = cylinder, Size = Vector3.new(0.3, 1.32, 1.32), Color = band }, CFrame.new(0, 1.05, 0.05) * upright)
		hat({ Size = Vector3.new(0.5, 0.42, 0.1), Color = gold, Reflectance = 0.2 }, CFrame.new(0, 1.05, -0.62))
		hat({ Size = Vector3.new(0.26, 0.2, 0.1), Color = band }, CFrame.new(0, 1.05, -0.65))
	elseif skin.Extra == "ChefHat" then
		-- A puffy white toque, plus two rows of buttons down the chest.
		local white = rgb(250, 250, 250)
		hat({ Shape = cylinder, Size = Vector3.new(0.7, 1.5, 1.5), Color = white }, CFrame.new(0, 1.15, 0) * upright)
		hat({ Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = white }, CFrame.new(0, 2.05, 0))
		for _, x in { -0.6, 0.6 } do
			hat({ Shape = ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = white }, CFrame.new(x, 1.85, 0))
		end
		for _, x in { -0.75, 0.75 } do
			for _, y in { 5, 3.9 } do
				table.insert(list, { Group = "Body", Props = { Shape = ball, Size = Vector3.one * 0.55, Color = rgb(40, 40, 45) }, CFrame = CFrame.new(x, y, -3.25) })
			end
		end
	elseif skin.Extra == "Cream" then
		-- A dollop of whipped cream with a cherry on top.
		local cream = rgb(255, 250, 240)
		hat({ Shape = ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = cream }, CFrame.new(0, 0.95, 0))
		hat({ Shape = ball, Size = Vector3.new(1.1, 1.1, 1.1), Color = cream }, CFrame.new(0, 1.55, 0))
		hat({ Shape = ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = rgb(210, 20, 40) }, CFrame.new(0, 2.15, 0))
	elseif skin.Extra == "Stem" then
		-- A pumpkin stem with a curly leaf.
		local green = rgb(90, 125, 40)
		hat({ Shape = cylinder, Size = Vector3.new(1, 0.45, 0.45), Color = green }, CFrame.new(0.05, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-12)) * upright)
		hat({ Size = Vector3.new(1, 0.12, 0.6), Color = rgb(110, 170, 50) }, CFrame.new(0.55, 1.05, 0) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	return list
end

return Skins
