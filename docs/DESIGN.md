# Navigation design

## Decisions

Use a plugin on top of DMS, with Niri retaining control of tiling, focus, scrolling, and dynamic workspace lifetime. Use DMS's existing bars, theme, launcher, and settings.

The target is a top strip of windows and a left rail of workspaces. Initially, one widget can render different content in horizontal and vertical bars. Confirm that independently configured instances and shared state behave correctly before adding icon editing.

## Window strip

Show windows on the workspace active on the hosting bar's output, not necessarily the globally focused output. Order tiled windows by Niri's column and tile indices. Define a stable fallback for floating windows or missing layout metadata. Clicking a title focuses that window by ID.

Long titles must elide, and many windows must have bounded overflow. Test DMS's host sizing before choosing scrolling, a maximum-width strip, or an overflow menu. Do not let a growing list push other bar controls off screen.

The plus button invokes DMS's existing launcher. Niri handles placement; application behavior and window rules can affect whether a new window appears and where it goes.

## Workspace rail

Show the output's workspaces in Niri order. Preserve normal dynamic workspace behavior, including the trailing empty workspace. An ordinary empty workspace can remain while active; do not forcibly delete workspaces or equate every empty workspace with an immediately removed one.

Use workspace IDs for session-local icon assignments. Remove an assignment when its workspace leaves Niri's state. Do not key icons by numeric position or persist runtime IDs across sessions. Icons across multiple widget instances need shared session state; choose that mechanism in the workspace milestone.

A rail plus button can focus the existing trailing empty workspace. Do not create persistent named workspaces to simulate a blank workspace.

## Milestones

1. **Load the scaffold:** validate horizontal/vertical placement, settings, service updates, and error-free reload in the actual DMS session.
2. **Window navigation:** add output-aware filtering, layout ordering, title buttons, focused state, bounded overflow, and launcher action.
3. **Workspace navigation:** add output-aware workspace buttons and active state while preserving dynamic lifetime.
4. **Workspace icons:** add editing and shared session-local assignments, with cleanup on workspace removal.
5. **Polish:** keyboard access where supported, hover labels, urgency indication, and multi-monitor/reconnect behavior.

## Open implementation questions

- How much space does DMS make available to a plugin in each bar section?
- Which host API should determine the workspace active on a particular monitor?
- Should floating windows appear after tiled windows or in a separate group?
- Which DMS launcher action reliably opens on the hosting bar's output?
- How should two plugin instances share ephemeral icons without saving stale IDs?

Resolve these by inspecting upstream code and testing small changes, without expanding into unrelated shell features.
