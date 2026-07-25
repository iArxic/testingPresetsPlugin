local Components = require(script.Parent.Components)
local PresetArgs = require(script.Parent.PresetArgs)
local PresetStore = require(script.Parent.PresetStore)
local Theme = require(script.Parent.Theme)

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
	destroy: () -> (),
}

type PresetRow = {
	id: string,
	controller: Components.ButtonController,
}

local LIST_WIDTH = 194
local PANE_PADDING = 10
local CONTROL_HEIGHT = 28
local LABEL_HEIGHT = 18
local FIELD_GAP = 4
local MIN_PLAYERS = 1
local MAX_PLAYERS = 8
local VALIDATION_DELAY = 0.15

local FALLBACK = Components.FALLBACK

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
	return trimmed
end

-- Decode errors arrive as "Script:12: message". The location is noise in a widget.
local function cleanErrorMessage(message: string): string
	local cleaned = string.gsub(tostring(message), "^.-:%d+:%s*", "")
	return cleaned
end

local function describeArgsType(value: any): string
	if value == nil then
		return "nil"
	end

	local valueType = type(value)
	if valueType ~= "table" then
		return valueType
	end

	if #value > 0 then
		return "array"
	end

	if next(value) == nil then
		return "empty table"
	end

	return "object"
end

function Widget.new(plugin: Plugin, callbacks: Callbacks): Controller
	local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 560, 560, 380, 420)

	local gui = plugin:CreateDockWidgetPluginGui("StudioTestPresetPluginWidget", widgetInfo)
	gui.Title = "Studio Test Presets"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	Theme.bind(root, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground, FALLBACK.background)

	----------------------------------------------------------------------------
	-- Preset list pane
	----------------------------------------------------------------------------

	local listPane = Instance.new("Frame")
	listPane.BackgroundTransparency = 1
	listPane.Size = UDim2.new(0, LIST_WIDTH, 1, 0)
	listPane.Parent = root
	Components.padding(listPane, PANE_PADDING)

	Components.label(listPane, {
		text = "Presets",
		font = Components.MEDIUM_FONT,
		textSize = 15,
		size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
	})

	local searchBox = Components.textBox(listPane, {
		placeholder = "Search presets",
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.new(0, 0, 0, 26),
		textSize = 13,
	})

	local newPresetButton = Components.button(listPane, {
		text = "New Preset",
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.new(0, 0, 0, 60),
		textSize = 13,
	})

	local refreshButton = Components.button(listPane, {
		text = "Refresh",
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.new(0, 0, 0, 92),
		textSize = 13,
	})

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.CanvasSize = UDim2.new()
	listScroll.Position = UDim2.new(0, 0, 0, 128)
	listScroll.Size = UDim2.new(1, 0, 1, -128)
	listScroll.ScrollBarThickness = 6
	listScroll.Parent = listPane
	Theme.bind(listScroll, "ScrollBarImageColor3", Enum.StudioStyleGuideColor.ScrollBar, FALLBACK.border)
	Components.list(listScroll, 4)

	local emptyListLabel = Components.label(listScroll, {
		text = "",
		textSize = 13,
		wrapped = true,
		size = UDim2.new(1, -6, 0, 34),
		color = Enum.StudioStyleGuideColor.DimmedText,
		fallback = FALLBACK.dimText,
	})
	emptyListLabel.Visible = false
	emptyListLabel.LayoutOrder = 1000000

	local divider = Instance.new("Frame")
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, LIST_WIDTH, 0, 0)
	divider.Size = UDim2.new(0, 1, 1, 0)
	divider.Parent = root
	Theme.bind(divider, "BackgroundColor3", Enum.StudioStyleGuideColor.Border, FALLBACK.border)

	----------------------------------------------------------------------------
	-- Form pane
	----------------------------------------------------------------------------

	local formPane = Instance.new("Frame")
	formPane.BackgroundTransparency = 1
	formPane.Position = UDim2.new(0, LIST_WIDTH + 1, 0, 0)
	formPane.Size = UDim2.new(1, -(LIST_WIDTH + 1), 1, 0)
	formPane.Parent = root
	Components.padding(formPane, PANE_PADDING)

	local selectionLabel = Components.label(formPane, {
		text = "New Preset",
		font = Components.MEDIUM_FONT,
		textSize = 15,
		size = UDim2.new(1, -120, 0, 26),
	})

	local runButton = Components.button(formPane, {
		text = "Run Test",
		size = UDim2.new(0, 112, 0, 26),
		position = UDim2.new(1, -112, 0, 0),
		textSize = 13,
		color = Enum.StudioStyleGuideColor.MainButton,
		fallback = FALLBACK.mainButton,
		textColor = Enum.StudioStyleGuideColor.BrightText,
		textFallback = FALLBACK.brightText,
	})
	runButton.instance.Visible = false

	local formScroll = Instance.new("ScrollingFrame")
	formScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	formScroll.BackgroundTransparency = 1
	formScroll.BorderSizePixel = 0
	formScroll.CanvasSize = UDim2.new()
	formScroll.Position = UDim2.new(0, 0, 0, 36)
	formScroll.Size = UDim2.new(1, 0, 1, -122)
	formScroll.ScrollBarThickness = 6
	formScroll.Parent = formPane
	Theme.bind(formScroll, "ScrollBarImageColor3", Enum.StudioStyleGuideColor.ScrollBar, FALLBACK.border)
	Components.list(formScroll, 10)

	-- Each field is a row in the list layout, so inserting one never moves another.
	local function fieldRow(order: number, labelText: string, controlHeight: number): (Frame, number)
		local row = Components.row(formScroll, LABEL_HEIGHT + FIELD_GAP + controlHeight, order)
		Components.label(row, {
			text = labelText,
			textSize = 13,
			size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
			color = Enum.StudioStyleGuideColor.SubText,
			fallback = FALLBACK.subText,
		})
		return row, LABEL_HEIGHT + FIELD_GAP
	end

	local nameRow, nameOffset = fieldRow(1, "Preset Name", CONTROL_HEIGHT)
	local nameBox = Components.textBox(nameRow, {
		placeholder = "Lobby Spawn",
		size = UDim2.new(1, -6, 0, CONTROL_HEIGHT),
		position = UDim2.new(0, 0, 0, nameOffset),
	})

	local modeRow, modeOffset = fieldRow(2, "Mode", CONTROL_HEIGHT)
	local modeHolder = Instance.new("Frame")
	modeHolder.BackgroundTransparency = 1
	modeHolder.Position = UDim2.new(0, 0, 0, modeOffset)
	modeHolder.Size = UDim2.new(1, -6, 0, CONTROL_HEIGHT)
	modeHolder.Parent = modeRow

	local modeLayout = Components.list(modeHolder, 6)
	modeLayout.FillDirection = Enum.FillDirection.Horizontal

	local modeButtons: { [string]: Components.ButtonController } = {}
	for index, modeName in { "Play", "Run", "Multiplayer" } do
		modeButtons[modeName] = Components.button(modeHolder, {
			text = modeName,
			size = UDim2.new(1 / 3, -4, 1, 0),
			layoutOrder = index,
			textSize = 13,
		})
	end

	local playersRow, playersOffset = fieldRow(3, "Player Count", CONTROL_HEIGHT)
	local decreaseButton = Components.button(playersRow, {
		text = "-",
		size = UDim2.new(0, CONTROL_HEIGHT, 0, CONTROL_HEIGHT),
		position = UDim2.new(0, 0, 0, playersOffset),
		textSize = 16,
	})
	local playerCountLabel = Components.label(playersRow, {
		text = "1",
		size = UDim2.new(0, 44, 0, CONTROL_HEIGHT),
		position = UDim2.new(0, CONTROL_HEIGHT + 4, 0, playersOffset),
		alignX = Enum.TextXAlignment.Center,
		font = Components.MEDIUM_FONT,
		textSize = 15,
	})
	local increaseButton = Components.button(playersRow, {
		text = "+",
		size = UDim2.new(0, CONTROL_HEIGHT, 0, CONTROL_HEIGHT),
		position = UDim2.new(0, CONTROL_HEIGHT + 52, 0, playersOffset),
		textSize = 16,
	})
	local playersHintLabel = Components.label(playersRow, {
		text = "Multiplayer only",
		textSize = 12,
		size = UDim2.new(1, -(CONTROL_HEIGHT * 2 + 60), 0, CONTROL_HEIGHT),
		position = UDim2.new(0, CONTROL_HEIGHT * 2 + 60, 0, playersOffset),
		color = Enum.StudioStyleGuideColor.DimmedText,
		fallback = FALLBACK.dimText,
	})

	local argsRow, argsOffset = fieldRow(4, "Args JSON", 92 + FIELD_GAP + 16)
	local argsBox = Components.textBox(argsRow, {
		placeholder = '{"testName":"LobbySpawn","timeout":15}',
		size = UDim2.new(1, -6, 0, 92),
		position = UDim2.new(0, 0, 0, argsOffset),
		multiLine = true,
		font = Components.CODE_FONT,
		textSize = 13,
		alignY = Enum.TextYAlignment.Top,
	})
	local validationLabel, setValidationColor = Components.label(argsRow, {
		text = "",
		textSize = 12,
		size = UDim2.new(1, -6, 0, 16),
		position = UDim2.new(0, 0, 0, argsOffset + 92 + FIELD_GAP),
		color = Enum.StudioStyleGuideColor.DimmedText,
		fallback = FALLBACK.dimText,
	})

	----------------------------------------------------------------------------
	-- Status and actions
	----------------------------------------------------------------------------

	local statusLabel, setStatusColor = Components.label(formPane, {
		text = "",
		textSize = 13,
		wrapped = true,
		automaticSize = Enum.AutomaticSize.Y,
		size = UDim2.new(1, 0, 0, 0),
		alignY = Enum.TextYAlignment.Bottom,
		color = Enum.StudioStyleGuideColor.InfoText,
		fallback = FALLBACK.infoText,
	})
	statusLabel.AnchorPoint = Vector2.new(0, 1)
	statusLabel.Position = UDim2.new(0, 0, 1, -38)
	statusLabel.BackgroundTransparency = 0
	-- Opaque so a long error painting upward covers the form instead of blending.
	Theme.bind(statusLabel, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground, FALLBACK.background)

	-- Bounded so a long decode error cannot grow over the whole form.
	local statusConstraint = Instance.new("UISizeConstraint")
	statusConstraint.MaxSize = Vector2.new(math.huge, 96)
	statusConstraint.Parent = statusLabel

	local actionBar = Instance.new("Frame")
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.BackgroundTransparency = 1
	actionBar.Position = UDim2.new(0, 0, 1, 0)
	actionBar.Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT)
	actionBar.Parent = formPane

	local saveButton = Components.button(actionBar, {
		text = "Save Preset",
		size = UDim2.new(1, -124, 1, 0),
		color = Enum.StudioStyleGuideColor.MainButton,
		fallback = FALLBACK.mainButton,
		textColor = Enum.StudioStyleGuideColor.BrightText,
		textFallback = FALLBACK.brightText,
	})
	local deleteButton = Components.button(actionBar, {
		text = "Delete",
		size = UDim2.new(0, 116, 1, 0),
		position = UDim2.new(1, -116, 0, 0),
		textColor = Enum.StudioStyleGuideColor.ErrorText,
		textFallback = FALLBACK.errorText,
	})
	deleteButton.instance.Visible = false

	----------------------------------------------------------------------------
	-- Delete confirmation overlay
	----------------------------------------------------------------------------

	local overlay = Instance.new("Frame")
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = root
	Theme.bind(overlay, "BackgroundColor3", Enum.StudioStyleGuideColor.Dark, Color3.fromRGB(0, 0, 0))

	local dialog = Instance.new("Frame")
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.BorderSizePixel = 0
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.new(1, -60, 0, 132)
	dialog.ZIndex = 11
	dialog.Parent = overlay
	Theme.bind(dialog, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground, FALLBACK.background)

	local dialogConstraint = Instance.new("UISizeConstraint")
	dialogConstraint.MaxSize = Vector2.new(320, math.huge)
	dialogConstraint.Parent = dialog

	local dialogCorner = Instance.new("UICorner")
	dialogCorner.CornerRadius = UDim.new(0, 6)
	dialogCorner.Parent = dialog

	local dialogStroke = Instance.new("UIStroke")
	dialogStroke.Thickness = 1
	dialogStroke.Parent = dialog
	Theme.bind(dialogStroke, "Color", Enum.StudioStyleGuideColor.Border, FALLBACK.border)

	Components.padding(dialog, 14)

	local dialogLabel = Components.label(dialog, {
		text = "",
		textSize = 14,
		wrapped = true,
		size = UDim2.new(1, 0, 0, 60),
		alignY = Enum.TextYAlignment.Top,
	})
	dialogLabel.ZIndex = 12

	local cancelButton = Components.button(dialog, {
		text = "Cancel",
		size = UDim2.new(0.5, -4, 0, CONTROL_HEIGHT),
		position = UDim2.new(0, 0, 1, -CONTROL_HEIGHT),
		textSize = 13,
	})
	cancelButton.instance.ZIndex = 12

	local confirmButton = Components.button(dialog, {
		text = "Delete",
		size = UDim2.new(0.5, -4, 0, CONTROL_HEIGHT),
		position = UDim2.new(0.5, 4, 1, -CONTROL_HEIGHT),
		textSize = 13,
		color = Enum.StudioStyleGuideColor.DialogMainButton,
		fallback = FALLBACK.mainButton,
		textColor = Enum.StudioStyleGuideColor.BrightText,
		textFallback = FALLBACK.brightText,
	})
	confirmButton.instance.ZIndex = 12

	----------------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------------

	local allPresets: { Preset } = {}
	local presetRows: { PresetRow } = {}
	local selectedPresetId = ""
	local selectedMode: PresetMode = "Play"
	local playerCount = MIN_PLAYERS
	local validationToken = 0
	local isDestroyed = false

	local function setStatus(message: string, isError: boolean?)
		statusLabel.Text = message
		statusLabel.BackgroundTransparency = if message == "" then 1 else 0
		setStatusColor(
			if isError then Enum.StudioStyleGuideColor.ErrorText else Enum.StudioStyleGuideColor.InfoText,
			nil
		)
	end

	local function setValidation(message: string, isError: boolean)
		validationLabel.Text = message
		setValidationColor(
			if isError then Enum.StudioStyleGuideColor.ErrorText else Enum.StudioStyleGuideColor.DimmedText,
			nil
		)
	end

	local function validateArgs()
		if trim(argsBox.Text) == "" then
			setValidation("no args - the test receives nil", false)
			return
		end

		local success, value = PresetArgs.decode(argsBox.Text)
		if success then
			setValidation(string.format("valid - %s", describeArgsType(value)), false)
		else
			setValidation(string.format("invalid: %s", cleanErrorMessage(value)), true)
		end
	end

	local function scheduleValidation()
		validationToken += 1
		local token = validationToken

		task.delay(VALIDATION_DELAY, function()
			if isDestroyed or token ~= validationToken then
				return
			end

			validateArgs()
		end)
	end

	local function updateModeButtons()
		for modeName, controller in modeButtons do
			controller.setSelected(modeName == selectedMode)
		end

		local isMultiplayer = selectedMode == "Multiplayer"
		decreaseButton.setEnabled(isMultiplayer)
		increaseButton.setEnabled(isMultiplayer)
		playersHintLabel.Visible = not isMultiplayer
		playerCountLabel.TextTransparency = if isMultiplayer then 0 else 0.45
	end

	local function setPlayerCount(value: number)
		playerCount = math.clamp(math.floor(value), MIN_PLAYERS, MAX_PLAYERS)
		playerCountLabel.Text = tostring(playerCount)
	end

	local function setSelectedMode(mode: PresetMode)
		selectedMode = mode
		updateModeButtons()
	end

	local function updateRowSelection()
		for _, row in presetRows do
			row.controller.setSelected(row.id == selectedPresetId)
		end
	end

	local function clearSelection()
		selectedPresetId = ""
		selectionLabel.Text = "New Preset"
		nameBox.Text = ""
		argsBox.Text = ""
		setSelectedMode("Play")
		setPlayerCount(MIN_PLAYERS)
		runButton.instance.Visible = false
		deleteButton.instance.Visible = false
		updateRowSelection()
		setStatus("", false)
		validateArgs()
	end

	local function loadPreset(preset: Preset)
		selectedPresetId = preset.id
		selectionLabel.Text = preset.name
		nameBox.Text = preset.name
		argsBox.Text = preset.argsJson
		setSelectedMode(preset.mode)
		setPlayerCount(preset.playerCount)
		runButton.instance.Visible = true
		deleteButton.instance.Visible = true
		updateRowSelection()
		validateArgs()
	end

	local function rebuildPresetRows()
		for _, row in presetRows do
			row.controller.instance:Destroy()
		end
		table.clear(presetRows)

		local query = searchBox.Text
		local visiblePresets = PresetStore.filter(allPresets, query)

		for index, preset in visiblePresets do
			local rowController = Components.button(listScroll, {
				text = "",
				size = UDim2.new(1, -6, 0, 34),
				layoutOrder = index,
				color = Enum.StudioStyleGuideColor.TableItem,
				fallback = FALLBACK.item,
			})

			local rowPadding = Instance.new("UIPadding")
			rowPadding.PaddingLeft = UDim.new(0, 8)
			rowPadding.PaddingRight = UDim.new(0, 8)
			rowPadding.Parent = rowController.instance

			local nameLabel = Components.label(rowController.instance, {
				text = preset.name,
				textSize = 13,
				size = UDim2.new(1, -66, 1, 0),
			})
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

			Components.label(rowController.instance, {
				text = preset.mode,
				textSize = 11,
				size = UDim2.new(0, 62, 1, 0),
				position = UDim2.new(1, -62, 0, 0),
				alignX = Enum.TextXAlignment.Right,
				color = Enum.StudioStyleGuideColor.DimmedText,
				fallback = FALLBACK.dimText,
			})

			rowController.onClick(function()
				loadPreset(preset)
			end)

			table.insert(presetRows, {
				id = preset.id,
				controller = rowController,
			})
		end

		if #visiblePresets == 0 then
			emptyListLabel.Visible = true
			emptyListLabel.Text = if #allPresets == 0
				then "No presets yet. Use New Preset to add one."
				else string.format('No presets match "%s".', trim(query))
		else
			emptyListLabel.Visible = false
		end

		updateRowSelection()
	end

	local function makePresetFromForm(): Preset?
		local trimmedName = trim(nameBox.Text)
		if trimmedName == "" then
			setStatus("Preset name is required.", true)
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

	----------------------------------------------------------------------------
	-- Wiring
	----------------------------------------------------------------------------

	searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildPresetRows)
	argsBox:GetPropertyChangedSignal("Text"):Connect(scheduleValidation)

	refreshButton.onClick(callbacks.onRefresh)
	newPresetButton.onClick(clearSelection)

	saveButton.onClick(function()
		local preset = makePresetFromForm()
		if preset then
			callbacks.onSave(preset)
		end
	end)

	runButton.onClick(function()
		if selectedPresetId == "" then
			setStatus("Select a preset before running it.", true)
			return
		end

		callbacks.onTest(selectedPresetId)
	end)

	deleteButton.onClick(function()
		if selectedPresetId == "" then
			setStatus("Select a preset before deleting it.", true)
			return
		end

		dialogLabel.Text = string.format('Delete preset "%s"? This cannot be undone.', trim(nameBox.Text))
		overlay.Visible = true
	end)

	cancelButton.onClick(function()
		overlay.Visible = false
	end)

	confirmButton.onClick(function()
		overlay.Visible = false
		if selectedPresetId ~= "" then
			callbacks.onDelete(selectedPresetId)
		end
	end)

	for modeName, controller in modeButtons do
		controller.onClick(function()
			setSelectedMode(modeName :: PresetMode)
		end)
	end

	decreaseButton.onClick(function()
		setPlayerCount(playerCount - 1)
	end)
	increaseButton.onClick(function()
		setPlayerCount(playerCount + 1)
	end)

	clearSelection()

	return {
		gui = gui,
		show = function()
			gui.Enabled = true
		end,
		setPresets = function(presets: { Preset })
			allPresets = presets
			rebuildPresetRows()

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
		destroy = function()
			isDestroyed = true
			overlay.Visible = false
		end,
	}
end

return Widget
