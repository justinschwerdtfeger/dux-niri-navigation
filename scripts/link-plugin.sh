#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
plugin_parent="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
plugin_destination="$plugin_parent/JustinNavigation"

if [[ -L "$plugin_destination" ]] && [[ "$(readlink -f -- "$plugin_destination")" == "$repo_dir" ]]; then
    printf 'Plugin is already linked: %s\n' "$plugin_destination"
    exit 0
fi
if [[ -e "$plugin_destination" || -L "$plugin_destination" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$plugin_destination" >&2
    exit 1
fi

mkdir -p -- "$plugin_parent"
ln -s -- "$repo_dir" "$plugin_destination"
printf 'Linked plugin: %s\nNext: DMS Settings → Plugins → Scan, then enable Justin Navigation and add it to your bar.\n' "$plugin_destination"
