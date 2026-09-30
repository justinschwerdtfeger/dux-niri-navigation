# Justin Navigation

A DMS plugin project for Material Shell-inspired navigation on Niri: window titles across the top and workspace icons down the left.

This is an initial scaffold. It supplies a horizontal/vertical bar widget, live Niri window and workspace counts, and a configurable label. Window buttons, workspace buttons, icons, and launch actions are not implemented yet. Counts cover all outputs and include Niri's trailing empty workspace.

## Intended behavior

- Top bar: windows on the bar's current workspace, in Niri's layout order, with titles and click-to-focus.
- Top-bar plus: open the existing DMS app launcher. Let Niri place newly created windows.
- Left bar: dynamic workspace navigation with small user-selected icons.
- Keep unnamed workspaces that disappear when empty; do not turn them into persistent named workspaces.
- Reuse DMS for settings, launcher, notifications, and other desktop services.

The project name and plugin id are provisional. This is a plugin, not a shell or compositor fork.

## Local development

Requires Niri and a functioning DMS installation with its supported Quickshell runtime. This plugin loads inside DMS; it is not a standalone `qs -p` configuration.

From the repository root, link it into DMS's plugin directory:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
ln -s "$PWD" "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/JustinNavigation"
```

The link command deliberately fails if that destination already exists. Inspect an existing destination before replacing it.

In DMS Settings → Plugins, scan for plugins, enable **Justin Navigation**, then add it to a DankBar widget list. A horizontal bar shows the label and counts; a vertical bar shows the icon and workspace count. This scaffold has no click actions.

After edits:

```bash
dms ipc call plugins reload justinNavigation
```

To remove the development link, first verify it points here, then remove only that link and disable the plugin in DMS. Setup is manual; repository checks do not alter your desktop configuration.

## Checks

```bash
make check
```

This validates the manifest, entry-point paths, and patch whitespace. It does not compile QML or prove DMS compatibility. See [development notes](docs/DEVELOPMENT.md) for runtime checks and the baseline inspected during scaffolding.

## Project map

| File | Purpose |
| --- | --- |
| `plugin.json` | DMS plugin identity and entry points |
| `NavigationWidget.qml` | Horizontal and vertical bar components |
| `NiriState.qml` | Boundary around DMS compositor services |
| `NavigationSettings.qml` | DMS-integrated settings |
| [Design](docs/DESIGN.md) | Decisions, limits, and next milestones |
| [Development](docs/DEVELOPMENT.md) | Upstream references and validation |
| [Agent guidance](AGENTS.md) | Context and working rules for future agents |
