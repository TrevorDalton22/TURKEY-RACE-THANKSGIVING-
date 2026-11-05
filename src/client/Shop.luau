-- The shop, opened from a lobby button, with two tabs:
--   Skins   spinning previews of every skin with its rarity. Feather skins are bought here, Robux skins
--           open Roblox's purchase prompt, and pass skins open the Harvest Pass.
--   Boosts  the Harvest Pass premium track and 2x XP boosts, for Robux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Audio = require(script.Parent.Audio)
local Purchases = require(script.Parent.Purchases)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Shop = {}

local GREEN = Color3.fromRGB(70, 170, 80)
local GREY = Color3.fromRGB(110, 110, 110)
local DIM_ORANGE = Color3.fromRGB(150, 95, 50)
local PURPLE = Color3.fromRGB(150, 80, 200)
local GOLD = Color3.fromRGB(255, 205, 70)
local CARD = Color3.fromRGB(95, 58, 32)
local GOOD_TEXT = Color3.fromRGB(150, 235, 120)
local BAD_TEXT = Color3.fromRGB(255, 130, 110)


-- Which pass tier gives each pass skin.
local passTier: { [string]: number } = {}
for tier, rewards in Season.Rewards do
	for _, reward in { rewards.Free, rewards.Premium } do
		if reward and reward.Skin then
			passTier[reward.Skin] = tier
		end
	end
end

local function previewPart(parent: Instance, piece: Skins.Piece)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic -- matches the turkey the server builds
	for k, v in piece.Props do
		p[k] = v
	end
	if piece.Mesh == "Sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = piece.Offset
	p.Parent = parent
end

