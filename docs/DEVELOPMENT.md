# Development notes

## Baseline

Compatibility verified on 2026-09-30 with DMS **1.6.2**, API **34**, settings schema **18**, Quickshell **0.3.1**, and Niri **26.04**. These are inspected versions, not a compatibility range.

The running `dms.service` invokes `/usr/bin/dms run --session`. Its embedded UI is extracted into `/run/user/1000/danklinux-shell/fc3c244a314d77c8/`; inspect the active process/logs to discover this path again after upgrades. The legacy `~/.config/quickshell/dms` symlink and `/usr/share/quickshell/dms` are not authoritative for this invocation. Earlier checks against DMS 1.4.4 and an older local shell are historical only.

The 1.6.2 repair replaced the Qt Quick Controls button with an explicitly sized rectangle, DMS `StyledText`, and a `MouseArea`. In the running host, the former controls displayed backgrounds without their labels. After a shell restart, screenshots confirmed labels and controls on DP-2 and the empty-workspace view on eDP-1. Plugin reload alone retained cached helper components: do not mistake a successful reload response for loading every changed QML file.

The left workspace rail and custom icons remain pending. The vertical plugin still displays a diagnostic count. No second bar was added by the compatibility repair.

The explicitly requested desktop configuration audit is recorded in [Configuration](CONFIGURATION.md). Routine repository checks never modify desktop settings.

## API boundary

`NiriState.qml` reads `CompositorService.isNiri`, `NiriService.windows`, and `NiriService.allWorkspaces`, and calls `NiriService.focusWindow(id)` plus `moveColumnLeft(outputName)`/`moveColumnRight(outputName)` for wheel navigation. These names exist in both inspected sources. It passes snapshots into pure functions in `WindowModel.js`. DMS's internal singleton services are not assumed to be stable public plugin APIs.

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

`make check` covers packaging validation, Python and link-script syntax, whitespace checks, twenty-five pure window-model tests, and eight tooling tests. Window-model tests cover output selection, workspace filtering, layout order, malformed/missing positions, floating-window exclusion/toggles, strip growth and arrow thresholds, title fallbacks, active state, urgency, changing snapshots, proportional geometry, and scroll offsets. Tooling tests cover successful repeated refresh, read-only embedded sources, persistent imports, preserved editor settings, overlapping paths, missing sources, scanner failure/timeout, and publication rollback.

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

## VS Code QML imports

Install the official `TheQtCompany.qt-qml` extension and its standalone `qmlls`. The downloaded server previously failed to start because `libodbc.so.2` was absent; the user installed its dependency and confirmed startup works.

Generate this repository's DMS imports from the active UI source:

```bash
python3 scripts/setup-qml-tooling.py --dms-source /run/user/1000/danklinux-shell/fc3c244a314d77c8
```

Discover the active source path again from `dms doctor` or service logs after upgrades. For a development checkout, pass its `quickshell/` directory with the DankCommon submodule present. The setup requires Python 3 and `qs`; it does not download sources or install packages.

The helper stages a DMS snapshot before publishing it under `.local/dms-tooling/source`, replaces the snapshot's entrypoint with an empty, offscreen helper, and lets Quickshell's own scanner generate `qmldir` files and singleton metadata. It imports types without instantiating DMS services or running a second desktop shell. Generated imports are copied to `.local/dms-tooling/imports` rather than depending on `/run/user/` after reboot. The import tree also preserves the source JavaScript helpers and assets, which Quickshell’s type scanner omits; otherwise relative imports such as `Common/QmlUtils.js` cannot resolve. `.qmlls.ini` points at that directory and the installed Qt/Quickshell import paths. New `.vscode/settings.json` enables the server and disables CMake calls; existing editor settings are preserved.

All generated paths are already gitignored. Refresh this snapshot after a DMS upgrade or moving the repository; it represents the selected source revision rather than automatically following changes. The setup rejects a source inside or containing its tooling directory before making changes, verifies the required modules and `qs`, and replaces the local `.qmlls.ini` and its generated directories only after metadata generation succeeds. A publication failure restores the previous artifacts. Generated destination symlinks are rejected. The scanner runtime is temporary and removed after imports are dereferenced and copied. It does not modify DMS, global editor settings, or desktop configuration.

In VS Code, open this repository and run **Qt: Restart QML Language Server**. If it keeps old configuration, use **Developer: Reload Window**. QML files should have language mode **QML**. Diagnostics appear as squiggles and in the Problems panel; text inside a dynamic `var` model can still be beyond static type checking.

