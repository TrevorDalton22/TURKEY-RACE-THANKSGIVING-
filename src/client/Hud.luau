-- Race HUD: status and timer, countdown, lap and place, stamina, power-up slot, banners and results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)

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

	Remotes.Results.OnClientEvent:Connect(function(list)
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
				Text = `{Format.ordinal(entry.Place)}   {entry.Name}   {detail}   +{entry.Feathers} 🪶`,
				TextColor3 = if entry.Place == 1 then ORANGE else Color3.new(1, 1, 1),
			})
		end
		results.Visible = true
		task.delay(Config.ResultsSeconds, function()
			results.Visible = false
		end)
	end)

	RunService.RenderStepped:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase") or "Waiting"
		local remaining = math.max(0, (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
		local mode = MODE_NAMES[ReplicatedStorage:GetAttribute("Mode") or "Race"] or "Race"
		local map = ReplicatedStorage:GetAttribute("Map") or ""
		local racing = player:GetAttribute("Racing") == true

		if phase == "Waiting" then
			status.Text = "Waiting for turkeys..."
		elseif phase == "Intermission" then
			status.Text = `Next race in {math.ceil(remaining)}  •  {map}  •  {mode}`
		elseif phase == "Countdown" then
			status.Text = `Get ready!  •  {map}  •  {mode}`
		elseif phase == "Racing" then
			status.Text = if racing then `{mode}  •  {Format.clock(remaining)}` else "Race in progress, next one soon!"
		else
			status.Text = "Results"
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
	end)
end

return Hud
