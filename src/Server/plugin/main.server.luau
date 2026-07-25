local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")

if not plugin then
	return
end

local PresetArgs = require(script.Parent.PresetArgs)
local PresetStore = require(script.Parent.PresetStore)
local Theme = require(script.Parent.Theme)
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
	destroy: () -> (),
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

local function describeTestResult(value: any): string
	if value == nil then
		return "nil"
	end

	if type(value) == "table" then
		local success, encoded = pcall(function()
			return HttpService:JSONEncode(value)
		end)
		if success then
			return encoded
		end
	end

	return tostring(value)
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

	local argsSuccess, studioArgs = PresetArgs.decode(preset.argsJson)
	if not argsSuccess then
		widgetController.setStatus(string.format("Invalid Args JSON: %s", tostring(studioArgs)), true)
		widgetController.show()
		return
	end

	isLaunching = true
	setButtonsEnabled(false)
	widgetController.setStatus(string.format("Launching %s preset '%s'...", preset.mode, preset.name), false)

	task.spawn(function()
		local success, result = pcall(function()
			if preset.mode == "Run" then
				return StudioTestService:ExecuteRunModeAsync(studioArgs)
			end

			if preset.mode == "Multiplayer" then
				return StudioTestService:ExecuteMultiplayerTestAsync(preset.playerCount, studioArgs)
			end

			return StudioTestService:ExecutePlayModeAsync(studioArgs)
		end)

		isLaunching = false
		setButtonsEnabled(true)

		if success then
			widgetController.setStatus(string.format("Preset '%s' finished with result: %s", preset.name, describeTestResult(result)), false)
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
	local argsSuccess, argsError = PresetArgs.decode(preset.argsJson)
	if not argsSuccess then
		widgetController.setStatus(string.format("Invalid Args JSON: %s", tostring(argsError)), true)
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

plugin.Unloading:Connect(function()
	if disconnectPresetStoreObserver then
		disconnectPresetStoreObserver()
		disconnectPresetStoreObserver = nil
	end

	widgetController.destroy()
	Theme.destroy()
end)

refreshToolbarButtons()