# Desktop compatibility audit — 2026-09-30

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
