-- The Settings button and window: music and sound effects on or off (saved with your stats), the track
-- that's playing and a button to skip it. Also shows the name of each new track in the corner for a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Audio)
local Music = require(script.Parent.Music)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Settings = {}

local ON_COLOR = Color3.fromRGB(95, 200, 95)
local OFF_COLOR = Color3.fromRGB(125, 110, 100)

-- Each setting: its saved name, the player attribute the server publishes it as, its label, and the sound
-- group it switches.
local OPTIONS = {
	{ Name = "Music", Attribute = "MusicOn", Label = "🎵 Music", Group = Audio.Music },
	{ Name = "Sfx", Attribute = "SfxOn", Label = "🔊 Sound effects", Group = Audio.Effects },
}

local function isOn(option): boolean
	return player:GetAttribute(option.Attribute) ~= false
end

function Settings.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeySettings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- over the HUD
	gui.Parent = player:WaitForChild("PlayerGui")

	local openButton = Ui.button(gui, {
		Name = "OpenButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 112),
		Size = UDim2.new(0, 120, 0, 46),
		Text = "⚙️ Settings",
	})

	local window = Ui.panel(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 400, 0, 290),
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	Ui.label(window, {
		Position = UDim2.new(0, 16, 0, 12),
		Size = UDim2.new(1, -80, 0, 40),
		Text = "⚙️ SETTINGS",
		TextColor3 = Ui.ORANGE,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local closeButton = Ui.button(window, {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 40, 0, 36),
		BackgroundColor3 = Color3.fromRGB(200, 60, 50),
		Text = "X",
	})

	-- One row per setting: its label on the left, an ON/OFF switch on the right.
	local switches = {}
	local function apply(option)
		local on = isOn(option)
		option.Group.Volume = if on then 1 else 0
		local switch = switches[option.Name]
		switch.Text = if on then "ON" else "OFF"
		switch.BackgroundColor3 = if on then ON_COLOR else OFF_COLOR
	end
	for i, option in OPTIONS do
		local y = 64 + (i - 1) * 56
		Ui.label(window, {
			Position = UDim2.new(0, 20, 0, y),
			Size = UDim2.new(1, -150, 0, 40),
			Text = option.Label,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local switch = Ui.button(window, {
			Name = option.Name .. "Switch",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, y),
			Size = UDim2.new(0, 100, 0, 40),
		})
		switches[option.Name] = switch
		switch.Activated:Connect(function()
			local on = not isOn(option)
			-- Change it here straight away (the server sets the same attribute, which saves it).
			player:SetAttribute(option.Attribute, on)
			Remotes.Settings:FireServer(option.Name, on)
			apply(option)
		end)
		player:GetAttributeChangedSignal(option.Attribute):Connect(function()
			apply(option)
		end)
		apply(option)
	end

	-- What's playing, with a skip button.
	local nowPlaying = Ui.label(window, {
		Position = UDim2.new(0, 20, 0, 184),
		Size = UDim2.new(1, -150, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 225, 170),
	})
	local skipButton = Ui.button(window, {
		Name = "SkipButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 180),
		Size = UDim2.new(0, 100, 0, 38),
		Text = "⏭ Skip",
	})
	skipButton.Activated:Connect(Music.skip)
	Ui.label(window, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -40, 0, 22),
		Text = "Music courtesy of APM Music",
		TextColor3 = Color3.fromRGB(200, 180, 160),
		TextStrokeTransparency = 1,
	})

	-- The new track's name in the bottom-left corner for a few seconds (only while music is on).
	local toast = Ui.label(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -34),
		Size = UDim2.new(0, 420, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 225, 170),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local toastTween: Tween?
	local function showTrack(name: string?)
		nowPlaying.Text = if name then `♪ {name}` else ""
		if not name or not isOn(OPTIONS[1]) then
			return
		end
		if toastTween then
			toastTween:Cancel()
		end
		toast.Text = `♪ Now playing: {name}`
		toast.TextTransparency = 0
		toast.TextStrokeTransparency = 0.4
		toastTween = TweenService:Create(toast, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 4), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		toastTween:Play()
	end
	Music.Changed:Connect(showTrack)
	showTrack(Music.Current)

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
	end)
	closeButton.Activated:Connect(function()
		window.Visible = false
	end)
end

return Settings
