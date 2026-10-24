# Navigation design

## Scope

Build navigation on top of DMS, inspired by Material Shell. Keep Niri as the source of truth for windows, layout, focus, and workspace lifetime. Use DMS bars, theme components, settings, launcher, and tooltips. This project does not own desktop configuration, a compositor fork, or a separate persistent workspace model.

Window Tabs (`justinNavigation`, retained for settings compatibility) and Workspaces (`justinWorkspaces`) are separate DMS widgets. Each follows its hosting bar's orientation; role is independent of orientation. Scope both to the hosting output. IDs identify live Niri objects; indices only describe order. IDs are not persistent across compositor sessions.

## Boundaries

`NiriState.qml` is the only consumer of DMS’s internal compositor services. It guards actions against live membership and adapts reactive snapshots to pure models. `BarGeometry.qml` isolates the DMS section-layout assumptions. `NavigationHost.qml` shares button-local hover bindings and axis-aware space budgets; `NavigationWidget.qml` owns tabs/launcher and `WorkspaceWidget.qml` owns the rail/picker. Keep those DMS dependencies out of the pure models and navigation views.

The root manifest is a Window Tabs composite with ordinary widget and optional sidebar daemon surfaces; `workspace-plugin/` contains the workspace manifest and thin QML wrappers. Its `shared -> ..` symlink makes imports work through DMS's installed plugin link without copying components. Install the entire checkout; the workspace folder is not a standalone package. QML resolves singleton identity by module URL: only workspace instances access `WorkspaceIcons`, and only window instances access `BrowserFavicons`. Sidebar instances use the root window module URL and share its favicon subscriber. This prevents duplicate workspace stores or favicon subscribers across entry paths.

`ModelUtils.syncRows` reconciles a QML ListModel by ID. It removes obsolete rows, inserts/moves rows, and writes only changed roles. Both views share it. Unchanged snapshots preserve delegates and avoid unnecessary notifications. Workspace assignments similarly retain object identity until their contents change.

## Window strip

Filter tiled windows on the workspace active on the hosting output. Sort by Niri column, tile, then ID; positionless tiled windows follow positioned ones. Display the window’s exact title; a blank title uses “Untitled window”. The tooltip may include the app name, but the tab label does not.

Horizontal tabs and optional rotated vertical titles use `preferredWidth × visualWindowWidth / monitorWidth`, with an individual readability minimum. Prefer Niri’s decorated tile width, then client width, then a monitor-wide fallback. Never normalize by the window list or smallest window: adding or resizing one tab must not enlarge unrelated tabs. Vertical bars default to square icons with full-title tooltips. Optional normal title rows fill the bar width and use a compact uniform height; wider bars do not inflate row height. Rotated titles turn toward the screen interior on left/right bars.

Content uses the host-provided `widgetThickness` on either cross axis. The plugin never binds a pill to the full `barThickness`: Dux owns inset, background, segmented styling, padding, and outlines. The fork’s zero inset can still make widgets reach the bar edges. Bar views receive the sizes computed by `PluginComponent`: `iconSizeLarge` for window app icons, `iconSize` for workspace symbols, and `textSize` for tab/launcher/overflow text. These honor the bar’s icon/font scale and maximize preferences independently of widget inset. Horizontal/rotated readability minimums include the scaled icon and text; normal title rows remain uniform and compact while accommodating their content where width permits. Scaled artwork may extend into the inset up to the full bar thickness, as native widgets do; scroll-view cross-axis bounds include that space while button backgrounds retain widget thickness. Uniform vertical row lengths grow when needed to fit scaled icons. The picker and standalone sidebar keep their existing independent sizing. Bar button backgrounds inherit Dux’s `BarPillSurface` and use `BarMetrics.widgetStyle` for native resting/pressed rounding, with Dux owning the rounding animation. Inner buttons remain separate like native RunningApps, while the host pill owns joined section corners. The icon picker and standalone sidebar explicitly retain their established generic radius. Shared controls use Dux 2.0’s `qs.DCommon.Widgets`, with shell-specific `DTooltip` and `DPopout` from `qs.Widgets`.

