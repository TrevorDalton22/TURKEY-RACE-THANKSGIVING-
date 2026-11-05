-- Race HUD: status and timer, countdown, lap and place, stamina, power-up slot, banners and results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local Cutscene = require(script.Parent.Cutscene)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Hud = {}

local MODE_NAMES = { Race = "Race", Elimination = "Don't Get Cooked" }
local ORANGE = Ui.ORANGE
local label, panel = Ui.label, Ui.panel

function Hud.start(controls)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local status = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 600, 0, 38) })
	local countdown = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0, 260, 0, 180), TextColor3 = ORANGE, Visible = false })

	local racePanel = panel(gui, { Position = UDim2.new(0, 12, 0, 60), Size = UDim2.new(0, 170, 0, 70), Visible = false })
	local lapLabel = label(racePanel, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0.5, -4), TextXAlignment = Enum.TextXAlignment.Left })
	local placeLabel = label(racePanel, { Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0.5, -4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ORANGE })

	local staminaBar = panel(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(0, 260, 0, 14), Visible = false })
	local staminaFill = panel(staminaBar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0 })

	local slot = panel(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Size = UDim2.new(0, 110, 0, 120), Visible = false })
	local slotIcon = label(slot, { Size = UDim2.new(1, 0, 0.6, 0), TextStrokeTransparency = 1 })
	local slotName = label(slot, { Position = UDim2.new(0, 6, 0.6, 0), Size = UDim2.new(1, -12, 0.22, 0) })
	label(slot, { Position = UDim2.new(0, 0, 0.82, 0), Size = UDim2.new(1, 0, 0.16, 0), Text = "[E]", TextColor3 = ORANGE })

	local banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.new(0, 640, 0, 52), TextTransparency = 1, TextStrokeTransparency = 1 })

	-- Level and XP toward the next level, in the lobby; the XP boost timer whenever one is running.
	local XP_BLUE = Color3.fromRGB(120, 200, 255)
	local xpBar = panel(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -36), Size = UDim2.new(0, 340, 0, 30) })
	local levelBadge = label(xpBar, { Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0, 70, 1, 0), TextColor3 = ORANGE })
	local xpTrack = panel(xpBar, { Position = UDim2.new(0, 80, 0, 6), Size = UDim2.new(1, -88, 1, -12), BackgroundColor3 = Color3.fromRGB(35, 20, 12), BackgroundTransparency = 0 })
	local xpFill = panel(xpTrack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = XP_BLUE, BackgroundTransparency = 0 })
	local xpText = label(xpTrack, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local boostLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.new(0, 300, 0, 24), TextColor3 = XP_BLUE, Visible = false })

	if UserInputService.KeyboardEnabled then
		label(gui, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -10),
			Size = UDim2.new(0, 600, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Shift sprint  •  Space flap (in the air)  •  Q belly slide  •  E power-up  •  G gobble",
		})
	end

	local results = panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 460, 0, 380), Visible = false })
	label(results, { Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, 0, 0, 44), Text = "RESULTS", TextColor3 = ORANGE })
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.new(0, 20, 0, 64)
	rows.Size = UDim2.new(1, -40, 1, -80)
	rows.Parent = results
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = rows

	local bannerTween: Tween?
	Remotes.Notify.OnClientEvent:Connect(function(text: string)
		if bannerTween then
			bannerTween:Cancel()
		end
		banner.Text = text
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.3
		bannerTween = TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
		bannerTween:Play()
	end)

	local resultsToken = 0
	Remotes.Results.OnClientEvent:Connect(function(list)
		-- Racers see the podium cutscene first.
		resultsToken += 1
		local token = resultsToken
		local holdBack = if Cutscene.plays(list) then Config.PodiumSeconds else 0
		for _, child in rows:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for _, entry in list do
			local detail = if entry.Time then Format.raceTime(entry.Time) elseif entry.Status == "Cooked" then "COOKED 🔥" else "DNF"
			label(rows, {
				Size = UDim2.new(1, 0, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = `{Format.ordinal(entry.Place)}   {entry.Name}   {detail}   +{entry.Feathers} {Format.FEATHER}  +{entry.Xp or 0} XP`,
				TextColor3 = if entry.Place == 1 then ORANGE else Color3.new(1, 1, 1),
			})
		end
		task.delay(holdBack, function()
			if token == resultsToken then
				results.Visible = true
			end
		end)
		task.delay(Config.ResultsSeconds, function()
			if token == resultsToken then
				results.Visible = false
			end
		end)
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
			status.Text = if inCircle then `✅ You're in!  Race starts in {math.ceil(remaining)}  •  {map}  •  {mode}`
				else `Race starts in {math.ceil(remaining)}  •  Step into the JOIN RACE circle to play!`
		elseif phase == "Countdown" then
			status.Text = if racing then `Get ready!  •  {map}  •  {mode}` else "Race starting!  •  Step into the JOIN RACE circle for the next one"
		elseif phase == "Racing" then
			status.Text = if racing then `{mode}  •  {Format.clock(remaining)}`
				else "Race in progress  •  Step into the JOIN RACE circle for the next one!"
		else
			status.Text = "🏆 Results"
		end

		countdown.Visible = phase == "Countdown" and racing
		countdown.Text = tostring(math.max(1, math.ceil(remaining)))

		racePanel.Visible = racing
		staminaBar.Visible = racing
		if racing then
			lapLabel.Text = `Lap {player:GetAttribute("Lap") or 1}/{ReplicatedStorage:GetAttribute("Laps") or Config.Laps}`
			placeLabel.Text = if player:GetAttribute("Cooked") then "COOKED 🔥"
				elseif player:GetAttribute("Finished") then "Finished!"
				else `{Format.ordinal(player:GetAttribute("Place") or 1)} place`
			local fraction = controls.Stamina / Config.Movement.StaminaMax
			staminaFill.Size = UDim2.fromScale(fraction, 1)
			staminaFill.BackgroundColor3 = if fraction < 0.3 then Color3.fromRGB(220, 60, 50) else ORANGE
		end

		local kind = player:GetAttribute("PowerUp")
		local def = kind and Config.PowerUps[kind]
		slot.Visible = def ~= nil
		if def then
			slotIcon.Text = def.Icon
			slotName.Text = def.Name
		end

		-- Out of the way while the shop or pass window is open.
		local windowOpen = false
		for _, name in { "TurkeyShop", "TurkeyPass", "TurkeySettings" } do
			local window = gui.Parent:FindFirstChild(name) and gui.Parent[name]:FindFirstChild("Window")
			windowOpen = windowOpen or (window ~= nil and window.Visible)
		end
		xpBar.Visible = not racing and not windowOpen
		if xpBar.Visible then
			local into, need = player:GetAttribute("LevelXp") or 0, player:GetAttribute("LevelXpNeeded") or 1
			levelBadge.Text = `Lv {player:GetAttribute("Level") or 1}`
			xpFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
			xpText.Text = `{into} / {need} XP`
		end
		local boostLeft = (player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow()
		boostLabel.Visible = boostLeft > 0 and not windowOpen
		if boostLabel.Visible then
			boostLabel.Text = `⚡ 2x XP  {Format.duration(boostLeft)}`
		end
	end)
end

return Hud
