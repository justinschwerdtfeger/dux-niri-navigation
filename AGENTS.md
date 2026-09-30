# Agent guidance

## Read first

Read `README.md`, `docs/DESIGN.md`, and `docs/DEVELOPMENT.md` before implementation. Keep them accurate as behavior changes.

## User intent

Build a DankMaterialShell plugin for Niri, inspired by Material Shell's navigation paradigm. The user wants a top window-title strip and a left workspace-icon rail, not a recreation of Material Shell's entire desktop. They prefer unnamed dynamic workspaces that disappear when empty. Noctalia v5 was considered; DMS is the selected starting point for this repository.

## Implementation boundaries

- Reuse DMS services and theme components. Keep internal Niri-service dependencies in `NiriState.qml` rather than spreading them throughout the UI.
- Inspect the installed DMS source or a specific upstream revision before using APIs. DMS internals may differ across releases; document the version actually tested.
- Use Niri IDs for live identity. Workspace indices can change, and IDs should not be assumed to persist across compositor sessions.
- Scope future window/workspace lists to the hosting bar's output. The scaffold's global counts are diagnostics only.
- Do not name workspaces merely to attach icons. Icons should not change workspace lifetime.
- Prefer reactive DMS state over polling or creating another IPC connection.
- Reuse the existing launcher for the plus button. Launching an app can activate an existing window; do not promise every launch creates a new window.
- Do not introduce a compositor fork, full shell, or persistent workspace model without an explicit scope change.
- Do not edit `.agents/`, `.codex/`, `.aws/`, or system/user desktop configuration as part of routine repository work.

## Validation and handoff

Run `make check` for changes to the scaffold. Validate interactive QML in DMS when available; distinguish static checks from runtime verification. Do not start/restart a full shell just to perform a static check. Use meaningful model tests when implementing filtering, ordering, or workspace lifecycle behavior; avoid tests that merely assert source text.

Record unfinished behavior and compatibility limits in the docs. Never claim the current diagnostic widget implements the planned navigation.
