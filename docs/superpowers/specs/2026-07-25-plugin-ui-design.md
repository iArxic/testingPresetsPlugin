# Studio Test Presets — UI Design

Date: 2026-07-25

## Problem

`Widget.luau` builds its interface with hardcoded colors and absolute pixel
offsets. Three consequences:

- Every color is a literal `Color3.fromRGB(...)` tuned for the dark theme, so the
  widget is a black rectangle on Studio's Light theme.
- Controls are placed at fixed offsets (`0, 96`, `0, 136`, `0, 160`, `0, 200`,
  `0, 224`, `0, 264`, `0, 288`). Adding a field means renumbering everything below it.
- Nothing reflows. At the 420x520 minimum dock size the action buttons at
  `1, -76` and `1, -40` overlap the Args box, and the status line is a fixed 20px
  row that clips the long JSON decode errors it exists to display.

## Goals

Match Studio's own look and reflow correctly, then add four usability features:
preset search, delete confirmation, live Args JSON validation, and a player count
stepper. No change to what a preset is or how it is stored.

## Non-goals

Rethinking the two-pane layout, adding a UI framework dependency, and changing the
preset schema are all out of scope.

## Modules

| File | Role |
| --- | --- |
| `Theme.luau` (new) | Wraps `settings().Studio.Theme`. Owns one `ThemeChanged` connection and a binding registry. |
| `Components.luau` (new) | Themed factories: `label`, `textBox`, `button`, `row`. Hover, pressed and disabled states wired once. |
| `Widget.luau` (rewritten) | Composition and state only. No raw `Color3`, no absolute offsets for form fields. |
| `PresetStore.luau` | Gains `PresetStore.filter(presets, query)`, a pure function so search is unit-testable. |
| `main.server.luau` | Wires `plugin.Unloading` to `Theme.destroy()` and the preset observer disconnect. |

`disconnectPresetStoreObserver` in `main.server.luau` is currently assigned and
never called. Wiring `Unloading` fixes that leak.

## Theme

`Theme.bind(instance, property, styleGuideColor, fallback)` applies the color now
and returns `set(color?, modifier?)`, where `nil` means "keep current". One setter
covers both modifier changes (a button entering `Hover`) and color swaps (the
status label moving between `InfoText` and `ErrorText`).

Every `GetColor` call is wrapped and falls back to a literal `Color3` matching the
current dark palette, covering Studio being unavailable and `GetColor` itself
failing. It does not cover a `StudioStyleGuideColor` member that does not exist on
the running build, because that errors where the enum is indexed at the call site,
before `Theme` sees it. Every member used here is long-standing.

Color mapping:

- Backgrounds: `MainBackground`, separated by a 1px `Border` divider rather than
  differently shaded panels, which is what Studio itself does and avoids guessing
  at a panel shade that works in both themes.
- Text: `MainText`, `SubText`, `DimmedText`.
- Inputs: `InputFieldBackground` with a `UIStroke` in `InputFieldBorder`.
- Buttons: `Button` / `ButtonText` with `Hover`, `Pressed` and `Disabled` modifiers.
- Save: `MainButton` with `BrightText`. Delete: `ErrorText` on a normal button.
- List rows: `TableItem`, using the `Selected` modifier for the active preset.
- Status: `InfoText` normally, `ErrorText` on failure.

## Layout

The two panes keep their split. Within each pane the three major regions (header,
scrolling body, footer) are anchored manually, because that is only a handful of
numbers and does not benefit from a layout object. Inside the scrolling bodies,
`UIListLayout` with `LayoutOrder` and `AutomaticCanvasSize.Y` drives the rows, so
adding a field never renumbers its neighbours and the content scrolls instead of
colliding at small dock sizes.

The status label uses `AutomaticSize.Y` with `TextWrapped`, so a full JSON decode
error is readable.

## Features

**Search.** A box above the preset list filters on name and mode,
case-insensitive substring, via `PresetStore.filter`. Empty query returns the list
unchanged. A "No presets match" row appears when a non-empty query matches nothing.

**Delete confirmation.** An in-widget overlay naming the preset, with Cancel and
Delete. It is an overlay frame, not a modal dialog, because a blocking dialog would
freeze the plugin.

**Live Args JSON validation.** Text changes on the Args box are debounced ~150ms
and passed to `PresetArgs.decode`. The result line reads `valid - object`,
`valid - string`, `valid - nil (no args)` or `invalid: <error>`. Reporting the
decoded *type* means the table-wrapping bug fixed in 373d5dd cannot silently return.

**Player count stepper.** `[-] N [+]` clamped to 1-8, rendered with the `Disabled`
modifier outside Multiplayer rather than only being non-editable.

## Error handling

Theme lookups fall back per binding. The validation debounce checks that the widget
still exists before writing to the label. Nothing in the UI path can throw into the
preset launch path, which stays as it is.

## Testing

`PresetStore.filter` gets Lune unit tests next to the existing 24 argument cases.
Theme and layout cannot run headless: those are covered by the compile check and
`argon build`, and must be confirmed visually in Studio under both themes. Any
claim about appearance will be labelled unverified until then.
