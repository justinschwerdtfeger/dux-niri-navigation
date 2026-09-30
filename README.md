# Justin Navigation

A DMS plugin project for Material Shell-inspired navigation on Niri: window icons and titles across the top and workspace icons down the left.

The horizontal widget shows app icons for windows on the workspace active on its monitor, ordered by Niri's layout. Each tab shows its icon and the window's own title, without an added application name. Width follows the window's visual width at a stable monitor-based scale; small tabs have a readability minimum. Long titles elide; hovering shows the application name and window title in a native DMS tooltip, which uses DMS’s single-line width limit. Left-click a window tab to focus its window, or middle-click to request that it close; use the arrows or drag the strip to reach overflow, and click **+** to open DMS's launcher. Scroll up/left over the widget to focus Niri’s next column, or down/right for the previous column; DMS reverse scrolling reverses those directions. Wheel input has no timed cooldown; fast and coalesced wheel steps are preserved. The plugin’s **Reverse scroll direction** toggle defaults on; turn it off to follow DMS’s normal direction. Manual overflow browsing stays in place across state updates until the active window changes. Floating windows are excluded; tiled windows without layout positions follow positioned windows in ID order. Both arrows sit on the right before **+**. Arrows appear only when the strip reaches its width ceiling and overflows. With no tiled windows, only **+** is shown.

The vertical widget is still a diagnostic workspace count across all outputs, including Niri's trailing empty workspace. Workspace buttons and custom icons are the next milestone.

Switching workspaces fades and gently slides the new window tabs into place. When windows open or close, surviving tabs slide into their new positions and new tabs fade in. The strip also eases its width as windows change, keeping each tab's proportional width and the hosting bar's width ceiling. Transitions follow DMS's animation speed setting and snap when animations are disabled. Visible animation in the running DMS session still needs verification.

## Intended behavior

- Top bar: windows on the bar's current workspace, in Niri's layout order, with icons and window titles, stable proportional widths, and click-to-focus; floating windows are excluded.
- Top-bar plus: open the existing DMS app launcher. Let Niri place newly created windows.
- Left bar: dynamic workspace navigation with small user-selected icons.
- Keep unnamed workspaces that disappear when empty; do not turn them into persistent named workspaces.
- Reuse DMS for settings, launcher, notifications, and other desktop services.

The project name and plugin id are provisional. This is a plugin, not a shell or compositor fork.

## Local development

Requires Niri and a functioning DMS installation with its supported Quickshell runtime. This plugin loads inside DMS; it is not a standalone `qs -p` configuration.

For a step-by-step first installation, see [Loading the plugin](docs/LOADING.md). From the repository root:

```bash
make link-plugin
```

This creates a development symlink, so DMS reads edits directly from this repository. It leaves an existing matching link alone and refuses to replace any other existing path. No sudo is needed.

In DMS Settings → Plugins, scan for plugins, enable **Justin Navigation**, then add it to a **horizontal** DankBar widget list. Start with a mostly empty bar section. **Allow full-width growth** is enabled by default: the strip grows with its window count up to the hosting bar’s available content width, reserving the actual pill padding, other widgets, and gaps. It does not stretch a short list to fill the bar. For crowded bars, disable this option and set a pixel maximum (default 640, range 240–7680). On the inspected DMS 1.6.2 host, the plugin subtracts other widgets in its section and reserves occupied neighboring sections. Empty center containers do not cap growth. A short list still uses only its natural width.

Application icons use 85% of the available icon slot; arrows and plus retain their size. Hover and press highlighting applies to individual buttons. Buttons use the full DMS bar height. In **Settings → DankBar**, select the bar and adjust **Size** to change its height. **Padding** and **Remove Widget Padding** control horizontal padding around this plugin, not its button height. The horizontal pill background and outline also fill the bar height.

After edits, use the plugin's **Reload** button in Settings → Plugins, or:

```bash
dms ipc call plugins reload justinNavigation
```

Verified in DMS 1.6.2 with Quickshell 0.3.1. The running shell uses DMS’s embedded UI and exposes the `plugins` IPC target. Helper-component edits can remain cached after plugin reload; see the loading guide. The launcher follows DMS's focused-monitor behavior; the plus button does not force the launcher onto an inactive monitor.

To remove the development link, first verify it points here, then remove only that link and disable the plugin in DMS. Repository checks do not alter your desktop configuration.

## Editor support

An optional setup script generates local DMS imports for VS Code. Install the official **Qt QML** extension and run **Qt: Restart QML Language Server** after opening this repository. See [development notes](docs/DEVELOPMENT.md#vs-code-qml-imports) for refreshing the imports after DMS upgrades. Generated metadata and editor paths are gitignored. The setup preserves DMS JavaScript helpers as well as type metadata so relative imports resolve.

## Checks

```bash
make check
```

Requires Python 3 and Node.js. This validates packaging, checks the setup script's syntax, runs window-model and tooling recovery tests, checks the link script's syntax, and checks patch whitespace. It does not compile QML. Earlier widget versions were loaded in DMS 1.6.2 and screenshots confirmed rendering. A user-authorized DMS restart confirmed the latest wheel handler loaded in both horizontal instances without plugin QML errors. Live rapid scrolling and visual interaction checks still need confirmation. Click, overflow, and launcher interaction checks remain. See [development notes](docs/DEVELOPMENT.md).

## Project map

| File | Purpose |
| --- | --- |
| `plugin.json` | DMS plugin identity and entry points |
| `NavigationWidget.qml` | Horizontal and vertical bar components |
| `BarGeometry.qml` | Adapter for DMS bar content bounds and sibling sizing |
| `NiriState.qml` | Boundary around DMS compositor services |
| `WindowModel.js` | Pure output filtering and window-ordering logic |
| `WindowStrip.qml` | Proportional icon/title strip and navigation controls |
| `NavigationButton.qml` | Themed icon/action button |
| `NavigationSettings.qml` | DMS-integrated settings |
| [Design](docs/DESIGN.md) | Decisions, limits, and next milestones |
| [Development](docs/DEVELOPMENT.md) | Upstream references and validation |
| [Loading](docs/LOADING.md) | First-time setup, reload, and troubleshooting |
| [Agent guidance](AGENTS.md) | Context and working rules for future agents |

The full review of the first three commits and its fixes are recorded in [Review](docs/REVIEW.md).
