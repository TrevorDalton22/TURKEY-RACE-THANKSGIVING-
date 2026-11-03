-- Dresses every character as a turkey: hides the avatar's body and welds on a feathered suit.

local Players = game:GetService("Players")

local TurkeySuit = {}

local BODY = Color3.fromRGB(120, 72, 40)
local HEAD = Color3.fromRGB(170, 120, 90)
local LEGS = Color3.fromRGB(240, 150, 40)
local TAIL = { Color3.fromRGB(150, 80, 35), Color3.fromRGB(205, 120, 45), Color3.fromRGB(235, 175, 70) }

local function attach(host: BasePart?, props, offset: CFrame)
	if not host then
		return
	end
	local p = Instance.new("Part")
	p.Name = "TurkeySuit"
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.CFrame = host.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = p
	weld.Parent = p
	p.Parent = host.Parent
end

local function dress(character: Model)
	for _, item in character:GetChildren() do
		if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if part.Name:find("Leg") or part.Name:find("Foot") then
				part.Color = LEGS
			else
				part.Transparency = 1
			end
		end
	end
	local face = character:FindFirstChild("Head") and character.Head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end

	local ball = Enum.PartType.Ball
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")

	attach(torso, { Shape = ball, Size = Vector3.new(4.2, 4.2, 4.2), Color = BODY }, CFrame.new(0, -0.3, 0.2))
	for i = -2, 2 do
		local feather = CFrame.new(0, 0.6, 1.9) * CFrame.Angles(0, 0, math.rad(i * 25)) * CFrame.new(0, 1.6, 0)
		attach(torso, { Size = Vector3.new(1.2, 3.6, 0.3), Color = TAIL[math.abs(i) + 1] }, feather)
	end

	attach(head, { Shape = ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = HEAD }, CFrame.new())
	attach(head, { Size = Vector3.new(0.5, 0.4, 0.7), Color = Color3.fromRGB(245, 170, 40) }, CFrame.new(0, -0.1, -1))
	attach(head, { Size = Vector3.new(0.35, 0.9, 0.35), Color = Color3.fromRGB(210, 30, 40) }, CFrame.new(0.15, -0.65, -0.95))
	for _, x in { -0.4, 0.4 } do
		attach(head, { Shape = ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = Color3.new(0, 0, 0) }, CFrame.new(x, 0.25, -0.85))
	end

	-- Wings ride on the upper arms, so the normal arm animations flap them.
	for _, name in { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" } do
		attach(character:FindFirstChild(name), { Size = Vector3.new(0.5, 2.2, 1.6), Color = BODY }, CFrame.new(0, -0.3, 0.2))
	end
end

function TurkeySuit.start()
	local function watch(player: Player)
		player.CharacterAppearanceLoaded:Connect(dress)
		if player:HasAppearanceLoaded() and player.Character then
			dress(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TurkeySuit
