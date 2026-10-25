# Development and validation

## Dependencies and checks

Runtime: Niri, DMS, and its supported Quickshell. Favicons additionally need system Python with PyGObject/Gio and a connected TabCtl Helium extension/helper. Development: Python 3.11+, Node.js 22.13+ (or 24+), npm, Ruff, ShellCheck, and Qt QML tools matching the system Qt version.

Use the [devcontainer](#devcontainer) to supply these development dependencies without installing them on the desktop. For a native setup:

```bash
npm ci
python3 -m pip install -r requirements-dev.txt
python3 scripts/setup-qml-tooling.py --dms-source /path/to/active/dms/ui
make check
```

| Target           | What it verifies                                                                                     |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| `make test`      | Plugin packaging; pure model behavior; Python bridge and tooling recovery                            |
| `make lint`      | ESLint, Ruff lint/format, Prettier, JS-library formatting, ShellCheck, shell syntax, diff whitespace |
| `make check-qml` | `qmllint` with generated DMS imports; `qmlformat` consistency                                        |
| `make check`     | All three targets above                                                                              |
| `make test-qml`  | Actual plugin components under Qt Quick Test with mocked DMS services                                |
| `make format`    | Applies configured Python, JS/JSON/Markdown, and QML formatting                                      |

Missing tools fail explicitly; checks must not silently skip a language. `SHELLCHECK`, `QMLTESTRUNNER`, `QMLLINT`, and `QMLFORMAT` can point to binaries outside PATH. Qt host tools are also discovered through `qtpaths6`. Node dependencies are locked in `package-lock.json`; Ruff is pinned in `requirements-dev.txt`. Development dependencies are not plugin runtime dependencies.

QML lint allows zero warnings. Three local exceptions cover incomplete Qt/Quickshell metadata: `Qt.styleHints.startDragDistance`, the process-exit signal's enum parameter, and the public `PanelWindow` type's runtime platform factory being described as an uncreatable base interface. The last exception covers only the root type declaration in `SidebarPanel`; its properties remain checked. Each suppression explains its scope. `.qmlformat.ini` fixes indentation, wrapping, and Unix newlines while preserving import and property order.

QML library directives are understood by the ESLint processor and the small Prettier wrapper. Top-level QML library functions are exports; ordinary local unused variables remain errors. Pure-model tests execute the actual libraries, including relative QML JS imports. Tests cover stable independent widths, output filtering, dynamic workspace lifecycle, delegate identity, every small-list edit permutation, favicon agreement, and acknowledgment-driven reorder sequencing.

`make test-qml` uses an offscreen Qt Quick Test runner with lightweight theme/visual stubs and mocked compositor requests. It does not load DMS desktop services or move real windows. It exercises real ListModels, buttons, focus/close timing, overflow, shared workspace assignments, dispatch rejection, and timeout. Both actual plugin entry points are instantiated, including the workspace shared-module symlink. Tests cover all vertical title modes, a wide normal-title bar, axis changes, vertical drop acknowledgment, horizontal workspace overflow, all four picker edges, and legacy favorites. These tests establish component behavior, not real DMS appearance.

Sidebar tests exercise the real `SidebarView` and tab buttons: click/hover activation, delayed hover cancellation, opening/closing held through interaction, keyboard collapse, focus/close dispatch, delegate preservation, animated hover collapse/reopening with retained overflow position and stable row/icon geometry at two font sizes, intermediate widths/title fades, interruption/reversal, constant native surface width and overlay reservation during motion, one target-based push reservation, disabled animations, empty workspaces, and pure model tests for reservation/monitor selection. The offscreen runner does not instantiate the actual Wayland panel or prove exclusive-zone behavior.

## Devcontainer

The checked-in container runs as `developer`, with the repository mounted at `/workspaces/justin-shell`. It installs ShellCheck, Qt QML tools and Qt Quick Test, Quickshell, Python/Gio, Node/npm, and pinned Ruff. Its creation hook runs `npm ci` and generates persistent DMS import metadata. The desktop's display sockets, session bus, and user configuration are not mounted; runtime acceptance still happens in the host DMS session.

From the host repository:

```bash
make dev-up
make dev-check
devcontainer exec --workspace-folder "$PWD" make format
devcontainer exec --workspace-folder "$PWD" bash
```

`make dev-check` runs `make check test-qml` in the running container. `make dev-up` creates/starts it and completes the setup hook. It also mounts the common Git directory at its original path so linked worktrees can run `git diff --check`. Use that target for linked-worktree startup; the editor's default mount alone is insufficient. The [Dev Container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli) provides access without opening an editor. `CONTAINER_ENGINE` and `DEVCONTAINER` override the Makefile's Docker/CLI executables; Docker was tested here.

After changing the Dockerfile or its copied requirements, rebuild through the same target so linked-worktree metadata remains mounted:

```bash
make dev-up DEVCONTAINER_UP_ARGS=--remove-existing-container
```

The Fedora 44 base image is pinned by digest. The Dux fork is fetched directly by commit and verified as `0bd677b213a445d4012e37968f8beca0acd90012` (2.0.0 plus configurable widget inset). Its `dux-qml-common` submodule is pinned by that commit to `ebf5e6c002da1bdaa4aaa2f319fea7b8507abc42`. Quickshell is selected as 0.3.1 from DMS's Fedora COPR. Other Fedora packages follow that release's updates; the whole package set is not frozen. The reviewed build has Qt 6.11.2, ShellCheck 0.11.0, Node 22.23.1, Python 3.14.8, and Ruff 0.16.9. Update `DMS_COMMIT` when changing the compatibility baseline.

Generated `.qmlls.ini` paths belong to the environment that last ran setup. When switching between native and container development, rerun `scripts/setup-qml-tooling.py` in that environment (`--dms-source /opt/dms/quickshell` inside the container), then restart the QML language server.

## Inspected baseline

The development source inspected for this change is the user’s **Dux 2.0.0** fork at `0bd677b213a445d4012e37968f8beca0acd90012`, including inset fix `d5f98f8c`. The local fork’s master at `c5b058c8` and the [2.0 release notes](https://duxlabs.dev/blog/v2-0-release) were also consulted. The devcontainer pins the stable fork and Quickshell **0.3.1**.

This development container has no installed `dms`, `/usr/share/quickshell/dms`, or active desktop under `/run/user/1000/danklinux-shell/`; installed/active source cannot be verified here. Previous desktop inspection used DMS **1.6.2**, Quickshell **0.3.1**, Niri **26.04**, and embedded UI `/run/user/1000/danklinux-shell/fc3c244a314d77c8`. Those are historical observations. Discover the current active source from `dms doctor` or service logs on the desktop before live acceptance; the legacy symlink and development snapshot do not establish the active revision.

Inspected internal contracts:

| Consumer            | DMS APIs/source                                                                                                                                                                                                                                                                                    |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NiriState`         | `CompositorService.isNiri`; `NiriService.windows`, `allWorkspaces`, `send`, `focusWindow`, `switchToWorkspace`, `focusColumnLeft/Right`                                                                                                                                                            |
| `NavigationHost`    | `PluginComponent` injections; distinct horizontal/vertical content components; `BasePill.content`, `widgetThickness`, `iconSize`, `iconSizeLarge`, `textSize`, hover/cursor controls; `Modules/DBar.BarPillSurface` and `BarMetrics.widgetStyle`                                                   |
| Widget entry points | `PopoutService.openDankLauncherV2`; `SettingsData.getPopupTriggerPosition` with actual bar edge; `DPopout`; legacy `PluginService.loadPluginData` favorite fallback                                                                                                                                |
| `BarGeometry`       | DankBar section ancestors, layout `widgetSpacing`, center `contentStart/contentSize`, actual pill padding; Dux 2.0 `SectionEntry.sectionContext`, section `entryRepeater` and `widgetSpacing`                                                                                                      |
| Views/settings      | DMS `Theme`, `StyledText`, `DIcon`, `DTooltip`, `DTextField`, `DScrollbar`, `PluginSettings`, `SelectionSetting`, `ToggleSetting`, `SliderSetting`, `Paths` icon/name helpers                                                                                                                      |
| Sidebar             | `PluginService` composite component resolution and daemon injection/load/unload; `SettingsData.getPluginSettingsForPlugin`; Quickshell 0.3.1 `Variants`, `PanelWindow`, Wayland layer/keyboard focus/exclusive zones; `Region.item` input masks as used by installed/active Niri overview surfaces |

Settings loaders inject `pluginService`, while each settings entry explicitly sets its `pluginId`. Keep those IDs consistent with their manifests. Window Tabs keeps `justinNavigation` and its existing setting keys for compatibility. Its composite manifest declares widget/daemon paths under `components`; Workspaces retains a single `component`. Sidebar preferences and vertical title display are plugin-wide, like the existing width/scroll preferences. Niri service actions return dispatch acceptance, not compositor completion. Reordering waits for reactive focus/layout snapshots and times out if acknowledgments never arrive.

Dux 2.0 renamed column navigation to `focusColumnLeft/Right` and moved reverse scrolling into the per-bar workspace-switcher options. Window Tabs follows that host option through `widgetOption`/`barWidgetEntry`, composing it with its existing plugin preference. The link helper now targets Dux’s `$XDG_CONFIG_HOME/dms/plugins` directory; it does not move or delete legacy installations.

The host adapters follow these Dux 2.0 contracts:

- `NavigationHost` passes `iconSize`, `iconSizeLarge`, and `textSize` through to buttons. These follow bar scale/maximize settings. Artwork can extend into the inset; button backgrounds keep `widgetThickness`. Picker and sidebar sizing are independent.
- `BarGeometry` reads `SectionEntry.sectionContext`, `entryRepeater`, and actual pill padding. `BarModel.primaryBudget` reserves occupied sections, siblings, spacing, and `overflowTriggerSize` when overflow is present. It never measures its own section to set its size. `sectionAvailablePrimarySize` is not a remaining-space contract.
- Workspace pointer targets fill the bar thickness while visible buttons retain their inset. Explicit ancestor-position reads account for centered-loader rounding at fractional sizes. Gaps and regions outside the bar stay outside the targets.
- Buttons inherit native `BarPillSurface` rounding and press animation. The host pill supplies joined corners. The picker and sidebar keep their existing radius overrides.
- The opt-in padding override gives each host pill a copied config with thickness-compensated `widgetPadding`. Dux still computes and snaps its readonly padding; the budget subtracts that value once. Disabling the override restores the live host config.
- Tooltip positions use the full `barThickness` on either axis. Pointer drags measure movement along the bar's axis in scene coordinates, including rotated labels.

The pinned Dux source and local fork `c5b058c83e6ac77420e43b8e7dd844a652cef679` were inspected for these contracts. Neither establishes the active desktop revision. Component tests cover all four edges, whole/fractional geometry, reactive sizing and scale changes, preserved delegates, pointer boundaries, native rounding, section overflow, config isolation, and restoring native padding. Pointer-event tests cover horizontal tabs, vertical icons/title rows, and left/right rotated titles; they complement direct drag-state tests.

## QML editor imports

Install the official **Qt QML** editor extension if desired. `scripts/setup-qml-tooling.py` snapshots the selected DMS UI into gitignored `.local/dms-tooling`, runs Quickshell’s metadata scanner in an empty offscreen helper, and publishes persistent imports plus `.qmlls.ini`. The empty helper imports only QtQuick/Quickshell: the scanner discovers the entire `qs` tree without importing Dux’s singleton graph (which requires a native display backend in 2.0). It does not instantiate desktop services or alter DMS. Include the `dux-qml-common` submodule (`quickshell/DCommon`) when using a source checkout.

The generated import tree retains JavaScript helpers and assets omitted by the scanner. It outlives `/run/user/` and the temporary scanner runtime. Failed generation/publication preserves the previous imports. Source/tooling overlap and generated-path symlinks are rejected. Existing VS Code settings are preserved.

Refresh after upgrading DMS or moving this repo. Then run **Qt: Restart QML Language Server**. Static dynamic-object warnings must be assessed against the host contract; disabling diagnostics globally hides genuine failures.

## Favicons

Inspected TabCtl source: `/var/home/justin/Documents/Builds/tabctl`, helper **v2.3.0-5-ge033643**, original packaged extension **2.3.0**, protocol **v2**. The user now runs the patched local extension **2.3.0.1**; `tabctl status` confirms Helium connectivity and compatible protocol. The subscriber uses `dev.slastra.TabCtl.Helium` and profile suffixes 2–16, interface `dev.slastra.TabCtl.Browser`, `ListTabsWithIcons` (`a(iissibbs)`), `TabsUpdated`, and D-Bus owner changes. It emits only active-tab titles/IDs/icon sources, excluding page URLs and inactive tabs.

Late replies cannot repopulate a replaced service owner. Burst events coalesce while a request is in flight. A failed subscriber clears state and retries after 30 seconds; this is process recovery, not tab polling. A disappearing startup profile does not stop discovery of other profiles. Unreferenced inline image files are removed as snapshots change.

TabCtl 2.3.0’s update listener ignores favicon-only changes. One delayed read after tab events helps but cannot guarantee freshness. A user-authorized fix in the separate TabCtl source adds favicon-change and completed-load notifications. The local test build is loaded in Helium, and a controlled late-icon change reached both the actual subscriber and the visible DMS strip. Store users still need an extension release containing the fix. See [Configuration](CONFIGURATION.md). The repository does not bundle or control a browser tab-detaching extension.

A live snapshot on 2026-10-10 matched all 12 Helium windows to nonempty HTTPS favicon sources. This establishes matching at that instant, not later notification delivery or image loading. Title-changing extensions, customized/incognito suffixes, conflicting duplicates, unsupported browser-internal image URLs, authenticated icons, and Qt loading errors may use the app-icon fallback. Only the `helium` app ID is supported. Favicon-only cache changes at an identical remote URL may also depend on Qt image caching.

For a controlled live regression, serve the manual fixture on the host:

```bash
python3 -m http.server 8766 --bind 127.0.0.1 --directory tests/manual
```

Open `http://127.0.0.1:8766/late-favicon.html` in Helium. Its title and URL stay fixed while its PNG favicon changes from red to green after six seconds, beyond the plugin's two-second compatibility read. Confirm the DMS window icon follows both colors; the button repeats a favicon-only change. Stop the server when finished. This isolates late notification delivery from title matching and remote image authentication.

## Runtime acceptance

Run these in the existing DMS session after loading the actual helper changes:

1. Inspect plugin logs for imports, missing properties, binding loops, and runtime exceptions. A successful reload alone is insufficient: DMS may retain helper QML in its cache. Restart the existing shell only with session-change authorization.
2. On Dux 2.0, click and right-click workspace buttons at both bar edges through a positive widget inset; check top/bottom and left/right bars, spacing between workspaces, and adjacent widgets. Check icon/font scale and maximize settings reactively, including large values on a small bar. Verify fitting tabs retain both rounded ends beside the launcher at fractional output scales. Check default/positive/zero **Widget inset**, padding, pill/segment/rectangle styles, outlines, and theme changes at all four edges. Confirm the content matches native widget thickness and stays centered. On each monitor, confirm output-scoped windows/workspaces, active highlighting, exact titles when enabled, app/favicon fallback, cross-axis hit targets, and native tooltips. Exercise each plugin on horizontal and vertical bars; test vertical icons, rotated titles on left/right, and normal titles on a wider bar.
3. Add/remove/resize tiled windows. Confirm independent proportional widths, stable fitting growth, real overflow arrows, crowded-bar budgets, and floating-window exclusion.
4. Drag both directions on each axis, across stacks/columns and overflow. Check grab position (including rotated titles), neighbor motion, drop acknowledgment, outside cancellation, external layout changes, and rapid follow-up gestures. Check animations disabled as well.
5. Verify focus on left press, one activation per press/release, ID-targeted middle close, wheel direction/fast steps, manual overflow preservation, keyboard focus, and launcher behavior.
6. Check workspace popup positioning/dismissal at all four bar edges, horizontal/vertical overflow, icon search/selection/pinning, legacy favorites and favorites after restart, workspace removal, and output movement. Confirm icon choices never retain unnamed workspaces.
7. Navigate Helium pages with late favicons. Distinguish title matching, TabCtl event delivery, and Qt image loading rather than treating all failures as the same problem.
8. Enable the standalone sidebar on each selected monitor. Verify left/right placement with existing bars, readable title widths, unavailable-output handling, and removal of its exclusive zone when Off. Check that always-visible mode reserves its full width; expandable overlay keeps the rail reservation; push mode resizes the work area. Exercise click/hover opening, short pointer crossings, Escape, tooltip position, keyboard focus, and held drag/reorder behavior before accepting the native surface.

The current evidence and independent review results are recorded in [Review](REVIEW.md). Static lint and isolated Qt tests do not establish visible Dux/Niri behavior. Live acceptance remains pending for inset and padding at fractional output scales, joined styles/outlines, native overflow and fit-to-widgets bars, multiple growing instances, actual pointer drags and compositor acknowledgment, tooltip/picker placement, and sidebar input masks/keyboard focus. The reported workspace-edge missed clicks still require a native retest after loading the changed helpers.

Previous native checks used DMS 1.6.2 and Niri 26.04: top tabs, the left workspace rail, sidebar hover collapse, late favicon delivery, and sidebar output scope/reservation had acceptance. These predate Dux 2.0. External changes/backups are recorded in [Configuration](CONFIGURATION.md); historical experiments remain in Git history. Compositor session changes that reuse IDs without an unavailable snapshot remain a compatibility limit.

## References

- [DMS plugin development](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [DMS source](https://github.com/duxlabs-dev/dux-shell)
- [Niri IPC](https://niri-wm.github.io/niri/niri_ipc/)
- [TabCtl](https://github.com/slastra/tabctl)
