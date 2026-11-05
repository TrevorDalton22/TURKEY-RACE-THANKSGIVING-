-- The game's look on every screen: chunky outlined text, rounded panels and cards, shaded buttons that bounce
-- when touched, windows with a colored header, and the square menu tiles down the left side.

local TweenService = game:GetService("TweenService")

local Ui = {}

-- The palette: warm browns with bright cartoon accents.
Ui.PANEL = Color3.fromRGB(60, 35, 20)
Ui.DARK = Color3.fromRGB(42, 24, 13)
Ui.WINDOW = Color3.fromRGB(64, 38, 21)
Ui.ORANGE = Color3.fromRGB(255, 150, 40)
Ui.CREAM = Color3.fromRGB(255, 236, 200)
Ui.GOLD = Color3.fromRGB(255, 205, 60)
Ui.GREEN = Color3.fromRGB(85, 200, 85)
Ui.BLUE = Color3.fromRGB(70, 160, 240)
Ui.PURPLE = Color3.fromRGB(155, 85, 215)
Ui.RED = Color3.fromRGB(225, 60, 50)
Ui.GREY = Color3.fromRGB(125, 115, 110)

local OUTLINE = Color3.fromRGB(40, 22, 12)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- Lighter at the top, darker at the bottom; a UIGradient multiplies, so this shades any color.
local SHADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))

-- The same color, darker (for borders).
function Ui.darker(color: Color3, amount: number?): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.15), v * (1 - (amount or 0.45)))
end

local function apply(instance: any, parent: Instance, props): any
	for k, v in props do
		instance[k] = v
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 10)
	c.Parent = parent
end

local function shade(parent: Instance)
	local gradient = Instance.new("UIGradient")
	gradient.Color = SHADE
	gradient.Rotation = 90
	gradient.Parent = parent
end

-- A border that stays a darker shade of the frame's color, even when the color changes later.
local function border(frame: GuiObject, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = Ui.darker(frame.BackgroundColor3)
	stroke.Parent = frame
	frame:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		stroke.Color = Ui.darker(frame.BackgroundColor3)
	end)
	return stroke
end

-- A thick dark outline around some text, instead of Roblox's thin built-in one.
function Ui.outline(text: TextLabel | TextButton, thickness: number?): UIStroke
	text.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = OUTLINE
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = text
	return stroke
end

