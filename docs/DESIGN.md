# Navigation design

## Scope

Build navigation on top of DMS, inspired by Material Shell. Keep Niri as the source of truth for windows, layout, focus, and workspace lifetime. Use DMS bars, theme components, settings, launcher, and tooltips. This project does not own desktop configuration, a compositor fork, or a separate persistent workspace model.

The same plugin renders a window strip on horizontal bars and a workspace rail on vertical bars. Scope both to the hosting output. IDs identify live Niri objects; indices only describe order. IDs are not persistent across compositor sessions.

## Boundaries

`NiriState.qml` is the only consumer of DMS’s internal compositor services. It guards actions against live membership and adapts reactive snapshots to pure models. `BarGeometry.qml` isolates the DMS section-layout assumptions. `NavigationWidget.qml` integrates the host pill, launcher, settings, and workspace popup. Keep those DMS dependencies out of the pure models and navigation views.

`ModelUtils.syncRows` reconciles a QML ListModel by ID. It removes obsolete rows, inserts/moves rows, and writes only changed roles. Both views share it. Unchanged snapshots preserve delegates and avoid unnecessary notifications. Workspace assignments similarly retain object identity until their contents change.

## Window strip

Filter tiled windows on the workspace active on the hosting output. Sort by Niri column, tile, then ID; positionless tiled windows follow positioned ones. Display the window’s exact title; a blank title uses “Untitled window”. The tooltip may include the app name, but the tab label does not.

Each width is `preferredWidth × visualWindowWidth / monitorWidth`, with an individual readability minimum. Prefer Niri’s decorated tile width, then client width, then a monitor-wide fallback. Never normalize by the window list or smallest window: adding or resizing one tab must not enlarge unrelated tabs.

Natural width grows with content up to available host space. Reserve siblings, occupied neighboring sections, gaps, and actual pill padding. Empty center containers do not constrain growth. A pixel limit applies when full-width growth is disabled. Arrows reserve space only during real overflow; hosts too narrow for arrows retain the launcher and direct dragging. Hosts smaller than the launcher itself remain a DMS layout limitation.

Focus on left press, with no repeated activation on release. Middle-click requests ID-targeted close; apps may prompt before closing. Wheel input preserves complete steps and partial remainders without a timed cooldown. The plus button calls the existing DMS launcher, which chooses the globally focused monitor and may activate an existing application window.

Follow the active tab unless the user browses overflow manually, holds a tab, or is reordering. Resume following when focus changes. During strip growth, clamp the scroll offset and defer reveal until growth settles, preventing temporary displacement of earlier tabs. Workspace entrance and tab movement follow DMS duration/easing and snap when animations are disabled.

## Dragging and acknowledgment

Start a drag after the platform threshold. The grabbed tab follows the pointer; neighbors open a gap when its leading edge overlaps 50% of their width. Use original geometry for targeting so animations do not feed back into hit testing. Edge scrolling runs only during a gesture. Outside drops cancel; structural list/workspace/output changes cancel an active gesture.

Animate each tab’s absolute visual position once. The Row supplies layout geometry; a compensating translation renders the animated position. This avoids combining separate row and preview animations during Niri acknowledgment. Retain the dropped preview and the dragged tab’s stacking/background until reordering completes or cancels.

`ReorderModel.js` is a pure state machine. For each adjacent exchange, await source focus, then expected layout. Across columns, first focus the neighboring tile because Niri swaps with that column’s active tile. `NiriState` dispatches each requested action and owns the 1.5-second per-stage timeout. Repeated snapshots never resend a swap.

Cancel on missing IDs, unexpected order/layout, unavailable compositor, changed output/workspace, explicit navigation/close, dispatch rejection, or timeout. Successful earlier steps remain after cancellation. Focus-dependent IPC is not atomic; external compositor actions can still race with dispatch. Cross-column swaps preserve column window counts but can change window dimensions and stack membership. There is no saved local window order.

## Workspace rail and picker

Show the output’s workspaces in index order, including the trailing empty workspace. Empty active workspaces follow normal Niri lifetime; do not delete or name them to attach an icon.

`state/WorkspaceIcons.qml` shares session-local assignments across instances. Reconcile against all outputs so one monitor cannot discard another’s assignments. The first observed window seeds a category; the lowest window ID approximates the earliest window when joining an existing session. Floating windows can seed icons. Keep the seed after closure, and remove assignments only when IDs leave state. Compositor unavailability clears them. Reused IDs without an unavailable snapshot remain a compatibility limit.

Use DMS’s monochrome Material Symbols through `DankIcon`. The 336-pixel picker has padded content, a 264-pixel all-icons grid, search, and bounded pinned favorites. Selection stays open; right-click pins/unpins. Only ordered favorite symbol names persist. There is no automatic-reset action. Anchor the popup with DMS’s `getPopupTriggerPosition` so it clears the hosting bar. Close stale editing on workspace removal/output movement.

The rail keeps delegates and manual scroll through unchanged snapshots; active-workspace and viewport changes reveal the selected row. Buttons support keyboard activation and visible focus feedback.

## Favicons

One QML singleton owns a read-only Python/Gio subscriber to TabCtl owner and tab events. Match active Helium tab titles to live Helium window titles across all outputs/profiles, stripping only the final ` - Helium` suffix. Browser window IDs are unrelated to Niri IDs. Duplicate titles may share artwork only when every candidate agrees on a nonempty source; missing or conflicting candidates fall back. Never infer browser identity from focus or ordering.

Qt loads browser-provided HTTP(S) URLs without browser cookies. The bridge materializes bounded inline images in a private temporary directory and removes files no longer referenced by any profile. Keep the app icon until a favicon is ready; restore it on error. Favicon snapshots update independently of tab geometry/model identity.

The TabCtl 2.3.0 compatibility workaround performs one read two seconds after tab events. It cannot cover later favicon-only updates; the event producer needs the notification fix. There is no recurring tab polling or another Niri connection.

## Compatibility and acceptance

The inspected baseline is DMS 1.6.2, Quickshell 0.3.1, and Niri 26.04. Internal host APIs and helper caching require rechecking after DMS upgrades. The current validation matrix and remaining visible checks live in [Development](DEVELOPMENT.md); past experiments remain in Git history.
