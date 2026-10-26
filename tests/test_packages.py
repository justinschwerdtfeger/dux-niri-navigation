"""Verify release bundles remain complete after relocation without the checkout."""

import importlib.util
import json
import re
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "package_plugins", ROOT / "scripts/package_plugins.py"
)
packager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.output = Path(temporary.name) / "packages"

    def test_each_archive_can_be_relocated_without_other_plugin_or_checkout(self):
        for selection, plugin_id in packager.PLUGINS.items():
            with self.subTest(plugin=selection), tempfile.TemporaryDirectory() as isolated:
                output = self.output / selection
                (package,) = packager.build(output, selection)
                self.assertEqual(
                    [path.name for path in output.iterdir() if path.is_dir()], [plugin_id]
                )
                manifest = json.loads((package / "plugin.json").read_text())
                archive = output / f"{plugin_id}-{manifest['version']}.tar.gz"
                with tarfile.open(archive) as bundle:
                    self.assertTrue(all(member.isfile() or member.isdir() for member in bundle))
                    bundle.extractall(isolated, filter="data")
                relocated = Path(isolated) / plugin_id
                self.assertEqual(
                    {path.relative_to(package) for path in package.rglob("*") if path.is_file()},
                    {
                        path.relative_to(relocated)
                        for path in relocated.rglob("*")
                        if path.is_file()
                    },
                )
                for path in relocated.rglob("*"):
                    self.assertFalse(path.is_symlink())
                    if path.suffix not in {".qml", ".js"}:
                        continue
                    # QML/JS imports and the favicon helper must resolve inside the bundle.
                    references = re.findall(r'^\.?import\s+"([^"]+)"', path.read_text(), re.M)
                    references += re.findall(r'Qt\.resolvedUrl\("([^"]+)"\)', path.read_text())
                    for reference in references:
                        dependency = (path.parent / reference).resolve()
                        self.assertTrue(dependency.is_relative_to(relocated), reference)
                        self.assertTrue(dependency.exists(), f"{path}: {reference}")
                entrypoints = manifest.get("components", {"widget": manifest.get("component")})
                for relative in [*entrypoints.values(), manifest["settings"]]:
                    self.assertTrue((relocated / relative).is_file())
                other_widget = (
                    "WorkspaceWidget.qml" if selection == "window-tabs" else "NavigationWidget.qml"
                )
                self.assertFalse((relocated / other_widget).exists())

    def test_rebuild_removes_stale_files_only_in_selected_package(self):
        windows, workspaces = packager.build(self.output)
        (windows / "stale.qml").write_text("old")
        (workspaces / "keep.qml").write_text("untouched")
        packager.build(self.output, "window-tabs")
        self.assertFalse((windows / "stale.qml").exists())
        self.assertEqual((workspaces / "keep.qml").read_text(), "untouched")

    def test_foreign_directory_and_source_tree_are_not_overwritten(self):
        foreign = self.output / "justinWorkspaces"
        foreign.mkdir(parents=True)
        (foreign / "keep").write_text("existing")
        with self.assertRaises(ValueError):
            packager.build(self.output)
        self.assertFalse((self.output / "justinNavigation").exists())
        self.assertEqual((foreign / "keep").read_text(), "existing")
        for source in [ROOT, ROOT / "shared", ROOT / "plugins/window-tabs"]:
            with self.assertRaises(ValueError):
                packager.build(source)
