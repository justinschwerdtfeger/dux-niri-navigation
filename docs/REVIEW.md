# Codebase review

Justin Window Tabs (`justinNavigation`) and Justin Workspaces (`justinWorkspaces`) target Dux Shell 2.0.0, including the user's configurable widget inset. The development source is pinned to fork revision `0bd677b213a445d4012e37968f8beca0acd90012`; its common widget submodule is `ebf5e6c002da1bdaa4aaa2f319fea7b8507abc42`.

## Current implementation

- Both widgets use the host's `widgetThickness` in either orientation. The old horizontal full-bar override is removed. Dux owns inset, pill/segment backgrounds, padding, and outlines; buttons retain their local hover and focus behavior.
- Controls use Dux 2.0's `DIcon`, `DTextField`, `DScrollbar`, and `StyledText` from `qs.DCommon.Widgets`, with `DTooltip` and `DPopout` from `qs.Widgets`. The picker passes its source item when positioning the popup.
- `BarGeometry` reads Dux 2.0 section entries and spacing to reserve siblings, the native overflow trigger, and occupied neighboring sections, ignoring its own changing extent and an empty center. Actual pill padding is subtracted once.
- The project [plugin skill](../skills/dms-plugin-dev/SKILL.md) adapts the fork's widget guidance and is linked from `AGENTS.md`. Tooling and the devcontainer target the same fork and `DCommon` imports.
- Column scrolling uses Dux 2.0’s `focusColumnLeft/Right` and per-bar reverse-scroll option. The link helper installs into Dux’s `dms/plugins` directory without touching legacy paths.
- Existing output scope, live IDs, dynamic workspace lifetime, exact titles, proportional widths, reorder acknowledgment, keyboard activation, middle close, and optional standalone sidebar contracts remain in force.

## Validation

`make check` and `make test-qml` pass in this checkout’s Dux 2.0 devcontainer: 59 JavaScript tests, 19 Python tests, all linters/formatters, zero-warning QML lint, and 45 Qt Quick passes (including initialization/cleanup). The project skill also passes `skill-creator`’s validator. The Qt regression suite covers injected thickness at top/bottom/left/right edges with default, positive, and zero-inset-sized content; reactive host updates; local hover/cursor behavior; and sibling/section/padding/overflow-trigger budgets on both axes. Existing model and interaction regressions remain enabled.

This development container has no installed or running desktop shell. The pinned source and mocked component tests do not establish the user's active fork revision or visible Dux/Niri behavior. Default/zero/positive inset, pill/segment/rectangle styles, outlines, crowded bars, native overflow, fit-to-widgets mode, tooltip and picker placement, and drag acknowledgment still require the live checks in [Development](DEVELOPMENT.md#runtime-acceptance).

Previous native acceptance used DMS 1.6.2 with Niri 26.04: the user confirmed top tabs, the left workspace rail, sidebar hover collapse, and late favicon delivery. Temporary sidebar tests established output scope and overlay/push reservations. Those observations predate this Dux migration. Historical setup changes and backups are recorded in [Configuration](CONFIGURATION.md); earlier implementation experiments remain in Git history.

## Independent review

The requested read-only sub-agent review found one P2 issue: Dux's separately created native overflow button was missing from the space budget. Horizontal and vertical regressions reproduced an over-allocation of 42 px (30 px trigger plus 12 px gap). The adapter now reserves Dux's `overflowTriggerSize` whenever `overflowCount > 0`, including before the button finishes incubation. Tests exercise a full strip beside an always-overflow sibling and a trailing section, multiple hidden entries sharing one trigger, and release of its reservation when overflow disappears. No other actionable findings were reported. The correction passes the complete check suite and both new regressions.
