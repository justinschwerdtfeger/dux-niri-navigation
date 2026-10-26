"""Build independent DMS plugin directories and versioned release archives."""

import argparse
import json
import shutil
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGINS = {"window-tabs": "justinNavigation", "workspaces": "justinWorkspaces"}
# Keep the ownership marker so pre-rename generated packages can still be rebuilt.
MARKER = ".justin-shell-package"


def selected_plugins(selection):
    return PLUGINS if selection == "all" else {selection: PLUGINS[selection]}


def runtime_files(directory):
    return sorted(
        path
        for path in directory.rglob("*")
        if path.is_file()
        and (path.suffix in {".qml", ".js", ".json", ".py", ".md"} or path.name == "qmldir")
    )


def build(output, selection="all"):
    output = Path(output).resolve()
    # Never allow a build to overwrite its source tree.
    for source in (ROOT / "shared", ROOT / "plugins"):
        if output.is_relative_to(source) or source.is_relative_to(output):
            raise ValueError("Package output must be separate from the source directories")
    output.mkdir(parents=True, exist_ok=True)
    selected = selected_plugins(selection)
    for plugin_id in selected.values():
        target = output / plugin_id
        if target.is_symlink() or (target.exists() and not (target / MARKER).is_file()):
            raise ValueError(
                f"Refusing to replace a directory not created by this packager: {target}"
            )
    results = []
    for name, plugin_id in selected.items():
        with tempfile.TemporaryDirectory(prefix=".package-", dir=output) as temporary:
            staged = Path(temporary) / plugin_id
            staged.mkdir()
            for source in (ROOT / "shared", ROOT / "plugins" / name):
                for path in runtime_files(source):
                    relative = path.relative_to(source)
                    target = staged / relative
                    if target.exists():
                        raise ValueError(f"Duplicate package file: {relative}")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, target)
            (staged / MARKER).write_text(f"{plugin_id}\n")
            manifest = json.loads((staged / "plugin.json").read_text())
            if manifest["id"] != plugin_id:
                raise ValueError(f"Unexpected plugin ID in {name}")
            archive_name = f"{plugin_id}-{manifest['version']}.tar.gz"
            archive = Path(temporary) / archive_name
            with tarfile.open(archive, "w:gz") as bundle:
                bundle.add(staged, arcname=plugin_id)
            destination = output / plugin_id
            if destination.exists():
                shutil.rmtree(destination)
            staged.rename(destination)
            archive.replace(output / archive_name)
            results.append(destination)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugin", choices=["all", *PLUGINS], default="all")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    try:
        for package in build(args.output, args.plugin):
            print(f"Packaged {package.name}: {package}")
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
