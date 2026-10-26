#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
plugin_parent="${XDG_CONFIG_HOME:-$HOME/.config}/dms/plugins"
case "${1:-all}" in
    all) ids=(justinNavigation justinWorkspaces); names=(JustinNavigation JustinWorkspaces) ;;
    window-tabs) ids=(justinNavigation); names=(JustinNavigation) ;;
    workspaces) ids=(justinWorkspaces); names=(JustinWorkspaces) ;;
    *) printf 'Usage: %s [all|window-tabs|workspaces]\n' "$0" >&2; exit 2 ;;
esac
sources=()
for id in "${ids[@]}"; do
    source="$repo_dir/dist/$id"
    if [[ ! -f "$source/plugin.json" ]]; then
        printf 'Missing package: %s; run make package first.\n' "$source" >&2
        exit 1
    fi
    sources+=("$source")
done

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
printf 'Next: DMS Settings → Plugins → Scan, then enable the linked plugins you want.\n'
