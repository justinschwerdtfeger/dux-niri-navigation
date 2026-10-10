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

QML lint allows zero warnings. Two local exceptions cover incomplete Qt/Quickshell metadata: `Qt.styleHints.startDragDistance` and the process-exit signal's enum parameter. Each suppression explains its scope. `.qmlformat.ini` fixes indentation, wrapping, and Unix newlines while preserving import and property order.

QML library directives are understood by the ESLint processor and the small Prettier wrapper. Top-level QML library functions are exports; ordinary local unused variables remain errors. Pure-model tests execute the actual libraries, including relative QML JS imports. Tests cover stable independent widths, output filtering, dynamic workspace lifecycle, delegate identity, every small-list edit permutation, favicon agreement, and acknowledgment-driven reorder sequencing.

`make test-qml` uses an offscreen Qt Quick Test runner with lightweight theme/visual stubs and mocked compositor requests. It does not load DMS desktop services or move real windows. It exercises real ListModels, buttons, focus/close timing, overflow, shared workspace assignments, dispatch rejection, and timeout. These tests establish component behavior, not real DMS appearance.

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

| Consumer           | DMS APIs/source                                                                                                                                                                      |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `NiriState`        | `CompositorService.isNiri`; `NiriService.windows`, `allWorkspaces`, `send`, `focusWindow`, `switchToWorkspace`, `moveColumnLeft/Right`                                               |
| `NavigationWidget` | `PluginComponent` injections; `BasePill.content`, `widgetThickness`, hover/cursor controls; `PopoutService.openDankLauncherV2`; `SettingsData.getPopupTriggerPosition`; `DankPopout` |
| `BarGeometry`      | DankBar section ancestors, layout `widgetSpacing`, center `contentStart/contentSize`, actual pill padding                                                                            |
| Views/settings     | DMS `Theme`, `StyledText`, `DankIcon`, `DankTooltip`, `DankTextField`, `DankScrollbar`, `PluginSettings`, `ToggleSetting`, `SliderSetting`, `Paths` icon/name helpers                |

Settings loaders inject `pluginService`, while `NavigationSettings` explicitly sets `pluginId`. Keep that ID consistent with `plugin.json`. Niri service actions return dispatch acceptance, not compositor completion. Reordering waits for reactive focus/layout snapshots and times out if acknowledgments never arrive.

The horizontal host pill uses scoped bindings for full height and button-local hover. The original bindings restore when orientation changes. `sectionAvailablePrimarySize` is not a remaining-width contract in this DMS version; do not substitute it for the inspected geometry adapter. Multiple growing plugin instances in one section and unusual center-index modes still need live checks.

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
2. On each monitor, confirm output-scoped windows/workspaces, active highlighting, exact titles, app/favicon fallback, bar-height hit targets, and native tooltips.
3. Add/remove/resize tiled windows. Confirm independent proportional widths, stable fitting growth, real overflow arrows, crowded-bar budgets, and floating-window exclusion.
4. Drag both directions, across stacks/columns and overflow. Check grab position, neighbor motion, drop acknowledgment, outside cancellation, external layout changes, and rapid follow-up gestures. Check animations disabled as well.
5. Verify focus on left press, one activation per press/release, ID-targeted middle close, wheel direction/fast steps, manual overflow preservation, keyboard focus, and launcher behavior.
6. Check workspace popup positioning/dismissal, icon search/selection/pinning, favorites after restart, workspace removal, and output movement. Confirm icon choices never retain unnamed workspaces.
7. Navigate Helium pages with late favicons. Distinguish title matching, TabCtl event delivery, and Qt image loading rather than treating all failures as the same problem.

Current refactor: model, bridge, tooling, QML lint/format, and isolated Qt Quick checks pass in the devcontainer. The restarted DMS session loads both plugin instances without plugin QML errors; the user reports improved tab drops. See [Review](REVIEW.md) for the evidence and remaining checks. Prior horizontal rendering and picker screenshots do not establish this refactor's visible rail behavior. Broader automatic icon categories and compositor-generation detection remain future work.

## References

- [DMS plugin development](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [DMS source](https://github.com/AvengeMedia/DankMaterialShell)
- [Niri IPC](https://niri-wm.github.io/niri/niri_ipc/)
- [TabCtl](https://github.com/slastra/tabctl)
