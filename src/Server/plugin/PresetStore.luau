local HttpService = game:GetService("HttpService")
local TestService = game:GetService("TestService")

local PRESET_ROOT_NAME = "StudioTestPresetPlugin"
local ARGS_VALUE_NAME = "ArgsJson"

export type PresetMode = "Play" | "Run" | "Multiplayer"

export type Preset = {
	id: string,
	name: string,
	mode: PresetMode,
	playerCount: number,
	argsJson: string,
}

local PresetStore = {}

local function getRootFolder(): Folder
	local folder = TestService:FindFirstChild(PRESET_ROOT_NAME)
	if folder then
		return folder :: Folder
	end

	folder = Instance.new("Folder")
	folder.Name = PRESET_ROOT_NAME
	folder.Parent = TestService

	return folder
end

local function readArgsValue(container: Instance): string
	local argsValue = container:FindFirstChild(ARGS_VALUE_NAME)
	if argsValue and argsValue:IsA("StringValue") then
		return argsValue.Value
	end

	return ""
end

local function writeArgsValue(container: Instance, value: string)
	local argsValue = container:FindFirstChild(ARGS_VALUE_NAME)
	if not argsValue then
		argsValue = Instance.new("StringValue")
		argsValue.Name = ARGS_VALUE_NAME
		argsValue.Parent = container
	end

	(argsValue :: StringValue).Value = value
end

local function coerceMode(modeValue: string): PresetMode
	if modeValue == "Run" then
		return "Run"
	end

	if modeValue == "Multiplayer" then
		return "Multiplayer"
	end

	return "Play"
end

local function readPreset(instance: Instance): Preset?
	if not instance:IsA("Folder") then
		return nil
	end

	local name = instance:GetAttribute("DisplayName")
	if typeof(name) ~= "string" or name == "" then
		return nil
	end

	local playerCount = instance:GetAttribute("PlayerCount")
	if typeof(playerCount) ~= "number" then
		playerCount = 1
	end

	local modeValue = instance:GetAttribute("Mode")
	if typeof(modeValue) ~= "string" then
		modeValue = ""
	end

	return {
		id = instance.Name,
		name = name,
		mode = coerceMode(modeValue),
		playerCount = math.clamp(math.floor(playerCount), 1, 8),
		argsJson = readArgsValue(instance),
	}
end

local function connectPresetFolderChangedSignals(presetFolder: Folder, onChanged: () -> ()): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}

	table.insert(connections, presetFolder:GetAttributeChangedSignal("DisplayName"):Connect(onChanged))
	table.insert(connections, presetFolder:GetAttributeChangedSignal("Mode"):Connect(onChanged))
	table.insert(connections, presetFolder:GetAttributeChangedSignal("PlayerCount"):Connect(onChanged))
	table.insert(connections, presetFolder.ChildAdded:Connect(function(child)
		if child:IsA("StringValue") and child.Name == ARGS_VALUE_NAME then
			table.insert(connections, child:GetPropertyChangedSignal("Value"):Connect(onChanged))
		end
		onChanged()
	end))
	table.insert(connections, presetFolder.ChildRemoved:Connect(onChanged))

	local argsValue = presetFolder:FindFirstChild(ARGS_VALUE_NAME)
	if argsValue and argsValue:IsA("StringValue") then
		table.insert(connections, argsValue:GetPropertyChangedSignal("Value"):Connect(onChanged))
	end

	return connections
end

function PresetStore.listPresets(): { Preset }
	local presets = {}

	for _, child in getRootFolder():GetChildren() do
		local preset = readPreset(child)
		if preset then
			table.insert(presets, preset)
		end
	end

	table.sort(presets, function(left, right)
		return string.lower(left.name) < string.lower(right.name)
	end)

	return presets
end

function PresetStore.getPreset(id: string): Preset?
	local presetFolder = getRootFolder():FindFirstChild(id)
	if not presetFolder then
		return nil
	end

	return readPreset(presetFolder)
end

function PresetStore.savePreset(preset: Preset): Preset
	local rootFolder = getRootFolder()
	local presetId = preset.id

	if presetId == "" then
		presetId = HttpService:GenerateGUID(false)
	end

	local presetFolder = rootFolder:FindFirstChild(presetId)
	if not presetFolder then
		presetFolder = Instance.new("Folder")
		presetFolder.Name = presetId
		presetFolder.Parent = rootFolder
	end

	presetFolder:SetAttribute("DisplayName", preset.name)
	presetFolder:SetAttribute("Mode", preset.mode)
	presetFolder:SetAttribute("PlayerCount", math.clamp(math.floor(preset.playerCount), 1, 8))
	writeArgsValue(presetFolder, preset.argsJson)

	return {
		id = presetId,
		name = preset.name,
		mode = preset.mode,
		playerCount = math.clamp(math.floor(preset.playerCount), 1, 8),
		argsJson = preset.argsJson,
	}
end

function PresetStore.deletePreset(id: string)
	local presetFolder = getRootFolder():FindFirstChild(id)
	if presetFolder then
		presetFolder:Destroy()
	end
end

function PresetStore.observeChanges(onChanged: () -> ()): () -> ()
	local rootFolder = getRootFolder()
	local rootConnections: { RBXScriptConnection } = {}
	local childConnections: { [Instance]: { RBXScriptConnection } } = {}

	local function disconnectConnections(connections: { RBXScriptConnection }?)
		if not connections then
			return
		end

		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local function watchChild(child: Instance)
		if not child:IsA("Folder") then
			return
		end

		childConnections[child] = connectPresetFolderChangedSignals(child, onChanged)
	end

	local function unwatchChild(child: Instance)
		disconnectConnections(childConnections[child])
		childConnections[child] = nil
	end

	for _, child in rootFolder:GetChildren() do
		watchChild(child)
	end

	table.insert(rootConnections, rootFolder.ChildAdded:Connect(function(child)
		watchChild(child)
		onChanged()
	end))
	table.insert(rootConnections, rootFolder.ChildRemoved:Connect(function(child)
		unwatchChild(child)
		onChanged()
	end))

	return function()
		for child in childConnections do
			unwatchChild(child)
		end
		disconnectConnections(rootConnections)
	end
end

return PresetStore