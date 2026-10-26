"""Run Qt's QML tools against repository files and the local DMS import snapshot."""

import argparse
import configparser
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def tool(name):
    override = os.environ.get(name.upper())
    if override:
        return override
    executable = shutil.which(name)
    if executable:
        return executable
    qtpaths = shutil.which("qtpaths6")
    if qtpaths:
        result = subprocess.run(
            [qtpaths, "--query", "QT_HOST_BINS"], capture_output=True, text=True, check=False
        )
        candidate = Path(result.stdout.strip()) / name
        if result.returncode == 0 and candidate.is_file():
            return str(candidate)
    raise ValueError(f"{name} is required; install Qt QML tools or set {name.upper()} to its path")


def run(action):
    files = sorted([*(ROOT / "plugins").rglob("*.qml"), *(ROOT / "shared").rglob("*.qml")])
    if action == "lint":
        files = sorted((ROOT / "dist").glob("*/*.qml")) + sorted(
            (ROOT / "dist").glob("*/state/*.qml")
        )
        if not files:
            raise ValueError("Plugin packages are missing; run make package first")
        imports = ROOT / ".local/dms-tooling/imports"
        if not (imports / "qs/Modules/Plugins/qmldir").is_file():
            raise ValueError(
                "DMS import metadata is missing; run scripts/setup-qml-tooling.py --dms-source PATH"
            )
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / ".qmlls.ini")
        paths = config.get("General", "importPaths", fallback=str(imports)).strip('"').split(":")
        command = [tool("qmllint"), "--ignore-settings", "--max-warnings", "0"]
        for path in dict.fromkeys([str(imports), *paths]):
            command += ["-I", path]
        return subprocess.run(command + [str(file) for file in files], check=False).returncode
    formatter = tool("qmlformat")
    files += sorted((ROOT / "tests/qml").rglob("*.qml"))
    failed = False
    for file in files:
        result = subprocess.run(
            [formatter, "--settings", str(ROOT / ".qmlformat.ini"), str(file)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            sys.stderr.write(result.stderr)
            failed = True
        elif action == "format":
            file.write_text(result.stdout)
        elif file.read_text() != result.stdout:
            print(f"{file.relative_to(ROOT)}: run make format", file=sys.stderr)
            failed = True
    return int(failed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("lint", "format", "check-format"))
    args = parser.parse_args()
    try:
        return run(args.action)
    except (ValueError, OSError, configparser.Error) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    sys.exit(main())