The installed standalone qmlls (build 2026-09-07, commit `b856c5b397`) initially reported twelve unqualified-access warnings across `NavigationWidget.qml` and `WindowStrip.qml`, plus missing DMS JavaScript imports in its logs. Both files now declare `pragma ComponentBehavior: Bound`, making their use of outer IDs in nested components explicit. Repeater delegates already declare the required model properties for bound components. The tooling setup now preserves the JavaScript dependencies and assets alongside generated metadata. A protocol-level check of all five QML files reports zero diagnostics after these fixes; diagnostic settings remain enabled. This editor check does not verify visual runtime behavior.

## Width-limit update

Full-width growth is enabled by default; saved `maximumWidth` values remain available when it is disabled. The pixel slider now reaches 7680 logical pixels. This change was inspected against the same DMS 1.6.2 host and checked with `make check`. Live reload verifies loading only; maximum-window-count layout and custom frame insets still need the acceptance check above.

## Proportional icon/title tabs

DMS 1.6.2 `handleWindowLayoutsChanged` replaces the reactive window snapshot with updated layouts; the plugin uses those events without polling. Niri's [WindowLayout documentation](https://niri-wm.github.io/niri/niri_ipc/struct.WindowLayout.html) recommends tile sizes for visual representations. Icon rendering uses the inspected DMS `Paths.getAppIcon` API with Quickshell `IconImage`, matching DMS’s focused-window widget. `AppIconRenderer` interprets `image://icon` provider URLs as its `image:` prefix; using `IconImage` directly avoids that conflict.

Tests cover decorated-width extraction and fallback, proportional sizing at a fixed monitor scale, variable-width scroll positions, and stable existing tab widths when another window shrinks, appears, or disappears. They also verify a stable fallback for unknown geometry and exact window titles without added application labels.

The earlier shared scale was based on the average and minimum widths in the window list. It caused unrelated tabs to enlarge when a narrow window appeared. The fixed monitor-based scale and per-tab readability minimum correct that behavior; strict ratios are relaxed only for tabs at the minimum. Live rendering was verified in DMS 1.6.2; deliberate resize and hover/click interaction checks remain separate from the model regressions.

## Full-history review — 2026-09-30

All three existing commits were reviewed against the final tree and the active DMS 1.6.2 UI source. See [Review](REVIEW.md) for findings and fixes. The plugin now calls the inspected `openDankLauncherV2` directly; older launcher APIs are outside the verified baseline. Tooltips explicitly render plain text, and custom buttons expose an accessibility press action with an enabled-state guard.

The revised tooling setup successfully regenerated imports from the active embedded source without loading desktop services. A separate nonvisual Quickshell helper checked component readiness for all five QML components without instantiating the plugin, panels, or desktop services. It used the existing Wayland backend because the DMS host depends on `PanelWindow`, which cannot load with the offscreen backend. These are tooling and component-loading checks. The changed scrolling, tooltip, accessibility, and launcher behavior still needs the runtime acceptance checks in the existing shell; no shell restart or desktop configuration change was performed for this review.


## Strip layout update — 2026-09-30

The model excludes floating windows reactively. Tab scale increased from 180 to 270 pixels per monitor-wide window, with a 96-pixel minimum (or 1.5 × (button height + 24), whichever is larger). Existing tabs retain their independent monitor-based scale. Arrows reserve no space until tabs plus the launcher overflow the configured ceiling. Empty workspaces, including floating-only workspaces, show just the launcher button.

Inspected the active DMS 1.6.2 `PluginComponent.qml`, `BasePill.qml`, `Theme.qml`, and `DankBarTab.qml`, plus the saved bar configuration. `BasePill` centers its content without clipping, so the horizontal strip now uses `barThickness` for button height. The follow-up full-height change also binds the horizontal host pill’s `widgetThickness` to `barThickness`, filling its background and outline. Settings → DankBar → Size changes bar height; Padding/Remove Widget Padding change horizontal padding for this plugin. No desktop configuration was changed.

`make check` covers the changed filtering, width scale, scroll offsets, arrow threshold, and plus-only geometry. Live visuals, full-height hit targets, and empty/populated transitions require validation in the existing DMS session. Helper caching can require an authorized shell restart; no restart was performed for this change.


## Full-height horizontal pill

DMS 1.6.2 `WidgetHost.qml` binds the plugin's `widgetThickness`, so the plugin leaves that injected property alone. Instead it identifies the `PluginComponent` child `BasePill` whose `content` is its horizontal component, then applies a scoped `Binding` to that pill's `widgetThickness`. Its value follows `barThickness`, and the original binding is restored for vertical instances. This is an inspected internal host dependency, not a public DMS full-height API; recheck after DMS upgrades.

