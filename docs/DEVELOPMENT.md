# Development notes

## Baseline

Compatibility verified on 2026-09-30 with DMS **1.6.2**, API **34**, settings schema **18**, Quickshell **0.3.1**, and Niri **26.04**. These are inspected versions, not a compatibility range.

The running `dms.service` invokes `/usr/bin/dms run --session`. Its embedded UI is extracted into `/run/user/1000/danklinux-shell/fc3c244a314d77c8/`; inspect the active process/logs to discover this path again after upgrades. The legacy `~/.config/quickshell/dms` symlink and `/usr/share/quickshell/dms` are not authoritative for this invocation. Earlier checks against DMS 1.4.4 and an older local shell are historical only.

The 1.6.2 repair replaced the Qt Quick Controls button with an explicitly sized rectangle, DMS `StyledText`, and a `MouseArea`. In the running host, the former controls displayed backgrounds without their labels. After a shell restart, screenshots confirmed labels and controls on DP-2 and the empty-workspace view on eDP-1. Plugin reload alone retained cached helper components: do not mistake a successful reload response for loading every changed QML file.

The left workspace rail and custom icons remain pending. The vertical plugin still displays a diagnostic count. No second bar was added by the compatibility repair.

The explicitly requested desktop configuration audit is recorded in [Configuration](CONFIGURATION.md). Routine repository checks never modify desktop settings.

## API boundary

`NiriState.qml` reads `CompositorService.isNiri`, `NiriService.windows`, and `NiriService.allWorkspaces`, and uses `NiriService.send` for ID-targeted close requests, and calls `NiriService.focusWindow(id)` plus `moveColumnLeft(outputName)`/`moveColumnRight(outputName)` for wheel navigation. These names exist in both inspected sources. It passes snapshots into pure functions in `WindowModel.js`. DMS's internal singleton services are not assumed to be stable public plugin APIs.

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

Workspace transitions also need live checks: switch quickly between populated and empty workspaces on each output, verify the tab entrance and strip width feel smooth, and disable DMS animations to confirm immediate changes. Check overflow and launcher hit targets during width changes.

`make check` covers packaging validation, Python and link-script syntax, whitespace checks, thirty-two pure window-model tests, and eight tooling tests. Window-model tests cover output selection, workspace filtering, layout order, malformed/missing positions, floating-window exclusion/toggles, strip growth and arrow thresholds, title fallbacks, active state, urgency, changing snapshots, proportional geometry, and scroll offsets. Tooling tests cover successful repeated refresh, read-only embedded sources, persistent imports, preserved editor settings, overlapping paths, missing sources, scanner failure/timeout, and publication rollback.

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

## Workspace strip transitions

Inspected the active DMS 1.6.2 `Common/Theme.qml`: `shortDuration`, `standardEasing`, and `snapListModelChanges` supply transition timing, easing, and disabled-animation behavior. `NavigationWidget` passes the adapter's active workspace ID into `WindowStrip`; no new compositor API or IPC connection is used. Tabs fade in with a small vertical offset on workspace changes, while natural content width animates independently. The width ceiling remains immediate, tab proportions remain unchanged, and window/focus updates are never delayed. Tooltips are dismissed and suppressed during the entrance. The startup marker now includes `workspace transitions loaded` to identify the changed helper.

An isolated offscreen Quickshell helper, using the actual strip logic with stub DMS visuals, verified intermediate opacity/offset/width values, rapid switches settling on the latest window, immediate focus updates, title snapshots avoiding a restart, empty-workspace launcher-only geometry, disabled animations, and immediate width ceilings. Its sandbox-blocked IPC socket did not affect the assertions. This is logic/runtime verification without desktop panels, not visible DMS verification. Live animation feel, multi-monitor behavior, overflow, and controls during resizing remain pending. No shell restart or desktop configuration edits were performed.

