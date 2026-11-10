-- The shop, opened from its lobby tile: one scrolling page in a wooden barn frame, in the style of a classic
-- Roblox shop (gradient cards with dots, striped section headers, chunky outlined text). From the top:
--   Feast Frenzy   2x Feathers for the whole server for a while, for Robux
--   Bundles        the Harvest Bundle: a skin, Feathers and Power-Up Starters together
--   Skin of the day  a Feathers skin at a discount (shared/Featured)
--   Game passes    VIP and the Harvest Pass premium track
--   Feathers       Feather packs
--   Boosts         Power-Up Starters and 2x XP
--   Turkey skins   every skin: Feathers skins are bought here, Robux skins open Roblox's prompt, pass skins the pass
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
local rgb = Color3.fromRGB

local Shop = {}

-- The barn palette.
local CREAM = rgb(255, 248, 228)
local HEADER = { rgb(255, 199, 82), rgb(240, 136, 36) }
local HEADER_RED = { rgb(232, 92, 70), rgb(168, 40, 28) }
local CARD = { rgb(255, 214, 96), rgb(243, 150, 44) }
local CARD_RED = { rgb(240, 116, 92), rgb(178, 52, 40) }
local BANNER = { rgb(255, 178, 64), rgb(222, 80, 38) }
local FEATHER_BUTTON = rgb(255, 160, 40)
local OWNED = rgb(140, 132, 124)
local GOOD_TEXT = rgb(170, 245, 120)
local BAD_TEXT = rgb(255, 150, 120)

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

-- Outlined cream text, the shop's look. props as for Ui.label, plus Thick: the outline's thickness.
local function text(parent: Instance, props): TextLabel
	local thick = props.Thick or 2.5
	props.Thick = nil
	props.TextColor3 = props.TextColor3 or CREAM
	local l = Ui.label(parent, props)
	l.Outline.Color = Ui.BARN_OUTLINE
	l.Outline.Thickness = thick
	return l
end

-- A little turkey in a ViewportFrame; returns the camera that looks at it.
local function turkeyPreview(parent: GuiObject, skin, props): Camera
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	for k, v in props do
		viewport[k] = v
	end
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

