-- The podium cutscene after a race. Everyone who raced watches the camera glide across the winners' podium in
-- the lobby (Workspace.Lobby.Podium) while 3rd, then 2nd, then after a drum roll 1st are revealed with name
-- tags, a fanfare and confetti. Then the camera comes back and the results board shows (client/Hud).
-- Players who didn't race still see the name tags pop up over the stands.
--
-- The camera moves from the invisible part Podium.CameraStart to Podium.CameraEnd, so the shot can be changed
-- by moving those two parts in Studio.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Audio = require(script.Parent.Audio)
local Music = require(script.Parent.Music)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Cutscene = {}

local MEDALS = {
	{ Icon = "🥇", Color = Color3.fromRGB(255, 205, 55) },
	{ Icon = "🥈", Color = Color3.fromRGB(210, 220, 235) },
	{ Icon = "🥉", Color = Color3.fromRGB(220, 140, 70) },
}
local CONFETTI = {
	Color3.fromRGB(235, 60, 55),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(90, 210, 90),
	Color3.fromRGB(70, 160, 245),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(240, 110, 200),
}
local DARK_TEXT = Color3.fromRGB(60, 32, 16)

-- When things happen, in seconds after the race ends. The cutscene ends at Config.PodiumSeconds.
local FADE = 0.35
local REVEAL_AT = { [3] = 1.3, [2] = 2.4 }
local DRUM_ROLL_AT = 3.1
local WINNER_AT = 4.9

