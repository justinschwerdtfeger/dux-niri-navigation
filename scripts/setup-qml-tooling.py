#!/usr/bin/env python3
"""Generate persistent, local DMS imports using Quickshell's own tooling scanner."""

import argparse
import configparser
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

HELPER = """import QtQuick
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
"""


def publish(entries, backup):
    """Replace generated artifacts together, restoring old ones on a write failure."""
    replaced = []
    try:
        for index, (staged, destination) in enumerate(entries):
            previous = backup / str(index)
            if destination.is_symlink():
                raise ValueError(f"Refusing to replace generated-path symlink: {destination}")
            if destination.exists():
                destination.rename(previous)
            replaced.append((destination, previous))
            staged.rename(destination)
    except Exception:
        for destination, previous in reversed(replaced):
            if destination.is_dir():
                shutil.rmtree(destination)
            elif destination.exists():
                destination.unlink()
            if previous.exists():
                previous.rename(destination)
        raise


def setup(root, source):
    source = source.resolve()
    local = root / ".local/dms-tooling"
    # Reject both directions before deleting or copying anything. Otherwise a
    # snapshot source can be deleted, or a parent source copied into itself.
    if source.is_relative_to(local.resolve()) or local.resolve().is_relative_to(source):
        raise ValueError("DMS source must be outside this repository's tooling directory")
    required = ("shell.qml", "Common/Theme.qml", "Widgets/StyledText.qml",
                "Services/NiriService.qml", "Modules/Plugins/PluginComponent.qml",
                "DankCommon/Common/Style.qml", "DankCommon/Widgets/StyledText.qml")
    for name in required:
        if not (source / name).is_file():
            raise ValueError(f"DMS source is missing {name}; include the DankCommon submodule")
    scanner = shutil.which("qs")
    if not scanner:
        raise ValueError("Quickshell (qs) is required to generate QML imports")

    local.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=local) as temporary:
        stage = Path(temporary)
        snapshot = stage / "source"
        shutil.copytree(source, snapshot, copy_function=shutil.copyfile,
                        ignore=shutil.ignore_patterns(".qmlls.ini", ".git"))
        # copyfile avoids read-only file permissions; copytree still copies
        # directory modes from embedded UI, so make those writable as well.
        snapshot.chmod(0o700)
        for directory in snapshot.rglob("*"):
            if directory.is_dir():
                directory.chmod(0o700)
        (snapshot / "shell.qml").write_text(HELPER)
        (snapshot / ".qmlls.ini").touch()
        runtime = stage / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
                   QT_STYLE_OVERRIDE="", XDG_CURRENT_DESKTOP="", DISPLAY="",
                   XDG_RUNTIME_DIR=str(runtime))
        try:
            result = subprocess.run([scanner, "-p", str(snapshot)], env=env,
                                    capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired as error:
            raise ValueError("Quickshell metadata generation timed out after 30 seconds") from error
        if result.returncode:
            raise ValueError("Quickshell metadata generation failed:\n" + result.stdout + result.stderr)

        config = configparser.ConfigParser(interpolation=None)
        config.read(snapshot / ".qmlls.ini")
        try:
            generated = Path(config["General"]["buildDir"].strip('"'))
            paths = config["General"]["importPaths"].strip('"')
        except KeyError as error:
            raise ValueError("Quickshell did not write its QML tooling configuration") from error
        if not generated.is_absolute():
            generated = snapshot / generated
        for module in ("Common", "Widgets", "Services", "Modules/Plugins",
                       "DankCommon/Common", "DankCommon/Widgets"):
            if not (generated / "qs" / module / "qmldir").is_file():
                raise ValueError(f"Quickshell did not generate metadata for qs.{module.replace('/', '.')}")

        # Dereference scanner symlinks before the temporary runtime disappears.
        # The scanner only exposes QML types, not imported JavaScript or assets.
        # Preserve the source tree too so relative imports remain resolvable.
        imports = local / "imports"
        shutil.copytree(snapshot, stage / "imports/qs", copy_function=shutil.copyfile,
                        ignore=shutil.ignore_patterns(".qmlls.ini"))
        shutil.copytree(generated / "qs", stage / "imports/qs", symlinks=False,
                        dirs_exist_ok=True)
        # The snapshot's scanner paths are temporary; only the root config is used.
        (snapshot / ".qmlls.ini").unlink()
        ini = stage / "qmlls.ini"
        ini.write_text(f'[General]\nno-cmake-calls=true\nbuildDir="{imports}"\n'
                       f'importPaths="{imports}:{paths}"\n')
        provenance = stage / "SOURCE.txt"
        provenance.write_text(f"DMS source snapshot: {source}\n")
        backup = stage / "backup"
        backup.mkdir()
        publish([(snapshot, local / "source"), (stage / "imports", imports),
                 (ini, root / ".qmlls.ini"), (provenance, local / "SOURCE.txt")], backup)

    editor = root / ".vscode/settings.json"
    editor.parent.mkdir(exist_ok=True)
    try:
        with editor.open("x") as settings:
            json.dump({"qt-qml.qmlls.enabled": True,
                       "qt-qml.qmlls.useNoCMakeCalls": True}, settings, indent=2)
            settings.write("\n")
    except FileExistsError:
        print("Existing VS Code settings preserved.")
    print(f"Generated DMS imports: {imports}")
    print("In VS Code run: Qt: Restart QML Language Server")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dms-source", type=Path, required=True,
                        help="Source directory of the active DMS UI, containing shell.qml")
    args = parser.parse_args()
    try:
        setup(Path(__file__).resolve().parent.parent, args.dms_source)
    except (ValueError, OSError, configparser.Error) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