-- Opens the shop (at a skin's card, or a section) once it's built.
local openAt: (skinId: string?) -> () = function() end
local openTab: (name: string) -> () = function() end

function Shop.open(skinId: string?)
	openAt(skinId)
end

-- Opens the shop at a section: "Featured", "Skins", "Feathers" or "Vip".
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
	local window, body, openWindow = Ui.window(gui, "SHOP", Ui.GREEN, UDim2.fromScale(0.5, 0.84), Vector2.new(600, 680))

	-- The barn: wood planks with a dark outline, a wooden name plaque over the top edge, harvest decorations
	-- around the frame.
	if not Ui.isPhone() then
		window.Position = UDim2.fromScale(0.5, 0.55)
	end
	window.Skin.Visible = false
	window:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 22)
	Ui.pattern(window, Ui.PLANKS, 256, 0)
	window.Border.Color = Ui.BARN_OUTLINE
	window.Border.Thickness = 5
	local plaque = window.Header
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = UDim2.new(0.5, 0, 0, 2)
	plaque.Size = UDim2.fromOffset(220, 58)
	plaque.BackgroundColor3 = rgb(178, 118, 66)
	plaque.ZIndex = 4
	plaque.Skin.ZIndex = 4
	plaque.Title.Position = UDim2.new(0, 12, 0, 8)
	plaque.Title.Size = UDim2.new(1, -24, 1, -16)
	plaque.Title.TextXAlignment = Enum.TextXAlignment.Center
	plaque.Title.TextColor3 = CREAM
	plaque.Title.Outline.Color = Ui.BARN_OUTLINE
	plaque.Title.ZIndex = 5
	for _, deco in {
		{ "pumpkin", UDim2.new(0, -26, 0, -24), 66 },
		{ "maple_leaf", UDim2.new(1, -36, 0.3, 0), 52 },
		{ "corn", UDim2.new(0, -30, 0.46, 0), 56 },
		{ "oak_leaf", UDim2.new(1, -24, 0.7, 0), 50 },
		{ "acorn", UDim2.new(0, -24, 1, -44), 48 },
		{ "pumpkin", UDim2.new(1, -40, 1, -40), 62 },
	} do
		Ui.icon(window, deco[1], { Name = "Deco", Position = deco[2], Size = UDim2.fromOffset(deco[3], deco[3]), ZIndex = 6 })
	end

	-- Feathers, top left inside the frame.
	local purse = Ui.barnPanel(window, {
		Name = "Purse",
		Position = UDim2.new(0, 18, 0, 10),
		Size = UDim2.fromOffset(132, 34),
		ZIndex = 3,
	}, rgb(110, 70, 38), rgb(80, 48, 26), 90)
	Ui.icon(purse, "feather", { Position = UDim2.new(0, -8, 0, -8), Size = UDim2.fromOffset(48, 48), ZIndex = 4 })
	local featherLabel = text(purse, { Position = UDim2.new(0, 38, 0, 5), Size = UDim2.new(1, -46, 1, -10), ZIndex = 4 })

	body.Position = UDim2.new(0, 16, 0, 54)
	body.Size = UDim2.new(1, -32, 1, -66)
	local message = text(body, {
		Name = "Message",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
	})
	local function say(t: string, good: boolean)
		message.Text = t
		message.TextColor3 = if good then GOOD_TEXT else BAD_TEXT
	end

	local page = Instance.new("ScrollingFrame")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.new(1, 0, 1, -28)
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.ScrollBarThickness = 8
	page.ScrollBarImageColor3 = rgb(255, 199, 82)
	page.Parent = body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = page

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local sections: { [string]: GuiObject } = {}
	local function header(name: string, title: string, colors)
		local h = Ui.barnHeader(page, { Name = name, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 48) }, title, colors[1], colors[2])
		sections[name] = h
		return h
	end
	local function card(props, colors, rotation: number?): Frame
		props.LayoutOrder = props.LayoutOrder or nextOrder()
		return Ui.barnPanel(props.Parent or page, props, colors[1], colors[2], rotation or 135, Ui.DOTS)
	end
	-- A row of equal cards side by side.
	local function row(height: number): Frame
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.LayoutOrder = nextOrder()
		r.Size = UDim2.new(1, 0, 0, height)
		r.Parent = page
		return r
	end
	local function cell(r: Frame, index: number, count: number, colors): Frame
		local f = Ui.barnPanel(r, {
			Position = UDim2.new((index - 1) / count, 4, 0, 0),
			Size = UDim2.new(1 / count, -8, 1, 0),
		}, colors[1], colors[2], 135, Ui.DOTS)
		return f
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
	local function refreshAll()
		featherLabel.Text = Format.number(feathers())
		for _, refresh in refreshers do
			refresh()
		end
	end
	-- A Robux button that shows the item's price (or owned) and keeps it current.
	local function robuxButton(parent: Instance, props, kind: Purchases.Kind, id: number, what: string, owned: (() -> boolean)?): TextButton
		local b = Ui.barnButton(parent, props)
		local price: Purchases.Price? = nil
		local function refresh()
			if owned and owned() then
				b.Text, b.BackgroundColor3 = "Owned ✓", OWNED
			else
				b.Text = Purchases.label(price, id)
				b.BackgroundColor3 = if id == 0 then OWNED else rgb(74, 186, 52)
			end
		end
		b.Activated:Connect(function()
			if not (owned and owned()) then
				buyRobux(kind, id, what)
			end
		end)
		Purchases.price(kind, id, function(p)
			price = p
			refresh()
		end)
		table.insert(refreshers, refresh)
		refresh()
		return b
	end

	-- Feast Frenzy ---------------------------------------------------------------------------------------------------

	local feast = robux.FeastFrenzy
	local banner = card({ Name = "Featured", Size = UDim2.new(1, 0, 0, 132) }, BANNER, 90)
	sections.Featured = banner
	Ui.icon(banner, "roast", { Position = UDim2.new(0, 4, 0, 8), Size = UDim2.fromOffset(116, 116), ZIndex = 2 })
	text(banner, { Position = UDim2.new(0, 124, 0, 10), Size = UDim2.new(1, -310, 0, 30), Text = "Feast Frenzy!", Thick = 3 })
	text(banner, { Position = UDim2.new(0, 124, 0, 40), Size = UDim2.new(1, -310, 0, 44), Text = `1x → {feast.Multiplier}x`, Thick = 3.5 })
	local feastNote = text(banner, {
		Position = UDim2.new(0, 124, 0, 86),
		Size = UDim2.new(1, -310, 0, 36),
		TextWrapped = true,
		Text = `Feathers for the whole server for {feast.Minutes} minutes!`,
	})
	robuxButton(banner, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 54),
	}, "Product", feast.Id, "Feast Frenzy is")
	local function refreshFeast()
		local left = (ReplicatedStorage:GetAttribute("FeastUntil") or 0) - now()
		if left > 0 then
			local by = ReplicatedStorage:GetAttribute("FeastBy")
			feastNote.Text = `On now: {Format.duration(left)} left{if by then `, thanks {by}!` else "!"} Buy more to add time.`
		else
			feastNote.Text = `Feathers for the whole server for {feast.Minutes} minutes!`
		end
	end
	table.insert(refreshers, refreshFeast)

	-- Bundles -----------------------------------------------------------------------------------------------------------

	header("Bundles", "Bundles!", HEADER)
	local bundle = robux.HarvestBundle
	local bundleSkin = Skins.byId[bundle.Skin]
	local bundleCard = card({ Size = UDim2.new(1, 0, 0, 150) }, CARD)
	Ui.barnTag(bundleCard, "NEW!", rgb(226, 56, 42))
	text(bundleCard, { Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(0.6, 0, 0, 28), Text = "Harvest Bundle", TextXAlignment = Enum.TextXAlignment.Left })
	local items = Instance.new("Frame")
	items.BackgroundTransparency = 1
	items.Position = UDim2.new(0, 8, 0, 38)
	items.Size = UDim2.new(1, -190, 1, -44)
	items.Parent = bundleCard
	local itemsLayout = Instance.new("UIListLayout")
	itemsLayout.FillDirection = Enum.FillDirection.Horizontal
	itemsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemsLayout.Padding = UDim.new(0, 2)
	itemsLayout.Parent = items
	local itemOrder = 0
	local function bundleItem(build: (Frame) -> (), caption: string): TextLabel
		itemOrder += 1
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.LayoutOrder = itemOrder
		slot.Size = UDim2.new(0.27, 0, 1, 0)
		slot.Parent = items
		build(slot)
		return text(slot, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 22), Text = caption })
	end
	local function plus()
		itemOrder += 1
		text(items, { LayoutOrder = itemOrder, Size = UDim2.new(0.06, 0, 0, 30), Text = "+" })
	end
	local skinCaption = bundleItem(function(slot)
		table.insert(cameras, turkeyPreview(slot, bundleSkin, { Size = UDim2.new(1, 0, 1, -22) }))
	end, bundleSkin.Name)
	plus()
	bundleItem(function(slot)
		Ui.icon(slot, "feathers_m", { Size = UDim2.new(1, 0, 1, -22) })
	end, Format.number(bundle.Feathers))
	plus()
	bundleItem(function(slot)
		Ui.icon(slot, "gift", { Size = UDim2.new(1, 0, 1, -22) })
	end, `{bundle.Starters} Starters`)
	text(bundleCard, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 40),
		Size = UDim2.fromOffset(150, 26),
		RichText = true,
		Text = `<s>R$ {bundle.WorthRobux}</s>`,
		TextColor3 = rgb(255, 230, 220),
	})
	robuxButton(bundleCard, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 72),
		Size = UDim2.fromOffset(158, 52),
	}, "Product", bundle.Id, "The Harvest Bundle is")
	table.insert(refreshers, function()
		skinCaption.Text = if ownedSkins()[bundle.Skin] then `+{Format.number(bundle.FeathersIfOwned)} (owned)` else bundleSkin.Name
	end)

	-- Skins (built here so the skin of the day can use their buttons' logic) ----------------------------------------------

	local skinPrices: { [string]: Purchases.Price } = {}
	local busy = false

	-- What a skin's button says, and its color.
	local function skinButtonState(skin): (string, Color3)
		local owned = ownedSkins()
		local source = Skins.source(skin)
		if skin.Id == player:GetAttribute("Skin") then
			return "Equipped", OWNED
		elseif owned[skin.Id] then
			return "Equip", rgb(74, 186, 52)
		elseif source == "Robux" then
			local id = robux.Skins[skin.Id] or 0
			return Purchases.label(skinPrices[skin.Id], id), if id == 0 then OWNED else rgb(74, 186, 52)
		elseif source == "Pass" then
			return `🎟️ Pass tier {passTier[skin.Id] or "?"}`, Ui.PURPLE
		end
		local price = Featured.price(skin, now())
		return `{Format.FEATHER} {Format.number(price)}`, if feathers() >= price then FEATHER_BUTTON else rgb(170, 120, 70)
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
		local ok, success, result = pcall(Remotes.Shop.InvokeServer, Remotes.Shop, action, skin.Id)
		busy = false
		say(if ok then result else "The shop is busy, try again!", ok and success)
		if ok and success then
			Audio.play(if action == "Buy" then "Purchase" else "Pickup")
		end
		refreshAll()
	end

	-- Skin of the day ----------------------------------------------------------------------------------------------------

	header("Deal", "Skin of the Day", HEADER_RED)
	local dealCard = card({ Size = UDim2.new(1, 0, 0, 132) }, CARD_RED)
	Ui.barnTag(dealCard, `-{math.floor(Featured.Discount * 100)}%`, rgb(226, 56, 42))
	local dealArt = Instance.new("Frame")
	dealArt.BackgroundTransparency = 1
	dealArt.Position = UDim2.new(0, 8, 0, 6)
	dealArt.Size = UDim2.fromOffset(124, 120)
	dealArt.Parent = dealCard
	local dealName = text(dealCard, { Position = UDim2.new(0, 140, 0, 14), Size = UDim2.new(1, -320, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
	local dealPrice = text(dealCard, {
		Position = UDim2.new(0, 140, 0, 50),
		Size = UDim2.new(1, -320, 0, 28),
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dealTimer = text(dealCard, { Position = UDim2.new(0, 140, 0, 84), Size = UDim2.new(1, -320, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	local dealButton = Ui.barnButton(dealCard, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 54),
	})
	dealButton.Activated:Connect(function()
		request(Featured.skin(now()))
	end)
	local dealSkinId: string? = nil
	local dealCamera: Camera? = nil
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
		dealPrice.Text = `<s>{Format.FEATHER} {Format.number(skin.Price)}</s>   {Format.FEATHER} {Format.number(Featured.price(skin, now()))}`
		dealButton.Text, dealButton.BackgroundColor3 = skinButtonState(skin)
	end)

	-- Game passes --------------------------------------------------------------------------------------------------------

	header("Vip", "Game Passes", HEADER)
	local passes = row(196)
	for i, pass in {
		{ Icon = "crown", Name = "VIP", Blurb = "2x Feathers every race, a VIP tag and a golden trail", Id = robux.VipPass, What = "VIP is", Owned = function() return player:GetAttribute("Vip") == true end },
		{ Icon = "ticket", Name = `{Season.Name} Premium`, Blurb = "Exclusive skins, boosts and Feathers on the premium track", Id = robux.PremiumPass, What = "The premium pass is", Owned = function() return player:GetAttribute("PassPremium") == true end },
	} do
		local c = cell(passes, i, 2, CARD)
		Ui.icon(c, pass.Icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(72, 72), ZIndex = 2 })
		text(c, { Position = UDim2.new(0, 8, 0, 74), Size = UDim2.new(1, -16, 0, 26), Text = pass.Name })
		text(c, { Position = UDim2.new(0, 10, 0, 102), Size = UDim2.new(1, -20, 0, 36), Text = pass.Blurb, TextWrapped = true })
		robuxButton(c, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -40, 0, 42) }, "GamePass", pass.Id, pass.What, pass.Owned)
	end

	-- Feathers -----------------------------------------------------------------------------------------------------------

	header("Feathers", "Feathers", HEADER)
	local packs = row(206)
	local PACK_ICONS = { "feathers_s", "feathers_m", "feathers_l" }
	local PACK_NOTES = { POPULAR = "Popular!", ["BEST VALUE"] = "Best value!" }
	for i, pack in robux.FeatherPacks do
		local c = cell(packs, i, #robux.FeatherPacks, CARD)
		text(c, { Position = UDim2.new(0, 6, 0, 8), Size = UDim2.new(1, -12, 0, 28), Text = Format.number(pack.Feathers), Thick = 3 })
		Ui.icon(c, PACK_ICONS[i] or "feathers_l", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(92, 92), ZIndex = 2 })
		if pack.Tag then
			text(c, { Position = UDim2.new(0, 6, 0, 128), Size = UDim2.new(1, -12, 0, 20), Text = PACK_NOTES[pack.Tag] or pack.Tag })
		end
		robuxButton(c, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 40) }, "Product", pack.Id, "Feather packs are")
	end

	-- Boosts -------------------------------------------------------------------------------------------------------------

	header("Boosts", "Power-Ups and Boosts", HEADER)
	local status = text(page, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24), RichText = true })
	local function boostCell(r: Frame, index: number, icon: string, title: string, blurb: string, id: number, what: string)
		local c = cell(r, index, 2, CARD)
		Ui.icon(c, icon, { Position = UDim2.new(0, 4, 0, 6), Size = UDim2.fromOffset(70, 70), ZIndex = 2 })
		text(c, { Position = UDim2.new(0, 78, 0, 10), Size = UDim2.new(1, -86, 0, 26), Text = title, TextXAlignment = Enum.TextXAlignment.Left })
		text(c, { Position = UDim2.new(0, 78, 0, 38), Size = UDim2.new(1, -86, 0, 34), Text = blurb, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		robuxButton(c, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -40, 0, 40) }, "Product", id, what)
	end
	local starters = row(140)
	for i, starter in robux.Starters do
		boostCell(starters, i, "gift", `Starter • {starter.Races} races`, "Start races with a power-up in hand", starter.Id, "Power-Up Starters are")
	end
	local boosts = row(140)
	for i, boost in robux.XpBoosts do
		local hours = boost.Minutes // 60
		local length = if boost.Minutes % 60 ~= 0 or hours == 0 then `{boost.Minutes} min` elseif hours == 1 then "1 hour" else `{hours} hours`
		boostCell(boosts, i, "lightning", `2x XP • {length}`, "Level up and climb the pass faster", boost.Id, "XP boosts are")
	end
	table.insert(refreshers, function()
		local parts = {}
		local left = (player:GetAttribute("BoostUntil") or 0) - now()
		table.insert(parts, if left > 0 then `⚡ 2x XP: {Format.duration(left)} left` else "No XP boost running")
		local count = player:GetAttribute("Starters") or 0
		if count > 0 then
			table.insert(parts, `🎁 {count} starter{if count == 1 then "" else "s"} left`)
		end
		status.Text = table.concat(parts, "   •   ")
	end)

	-- Turkey skins -------------------------------------------------------------------------------------------------------

	header("Skins", "Turkey Skins", HEADER)
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = nextOrder()
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.Parent = page
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(10, 14)
	gridLayout.CellSize = UDim2.new(1 / 3, -7, 0, 220)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 8)
	gridPad.Parent = grid
	local entries = {}
	for i, skin in Skins.List do
		local rarity = Skins.Rarities[skin.Rarity]
		local c = Ui.barnPanel(grid, { Name = skin.Id, LayoutOrder = i }, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35), rarity.Color, 135, Ui.DOTS)
		table.insert(cameras, turkeyPreview(c, skin, { Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0.56, -6), ZIndex = 2 }))
		text(c, { Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 18), Text = string.upper(skin.Rarity), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		text(c, { Position = UDim2.new(0, 6, 0.58, 0), Size = UDim2.new(1, -12, 0, 26), Text = skin.Name })
		local button = Ui.barnButton(c, {
			Name = "Action",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 40),
		})
		button.Activated:Connect(function()
			request(skin)
		end)
		local sale = Ui.barnTag(c, `-{math.floor(Featured.Discount * 100)}%`, rgb(226, 56, 42))
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

	-- Opening, scrolling to a section, the red dot ------------------------------------------------------------------------

	local function setOpen(open: boolean)
		openWindow(open)
		if open then
			message.Text = ""
			refreshAll()
		end
	end
	-- Scrolls so `target` sits at the top of the page.
	local function scrollTo(target: GuiObject)
		task.defer(function()
			local y = (target.AbsolutePosition.Y - page.AbsolutePosition.Y) / Ui.scaleOf(page) + page.CanvasPosition.Y
			page.CanvasPosition = Vector2.new(0, math.max(0, y - 10))
		end)
	end
	openButton.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	openTab = function(name: string)
		if player:GetAttribute("Racing") or not sections[name] then
			return
		end
		setOpen(true)
		scrollTo(sections[name])
	end
	openAt = function(skinId: string?)
		if player:GetAttribute("Racing") then
			return
		end
		setOpen(true)
		local target = skinId and grid:FindFirstChild(skinId) :: GuiObject?
		scrollTo(target or sections.Skins)
		if target then
			Ui.pop(target, 0.7)
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
	for _, attribute in { "OwnedSkins", "Skin", "PassPremium", "Vip", "Starters", "BoostUntil" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refreshAll()
			refreshDot()
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal("FeastUntil"):Connect(refreshFeast)
	window:GetPropertyChangedSignal("Visible"):Connect(refreshDot)
	task.spawn(function()
		player:WaitForChild("leaderstats"):WaitForChild("Feathers").Changed:Connect(function()
			refreshAll()
			refreshDot()
		end)
		refreshAll()
		refreshDot()
	end)
	window.Visible = false

	-- While the shop is open: spin the previews and keep the timers ticking.
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
		if os.clock() - lastTick > 0.5 then
			lastTick = os.clock()
			dealTimer.Text = `New deal in {Format.duration(Featured.secondsLeft(now()))}`
			refreshFeast()
			refreshAll()
		end
	end)
end

return Shop