local function nameTag(stand: BasePart, place: number, entry): (BillboardGui, UIScale)
	local medal = MEDALS[place]
	local tag = Instance.new("BillboardGui")
	tag.Name = "PodiumTag" .. place
	tag.Adornee = stand
	tag.ResetOnSpawn = false
	tag.Size = UDim2.new(12, 0, 4.6, 0) -- in studs, so it sits over the stand like a sign
	tag.StudsOffsetWorldSpace = Vector3.new(0, stand.Size.Y / 2 + Config.Movement.RideHeight + 6.5, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 400
	tag.Enabled = false

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = medal.Color
	card.BorderSizePixel = 0
	card.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK_TEXT
	stroke.Thickness = 3
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = card

	local detail = if entry.Time then Format.raceTime(entry.Time) elseif entry.Status == "DNF" then "Still racing!" else ""
	for _, line in {
		{ y = 0.04, h = 0.38, text = `{medal.Icon} {string.upper(Format.ordinal(place))}` },
		{ y = 0.42, h = 0.34, text = entry.Name },
		{ y = 0.74, h = 0.22, text = detail },
	} do
		Ui.label(card, {
			Position = UDim2.fromScale(0.05, line.y),
			Size = UDim2.fromScale(0.9, line.h),
			Text = line.text,
			TextColor3 = DARK_TEXT,
			TextStrokeTransparency = 1,
		})
	end
	tag.Parent = player:WaitForChild("PlayerGui")
	return tag, scale
end

local function confetti(position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	for _, color in CONFETTI do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/whiteCircle.png"
		emitter.Color = ColorSequence.new(color)
		emitter.Size = NumberSequence.new(0.35)
		-- Flattening and widening over and over looks like flakes tumbling as they fall.
		emitter.Squash = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.9),
			NumberSequenceKeypoint.new(0.4, -0.9),
			NumberSequenceKeypoint.new(0.6, 0.9),
			NumberSequenceKeypoint.new(0.8, -0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Lifetime = NumberRange.new(3, 4.5)
		emitter.Speed = NumberRange.new(26, 40)
		emitter.SpreadAngle = Vector2.new(55, 55)
		emitter.Acceleration = Vector3.new(0, -20, 0)
		emitter.Drag = 1.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-260, 260)
		emitter.Rate = 0
		emitter.Parent = attachment
		emitter:Emit(25)
	end
	Debris:AddItem(attachment, 6)
end

-- The camera shot, letterbox and fades for players who raced. Returns a function that sets the caption
-- under the picture and one that ends it.
local function cinematic(podium: Instance): ((string) -> (), () -> ())
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "TurkeyCutscene"
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 20

	local function bar(top: boolean): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, if top then 1 else 0)
		frame.Position = UDim2.fromScale(0, if top then 0 else 1)
		frame.Size = UDim2.fromScale(1, 0.12)
		frame.Parent = overlay
		return frame
	end
	local topBar, bottomBar = bar(true), bar(false)
	Ui.label(topBar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.8, 0.5),
		Text = `🏁 {ReplicatedStorage:GetAttribute("Map") or "Race"} 🏁`,
		TextColor3 = Ui.ORANGE,
	})
	local caption = Ui.label(bottomBar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.55),
		Text = "",
	})
	local fade = Instance.new("Frame")
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 5
	fade.Parent = overlay
	overlay.Parent = player:WaitForChild("PlayerGui")

	local function tween(instance: Instance, seconds: number, goal)
		local t = TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		t:Play()
		return t
	end

	-- Fade out of the race...
	Music.duck(true)
	tween(fade, FADE, { BackgroundTransparency = 0 }).Completed:Wait()

	-- ...and in on the podium, with everything else on screen hidden and movement off.
	local hidden = {}
	for _, gui in player.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui ~= overlay and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	local controls
	pcall(function()
		controls = (require :: any)(player.PlayerScripts:FindFirstChild("PlayerModule")):GetControls()
		controls:Disable()
	end)

	local camera = workspace.CurrentCamera
	local stand = podium:FindFirstChild("Stand1") :: BasePart
	local startPart, endPart = podium:FindFirstChild("CameraStart"), podium:FindFirstChild("CameraEnd")
	local from, to
	if startPart and endPart then
		from, to = (startPart :: BasePart).CFrame, (endPart :: BasePart).CFrame
	else
		local focus = stand.Position + Vector3.new(0, 6, 0)
		local front = stand.CFrame.LookVector
		from = CFrame.lookAt(focus + front * 40 + Vector3.new(0, 14, 0), focus)
		to = CFrame.lookAt(focus + front * 24 + Vector3.new(0, 6, 0), focus)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local shotStarted = os.clock()
	local shotLength = Config.PodiumSeconds - FADE * 2
	RunService:BindToRenderStep("TurkeyPodiumCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local t = math.clamp((os.clock() - shotStarted) / shotLength, 0, 1)
		camera.CFrame = from:Lerp(to, TweenService:GetValue(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
	end)
	topBar.Position = UDim2.fromScale(0, 0.12)
	bottomBar.Position = UDim2.fromScale(0, 0.88)
	tween(fade, FADE, { BackgroundTransparency = 1 })

	local function setCaption(text: string)
		caption.Text = text
	end

	local function finish()
		tween(fade, FADE, { BackgroundTransparency = 0 }).Completed:Wait()
		RunService:UnbindFromRenderStep("TurkeyPodiumCamera")
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
		if controls then
			controls:Enable()
		end
		Music.duck(false)
		topBar.Visible = false
		bottomBar.Visible = false
		tween(fade, FADE, { BackgroundTransparency = 1 }).Completed:Wait()
		overlay:Destroy()
	end
	return setCaption, finish
end

-- top: the podium's results entries by place. raced: whether this player was in the race.
local function play(podium: Instance, top, raced: boolean)
	local started = os.clock()
	local function at(seconds: number)
		local wait = started + seconds - os.clock()
		if wait > 0 then
			task.wait(wait)
		end
	end
	-- Sounds play flat for the racers watching the cutscene, and from the podium for anyone in the lobby.
	local stand1 = podium:FindFirstChild("Stand1") :: BasePart
	local function sound(name: string)
		Audio.play(name, if raced then nil else stand1.Position)
	end

	local tags = {}
	for place, entry in top do
		local stand = podium:FindFirstChild("Stand" .. place) :: BasePart?
		if stand then
			local tag, scale = nameTag(stand, place, entry)
			tags[place] = { tag = tag, scale = scale }
		end
	end
	local function reveal(place: number)
		local tag = tags[place]
		if tag then
			tag.tag.Enabled = true
			TweenService:Create(tag.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end

	local setCaption, finish
	if raced then
		setCaption, finish = cinematic(podium)
	end

	for _, place in { 3, 2 } do
		at(REVEAL_AT[place])
		if top[place] then
			reveal(place)
			sound("Reveal")
		end
	end
	at(DRUM_ROLL_AT)
	local drumRoll = if raced then Audio.play("DrumRoll") else nil
	at(WINNER_AT)
	if drumRoll then
		drumRoll:Stop()
	end
	reveal(1)
	sound("Fanfare")
	-- A burst over the winner, then one over each of the other stands.
	local up = Vector3.new(0, stand1.Size.Y / 2 + 2, 0)
	confetti(stand1.Position + up)
	task.delay(0.5, confetti, stand1.Position - stand1.CFrame.RightVector * 11 + up)
	task.delay(0.8, confetti, stand1.Position + stand1.CFrame.RightVector * 11 + up)
	if setCaption then
		setCaption(`🏆 {top[1].Name} WINS! 🏆`)
	end

	if finish then
		at(Config.PodiumSeconds - FADE)
		finish()
	end
	-- The tags stay up over the winners until the next countdown can start.
	at(Config.ResultsSeconds)
	for _, tag in tags do
		tag.tag:Destroy()
	end
end

function Cutscene.start()
	Remotes.Results.OnClientEvent:Connect(function(results)
		local lobby = workspace:FindFirstChild("Lobby")
		local podium = lobby and lobby:FindFirstChild("Podium")
		if not podium or not podium:FindFirstChild("Stand1") then
			return
		end
		local top, raced = {}, false
		for _, entry in results do
			if entry.Podium then
				top[entry.Podium] = entry
			end
			if entry.UserId == player.UserId then
				raced = true
			end
		end
		if top[1] then
			task.spawn(play, podium, top, raced)
		end
	end)
end

-- Whether this player gets the cutscene for these results (Hud holds the results board back until it ends).
function Cutscene.plays(results): boolean
	local lobby = workspace:FindFirstChild("Lobby")
	local podium = lobby and lobby:FindFirstChild("Podium")
	if not podium or not podium:FindFirstChild("Stand1") then
		return false
	end
	local raced, winner = false, false
	for _, entry in results do
		raced = raced or entry.UserId == player.UserId
		winner = winner or entry.Podium == 1
	end
	return raced and winner
end

return Cutscene
