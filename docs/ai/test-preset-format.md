# Test Preset Format

This repository stores plugin test presets under `TestService/StudioTestPresetPlugin`.

## Roblox Studio MCP Server

If an AI tool has access to a connected Roblox Studio MCP server, it should prefer creating or updating presets directly in the live Studio DataModel instead of only describing the structure.

If the Roblox Studio MCP server is not available, this document is the source of truth for the manual or tool-driven preset structure.

## Schema

Each preset is represented by a `Folder` with:

- `Name`: internal preset id. This is not the display label.
- Attribute `DisplayName`: human-readable preset name.
- Attribute `Mode`: one of `Play`, `Run`, or `Multiplayer`.
- Attribute `PlayerCount`: integer from `1` to `8`.
- Optional child `StringValue` named `ArgsJson` whose `Value` is raw JSON text.

## Semantics

- `DisplayName` is what the plugin shows in the widget and may show in the toolbar.
- `Mode` controls which `StudioTestService` entry point is used.
- `PlayerCount` matters for `Multiplayer` and should still remain valid for other modes.
- Blank `ArgsJson` is valid and means the plugin passes `nil`.
- The decoded JSON value keeps its type when it reaches `GetTestArgs()`. A JSON object
  arrives as a dictionary, and a bare `"string"`, `15`, or `true` arrives as that same
  scalar rather than being wrapped in a table.

## Example Structure

```text
TestService
  StudioTestPresetPlugin
    2f0d9e9a-9f03-4a28-a0df-7de78fd0d4b2
      Attributes:
        DisplayName = "Lobby Smoke"
        Mode = "Play"
        PlayerCount = 1
      ArgsJson (StringValue)
        Value = {"testName":"LobbySpawn","timeout":15}
```

## Example Values

### Play preset

```json
{"testName":"LobbySpawn","timeout":15}
```

### Run preset

```json
{"suite":"StartupChecks"}
```

### Multiplayer preset

```json
{"map":"Arena","scenario":"Smoke"}
```

## Authoring Rules

- Never use a blank `DisplayName`.
- Never write a `Mode` outside `Play`, `Run`, or `Multiplayer`.
- Never write `PlayerCount` outside `1` to `8`.
- When updating an existing preset, keep its folder `Name` unchanged.
- When a live Roblox Studio MCP connection exists, prefer applying these values directly to the DataModel.
