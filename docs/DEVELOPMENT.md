# Development notes

## Baseline

Scaffold created on 2026-09-30. Local DMS reports `1.4.4-2.fc44`; sources are installed at `/usr/share/quickshell/dms`. The online development guide currently describes DMS 1.6. These are inspected references, not a verified compatibility range.

The local `qs` executable identifies itself as `noctalia-qs 0.0.12`. A successful `qs --version` does not establish that it is the runtime supported by DMS. Do not replace system packages or launch a second shell to work around runtime differences without a separate task.

## API boundary

`NiriState.qml` currently reads `CompositorService.isNiri`, `NiriService.windows`, and `NiriService.allWorkspaces`. These names exist in the inspected local sources. DMS's internal singleton services are not assumed to be stable public plugin APIs.

Before expanding the adapter, inspect:

- `Services/NiriService.qml`: event handling, workspace state, layout metadata, and focus actions.
- `Modules/Plugins/PluginComponent.qml`: injected `parentScreen`, bar sizing/orientation, and click handling.
- `Modules/Plugins/PluginSettings.qml` and `StringSetting.qml`: settings injection and persistence.
- Existing window/workspace widgets: output selection, launcher integration, and host sizing.

The settings entry intentionally relies on DMS to inject the manifest's plugin ID. Do not hardcode a second independent ID in that component.

## Runtime acceptance checks

After manually loading the plugin in an existing DMS/Niri session:

- Confirm both bar orientations render without QML errors.
- Change the label in plugin settings and verify the horizontal label updates.
- Open/close windows and confirm global counts update.
- Populate and leave an unnamed workspace; confirm the count follows Niri when it disappears.
- Reload the plugin and verify it returns without breaking the bar.
- Inspect logs for unresolved imports, missing properties, or binding errors.

Later navigation milestones also need multi-monitor filtering, window reorder/title changes, floating windows, long-title overflow, and icon cleanup checks.

No interactive runtime validation has been performed for this initial scaffold. `make check` only checks packaging and whitespace.

## Upstream references

- [DMS plugin development](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [DMS plugin overview](https://danklinux.com/docs/dankmaterialshell/plugins-overview)
- [DMS source](https://github.com/AvengeMedia/DankMaterialShell)
- [DMS Niri service](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Services/NiriService.qml)
- [Niri window API](https://niri-wm.github.io/niri/niri_ipc/struct.Window.html)
- [Niri layout API](https://niri-wm.github.io/niri/niri_ipc/struct.WindowLayout.html)
- [Niri actions](https://niri-wm.github.io/niri/niri_ipc/enum.Action.html)
- [Material Shell inspiration](https://github.com/material-shell/material-shell)

For QML language-server support, follow DMS's upstream development guide using a separate local DMS checkout with its submodules. Avoid checking machine-specific import paths into this plugin repository.
