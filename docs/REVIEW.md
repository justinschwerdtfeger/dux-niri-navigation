# Full-history review — 2026-09-30

Reviewed every existing commit, all tracked implementation files, tests, and documentation. API checks used the active DMS 1.6.2 embedded UI at `/run/user/1000/danklinux-shell/fc3c244a314d77c8`, including the Niri service, plugin host/pill, launcher service, theme text, and icon resolver. The review preserves the current window-strip milestone; workspace navigation and icon assignments remain pending.

| Commit | Review |
| --- | --- |
| `4d281b9` — scaffold | Reviewed packaging, service boundary, diagnostic views, settings, and initial design. Later prototype work already corrected the original settings-ID injection assumption and replaced diagnostic horizontal content. The remaining vertical count is explicitly diagnostic. |
| `f63c73c` — top-bar prototype | Output/ID filtering and stable proportional widths have useful regression coverage. Found overflow browsing interrupted by snapshot replacement, an unsupported launcher fallback, automatic rich-text interpretation in the standard tooltip, and a missing accessibility action on the custom button. |
| `5dabbf5` — QML tooling | Syntax validation did not exercise refresh behavior. Found destructive source/destination overlap, loss of the previous setup on scanner failure, and weak metadata validation. Added staged publication and recovery tests. |

## Changes

- Preserve manual overflow browsing across title, geometry, and window-list updates. Focus changes resume following the active window. Extract scroll-offset calculation into the pure model and test bounds, variable widths, oversized tabs, removal, and manual browsing.
- Use the inspected DMS 1.6.2 launcher API directly. The removed `openSpotlight` fallback does not exist in the verified source; older shells are not promised compatibility.
- Render tooltip titles literally, including HTML-looking strings. DMS's existing `StyledText` already defaults to plain text; the explicit title setting documents that contract. Add an accessibility press action that respects the button's enabled state.
- Validate tooling prerequisites and reject source/tooling overlap before copying. Generate metadata in a temporary staging directory, check every required module, dereference scanner links, then publish with rollback. Scanner errors, missing metadata, timeouts, and publication failures preserve the previous setup. Keep existing JSON/JSONC editor preferences untouched.
- Add tooling behavior tests to `make check`; preserve all existing stable-width regressions. Remove resolved design questions and update validation documentation.

## Validation and remaining work

`make check` passes fourteen window-model tests and eight tooling tests plus packaging, syntax, and whitespace checks. A real tooling refresh succeeded against the installed embedded source. An isolated nonvisual Quickshell helper using the existing Wayland backend reported all five plugin QML components ready without instantiating the plugin, panels, or desktop services, or restarting DMS. The host component needs that backend for `PanelWindow`; the other four components also loaded offscreen.

Live interaction remains unverified for these changes: drag/arrow browsing while titles and geometry update, automatic scrolling after focus changes, literal tooltips, accessibility activation, and launcher clicks. Shared bars still need a configured width cap because DMS exposes no per-widget remaining-width contract. The workspace rail and shared session-local workspace icons require a future implementation and runtime validation.
