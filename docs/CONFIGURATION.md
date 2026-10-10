# Desktop compatibility audit — 2026-09-30

## TabCtl favicon event fix — 2026-10-10

With explicit user authorization, patched the separate project at
`/var/home/justin/Documents/Builds/tabctl/extensions/shared/core.js` to emit
debounced notifications for `favIconUrl` changes and completed page loads.
Loading-progress updates remain ignored. Updated its Chrome/Firefox behavior
regression, rebuilt both bundles, and passed all 36 extension tests and both
syntax checks. No browser tabs or desktop settings were changed.

Helium initially used the packaged TabCtl extension
`baomblllgemcgbignhpbipgiofmjdhpn`, version 2.3.0, rather than loading this source
checkout. Reloading that packaged copy alone does **not** activate the source
patch. The rebuilt extension must be installed with the native helper's allowed
origin respected, or the upstream packaged extension must incorporate the fix.
The local test installation and live favicon-only notifications are verified below.

At the user's request, prepared a local unpacked test build at
`/var/home/justin/Documents/Builds/tabctl/build/helium-favicon-test`. Its manifest
uses the packaged extension's public key, preserving the same extension ID;
verified it against Helium's native-messaging allowed origin. It contains the
rebuilt Chrome bundle, original permissions/assets, and `TESTING.md` with loading
and packaged-version restoration instructions. The user loaded that folder through
Helium's extension manager. The test copy is labeled **TabCtl (favicon test)**,
version **2.3.0.1**; `tabctl status` confirms it is connected with protocol v2.

The local manual fixture keeps its title/URL fixed and changes its PNG favicon
from red to green after six seconds. The actual plugin subscriber emitted two
distinct icon snapshots, and the user confirmed both colors appeared in the DMS
strip. This verifies late-icon event delivery and inline image rendering; remote
authentication, ambiguous titles, and unchanged-URL image caching remain separate
limits. The temporary loopback test server was stopped after validation.

The sections below are historical records of earlier authorized desktop changes,
not current setup instructions or current plugin validation claims.

## External Helium links — 2026-10-08

At the user's explicit request, installed `~/.local/bin/helium-new-window` and a hidden `~/.local/share/applications/helium-new-window.desktop` handler. The wrapper executes `env DESKTOPINTEGRATION=1 "$HOME/AppImages/helium.appimage" --new-window "$@"`. Registered this separate desktop entry for HTTP and HTTPS, leaving the AppImage-managed `helium.desktop` intact so its regeneration does not overwrite the wrapper. The inspected launcher reports Helium AppImage 0.18.3.1. This requires the AppImage to remain at that path.

Shell syntax and desktop-entry validation pass; both `xdg-mime` and Gio resolve HTTP/HTTPS to the new handler. No test URL was opened; visible new-window behavior and Discord's portal handoff remain to be confirmed. Browser-internal middle-click and Ctrl+click behavior is unaffected. Multiple URLs passed together can still become multiple tabs in one new window.

Previous association files are backed up at `~/.local/share/helium-new-window-backups/20261008-213622/`. To undo just this change, run `xdg-mime default helium.desktop x-scheme-handler/http` and `xdg-mime default helium.desktop x-scheme-handler/https`; the wrapper and hidden desktop entry can then be removed. This is a user-authorized configuration change, not a routine repository setup step.

The user explicitly authorized edits to DMS settings and `~/.config/niri`. This is a record of that session, not instructions for routine repository work.

## Verified baseline

DMS CLI and running shell both report 1.6.2; API 34, settings schema 18, Quickshell 0.3.1, Niri 26.04. Persisted DMS settings keys were compared with the embedded UI's settings specification: no obsolete keys were found. `dms.service` is enabled and active, using the embedded UI.

## Applied changes

- Reordered Niri includes so DMS integrations load first and custom `cfg/` files retain precedence. Included DMS's floating-window and wallpaper-backdrop rules.
- Removed the active generated output include. `cfg/display.kdl` owns monitor scale/placement using the external display's stable identity; `dms/outputs.kdl` remains generated but inactive. DMS display changes therefore do not control Niri placement unless this ownership choice is changed. Custom input settings similarly own input configuration.
- Kept zero gaps, disabled focus ring, full-width opening columns, and utility/dialog floating rules. Added DMS native windows to the utility rule so they open floating without maximization.
- Set DMS `niriLayoutRadiusOverride` to 20, matching the user's custom window radius and keeping generated Alt-Tab highlighting consistent.
- Removed the stale Noctalia overview rule and obsolete commented startup entry; updated wallpaper/activation comments.
- Removed KDE's authentication-agent autostart because the active DMS runtime provides Polkit integration. No KDE agent process remained during verification. Authentication prompts were not exercised.
- Created `~/.config/xdg-terminals.list` selecting `org.gnome.Ptyxis.desktop`. The existing Mod+Return shortcut still launches Ptyxis.
- Checked configured DMS IPC targets/functions against the live shell; all bindings in `cfg/shell.kdl` remain supported, including the `dankdash wallpaper` compatibility action.

Desktop backup: `/var/home/justin/.config/DankMaterialShell/backups/before-1.6.2-compatibility-20260930-144539`. It contains the pre-change Niri tree and DMS settings. The terminal preference file did not exist before this audit; remove it to undo that addition. Restore only the files needed, with DMS stopped while restoring its settings.

## Validation and limits

`niri validate` passes before and after applying the staged configuration. Both monitor positions/scales are unchanged: DP-2 at (0, 0), scale 1.5; eDP-1 at (2560, 0), scale 2. The plugin reports loaded on both bars. Live screenshots confirm titles, arrows, plus, and the empty-workspace label. `make check` passes all five model tests and scaffold checks. Click, launcher, tooltip, and overflow interactions still require manual acceptance checks.

`dms doctor` reports zero errors and three warnings: Bazzite is unsupported by its automatic setup command; PowerProfilesDaemon is unavailable/masked; and its terminal heuristic does not recognize installed Ptyxis. Selecting Ptyxis through `xdg-terminals.list` addresses terminal launch preference without installing another emulator.

Startup also reports malformed external application desktop entries, a host portal registration warning, English translation fallback, and attempted inactive Sway/Hyprland connections. These are outside the plugin's QML/configuration repair; no errors naming this plugin appeared. Optional khal is absent; dankcalendar is installed. Calendar synchronization and the system power-profile service were not reconfigured. This audit does not guarantee compatibility of every third-party plugin or optional service.