-- Text that fills its box, outlined unless props sets TextStrokeTransparency = 1 (for dark text on light
-- backgrounds, and emoji).
function Ui.label(parent: Instance, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	local plain = props.TextStrokeTransparency == 1
	apply(l, parent, props)
	if not plain then
		Ui.outline(l)
	end
	return l
end

-- A plain rounded background.
function Ui.panel(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.PANEL
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	corner(f)
	return apply(f, parent, props)
end

-- A solid panel with a dark border and a soft shade: windows, slots, boards and pills.
function Ui.card(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.DARK
	f.BorderSizePixel = 0
	corner(f, UDim.new(0, 12))
	shade(f)
	apply(f, parent, props)
	border(f, 3)
	return f
end

-- A shaded button with a border and outlined text that grows a little under the mouse and squashes when
-- pressed. Set .Text and .TextColor3 as usual; they're drawn by an outlined label inside it.
function Ui.button(parent: Instance, props): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Ui.ORANGE
	b.BorderSizePixel = 0
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextTransparency = 1
	corner(b)
	shade(b)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.16, 0)
	padding.PaddingBottom = UDim.new(0.16, 0)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = b

	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromScale(1, 1)
	face.Font = Enum.Font.FredokaOne
	face.TextScaled = true
	face.Parent = b
	Ui.outline(face)

	apply(b, parent, props)
	b.TextTransparency = 1
	face.Text = b.Text
	face.TextColor3 = b.TextColor3
	b:GetPropertyChangedSignal("Text"):Connect(function()
		face.Text = b.Text
	end)
	b:GetPropertyChangedSignal("TextColor3"):Connect(function()
		face.TextColor3 = b.TextColor3
	end)
	border(b, 3)

	local scale = Instance.new("UIScale")
	scale.Parent = b
	local hovering = false
	local function to(size: number)
		TweenService:Create(scale, QUICK, { Scale = size }):Play()
	end
	b.MouseEnter:Connect(function()
		hovering = true
		to(1.06)
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(if hovering then 1.06 else 1)
	end)
	return b
end

-- A square menu tile down the left side of the screen, with a big icon and its name under it.
-- order: its place in the stack from the top (1, 2, 3, ...).
function Ui.menuButton(gui: ScreenGui, order: number, icon: string, text: string, color: Color3): TextButton
	local b = Ui.button(gui, {
		Name = "OpenButton",
		Position = UDim2.new(0, 14, 0.5, (order - 1) * 86),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = color,
		Text = "",
	})
	-- The icon and name place themselves, so no padding, and rounder corners for a tile.
	local padding = b:FindFirstChildOfClass("UIPadding") :: UIPadding
	padding:Destroy()
	local round = b:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(0, 16)
	Ui.label(b, {
		Position = UDim2.new(0.15, 0, 0.06, 0),
		Size = UDim2.new(0.7, 0, 0.56, 0),
		Text = icon,
		TextStrokeTransparency = 1,
	})
	Ui.label(b, {
		Position = UDim2.new(0, 4, 0.62, 0),
		Size = UDim2.new(1, -8, 0.3, 0),
		Text = text,
	})
	return b
end

-- Scales something up from small with a little bounce (things appearing).
function Ui.pop(object: GuiObject, from: number?)
	local scale = object:FindFirstChild("Pop") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "Pop"
		scale.Parent = object
	end
	scale.Scale = from or 0.6
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

-- Every window's open/close function, so opening one closes the others.
local windows: { [Frame]: (boolean) -> () } = {}

-- A window in the middle of the screen: a colored header with the title, a close button on the corner and
-- a body for the contents. Returns the window (named Window), its body, and a function that opens (with a
-- pop) or closes it. Opening a window closes any other.
function Ui.window(gui: ScreenGui, title: string, color: Color3, size: UDim2, maxSize: Vector2): (Frame, Frame, (boolean) -> ())
	local window = Ui.card(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size,
		BackgroundColor3 = Ui.WINDOW,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = window

	local header = Ui.card(window, {
		Name = "Header",
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 0, 50),
		BackgroundColor3 = color,
	})
	local titleLabel = Ui.label(header, {
		Name = "Title",
		Position = UDim2.new(0, 16, 0, 7),
		Size = UDim2.new(1, -90, 1, -14),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	titleLabel.Outline.Thickness = 3

	local close = Ui.button(window, {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Ui.RED,
		Text = "X",
		ZIndex = 3,
	})
	close.Face.ZIndex = 3

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 14, 0, 70)
	body.Size = UDim2.new(1, -28, 1, -82)
	body.Parent = window

	local function setOpen(open: boolean)
		if open then
			for other, closeOther in windows do
				if other ~= window and other.Visible then
					closeOther(false)
				end
			end
			window.Visible = true
			Ui.pop(window, 0.85)
		else
			window.Visible = false
		end
	end
	windows[window] = setOpen
	close.Activated:Connect(function()
		setOpen(false)
	end)
	return window, body, setOpen
end

-- How much autoScale is scaling the screen `object` is on. Divide AbsoluteSize and AbsolutePosition by this
-- to get the units that sizes, positions and CanvasPosition are set in.
function Ui.scaleOf(object: Instance): number
	local gui = object:FindFirstAncestorWhichIsA("LayerCollector")
	local scale = gui and gui:FindFirstChild("AutoScale")
	return if scale and scale:IsA("UIScale") then scale.Scale else 1
end

-- Scales a whole screen of UI with the height of the game window, so it fits small phones and isn't tiny
-- on big monitors. Positions and sizes are designed for a window about 720 pixels tall.
function Ui.autoScale(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Parent = gui
	local connection: RBXScriptConnection?
	local function watch()
		local camera = workspace.CurrentCamera
		if connection then
			connection:Disconnect()
		end
		if not camera then
			return
		end
		local function update()
			scale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.6, 1.3)
		end
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

return Ui
