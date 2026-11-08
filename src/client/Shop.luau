-- The shop, opened from its lobby tile, with four tabs:
--   Featured   a banner cycling the VIP pass, the Harvest Pass premium track and the Robux skins; the skin of the
--              day (shared/Featured), a Feathers skin at a discount; and the popular Feather pack.
--   Skins      spinning previews of every skin with its rarity. Feather skins are bought here, Robux skins open
--              Roblox's purchase prompt, and pass skins open the Harvest Pass.
--   Feathers   Feather packs, for Robux.
--   VIP        the VIP pass, the premium track, Power-Up Starters and 2x XP boosts, for Robux.
-- The tile wears a red dot while there's a Feathers skin you can afford.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Featured = require(ReplicatedStorage.Shared.Featured)
local Format = require(ReplicatedStorage.Shared.Format)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local TurkeyModel = require(ReplicatedStorage.Shared.TurkeyModel)
local Audio = require(script.Parent.Audio)
local Purchases = require(script.Parent.Purchases)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local robux = Config.Robux

local Shop = {}

local CARD = Color3.fromRGB(120, 74, 42)
local DIM_ORANGE = Color3.fromRGB(150, 100, 60)
local GOOD_TEXT = Color3.fromRGB(160, 240, 120)
local BAD_TEXT = Color3.fromRGB(255, 140, 115)
local XP_BLUE = Color3.fromRGB(120, 200, 255)
local VIP_GOLD = Color3.fromRGB(255, 205, 70)
local TABS = {
	{ Name = "Featured", Icon = "star", Text = "Featured" },
	{ Name = "Skins", Icon = "turkey", Text = "Skins" },
	{ Name = "Feathers", Icon = "feather", Text = "Feathers" },
	{ Name = "Vip", Icon = "crown", Text = "VIP & Boosts" },
}

