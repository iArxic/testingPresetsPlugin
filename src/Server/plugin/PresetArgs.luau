local HttpService = game:GetService("HttpService")

local PresetArgs = {}

local function tryJsonDecode(text: string): (boolean, any)
	return pcall(function()
		return HttpService:JSONDecode(text)
	end)
end

--[[
	Decodes a preset's raw `Args JSON` into the single `Variant` that
	`StudioTestService` forwards to `GetTestArgs()`.

	The decoded value is returned with its type intact: a JSON object becomes a
	dictionary, a JSON string stays a string, and blank text becomes `nil`.
	Returns `false` plus the decode error when the text is not valid JSON.
]]
function PresetArgs.decode(rawValue: string): (boolean, any)
	local trimmed = string.gsub(rawValue, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return true, nil
	end

	local success, result = tryJsonDecode(trimmed)
	if success then
		return true, result
	end

	-- `JSONDecode` is only documented to accept a JSON object or array, so bare
	-- top-level scalars such as `"SmokeTest"`, `15`, or `true` can be rejected.
	-- Decode those through a one-element array so the engine parser still does
	-- the work, and keep the original error if the text is not a lone scalar.
	local wrappedSuccess, wrapped = tryJsonDecode(string.format("[%s]", trimmed))
	if wrappedSuccess and type(wrapped) == "table" and #wrapped <= 1 then
		return true, wrapped[1]
	end

	return false, result
end

return PresetArgs
