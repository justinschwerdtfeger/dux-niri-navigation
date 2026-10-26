# Window Tabs

An independent Dux Shell 2.0 plugin for Niri, targeting fork revision `0bd677b2` and Quickshell 0.3.1.

Extract the release archive into `$XDG_CONFIG_HOME/dms/plugins` (default `~/.config/dms/plugins`). The resulting `justinNavigation` directory contains `plugin.json` and all runtime files. In DMS Settings → Plugins, scan and enable **Window Tabs**, then add its widget to a bar. The standalone sidebar is optional and defaults off in plugin settings.

Neither the source checkout nor Workspaces is required. Keep the package's files together. Favicons additionally require system Python with PyGObject/Gio and the existing TabCtl Helium extension/helper; application icons remain the fallback.

Plugin ID `justinNavigation` preserves existing Window Tabs settings. When upgrading a linked development installation, remove only the old installation symlink after verifying its target; do not install a second copy with the same ID.

Source, full documentation, and compatibility limits: [Dux Niri Navigation](https://github.com/justinschwerdtfeger/dux-niri-navigation).
