-- Turns every map's checkpoints into arches. Each checkpoint in a map's Checkpoints folder is a flat wall across
-- the track (Track reads where they are); this hides the wall and builds an orange-and-cream arch over the same
-- spot, with its number on a sign. Each arch also has a glowing inner strip, off until a racer's client lights
-- it up to show their next checkpoint (client/Checkpoints).
--
-- The arches go in an Arches folder in each map, each with an Index attribute (its checkpoint number).

local Arches = {}

local ORANGE = Color3.fromRGB(255, 140, 35)
local CREAM = Color3.fromRGB(255, 240, 210)
local WOOD = Color3.fromRGB(150, 92, 48)
local GOLD = Color3.fromRGB(255, 196, 52)
local GLOW = Color3.fromRGB(130, 255, 140)

local POST_HEIGHT = 12
local SEGMENTS = 12

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function numberSign(parent: Instance, cframe: CFrame, text: string)
	local board = part(parent, "Sign", Vector3.new(6, 3, 0.6), cframe, WOOD)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = CREAM
		label.TextStrokeColor3 = Color3.fromRGB(60, 30, 12)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = board
	end
end

-- Points along the arch's curve, from the top of one post over to the other: a half ellipse `rise` high.
local function curve(width: number, rise: number, lift: number): { Vector3 }
	local points = {}
	for i = 0, SEGMENTS do
		local angle = math.pi * (1 - i / SEGMENTS)
		table.insert(points, Vector3.new(math.cos(angle) * width / 2, POST_HEIGHT + lift + math.sin(angle) * rise, 0))
	end
	return points
end

-- A chain of blocks along `points` (in the arch's own space).
local function chain(parent: Instance, frame: CFrame, points: { Vector3 }, thickness: number, colorAt: (number) -> Color3, name: string, material: Enum.Material?)
	for i = 1, #points - 1 do
		local a, b = frame * points[i], frame * points[i + 1]
		local segment = part(parent, name, Vector3.new(thickness, thickness, (b - a).Magnitude + thickness * 0.4), CFrame.lookAt((a + b) / 2, b), colorAt(i))
		if material then
			segment.Material = material
		end
	end
end

local function build(checkpoint: BasePart, index: number, count: number, folder: Folder)
	-- The wall runs across the track along its longer side.
	local across = if checkpoint.Size.X >= checkpoint.Size.Z then checkpoint.CFrame.RightVector else checkpoint.CFrame.LookVector
	across = Vector3.new(across.X, 0, across.Z).Unit
	local width = math.max(checkpoint.Size.X, checkpoint.Size.Z)
	local floor = checkpoint.Position - Vector3.new(0, checkpoint.Size.Y / 2, 0)
	local frame = CFrame.fromMatrix(floor, across, Vector3.yAxis)
	local rise = math.clamp(width * 0.14, 4, 9)

	local arch = Instance.new("Model")
	arch.Name = "Arch" .. index
	arch:SetAttribute("Index", index)
	for _, side in { -1, 1 } do
		part(arch, "Post", Vector3.new(2.2, POST_HEIGHT, 2.2), frame * CFrame.new(side * width / 2, POST_HEIGHT / 2, 0), WOOD)
		part(arch, "Cap", Vector3.new(3, 3, 3), frame * CFrame.new(side * width / 2, POST_HEIGHT + 0.6, 0), GOLD, Enum.PartType.Ball)
	end
	chain(arch, frame, curve(width, rise, 0.6), 1.8, function(i)
		return if i % 2 == 0 then CREAM else ORANGE
	end, "Arc")
	-- The glow strip runs just inside the arch; it's hidden until it marks someone's next checkpoint.
	local glow = Instance.new("Model")
	glow.Name = "Glow"
	chain(glow, frame, curve(width - 2.6, rise - 1.3, 0), 0.7, function()
		return GLOW
	end, "Glow", Enum.Material.Neon)
	for _, p in glow:GetChildren() do
		(p :: BasePart).Transparency = 1
	end
	glow.Parent = arch
	numberSign(arch, frame * CFrame.new(0, POST_HEIGHT + rise - 2.6, 0), `{index}/{count}`)

	checkpoint.Transparency = 1
	arch.Parent = folder
end

function Arches.start()
	for _, map in workspace:WaitForChild("Maps"):GetChildren() do
		local checkpoints = map:FindFirstChild("Checkpoints")
		if checkpoints and not map:FindFirstChild("Arches") then
			local folder = Instance.new("Folder")
			folder.Name = "Arches"
			local count = #checkpoints:GetChildren()
			for i = 1, count do
				local checkpoint = checkpoints:FindFirstChild("CP" .. i)
				if checkpoint and checkpoint:IsA("BasePart") then
					build(checkpoint, i, count, folder)
				end
			end
			folder.Parent = map
		end
	end
end

return Arches
