# Agent guidance

## Read first

Read `README.md`, `docs/DESIGN.md`, and `docs/DEVELOPMENT.md` before implementation. Keep them accurate as behavior changes.

## User intent

Build a DankMaterialShell plugin for Niri, inspired by Material Shell's navigation paradigm. The user now wants a top window-icon-and-title strip with widths proportional to visual window sizes (no added app-name label), and a left workspace-icon rail, not a recreation of Material Shell's entire desktop. They prefer unnamed dynamic workspaces that disappear when empty. Noctalia v5 was considered; DMS is the selected starting point for this repository.

## Implementation boundaries

- Reuse DMS services and theme components. Keep internal Niri-service dependencies in `NiriState.qml` rather than spreading them throughout the UI.
- Inspect the installed DMS source or a specific upstream revision before using APIs. DMS internals may differ across releases; document the version actually tested.
- Use Niri IDs for live identity. Workspace indices can change, and IDs should not be assumed to persist across compositor sessions.
- Scope window/workspace lists to the hosting bar's output. The vertical rail includes the hosting output’s trailing empty workspace.
- Do not name workspaces merely to attach icons. Icons should not change workspace lifetime.
- Prefer reactive DMS state over polling or creating another IPC connection.
- Reuse the existing launcher for the plus button. Launching an app can activate an existing window; do not promise every launch creates a new window.
- Do not introduce a compositor fork, full shell, or persistent workspace model without an explicit scope change.
- Do not edit `.agents/`, `.codex/`, `.aws/`, or system/user desktop configuration as part of routine repository work.

## Validation and handoff

Run `make check` for changes to the scaffold. Validate interactive QML in DMS when available; distinguish static checks from runtime verification. Do not start/restart a full shell just to perform a static check. Use meaningful model tests when implementing filtering, ordering, or workspace lifecycle behavior; avoid tests that merely assert source text.

Record unfinished behavior and compatibility limits in the docs. The horizontal window strip and workspace rail/icon picker are implemented; visible rail validation and broader automatic icon categories remain pending. Do not claim compilation checks establish visible bar behavior. The running shell's config can differ from the installed DMS package; inspect both when diagnosing compatibility.

## DMS 1.6.2 compatibility findings

- The running service uses the embedded UI extracted under `/run/user/1000/danklinux-shell/`, rather than the legacy Quickshell config symlink. Discover the active path from logs after upgrades.
- Plugin reload can retain cached helper QML components. A successful reload is not proof that helper edits loaded. Restart the existing shell only when runtime validation requires it and the user has authorized session changes.
- Navigation buttons use explicit label geometry because the former Qt Quick Controls buttons rendered blank labels in the real host.
- See `docs/CONFIGURATION.md` for the user-authorized desktop config audit; do not repeat those external edits during routine repository work.

- Tab widths use a fixed monitor-based scale and an individual readability minimum. Never normalize by the current window list or smallest window: that caused unrelated tabs to grow when a small window was added or resized. Keep the regression tests for this behavior.
