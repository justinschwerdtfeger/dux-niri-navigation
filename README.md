# Justin Navigation

A DMS plugin project for Material Shell-inspired navigation on Niri: window icons and titles across the top and workspace icons down the left.

The horizontal widget shows app icons for windows on the workspace active on its monitor, ordered by Niri's layout. Each tab shows its icon and the window's own title, without an added application name. Width follows the window's visual width at a stable monitor-based scale; small tabs have a readability minimum. Long titles elide, with the full title on hover. Click an icon to focus its window; use the arrows or drag the strip to reach overflow, and click **+** to open DMS's launcher. Floating windows and windows without layout positions follow tiled windows in ID order.

The vertical widget is still a diagnostic workspace count across all outputs, including Niri's trailing empty workspace. Workspace buttons and custom icons are the next milestone.

## Intended behavior

- Top bar: windows on the bar's current workspace, in Niri's layout order, with icons and window titles, stable proportional widths, and click-to-focus.
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

In DMS Settings → Plugins, scan for plugins, enable **Justin Navigation**, then add it to a **horizontal** DankBar widget list. Start with a mostly empty bar section. **Allow full-width growth** is enabled by default: the strip grows with its window count up to the monitor width, reserving basic pill padding and bar insets. It does not stretch a short list to fill the bar. For crowded bars, disable this option and set a pixel maximum (default 640, range 240–7680). The plugin does not automatically subtract other widgets or custom frame geometry; use a dedicated bar for near-full-width navigation.

After edits, use the plugin's **Reload** button in Settings → Plugins, or:

```bash
dms ipc call plugins reload justinNavigation
```

Verified in DMS 1.6.2 with Quickshell 0.3.1. The running shell uses DMS’s embedded UI and exposes the `plugins` IPC target. Helper-component edits can remain cached after plugin reload; see the loading guide. The launcher follows DMS's focused-monitor behavior; the plus button does not force the launcher onto an inactive monitor.

To remove the development link, first verify it points here, then remove only that link and disable the plugin in DMS. Repository checks do not alter your desktop configuration.

## Checks

```bash
make check
```

Requires Python 3 and Node.js. This validates packaging, checks the setup script's syntax, runs eleven window-model tests, and checks patch whitespace. It does not compile QML. The widget was loaded in DMS 1.6.2 and screenshots confirmed title text, arrows, the plus button, and the empty-workspace label. Click, overflow, and launcher interaction checks remain. See [development notes](docs/DEVELOPMENT.md).

## Project map

| File | Purpose |
| --- | --- |
| `plugin.json` | DMS plugin identity and entry points |
| `NavigationWidget.qml` | Horizontal and vertical bar components |
| `NiriState.qml` | Boundary around DMS compositor services |
| `WindowModel.js` | Pure output filtering and window-ordering logic |
| `WindowStrip.qml` | Proportional icon/title strip and navigation controls |
| `NavigationButton.qml` | Themed icon/action button |
| `NavigationSettings.qml` | DMS-integrated settings |
| [Design](docs/DESIGN.md) | Decisions, limits, and next milestones |
| [Development](docs/DEVELOPMENT.md) | Upstream references and validation |
| [Loading](docs/LOADING.md) | First-time setup, reload, and troubleshooting |
| [Agent guidance](AGENTS.md) | Context and working rules for future agents |