-- Builds a little turkey in a ViewportFrame and returns the camera that looks at it.
local function buildPreview(card: Frame, skin): Camera
	-- Tinted with the skin's rarity color, so rare skins stand out at a glance.
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundColor3 = Skins.Rarities[skin.Rarity].Color
	viewport.BackgroundTransparency = 0.55
	viewport.Position = UDim2.new(0, 6, 0, 6)
	viewport.Size = UDim2.new(1, -12, 0.58, -6)
	Instance.new("UICorner").Parent = viewport
	viewport.Parent = card

	-- The turkey with its body at the origin, in its resting pose.
	for _, piece in Skins.pieces(skin.Id) do
		previewPart(viewport, piece)
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Rarity, in its color, across the top of the preview.
	local rarity = Skins.Rarities[skin.Rarity]
	Ui.label(viewport, {
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0.16, 0),
		Text = string.upper(skin.Rarity),
		TextColor3 = rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	return camera
end

local function ownedSkins(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- Opens the shop on its Skins tab, scrolled to `skinId` if given (set once the shop is built).
local openAt: (skinId: string?) -> () = function() end

function Shop.open(skinId: string?)
	openAt(skinId)
end

-- passApi: the Pass module, so a pass skin's button can open the pass.
function Shop.start(passApi)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- over the HUD
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.autoScale(gui)

	local openButton = Ui.menuButton(gui, 1, "🛒", "SHOP", Ui.GREEN)
	local window, body, openWindow = Ui.window(gui, "🛒 SHOP", Ui.GREEN, UDim2.fromScale(0.9, 0.84), Vector2.new(720, 540))

	-- Feathers in the header; tabs along the top of the body.
	local featherLabel = Ui.label(window.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 9),
		Size = UDim2.new(0.4, 0, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.CREAM,
	})
	local tabs = {}
	local function tabButton(name: string, text: string, x: number)
		local b = Ui.button(body, {
			Name = name .. "Tab",
			Position = UDim2.new(0, x, 0, 0),
			Size = UDim2.new(0, 140, 0, 40),
			Text = text,
		})
		tabs[name] = b
		return b
	end
	tabButton("Skins", "🦃 Skins", 0)
	tabButton("Boosts", "⚡ Boosts", 152)

	local message = Ui.label(body, {
		Name = "Message",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
	})
	local function say(text: string, good: boolean)
		message.Text = text
		message.TextColor3 = if good then GOOD_TEXT else BAD_TEXT
	end

	-- Skins tab ----------------------------------------------------------------------------------------

	-- Four cards per row; on short screens the grid scrolls instead of squashing them.
	local cards = Instance.new("ScrollingFrame")
	cards.Name = "Cards"
	cards.BackgroundTransparency = 1
	cards.BorderSizePixel = 0
	cards.Position = UDim2.new(0, 0, 0, 50)
	cards.Size = UDim2.new(1, 0, 1, -82)
	cards.CanvasSize = UDim2.new()
	cards.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cards.ScrollingDirection = Enum.ScrollingDirection.Y
	cards.ScrollBarThickness = 6
	cards.ScrollBarImageColor3 = Ui.ORANGE
	cards.Parent = body
	local COLUMNS, GAP, CARD_ASPECT, MIN_HEIGHT = 4, 8, 0.8, 150 -- CARD_ASPECT is width / height
	local rows = math.ceil(#Skins.List / COLUMNS)
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = cards
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 3)
	gridPadding.PaddingLeft = UDim.new(0, 3)
	gridPadding.Parent = cards
	local function fitCards()
		local size = cards.AbsoluteSize / Ui.scaleOf(cards)
		-- Leave room for the scroll bar so the last column isn't covered.
		local width = math.max((size.X - cards.ScrollBarThickness - 3 - GAP * COLUMNS) / COLUMNS, 40)
		-- Shorten the cards so every row fits, down to a minimum; below that the grid scrolls.
		local fitHeight = (size.Y - GAP * (rows - 1)) / rows
		grid.CellSize = UDim2.fromOffset(width, math.max(math.min(width / CARD_ASPECT, fitHeight), MIN_HEIGHT))
	end
	cards:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
	gui.AutoScale:GetPropertyChangedSignal("Scale"):Connect(fitCards)
	fitCards()

	local entries = {}
	local skinPrices: { [string]: Purchases.Price } = {}
	local busy = false

	local function refreshSkins()
		local owned = ownedSkins()
		local equipped = player:GetAttribute("Skin")
		local leaderstats = player:FindFirstChild("leaderstats")
		local feathers = if leaderstats then leaderstats.Feathers.Value else 0
		featherLabel.Text = `{Format.FEATHER} {feathers}`
		for _, entry in entries do
			local skin, button = entry.skin, entry.button
			local source = Skins.source(skin)
			button.TextColor3 = Color3.new(1, 1, 1)
			if skin.Id == equipped then
				button.Text = "Equipped"
				button.BackgroundColor3 = GREY
			elseif owned[skin.Id] then
				button.Text = "Equip"
				button.BackgroundColor3 = GREEN
			elseif source == "Robux" then
				local id = Config.Robux.Skins[skin.Id] or 0
				button.Text = Purchases.label(skinPrices[skin.Id], id)
				button.BackgroundColor3 = if id == 0 then GREY else Purchases.GREEN
			elseif source == "Pass" then
				button.Text = `🎟️ Pass tier {passTier[skin.Id] or "?"}`
				button.BackgroundColor3 = PURPLE
			else
				button.Text = `Buy {Format.FEATHER} {skin.Price}`
				button.BackgroundColor3 = if feathers >= skin.Price then Ui.ORANGE else DIM_ORANGE
			end
		end
	end

	local function request(skin)
		if busy or skin.Id == player:GetAttribute("Skin") then
			return
		end
		local owned = ownedSkins()[skin.Id]
		local source = Skins.source(skin)
		if not owned and source == "Robux" then
			local id = Config.Robux.Skins[skin.Id] or 0
			if id == 0 then
				say("This skin is coming soon!", false)
			else
				Purchases.buy("GamePass", id)
			end
			return
		elseif not owned and source == "Pass" then
			passApi.open()
			return
		end
		busy = true
		local action = if owned then "Equip" else "Buy"
		local ok, success, text = pcall(Remotes.Shop.InvokeServer, Remotes.Shop, action, skin.Id)
		busy = false
		say(if ok then text else "The shop is busy, try again!", ok and success)
		if ok and success then
			Audio.play(if action == "Buy" then "Purchase" else "Pickup")
		end
		refreshSkins()
	end

	for i, skin in Skins.List do
		local card = Ui.panel(cards, {
			Name = skin.Id,
			LayoutOrder = i,
			BackgroundColor3 = CARD,
			BackgroundTransparency = 0,
		})
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Skins.Rarities[skin.Rarity].Color
		stroke.Parent = card
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
		if skin.Robux then
			Purchases.price("GamePass", Config.Robux.Skins[skin.Id] or 0, function(price)
				skinPrices[skin.Id] = price
				refreshSkins()
			end)
		end
	end

	-- Boosts tab ---------------------------------------------------------------------------------------

	local boosts = Instance.new("Frame")
	boosts.Name = "Boosts"
	boosts.BackgroundTransparency = 1
	boosts.Position = UDim2.new(0, 0, 0, 50)
	boosts.Size = UDim2.new(1, 0, 1, -82)
	boosts.Visible = false
	boosts.Parent = body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = boosts

	local boostStatus = Ui.label(boosts, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 30),
	})

	-- A wide card: icon, title and blurb on the left, a buy button on the right.
	local function offerRow(order: number, icon: string, title: string, blurb: string, color: Color3)
		local row = Ui.panel(boosts, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = CARD,
			BackgroundTransparency = 0,
		})
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = color
		stroke.Parent = row
		Ui.label(row, { Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 80, 1, -16), Text = icon, TextStrokeTransparency = 1 })
		Ui.label(row, {
			Position = UDim2.new(0, 96, 0, 10),
			Size = UDim2.new(1, -300, 0, 32),
			Text = title,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(row, {
			Position = UDim2.new(0, 96, 0, 46),
			Size = UDim2.new(1, -300, 0, 40),
			Text = blurb,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(255, 230, 200),
		})
		return Ui.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0, 180, 0, 50),
		})
	end

	local premiumId = Config.Robux.PremiumPass
	local premiumPrice: Purchases.Price? = nil
	local premiumButton = offerRow(1, "🎟️", `{Season.Name} Premium`, "Unlock the premium track: exclusive skins, 2x XP boosts and thousands of Feathers. Rewards you've already reached are yours at once.", GOLD)
	premiumButton.Activated:Connect(function()
		if player:GetAttribute("PassPremium") ~= true then
			if premiumId == 0 then
				say("The premium pass is coming soon!", false)
			else
				Purchases.buy("GamePass", premiumId)
			end
		end
	end)

	local boostRows = {}
	for i, boost in Config.Robux.XpBoosts do
		local hours = boost.Minutes // 60
		local length = if boost.Minutes % 60 ~= 0 or hours == 0 then `{boost.Minutes} minutes` elseif hours == 1 then "1 hour" else `{hours} hours`
		local button = offerRow(i + 1, "⚡", `2x XP • {length}`, "Double XP from every race, for leveling up and climbing the pass faster. Buy more to add more time.", Color3.fromRGB(120, 200, 255))
		local entry = { boost = boost, button = button, price = nil }
		table.insert(boostRows, entry)
		button.Activated:Connect(function()
			if boost.Id == 0 then
				say("XP boosts are coming soon!", false)
			else
				Purchases.buy("Product", boost.Id)
			end
		end)
		Purchases.price("Product", boost.Id, function(price)
			entry.price = price
		end)
	end

	local function refreshBoosts()
		local untilTime = player:GetAttribute("BoostUntil") or 0
		local left = untilTime - workspace:GetServerTimeNow()
		boostStatus.Text = if left > 0 then `⚡ 2x XP active: {Format.duration(left)} left` else "No XP boost running"
		boostStatus.TextColor3 = if left > 0 then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(200, 180, 160)
		if player:GetAttribute("PassPremium") == true then
			premiumButton.Text = "Owned ✓"
			premiumButton.BackgroundColor3 = GREY
		else
			premiumButton.Text = Purchases.label(premiumPrice, premiumId)
			premiumButton.BackgroundColor3 = if premiumId == 0 then GREY else Purchases.GREEN
		end
		for _, entry in boostRows do
			entry.button.Text = Purchases.label(entry.price, entry.boost.Id)
			entry.button.BackgroundColor3 = if entry.boost.Id == 0 then GREY else Purchases.GREEN
		end
	end
	Purchases.price("GamePass", premiumId, function(price)
		premiumPrice = price
	end)

	-- Tabs and opening ---------------------------------------------------------------------------------

	local current = "Skins"
	local function showTab(name: string)
		current = name
		cards.Visible = name == "Skins"
		boosts.Visible = name == "Boosts"
		for tabName, b in tabs do
			b.BackgroundColor3 = if tabName == name then Ui.ORANGE else Ui.PANEL
		end
		message.Text = ""
		refreshSkins()
		refreshBoosts()
	end
	tabs.Skins.Activated:Connect(function()
		showTab("Skins")
	end)
	tabs.Boosts.Activated:Connect(function()
		showTab("Boosts")
	end)

	local function setOpen(open: boolean)
		openWindow(open)
		if open then
			showTab(current)
		end
	end
	openButton.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	openAt = function(skinId: string?)
		if player:GetAttribute("Racing") then
			return
		end
		current = "Skins"
		setOpen(true)
		local entry = skinId and cards:FindFirstChild(skinId) :: Frame?
		if entry then
			-- Scroll so that skin's row is at the top, and make its card bounce.
			task.defer(function()
				local y = (entry.AbsolutePosition.Y - cards.AbsolutePosition.Y) / Ui.scaleOf(cards) + cards.CanvasPosition.Y
				cards.CanvasPosition = Vector2.new(0, math.max(0, y - 4))
				Ui.pop(entry, 0.7)
			end)
		end
	end

	-- The shop is a lobby thing: hide it while racing.
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local racing = player:GetAttribute("Racing") == true
		openButton.Visible = not racing
		if racing then
			setOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("OwnedSkins"):Connect(refreshSkins)
	player:GetAttributeChangedSignal("Skin"):Connect(refreshSkins)
	player:GetAttributeChangedSignal("PassPremium"):Connect(refreshBoosts)
	task.spawn(function()
		player:WaitForChild("leaderstats"):WaitForChild("Feathers").Changed:Connect(refreshSkins)
		refreshSkins()
	end)
	showTab("Skins")
	window.Visible = false

	-- While the shop is open: spin the previews and count down the boost timer.
	local lastTick = 0
	RunService.RenderStepped:Connect(function()
		if not window.Visible then
			return
		end
		local angle = os.clock() * 0.8
		-- Far enough back to fit the tail fan, the tallest hat (the chef's toque) and the feet.
		local eye = Vector3.new(math.sin(angle) * 19, 3, -math.cos(angle) * 19)
		local view = CFrame.lookAt(eye, Vector3.new(0, 0.9, 0))
		for _, entry in entries do
			entry.camera.CFrame = view
		end
		if current == "Boosts" and os.clock() - lastTick > 0.5 then
			lastTick = os.clock()
			refreshBoosts()
		end
	end)
end

return Shop
