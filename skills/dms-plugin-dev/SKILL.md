---
name: dms-plugin-dev
description: Create, modify, or debug Dux Niri Navigation's Dux Shell bar widgets, settings, and optional sidebar daemon. Covers Dux 2.0 host sizing and shared widgets; use the repository development workflow for verification.
---

# Dux Shell plugin development

Adapted from Dux Shell's [plugin skill](https://github.com/justinschwerdtfeger/dux-shell/blob/0bd677b2/.agents/skills/dms-plugin-dev/SKILL.md), inspected at fork revision `0bd677b2` (Dux 2.0.0 plus configurable widget inset). This project-scoped version covers the surfaces used here. Read `AGENTS.md`, `README.md`, `docs/DESIGN.md`, and `docs/DEVELOPMENT.md` first; preserve their navigation and workspace-lifetime contracts.

## Host and geometry

- Widget surfaces inherit `PluginComponent` from `qs.Modules.Plugins`. Define distinct `horizontalBarPill` and `verticalBarPill` components; unload inactive content. Composite plugins declare each surface in the manifest's `components` map; single-surface plugins use `component`.
- The host injects `axis`, `section`, `parentScreen`, `widgetThickness`, `barThickness`, `barSpacing`, `barConfig`, `pluginId`, `pluginService`, and reactive `pluginData`. Inspect the target host source before depending on internal properties.
- Size the content's cross axis from `widgetThickness` in both orientations. `barThickness` is the complete bar and remains appropriate for popup positioning and host text/icon scaling. Never override a pill's thickness to reach the bar edges. The fork's `widgetInset` setting controls this for each bar, including zero inset.
- Dux owns the pill background, segmentation, padding, and outlines. Individual navigation buttons own their hover/cursor behavior. Keep section ancestry and budget assumptions in `BarGeometry.qml`; do not copy them into views or compositor models.
- A bar's primary extent already excludes its frame margins. Subtract actual host pill padding once, and reserve neighbors and section spacing. Growing widgets must not measure their own section to set their size.

## Dux 2.0 components

- Import shared controls from `qs.DCommon.Widgets`: `DIcon`, `DTextField`, `DScrollbar`, and `StyledText`. Shell-specific `DTooltip` and `DPopout` remain in `qs.Widgets`. Avoid deprecated `Dank*` wrappers.
- Use `Theme` from `qs.Common` for colors, typography, radii, and motion. Verify property names against the target revision. Keep navigation text's explicit geometry and existing focus/press/close/drag semantics when replacing controls.
- `DTextField` exposes `text`, `placeholderText`, `leftIconName`, and `showClearButton`; `DIcon` exposes `name`, `size`, and `color`. `DScrollbar` attaches through Qt Quick Controls' `ScrollBar` properties.
- `DTooltip.show(text, x, y, screen, leftAlign, rightAlign)` and `hide()` manage native tooltips. `DPopout` accepts `content`, `popupWidth`, `popupHeight`, and `screen`; anchor with `SettingsData.getPopupTriggerPosition` and `setTriggerPosition`, passing the actual edge and source item.

## Settings and services

- Settings entries inherit `PluginSettings` and explicitly set their manifest's `pluginId`. Use native `SelectionSetting`, `ToggleSetting`, and `SliderSetting`; declare `settings_write` permission. Keep existing IDs and setting keys compatible.
- `pluginData` is reactive. Save preferences with `pluginService.savePluginData`; guard null services. Persist favorite symbols only. Workspace assignments stay session-local and disappear with their live Niri IDs.
- Use Dux's existing launcher and `NiriState.qml`'s reactive compositor boundary. Do not introduce polling or another Niri IPC subscriber. Daemons follow Dux's load/unload lifecycle; the standalone sidebar remains opt-in.

## Verify and hand off

Run `make check` and `make test-qml` using the documented devcontainer if needed. Refresh QML metadata from the source revision being targeted. Mocked Qt tests establish component behavior; test real host appearance, padding, segmentation, tooltips, and Niri interactions separately. Record inspected revisions and remaining visible checks in `docs/DEVELOPMENT.md`, and review findings in `docs/REVIEW.md`. Installing plugins or changing desktop settings is separate from repository development.
