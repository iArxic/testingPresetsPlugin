local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")

if not plugin then
	return
end

local PresetStore = require(script.Parent.PresetStore)
local Widget = require(script.Parent.Widget)

type PresetMode = "Play" | "Run" | "Multiplayer"
type Preset = {
	id: string,
	name: string,
	mode: PresetMode,
	playerCount: number,
	argsJson: string,
}
type WidgetController = {
	gui: DockWidgetPluginGui,
	show: () -> (),
	setPresets: ({ Preset }) -> (),
	setStatus: (string, boolean?) -> (),
	clearSelection: () -> (),
}
type ToolbarButtonEntry = {
	button: PluginToolbarButton,
	signature: string,
}

local TOOLBAR_NAME = "Studio Test Presets"
local EDIT_BUTTON_ID = "StudioTestPresetPlugin_Edit"
local EDIT_BUTTON_TEXT = "Create / Edit"
local BUTTON_ICON = ""

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local editButton = toolbar:CreateButton(EDIT_BUTTON_ID, "Create or edit Studio test presets", BUTTON_ICON, EDIT_BUTTON_TEXT)

local widgetController: WidgetController
local presetButtons: { [string]: ToolbarButtonEntry } = {}
local isLaunching = false
local runPreset: (Preset) -> ()
local refreshToolbarButtons: () -> ()
local disconnectPresetStoreObserver: (() -> ())?
local pendingRefresh = false

local function decodeArgs(rawValue: string): (boolean, any)
	local trimmed = string.gsub(rawValue, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return true, nil
	end

	local success, result = pcall(function()
		return HttpService:JSONDecode(trimmed)
	end)

	if not success then
		return false, result
	end

	return true, result
end

local function setButtonsEnabled(enabled: boolean)
	editButton.Enabled = enabled
	for _, entry in presetButtons do
		entry.button.Enabled = enabled
	end
end

local function getPresetToolbarSignature(preset: Preset): string
	return string.format("%s\0%s", preset.name, preset.mode)
end

local function createPresetToolbarButton(preset: Preset): PluginToolbarButton
	local buttonId = string.format("StudioTestPresetPlugin_%s", preset.id)
	local tooltip = string.format("Run %s preset in %s mode", preset.name, preset.mode)
	local button = toolbar:CreateButton(buttonId, tooltip, BUTTON_ICON, preset.name)
	button.Click:Connect(function()
		local latestPreset = PresetStore.getPreset(preset.id)
		if not latestPreset then
			widgetController.setStatus("The selected preset no longer exists.", true)
			refreshToolbarButtons()
			return
		end

		runPreset(latestPreset)
	end)
	return button
end

runPreset = function(preset: Preset)
	if isLaunching then
		widgetController.setStatus("A Studio test is already being launched.", true)
		return
	end

	local argsSuccess, argsOrError = decodeArgs(preset.argsJson)
	if not argsSuccess then
		widgetController.setStatus(string.format("Invalid Args JSON: %s", tostring(argsOrError)), true)
		widgetController.show()
		return
	end

	isLaunching = true
	setButtonsEnabled(false)
	widgetController.setStatus(string.format("Launching %s preset '%s'...", preset.mode, preset.name), false)

	task.spawn(function()
		local success, result = pcall(function()
			if preset.mode == "Run" then
				return StudioTestService:ExecuteRunModeAsync(argsOrError)
			end

			if preset.mode == "Multiplayer" then
				return StudioTestService:ExecuteMultiplayerTestAsync(preset.playerCount, argsOrError)
			end

			return StudioTestService:ExecutePlayModeAsync(argsOrError)
		end)

		isLaunching = false
		setButtonsEnabled(true)

		if success then
			widgetController.setStatus(string.format("Preset '%s' finished with result: %s", preset.name, HttpService:JSONEncode(result)), false)
		else
			widgetController.setStatus(string.format("Launch failed for '%s': %s", preset.name, tostring(result)), true)
			widgetController.show()
		end
	end)
end

refreshToolbarButtons = function()
	local presets = PresetStore.listPresets()
	widgetController.setPresets(presets)
	local seenPresetIds = {}
	for _, preset in presets do
		seenPresetIds[preset.id] = true
		local signature = getPresetToolbarSignature(preset)
		local existingEntry = presetButtons[preset.id]
		if existingEntry and existingEntry.signature == signature then
			continue
		end

		if existingEntry then
			existingEntry.button:Destroy()
			presetButtons[preset.id] = nil
		end

		local success, buttonOrError = pcall(function()
			return createPresetToolbarButton(preset)
		end)
		if not success then
			widgetController.setStatus(string.format("Failed to refresh toolbar button for '%s': %s", preset.name, tostring(buttonOrError)), true)
			continue
		end

		presetButtons[preset.id] = {
			button = buttonOrError,
			signature = signature,
		}
	end

	local removedPresetIds = {}
	for presetId in presetButtons do
		if not seenPresetIds[presetId] then
			table.insert(removedPresetIds, presetId)
		end
	end
	for _, presetId in removedPresetIds do
		presetButtons[presetId].button:Destroy()
		presetButtons[presetId] = nil
	end

	setButtonsEnabled(not isLaunching)
end

local function scheduleRefreshToolbarButtons()
	if pendingRefresh then
		return
	end

	pendingRefresh = true
	task.defer(function()
		pendingRefresh = false
		refreshToolbarButtons()
	end)
end

local function savePreset(preset: Preset)
	local argsSuccess, argsOrError = decodeArgs(preset.argsJson)
	if not argsSuccess then
		widgetController.setStatus(string.format("Invalid Args JSON: %s", tostring(argsOrError)), true)
		return
	end

	if preset.mode == "Multiplayer" and (preset.playerCount < 1 or preset.playerCount > 8) then
		widgetController.setStatus("Multiplayer presets require a player count between 1 and 8.", true)
		return
	end

	local savedPreset = PresetStore.savePreset(preset)
	refreshToolbarButtons()
	widgetController.setStatus(string.format("Saved preset '%s'.", savedPreset.name), false)
end

local function testPreset(presetId: string)
	local preset = PresetStore.getPreset(presetId)
	if not preset then
		widgetController.setStatus("The selected preset no longer exists.", true)
		refreshToolbarButtons()
		return
	end

	runPreset(preset)
end

local function deletePreset(presetId: string)
	local existingPreset = PresetStore.getPreset(presetId)
	if not existingPreset then
		widgetController.setStatus("The selected preset no longer exists.", true)
		refreshToolbarButtons()
		return
	end

	PresetStore.deletePreset(presetId)
	refreshToolbarButtons()
	widgetController.clearSelection()
	widgetController.setStatus(string.format("Deleted preset '%s'.", existingPreset.name), false)
end

widgetController = Widget.new(plugin, {
	onSave = savePreset,
	onTest = testPreset,
	onDelete = deletePreset,
	onRefresh = refreshToolbarButtons,
})

disconnectPresetStoreObserver = PresetStore.observeChanges(scheduleRefreshToolbarButtons)

editButton.Click:Connect(function()
	widgetController.show()
	refreshToolbarButtons()
end)

refreshToolbarButtons()