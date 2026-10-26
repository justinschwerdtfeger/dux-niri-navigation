# Justin Navigation plugins

Two Dux Shell (DMS) plugins for Niri: **Justin Window Tabs** and **Justin Workspaces**. Each works on horizontal or vertical bars, independently of the other. DMS owns the bars, theme, launcher, and settings; Niri owns layout, focus, and dynamic workspace lifetime.

Window Tabs also provides an optional standalone sidebar with readable horizontal titles, independent of DankBar's width limit.

## Use

Targets **Dux Shell 2.0**, including the fork’s configurable widget inset, with Niri and Quickshell 0.3.1. The development source is pinned to fork revision `0bd677b2`. Earlier native validation used DMS 1.6.2 and Niri 26.04; visible Dux 2.0 acceptance is pending. Internal host APIs can change across releases.

```bash
make link-plugin
```

`make link-plugin` builds two self-contained packages and links both entries. In DMS Settings → Plugins, scan and enable the plugins you want, then add their widgets to any bar. Each instance follows its hosting monitor and bar orientation. Use `make link-plugin PLUGIN=window-tabs` or `make link-plugin PLUGIN=workspaces` to install just one. The helper respects `XDG_CONFIG_HOME`, accepts matching links, and refuses to replace other content. Keep the generated package directory in place while linked; source edits require rebuilding. Existing checkout links need the [one-time package migration](docs/LOADING.md#upgrade-from-checkout-links).

**Upgrading from Justin Navigation:** horizontal tabs retain their existing widget ID and settings (`justinNavigation`). Replace the old widget on workspace bars with **Justin Workspaces** (`justinWorkspaces`). Pinned icons fall back to the old plugin's favorites until you change them in the new picker. See [Loading](docs/LOADING.md) for migration and setup.

## Window strip

- Shows tiled windows on the monitor’s active workspace, ordered by Niri columns and tiles. Floating windows are excluded.
- Shows application icons and exact window titles, without an added app-name label. Vertical bars default to icons; **Vertical tab display** optionally shows rotated titles or normal title rows for wider bars. Hover displays DMS’s native app/title tooltip in every mode.
- Horizontal and rotated tabs scale independently from the monitor width, with a readability minimum. **Window tab width** adjusts that scale (120–480 px for a monitor-wide window; default 240). Vertical icons use square buttons; normal title rows keep a compact height while filling the bar's width.
- Focuses on left press, requests close on middle-click, and reorders real Niri windows on left drag. Neighbors make room at 50% overlap. Dragging near an edge scrolls overflow.
- Grows along the bar while reserving other widgets and padding. **Fill available bar space** defaults on; disable it to apply **Window strip length** (default 640 px) to width or height.
- Shows overflow arrows before **+** only when needed. Manual overflow browsing stays put until focus changes. Empty workspaces show only **+**, which opens DMS’s launcher on its focused monitor.
- Wheel up/left focuses the previous column; down/right focuses the next. The hosting bar’s Dux workspace-switcher reverse scrolling and the plugin’s optional **Reverse scroll direction** compose; the plugin option defaults off.

Buttons follow Dux’s widget thickness on either axis, matching native widgets. The fork’s **Widget inset** controls their distance from the bar edges, including zero inset; the plugin does not override pill height. Dux owns pill styling and outlines. Both plugins offer **Override widget padding** and **Widget padding** (0–48 px per end, default 8 when enabled). The override defaults off, following the hosting bar. It changes left/right space on horizontal bars and top/bottom space on vertical bars; button thickness, bar inset, and standalone sidebar spacing stay independent. Each plugin saves its own preference, shared by its bar instances. Bar buttons use Dux’s native pill/flat rounding and pressed shape. Both widgets follow the hosting bar’s **Icon scale** and **Maximize widget icons** settings. Window Tabs also follows **Font scale** and **Maximize widget text**, including the launcher and overflow controls. Transitions follow Dux animation settings.

## Standalone window sidebar

In **DMS Settings → Plugins → Justin Window Tabs**, set **Standalone sidebar** to:

- **Always visible titles:** a wide vertical list that reserves its full width for windows.
- **Expandable icon rail:** a 48-pixel rail that expands into horizontal title rows. Choose **Click** or **Hover** with **Expand sidebar on**. The expand/collapse button works in either mode; Escape collapses it. Hover opens after 200 ms and closes 400 ms after leaving, with both timers held during presses, dragging, and reorder acknowledgment.

**Sidebar title width** defaults to 240 px (160–480 px, capped at half the monitor). Choose the **Sidebar side** and **Sidebar monitor**. Expandable mode overlays windows beyond the compact rail by default; enable **Push windows aside when expanded** to reserve the wider area instead. Preferences apply independently of ordinary bar widgets, which remain available. The sidebar defaults **Off**; no desktop layout is changed by installing the feature.

The sidebar uses the same output-scoped tabs, focus/close actions, favicons, dragging, overflow, launcher, and DMS theme. Width is independent of DMS's **Bar → Appearance → Spacing → Size**, whose DMS 1.6 slider only allows a narrow widget area. Disconnected selected monitors produce no sidebar until they return. Expansion/collapse uses DMS’s animation speed and easing with a title fade inside a stable surface, while preserving icon sizes and scrolling. Transparent space passes clicks through; push mode lets Niri handle the window-layout transition. See [Loading](docs/LOADING.md#standalone-sidebar) for setup and [Development](docs/DEVELOPMENT.md#runtime-acceptance) for live validation limits.

## Workspace rail

Shows the monitor’s workspaces, including its trailing empty workspace, in a horizontal row or vertical rail. Left-click switches workspace; right-click opens a searchable picker with 100 monochrome DMS Material Symbols. Right-click a picker icon to pin/unpin it. Pinned symbols persist through DMS settings; workspace assignments live only for the shell session and are removed with the workspace. Choosing an icon never names or retains a workspace.

The bar’s inset changes the visible buttons, while their click targets span the full bar thickness. This keeps top/bottom edges clickable on horizontal bars and left/right edges clickable on vertical bars.

New workspaces start with a plus (`add`); the first observed window seeds a simple app category. Assignments stay stable when that window closes. The picker’s current layout is intentionally retained.

## Optional favicons

Helium windows can use their active page’s favicon through the existing [TabCtl](https://github.com/slastra/tabctl) extension/native helper. This requires `/usr/bin/python3` with PyGObject/Gio and a connected TabCtl Helium service. The plugin subscribes to events without polling or controlling tabs. Missing, failed, or conflicting images use the application icon.

TabCtl 2.3.0 omits favicon-only notifications, so late icons can remain stale. A fix in the separate TabCtl project is active in the user's local 2.3.0.1 test build; a delayed favicon change was verified through the DMS strip. Exact-title matching and unauthenticated Qt image loading have additional limits. See [favicon compatibility](docs/DEVELOPMENT.md#favicons) and the separate-project patch record in [Configuration](docs/CONFIGURATION.md).

## Development

The devcontainer supplies the linters, formatters, Qt Quick Test, and a pinned Dux 2.0 fork source snapshot. Docker and the Dev Container CLI are available on the reviewed host; no host QML-tool installation is needed.

```bash
make dev-up
make dev-check
```

Alternatively, use **Dev Containers: Reopen in Container** in VS Code. Inside the container, run `make check`, `make test-qml`, or `make format` directly. See [Development](docs/DEVELOPMENT.md#devcontainer) for access, versions, and rebuild instructions.

For native development instead:

```bash
npm ci
python3 -m pip install -r requirements-dev.txt
python3 scripts/setup-qml-tooling.py --dms-source /path/to/active/dms/ui
make check
```

Development checks require Node.js 22.13+ (or 24+), Python 3.11+, Ruff, ShellCheck, and Qt’s `qmllint`/`qmlformat`. Qt tools must match the installed Qt runtime. Node dependencies and Ruff are pinned. Development tools are not needed to run the plugin.

`make check` runs packaging checks, JavaScript/Python behavior tests, ESLint, Ruff, Prettier, ShellCheck, QML lint/format checks, and patch whitespace checks. `make format` applies formatting. `make test` runs the model/tooling tests without DMS imports. `make test-qml` runs isolated Qt Quick tests with mocked DMS services; it needs `qmltestrunner`. None of these targets starts or restarts the desktop shell.

Reload with `dms ipc call plugins reload justinNavigation` or `dms ipc call plugins reload justinWorkspaces`. DMS can cache helper components across reloads; a shell restart may be needed to load helper changes. Runtime validation and its limits are documented in [Development](docs/DEVELOPMENT.md).

## Packaging and source layout

```bash
make package                       # Both plugins
make package PLUGIN=window-tabs    # Window Tabs only
make package PLUGIN=workspaces     # Workspaces only
```

The output is `dist/justinNavigation/` and `dist/justinWorkspaces/`, with a versioned `.tar.gz` archive beside each directory. Each archive contains a complete plugin directory; extract either into Dux's plugin directory, scan, and enable it. Neither package requires this checkout or the other plugin. Plugin IDs, settings, and independent manifest versions are preserved. Building requires Python 3.11+; release packages require no build tools.

| Area                                                  | Source                                                                        |
| ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| Window Tabs widget, settings, sidebar, and manifest   | `plugins/window-tabs/`                                                        |
| Workspaces widget, settings, picker, and manifest     | `plugins/workspaces/`                                                         |
| Compositor adapter and host geometry                  | `shared/NiriState.qml`, `shared/NavigationHost.qml`, `shared/BarGeometry.qml` |
| Pure models, session state, and favicon subscriber    | `shared/*.js`, `shared/state/`, `shared/scripts/`                             |
| Package builder, development tooling, and regressions | `scripts/`, `tests/`, `.devcontainer/`, `Makefile`                            |

Shared runtime files are copied into each package at build time. QML uses package-local imports, keeping singleton identity within each installed plugin. Source directories are build inputs; load the generated packages for development and runtime.

[Design](docs/DESIGN.md) describes current contracts. [Development](docs/DEVELOPMENT.md) describes APIs and validation. [Review](docs/REVIEW.md) records this refactor. [Agent guidance](AGENTS.md) sets maintenance boundaries and links the project [Dux plugin skill](skills/dms-plugin-dev/SKILL.md). Git history retains earlier implementation notes.
