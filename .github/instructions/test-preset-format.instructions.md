---
name: "Studio Test Preset Format"
description: "Use when creating, updating, or reviewing Studio test presets for this plugin, especially through a Roblox Studio MCP server. Covers the TestService folder schema, required attributes, and ArgsJson value format."
---
# Studio Test Preset Format

- Prefer using a connected Roblox Studio MCP server when creating or updating presets in a live Studio session.
- If no Roblox Studio MCP server is available, use this file as the source of truth for the exact preset structure to create manually.

- Presets are stored under `TestService/StudioTestPresetPlugin`.
- Each preset is a `Folder` whose `Name` is the internal preset id.
- Each preset folder must have these attributes:
  - `DisplayName`: preset label shown in the plugin UI.
  - `Mode`: `Play`, `Run`, or `Multiplayer`.
  - `PlayerCount`: integer from `1` to `8`.
- Each preset folder may contain a `StringValue` named `ArgsJson`.
- `ArgsJson.Value` is raw JSON text or blank.
- Blank `ArgsJson` means the plugin passes `nil`.
- `PlayerCount` is only meaningful for `Multiplayer`, but the stored value should still be valid.
- Prefer readable preset names because they may appear in the plugin toolbar.
