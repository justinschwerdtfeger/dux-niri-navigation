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

`make dev-check` runs `make check test-qml` in the running container. `make dev-up` creates/starts it and completes the setup hook. VS Code's **Dev Containers: Reopen in Container** uses the same configuration. The [Dev Container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli) provides access without opening an editor. `CONTAINER_ENGINE` and `DEVCONTAINER` override the Makefile's Docker/CLI executables; Docker was tested here.

After changing the Dockerfile or its copied requirements, use **Rebuild Container**, or:

```bash
devcontainer up --workspace-folder "$PWD" --remove-existing-container
```

The Fedora 44 base image is pinned by digest. DMS is checked out at tag `v1.6.2`, and its commit is verified as `2db7646fe3ab47fddfdb8723f2da07d61a0d47ac`. Quickshell is selected as 0.3.1 from DMS's Fedora COPR. Other Fedora packages follow that release's updates; the whole package set is not frozen. The reviewed build has Qt 6.11.2, ShellCheck 0.11.0, Node 22.23.1, Python 3.14.8, and Ruff 0.16.9. Update the DMS tag/commit together when changing the compatibility baseline.

Generated `.qmlls.ini` paths belong to the environment that last ran setup. When switching between native and container development, rerun `scripts/setup-qml-tooling.py` in that environment (`--dms-source /opt/dms/quickshell` inside the container), then restart the QML language server.

## Inspected baseline

The installed and running UI are DMS **1.6.2**; Quickshell is **0.3.1**, Niri **26.04**. The running DMS service uses embedded UI at `/run/user/1000/danklinux-shell/fc3c244a314d77c8`; installed source is `/usr/share/quickshell/dms`. Discover the active path from `dms doctor` or service logs after upgrades instead of assuming a legacy config symlink controls the running shell.

Inspected internal contracts:

