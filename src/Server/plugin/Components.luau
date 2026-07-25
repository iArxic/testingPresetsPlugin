--[[
	Themed building blocks for the plugin widget.

	Every factory binds its colors through `Theme`, so nothing in `Widget` needs to
	name a `Color3` directly. Fallback colors match the plugin's previous dark
	palette and are only used when Studio's theme is unavailable.
]]

local Theme = require(script.Parent.Theme)

local Components = {}

local FALLBACK = {
	background = Color3.fromRGB(22, 24, 29),
	border = Color3.fromRGB(52, 58, 70),
	mainText = Color3.fromRGB(235, 235, 235),
	subText = Color3.fromRGB(173, 181, 191),
	dimText = Color3.fromRGB(140, 147, 157),
	brightText = Color3.fromRGB(255, 255, 255),
	inputBackground = Color3.fromRGB(33, 37, 43),
	inputBorder = Color3.fromRGB(60, 66, 78),
	button = Color3.fromRGB(63, 70, 82),
	buttonText = Color3.fromRGB(235, 235, 235),
	mainButton = Color3.fromRGB(53, 94, 154),
	item = Color3.fromRGB(52, 58, 70),
	errorText = Color3.fromRGB(242, 121, 121),
	infoText = Color3.fromRGB(157, 218, 171),
}

Components.FALLBACK = FALLBACK

local function makeFont(weight: Enum.FontWeight): Font
	local success, font = pcall(function()
		return Font.fromEnum(Enum.Font.BuilderSans)
	end)

	if not success then
		font = Font.fromEnum(Enum.Font.SourceSans)
	end

	font.Weight = weight
	return font
end

local REGULAR_FONT = makeFont(Enum.FontWeight.Regular)
local MEDIUM_FONT = makeFont(Enum.FontWeight.Medium)
local CODE_FONT = Font.fromEnum(Enum.Font.Code)

Components.REGULAR_FONT = REGULAR_FONT
Components.MEDIUM_FONT = MEDIUM_FONT
Components.CODE_FONT = CODE_FONT

export type ButtonController = {
	instance: TextButton,
	setEnabled: (boolean) -> (),
	setSelected: (boolean) -> (),
	setText: (string) -> (),
	onClick: (() -> ()) -> RBXScriptConnection,
}

export type LabelProps = {
	text: string?,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
	textSize: number?,
	font: Font?,
	color: Enum.StudioStyleGuideColor?,
	fallback: Color3?,
	wrapped: boolean?,
	automaticSize: Enum.AutomaticSize?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
}

export type TextBoxProps = {
	placeholder: string?,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
	textSize: number?,
	font: Font?,
	multiLine: boolean?,
	alignY: Enum.TextYAlignment?,
}

export type ButtonProps = {
	text: string?,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
	textSize: number?,
	font: Font?,
	color: Enum.StudioStyleGuideColor?,
	fallback: Color3?,
	textColor: Enum.StudioStyleGuideColor?,
	textFallback: Color3?,
	cornerRadius: number?,
}

