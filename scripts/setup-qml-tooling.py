#!/usr/bin/env python3
"""Generate persistent, local DMS imports using Quickshell's own tooling scanner."""

import argparse
import configparser
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--dms-source", type=Path, required=True,
                    help="Source directory of the active DMS UI, containing shell.qml")
args = parser.parse_args()
source = args.dms_source.resolve()
if not (source / "shell.qml").is_file():
    parser.error("DMS source must contain shell.qml")

local = root / ".local/dms-tooling"
local.mkdir(parents=True, exist_ok=True)
snapshot = local / "source"


def writable_directories(tree):
    tree.chmod(0o700)
    for path in tree.rglob("*"):
        if path.is_dir():
            path.chmod(0o700)


if snapshot.exists():
    writable_directories(snapshot)
    shutil.rmtree(snapshot)
shutil.copytree(source, snapshot, copy_function=shutil.copyfile,
                ignore=shutil.ignore_patterns(".qmlls.ini", ".git"))
writable_directories(snapshot)
# Import modules for scanning, without loading DMSShell or instantiating services.
(snapshot / "shell.qml").write_text("""import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import qs.DankCommon.Common
import qs.DankCommon.Widgets

ShellRoot {
    Timer { interval: 100; running: true; onTriggered: Qt.quit() }
}
""")
(snapshot / ".qmlls.ini").touch()
runtime = local / "runtime"
runtime.mkdir(exist_ok=True, mode=0o700)
runtime.chmod(0o700)
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
           QT_STYLE_OVERRIDE="", XDG_CURRENT_DESKTOP="", DISPLAY="",
           XDG_RUNTIME_DIR=str(runtime))
result = subprocess.run(["qs", "-p", str(snapshot)], env=env,
                        capture_output=True, text=True, timeout=30)
if result.returncode:
    raise SystemExit(result.stdout + result.stderr)

config = configparser.ConfigParser()
config.read(snapshot / ".qmlls.ini")
generated = Path(config["General"]["buildDir"].strip('"'))
if not (generated / "qs/Common/qmldir").is_file():
    raise SystemExit("Quickshell did not generate the DMS module metadata")

# Persist scanner output; its default runtime directory disappears at reboot.
imports = local / "imports"
if imports.exists():
    shutil.rmtree(imports)
shutil.copytree(generated / "qs", imports / "qs", symlinks=False)
paths = config["General"]["importPaths"].strip('"')
(root / ".qmlls.ini").write_text(
    f'[General]\nno-cmake-calls=true\nbuildDir="{imports}"\n'
    f'importPaths="{imports}:{paths}"\n')

editor = root / ".vscode/settings.json"
editor.parent.mkdir(exist_ok=True)
if editor.exists():
    # Leave existing JSON/JSONC preferences untouched; .qmlls.ini is sufficient.
    print("Existing VS Code settings preserved.")
else:
    editor.write_text(json.dumps({"qt-qml.qmlls.enabled": True,
                                 "qt-qml.qmlls.useNoCMakeCalls": True}, indent=2) + "\n")
(local / "SOURCE.txt").write_text(f"DMS source snapshot: {source}\n")
print(f"Generated DMS imports: {imports}")
print("In VS Code run: Qt: Restart QML Language Server")