| Consumer            | DMS APIs/source                                                                                                                                                                                                                                                                                                     |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NiriState`         | `CompositorService.isNiri`; `NiriService.windows`, `allWorkspaces`, `send`, `focusWindow`, `switchToWorkspace`, `moveColumnLeft/Right`                                                                                                                                                                              |
| `NavigationHost`    | `PluginComponent` injections; distinct horizontal/vertical content components; `BasePill.content`, `widgetThickness`, hover/cursor controls                                                                                                                                                                         |
| Widget entry points | `PopoutService.openDankLauncherV2`; `SettingsData.getPopupTriggerPosition` with actual bar edge; `DankPopout`; legacy `PluginService.loadPluginData` favorite fallback                                                                                                                                              |
| `BarGeometry`       | DankBar section ancestors, layout `widgetSpacing`, center `contentStart/contentSize`, actual pill padding                                                                                                                                                                                                           |
| Views/settings      | DMS `Theme`, `StyledText`, `DankIcon`, `DankTooltip`, `DankTextField`, `DankScrollbar`, `PluginSettings`, `SelectionSetting`, `ToggleSetting`, `SliderSetting`, `Paths` icon/name helpers                                                                                                                           |
| Sidebar             | Installed/active `PluginService` composite component resolution and daemon injection/load/unload; `SettingsData.getPluginSettingsForPlugin`; Quickshell 0.3.1 `Variants`, `PanelWindow`, Wayland layer/keyboard focus/exclusive zones; `Region.item` input masks as used by installed/active Niri overview surfaces |

Settings loaders inject `pluginService`, while each settings entry explicitly sets its `pluginId`. Keep those IDs consistent with their manifests. Window Tabs keeps `justinNavigation` and its existing setting keys for compatibility. Its composite manifest declares widget/daemon paths under `components`; Workspaces retains a single `component`. Sidebar preferences and vertical title display are plugin-wide, like the existing width/scroll preferences. Niri service actions return dispatch acceptance, not compositor completion. Reordering waits for reactive focus/layout snapshots and times out if acknowledgments never arrive.

The horizontal host pill uses scoped bindings for full height; both orientations use button-local hover. The original bindings restore when orientation changes. Use distinct content components for horizontal and vertical pills: matching by component identity cannot distinguish two pills sharing one component. `sectionAvailablePrimarySize` is not a remaining-width contract in this DMS version; do not substitute it for the inspected geometry adapter. Multiple growing plugin instances in one section and unusual center-index modes still need live checks.

## QML editor imports

Install the official **Qt QML** editor extension if desired. `scripts/setup-qml-tooling.py` snapshots the selected DMS UI into gitignored `.local/dms-tooling`, runs Quickshell’s metadata scanner in an empty offscreen helper, and publishes persistent imports plus `.qmlls.ini`. It does not instantiate desktop services or alter DMS. Include the DankCommon submodule when using a source checkout.

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
2. On each monitor, confirm output-scoped windows/workspaces, active highlighting, exact titles when enabled, app/favicon fallback, cross-axis hit targets, and native tooltips. Exercise each plugin on horizontal and vertical bars; test vertical icons, rotated titles on left/right, and normal titles on a wider bar.
3. Add/remove/resize tiled windows. Confirm independent proportional widths, stable fitting growth, real overflow arrows, crowded-bar budgets, and floating-window exclusion.
4. Drag both directions on each axis, across stacks/columns and overflow. Check grab position (including rotated titles), neighbor motion, drop acknowledgment, outside cancellation, external layout changes, and rapid follow-up gestures. Check animations disabled as well.
5. Verify focus on left press, one activation per press/release, ID-targeted middle close, wheel direction/fast steps, manual overflow preservation, keyboard focus, and launcher behavior.
6. Check workspace popup positioning/dismissal at all four bar edges, horizontal/vertical overflow, icon search/selection/pinning, legacy favorites and favorites after restart, workspace removal, and output movement. Confirm icon choices never retain unnamed workspaces.
7. Navigate Helium pages with late favicons. Distinguish title matching, TabCtl event delivery, and Qt image loading rather than treating all failures as the same problem.
8. Enable the standalone sidebar on each selected monitor. Verify left/right placement with existing bars, readable title widths, unavailable-output handling, and removal of its exclusive zone when Off. Check that always-visible mode reserves its full width; expandable overlay keeps the rail reservation; push mode resizes the work area. Exercise click/hover opening, short pointer crossings, Escape, tooltip position, keyboard focus, and held drag/reorder behavior before accepting the native surface.

Current implementation: model, bridge, packaging/tooling, QML lint/format, and isolated Qt Quick checks pass in the devcontainer. The standalone sidebar composite/daemon loads in the native DMS session. Temporary DP-2 validation confirmed monitor scope, pinned reservation on either edge, compact/overlay/push reservation sizes, native IPC expansion/collapse, and complete removal/restoration with Off. Temporary validation restored the original settings; the user has since enabled expandable hover mode. The user confirmed the hover-collapse rerender fix. The animation uses a fixed Wayland surface and an input mask matching the visible panel, avoiding per-frame buffer/configure resizing. Push reservation changes once with the target. These contracts have isolated coverage; native smoothness and transparent-area click-through still need acceptance. Visual placement beside existing bars, title readability, tooltip anchors, hover, keyboard focus, and live dragging still need acceptance. The user-authorized migration retains top-bar Window Tabs and replaces the left-bar workspace widget with Workspaces. Both entries load on both monitors without plugin QML errors after restarting the existing shell. The user confirmed that these top/left widgets look and behave as before. Horizontal workspaces, vertical title modes, and their live interactions still need visible acceptance. The earlier combined plugin had improved tab drops and a confirmed late favicon update; those observations do not establish the split's alternate layouts. See [Review](REVIEW.md) for evidence and remaining checks, and [Configuration](CONFIGURATION.md) for the migration backup. Broader automatic icon categories and compositor-generation detection remain future work.

## References

- [DMS plugin development](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [DMS source](https://github.com/AvengeMedia/DankMaterialShell)
- [Niri IPC](https://niri-wm.github.io/niri/niri_ipc/)
- [TabCtl](https://github.com/slastra/tabctl)
