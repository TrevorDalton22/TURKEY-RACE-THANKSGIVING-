-- Helpers for the room builders in this folder. The maps live in the place file, not in Rojo; these scripts build
-- the rooms around each map's track, so the scenery can be rebuilt from code. Nothing in the game loads them. To run
-- one, use Studio's command bar, then save the place:
--
--   loadstring(game.ServerScriptService.Server.MapBuilders.DiningRoom.Source)()
--
-- Each one can be run again: it replaces its own Room folder and leaves the track, gates and item boxes alone.
--
-- Everything a builder makes is scenery: anchored, and nothing can stand on it or be hit by it, so the only things
-- a turkey touches are the track surfaces and obstacles that were already in the map. A turkey that goes over the
-- edge drops through the furniture to the floor and respawns at its last checkpoint.

local Kit = {}

local made = 0

local function finish(p: BasePart, parent: Instance, name: string, material: Enum.Material?, options)
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	if options then
		for k, v in options do
			p[k] = v
		end
	end
	p.Parent = parent
	made += 1
	if made % 300 == 0 then
		task.wait() -- keeps Studio responsive during a big build
	end
	return p
end

-- A block. Parts are limited to 2048 studs a side, which is bigger than any room here.
function Kit.box(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, options)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	return finish(p, parent, name, material, options)
end

function Kit.ball(parent: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?, options)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * diameter
	p.Position = position
	p.Color = color
	return finish(p, parent, name, material, options)
end

-- An upright cylinder, centered on `position`.
function Kit.post(parent: Instance, name: string, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?, options)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	p.Color = color
	return finish(p, parent, name, material, options)
end

-- A cylinder running along the line from `a` to `b`.
function Kit.pipe(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, options)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new((b - a).Magnitude, diameter, diameter)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	p.Color = color
	return finish(p, parent, name, material, options)
end

function Kit.wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, options)
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	return finish(p, parent, name, material, options)
end

-- A soft glow, for lamps and windows. Keep these few: each one costs every player some frame rate.
function Kit.light(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

-- Text on the front of a part.
function Kit.sign(part: BasePart, text: string, color: Color3, stroke: Color3?, face: Enum.NormalId?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Scaled text stops growing at 100 pixels, so the surface is made about that tall to let it fill the part.
	gui.PixelsPerStud = 110 / part.Size.Y
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	if stroke then
		label.TextStrokeColor3 = stroke
		label.TextStrokeTransparency = 0
	end
	label.Parent = gui
	gui.Parent = part
	return gui
end

-- A new empty folder in `map`, replacing any left by the last build, so a builder can be run again.
function Kit.fresh(map: Instance, name: string): Folder
	local old = map:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = map
	return folder
end

function Kit.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- The invisible part that says where the chef's feet go (Track reads it).
function Kit.chefSpot(map: Instance, position: Vector3, facing: Vector3)
	local old = map:FindFirstChild("ChefSpot")
	if old then
		old:Destroy()
	end
	return Kit.box(map, "ChefSpot", Vector3.new(4, 1, 4), CFrame.lookAt(position, position + facing), Color3.new(1, 1, 1), nil, { Transparency = 1 })
end

-- Moves the start pads, Pad1 first. Rows need to be at least 13 studs apart to fit a turkey.
function Kit.layPads(map: Instance, positions: { { number } })
	for i, position in positions do
		local pad = map.StartPads["Pad" .. i]
		pad.Position = Vector3.new(position[1], pad.Position.Y, position[2])
	end
end

return Kit