The QML language-server check reported no animation-related diagnostics; its existing dynamic host-property and tooltip-loader type warnings remain (eight in `BarGeometry`, four in `WindowStrip`). `make check` passes. A live plugin reload attempt was blocked by sandbox IPC access; automatic approval review then rejected the escalation because it requires explicit authorization for a session-affecting reload. The running plugin has not been reloaded for this change, so visible DMS validation remains pending.

## Middle-click to close

Window tabs opt into `NavigationButton.acceptMiddleClick`; middle-button release emits a separate close signal, while left-click and the accessibility press action retain focus behavior. `NiriState.closeWindow` guards compositor availability and current output/workspace membership, rejects null/undefined IDs, and sends `{"Action":{"CloseWindow":{"id":windowId}}}` through DMS's existing request socket. The window disappears from reactive state when Niri reports closure; the plugin does not remove it optimistically. Applications can present their normal unsaved-work prompt.

Inspected the installed DMS 1.6.2 `NiriService.send` and `focusWindow` request pattern, plus the [Niri 26.04 IPC action definition](https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs) and installed `niri msg action close-window --help`. DMS has no dedicated close-by-ID helper in this version. The explicit ID avoids a focus-then-close race.

An isolated offscreen Quickshell/QtTest helper exercised actual left/middle mouse events against the changed button and strip with stub visuals and a mocked DMS service. It verified closing the unfocused clicked ID without focusing, left-click focus only, launcher middle-click exclusion, disabled tabs, and rejection of other-output, removed, unknown, null/undefined, and non-Niri targets. No real close requests were sent. The helper's sandbox-blocked IPC listener did not affect assertions. `make check` passes. Live DMS middle-click delivery, application close prompts, and dynamic workspace removal after closing its last window remain to be verified; no plugin reload, shell restart, or desktop configuration change was performed for this update. Helper QML caching remains the documented compatibility limit.

## Open/close tab movement

The strip previously animated its natural width but replaced every Repeater delegate on each window snapshot, so neighbors jumped on open/close. `WindowModel.tabModelChanges` now computes incremental remove/insert/move operations by live Niri ID. `WindowStrip` applies those edits to a ListModel and updates roles in place. Row move transitions animate surviving tab positions; add transitions fade in new wrappers without overriding the button's disabled opacity. Moves also finish any interrupted entrance opacity. Closed tabs leave immediately; close requests and compositor updates are never delayed.

Inspected DMS 1.6.2's `Common/Theme.qml` and `DankCommon/Common/ListViewTransitions.qml`; this horizontal Row uses theme duration/easing and null transitions when animations are disabled, matching DMS's zero-duration avoidance. The startup marker includes `tab movement loaded` to identify the new helper. Existing proportional widths, output filtering, click actions, workspace entrance, and overall width animation remain.

`make check` includes an additional model regression for mixed opens, closes, reorderings, empty state, snapshot-only updates, and survivor identity preservation. An isolated offscreen Quickshell helper used the actual strip/button logic with stub DMS visuals and verified intermediate x positions during open/close, survivor delegate identity, insert opacity, title snapshots, rapid removal/reordering, interrupted fades completing, disabled-animation snapping, and empty-state cleanup. Existing isolated workspace-transition and actual middle/left mouse-event checks also pass. The helpers' sandbox-blocked IPC listeners did not affect assertions; they made no compositor calls. Live DMS feel, overflow during movement, sibling repositioning in the host bar, and helper-cache refresh remain pending. No live plugin reload, shell restart, or desktop configuration change was performed.

## Adjustable tab width

The default proportional scale is now 240 pixels per monitor-wide window, reduced from 270 (about 11%). `NavigationSettings` uses the inspected DMS 1.6.2 `SliderSetting` API for `tabWidth`, with a 120–480 pixel range and 240 default. `NavigationWidget` passes saved changes reactively to the strip. The pure model clamps the scale to that range and falls back to 240 for invalid values. Each tab keeps its independent readability minimum; the setting does not change the strip's maximum-width control.

`make check` covers default/custom scales, both range boundaries, invalid values, proportional widths and scroll offsets, and stable widths as other windows change. Live settings persistence and appearance at the new scale remain pending; no live plugin reload, shell restart, or desktop configuration changes were performed.

