# Loading the navigation plugins

## Install and enable

Run from the repository:

```bash
make link-plugin
```

The helper creates two links under `$XDG_CONFIG_HOME/DankMaterialShell/plugins`, defaulting to `~/.config`:

| Directory          | Target              | Plugin ID                               |
| ------------------ | ------------------- | --------------------------------------- |
| `JustinNavigation` | Repository root     | `justinNavigation` (Justin Window Tabs) |
| `JustinWorkspaces` | `workspace-plugin/` | `justinWorkspaces` (Justin Workspaces)  |

Keep the entire checkout in place while linked, including `workspace-plugin/shared -> ..`. Repeated calls accept matching links. Both destinations are checked before either is created; conflicting content is never replaced. Runtime needs DMS/Niri and the supported Quickshell; lint tools are only for development.

In DMS Settings → Plugins, scan and enable **Justin Window Tabs**, **Justin Workspaces**, or both. Add the desired widget to a bar's widget list. Both support horizontal and vertical bars. Enabling a plugin and placing a widget are separate steps. Start in a section with some free space.

## Upgrade from the combined plugin

1. Run `make link-plugin`, scan, and enable **Justin Workspaces**.
2. Keep existing horizontal tab widgets: their ID and saved window settings are unchanged.
3. On bars where the old **Justin Navigation** widget showed workspaces, replace it with **Justin Workspaces** in the same section/position. Leaving the old widget there now shows vertical window tabs.
4. Existing pinned symbols remain available through a legacy-settings fallback. The first pin/unpin in the new picker saves that list under `justinWorkspaces`; workspace assignments remain session-local.
5. Restart the existing DMS shell if helper caching prevents the split from loading correctly.

The install helper does not edit bar configurations or enable plugins automatically. Agents must have desktop-configuration authorization before migrating an existing layout.

## Standalone sidebar

Enable **Justin Window Tabs**, then open its plugin settings. No bar widget placement is required for the sidebar: DMS loads its daemon alongside the optional bar widget surface.

1. Set **Standalone sidebar** to **Always visible titles** or **Expandable icon rail**. The default is **Off**.
2. Choose **Sidebar side**, **Sidebar monitor**, and **Sidebar title width**. Use the plugin width slider rather than the regular bar Size slider.
3. For expandable mode, choose **Expand sidebar on → Click/Hover** and toggle **Push windows aside when expanded**. Off overlays windows beyond the reserved 48-pixel rail; on changes the reserved area with expansion.
4. Use the rail's top expand/collapse button in either trigger mode, or Escape to collapse. Hover opening/closing waits briefly and pauses during interaction/reordering. Click mode stays open until explicitly collapsed.

For a keyboard shortcut, DMS’s existing command `dms ipc call plugins toggle justinNavigation` toggles all selected expandable sidebars. It leaves pinned/Off modes alone and respects interaction holds.

Existing Window Tabs bar widgets remain in place, so remove any unwanted duplicate tab widget through **Bar → Widgets**. Workspaces is independent. Turning the sidebar Off removes its panel and reserved area. A selected disconnected monitor stays selected and displays its sidebar when it returns.

## Window Tabs

The strip shows that monitor’s active workspace, including its unfocused active window. Floating windows are excluded. An empty or floating-only workspace shows **+**. Arrows appear immediately before **+** only during overflow. Tabs use exact titles and independently proportional widths. DMS tooltips may show the app name.

**Fill available bar space** defaults on and reserves sibling widgets, gaps, and pill padding. Disable it for a smaller **Window strip length** limit (width horizontally, height vertically). **Window tab width** changes the proportional scale for horizontal/rotated titles. Wheel up/left goes to the previous column and down/right to the next; DMS reverse scrolling and the plugin’s **Reverse scroll direction** toggle reverse that mapping. The plugin toggle defaults off.

On vertical bars, **Vertical tab display** defaults to **Icons only**, with titles in tooltips. Select **Rotated titles** for labels along a narrow bar, or **Normal title rows** on a wider bar. Dragging, focus, close, launcher, and overflow work along the selected bar axis. The horizontal appearance is retained.

Buttons and the horizontal pill fill the DMS bar height. Adjust **Size** for height, and **Padding/Remove Widget Padding** for horizontal padding. The launcher follows DMS’s focused monitor and may activate an existing app window.

## Workspaces

Add **Justin Workspaces** to any bar. A horizontal bar shows a row; a vertical bar shows a rail. Left-click changes workspace; right-click opens the icon picker. Right-click picker icons to pin/unpin. Assigning an icon never names or retains a dynamic workspace. The picker controls are unchanged, and its position follows all four bar edges.

## Favicons

Register and connect the existing TabCtl extension/native helper, and confirm `tabctl status` shows Helium. System Python needs PyGObject/Gio. Window Tabs subscribes automatically in either orientation; Workspaces does not start a subscriber. Application icons remain the fallback. See [compatibility limits](DEVELOPMENT.md#favicons) for stale/missing images.

## Reload

Use the plugin’s Reload button, or on the inspected DMS 1.6.2 host:

```bash
dms ipc call plugins reload justinNavigation
dms ipc call plugins reload justinWorkspaces
```

After a manifest surface change, use a plugin rescan or restart so DMS discovers the new component map. Helper QML and directory listings may remain cached: even correctly named new files can produce a case-mismatch error until restart. If changed helper properties or behavior do not load, restart the **existing** shell:

```bash
systemctl --user restart dms.service
```

This briefly interrupts DMS panels/popouts while application windows remain running. Do not start another shell. Agents need session-change authorization before restarting. After upgrades, discover the active embedded UI path from logs or `dms doctor`; the installed source and running UI can differ.

## Troubleshooting and removal

- **Not listed:** scan again; verify each development link resolves to its package and that package contains `plugin.json`.
- **Enabled but absent:** add the widget to the selected bar.
- **No windows:** check you added Window Tabs, its hosting output/active workspace, and whether windows are floating. The plugin deliberately does not fall back to another monitor.
- **Vertical titles absent:** select a title mode in Window Tabs settings. Normal titles require enough bar width for readable text.
- **Clipped strip:** check the hosting section and other widget widths; try the explicit maximum. Unusual centering or multiple growing instances may need host-specific validation.
- **Old behavior after reload:** inspect helper-cache loading and service logs before treating it as a new code failure.
- **Load errors:** collect the exact QML error and the installed/running DMS versions.

To uninstall either plugin, disable/remove its widgets in DMS, verify its link points to this checkout, and remove only that link. Removing the Window Tabs install link does not remove the shared repository files needed by Workspaces. Respect a custom `XDG_CONFIG_HOME` when checking paths.
