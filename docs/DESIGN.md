# Navigation design

## Decisions

Use a plugin on top of DMS, with Niri retaining control of tiling, focus, scrolling, and dynamic workspace lifetime. Use DMS's existing bars, theme, launcher, and settings.

The target is a top strip of window icons and titles and a left rail of workspaces. Initially, one widget can render different content in horizontal and vertical bars. Confirm that independently configured instances and shared state behave correctly before adding icon editing.

## Window strip

Show tiled windows on the workspace active on the hosting bar's output, not necessarily the globally focused output. Order tiled windows by Niri's column and tile indices. Exclude floating windows; use stable ID ordering for tiled windows missing layout metadata. Clicking an icon focuses that window by ID. Tabs show the window’s exact title beside its icon, without an added application label. Blank titles use “Untitled window”, not the app ID.

Many windows must have bounded overflow; long titles remain available on hover. Test DMS's host sizing before choosing scrolling, a maximum-width strip, or an overflow menu. Do not let a growing list push other bar controls off screen.

The first implementation uses a horizontally flickable icon/title strip with arrow controls and a fixed plus button. Full-width growth defaults on, replacing the former 45% monitor cap. The natural content width grows with the list up to the hosting bar’s content-width ceiling, minus actual pill padding, sibling widget widths, and gaps. It does not stretch short lists. Disabling full-width growth restores the configurable pixel maximum. The DMS 1.6.2 adapter uses the actual content area after host margins, subtracts other visible widgets in the same section, and reserves occupied neighboring sections. Empty center containers do not constrain growth. Center placement uses a symmetric budget around the bar midpoint; unusual DMS centering modes still need live validation. DMS 1.6.2's `sectionAvailablePrimarySize` is not a remaining-width contract and is not used; `BarGeometry.qml` isolates the inspected section ancestry and geometry dependencies. A newly active window is scrolled into view. Arrows or dragging suspend active-window following until focus changes, so title/layout snapshots do not interrupt manual browsing. Geometry changes clamp the offset and reveal the active tab only while following it. Positionless tiled windows follow positioned windows in ID order; floating windows are excluded. Arrows are hidden until tabs plus the launcher exceed the width ceiling; only then do they reserve space. An empty strip has just the launcher button, with no label or extra gaps.

The plus button invokes DMS's existing launcher. Niri handles placement; application behavior and window rules can affect whether a new window appears and where it goes.

The inspected launcher APIs choose the globally focused output and take no screen argument. The plugin preserves that behavior for now; it does not force monitor focus when opening the launcher.

Buttons use the hosting bar’s full `barThickness`, centered by DMS’s unclipped content loader. A scoped binding sets the horizontal host pill’s `widgetThickness` to `barThickness`, so its background and outline also fill the height. The host pill is identified by its content component rather than child order; vertical instances retain DMS sizing. The DMS Size control sets bar height, whereas widget padding is horizontal for this plugin.

## Workspace rail

Show the output's workspaces in Niri order. Preserve normal dynamic workspace behavior, including the trailing empty workspace. An ordinary empty workspace can remain while active; do not forcibly delete workspaces or equate every empty workspace with an immediately removed one.

Use workspace IDs for session-local icon assignments. Remove an assignment when its workspace leaves Niri's state. Do not key icons by numeric position or persist runtime IDs across sessions. Icons across multiple widget instances need shared session state; choose that mechanism in the workspace milestone.

A rail plus button can focus the existing trailing empty workspace. Do not create persistent named workspaces to simulate a blank workspace.

## Milestones

1. **Load the scaffold:** validate horizontal/vertical placement, settings, service updates, and error-free reload in the actual DMS session.
2. **Window navigation:** implemented output-aware filtering, layout ordering, title buttons, active state, bounded overflow, and launcher action; rendering verified in DMS 1.6.2; click and overflow interaction checks remain.
3. **Workspace navigation:** add output-aware workspace buttons and active state while preserving dynamic lifetime.
4. **Workspace icons:** add editing and shared session-local assignments, with cleanup on workspace removal.
5. **Polish:** keyboard access where supported, hover labels, urgency indication, and multi-monitor/reconnect behavior.

## Open implementation questions

- How much space does DMS make available to a plugin in each bar section?
- Which DMS launcher action reliably opens on the hosting bar's output?
- How should two plugin instances share ephemeral icons without saving stale IDs?

Resolve these by inspecting upstream code and testing small changes, without expanding into unrelated shell features.

## Proportional icon/title tabs

Use DMS `Paths.getAppIcon`, desktop-entry lookup, and Quickshell `IconImage` (as used by DMS’s focused-window widget); unresolved icons receive a generic window icon. Show the exact window title beside the icon, eliding long text. Do not prepend or append the app name. Titles supplied by applications are not heuristically rewritten; titles and hover labels render literal plain text, including strings that resemble HTML.

Use Niri `layout.tile_size[0]` (visual width including compositor decorations), falling back to `window_size[0]` if necessary. Width data remains in the Niri adapter's pure model. Floating windows do not enter the strip model.

Use a fixed scale of 270 tab pixels per monitor-width window. Each tab independently has a readability minimum of 96 pixels (or 1.5 times button height plus 24 if larger). Tiny tabs therefore depart from exact ratios, but adding, shrinking, or removing one window never changes another window's width. Missing geometry uses a monitor-wide fallback, also independent of the list. The prior average/minimum-based shared scale caused unrelated tabs to expand and must not be restored.

Recalculate scroll offsets from accumulated variable widths, and reveal the active tab after geometry changes. Overflow scrolls within the configured strip ceiling. Stacked windows in one column appear as separate tabs with their individual widths; this is not a two-dimensional layout map.

## Editor tooling

Language-server imports use a local source snapshot and metadata generated by Quickshell’s own scanner, preserving JavaScript helpers and assets needed by relative imports. Nested UI components declare bound creation scopes so outer IDs resolve explicitly in both Qt and the language server. This editor-only helper never instantiates DMS services; generated metadata is persistent across reboot and refreshed explicitly after upgrades. Refreshes stage the snapshot and metadata before replacing the previous setup. Source/tooling path overlap is rejected, and generation or publication failures preserve the previous artifacts. See the development guide.