## Dragging tabs to reorder windows

Inspected the active DMS 1.6.2 `NiriService.focusWindow`, `send`, `handleWindowFocusChanged`, and `handleWindowLayoutsChanged`, plus the installed Niri 26.04 swap action help, [IPC action definitions](https://github.com/niri-wm/niri/blob/v26.04/niri-ipc/src/lib.rs), and [scrolling layout implementation](https://github.com/niri-wm/niri/blob/v26.04/src/layout/scrolling.rs). Niri's cross-column swap targets the neighboring column's active tile; selecting that tile before refocusing the source is required for stacked columns. In the same column, MoveWindowUp/Down exchanges adjacent tiles. These actions depend on focus, so the adapter waits for DMS's focused-window snapshot before dispatch and for the expected ID order afterward. It rechecks the next action against current layout metadata before dispatch. No second IPC connection or compositor polling was added.

`NavigationButton` distinguishes a platform-threshold left drag from a click, retains the mouse grab over a Flickable, and suppresses clicks after dragging. `WindowStrip` provides the moving tab, animated neighbor preview, outside-drop cancellation, and a 16 ms edge-scroll timer limited to the gesture. Existing arrow browsing remains. Drops send source/target IDs and before/after placement to `NiriState`; the adapter plans one adjacent step at a time and stops on invalid state, request rejection, explicit interaction, or a 1.5-second per-stage timeout. New drag gestures are disabled while a reorder is pending. Tabs still follow reactive Niri order rather than a saved local order. The startup marker now includes `tab dragging`.

`make check` includes drop-midpoint tests, action selection/invalid-target guards, and all insertion combinations across a representative mix of stacked and standalone columns, checking final order and unaffected workspace data. Isolated offscreen Quickshell/QtTest helpers exercised actual mouse press/move/release, tab visual following, drop delivery and click suppression, multi-step focus/layout acknowledgment sequencing, existing click/middle-close behavior, edge scrolling, outside drops, structural cancellation, user interruption, removed IDs, output changes, socket rejection, and timeout without an unacknowledged move. The helpers used mocked DMS services and stub visuals; their sandbox-blocked IPC listeners did not affect assertions and no real windows were moved.

Live Niri reorder behavior remains unverified. Acceptance needs moves in both directions, stacked/tabbed columns, overflow on each output, fullscreen/maximized columns, external focus/layout changes, and rapid follow-up gestures. Column swaps can change a window's dimensions and stack membership while preserving each column's window count. Focus-dependent IPC actions are not atomic: an external compositor action between the confirmed focus and the next request can still interfere; the adapter cancels on an unexpected resulting snapshot but cannot roll back a completed swap. Partial successful steps remain in Niri if a later step is canceled. No live plugin reload, shell restart, or desktop configuration edits were performed; the existing helper-cache limit still applies.

## Neighbor preview and mouse-down focus

Dragging now translates neighboring tab visuals into the proposed insertion order, using `WindowModel.tabDragOffsets` and the existing DMS 1.6.2 theme duration/easing. Target thresholds remain tied to compositor tab geometry, so the preview cannot feed back into hit testing. Tab widths and the live model stay unchanged during the gesture. The placement marker and its unused boundary output were removed. A dropped preview remains until the adapter finishes or cancels, allowing animated row movement and preview offsets to settle together as Niri confirms the order. Cancellation restores the original positions.

Window tabs opt into `NavigationButton.activateOnPress`; a left press emits focus once, and mouse-up does not emit another activation. Accessibility press, middle-click close, and launcher/arrow release actions remain. Press tracking defers automatic viewport reveal until release so reactive focus updates cannot shift the held tab underneath the cursor.

`make check` covers neighbor offsets in both directions, variable widths, original-slot/no-op behavior, invalid targets, and unaffected compositor order. Isolated offscreen Quickshell/QtTest helpers verified actual mouse-down focus before release, no duplicate focus on mouse-up, intermediate neighbor positions, reverse dragging, unchanged unrelated tabs, retained gap through drop confirmation, outside cancellation, disabled-animation snapping, middle-close/launcher timing, and reactive focus updates preserving the held tab's viewport position before revealing it after release. These used the actual strip/button logic with stub theme visuals and simulated state; their sandbox-blocked IPC listeners did not affect assertions. Visible DMS/Niri behavior remains pending. No live reload, shell restart, or desktop configuration edits were performed; existing helper caching and focus-dependent IPC limits still apply.

## Earlier drag preview

The neighbor preview now triggers when the dragged tab's leading edge overlaps 50% of a neighboring tab's width, in either direction. The initial 25% edge-overlap threshold felt too eager and was increased to 40%, then 50% at the user’s request; the original pointer-midpoint behavior was slower still. `WindowStrip` passes the dragged tab's left edge in content coordinates, accounting for the mouse grab offset and overflow scroll. Targeting remains independent of animated preview positions. Returning across the threshold restores the earlier slot; staying in the original position does not reorder anything.

`make check` covers the exact 50%-overlap thresholds in both directions, returning across a threshold, variable widths, original-slot behavior, and invalid IDs. An isolated offscreen Quickshell/QtTest helper also verified actual mouse motion crossing the earlier threshold and intermediate neighbor animation in both directions, with stub visuals and no compositor calls. Its sandbox-blocked IPC listener did not affect assertions. Visible feel in DMS remains to be verified; no live reload, shell restart, or desktop configuration changes were performed.

## Opaque held tabs

Window tabs opt into `NavigationButton.opaqueBackground` while pressed or dragged. A fully opaque DMS surface sits beneath the existing highlight, preserving selected and hovered colors while covering overlapping titles. The property resets through existing release and cancellation handling.

`make check` passes. An isolated offscreen Quickshell/QtTest helper verified actual mouse presses and dragging keep the background alpha at one even with a translucent theme surface, neighbors remain unaffected, and release restores normal styling. It also verified the current 50% overlap preview in both directions. Stub visuals and simulated window state do not establish visible DMS behavior; live validation remains pending. No live reload or shell restart was performed.

## Overflow arrows during growth

Adding a fitting window briefly showed overflow controls because arrow visibility compared the final tab width against the strip’s still-expanding animated width. `WindowStrip` now uses the smaller of animated and live content demand for that comparison. Growth tracks the width animation; removal stops demanding space immediately. The actual assigned host width remains the overflow limit.

An isolated offscreen Quickshell helper reproduced the flash before the change and passed afterward, sampling arrow visibility throughout a fitting addition. It also checked final natural width, real overflow at the configured ceiling, arrow removal after shrinking, a narrower host allocation, and a host too narrow for arrow controls. `make check` passes. This uses stub DMS visuals; visible validation in the running host remains pending. No live shell reload, restart, or desktop configuration changes were performed.

## Stable positions during right-edge addition

A newly focused rightmost window was revealed against the temporarily smaller viewport during strip growth. This scrolled earlier tabs out of place and progressively reversed that offset as the viewport expanded. `revealActive` now clamps without following focus during content-width growth, then reveals once growth finishes. Animated content-width updates also schedule reveal, ensuring capped strips still reveal the active window after the viewport stops widening. Manual browsing and held-tab guards remain in effect.

An isolated offscreen Quickshell helper reproduced intermediate displacement before the change and verified earlier-tab positions stay fixed throughout a fitting, focused right-edge addition afterward. It checked intermediate animation samples, absence of arrow flashes, final natural width, focus reveal after capped growth, narrower host overflow, and the narrow-host arrow guard. `make check` passes. This used stub DMS visuals; visible running-host verification remains pending. No live shell reload or restart was performed.

## Flipped default scrolling direction

The `reverseScroll` default is now false in settings, the widget’s absent-value fallback, the strip, and the pure wheel model. With DMS reverse scrolling off, up/left focuses the previous column and down/right the next. Explicit saved preferences remain honored. Model tests verify the new default, both axes, accumulated input, and composition with DMS and widget reversal; `make check` passes. No desktop settings were edited.
