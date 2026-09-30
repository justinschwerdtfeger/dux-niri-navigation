"""Validate the plugin's packaging without starting a desktop session."""

import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
tooling_script = root / "scripts/setup-qml-tooling.py"
compile(tooling_script.read_text(), str(tooling_script), "exec")
manifest = json.loads((root / "plugin.json").read_text())
required = ("id", "name", "description", "version", "author", "type", "component", "settings")
for key in required:
    if not isinstance(manifest.get(key), str) or not manifest[key]:
        raise SystemExit(f"plugin.json: missing or invalid {key}")

if manifest["type"] != "widget":
    raise SystemExit("Expected a DMS widget plugin")

for key in ("component", "settings"):
    path = (root / manifest[key]).resolve()
    if not path.is_relative_to(root) or not path.is_file() or path.suffix != ".qml":
        raise SystemExit(f"plugin.json: invalid {key} path")

if "dankbar-widget" not in manifest.get("capabilities", []):
    raise SystemExit("Missing dankbar-widget capability")

print("Plugin manifest and entry points are valid. QML runtime validation is separate.")
