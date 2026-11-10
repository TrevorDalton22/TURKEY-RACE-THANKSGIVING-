-- The on-screen HUD.
--   Always:   the status bar at the top (what's happening and the time left) and banners.
--   Lobby:    Feathers, level and XP, and the XP boost timer.
--   Racing:   lap, place, stamina, the power-up slot and the start countdown.
--   After:    the results board (held back while the podium cutscene plays).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Featured = require(ReplicatedStorage.Shared.Featured)
local Format = require(ReplicatedStorage.Shared.Format)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Ui = require(script.Parent.Ui)
local Cutscene = require(script.Parent.Cutscene)
local Shop = require(script.Parent.Shop)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Hud = {}

local MODE_NAMES = { Race = "Race", Elimination = "Don't Get Cooked" }
local POWER_COLORS = {
	DrumstickDash = Color3.fromRGB(255, 140, 40),
	PieLauncher = Color3.fromRGB(215, 155, 85),
	ButterSlide = Color3.fromRGB(245, 205, 60),
	GobbleBomb = Color3.fromRGB(230, 70, 60),
	MashedPotatoShield = Color3.fromRGB(150, 175, 205),
	CornTornado = Color3.fromRGB(110, 190, 75),
}
local PLACE_COLORS = { Ui.GOLD, Color3.fromRGB(215, 225, 240), Color3.fromRGB(230, 150, 80) }
local COUNT_COLORS = { Color3.fromRGB(120, 230, 110), Ui.GOLD, Ui.ORANGE, Ui.RED } -- GO, 1, 2, 3
local XP_BLUE = Color3.fromRGB(110, 195, 255)
local LOW_STAMINA = Color3.fromRGB(230, 70, 55)

local label, card = Ui.label, Ui.card

function Hud.start(controls)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the status bar sits in the top bar, between Roblox's buttons
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.autoScale(gui)

	-- Status bar ---------------------------------------------------------------------------------------
	local statusBar = card(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(500, 44),
	})
	statusBar.Border.Color = Ui.ORANGE
	local status = label(statusBar, { Position = UDim2.new(0, 14, 0, 7), Size = UDim2.new(1, -28, 1, -14) })
	local lapPill = card(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = Ui.ORANGE,
		Visible = false,
	})
	local lapLabel = label(lapPill, { Position = UDim2.new(0, 10, 0, 5), Size = UDim2.new(1, -20, 1, -10) })

	-- Lobby: Feathers, level and XP ------------------------------------------------------------------------
	-- Above the menu tiles; on phones, at the end of their row along the top (see Ui.menuButton).
	local feathersPill = card(gui, {
		AnchorPoint = if Ui.isPhone() then Vector2.new(0, 0.5) else Vector2.new(0, 1),
		Position = if Ui.isPhone() then UDim2.new(0, 14 + 3 * 88 + 16, 0, Ui.PHONE_MENU_TOP + 40) else UDim2.new(0, 14, 0.5, -12),
		Size = UDim2.fromOffset(150, 42),
	})
	Ui.icon(feathersPill, "feather", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 2,
	})
	local feathersLabel = label(feathersPill, {
		Position = UDim2.new(0, 40, 0, 6),
		Size = UDim2.new(1, -50, 1, -12),
		TextColor3 = Ui.CREAM,
	})

	local xpBar = card(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 18, 1, -28),
		Size = UDim2.fromOffset(360, 30),
	})
	local xpFill = Instance.new("Frame")
	xpFill.BackgroundColor3 = XP_BLUE
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpBar
	Instance.new("UICorner").Parent = xpFill
	local xpText = label(xpBar, { Position = UDim2.new(0, 34, 0, 5), Size = UDim2.new(1, -44, 1, -10), ZIndex = 2 })
	local levelBadge = card(xpBar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Ui.BLUE,
		ZIndex = 3,
	})
	levelBadge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	label(levelBadge, { Position = UDim2.fromScale(0.15, 0.1), Size = UDim2.fromScale(0.7, 0.28), Text = "LEVEL", ZIndex = 3 })
	local levelLabel = label(levelBadge, { Position = UDim2.fromScale(0.15, 0.36), Size = UDim2.fromScale(0.7, 0.5), ZIndex = 3 })
	local boostPill = card(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 18, 1, -70),
		Size = UDim2.fromOffset(190, 30),
		BackgroundColor3 = Color3.fromRGB(40, 90, 150),
		Visible = false,
	})
	local boostLabel = label(boostPill, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 1, -8) })

	-- A Feast Frenzy someone bought for the whole server, under the status bar (and the lap pill while racing).
	local feastPill = card(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(360, 34),
		BackgroundColor3 = Color3.fromRGB(205, 96, 34),
		Visible = false,
	})
	local feastLabel = label(feastPill, { Position = UDim2.new(0, 10, 0, 5), Size = UDim2.new(1, -20, 1, -10) })

	-- Racing: place, stamina, power-up slot, countdown ---------------------------------------------------------
	local placeCard = card(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 40),
		Size = UDim2.fromOffset(150, 120),
		Visible = false,
	})
	local placeLabel = label(placeCard, { Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -16, 0.62, 0) })
	placeLabel.Outline.Thickness = 3
	local placeOf = label(placeCard, {
		Position = UDim2.new(0, 8, 0.66, 0),
		Size = UDim2.new(1, -16, 0.26, 0),
		TextColor3 = Ui.CREAM,
	})

	local staminaBar = card(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(320, 26),
		Visible = false,
	})
	local staminaFill = Instance.new("Frame")
	staminaFill.BackgroundColor3 = Ui.GOLD
	staminaFill.BorderSizePixel = 0
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.Parent = staminaBar
	Instance.new("UICorner").Parent = staminaFill
	local staminaGradient = Instance.new("UIGradient")
	staminaGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 170, 120))
	staminaGradient.Parent = staminaFill
	label(staminaBar, { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 1, -8), Text = "⚡ STAMINA", ZIndex = 2 })

	local slot = card(gui, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(124, 140),
		Visible = false,
	})
	local slotIcon = Ui.icon(slot, "star", { Position = UDim2.new(0.12, 0, 0, 6), Size = UDim2.new(0.76, 0, 0.52, 0) })
	local slotName = label(slot, { Position = UDim2.new(0, 8, 0.56, 0), Size = UDim2.new(1, -16, 0.18, 0) })
	local keycap = card(slot, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(if UserInputService.KeyboardEnabled then 40 else 70, 26),
		BackgroundColor3 = Ui.CREAM,
	})
	label(keycap, {
		Position = UDim2.new(0, 4, 0, 3),
		Size = UDim2.new(1, -8, 1, -6),
		Text = if UserInputService.KeyboardEnabled then "E" else "USE",
		TextColor3 = Ui.DARK,
		TextStrokeTransparency = 1,
	})

	local countdown = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(320, 200),
		Visible = false,
	})
	countdown.Outline.Thickness = 5

	-- Controls, bottom left (keyboards only).
	if UserInputService.KeyboardEnabled then
		local hint = Ui.panel(gui, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -8),
			Size = UDim2.fromOffset(470, 24),
			BackgroundTransparency = 0.45,
		})
		local key = '<font color="#FFB347">%s</font>'
		label(hint, {
			Position = UDim2.new(0, 10, 0, 3),
			Size = UDim2.new(1, -20, 1, -6),
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{key:format("Shift")} sprint   {key:format("Space")} flap   {key:format("Q")} slide   {key:format("E")} item   {key:format("G")} gobble`,
		})
	end

	-- Banners ---------------------------------------------------------------------------------------------------
	local banner = card(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(560, 54),
		Visible = false,
	})
	banner.Border.Color = Ui.ORANGE
	local bannerLabel = label(banner, { Position = UDim2.new(0, 16, 0, 9), Size = UDim2.new(1, -32, 1, -18) })
	local bannerToken = 0
	Remotes.Notify.OnClientEvent:Connect(function(text: string)
		bannerToken += 1
		local token = bannerToken
		bannerLabel.Text = text
		banner.Visible = true
		Ui.pop(banner, 0.5)
		task.delay(2.8, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end)

	-- Results board ---------------------------------------------------------------------------------------------
	local results = card(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 440),
		BackgroundColor3 = Ui.WINDOW,
		Visible = false,
	})
	local resultsHeader = card(results, {
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 0, 50),
		BackgroundColor3 = Ui.ORANGE,
	})
	local resultsTitle = label(resultsHeader, { Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -24, 1, -14), Text = "🏁 RESULTS" })
	resultsTitle.Outline.Thickness = 3
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.new(0, 14, 0, 70)
	rows.Size = UDim2.new(1, -28, 1, -84)
	rows.Parent = results
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	-- Under the results: how close you are to the next skin, with a way to the shop.
	local nudge = Ui.panel(results, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(1, -28, 0, 44),
		BackgroundColor3 = Ui.DARK,
	})
	local nudgeLabel = label(nudge, {
		Position = UDim2.new(0, 12, 0, 9),
		Size = UDim2.new(1, -150, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.CREAM,
	})
	local nudgeButton = Ui.button(nudge, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Ui.GREEN,
		Text = "SHOP",
	})
	local nudgeSkin: string? = nil
	nudgeButton.Activated:Connect(function()
		results.Visible = false
		Shop.open(nudgeSkin)
	end)

	-- The cheapest Feathers skin you don't own yet, and what it costs you today.
	local function updateNudge(): boolean
		local owned = {}
		for id in string.gmatch(player:GetAttribute("OwnedSkins") or "", "[^,]+") do
			owned[id] = true
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local have = if leaderstats then leaderstats.Feathers.Value else 0
		local best, bestPrice = nil, math.huge
		for _, skin in Skins.List do
			local price = if Skins.source(skin) == "Feathers" then Featured.price(skin, workspace:GetServerTimeNow()) else math.huge
			if not owned[skin.Id] and price < bestPrice then
				best, bestPrice = skin, price
			end
		end
		if not best then
			return false
		end
		nudgeSkin = best.Id
		nudgeLabel.Text = if have >= bestPrice
			then `🦃 You can buy the {best.Name} now!`
			else `{Format.number(bestPrice - have)} more {Format.FEATHER} for the {best.Name}`
		return true
	end

	local function resultRow(entry)
		local mine = entry.UserId == player.UserId
		local row = Ui.panel(rows, {
			LayoutOrder = entry.Place,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if mine then Color3.fromRGB(110, 66, 30) else Ui.PANEL,
			BackgroundTransparency = 0,
		})
		if mine then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Ui.ORANGE
			stroke.Thickness = 2
			stroke.Parent = row
		end
		local badge = card(row, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = PLACE_COLORS[entry.Place] or Color3.fromRGB(120, 85, 60),
		})
		badge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		label(badge, { Position = UDim2.fromScale(0.15, 0.18), Size = UDim2.fromScale(0.7, 0.64), Text = tostring(entry.Place) })
		local detail = if entry.Time then Format.raceTime(entry.Time) elseif entry.Status == "Cooked" then "COOKED 🔥" else "DNF"
		label(row, {
			Position = UDim2.new(0, 46, 0, 8),
			Size = UDim2.new(0.4, -46, 1, -16),
			Text = entry.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if entry.Place == 1 then Ui.GOLD else Color3.new(1, 1, 1),
		})
		label(row, {
			Position = UDim2.new(0.4, 0, 0, 9),
			Size = UDim2.new(0.22, 0, 1, -18),
			Text = detail,
			TextColor3 = Ui.CREAM,
		})
		label(row, {
			Position = UDim2.new(0.62, 0, 0, 9),
			Size = UDim2.new(0.38, -8, 1, -18),
			Text = `+{entry.Feathers} {Format.FEATHER}   <font color="#8ECFFF">+{entry.Xp or 0} XP</font>`,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.CREAM,
		})
	end

	local resultsToken = 0
	Remotes.Results.OnClientEvent:Connect(function(list)
		-- Racers see the podium cutscene first.
		resultsToken += 1
		local token = resultsToken
		local holdBack = if Cutscene.plays(list) then Config.PodiumSeconds else 0
		for _, child in rows:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, entry in list do
			resultRow(entry)
		end
		task.delay(holdBack, function()
			if token == resultsToken then
				-- As tall as the rows need, plus the nudge when there's a skin left to buy.
				nudge.Visible = updateNudge()
				results.Size = UDim2.fromOffset(520, 84 + #list * 46 + (if nudge.Visible then 54 else 0))
				results.Visible = true
				Ui.pop(results, 0.8)
			end
		end)
		task.delay(Config.ResultsSeconds, function()
			if token == resultsToken then
				results.Visible = false
			end
		end)
	end)

	-- Every frame ------------------------------------------------------------------------------------------------
	local lastCount: number? = nil
	local lastPowerUp: string? = nil
	local goUntil = 0
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Racing" and player:GetAttribute("Racing") then
			goUntil = os.clock() + 0.9
		end
	end)

	RunService.RenderStepped:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase") or "Waiting"
		local remaining = math.max(0, (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
		local mode = MODE_NAMES[ReplicatedStorage:GetAttribute("Mode") or "Race"] or "Race"
		local map = ReplicatedStorage:GetAttribute("Map") or ""
		local racing = player:GetAttribute("Racing") == true
		local inCircle = player:GetAttribute("InCircle") == true

		if phase == "Waiting" then
			status.Text = "🏁 Step into the JOIN RACE circle to race!"
		elseif phase == "Intermission" then
			status.Text = if inCircle then `✅ You're in!  Starting in {math.ceil(remaining)}  •  {map}`
				else `⏱️ Race in {math.ceil(remaining)}  •  Step into the JOIN RACE circle!`
		elseif phase == "Countdown" then
			status.Text = if racing then `{map}  •  {mode}` else "🏁 Race starting!  Join the next one in the circle"
		elseif phase == "Racing" then
			status.Text = if racing then `⏱️ {Format.clock(remaining)}  •  {mode}` else "🏁 Race on!  Join the next one in the circle"
		else
			status.Text = "🏆 Results"
		end

		-- The countdown pops each number, then GO!
		local count = math.ceil(remaining)
		local showCount = phase == "Countdown" and racing and count >= 1
		local showGo = os.clock() < goUntil
		countdown.Visible = showCount or showGo
		if showGo then
			if lastCount ~= 0 then
				lastCount = 0
				countdown.Text = "GO!"
				countdown.TextColor3 = COUNT_COLORS[1]
				Ui.pop(countdown, 1.8)
			end
		elseif showCount and count ~= lastCount then
			lastCount = count
			countdown.Text = tostring(count)
			countdown.TextColor3 = COUNT_COLORS[math.min(count, 3) + 1]
			Ui.pop(countdown, 1.8)
		elseif not countdown.Visible then
			lastCount = nil
		end

		lapPill.Visible = racing
		placeCard.Visible = racing
		staminaBar.Visible = racing
		feathersPill.Visible = not racing

		local feastLeft = (ReplicatedStorage:GetAttribute("FeastUntil") or 0) - workspace:GetServerTimeNow()
		feastPill.Visible = feastLeft > 0
		if feastPill.Visible then
			local by = ReplicatedStorage:GetAttribute("FeastBy")
			feastLabel.Text = `🦃 FEAST FRENZY: {Config.Robux.FeastFrenzy.Multiplier}x Feathers • {Format.duration(feastLeft)}{if by then ` • thanks {by}!` else ""}`
			feastPill.Position = UDim2.new(0.5, 0, 0, if racing then 106 else 62)
		end
		if racing then
			lapLabel.Text = `LAP {player:GetAttribute("Lap") or 1}/{ReplicatedStorage:GetAttribute("Laps") or Config.Laps}`
			local place = player:GetAttribute("Place") or 1
			if player:GetAttribute("Cooked") then
				placeLabel.Text = "🔥"
				placeOf.Text = "COOKED!"
			elseif player:GetAttribute("Finished") then
				placeLabel.Text = string.upper(Format.ordinal(place))
				placeOf.Text = "FINISHED!"
			else
				placeLabel.Text = string.upper(Format.ordinal(place))
				placeOf.Text = "PLACE"
			end
			placeLabel.TextColor3 = PLACE_COLORS[place] or Color3.new(1, 1, 1)
			local fraction = math.clamp(controls.Stamina / Config.Movement.StaminaMax, 0, 1)
			staminaFill.Size = UDim2.fromScale(fraction, 1)
			staminaFill.Visible = fraction > 0.02
			local low = fraction < 0.3
			staminaFill.BackgroundColor3 = if low then LOW_STAMINA else Ui.GOLD
			staminaBar.Border.Color = LOW_STAMINA
			staminaBar.Border.Transparency = if low and os.clock() % 0.5 < 0.25 then 0 else 1
		end

		local kind = player:GetAttribute("PowerUp")
		local def = kind and Config.PowerUps[kind]
		-- While the touch buttons are showing, their Use button shows the power-up instead (client/TouchButtons).
		local touchButtons = gui.Parent:FindFirstChild("TurkeyTouchButtons")
		slot.Visible = def ~= nil and not (touchButtons and touchButtons.Enabled)
		if def and kind ~= lastPowerUp then
			Ui.setIcon(slotIcon, Ui.POWER_ICONS[kind] or "star")
			slotName.Text = def.Name
			slot.BackgroundColor3 = POWER_COLORS[kind] or Ui.DARK
			Ui.pop(slot, 0.4)
		end
		lastPowerUp = kind

		local leaderstats = player:FindFirstChild("leaderstats")
		local feathers = leaderstats and leaderstats:FindFirstChild("Feathers")
		feathersLabel.Text = Format.number(if feathers then feathers.Value else 0)

		-- Out of the way while the shop, pass or settings window is open.
		local windowOpen = false
		for _, name in { "TurkeyShop", "TurkeyPass", "TurkeySettings" } do
			local window = gui.Parent:FindFirstChild(name) and gui.Parent[name]:FindFirstChild("Window")
			windowOpen = windowOpen or (window ~= nil and window.Visible)
		end
		xpBar.Visible = not racing and not windowOpen
		if xpBar.Visible then
			local into, need = player:GetAttribute("LevelXp") or 0, player:GetAttribute("LevelXpNeeded") or 1
			levelLabel.Text = tostring(player:GetAttribute("Level") or 1)
			xpFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
			xpFill.Visible = into > 0
			xpText.Text = `{Format.number(into)} / {Format.number(need)} XP`
		end
		local boostLeft = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
		boostPill.Visible = boostLeft > 0 and not windowOpen and not racing
		if boostPill.Visible then
			boostLabel.Text = `⚡ 2x XP  {Format.duration(boostLeft)}`
		end
	end)
end

return Hud
