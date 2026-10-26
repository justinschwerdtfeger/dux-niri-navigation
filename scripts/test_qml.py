"""Run component tests on relocated bundles, then load each plugin on its own."""

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from package_plugins import PLUGINS, ROOT


def run(runner):
    with tempfile.TemporaryDirectory(prefix="dux-niri-navigation-qml-") as temporary:
        stage = Path(temporary)
        shutil.copytree(ROOT / "tests/qml", stage / "tests/qml")
        for plugin_id in PLUGINS.values():
            shutil.copytree(ROOT / "dist" / plugin_id, stage / "dist" / plugin_id)
        command = [runner, "-import", str(stage / "tests/qml/imports")]
        environment = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        result = subprocess.run(
            [*command, "-input", str(stage / "tests/qml")], env=environment, check=False
        )
        if result.returncode:
            return result.returncode
        # Each smoke run has exactly one plugin directory and no source checkout.
        for plugin_id, widget in [
            ("justinNavigation", "NavigationWidget"),
            ("justinWorkspaces", "WorkspaceWidget"),
        ]:
            with tempfile.TemporaryDirectory(dir=stage) as isolated:
                isolated = Path(isolated)
                shutil.copytree(ROOT / "dist" / plugin_id, isolated / "package")
                (isolated / "tst_package.qml").write_text(
                    'import QtQuick\nimport QtTest\nimport "package" as Plugin\n'
                    "Item {\n"
                    f"    Plugin.{widget} {{ id: widget; "
                    'parentScreen: ({name: "DP-1", width: 1920, height: 1080}) }\n'
                    "    TestCase {\n"
                    f'        name: "Standalone_{plugin_id}"; when: windowShown\n'
                    "        function test_load() { verify(widget.width > 0); verify(widget.height > 0); }\n"
                    "    }\n}\n"
                )
                result = subprocess.run(
                    [*command, "-input", str(isolated)], env=environment, check=False
                )
                if result.returncode:
                    return result.returncode
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", default="qmltestrunner")
    arguments = parser.parse_args()
    try:
        raise SystemExit(run(arguments.runner))
    except OSError as error:
        parser.exit(1, f"{error}\n")
