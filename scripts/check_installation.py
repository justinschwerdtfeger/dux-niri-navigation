"""Reject a second user installation of any selected plugin ID."""

import argparse
import json
from pathlib import Path

from package_plugins import PLUGINS, ROOT

LINK_NAMES = {"justinNavigation": "JustinNavigation", "justinWorkspaces": "JustinWorkspaces"}


def check_installations(parent, selected):
    if not parent.exists():
        return
    for directory in sorted(parent.iterdir()):
        manifest = directory / "plugin.json"
        if not manifest.is_file():
            continue
        try:
            data = json.loads(manifest.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError):
            # Dux also ignores manifests it cannot parse.
            continue
        plugin_id = data.get("id") if isinstance(data, dict) else None
        if not isinstance(plugin_id, str) or plugin_id not in selected:
            continue
        expected_source = ROOT / "dist" / plugin_id
        if (
            directory.name == LINK_NAMES[plugin_id]
            and directory.is_symlink()
            and directory.resolve() == expected_source
        ):
            continue
        raise ValueError(
            f"Plugin {plugin_id} is already installed at {directory}; refusing a duplicate"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("parent", type=Path)
    parser.add_argument("ids", nargs="+", choices=list(PLUGINS.values()))
    args = parser.parse_args()
    try:
        check_installations(args.parent, set(args.ids))
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
