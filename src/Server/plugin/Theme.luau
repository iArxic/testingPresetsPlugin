--[[
	Keeps plugin UI colors in sync with the current Studio theme.

	`Theme.bind` records a binding and applies it immediately. Every binding is
	re-applied when Studio's theme changes, through a single shared connection.
]]

local Theme = {}

export type Setter = (color: Enum.StudioStyleGuideColor?, modifier: Enum.StudioStyleGuideModifier?) -> ()

type Binding = {
	instance: Instance,
	property: string,
	color: Enum.StudioStyleGuideColor,
	modifier: Enum.StudioStyleGuideModifier,
	fallback: Color3,
}

local bindings: { Binding } = {}
local themeChangedConnection: RBXScriptConnection? = nil

local function getStudio(): any?
	local success, studio = pcall(function()
		return settings().Studio
	end)

	if success then
		return studio
	end

	return nil
end

-- Falls back to the literal color when Studio is unavailable or the style guide
-- entry is not known to this Studio build.
local function resolveColor(binding: Binding): Color3
	local studio = getStudio()
	if not studio then
		return binding.fallback
	end

	local success, color = pcall(function()
		return studio.Theme:GetColor(binding.color, binding.modifier)
	end)

	if success and typeof(color) == "Color3" then
		return color
	end

	return binding.fallback
end

local function applyBinding(binding: Binding)
	local target = binding.instance :: any
	target[binding.property] = resolveColor(binding)
end

local function ensureConnection()
	if themeChangedConnection then
		return
	end

	local studio = getStudio()
	if not studio then
		return
	end

	local success, connection = pcall(function()
		return studio.ThemeChanged:Connect(function()
			for _, binding in bindings do
				applyBinding(binding)
			end
		end)
	end)

	if success then
		themeChangedConnection = connection
	end
end

--[[
	Binds `property` on `instance` to a Studio style guide color.

	Returns a setter that swaps the style guide color, the modifier, or both.
	Passing `nil` for either keeps its current value.
]]
function Theme.bind(
	instance: Instance,
	property: string,
	color: Enum.StudioStyleGuideColor,
	fallback: Color3
): Setter
	local binding: Binding = {
		instance = instance,
		property = property,
		color = color,
		modifier = Enum.StudioStyleGuideModifier.Default,
		fallback = fallback,
	}

	table.insert(bindings, binding)
	applyBinding(binding)
	ensureConnection()

	return function(nextColor: Enum.StudioStyleGuideColor?, nextModifier: Enum.StudioStyleGuideModifier?)
		if nextColor then
			binding.color = nextColor
		end

		if nextModifier then
			binding.modifier = nextModifier
		end

		applyBinding(binding)
	end
end

function Theme.destroy()
	if themeChangedConnection then
		themeChangedConnection:Disconnect()
		themeChangedConnection = nil
	end

	table.clear(bindings)
end

return Theme
