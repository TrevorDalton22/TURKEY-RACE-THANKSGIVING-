-- The game's look on every screen, matching the low-poly maps: panels and buttons with cut corners, a bevel and
-- faint facets (assets/ui/build_ui_art.py), chunky outlined text, buttons that bounce when touched, windows with a
-- colored header, low-poly icons, and the square menu tiles down the left side.
--
-- Panels are drawn by a grey 9-slice image tinted with the frame's BackgroundColor3, so code can keep setting
-- BackgroundColor3 and BackgroundTransparency as usual and the image follows. Each panel still has a Border stroke,
-- hidden until something sets its color (a highlight), and a UICorner.

local TweenService = game:GetService("TweenService")

local Ui = {}

-- The palette: warm browns and cream with fall colors, like the maps.
Ui.PANEL = Color3.fromRGB(92, 56, 34)
Ui.DARK = Color3.fromRGB(72, 42, 26)
Ui.WINDOW = Color3.fromRGB(104, 64, 38)
Ui.ORANGE = Color3.fromRGB(232, 124, 42)
Ui.CREAM = Color3.fromRGB(255, 238, 210)
Ui.GOLD = Color3.fromRGB(245, 182, 50)
Ui.GREEN = Color3.fromRGB(104, 168, 58)
Ui.BLUE = Color3.fromRGB(66, 140, 214)
Ui.PURPLE = Color3.fromRGB(140, 82, 200)
Ui.RED = Color3.fromRGB(196, 56, 42)
Ui.GREY = Color3.fromRGB(128, 118, 110)

-- The art, from assets/ui/export (uploaded 2026-11-07).
local PANEL_IMAGE = "rbxassetid://103574113001983" -- ui_panel.png
local WINDOW_IMAGE = "rbxassetid://120450639646642" -- ui_window.png
local ICON_IMAGE = "rbxassetid://107763113550500" -- ui_icons.png, 128 px cells
local SLICE = { [PANEL_IMAGE] = 28, [WINDOW_IMAGE] = 36 } -- 9-slice margins, of 256 px

-- Each icon's cell in the sheet, from ui_icons.json.
Ui.ICONS = {
	feather = { 0, 0 }, cart = { 1, 0 }, ticket = { 2, 0 }, gear = { 3, 0 }, lightning = { 4, 0 }, crown = { 5, 0 },
	gift = { 6, 0 }, trophy = { 7, 0 }, star = { 0, 1 }, lock = { 1, 1 }, check = { 2, 1 }, clock = { 3, 1 },
	turkey = { 4, 1 }, tag = { 5, 1 }, feathers_s = { 6, 1 }, feathers_m = { 7, 1 }, feathers_l = { 0, 2 },
	drumstick = { 1, 2 }, pie = { 2, 2 }, butter = { 3, 2 }, bomb = { 4, 2 }, potato = { 5, 2 }, tornado = { 6, 2 },
}
-- The icon for each power-up.
Ui.POWER_ICONS = {
	DrumstickDash = "drumstick", PieLauncher = "pie", ButterSlide = "butter",
	GobbleBomb = "bomb", MashedPotatoShield = "potato", CornTornado = "tornado",
}

local OUTLINE = Color3.fromRGB(46, 24, 12)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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

-- Rounded about as much as the image's corners are cut, so a highlight ring hugs them.
local function corner(parent: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 11)
	c.Parent = parent
end

-- The faceted panel image behind a frame, tinted with its BackgroundColor3. The frame itself stays see-through:
-- whatever transparency code gives the frame goes to the image instead. scale sizes the cut corners.
local function skin(frame: GuiObject, image: string, scale: number)
	local s = Instance.new("ImageLabel")
	s.Name = "Skin"
	s.BackgroundTransparency = 1
	s.Image = image
	s.ScaleType = Enum.ScaleType.Slice
	local m = SLICE[image]
	s.SliceCenter = Rect.new(m, m, 256 - m, 256 - m)
	s.SliceScale = scale
	s.Size = UDim2.fromScale(1, 1)
	s.ZIndex = 0
	s.Parent = frame
	local syncing = false
	local function sync()
		if syncing then
			return
		end
		syncing = true
		s.ImageColor3 = frame.BackgroundColor3
		if frame.BackgroundTransparency < 1 then
			s.ImageTransparency = frame.BackgroundTransparency
			frame.BackgroundTransparency = 1
		end
		syncing = false
	end
	frame:GetPropertyChangedSignal("BackgroundColor3"):Connect(sync)
	frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(sync)
	sync()
	return s
end

