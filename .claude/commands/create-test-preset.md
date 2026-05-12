Create or update a Studio test preset for this repository.

Follow the repository preset format in `docs/ai/test-preset-format.md`.

Preferred execution path:
- If the Roblox Studio MCP server is connected, use it to create or update the preset directly in the live Studio session.
- If the Roblox Studio MCP server is not connected, produce the exact preset structure and values the user should apply.

Requirements:
- Store presets under `TestService/StudioTestPresetPlugin`.
- Use a preset folder with an internal id as the folder name.
- Set `DisplayName`, `Mode`, and `PlayerCount` attributes.
- Store raw JSON in `ArgsJson` as a `StringValue`.
- Only use `Mode` values `Play`, `Run`, or `Multiplayer`.
- Keep `PlayerCount` in the range `1` to `8`.
- Preserve existing preset ids when updating.
- Prefer operating on the live DataModel through the Roblox Studio MCP server instead of describing abstract steps.

When the request is ambiguous, infer the smallest reasonable preset and state the final values you created.