The width ceiling reserves the padding scaled to the full-height pill, matching `BasePill.horizontalPadding`. DMS opacity, hover, outline, rounding, and blur behavior remain in the host component. Static checks pass. A temporary, offscreen QML helper verified host-pill lookup, full-height binding, resize updates, and restoration of the original binding when switching to vertical orientation. It instantiated no DMS services or panels; sandbox restrictions blocked its IPC socket, so it was terminated after the assertions passed. Live full-height appearance remains unverified without reloading the existing session. No desktop settings or shell service were changed.


## Right-side navigation controls

Both arrows now sit to the right of the window viewport, before the launcher. The control row anchors to the strip's actual right edge; the viewport fills the remaining width instead of relying on the requested implicit width. Arrow visibility uses the actual width. If arrows cannot fit, they are hidden and dragging remains available. The strip clips its content to its bounds.

The inspected DMS 1.6.2 `WidgetHost` injects `sectionAvailablePrimarySize` when a plugin declares it. A trial cap using that section budget stopped full-width growth short of the right edge in the user’s session, so the plugin no longer declares or uses it. The monitor ceiling and optional explicit pixel limit control growth; right-anchored controls remain. Shared sections may still need the explicit plugin width limit. Model tests cover reduced host widths and the narrow fallback. An isolated offscreen QML helper used the actual strip layout with stub theme/button visuals and verified arrow order, launcher right-edge placement, reduced host widths, and the plus-only empty state. Sandbox restrictions blocked its IPC socket; it was terminated after the assertions passed. Actual DMS session appearance remains to be verified.


The section-budget cap was removed after live user feedback showed premature clipping of full-width growth. `make check` passes after the correction. No shell restart or desktop configuration change was performed; the restored extent still needs confirmation after plugin reload.


## Available bar width correction

Live feedback exposed both incomplete width ceilings: the monitor cap ignored the launcher/music siblings, while DMS's section budget stopped growth prematurely. The current implementation uses `BarGeometry.qml`, inspected against the active DMS 1.6.2 `DankBarContent`, `LeftSection`, `RightSection`, `CenterSection`, `WidgetHost`, and `BasePill` sources. Read-only desktop configuration inspection confirmed launcher/navigation/music in the top bar's left section, empty center/right sections, and zero bar insets.

The adapter finds the containing section and layout through named section ancestors and the layout's `widgetSpacing`. It reads the stack content width (already excluding host margins), other visible delegates' widths, occupied adjacent sections, and the actual snapped `BasePill.horizontalPadding`. It excludes the plugin's own section width to avoid a sizing feedback loop. `CenterSection.width` spans the bar even when empty, so occupancy uses `contentStart`/`contentSize`. A centered plugin uses a symmetric midpoint budget; unusual index-centering configurations and multiple growing plugin instances require additional live checks. Insufficient space for even the launcher remains a host layout limitation.

Twenty model tests include sibling reservation, empty center handling, exact zero-inset growth, and occupied neighboring sections. An offscreen QML helper instantiated the actual adapter with a representative host layout and verified reactive music appearance/removal, monitor resizing, and center/right occupancy without binding loops. It instantiated no DMS services; its sandbox-blocked IPC socket was unrelated to the successful assertions and the helper was terminated afterward. `make check` passes. Live rendering still requires confirmation after reload; no shell restart or desktop configuration edits were performed.


## Hover, native tooltip, and application icon update

Inspected the active DMS 1.6.2 `BasePill`, `RunningApps`, `DankTooltip`, and the DankCommon `StyledText`. The plugin applies scoped bindings to the horizontal pill’s `enableBackgroundHover` and `enableCursor`, restoring the host values for vertical orientation. Buttons continue to style their own hover/pressed states.

`NavigationButton` replaces Qt Controls ToolTip with delayed tooltip-request/dismissal signals. `WindowStrip` owns a shared lazy `DankTooltip` loader and passes the hosting screen, bar edge, and spacing using the inspected native `show(text, x, y, screen, leftAlign, rightAlign)` API. Top/bottom placement follows RunningApps; native tooltip text is plain text and elides at its built-in width cap. Application icon size is multiplied by 0.85; control glyph sizes are unchanged.

`make check` passes. An isolated offscreen QML helper loaded the changed button/strip logic with stub DMS visuals and tooltip, verifying reduced icon size, dismissal on disable, tooltip ownership, scroll dismissal, and top/bottom placement. Its sandbox-blocked IPC socket did not affect those assertions; it was terminated afterward. This does not verify native tooltip rendering, mouse hover timing, auto-hide/frame-bar placement, or visible hover color in the running DMS session. Helper caching may require an authorized shell restart if reload retains old QML; no restart or desktop configuration edits were performed.


