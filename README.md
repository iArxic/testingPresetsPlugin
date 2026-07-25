# Studio Test Preset Plugin

This plugin adds a fixed `Create / Edit` toolbar button and one dynamic toolbar button per saved preset.

## What it does

- Opens a dock widget where you can create, edit, or delete presets.
- Stores presets inside the current place under `TestService/StudioTestPresetPlugin`.
- Creates a toolbar button for each saved preset.
- Launches `StudioTestService` play, run, or multiplayer tests from the saved preset.

## Preset fields

- `Preset Name`
- `Mode`: `Play`, `Run`, or `Multiplayer`
- `Player Count`: only used for `Multiplayer`, must be between `1` and `8`
- `Args JSON`: raw JSON passed into `StudioTestService`

`StudioTestService` takes a single `Variant` argument and `GetTestArgs()` returns it
with its type intact, so the decoded JSON value is forwarded as-is. An object arrives
as a dictionary, a string arrives as a string, and a number arrives as a number. The
value is never wrapped in a table.

Examples for `Args JSON`:

```json
{"testName":"LobbySpawn","timeout":15}
```

```json
"SmokeTest"
```

```json
true
```

Leave the field blank to pass `nil`.

## Important limitation

The plugin only starts Studio test sessions. If you want a test to end automatically and return a result, your game-side test scripts still need to call:

- `StudioTestService:GetTestArgs()` to read the payload
- `StudioTestService:EndTest(result)` from the server to finish the session

Without that, `ExecutePlayModeAsync`, `ExecuteRunModeAsync`, and `ExecuteMultiplayerTestAsync` will wait until the session ends by normal Studio controls.

## Development

`default.project.json` syncs `src/Server` into `ServerScriptService`, so the plugin
source lands at `ServerScriptService/plugin` in the connected place:

```sh
argon serve
```

That copy is for editing and version control only. `main.server.luau` starts with
`if not plugin then return end`, so it does nothing when it runs from inside a place.

To actually run it, install it as a local plugin: right-click the synced `plugin`
folder in `ServerScriptService` and choose **Save as Local Plugin**. Repeat that after
changing the source, otherwise Studio keeps running the previously installed copy.

## Source layout

- `src/Server/plugin/main.server.luau`: toolbar buttons, widget wiring, test launching
- `src/Server/plugin/PresetArgs.luau`: decodes `Args JSON` into the `Variant` passed to `StudioTestService`
- `src/Server/plugin/PresetStore.luau`: reads and writes presets under `TestService/StudioTestPresetPlugin`
- `src/Server/plugin/Widget.luau`: dock widget UI

## AI Customization Files

This repo includes shareable AI customization assets for creating test presets:

- Copilot custom agent: `.github/agents/create-test-preset.agent.md`
- Copilot instructions: `.github/instructions/test-preset-format.instructions.md`
- Claude command: `.claude/commands/create-test-preset.md`
- Portable preset spec: `docs/ai/test-preset-format.md`

These files describe the preset schema stored under `TestService/StudioTestPresetPlugin` and are intended to help AI tools create or update presets consistently.

When available, these AI customizations should prefer a connected Roblox Studio MCP server so presets can be created or updated directly in the live Studio session. The portable schema document remains the fallback when no MCP connection is available.