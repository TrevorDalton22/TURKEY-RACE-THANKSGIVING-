-- The Settings button and window: music and sound effects on or off (saved with your stats), the track
-- that's playing and a button to skip it. Also shows the name of each new track in the corner for a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	Ui.autoScale(gui)

	local openButton = Ui.menuButton(gui, 3, "gear", "SETTINGS", Ui.BLUE)
	local window, body, setOpen = Ui.window(gui, "SETTINGS", Ui.BLUE, UDim2.fromOffset(420, 320), Vector2.new(420, 320))
	Ui.icon(window.Header, "gear", { Position = UDim2.new(0, 8, 0, -4), Size = UDim2.fromOffset(52, 52), ZIndex = 2 })
	window.Header.Title.Position = UDim2.new(0, 64, 0, 7)

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
		local row = Ui.panel(body, {
			Position = UDim2.new(0, 0, 0, (i - 1) * 60),
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 0,
		})
		Ui.label(row, {
			Position = UDim2.new(0, 14, 0, 10),
			Size = UDim2.new(1, -140, 1, -20),
			Text = option.Label,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local switch = Ui.button(row, {
			Name = option.Name .. "Switch",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 38),
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
	local musicRow = Ui.panel(body, {
		Position = UDim2.new(0, 0, 0, 120),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 0,
	})
	local nowPlaying = Ui.label(musicRow, {
		Position = UDim2.new(0, 14, 0, 12),
		Size = UDim2.new(1, -140, 1, -24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.CREAM,
	})
	local skipButton = Ui.button(musicRow, {
		Name = "SkipButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 100, 0, 38),
		Text = "⏭ Skip",
		BackgroundColor3 = Ui.BLUE,
	})
	skipButton.Activated:Connect(Music.skip)
	Ui.label(body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Music courtesy of APM Music",
		TextColor3 = Color3.fromRGB(200, 180, 160),
		TextStrokeTransparency = 1,
	})

	-- The new track's name in the bottom-left corner for a few seconds (only while music is on).
	local toast = Ui.label(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -38),
		Size = UDim2.new(0, 420, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.CREAM,
		Visible = false,
	})
	local toastToken = 0
	local function showTrack(name: string?)
		nowPlaying.Text = if name then `♪ {name}` else ""
		if not name or not isOn(OPTIONS[1]) then
			return
		end
		toastToken += 1
		local token = toastToken
		toast.Text = `♪ Now playing: {name}`
		toast.Visible = true
		Ui.pop(toast, 0.7)
		task.delay(5, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end
	Music.Changed:Connect(showTrack)
	showTrack(Music.Current)

	openButton.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	-- Out of the way during races, like the shop and pass tiles; on phones it would sit under your steering thumb.
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local racing = player:GetAttribute("Racing") == true
		openButton.Visible = not racing
		if racing then
			setOpen(false)
		end
	end)
end

return Settings
