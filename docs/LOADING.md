# Loading Justin Navigation

## Install and enable

Run from the repository:

```bash
make link-plugin
```

The helper links this checkout to `$XDG_CONFIG_HOME/DankMaterialShell/plugins/JustinNavigation`, defaulting to `~/.config`. Keep the checkout in place while linked. Repeated calls accept the matching link and refuse to overwrite another path. Runtime needs DMS/Niri and the supported Quickshell; lint tools are only for development.

In DMS Settings → Plugins, scan and enable **Justin Navigation**. Then add it to a horizontal bar’s widget list. Enabling a plugin and placing a widget are separate steps. Start in a section with some free space.

The strip shows that monitor’s active workspace, including its unfocused active window. Floating windows are excluded. An empty or floating-only workspace shows **+**. Arrows appear immediately before **+** only during overflow. Tabs use exact titles and independently proportional widths. DMS tooltips may show the app name.

**Allow full-width growth** defaults on and reserves sibling widgets, gaps, and pill padding. Disable it for a smaller **Window strip width** limit. **Window tab width** changes the proportional scale. Wheel up/left goes to the previous column and down/right to the next; DMS reverse scrolling and the plugin’s **Reverse scroll direction** toggle reverse that mapping. The plugin toggle defaults off.

For workspaces, add the same plugin to a vertical bar. In DMS bar settings, create/select a **Left** bar if desired. Left-click changes workspace; right-click opens the icon picker. Right-click picker icons to pin/unpin. These bar configuration choices are manual desktop preferences; repository checks do not apply them.

Buttons and the horizontal pill fill the DMS bar height. Adjust **Size** for height, and **Padding/Remove Widget Padding** for horizontal padding. The launcher follows DMS’s focused monitor and may activate an existing app window.

## Favicons

Register and connect the existing TabCtl extension/native helper, and confirm `tabctl status` shows Helium. System Python needs PyGObject/Gio. The plugin subscribes automatically when a horizontal instance needs favicons. Application icons remain the fallback. See [compatibility limits](DEVELOPMENT.md#favicons) for stale/missing images.

## Reload

Use the plugin’s Reload button, or on the inspected DMS 1.6.2 host:

```bash
dms ipc call plugins reload justinNavigation
```

Helper QML may remain cached. If changed helper properties or behavior do not load, restart the **existing** shell:

```bash
systemctl --user restart dms.service
```

This briefly interrupts DMS panels/popouts while application windows remain running. Do not start another shell. Agents need session-change authorization before restarting. After upgrades, discover the active embedded UI path from logs or `dms doctor`; the installed source and running UI can differ.

## Troubleshooting and removal

- **Not listed:** scan again; verify the development link resolves to this repo and the root contains `plugin.json`.
- **Enabled but absent:** add the widget to the selected bar.
- **No windows:** check orientation, hosting output, active workspace, and whether the windows are floating. The plugin deliberately does not fall back to another monitor.
- **Clipped strip:** check the hosting section and other widget widths; try the explicit maximum. Unusual centering or multiple growing instances may need host-specific validation.
- **Old behavior after reload:** inspect helper-cache loading and service logs before treating it as a new code failure.
- **Load errors:** collect the exact QML error and the installed/running DMS versions.

To uninstall, disable/remove the widget in DMS, verify the link points to this checkout, and remove only that link. Respect a custom `XDG_CONFIG_HOME` when checking paths.
