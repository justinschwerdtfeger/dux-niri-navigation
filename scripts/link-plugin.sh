#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
plugin_parent="${XDG_CONFIG_HOME:-$HOME/.config}/dms/plugins"
sources=("$repo_dir" "$repo_dir/workspace-plugin")
names=(JustinNavigation JustinWorkspaces)

# Validate every destination before creating either link.
for index in "${!names[@]}"; do
    destination="$plugin_parent/${names[$index]}"
    if [[ -L "$destination" ]] && [[ "$(readlink -f -- "$destination")" == "${sources[$index]}" ]]; then
        continue
    fi
    if [[ -e "$destination" || -L "$destination" ]]; then
        printf 'Refusing to replace existing path: %s\n' "$destination" >&2
        exit 1
    fi
done

mkdir -p -- "$plugin_parent"
for index in "${!names[@]}"; do
    destination="$plugin_parent/${names[$index]}"
    if [[ ! -L "$destination" ]]; then
        ln -s -- "${sources[$index]}" "$destination"
    fi
    printf 'Plugin linked: %s\n' "$destination"
done
printf 'Next: DMS Settings → Plugins → Scan, then enable Justin Window Tabs and Justin Workspaces.\n'