## Application name in hover text

Window tooltips now show `Application name • Window title`; tab labels remain title-only. Inspected DMS 1.6.2 `Paths.getAppName(appId, desktopEntry)` and FocusedApp's use of `DesktopEntries.heuristicLookup(Paths.moddedAppId(appId))`. The button reuses one desktop-entry lookup for the icon and application name. DMS falls back to the app ID if no desktop name resolves; absent app identity leaves just the window title. Arrow and launcher tooltips retain their action labels. `make check` passes; live hover appearance still needs session verification.


## Niri wheel navigation

Inspected active DMS 1.6.2 `BarScrollArea.qml` and `NiriService.qml`: despite their names, `moveColumnLeft`/`moveColumnRight` send `FocusColumnLeft`/`FocusColumnRight`, focusing the supplied output first when needed. Only `NiriState.qml` calls these services. The strip emits `columnScrollRequested`, consumes wheel events, dismisses tooltips, and applies DMS wheel thresholds, direction preference, and cooldown. Pure model tests cover both axes, reversed direction, smooth accumulation, pixel-only input, and device/axis changes.

`make check` passes. An isolated QML helper with stub visuals verified wheel request emission, accepted-event handling, cooldown, and the non-Niri guard; it made no compositor calls. Native wheel delivery, click/drag passthrough, multi-monitor focus changes, column boundaries/stacks, and touchpad feel remain for live session validation. No shell restart or desktop configuration changes were performed.


The widget’s wheel direction was subsequently reversed at the user’s request: up/left advances and down/right goes back, before applying DMS reverse scrolling. Direction tests were updated for both axes, smooth input, and the DMS preference. `make check` passes; no global settings were changed.


## Configurable scroll direction

`NavigationSettings` adds DMS's inspected `ToggleSetting` with key `reverseScroll` and default true. `NavigationWidget` passes the reactive saved value to the strip, treating an absent setting as true to preserve the current direction. Changing the toggle clears accumulated input. The model applies this widget preference on top of DMS's global reverse-scrolling setting. Tests cover both preferences for mouse, horizontal, smooth, and pixel-only input; `make check` passes. Saving/toggling in the live settings UI remains to be verified.


## Unthrottled wheel navigation

Removed the 100 ms cooldown at the user’s request. Every complete wheel step is dispatched synchronously, including multiple steps in a single coalesced event; partial remainder is preserved instead of discarded. Existing mouse/touchpad distance thresholds and the direction option remain. A regression verifies fifty consecutive wheel events, multi-step events, and angle/pixel remainders. `make check` passes. An isolated QML helper also verified fifty immediate request emissions, three requests from one coalesced event, and changing the direction option. It used stub visuals and made no compositor calls. Actual focus speed remains subject to Niri/DMS processing; live rapid scrolling still needs verification.


## Rapid wheel follow-up and helper cache

The user reported that rapid mouse-wheel input still missed steps, while their Super+wheel Niri binding worked. Inspection found the earlier input classifier raised its threshold to 500 angle units whenever pixel metadata appeared. It now consistently uses 120 angle units per step and keeps accumulated angle input when that metadata changes; tests cover three consecutive mixed-metadata notches and zero-delta events.

Rechecked the active DMS `NiriService.send` and `DankSocket.send`: they directly write requests without a debounce. Inspected [Niri 26.04 IPC server](https://github.com/niri-wm/niri/blob/v26.04/src/ipc/server.rs) and [column focus implementation](https://github.com/niri-wm/niri/blob/v26.04/src/layout/scrolling.rs): the server processes requests in order, and column activation changes its index directly rather than waiting for animations. This does not establish live wheel delivery.

Added a one-time strip startup log stating the no-cooldown/120-angle-unit behavior to distinguish actual helper loading from successful plugin reload. A live plugin reload returned success on 2026-09-30 at 18:02 America/Chicago, but logs showed no new startup marker. The running helper remained cached. The user explicitly authorized one restart of the existing DMS service. After the restart at 18:09 America/Chicago, `dms.service` was active and both horizontal instances logged the new no-cooldown/120-angle-unit startup marker. No plugin QML errors or binding loops appeared in the startup logs. This verifies the updated helper loaded, not physical wheel delivery; rapid mouse-wheel behavior still needs user confirmation. No compositor settings or Niri keybindings were changed.