-- Which pass tier gives each pass skin.
local passTier: { [string]: number } = {}
for tier, rewards in Season.Rewards do
	for _, reward in { rewards.Free, rewards.Premium } do
		if reward and reward.Skin then
			passTier[reward.Skin] = tier
		end
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function feathers(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	return if leaderstats then leaderstats.Feathers.Value else 0
end

local function ownedSkins(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- A little turkey in a ViewportFrame, tinted with its rarity color; returns the camera that looks at it.
local function turkeyPreview(parent: GuiObject, skin, props): Camera
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundColor3 = Skins.Rarities[skin.Rarity].Color
	viewport.BackgroundTransparency = 0.55
	for k, v in props do
		viewport[k] = v
	end
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = viewport
	viewport.Parent = parent

	local mesh = TurkeyModel.newMesh(skin.Id, true)
	mesh.CFrame = TurkeyModel.MeshInGround
	mesh.Parent = viewport
	for _, piece in Skins.pieces(skin.Id) do
		local part = TurkeyModel.newPiece(piece)
		part.CFrame = piece.CFrame
		part.Parent = viewport
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

-- A ribbon across a card's top corner: "POPULAR", "-20%".
local function ribbon(parent: GuiObject, text: string, color: Color3)
	local tag = Ui.card(parent, {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -8),
		Size = UDim2.fromOffset(math.max(64, #text * 11 + 20), 28),
		BackgroundColor3 = color,
		ZIndex = 4,
	})
	tag.Skin.ZIndex = 4
	tag.Rotation = 6
	Ui.label(tag, { Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 1, -8), Text = text, ZIndex = 5 })
	return tag
end

-- A scrolling page under the tabs.
local function scroller(parent: Instance, name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(0, 0, 0, 56)
	frame.Size = UDim2.new(1, 0, 1, -88)
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Ui.ORANGE
	frame.Visible = false
	frame.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = frame
	return frame
end

-- Opens the shop on its Skins tab, scrolled to `skinId` if given (set once the shop is built).
local openAt: (skinId: string?) -> () = function() end
local openTab: (name: string) -> () = function() end

function Shop.open(skinId: string?)
	openAt(skinId)
end

-- Opens the shop on a tab: "Featured", "Skins", "Feathers" or "Vip".
function Shop.openTab(name: string)
	openTab(name)
end

-- passApi: the Pass module, so a pass skin's button can open the pass.
function Shop.start(passApi)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- over the HUD
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.autoScale(gui)

	local openButton = Ui.menuButton(gui, 1, "cart", "SHOP", Ui.GREEN)
	local dot = Ui.badge(openButton)
	local window, body, openWindow = Ui.window(gui, "SHOP", Ui.GREEN, UDim2.fromScale(0.9, 0.86), Vector2.new(760, 560))
	Ui.icon(window.Header, "cart", { Position = UDim2.new(0, 8, 0, -6), Size = UDim2.fromOffset(56, 56), ZIndex = 2 })
	window.Header.Title.Position = UDim2.new(0, 66, 0, 7)

	-- Feathers in the header.
	local featherLabel = Ui.label(window.Header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 9),
		Size = UDim2.new(0.3, 0, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.CREAM,
	})
	Ui.icon(window.Header, "feather", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.7, -58, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
	})

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

	-- Tabs along the top, each with an icon.
	local tabButtons, pages = {}, {}
	for i, tab in TABS do
		local b = Ui.button(body, {
			Name = tab.Name .. "Tab",
			Position = UDim2.new((i - 1) / #TABS, 3, 0, 0),
			Size = UDim2.new(1 / #TABS, -6, 0, 46),
			Text = "",
			BackgroundColor3 = Ui.PANEL,
		})
		Ui.icon(b, tab.Icon, { Position = UDim2.new(0, -4, 0, -4), Size = UDim2.new(0, 38, 1, 8) })
		Ui.label(b, { Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -36, 1, 0), Text = tab.Text })
		tabButtons[tab.Name] = b
	end

	-- Buys a Robux item, or says it's coming.
	local function buyRobux(kind: Purchases.Kind, id: number, what: string)
		if id == 0 then
			say(`{what} coming soon!`, false)
		else
			Purchases.buy(kind, id)
		end
	end

	local cameras = {} -- every turkey preview, turned together
	local refreshers = {} -- functions that bring a part of the shop up to date
	local function refreshAll() end -- filled in below

	-- Skins tab -----------------------------------------------------------------------------------------------------

	local skinsPage = scroller(body, "Skins")
	pages.Skins = skinsPage
	local COLUMNS, GAP, CARD_ASPECT = 4, 10, 0.78 -- CARD_ASPECT is width / height
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(GAP, GAP + 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = skinsPage
	local function fitCards()
		local width = skinsPage.AbsoluteSize.X / Ui.scaleOf(skinsPage)
		local cell = math.max((width - 24 - GAP * (COLUMNS - 1)) / COLUMNS, 60)
		grid.CellSize = UDim2.fromOffset(cell, math.max(cell / CARD_ASPECT, 150))
	end
	skinsPage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
	gui.AutoScale:GetPropertyChangedSignal("Scale"):Connect(fitCards)
	fitCards()

	local entries = {}
	local skinPrices: { [string]: Purchases.Price } = {}
	local busy = false

	-- What a skin's button says, and its color, wherever it's shown.
	local function skinButtonState(skin): (string, Color3)
		local owned = ownedSkins()
		local source = Skins.source(skin)
		if skin.Id == player:GetAttribute("Skin") then
			return "Equipped", Ui.GREY
		elseif owned[skin.Id] then
			return "Equip", Ui.GREEN
		elseif source == "Robux" then
			local id = robux.Skins[skin.Id] or 0
			return Purchases.label(skinPrices[skin.Id], id), if id == 0 then Ui.GREY else Purchases.GREEN
		elseif source == "Pass" then
			return `🎟️ Pass tier {passTier[skin.Id] or "?"}`, Ui.PURPLE
		end
		local price = Featured.price(skin, now())
		return `Buy {Format.FEATHER} {Format.number(price)}`, if feathers() >= price then Ui.ORANGE else DIM_ORANGE
	end

	local function request(skin)
		if busy or skin.Id == player:GetAttribute("Skin") then
			return
		end
		local owned = ownedSkins()[skin.Id]
		local source = Skins.source(skin)
		if not owned and source == "Robux" then
			buyRobux("GamePass", robux.Skins[skin.Id] or 0, "This skin is")
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
		refreshAll()
	end

	for i, skin in Skins.List do
		local card = Ui.card(skinsPage, { Name = skin.Id, LayoutOrder = i, BackgroundColor3 = CARD })
		local rarity = Skins.Rarities[skin.Rarity]
		card.Border.Color = rarity.Color
		table.insert(cameras, turkeyPreview(card, skin, { Position = UDim2.new(0, 7, 0, 7), Size = UDim2.new(1, -14, 0.58, -7) }))
		Ui.label(card, {
			Position = UDim2.new(0, 12, 0, 10),
			Size = UDim2.new(1, -24, 0.1, 0),
			Text = string.upper(skin.Rarity),
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		})
		Ui.label(card, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.6, 0),
			Size = UDim2.new(1, -14, 0.13, 0),
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
		local sale = ribbon(card, `-{math.floor(Featured.Discount * 100)}%`, Ui.RED)
		sale.Visible = false
		table.insert(entries, { skin = skin, button = button, sale = sale })
		if skin.Robux then
			Purchases.price("GamePass", robux.Skins[skin.Id] or 0, function(price)
				skinPrices[skin.Id] = price
				refreshAll()
			end)
		end
	end

	table.insert(refreshers, function()
		local deal = Featured.skin(now())
		local owned = ownedSkins()
		for _, entry in entries do
			entry.button.Text, entry.button.BackgroundColor3 = skinButtonState(entry.skin)
			entry.sale.Visible = entry.skin.Id == deal.Id and not owned[deal.Id]
		end
	end)

	-- Featured tab --------------------------------------------------------------------------------------------------

	local featuredPage = scroller(body, "Featured")
	pages.Featured = featuredPage
	local featuredList = Instance.new("UIListLayout")
	featuredList.Padding = UDim.new(0, 14)
	featuredList.SortOrder = Enum.SortOrder.LayoutOrder
	featuredList.Parent = featuredPage

	-- The banner: one big offer at a time, cycling.
	local banner = Ui.card(featuredPage, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = Ui.PURPLE })
	local bannerArt = Instance.new("Frame")
	bannerArt.BackgroundTransparency = 1
	bannerArt.Position = UDim2.new(0, 12, 0, 12)
	bannerArt.Size = UDim2.new(0, 150, 1, -24)
	bannerArt.Parent = banner
	local bannerTitle = Ui.label(banner, {
		Position = UDim2.new(0, 176, 0, 16),
		Size = UDim2.new(1, -390, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	bannerTitle.Outline.Thickness = 3
	local bannerBlurb = Ui.label(banner, {
		Position = UDim2.new(0, 176, 0, 62),
		Size = UDim2.new(1, -390, 0, 84),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.CREAM,
	})
	local bannerButton = Ui.button(banner, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, -6),
		Size = UDim2.fromOffset(186, 60),
	})
	local dots = Instance.new("Frame")
	dots.BackgroundTransparency = 1
	dots.AnchorPoint = Vector2.new(0.5, 1)
	dots.Position = UDim2.new(0.5, 0, 1, -8)
	dots.Size = UDim2.fromOffset(220, 14)
	dots.Parent = banner
	local dotLayout = Instance.new("UIListLayout")
	dotLayout.FillDirection = Enum.FillDirection.Horizontal
	dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotLayout.Padding = UDim.new(0, 8)
	dotLayout.Parent = dots

	local offers = {
		{
			Art = "crown", Color = Color3.fromRGB(150, 50, 40), Title = "👑 VIP",
			Blurb = "2x Feathers from every race, a VIP tag in chat and over your turkey, and a golden trail behind it.",
			Kind = "GamePass", Id = robux.VipPass, What = "VIP is",
			Owned = function() return player:GetAttribute("Vip") == true end,
		},
		{
			Art = "ticket", Color = Ui.PURPLE, Title = `⭐ {Season.Name} Premium`,
			Blurb = "The premium track: exclusive skins, XP boosts and thousands of Feathers. Rewards you've already reached are yours at once.",
			Kind = "GamePass", Id = robux.PremiumPass, What = "The premium pass is",
			Owned = function() return player:GetAttribute("PassPremium") == true end,
		},
	}
	for _, skin in Skins.List do
		if skin.Robux then
			table.insert(offers, {
				Skin = skin, Color = Ui.darker(Skins.Rarities[skin.Rarity].Color, 0.25), Title = `🦃 {skin.Name}`,
				Blurb = `A {string.upper(skin.Rarity)} turkey with its own sparkle. Yours forever, on every map.`,
				Kind = "GamePass", Id = robux.Skins[skin.Id] or 0, What = "This skin is",
				Owned = function() return ownedSkins()[skin.Id] == true end,
			})
		end
	end
	local offerPrices = {}
	local current = 1
	local dotButtons = {}
	local bannerCamera: Camera? = nil

	local function showOffer(index: number)
		local changed = (index - 1) % #offers + 1 ~= current or #bannerArt:GetChildren() == 0
		current = (index - 1) % #offers + 1
		local offer = offers[current]
		banner.BackgroundColor3 = offer.Color
		bannerTitle.Text = offer.Title
		bannerBlurb.Text = offer.Blurb
		if changed then
			for _, child in bannerArt:GetChildren() do
				child:Destroy()
			end
			if bannerCamera then
				table.remove(cameras, table.find(cameras, bannerCamera))
				bannerCamera = nil
			end
			if offer.Skin then
				bannerCamera = turkeyPreview(bannerArt, offer.Skin, { Size = UDim2.fromScale(1, 1) })
				table.insert(cameras, bannerCamera)
			else
				Ui.icon(bannerArt, offer.Art, { Size = UDim2.fromScale(1, 1) })
			end
		end
		if offer.Owned() then
			bannerButton.Text, bannerButton.BackgroundColor3 = "Owned ✓", Ui.GREY
		else
			bannerButton.Text = Purchases.label(offerPrices[current], offer.Id)
			bannerButton.BackgroundColor3 = if offer.Id == 0 then Ui.GREY else Purchases.GREEN
		end
		for i, d in dotButtons do
			d.BackgroundColor3 = if i == current then Ui.CREAM else Ui.DARK
		end
	end
	local lastCycle = os.clock()
	for i, offer in offers do
		local d = Instance.new("TextButton")
		d.Text = ""
		d.AutoButtonColor = false
		d.BorderSizePixel = 0
		d.Size = UDim2.fromOffset(14, 14)
		d.BackgroundColor3 = Ui.DARK
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = d
		d.Parent = dots
		d.Activated:Connect(function()
			lastCycle = os.clock()
			showOffer(i)
		end)
		table.insert(dotButtons, d)
		Purchases.price(offer.Kind, offer.Id, function(price)
			offerPrices[i] = price
			if i == current then
				showOffer(current)
			end
		end)
	end
	bannerButton.Activated:Connect(function()
		local offer = offers[current]
		if not offer.Owned() then
			buyRobux(offer.Kind, offer.Id, offer.What)
		end
	end)

	-- Under the banner: the skin of the day and the popular Feather pack.
	local lower = Instance.new("Frame")
	lower.BackgroundTransparency = 1
	lower.LayoutOrder = 2
	lower.Size = UDim2.new(1, 0, 0, 200)
	lower.Parent = featuredPage

	local dealCard = Ui.card(lower, { Size = UDim2.new(0.58, -7, 1, 0), BackgroundColor3 = CARD })
	dealCard.Border.Color = Ui.GOLD
	Ui.icon(dealCard, "tag", { Position = UDim2.new(0, 10, 0, 8), Size = UDim2.fromOffset(38, 38) })
	Ui.label(dealCard, {
		Position = UDim2.new(0, 52, 0, 13),
		Size = UDim2.new(1, -110, 0, 28),
		Text = "SKIN OF THE DAY",
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dealArt = Instance.new("Frame")
	dealArt.BackgroundTransparency = 1
	dealArt.Position = UDim2.new(0, 10, 0, 52)
	dealArt.Size = UDim2.new(0.42, -10, 1, -62)
	dealArt.Parent = dealCard
	local dealName = Ui.label(dealCard, {
		Position = UDim2.new(0.42, 8, 0, 54),
		Size = UDim2.new(0.58, -18, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dealPrice = Ui.label(dealCard, {
		Position = UDim2.new(0.42, 8, 0, 86),
		Size = UDim2.new(0.58, -18, 0, 26),
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.CREAM,
	})
	local dealTimer = Ui.label(dealCard, {
		Position = UDim2.new(0.42, 8, 0, 114),
		Size = UDim2.new(0.58, -18, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(230, 200, 160),
	})
	local dealButton = Ui.button(dealCard, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.42, 8, 1, -10),
		Size = UDim2.new(0.58, -20, 0, 46),
	})
	ribbon(dealCard, `-{math.floor(Featured.Discount * 100)}%`, Ui.RED)
	local dealSkinId: string? = nil
	local dealCamera: Camera? = nil
	dealButton.Activated:Connect(function()
		request(Featured.skin(now()))
	end)

	local packCard = Ui.card(lower, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.42, -7, 1, 0),
		BackgroundColor3 = CARD,
	})
	local popular = robux.FeatherPacks[2]
	Ui.icon(packCard, "feathers_m", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(100, 100) })
	Ui.label(packCard, {
		Position = UDim2.new(0, 10, 0, 104),
		Size = UDim2.new(1, -20, 0, 30),
		Text = `{Format.number(popular.Feathers)} Feathers`,
		TextColor3 = Ui.GOLD,
	})
	local packButton = Ui.button(packCard, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 46),
	})
	if popular.Tag then
		ribbon(packCard, popular.Tag, Ui.ORANGE)
	end
	local popularPrice: Purchases.Price? = nil
	Purchases.price("Product", popular.Id, function(price)
		popularPrice = price
		packButton.Text = Purchases.label(price, popular.Id)
	end)
	packButton.Activated:Connect(function()
		buyRobux("Product", popular.Id, "Feather packs are")
	end)

	table.insert(refreshers, function()
		local skin = Featured.skin(now())
		if skin.Id ~= dealSkinId then
			dealSkinId = skin.Id
			for _, child in dealArt:GetChildren() do
				child:Destroy()
			end
			if dealCamera then
				table.remove(cameras, table.find(cameras, dealCamera))
			end
			dealCamera = turkeyPreview(dealArt, skin, { Size = UDim2.fromScale(1, 1) })
			table.insert(cameras, dealCamera)
			dealName.Text = skin.Name
		end
		local price = Featured.price(skin, now())
		dealPrice.Text = `<s>{Format.FEATHER} {Format.number(skin.Price)}</s>   <font color="#FFD25A">{Format.FEATHER} {Format.number(price)}</font>`
		dealButton.Text, dealButton.BackgroundColor3 = skinButtonState(skin)
		packButton.Text = Purchases.label(popularPrice, popular.Id)
		packButton.BackgroundColor3 = if popular.Id == 0 then Ui.GREY else Purchases.GREEN
		showOffer(current)
	end)

	-- Feathers tab --------------------------------------------------------------------------------------------------

	local feathersPage = scroller(body, "Feathers")
	pages.Feathers = feathersPage
	local feathersList = Instance.new("UIListLayout")
	feathersList.Padding = UDim.new(0, 10)
	feathersList.SortOrder = Enum.SortOrder.LayoutOrder
	feathersList.Parent = feathersPage
	Ui.label(feathersPage, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "Feathers buy skins in the shop. Every race earns some too!",
		TextColor3 = Ui.CREAM,
	})
	local packRow = Instance.new("Frame")
	packRow.BackgroundTransparency = 1
	packRow.LayoutOrder = 1
	packRow.Size = UDim2.new(1, 0, 0, 300)
	packRow.Parent = feathersPage
	local PACK_ICONS = { "feathers_s", "feathers_m", "feathers_l" }
	local packButtons = {}
	for i, pack in robux.FeatherPacks do
		local count = #robux.FeatherPacks
		local card = Ui.card(packRow, {
			Position = UDim2.new((i - 1) / count, 6, 0, 12),
			Size = UDim2.new(1 / count, -12, 1, -12),
			BackgroundColor3 = CARD,
		})
		if pack.Tag then
			card.Border.Color = Ui.GOLD
			ribbon(card, pack.Tag, if i == count then Ui.RED else Ui.ORANGE)
		end
		Ui.icon(card, PACK_ICONS[i] or "feathers_l", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.new(0.8, 0, 0.48, 0),
		})
		Ui.label(card, {
			Position = UDim2.new(0, 8, 0.55, 0),
			Size = UDim2.new(1, -16, 0.14, 0),
			Text = Format.number(pack.Feathers),
			TextColor3 = Ui.GOLD,
		})
		Ui.label(card, {
			Position = UDim2.new(0, 8, 0.69, 0),
			Size = UDim2.new(1, -16, 0.08, 0),
			Text = "FEATHERS",
			TextColor3 = Ui.CREAM,
		})
		local button = Ui.button(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 46),
		})
		local entry = { pack = pack, button = button, price = nil }
		table.insert(packButtons, entry)
		button.Activated:Connect(function()
			buyRobux("Product", pack.Id, "Feather packs are")
		end)
		Purchases.price("Product", pack.Id, function(price)
			entry.price = price
			button.Text = Purchases.label(price, pack.Id)
		end)
	end
	table.insert(refreshers, function()
		for _, entry in packButtons do
			entry.button.Text = Purchases.label(entry.price, entry.pack.Id)
			entry.button.BackgroundColor3 = if entry.pack.Id == 0 then Ui.GREY else Purchases.GREEN
		end
	end)

	-- VIP & Boosts tab ----------------------------------------------------------------------------------------------

	local vipPage = scroller(body, "Vip")
	pages.Vip = vipPage
	local vipList = Instance.new("UIListLayout")
	vipList.Padding = UDim.new(0, 10)
	vipList.SortOrder = Enum.SortOrder.LayoutOrder
	vipList.Parent = vipPage
	local status = Ui.label(vipPage, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 28), RichText = true })

	-- A wide card: icon, title and blurb on the left, a buy button on the right.
	local rows = {}
	local function offerRow(order: number, icon: string, title: string, blurb: string, color: Color3, kind: Purchases.Kind, id: number, what: string, owned: (() -> boolean)?)
		local row = Ui.card(vipPage, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = CARD })
		row.Border.Color = color
		Ui.icon(row, icon, { Position = UDim2.new(0, 8, 0, 6), Size = UDim2.fromOffset(88, 88) })
		Ui.label(row, {
			Position = UDim2.new(0, 104, 0, 10),
			Size = UDim2.new(1, -310, 0, 32),
			Text = title,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(row, {
			Position = UDim2.new(0, 104, 0, 46),
			Size = UDim2.new(1, -310, 0, 44),
			Text = blurb,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Ui.CREAM,
		})
		local button = Ui.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(180, 52),
		})
		local entry = { button = button, id = id, kind = kind, owned = owned, price = nil }
		table.insert(rows, entry)
		button.Activated:Connect(function()
			if not (owned and owned()) then
				buyRobux(kind, id, what)
			end
		end)
		Purchases.price(kind, id, function(price)
			entry.price = price
		end)
	end

	offerRow(1, "crown", "VIP", "2x Feathers from every race, a VIP tag in chat and over your turkey, and a golden trail.", VIP_GOLD, "GamePass", robux.VipPass, "VIP is", function()
		return player:GetAttribute("Vip") == true
	end)
	offerRow(2, "ticket", `{Season.Name} Premium`, "Exclusive skins, XP boosts and thousands of Feathers on the premium track.", Color3.fromRGB(205, 160, 255), "GamePass", robux.PremiumPass, "The premium pass is", function()
		return player:GetAttribute("PassPremium") == true
	end)
	for i, starter in robux.Starters do
		offerRow(2 + i, "gift", `Power-Up Starter • {starter.Races} races`, "Start each race with a random power-up already in hand (never the Drumstick Dash).", Color3.fromRGB(150, 220, 110), "Product", starter.Id, "Power-Up Starters are")
	end
	for i, boost in robux.XpBoosts do
		local hours = boost.Minutes // 60
		local length = if boost.Minutes % 60 ~= 0 or hours == 0 then `{boost.Minutes} minutes` elseif hours == 1 then "1 hour" else `{hours} hours`
		offerRow(10 + i, "lightning", `2x XP • {length}`, "Double XP from every race, for leveling up and climbing the pass faster. Buy more to add more time.", XP_BLUE, "Product", boost.Id, "XP boosts are")
	end

	local function refreshVip()
		local parts = {}
		local left = (player:GetAttribute("BoostUntil") or 0) - now()
		table.insert(parts, if left > 0 then `<font color="#78C8FF">⚡ 2x XP: {Format.duration(left)} left</font>` else "No XP boost running")
		local starters = player:GetAttribute("Starters") or 0
		if starters > 0 then
			table.insert(parts, `<font color="#96DC6E">🎁 {starters} starter{if starters == 1 then "" else "s"} left</font>`)
		end
		if player:GetAttribute("Vip") == true then
			table.insert(parts, `<font color="#FFCD46">👑 VIP</font>`)
		end
		status.Text = table.concat(parts, "   •   ")
		for _, entry in rows do
			if entry.owned and entry.owned() then
				entry.button.Text, entry.button.BackgroundColor3 = "Owned ✓", Ui.GREY
			else
				entry.button.Text = Purchases.label(entry.price, entry.id)
				entry.button.BackgroundColor3 = if entry.id == 0 then Ui.GREY else Purchases.GREEN
			end
		end
	end
	table.insert(refreshers, refreshVip)

	-- Tabs, opening, the red dot -----------------------------------------------------------------------------------

	refreshAll = function()
		featherLabel.Text = Format.number(feathers())
		for _, refresh in refreshers do
			refresh()
		end
	end

	local currentTab = "Featured"
	local function showTab(name: string)
		currentTab = name
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		for tabName, b in tabButtons do
			b.BackgroundColor3 = if tabName == name then Ui.ORANGE else Ui.PANEL
		end
		message.Text = ""
		refreshAll()
	end
	for name, b in tabButtons do
		b.Activated:Connect(function()
			showTab(name)
		end)
	end

	local function setOpen(open: boolean)
		openWindow(open)
		if open then
			showTab(currentTab)
		end
	end
	openButton.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	openTab = function(name: string)
		if player:GetAttribute("Racing") or not pages[name] then
			return
		end
		currentTab = name
		setOpen(true)
	end
	openAt = function(skinId: string?)
		if player:GetAttribute("Racing") then
			return
		end
		currentTab = "Skins"
		setOpen(true)
		local entry = skinId and skinsPage:FindFirstChild(skinId) :: Frame?
		if entry then
			-- Scroll so that skin's row is at the top, and make its card bounce.
			task.defer(function()
				local y = (entry.AbsolutePosition.Y - skinsPage.AbsolutePosition.Y) / Ui.scaleOf(skinsPage) + skinsPage.CanvasPosition.Y
				skinsPage.CanvasPosition = Vector2.new(0, math.max(0, y - 4))
				Ui.pop(entry, 0.7)
			end)
		end
	end

	-- The red dot: a Feathers skin you don't own and can afford.
	local function refreshDot()
		local owned, have, t = ownedSkins(), feathers(), now()
		local affordable = false
		for _, skin in Skins.List do
			if Skins.source(skin) == "Feathers" and not owned[skin.Id] and Featured.price(skin, t) <= have then
				affordable = true
				break
			end
		end
		dot.Visible = affordable and not window.Visible
	end

	-- The shop is a lobby thing: hide it while racing.
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local racing = player:GetAttribute("Racing") == true
		openButton.Visible = not racing
		if racing then
			setOpen(false)
		end
	end)
	for _, attribute in { "OwnedSkins", "Skin", "PassPremium", "Vip", "Starters" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refreshAll()
			refreshDot()
		end)
	end
	window:GetPropertyChangedSignal("Visible"):Connect(refreshDot)
	task.spawn(function()
		player:WaitForChild("leaderstats"):WaitForChild("Feathers").Changed:Connect(function()
			refreshAll()
			refreshDot()
		end)
		refreshAll()
		refreshDot()
	end)
	showTab("Featured")
	window.Visible = false

	-- While the shop is open: spin the previews, cycle the banner and keep the timers ticking.
	local lastTick = 0
	RunService.RenderStepped:Connect(function()
		if not window.Visible then
			if os.clock() - lastTick > 30 then
				lastTick = os.clock()
				refreshDot() -- a new skin of the day
			end
			return
		end
		local angle = os.clock() * 0.8
		-- Far enough back to fit the tail fan, the tallest hat (the chef's toque) and the feet.
		local eye = Vector3.new(math.sin(angle) * 24, 10, -math.cos(angle) * 24)
		local view = CFrame.lookAt(eye, Vector3.new(0, 6.4, 0))
		for _, camera in cameras do
			camera.CFrame = view
		end
		if currentTab == "Featured" and os.clock() - lastCycle > 5 then
			lastCycle = os.clock()
			showOffer(current + 1)
		end
		if os.clock() - lastTick > 0.5 then
			lastTick = os.clock()
			dealTimer.Text = `New deal in {Format.duration(Featured.secondsLeft(now()))}`
			if currentTab == "Vip" then
				refreshVip()
			end
		end
	end)
end

return Shop
