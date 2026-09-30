# Loading the custom plugin

This plugin runs inside DMS. You do not run its QML files directly, and you do not need to build or install system packages.

## 1. Link the repository

In a terminal:

```bash
cd /var/home/justin/Documents/Projects/justin-shell
make link-plugin
```

This creates `~/.config/DankMaterialShell/plugins/JustinNavigation` (or the equivalent under `XDG_CONFIG_HOME`) pointing to this repository. The helper is safe to repeat and refuses to overwrite another directory or link. Keep the repository in place while the link is installed.

## 2. Enable the plugin

Open DMS Settings, then **Plugins**. You can open Settings with:

```bash
dms ipc call settings open
```

Click **Scan** (called **Scan for Plugins** in some versions). Find **Justin Navigation** and enable it. Enabling makes the component available; it does not place it on your bar yet.

## 3. Add it to the top bar

Open **Bar** settings, find the widget lists for your horizontal bar, and add **Justin Navigation** to a section. Start in a section with few other widgets. If your DMS version offers several bars, select the top bar first.

You should see app icons and window titles for that monitor's active workspace, two overflow arrows, and a **+** button. Tab widths follow visual window widths at a fixed monitor-based scale, with a readability minimum for small tabs. No separate application name is added. An empty workspace shows **No windows**. The plus button opens the existing DMS launcher, which follows the focused monitor. It does not guarantee that an app will create a new window.

In plugin settings, **Allow full-width growth** defaults on and removes the old 45% cap. The strip grows as windows are added, rather than stretching a short list. Disable it to apply **Window strip width** when other widgets need room. A dedicated navigation bar can use nearly the monitor's full width; shared sections still need space for their other widgets. Hover an icon for the complete window title. Arrows or horizontal dragging reveal additional windows. The highlighted icon is the workspace's active window, even on an unfocused monitor.

Adding it to a vertical bar currently shows a diagnostic count, not the planned workspace rail.

## 4. Reload after edits

Return to Settings → Plugins and click the **Reload Plugin** button on Justin Navigation. Because the installation is a symlink, there is no copying step. DMS 1.6.2 can cache helper QML components across plugin reloads. If an edit to `NavigationButton.qml` or `WindowStrip.qml` does not appear, restart the existing shell service:

```bash
systemctl --user restart dms.service
```

This briefly closes and reopens DMS panels and popouts; application windows remain running. Do not start a second shell.

DMS 1.6.2 supports:

```bash
dms ipc call plugins reload justinNavigation
```

Check `dms ipc --help` for targets exposed by the running shell. The old local shell lacked this target, but it was replaced with the packaged DMS source on 2026-09-30.

## Top and left bars together

DMS 1.6.2 supports independently configured bars. In Settings → Bar, use **Add Bar**, select the new bar, set its position to **Left**, and choose its widgets. Keep the existing bar at **Top**. The plugin's vertical view remains diagnostic until the workspace rail is implemented; DMS's built-in workspace switcher can be used in the left bar in the meantime.

## Troubleshooting

- **Not listed:** run Scan and check `readlink -f ~/.config/DankMaterialShell/plugins/JustinNavigation`. It should point to this repository, whose root contains `plugin.json`.
- **Listed but not on the bar:** enabling and adding a bar widget are separate steps.
- **Failed to load:** inspect the error shown in Plugins and the DMS logs. Include the exact QML error when requesting help.
- **No windows despite open apps:** check that this is a horizontal bar on the monitor containing those windows. Output selection intentionally does not fall back to another monitor.
- **Target not found on reload:** check the active shell path/version; older DMS configs lack plugin IPC. The Settings UI is an alternative.
- **Link already exists:** the helper accepts a link pointing here but refuses to replace other content. Inspect it before changing anything.

If you use a custom `XDG_CONFIG_HOME`, use that location when checking the link.
