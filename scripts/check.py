"""Validate the plugin's packaging without starting a desktop session."""

import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
for script in (root / "scripts").glob("*.py"):
    compile(script.read_text(), str(script), "exec")
ids = set()
for package in (root, root / "workspace-plugin"):
    manifest = json.loads((package / "plugin.json").read_text())
    required = ("id", "name", "description", "version", "author", "type", "settings")
    for key in required:
        if not isinstance(manifest.get(key), str) or not manifest[key]:
            raise SystemExit(f"{package.name}/plugin.json: missing or invalid {key}")
    if manifest["id"] in ids:
        raise SystemExit("Plugin IDs must be distinct")
    ids.add(manifest["id"])
    if package == root:
        if manifest["type"] != "composite" or set(manifest.get("components", {})) != {
            "widget",
            "daemon",
        }:
            raise SystemExit("Window Tabs must provide widget and daemon surfaces")
        paths = {**manifest["components"], "settings": manifest["settings"]}
    else:
        if manifest["type"] != "widget":
            raise SystemExit("Workspaces must be a widget plugin")
        paths = {"component": manifest.get("component"), "settings": manifest["settings"]}
    for key, value in paths.items():
        if not isinstance(value, str) or not value:
            raise SystemExit(f"{package.name}/plugin.json: invalid {key} path")
        path = (package / value).resolve()
        if not path.is_relative_to(package) or not path.is_file() or path.suffix != ".qml":
            raise SystemExit(f"{package.name}/plugin.json: invalid {key} path")
    if "dankbar-widget" not in manifest.get("capabilities", []):
        raise SystemExit("Missing dankbar-widget capability")

shared = root / "workspace-plugin/shared"
if not shared.is_symlink() or shared.resolve() != root:
    raise SystemExit("Workspace plugin's shared link must point to the repository root")
print("Both plugin manifests and entry points are valid. QML runtime validation is separate.")
