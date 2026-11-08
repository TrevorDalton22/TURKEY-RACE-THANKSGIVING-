-- Big low-poly buttons for phones and tablets, around Roblox's jump button in the bottom right: Sprint (hold),
-- Slide, Use (showing the power-up you're holding) and Gobble. They replace ContextActionService's small default
-- buttons (see client/Controls); keyboards and gamepads are unchanged.
--
-- They're laid out from the jump button's size and place, worked out the way Roblox's PlayerModule does it, so
-- they never cover it: 70 px on small screens (the shorter side 500 px or less), 120 px on bigger ones.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local TouchButtons = {}

local connections: { RBXScriptConnection } = {}

-- A round button with an icon and a word under it. press(true) on touch down, press(false) when that touch
-- ends, even if the finger slid off the button first.
local function roundButton(gui: ScreenGui, icon: string, text: string, color: Color3, size: number, center: UDim2, press: (boolean) -> ())
	local b = Ui.button(gui, {
		Name = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		Text = "",
	})
	b:FindFirstChildOfClass("UIPadding"):Destroy()
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local image = Ui.icon(b, icon, { Position = UDim2.fromScale(0.16, 0.06), Size = UDim2.fromScale(0.68, 0.62) })
	Ui.label(b, { Position = UDim2.fromScale(0.08, 0.64), Size = UDim2.fromScale(0.84, 0.24), Text = text })
	local active: InputObject? = nil
	b.InputBegan:Connect(function(input)
		if active == nil and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			active = input
			press(true)
		end
	end)
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if active ~= nil and (input == active or input.UserInputType == active.UserInputType and input.UserInputType == Enum.UserInputType.MouseButton1) then
			active = nil
			press(false)
		end
	end))
	return b, image
end

function TouchButtons.start(controls)
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyTouchButtons"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")

	local buttons = {}
	local useImage: ImageLabel? = nil
	local function build()
		for _, b in buttons do
			b:Destroy()
		end
		table.clear(buttons)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		controls.setSprint(false)
		local camera = workspace.CurrentCamera
		local screen = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local small = math.min(screen.X, screen.Y) <= 500
		-- Roblox's jump button: its size, and its middle measured from the bottom right corner.
		local jump = if small then 70 else 120
		local jx, jy = jump * 1.5 - 10 - jump / 2, if small then jump + 20 - jump / 2 else jump * 1.75 - jump / 2
		local function at(dx: number, dy: number): UDim2
			return UDim2.new(1, -jx + dx * jump, 1, -jy + dy * jump)
		end
		local sprint = roundButton(gui, "lightning", "SPRINT", Ui.ORANGE, jump * 1.05, at(-1.3, 0.05), controls.setSprint)
		local slide = roundButton(gui, "butter", "SLIDE", Ui.BLUE, jump * 0.85, at(-1.1, -1.1), function(down)
			if down then
				controls.slide()
			end
		end)
		local use, image = roundButton(gui, "gift", "USE", Ui.GREEN, jump * 0.95, at(0, -1.25), function(down)
			if down then
				controls.use()
			end
		end)
		local gobble = roundButton(gui, "turkey", "GOBBLE", Ui.RED, jump * 0.7, at(-2.35, -0.55), function(down)
			if down then
				controls.gobble()
			end
		end)
		buttons = { sprint, slide, use, gobble }
		useImage = image
	end
	-- The Use button shows the power-up you're holding, and fades when there's none.
	local function refreshUse()
		local kind = player:GetAttribute("PowerUp")
		local icon = kind and Ui.POWER_ICONS[kind]
		local use = buttons[3]
		if useImage and use then
			Ui.setIcon(useImage, icon or "gift")
			useImage.ImageTransparency = if icon then 0 else 0.55
			use.BackgroundColor3 = if icon then Ui.GREEN else Ui.GREY
			if icon then
				Ui.pop(use, 0.7)
			end
		end
	end
	player:GetAttributeChangedSignal("PowerUp"):Connect(refreshUse)
	build()
	refreshUse()
	-- Turning the phone changes which layout fits.
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			build()
			refreshUse()
		end)
	end
end

return TouchButtons
