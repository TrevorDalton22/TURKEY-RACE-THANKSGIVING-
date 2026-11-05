-- The turkey showroom by the spawn (Workspace.Lobby.Showroom): each stand there has a Skin attribute, and this
-- puts that skin's turkey on it, slowly turning, with a sign showing its name, rarity and price (or that you
-- own it), and a prompt that opens the shop on that skin. Change a stand's Skin attribute in Studio to feature
-- a different turkey.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Purchases = require(script.Parent.Purchases)
local Shop = require(script.Parent.Shop)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Showroom = {}

local SPIN_SPEED = 0.6 -- radians a second

-- Which pass tier gives each pass skin.
local passTier: { [string]: number } = {}
for tier, rewards in Season.Rewards do
	for _, reward in { rewards.Free, rewards.Premium } do
		if reward and reward.Skin then
			passTier[reward.Skin] = tier
		end
	end
end

-- The skin's turkey as one model whose pivot is the middle of its body, standing on nothing yet.
local function turkey(skinId: string): Model
	local model = Instance.new("Model")
	model.Name = "ShowroomTurkey"
	for _, piece in Skins.pieces(skinId) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in piece.Props do
			p[k] = v
		end
		if piece.Mesh == "Sphere" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.CFrame = piece.Offset
		if piece.Sparkle then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(piece.Sparkle)
			sparkle.LightEmission = 0.8
			sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			sparkle.Lifetime = NumberRange.new(0.8, 1.4)
			sparkle.Speed = NumberRange.new(1, 2)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Rate = 12
			sparkle.Parent = p
		end
		p.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- What the sign says about getting this skin.
local function priceText(skin, owned: { [string]: boolean }, prices): (string, Color3)
	if player:GetAttribute("Skin") == skin.Id then
		return "✅ EQUIPPED", Ui.GREEN
	elseif owned[skin.Id] then
		return "✅ OWNED", Ui.GREEN
	end
	local source = Skins.source(skin)
	if source == "Robux" then
		return Purchases.label(prices[skin.Id], Config.Robux.Skins[skin.Id] or 0), Color3.fromRGB(120, 235, 160)
	elseif source == "Pass" then
		return `🎟️ Pass tier {passTier[skin.Id] or "?"}`, Color3.fromRGB(215, 160, 255)
	end
	return `{Format.FEATHER} {Format.number(skin.Price)}`, Ui.CREAM
end

local function sign(stand: BasePart, skin, height: number): TextLabel
	local board = Instance.new("BillboardGui")
	board.Name = "ShowroomSign"
	board.Adornee = stand
	board.ResetOnSpawn = false
	board.Size = UDim2.new(8, 0, 3.4, 0) -- in studs
	board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	board.LightInfluence = 0
	board.MaxDistance = 120
	board.Parent = player:WaitForChild("PlayerGui")

	local rarity = Skins.Rarities[skin.Rarity]
	local back = Ui.card(board, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.DARK })
	back.Border.Color = rarity.Color
	Ui.label(back, { Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.4), Text = skin.Name, TextColor3 = rarity.Color })
	Ui.label(back, { Position = UDim2.fromScale(0.05, 0.44), Size = UDim2.fromScale(0.9, 0.2), Text = string.upper(skin.Rarity), TextColor3 = Ui.CREAM })
	return Ui.label(back, { Position = UDim2.fromScale(0.05, 0.66), Size = UDim2.fromScale(0.9, 0.28) })
end

function Showroom.start()
	local lobby = workspace:WaitForChild("Lobby")
	local showroom = lobby:WaitForChild("Showroom", 15)
	if not showroom then
		return
	end
	-- Wait for the stands to stream in.
	task.wait(1)

	local displays = {}
	local prices = {}
	for _, stand in showroom:GetChildren() do
		local skin = stand:IsA("BasePart") and Skins.byId[stand:GetAttribute("Skin") or ""]
		if skin then
			local model = turkey(skin.Id)
			-- ExtentsSize is the stand's size in the world, so a cylinder stood on end works too.
			local half = stand.ExtentsSize.Y / 2
			local top = stand.Position + Vector3.new(0, half + Skins.FootDepth + 0.1, 0)
			model.Parent = workspace
			local price = sign(stand, skin, half + 12)

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "View in Shop"
			prompt.ObjectText = skin.Name
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = stand
			prompt.Triggered:Connect(function()
				Shop.open(skin.Id)
			end)

			-- Each turkey starts facing a different way so they don't turn in step.
			table.insert(displays, { model = model, top = top, skin = skin, price = price, phase = #displays * 1.7 })
			if skin.Robux then
				Purchases.price("GamePass", Config.Robux.Skins[skin.Id] or 0, function(robux)
					prices[skin.Id] = robux
				end)
			end
		end
	end

	local lastSigns = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, display in displays do
			local bob = math.sin(now * 1.6 + display.phase) * 0.25
			display.model:PivotTo(CFrame.new(display.top + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * SPIN_SPEED + display.phase, 0))
		end
		-- The signs only need checking now and then.
		if now - lastSigns > 0.5 then
			lastSigns = now
			local owned = {}
			for id in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
				owned[id] = true
			end
			for _, display in displays do
				local text, color = priceText(display.skin, owned, prices)
				display.price.Text = text
				display.price.TextColor3 = color
			end
		end
	end)
end

return Showroom
