# Workspaces

An independent Dux Shell 2.0 plugin for Niri, targeting fork revision `0bd677b2` and Quickshell 0.3.1.

Extract the release archive into `$XDG_CONFIG_HOME/dms/plugins` (default `~/.config/dms/plugins`). The resulting `justinWorkspaces` directory contains `plugin.json` and all runtime files. In DMS Settings → Plugins, scan and enable **Workspaces**, then add its widget to a horizontal or vertical bar.

Neither the source checkout nor Window Tabs is required. Keep the package's files together. New workspaces show a plus until their first window seeds an icon or you choose a custom symbol. Left-click switches workspace; right-click opens the icon picker. Right-click picker icons to pin favorites. Icon assignments remain session-local and never name or retain workspaces.

Plugin ID `justinWorkspaces` preserves existing settings. When upgrading a linked development installation, remove only the old installation symlink after verifying its target; do not install a second copy with the same ID.

Source, full documentation, and compatibility limits: [Dux Niri Navigation](https://github.com/justinschwerdtfeger/dux-niri-navigation).
