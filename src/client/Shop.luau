-- Skin shop: a lobby button opens a panel of spinning turkey previews to buy with Feathers or equip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Skins = require(ReplicatedStorage.Shared.Skins)
local Audio = require(script.Parent.Audio)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Shop = {}

local GREEN = Color3.fromRGB(70, 170, 80)
local GREY = Color3.fromRGB(110, 110, 110)
local DIM_ORANGE = Color3.fromRGB(150, 95, 50)
local GOOD_TEXT = Color3.fromRGB(150, 235, 120)
local BAD_TEXT = Color3.fromRGB(255, 130, 110)

-- Where each piece's host body part sits on the preview turkey (torso at the origin).
local PREVIEW_HOSTS = {
	Torso = { CFrame.new() },
	Head = { CFrame.new(0, 1.5, 0) },
	Wing = { CFrame.new(-1.5, 0.2, 0), CFrame.new(1.5, 0.2, 0) },
}

local function previewPart(parent: Instance, props, cframe: CFrame)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.CFrame = cframe
	p.Parent = parent
end

-- Builds a little turkey in a ViewportFrame and returns the camera that looks at it.
local function buildPreview(card: Frame, skin): Camera
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundColor3 = Color3.fromRGB(255, 225, 170)
	viewport.BackgroundTransparency = 0.7
	viewport.Position = UDim2.new(0, 6, 0, 6)
	viewport.Size = UDim2.new(1, -12, 0.58, -6)
	Instance.new("UICorner").Parent = viewport
	viewport.Parent = card

	for _, piece in Skins.pieces(skin.Id) do
		for _, host in PREVIEW_HOSTS[piece.Host] do
			previewPart(viewport, piece.Props, host * piece.Offset)
		end
	end
	-- In game the legs are the avatar's own; the preview gets simple ones.
	for _, x in { -0.5, 0.5 } do
		previewPart(viewport, { Size = Vector3.new(0.4, 1.8, 0.4), Color = skin.Legs }, CFrame.new(x, -3.2, 0.2))
		previewPart(viewport, { Size = Vector3.new(0.9, 0.3, 1.1), Color = skin.Legs }, CFrame.new(x, -4.1, -0.1))
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function ownedSkins(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

function Shop.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyShop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local openButton = Ui.button(gui, {
		Name = "OpenButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 46),
		Text = "🛒 Shop",
	})

	local window = Ui.panel(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.82),
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(660, 420)
	limit.Parent = window

	Ui.label(window, {
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(0.5, -16, 0, 36),
		Text = "TURKEY SKINS",
		TextColor3 = Ui.ORANGE,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local featherLabel = Ui.label(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 14),
		Size = UDim2.new(0.35, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local closeButton = Ui.button(window, {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 40, 0, 36),
		BackgroundColor3 = Color3.fromRGB(200, 60, 50),
		Text = "X",
	})

	local cards = Instance.new("Frame")
	cards.Name = "Cards"
	cards.BackgroundTransparency = 1
	cards.Position = UDim2.new(0, 12, 0, 56)
	cards.Size = UDim2.new(1, -24, 1, -98)
	cards.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cards

	local message = Ui.label(window, {
		Name = "Message",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 28),
		Text = "",
	})

	local entries = {}
	local busy = false

	local function refresh()
		local owned = ownedSkins()
		local equipped = player:GetAttribute("Skin")
		local leaderstats = player:FindFirstChild("leaderstats")
		local feathers = if leaderstats then leaderstats.Feathers.Value else 0
		featherLabel.Text = `🪶 {feathers}`
		for _, entry in entries do
			local skin, button = entry.skin, entry.button
			if skin.Id == equipped then
				button.Text = "Equipped"
				button.BackgroundColor3 = GREY
			elseif owned[skin.Id] then
				button.Text = "Equip"
				button.BackgroundColor3 = GREEN
			else
				button.Text = `Buy 🪶 {skin.Price}`
				button.BackgroundColor3 = if feathers >= skin.Price then Ui.ORANGE else DIM_ORANGE
			end
		end
	end

	local function request(skin)
		if busy or skin.Id == player:GetAttribute("Skin") then
			return
		end
		busy = true
		local action = if ownedSkins()[skin.Id] then "Equip" else "Buy"
		local ok, success, text = pcall(Remotes.Shop.InvokeServer, Remotes.Shop, action, skin.Id)
		busy = false
		message.Text = if ok then text else "The shop is busy, try again!"
		message.TextColor3 = if ok and success then GOOD_TEXT else BAD_TEXT
		if ok and success then
			Audio.play(if action == "Buy" then "Purchase" else "Pickup")
		end
		refresh()
	end

	local count = #Skins.List
	for i, skin in Skins.List do
		local card = Ui.panel(cards, {
			Name = skin.Id,
			LayoutOrder = i,
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			BackgroundColor3 = Color3.fromRGB(95, 58, 32),
		})
		local camera = buildPreview(card, skin)
		Ui.label(card, {
			Position = UDim2.new(0.5, 0, 0.6, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(1, -12, 0.13, 0),
			Text = skin.Name,
		})
		local button = Ui.button(card, {
			Name = "Action",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0.2, 0),
		})
		button.Activated:Connect(function()
			request(skin)
		end)
		table.insert(entries, { skin = skin, camera = camera, button = button })
	end

	local function setOpen(open: boolean)
		window.Visible = open
		if open then
			message.Text = ""
			refresh()
		end
	end
	openButton.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	-- The shop is a lobby thing: hide it while racing.
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local racing = player:GetAttribute("Racing") == true
		openButton.Visible = not racing
		if racing then
			setOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("OwnedSkins"):Connect(refresh)
	player:GetAttributeChangedSignal("Skin"):Connect(refresh)
	task.spawn(function()
		player:WaitForChild("leaderstats"):WaitForChild("Feathers").Changed:Connect(refresh)
		refresh()
	end)

	-- Spin the previews while the shop is open.
	RunService.RenderStepped:Connect(function()
		if not window.Visible then
			return
		end
		local angle = os.clock() * 0.8
		local eye = Vector3.new(math.sin(angle) * 13, 1.5, -math.cos(angle) * 13)
		local view = CFrame.lookAt(eye, Vector3.new(0, -0.2, 0))
		for _, entry in entries do
			entry.camera.CFrame = view
		end
	end)
end

return Shop
