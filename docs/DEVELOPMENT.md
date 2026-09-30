# Development notes

## Baseline

Compatibility verified on 2026-09-30 with DMS **1.6.2**, API **34**, settings schema **18**, Quickshell **0.3.1**, and Niri **26.04**. These are inspected versions, not a compatibility range.

The running `dms.service` invokes `/usr/bin/dms run --session`. Its embedded UI is extracted into `/run/user/1000/danklinux-shell/fc3c244a314d77c8/`; inspect the active process/logs to discover this path again after upgrades. The legacy `~/.config/quickshell/dms` symlink and `/usr/share/quickshell/dms` are not authoritative for this invocation. Earlier checks against DMS 1.4.4 and an older local shell are historical only.

The 1.6.2 repair replaced the Qt Quick Controls button with an explicitly sized rectangle, DMS `StyledText`, and a `MouseArea`. In the running host, the former controls displayed backgrounds without their labels. After a shell restart, screenshots confirmed labels and controls on DP-2 and the empty-workspace view on eDP-1. Plugin reload alone retained cached helper components: do not mistake a successful reload response for loading every changed QML file.

The left workspace rail and custom icons remain pending. The vertical plugin still displays a diagnostic count. No second bar was added by the compatibility repair.

The explicitly requested desktop configuration audit is recorded in [Configuration](CONFIGURATION.md). Routine repository checks never modify desktop settings.

## API boundary

`NiriState.qml` reads `CompositorService.isNiri`, `NiriService.windows`, and `NiriService.allWorkspaces`, and calls `NiriService.focusWindow(id)`. These names exist in both inspected sources. It passes snapshots into pure functions in `WindowModel.js`. DMS's internal singleton services are not assumed to be stable public plugin APIs.

Before expanding the adapter, inspect:

- `Services/NiriService.qml`: event handling, workspace state, layout metadata, and focus actions.
- `Modules/Plugins/PluginComponent.qml`: injected `parentScreen`, bar sizing/orientation, and click handling.
- `Modules/Plugins/PluginSettings.qml` and `StringSetting.qml`: settings injection and persistence.
- Existing window/workspace widgets: output selection, launcher integration, and host sizing.

The inspected settings loaders inject `pluginService` but not the required `pluginId`. `NavigationSettings.qml` therefore explicitly sets `justinNavigation`, matching the manifest. Keep those IDs in sync when renaming the plugin. This corrects the original scaffold's assumption about ID injection.

## Runtime acceptance checks

After manually loading the plugin in an existing DMS/Niri session:

- Confirm both bar orientations render without QML errors.
- Toggle full-width growth and add enough windows to exceed the old 45% cap. Confirm the monitor ceiling, then disable it and verify the pixel limit applies. Test crowded bars separately; other widget widths are not automatically reserved.
- Open/close windows and verify the titles update on the correct monitor.
- Switch/reorder windows and verify layout ordering, active-window highlighting, and click-to-focus.
- Verify long-title tooltips, overflow arrows/dragging, and the plus launch action.
- Populate and leave an unnamed workspace; confirm the count follows Niri when it disappears.
- Reload the plugin and verify it returns without breaking the bar.
- Inspect logs for unresolved imports, missing properties, or binding errors.

Later navigation milestones also need multi-monitor filtering, window reorder/title changes, floating windows, long-title overflow, and icon cleanup checks.

`make check` passes packaging validation, setup-script syntax, whitespace checks, and eleven pure model tests. Tests cover output selection, workspace filtering, layout order, malformed/missing positions, floating windows, title fallbacks, active state, urgency, and changing snapshots.

Earlier windowless compilation checks established QML component readiness only. Current verification includes live DMS loading and screenshots of populated/empty monitor bars. Click-to-focus, launcher clicks, tooltip behavior, and overflow interaction still need the acceptance checks above; rendering evidence does not establish those interactions.

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

## Width-limit update

Full-width growth is enabled by default; saved `maximumWidth` values remain available when it is disabled. The pixel slider now reaches 7680 logical pixels. This change was inspected against the same DMS 1.6.2 host and checked with `make check`. Live reload verifies loading only; maximum-window-count layout and custom frame insets still need the acceptance check above.

## Proportional icon/title tabs

DMS 1.6.2 `handleWindowLayoutsChanged` replaces the reactive window snapshot with updated layouts; the plugin uses those events without polling. Niri's [WindowLayout documentation](https://niri-wm.github.io/niri/niri_ipc/struct.WindowLayout.html) recommends tile sizes for visual representations. Icon rendering uses the inspected DMS `Paths.getAppIcon` API with Quickshell `IconImage`, matching DMS’s focused-window widget. `AppIconRenderer` interprets `image://icon` provider URLs as its `image:` prefix; using `IconImage` directly avoids that conflict.

Tests cover decorated-width extraction and fallback, proportional sizing at a fixed monitor scale, variable-width scroll positions, and stable existing tab widths when another window shrinks, appears, or disappears. They also verify a stable fallback for unknown geometry and exact window titles without added application labels.

The earlier shared scale was based on the average and minimum widths in the window list. It caused unrelated tabs to enlarge when a narrow window appeared. The fixed monitor-based scale and per-tab readability minimum correct that behavior; strict ratios are relaxed only for tabs at the minimum. Live rendering was verified in DMS 1.6.2; deliberate resize and hover/click interaction checks remain separate from the model regressions.
