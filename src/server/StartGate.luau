-- The starting gate: a pair of red-and-white doors across the track just in front of the racers' pads, between
-- two posts with a sign on top. It's built as racers line up and taken down a few seconds after GO; each
-- client swings the doors open at GO (client/StartGate). It's only for show: nothing collides with it, and
-- racers are held in place until GO anyway.
--
-- Each door is a Model with the attributes Hinge (the CFrame it turns around) and Swing (+1 or -1, the way
-- it turns so it opens forward, down the track).

local Track = require(script.Parent.Track)

local StartGate = {}

local RED = Color3.fromRGB(225, 55, 45)
local WHITE = Color3.fromRGB(250, 246, 236)
local WOOD = Color3.fromRGB(150, 92, 48)
local GOLD = Color3.fromRGB(255, 196, 52)

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

local function sign(beam: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = if face == Enum.NormalId.Front then "Front" else "Back"
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = Color3.fromRGB(90, 40, 15)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = beam
end

-- Builds the gate for the current map in front of its start pads and returns it.
function StartGate.build(): Model
	local pads = Track.StartPads
	local _, forward = Track.pointAt(0)
	local right = forward:Cross(Vector3.yAxis)

	-- How far ahead the front row reaches, and how wide the rows are, measured from the first pad.
	local base = pads[1].Position
	local front, minSide, maxSide = -math.huge, math.huge, -math.huge
	for _, pad in pads do
		local offset = pad.Position - base
		local half = math.max(pad.Size.X, pad.Size.Z) / 2
		front = math.max(front, offset:Dot(forward) + half)
		local side = offset:Dot(right)
		minSide = math.min(minSide, side - half)
		maxSide = math.max(maxSide, side + half)
	end
	local width = math.min(maxSide - minSide + 8, Track.LaneWidth - 2)
	local floorY = base.Y - pads[1].Size.Y / 2
	local center = base + forward * (front + 4) + right * ((minSide + maxSide) / 2)
	center = Vector3.new(center.X, floorY, center.Z)
	-- The gate's front faces the racers, so its local +Z points down the track.
	local frame = CFrame.lookAt(center, center - forward)

	local gate = Instance.new("Model")
	gate.Name = "StartGate"
	gate.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local half = width / 2
	for _, x in { -(half + 1), half + 1 } do
		part(gate, "Post", Vector3.new(2, 16, 2), frame * CFrame.new(x, 8, 0), RED)
		part(gate, "Cap", Vector3.new(2.8, 1, 2.8), frame * CFrame.new(x, 16.5, 0), GOLD)
		part(gate, "Knob", Vector3.new(2, 2, 2), frame * CFrame.new(x, 17.8, 0), GOLD, Enum.PartType.Ball)
	end
	local beam = part(gate, "Sign", Vector3.new(width + 6, 3.2, 1.4), frame * CFrame.new(0, 14.6, 0), WOOD)
	sign(beam, Enum.NormalId.Front, "GET READY!")
	sign(beam, Enum.NormalId.Back, "🦃 TURKEY RACE 🦃")

	-- Two doors, each from its post to the middle, hinged at the post.
	local doorLength = half - 0.2
	for _, side in { -1, 1 } do
		local door = Instance.new("Model")
		door.Name = if side < 0 then "DoorL" else "DoorR"
		local hinge = frame * CFrame.new(side * half, 0, 0)
		-- Back toward the middle from the hinge.
		local function at(along: number, y: number): CFrame
			return hinge * CFrame.new(-side * along, y, 0)
		end
		for i, y in { 2.4, 5, 7.6 } do
			part(door, "Slat", Vector3.new(doorLength, 1.5, 0.5), at(doorLength / 2, y), if i == 2 then WHITE else RED)
		end
		for _, along in { 0.45, doorLength - 0.45 } do
			part(door, "Stile", Vector3.new(0.9, 7.8, 0.7), at(along, 5), WHITE)
		end
		door:SetAttribute("Hinge", hinge)
		-- Turning this way about the hinge sends the door's free end forward, down the track.
		door:SetAttribute("Swing", side)
		door.Parent = gate
	end

	gate.Parent = workspace
	return gate
end

return StartGate