-- A highlight ring, hidden until code sets its color (a glowing status bar, a flashing stamina bar).
local function border(frame: GuiObject, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Transparency = 1
	stroke.Parent = frame
	stroke:GetPropertyChangedSignal("Color"):Connect(function()
		stroke.Transparency = 0
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

-- A low-poly icon from the sheet (see Ui.ICONS), filling its box.
function Ui.icon(parent: Instance, name: string, props): ImageLabel
	local cell = Ui.ICONS[name] or Ui.ICONS.star
	local i = Instance.new("ImageLabel")
	i.Name = "Icon"
	i.BackgroundTransparency = 1
	i.Image = ICON_IMAGE
	i.ImageRectSize = Vector2.new(128, 128)
	i.ImageRectOffset = Vector2.new(cell[1] * 128, cell[2] * 128)
	i.ScaleType = Enum.ScaleType.Fit
	return apply(i, parent, props or {})
end

-- Points an icon made by Ui.icon at a different picture.
function Ui.setIcon(icon: ImageLabel, name: string)
	local cell = Ui.ICONS[name] or Ui.ICONS.star
	icon.ImageRectOffset = Vector2.new(cell[1] * 128, cell[2] * 128)
end

-- A see-through panel: HUD pills and backdrops.
function Ui.panel(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.PANEL
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	corner(f)
	skin(f, PANEL_IMAGE, 0.45)
	apply(f, parent, props)
	border(f, 3)
	return f
end

-- A solid panel: windows, slots, boards and pills.
function Ui.card(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.DARK
	f.BorderSizePixel = 0
	corner(f)
	skin(f, PANEL_IMAGE, 0.55)
	apply(f, parent, props)
	border(f, 3)
	return f
end

-- A button with outlined text that grows a little under the mouse and squashes when pressed. Set .Text and
-- .TextColor3 as usual; they're drawn by an outlined label inside it.
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
	skin(b, PANEL_IMAGE, 0.45)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
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
-- order: its place in the stack from the top (1, 2, 3, ...). icon: a name from Ui.ICONS, or an emoji.
function Ui.menuButton(gui: ScreenGui, order: number, icon: string, text: string, color: Color3): TextButton
	local b = Ui.button(gui, {
		Name = "OpenButton",
		Position = UDim2.new(0, 14, 0.5, (order - 1) * 90),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = color,
		Text = "",
	})
	-- The icon and name place themselves, so no padding.
	local padding = b:FindFirstChildOfClass("UIPadding") :: UIPadding
	padding:Destroy()
	local area = { Position = UDim2.new(0.12, 0, 0.02, 0), Size = UDim2.new(0.76, 0, 0.64, 0) }
	if Ui.ICONS[icon] then
		Ui.icon(b, icon, area)
	else
		area.Text = icon
		area.TextStrokeTransparency = 1
		Ui.label(b, area)
	end
	Ui.label(b, {
		Position = UDim2.new(0, 4, 0.64, 0),
		Size = UDim2.new(1, -8, 0.28, 0),
		Text = text,
	})
	return b
end

-- A small red dot on a corner, for "something new here". Returns it hidden.
function Ui.badge(parent: GuiObject): Frame
	local dot = Ui.card(parent, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Ui.RED,
		ZIndex = 5,
		Visible = false,
	})
	dot:FindFirstChild("Skin").ZIndex = 5
	Ui.label(dot, { Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 6 })
	return dot
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
-- pop) or closes it. Opening a window closes any other. On short screens it grows to fill more of the screen.
function Ui.window(gui: ScreenGui, title: string, color: Color3, size: UDim2, maxSize: Vector2): (Frame, Frame, (boolean) -> ())
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = size
	window.BackgroundColor3 = Ui.WINDOW
	window.BorderSizePixel = 0
	window.Visible = false
	corner(window)
	skin(window, WINDOW_IMAGE, 0.8)
	window.Parent = gui
	border(window, 3)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = window
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y < 500 then
		window.Size = UDim2.fromScale(math.max(size.X.Scale, 0.96), math.max(size.Y.Scale, 0.92))
	end

	local header = Ui.card(window, {
		Name = "Header",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 50),
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
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = Ui.RED,
		Text = "X",
		ZIndex = 3,
	})
	close.Face.ZIndex = 3
	close.Skin.ZIndex = 3

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 16, 0, 72)
	body.Size = UDim2.new(1, -32, 1, -86)
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
-- on big monitors. Positions and sizes are designed for a window about 720 pixels tall. It also keeps the
-- screen clear of notches and rounded corners.
function Ui.autoScale(gui: ScreenGui)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
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