function Components.padding(parent: Instance, px: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	padding.Parent = parent
	return padding
end

function Components.list(parent: Instance, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

--[[
	A transparent full-width container for one form field. Rows are ordered by
	`layoutOrder` inside a `UIListLayout`, so inserting a field never shifts the
	position of any other field.
]]
function Components.row(parent: Instance, height: number, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = layoutOrder
	row.Parent = parent
	return row
end

-- Returns the label plus a setter for its text color, so callers that need to
-- recolor it later (status, validation) do not add a second competing binding.
function Components.label(parent: Instance, props: LabelProps): (TextLabel, Theme.Setter)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = props.font or REGULAR_FONT
	label.Text = props.text or ""
	label.TextSize = props.textSize or 14
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
	label.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	label.TextWrapped = props.wrapped or false
	label.AutomaticSize = props.automaticSize or Enum.AutomaticSize.None
	label.Size = props.size or UDim2.new(1, 0, 0, 18)
	label.LayoutOrder = props.layoutOrder or 0

	if props.position then
		label.Position = props.position
	end

	label.Parent = parent

	local setTextColor = Theme.bind(
		label,
		"TextColor3",
		props.color or Enum.StudioStyleGuideColor.MainText,
		props.fallback or FALLBACK.mainText
	)

	return label, setTextColor
end

function Components.textBox(parent: Instance, props: TextBoxProps): TextBox
	local textBox = Instance.new("TextBox")
	textBox.BorderSizePixel = 0
	textBox.ClearTextOnFocus = false
	textBox.FontFace = props.font or REGULAR_FONT
	textBox.PlaceholderText = props.placeholder or ""
	textBox.Text = ""
	textBox.TextSize = props.textSize or 14
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	textBox.MultiLine = props.multiLine or false
	textBox.Size = props.size or UDim2.new(1, 0, 0, 28)
	textBox.LayoutOrder = props.layoutOrder or 0

	if props.position then
		textBox.Position = props.position
	end

	textBox.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = textBox

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = textBox

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = textBox

	Theme.bind(
		textBox,
		"BackgroundColor3",
		Enum.StudioStyleGuideColor.InputFieldBackground,
		FALLBACK.inputBackground
	)
	Theme.bind(textBox, "TextColor3", Enum.StudioStyleGuideColor.MainText, FALLBACK.mainText)
	Theme.bind(textBox, "PlaceholderColor3", Enum.StudioStyleGuideColor.DimmedText, FALLBACK.dimText)
	Theme.bind(stroke, "Color", Enum.StudioStyleGuideColor.InputFieldBorder, FALLBACK.inputBorder)

	return textBox
end

--[[
	A button whose background and text follow the Studio theme, including the
	hover, pressed, selected and disabled modifiers.

	`onClick` swallows clicks while the button is disabled, so callers never need
	to re-check enabled state in their handlers.
]]
function Components.button(parent: Instance, props: ButtonProps): ButtonController
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.FontFace = props.font or MEDIUM_FONT
	button.Text = props.text or ""
	button.TextSize = props.textSize or 14
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Size = props.size or UDim2.new(1, 0, 0, 28)
	button.LayoutOrder = props.layoutOrder or 0

	if props.position then
		button.Position = props.position
	end

	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, props.cornerRadius or 4)
	corner.Parent = button

	local setBackground = Theme.bind(
		button,
		"BackgroundColor3",
		props.color or Enum.StudioStyleGuideColor.Button,
		props.fallback or FALLBACK.button
	)
	local setTextColor = Theme.bind(
		button,
		"TextColor3",
		props.textColor or Enum.StudioStyleGuideColor.ButtonText,
		props.textFallback or FALLBACK.buttonText
	)

	local isEnabled = true
	local isSelected = false
	local isHovered = false
	local isPressed = false

	local function refresh()
		local modifier = Enum.StudioStyleGuideModifier.Default

		if not isEnabled then
			modifier = Enum.StudioStyleGuideModifier.Disabled
		elseif isPressed then
			modifier = Enum.StudioStyleGuideModifier.Pressed
		elseif isSelected then
			modifier = Enum.StudioStyleGuideModifier.Selected
		elseif isHovered then
			modifier = Enum.StudioStyleGuideModifier.Hover
		end

		setBackground(nil, modifier)
		setTextColor(nil, modifier)
	end

	button.MouseEnter:Connect(function()
		isHovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		refresh()
	end)
	button.MouseButton1Down:Connect(function()
		isPressed = true
		refresh()
	end)
	button.MouseButton1Up:Connect(function()
		isPressed = false
		refresh()
	end)

	refresh()

	return {
		instance = button,
		setEnabled = function(enabled: boolean)
			isEnabled = enabled
			refresh()
		end,
		setSelected = function(selected: boolean)
			isSelected = selected
			refresh()
		end,
		setText = function(text: string)
			button.Text = text
		end,
		onClick = function(callback: () -> ()): RBXScriptConnection
			return button.MouseButton1Click:Connect(function()
				if not isEnabled then
					return
				end

				callback()
			end)
		end,
	}
end

return Components
