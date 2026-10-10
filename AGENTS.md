# Agent guidance

## Start here

Read `README.md`, `docs/DESIGN.md`, and `docs/DEVELOPMENT.md` before changing behavior. Keep current contracts and validation limits accurate. Use Git history for past experiments instead of appending a development diary to the docs.

## Product contracts

- This is a DMS plugin for Niri: window icons/titles on horizontal bars and workspace icons on vertical bars. Preserve the established visual style while fixing usability, bugs, and DMS inconsistencies.
- Scope both lists to the hosting output. Include its trailing empty workspace. Use live Niri IDs for identity and workspace indices only for order; IDs are not persistent across compositor sessions.
- Keep unnamed dynamic workspaces. Icon choices must never name or retain them. Persist favorite symbols only; assignments are session-local and disappear with their workspaces.
- Window tabs show exact titles without an app-name label; floating windows are excluded. Use a stable monitor-based width scale and an individual readability minimum. Never normalize by the list or smallest window; retain those regressions.
- Reuse DMS’s launcher, theme, settings, icons, and tooltips. A launch can activate an existing window. Do not add a compositor fork, complete shell, persistent workspace model, or browser tab-detaching extension without an explicit scope change.

## Implementation

- Inspect the installed **and active** DMS source before changing internal APIs. Record the inspected revision/version. The current baseline is DMS 1.6.2, Quickshell 0.3.1, Niri 26.04.
- Keep compositor-service access in `NiriState.qml` and section/layout assumptions in `BarGeometry.qml`. Prefer reactive DMS state over polling or another Niri IPC connection.
- Keep transformations and reorder acknowledgment logic in pure JS models. Share ID-based ListModel updates through `ModelUtils`; preserve delegates and avoid unchanged role writes.
- Prefer clear code and measured reductions in work over compressed one-line implementations. Use the configured formatters rather than introducing another style.
- Do not edit `.agents/`, `.codex/`, `.aws/`, unrelated projects, or desktop configuration during routine repo work. Session authorization can explicitly extend this boundary; record any external changes separately.

## Validation and handoff

- Run `make check` after changes. Use `make dev-up` and `make dev-check` if host tools are missing; the devcontainer supplies the complete toolchain. Missing lint tools must fail explicitly, not be silently skipped. `make test` provides model/bridge/tooling checks without Qt imports.
- Run `make test-qml` for interactive/model integration changes when the Qt Quick runner is available. Use meaningful behavior tests for filtering, widths, delegate identity, reordering, and workspace lifetime; avoid source-text assertions.
- Distinguish lint/component/isolated checks from visible DMS/Niri verification. Never claim static compilation proves actual bar behavior.
- Do not start/restart the desktop shell for static checks. Plugin reload can retain cached helper components; restart the existing shell only when runtime validation needs it and session changes are authorized.
- Navigation buttons keep explicit text geometry because Qt Quick Controls labels previously rendered blank in the real host. Preserve mouse-down focus, middle close, keyboard activation, and DMS theme behavior.
- The active DMS UI is embedded under `/run/user/1000/danklinux-shell/`; discover its current path from logs after upgrades. A legacy Quickshell symlink does not establish the active source.
- Record remaining compatibility/visible checks in `docs/DEVELOPMENT.md` and review results in `docs/REVIEW.md`. `docs/CONFIGURATION.md` records external user-authorized work and is not a routine setup checklist.
