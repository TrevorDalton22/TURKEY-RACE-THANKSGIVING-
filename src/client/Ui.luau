-- Shared look for the HUD and shop: brown panels, orange accents, chunky text.

local Ui = {}

Ui.PANEL = Color3.fromRGB(60, 35, 20)
Ui.ORANGE = Color3.fromRGB(255, 150, 40)

local function apply(instance: any, parent: Instance, props): any
	for k, v in props do
		instance[k] = v
	end
	instance.Parent = parent
	return instance
end

local function text(instance: TextLabel | TextButton)
	instance.Font = Enum.Font.FredokaOne
	instance.TextColor3 = Color3.new(1, 1, 1)
	instance.TextStrokeTransparency = 0.4
	instance.TextScaled = true
end

function Ui.label(parent: Instance, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	text(l)
	return apply(l, parent, props)
end

function Ui.panel(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.PANEL
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	Instance.new("UICorner").Parent = f
	return apply(f, parent, props)
end

function Ui.button(parent: Instance, props): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Ui.ORANGE
	b.BorderSizePixel = 0
	text(b)
	Instance.new("UICorner").Parent = b
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = b
	return apply(b, parent, props)
end

return Ui
