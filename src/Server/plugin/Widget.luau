local Widget = {}

export type PresetMode = "Play" | "Run" | "Multiplayer"

export type Preset = {
	id: string,
	name: string,
	mode: PresetMode,
	playerCount: number,
	argsJson: string,
}

export type Callbacks = {
	onSave: (Preset) -> (),
	onTest: (string) -> (),
	onDelete: (string) -> (),
	onRefresh: () -> (),
}

export type Controller = {
	gui: DockWidgetPluginGui,
	show: () -> (),
	setPresets: ({ Preset }) -> (),
	setStatus: (string, boolean?) -> (),
	clearSelection: () -> (),
}

type PresetButtonEntry = {
	id: string,
	button: TextButton,
}

local ROW_HEIGHT = 30
local MODE_OPTIONS = { "Play", "Run", "Multiplayer" }

local function createTextLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansSemibold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function createTextBox(parent: Instance, placeholderText: string, size: UDim2, position: UDim2): TextBox
	local textBox = Instance.new("TextBox")
	textBox.BackgroundColor3 = Color3.fromRGB(33, 37, 43)
	textBox.BorderSizePixel = 0
	textBox.ClearTextOnFocus = false
	textBox.Font = Enum.Font.Code
	textBox.PlaceholderColor3 = Color3.fromRGB(140, 147, 157)
	textBox.PlaceholderText = placeholderText
	textBox.Text = ""
	textBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	textBox.TextSize = 16
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Size = size
	textBox.Position = position
	textBox.Parent = parent
	return textBox
end