Natural length grows with content up to available host space, along either axis. Reserve siblings, occupied neighboring sections, gaps, and actual pill padding. Empty center containers do not constrain growth. A pixel limit applies when filling available bar space is disabled. The controls grid has one column when only the launcher is visible and three columns for horizontal overflow, avoiding an extra empty-column gap that clips fitting tabs. Arrows reserve space only during real overflow; hosts too narrow for arrows retain the launcher and direct dragging. Hosts smaller than the launcher itself remain a DMS layout limitation.

Focus on left press, with no repeated activation on release. Middle-click requests ID-targeted close; apps may prompt before closing. Wheel input preserves complete steps and partial remainders without a timed cooldown. The plus button calls the existing DMS launcher, which chooses the globally focused monitor and may activate an existing application window.

Follow the active tab unless the user browses overflow manually, holds a tab, or is reordering. Resume following when focus changes. During strip growth, clamp the scroll offset and defer reveal until growth settles, preventing temporary displacement of earlier tabs. Workspace entrance and tab movement follow DMS duration/easing and snap when animations are disabled.

## Standalone sidebar

Stock DMS 1.6's bar Size slider changes inner padding (-8 to 24), leaving roughly 40 px of widget width at its maximum. Normal title rows in a conventional vertical widget therefore cannot become a readable wide sidebar through that GUI. Use a plugin-owned Quickshell `PanelWindow` for independent width; do not patch DMS's padding formula or create another desktop shell.

`SidebarDaemon` loads the existing plugin settings and creates one `SidebarPanel` per selected live Quickshell screen. Off creates no panels/NiriState instances. A missing selected output never falls back to a different screen. DMS owns daemon load/unload; removing a screen or disabling the mode destroys its panel. `SidebarModel` sanitizes preferences and computes visual/reserved width. The panel stays on the chosen edge and uses Wayland exclusive zones, leaving arrangement with other panels to the compositor.

Always-visible mode shows normal title rows and reserves the full width. Expandable mode starts as a 48-pixel icon rail. Its title width defaults to 240 px, accepts 160–480 px, and is capped at half the monitor. Overlay mode keeps the reserved area at 48 px while the panel grows over application windows; push mode changes the exclusive zone with expansion. Each screen has its own session-local expansion state; preferences are plugin-wide.

`SidebarView` reuses `WindowStrip` without a second window-list implementation or another Niri connection. A dedicated button expands/collapses; Escape collapses without dispatching a window action. Optional hover opening waits 200 ms; leaving waits 400 ms. Stop both timers during a press, drag, or compositor acknowledgment, then reconsider hover when the interaction finishes. Brief pointer crossings cannot open the panel, and leaving during a reorder cannot collapse its held preview. Click mode stays expanded until the button or Escape closes it. Expansion changes panel width and title visibility without switching the strip’s layout mode. Animate one shared width using `Theme.shortDuration` and `Theme.standardEasing`, as DMS’s inline tray does. Derive title opacity from that width. The Wayland surface keeps the full configured width throughout the animation; its input region follows only the visible panel so transparent space passes input through. Align the visible panel to the chosen edge within that surface. Overlay retains its fixed rail reservation; push reservation changes only with the expansion target, letting Niri animate the work-area change without per-frame configure/layout requests. Keep fading titles alive until collapse finishes. Reversals start from the current width, and disabled DMS animations snap. Keep the same 36 px rows, icon source sizes, surviving delegates, and manual scroll offset through hover collapse/reopening; resizing every icon can cause image reloads and flashing.

The sidebar is optional and disabled by default. Bar widget placement is independent, so users can retain or remove duplicate tab views in DMS's GUI. Native monitor scope and exclusive-zone sizes are verified on DP-2. Visual placement, tooltip anchors around neighboring bars, hover, and keyboard focus still require real-host acceptance in addition to the isolated component tests. DMS’s built-in plugin toggle forwards to each selected panel; pinned/Off modes ignore it, and active presses/drags/reorders hold expansion.

## Dragging and acknowledgment

