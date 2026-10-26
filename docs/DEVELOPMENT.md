# Development and validation

## Dependencies and checks

Runtime: Niri, Dux Shell 2.0, and Quickshell 0.3.1. Favicons additionally need system Python with PyGObject/Gio and a connected TabCtl Helium extension/helper. Native development needs Python 3.11+, Node.js 22.13+ (or 24+), npm, Ruff, ShellCheck, and Qt QML tools matching the Qt runtime.

The [devcontainer](#devcontainer) supplies the complete toolchain without installing it on the desktop. For native setup:

```bash
npm ci
python3 -m pip install -r requirements-dev.txt
python3 scripts/setup-qml-tooling.py --dms-source /path/to/active/dms/ui
make check test-qml
```

| Target           | Verification                                                                                          |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| `make test`      | Packaging, pure JS models, Python bridge, installation and development tooling                        |
| `make lint`      | ESLint, Ruff lint/format, Prettier, JS-library formatting, ShellCheck, shell syntax, patch whitespace |
| `make check-qml` | Zero-warning QML lint on assembled packages and formatting of canonical QML sources/tests             |
| `make check`     | All three targets above                                                                               |
| `make test-qml`  | Real plugin components under offscreen Qt Quick Test with mocked Dux services                         |
| `make format`    | Configured Python, JS/JSON/Markdown and QML formatters                                                |

Missing tools fail explicitly. `SHELLCHECK`, `QMLTESTRUNNER`, `QMLLINT`, and `QMLFORMAT` can select binaries outside PATH; lint/format tools also use `qtpaths6` discovery. Node dependencies and Ruff are pinned. These tools are not runtime dependencies.

QML lint has three narrowly scoped metadata exceptions: `Qt.styleHints.startDragDistance`, the process-exit enum parameter, and Quickshell's runtime `PanelWindow` factory. The last suppresses only the root type declaration; panel properties remain checked. Each suppression explains the metadata gap. QML library directives are handled by the ESLint processor and Prettier wrapper; top-level library exports are allowed while unused locals remain errors.

Behavior tests cover output filtering, exact titles and independent widths, workspace lifetime and icon assignment, delegate identity and unchanged role writes, acknowledgment-driven reordering, favicon agreement, subscriber recovery, and tooling rollback. Qt tests add actual pointer gestures on both axes, focus/close timing, naturally acquired Escape focus, event-order permutations for sidebar holds, overflow and active-item reveal, native scale/style/inset/padding bindings, all four picker edges, and fractional workspace hit targets. These are component checks, not visible Dux/Niri verification.

## Independent plugin packages

`make package` builds `dist/justinNavigation/` and `dist/justinWorkspaces/`, plus archives named from their independent manifest versions. `PLUGIN=window-tabs` or `PLUGIN=workspaces` selects one. Runtime files are copied into each package with local imports; no source-tree symlinks or sibling-plugin imports remain. IDs and saved setting keys stay compatible.

The packager rejects source/output overlap and foreign output directories, and removes stale files only in selected generated packages. Tests extract each archive separately and verify dependency closure, entry points, relocation, and rebuild isolation. Installation tests use temporary configuration trees and cover either plugin alone, repeated linking, preserved conflicts/legacy links, and duplicate IDs under arbitrary folder names, alternate symlinks, and BOM-prefixed manifests. See [Loading](LOADING.md) before migrating a live installation.

`make test`, `make check-qml`, and `make test-qml` build packages first. Pure-model tests execute source libraries. QML lint uses assembled packages; formatting uses canonical files under `plugins/`, `shared/`, and `tests/qml/`. Qt tests run from relocated bundle/fixture copies, followed by smoke runs with only one plugin present. They do not instantiate the real Wayland sidebar panel or connect to Niri.

## Devcontainer

The container runs as `developer` with the checkout at `/workspaces/dux-niri-navigation`. It supplies Node/npm, Python/Gio, pinned Ruff, ShellCheck, Qt tools, Qt Quick Test, and Quickshell. Its creation hook runs `npm ci` and generates persistent Dux imports. It has no desktop display socket, session bus, or user configuration mounts.

```bash
make dev-up
make dev-check
devcontainer exec --workspace-folder "$PWD" make format
devcontainer exec --workspace-folder "$PWD" bash
```

`make dev-up` starts the container and completes setup. For linked Git worktrees it mounts the common Git metadata directory at its original absolute path, so `git diff --check` resolves the repository. `make dev-check` runs `make check test-qml`. If the CLI is absent, pass `DEVCONTAINER='npx --yes @devcontainers/cli@0.89.0'` to both Make commands. `CONTAINER_ENGINE` selects the engine; Docker is the verified engine.

VS Code's **Dev Containers: Reopen in Container** uses the same image/setup. In a linked worktree, run `make dev-up` first so the extra Git mount exists before attaching. An older container created without that mount must be recreated; do not remove a container carrying unrelated work.

After changing the Dockerfile or copied requirements, rebuild this checkout's disposable container with `make dev-up DEVCONTAINER_UP_ARGS=--remove-existing-container`. This retains the worktree mount arguments. Save any container-local work first. Generated `.qmlls.ini` paths belong to the environment that last ran setup: rerun setup when switching between native and container development (`--dms-source /opt/dms/quickshell` in the container).

The Fedora 44 image is pinned by digest. The Dockerfile fetches Dux commit `0bd677b213a445d4012e37968f8beca0acd90012` directly and initializes its recorded `dux-qml-common` submodule (`ebf5e6c002da1bdaa4aaa2f319fea7b8507abc42`). It does not require a moving branch to remain at that commit. Quickshell is selected as 0.3.1 from the DMS Fedora COPR. Other Fedora packages follow release updates; the entire package set is not frozen. The reviewed container uses Qt 6.11.2 and Ruff 0.16.9. Change `DMS_COMMIT` deliberately when updating the compatibility baseline.

## Inspected baseline and host contracts

This review inspected pinned Dux **`0bd677b213a445d4012e37968f8beca0acd90012`**, Quickshell **0.3.1**, and local fork **`c5b058c83e6ac77420e43b8e7dd844a652cef679`**. The development environment has no usable installed desktop `dms` or active UI under `/run/user/1000/danklinux-shell/`. Those snapshots do not establish the user's running revision. On the desktop, discover the current embedded UI through `dms doctor` or service logs before changing internal APIs; a legacy Quickshell symlink is insufficient.

| Boundary              | Inspected contracts                                                                                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NiriState`           | `CompositorService.isNiri`; reactive `NiriService.windows`/`allWorkspaces`; `send`, `focusWindow`, `switchToWorkspace`, `focusColumnLeft/Right`                   |
| `NavigationHost`      | `PluginComponent` injections and horizontal/vertical pills; `BasePill.content`, readonly `horizontalPadding`, hover/cursor controls; native icon/text sizes       |
| `BarGeometry`         | `SectionEntry.sectionContext`; section `entryRepeater`, `entryRevision`, spacing, center extents and native overflow-trigger size                                 |
| Buttons/views         | `BarPillSurface` and `BarMetrics.widgetStyle`; `Theme`, `Paths`, shared controls from `qs.DCommon.Widgets`; `DTooltip` and `DPopout` from `qs.Widgets`            |
| Entry points/settings | `openDankLauncherV2`; popup trigger positioning with actual edge/source item; native `PluginSettings` controls; ID-keyed plugin data and legacy favorite fallback |
| Sidebar               | Composite daemon lifecycle/settings; Quickshell `Variants`, `PanelWindow`, layer/keyboard focus, exclusive zones and `Region.item` input masks                    |

Keep compositor-service access in `NiriState` and host ancestry/layout assumptions in `BarGeometry`. Niri dispatch acceptance is not completion: reordering awaits reactive focus/layout snapshots with a 1.5-second per-stage timeout. Settings entries explicitly declare their manifest's `pluginId`; only favorites persist, never workspace IDs or assignments.

Dux owns widget thickness/inset, pill backgrounds, joined corners, outlines, padding snapping, and press rounding. `NavigationHost` optionally supplies a copied, thickness-compensated padding config to its pills; the default uses the live host config. Budgets reserve actual padding once, visible siblings, occupied neighboring sections, and native overflow triggers without measuring their own growing section. Multiple growing widgets and unusual host layouts still need visible acceptance.

Native `PluginComponent.iconSize`/`iconSizeLarge`/`textSize` supply scale/maximize settings. Artwork can extend into the full bar cross axis while backgrounds retain widget thickness. Workspace hit targets align to the actual host origin, reading ancestor positions to account for centered-loader rounding at fractional sizes. Window tooltips clear the full bar thickness on all four edges. Sidebar and picker sizing remain independent.

Column scrolling composes the plugin's reverse option with the hosting bar's workspace-switcher option through `SettingsData.widgetOption`/`barWidgetEntry`. The launcher uses Dux's globally focused output and can activate an existing application window. Existing DMS 1.6 observations are historical; there is no current 1.6 compatibility claim.

## QML editor imports

Use the official Qt QML editor extension if desired. `scripts/setup-qml-tooling.py` snapshots the selected Dux UI into ignored `.local/dms-tooling`, runs Quickshell's scanner through an empty offscreen helper, and publishes persistent imports plus `.qmlls.ini`. The scanner discovers the `qs` tree without importing Dux's native-display singleton graph. Include the `quickshell/DCommon` submodule when using source checkouts.

The snapshot retains JS helpers/assets and dereferences temporary scanner symlinks. Failed generation/publication preserves working imports. Source/tooling overlap and generated-path symlinks are rejected; existing VS Code settings are preserved. Refresh after Dux upgrades or moving the checkout, then run **Qt: Restart QML Language Server**. Do not globally disable diagnostics to hide dynamic-object warnings.

## Favicons

The read-only subscriber uses TabCtl protocol v2, `dev.slastra.TabCtl.Helium` and profile suffixes 2–16, `dev.slastra.TabCtl.Browser`, `ListTabsWithIcons` (`a(iissibbs)`), `TabsUpdated`, and owner changes. It emits active-tab titles/IDs/icon sources without page URLs or inactive tabs. Late replies cannot repopulate replaced owners; burst events coalesce. Failed processes clear state and retry after 30 seconds. Inline images are bounded and removed once unreferenced across all profiles.

Inspected TabCtl helper: **v2.3.0-5-ge033643**; original extension: **2.3.0**. That extension omits favicon-only notifications. One read two seconds after tab events helps but cannot guarantee freshness. The user's separately patched **2.3.0.1** build delivered a delayed icon to the visible DMS 1.6 strip; see [Configuration](CONFIGURATION.md) for the authorized external patch. Store installations need a release containing that notification fix.

Only the `helium` app ID is supported. Exact titles must agree across profiles; conflicting/missing icons fall back. Qt loads HTTP(S) images without browser cookies. Customized titles/incognito suffixes, browser-internal URLs, authenticated images, Qt loading errors, and caching at unchanged URLs can also use stale or fallback artwork. A historical snapshot matching 12 windows established matching only at that instant.

For a live favicon-only regression:

```bash
python3 -m http.server 8766 --bind 127.0.0.1 --directory tests/manual
```

Open `http://127.0.0.1:8766/late-favicon.html` in Helium. Its title/URL stay fixed while the icon changes red to green after six seconds, beyond the compatibility read. Confirm the strip follows both colors; the button repeats the change. Stop the server afterward. Distinguish matching, notification delivery, and Qt image loading.

## Runtime acceptance

Run in the existing Dux/Niri session after loading the changed packages. Repository checks never start/restart the desktop shell or migrate configuration. Helper QML can survive plugin reloads; restart the existing shell only with session authorization.

For the Dux Niri Navigation rename, visible confirmation of the **Window Tabs** and **Workspaces** names after rebuilding and rescanning remains pending. Legacy IDs, installation links, package ownership markers, and layer namespaces are preserved; the rename requires no desktop settings migration.

1. Record installed and active revisions. Inspect logs for imports, missing properties, binding loops and exceptions; reload success alone does not prove new helpers loaded.
2. Exercise both plugins at all four bar edges with default/positive/zero inset, fractional output scales, native styles, outlines, padding overrides, icon/font scales and maximize options. Confirm fitting-tab containment, full-cross-axis workspace clicks/right-clicks, gaps/outside boundaries, native tooltips and picker placement. The earlier runtime report of missed workspace edge clicks remains unverified after the component correction.
3. Check each output's active workspace, exact titles, floating exclusion, trailing empty workspace, custom/seeded icons and removal lifetime. Install either archive alone and verify settings survive legacy-link migration.
4. Add/remove/resize tiled windows; inspect independent widths, stable growth, crowded sections, native overflow parking/menus, fit-to-widgets bars and multiple growing instances.
5. Drag using actual pointer gestures in horizontal, vertical-icon, normal-title, rotated-title and sidebar layouts. Check grab offset, overlap targets, autoscroll, outside cancellation, acknowledgments, external changes, rapid gestures and disabled animations. Verify focus on press, middle close, keyboard activation, scrolling, manual overflow and launcher behavior.
6. Exercise icon search/selection/pinning, favorite fallback/persistence, popup dismissal, workspace removal and output movement. Icon choices must never retain unnamed workspaces.
7. Test sidebar left/right placement with existing bars and selected/disconnected monitors. Confirm Off removes panels/reservations; pinned, overlay and push modes reserve the correct widths. Check click/hover delays, entering/leaving during a hold, held controls, Escape after a real expand-button click, keyboard focus, animation reversal and transparent-area click-through. Hover alone must not acquire keyboard focus.
8. Verify late Helium favicons with the fixture above.

[Review](REVIEW.md) records the current audit and validation. Earlier native acceptance used DMS 1.6.2/Niri 26.04: top tabs, the left workspace rail, sidebar hover collapse and late favicon delivery were user-confirmed, and temporary DP-2 tests established sidebar output scope and overlay/push reservations. Those results predate Dux 2.0. Current native smoothness, input masks, exclusive zones, host appearance and reorder races remain unverified. Historical authorized desktop changes/backups remain in [Configuration](CONFIGURATION.md); prior implementation experiments remain in Git history.