local function createButton(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansSemibold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.Size = size
	button.Position = position
	button.Parent = parent
	return button
end

function Widget.new(plugin: Plugin, callbacks: Callbacks): Controller
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		520,
		520,
		420,
		520
	)

	local gui = plugin:CreateDockWidgetPluginGui("StudioTestPresetPluginWidget", widgetInfo)
	gui.Title = "Studio Test Presets"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.BackgroundColor3 = Color3.fromRGB(22, 24, 29)
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local listPanel = Instance.new("Frame")
	listPanel.BackgroundColor3 = Color3.fromRGB(28, 31, 37)
	listPanel.BorderSizePixel = 0
	listPanel.Position = UDim2.new(0, 12, 0, 12)
	listPanel.Size = UDim2.new(0, 170, 1, -24)
	listPanel.Parent = root

	local listTitle = createTextLabel(listPanel, "Saved Presets", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 8))
	listTitle.TextSize = 18

	local refreshButton = createButton(
		listPanel,
		"Refresh",
		UDim2.new(1, -16, 0, ROW_HEIGHT),
		UDim2.new(0, 8, 0, 38),
		Color3.fromRGB(64, 112, 189)
	)
	local newPresetButton = createButton(
		listPanel,
		"New Preset",
		UDim2.new(1, -16, 0, ROW_HEIGHT),
		UDim2.new(0, 8, 0, 76),
		Color3.fromRGB(90, 102, 119)
	)
	local listSelectionLabel = createTextLabel(listPanel, "Selected: New Preset", UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 0, 114))
	listSelectionLabel.TextColor3 = Color3.fromRGB(173, 181, 191)
	listSelectionLabel.TextWrapped = true

	local presetList = Instance.new("ScrollingFrame")
	presetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	presetList.BackgroundColor3 = Color3.fromRGB(22, 24, 29)
	presetList.BorderSizePixel = 0
	presetList.CanvasSize = UDim2.new()
	presetList.Position = UDim2.new(0, 8, 0, 156)
	presetList.ScrollBarImageColor3 = Color3.fromRGB(90, 97, 110)
	presetList.Size = UDim2.new(1, -16, 1, -164)
	presetList.Parent = listPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = presetList

	local formPanel = Instance.new("Frame")
	formPanel.BackgroundColor3 = Color3.fromRGB(28, 31, 37)
	formPanel.BorderSizePixel = 0
	formPanel.Position = UDim2.new(0, 194, 0, 12)
	formPanel.Size = UDim2.new(1, -206, 1, -24)
	formPanel.Parent = root

	local formTitle = createTextLabel(formPanel, "Create / Edit", UDim2.new(1, -144, 0, 24), UDim2.new(0, 8, 0, 8))
	formTitle.TextSize = 18

	local selectionLabel = createTextLabel(formPanel, "Selected: New Preset", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 38))
	selectionLabel.TextColor3 = Color3.fromRGB(173, 181, 191)

	createTextLabel(formPanel, "Preset Name", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 72))
	local nameBox = createTextBox(formPanel, "Lobby Spawn", UDim2.new(1, -16, 0, ROW_HEIGHT), UDim2.new(0, 8, 0, 96))

	createTextLabel(formPanel, "Mode", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 136))
	local modeButtonWidth = 88
	local modeButtons = {}
	local selectedMode: PresetMode = "Play"

	local createModeButton do
		function createModeButton(mode: PresetMode, index: number)
			local button = createButton(
				formPanel,
				mode,
				UDim2.new(0, modeButtonWidth, 0, ROW_HEIGHT),
				UDim2.new(0, 8 + ((modeButtonWidth + 8) * (index - 1)), 0, 160),
				Color3.fromRGB(53, 94, 154)
			)
			modeButtons[mode] = button
		end
	end

	for index, modeName in MODE_OPTIONS do
		createModeButton(modeName :: PresetMode, index)
	end

	createTextLabel(formPanel, "Player Count", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 200))
	local playerCountBox = createTextBox(formPanel, "1", UDim2.new(0, 90, 0, ROW_HEIGHT), UDim2.new(0, 8, 0, 224))
	playerCountBox.Text = "1"

	createTextLabel(formPanel, "Args JSON", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 264))
	local argsBox = createTextBox(formPanel, '{"testName":"LobbySpawn"}', UDim2.new(1, -16, 0, 96), UDim2.new(0, 8, 0, 288))
	argsBox.MultiLine = true
	argsBox.TextYAlignment = Enum.TextYAlignment.Top

	local saveButton = createButton(
		formPanel,
		"Save Preset",
		UDim2.new(1, -16, 0, ROW_HEIGHT),
		UDim2.new(0, 8, 1, -76),
		Color3.fromRGB(66, 148, 94)
	)
	local testButton = createButton(
		formPanel,
		"Test Selected",
		UDim2.new(0, 128, 0, ROW_HEIGHT),
		UDim2.new(1, -136, 0, 8),
		Color3.fromRGB(64, 112, 189)
	)
	local deleteButton = createButton(
		formPanel,
		"Delete Preset",
		UDim2.new(1, -16, 0, ROW_HEIGHT),
		UDim2.new(0, 8, 1, -40),
		Color3.fromRGB(156, 67, 67)
	)

	local statusLabel = createTextLabel(formPanel, "", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 1, -104))
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = Color3.fromRGB(157, 218, 171)

	local selectedPresetId = ""
	local presetButtons: { PresetButtonEntry } = {}

	local function updateSelectedLabels(selectedName: string)
		local selectedText = string.format("Selected: %s", selectedName)
		selectionLabel.Text = selectedText
		listSelectionLabel.Text = selectedText
	end

	local function updatePresetButtonStyles()
		for _, entry in presetButtons do
			entry.button.BackgroundColor3 = if entry.id == selectedPresetId
				then Color3.fromRGB(64, 112, 189)
				else Color3.fromRGB(52, 58, 70)
		end
	end

	local function updateModeButtonStyles()
		for modeName, button in modeButtons do
			button.BackgroundColor3 = if modeName == selectedMode
				then Color3.fromRGB(53, 94, 154)
				else Color3.fromRGB(63, 70, 82)
		end

		local isMultiplayer = selectedMode == "Multiplayer"
		playerCountBox.TextEditable = isMultiplayer
		playerCountBox.BackgroundColor3 = if isMultiplayer
			then Color3.fromRGB(33, 37, 43)
			else Color3.fromRGB(42, 46, 54)
	end

	local function setStatus(message: string, isError: boolean?)
		statusLabel.Text = message
		statusLabel.TextColor3 = if isError
			then Color3.fromRGB(242, 121, 121)
			else Color3.fromRGB(157, 218, 171)
	end

	local function clearSelection()
		selectedPresetId = ""
		updateSelectedLabels("New Preset")
		nameBox.Text = ""
		selectedMode = "Play"
		playerCountBox.Text = "1"
		argsBox.Text = ""
		testButton.Visible = false
		deleteButton.Visible = false
		updateModeButtonStyles()
		updatePresetButtonStyles()
		setStatus("", false)
	end

	local function loadPreset(preset: Preset)
		selectedPresetId = preset.id
		updateSelectedLabels(preset.name)
		nameBox.Text = preset.name
		selectedMode = preset.mode
		playerCountBox.Text = tostring(preset.playerCount)
		argsBox.Text = preset.argsJson
		testButton.Visible = true
		deleteButton.Visible = true
		updateModeButtonStyles()
		updatePresetButtonStyles()
		setStatus("Loaded preset", false)
	end

	local function parsePlayerCount(): number?
		local parsedValue = tonumber(playerCountBox.Text)
		if not parsedValue then
			return nil
		end

		return math.floor(parsedValue)
	end

	local function makePresetFromForm(): Preset?
		local trimmedName = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		if trimmedName == "" then
			setStatus("Preset name is required.", true)
			return nil
		end

		local playerCount = parsePlayerCount() or 1
		if selectedMode == "Multiplayer" and (playerCount < 1 or playerCount > 8) then
			setStatus("Multiplayer presets require a player count between 1 and 8.", true)
			return nil
		end

		return {
			id = selectedPresetId,
			name = trimmedName,
			mode = selectedMode,
			playerCount = playerCount,
			argsJson = argsBox.Text,
		}
	end

	local function rebuildPresetButtons(presets: { Preset })
		for _, entry in presetButtons do
			entry.button:Destroy()
		end
		table.clear(presetButtons)

		for _, preset in presets do
			local button = createButton(
				presetList,
				string.format("%s (%s)", preset.name, preset.mode),
				UDim2.new(1, -6, 0, 38),
				UDim2.new(),
				Color3.fromRGB(52, 58, 70)
			)
			button.TextWrapped = true
			button.MouseButton1Click:Connect(function()
				loadPreset(preset)
			end)
			table.insert(presetButtons, {
				id = preset.id,
				button = button,
			})
		end

		updatePresetButtonStyles()
	end

	refreshButton.MouseButton1Click:Connect(callbacks.onRefresh)
	newPresetButton.MouseButton1Click:Connect(clearSelection)
	saveButton.MouseButton1Click:Connect(function()
		local preset = makePresetFromForm()
		if not preset then
			return
		end

		callbacks.onSave(preset)
	end)
	testButton.MouseButton1Click:Connect(function()
		if selectedPresetId == "" then
			setStatus("Select a preset before testing it.", true)
			return
		end

		callbacks.onTest(selectedPresetId)
	end)
	deleteButton.MouseButton1Click:Connect(function()
		if selectedPresetId == "" then
			setStatus("Select a preset before deleting it.", true)
			return
		end

		callbacks.onDelete(selectedPresetId)
	end)

	for modeName, button in modeButtons do
		button.MouseButton1Click:Connect(function()
			selectedMode = modeName :: PresetMode
			updateModeButtonStyles()
		end)
	end

	testButton.Visible = false
	deleteButton.Visible = false
	clearSelection()

	return {
		gui = gui,
		show = function()
			gui.Enabled = true
		end,
		setPresets = function(presets: { Preset })
			rebuildPresetButtons(presets)

			if selectedPresetId ~= "" then
				for _, preset in presets do
					if preset.id == selectedPresetId then
						loadPreset(preset)
						return
					end
				end

				clearSelection()
			end
		end,
		setStatus = setStatus,
		clearSelection = clearSelection,
	}
end

return Widget