Start a drag after the platform threshold. The grabbed tab follows the pointer; neighbors open a gap when its leading edge overlaps 50% of their primary length. Use original geometry for targeting so animations do not feed back into hit testing. Map grab offsets from the unrotated delegate wrapper, including for rotated buttons. Edge scrolling runs only during a gesture. Outside drops cancel; structural list/workspace/output changes cancel an active gesture. Orientation/display changes cancel previews, reset overflow, and reveal the active tab after layout settles.

Animate each tab’s absolute visual position once. A one-row/one-column Grid supplies layout geometry; a compensating translation on the delegate wrapper renders the animated position along the active axis. This avoids combining separate layout and preview animations during Niri acknowledgment. Retain the dropped preview and the dragged tab’s stacking/background until reordering completes or cancels.

`ReorderModel.js` is a pure state machine. For each adjacent exchange, await source focus, then expected layout. Across columns, first focus the neighboring tile because Niri swaps with that column’s active tile. `NiriState` dispatches each requested action and owns the 1.5-second per-stage timeout. Repeated snapshots never resend a swap.

Cancel on missing IDs, unexpected order/layout, unavailable compositor, changed output/workspace, explicit navigation/close, dispatch rejection, or timeout. Successful earlier steps remain after cancellation. Focus-dependent IPC is not atomic; external compositor actions can still race with dispatch. Cross-column swaps preserve column window counts but can change window dimensions and stack membership. There is no saved local window order.

## Workspace rail and picker

Show the output’s workspaces in index order, including the trailing empty workspace. Empty active workspaces follow normal Niri lifetime; do not delete or name them to attach an icon.

`state/WorkspaceIcons.qml` shares session-local assignments across instances. Reconcile against all outputs so one monitor cannot discard another’s assignments. The first observed window seeds a category; the lowest window ID approximates the earliest window when joining an existing session. Floating windows can seed icons. Keep the seed after closure, and remove assignments only when IDs leave state. Compositor unavailability clears them. Reused IDs without an unavailable snapshot remain a compatibility limit.

Use DMS’s monochrome Material Symbols through `DIcon`. The 336-pixel picker has padded content, a 264-pixel all-icons grid, search, and bounded pinned favorites. Selection stays open; right-click pins/unpins. Only ordered favorite symbol names persist. Until its own favorite setting exists, Workspaces reads the legacy `justinNavigation` favorites; saving even an empty list overrides that fallback. There is no automatic-reset action. Anchor the popup with DMS’s `getPopupTriggerPosition` using the actual top/bottom/left/right bar edge. Close stale editing on workspace removal/output movement.

The rail keeps delegates and manual scroll through unchanged snapshots; active-workspace, viewport, and scaled row-length changes reveal the selected row after pending layout updates. Orientation changes may recreate ListView delegates. Bound horizontal width and vertical height by the hosting section and scroll overflow on the selected axis. Buttons support keyboard activation and visible focus feedback.

## Favicons

One QML singleton owns a read-only Python/Gio subscriber to TabCtl owner and tab events. Match active Helium tab titles to live Helium window titles across all outputs/profiles, stripping only the final ` - Helium` suffix. Browser window IDs are unrelated to Niri IDs. Duplicate titles may share artwork only when every candidate agrees on a nonempty source; missing or conflicting candidates fall back. Never infer browser identity from focus or ordering.

Qt loads browser-provided HTTP(S) URLs without browser cookies. The bridge materializes bounded inline images in a private temporary directory and removes files no longer referenced by any profile. Keep the app icon until a favicon is ready; restore it on error. Favicon snapshots update independently of tab geometry/model identity.

The TabCtl 2.3.0 compatibility workaround performs one read two seconds after tab events. It cannot cover later favicon-only updates; the event producer needs the notification fix. There is no recurring tab polling or another Niri connection.

## Compatibility and acceptance

The development target is Dux 2.0.0 fork revision `0bd677b2` (including configurable widget inset) and Quickshell 0.3.1. Previous native acceptance used DMS 1.6.2 and Niri 26.04; it does not establish Dux 2.0 appearance. Internal host APIs and helper caching require rechecking after DMS upgrades. The current validation matrix and remaining visible checks live in [Development](DEVELOPMENT.md); past experiments remain in Git history.
