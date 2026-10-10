"""Exercise tooling refresh and failure recovery without starting Quickshell."""

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "qml_tooling", Path(__file__).resolve().parents[1] / "scripts/setup-qml-tooling.py"
)
tooling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tooling)


class ToolingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        self.root = base / "repo"
        self.source = base / "dms"
        self.root.mkdir()
        for name in (
            "shell.qml",
            "Common/Theme.qml",
            "Widgets/StyledText.qml",
            "Services/NiriService.qml",
            "Modules/Plugins/PluginComponent.qml",
            "DankCommon/Common/Style.qml",
            "DankCommon/Widgets/StyledText.qml",
        ):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original DMS source\n")
        self.local = self.root / ".local/dms-tooling"
        (self.source / "Common/QmlUtils.js").write_text("function helper() {}\n")
        (self.source / "assets").mkdir()
        (self.source / "assets/icon.svg").write_text("<svg/>\n")
        self.local.mkdir(parents=True)
        for name in ("source", "imports"):
            (self.local / name).mkdir()
            (self.local / name / "previous").write_text("keep me")
        (self.local / "SOURCE.txt").write_text("previous source")
        (self.root / ".qmlls.ini").write_text("previous config")
        editor = self.root / ".vscode/settings.json"
        editor.parent.mkdir()
        editor.write_text('// existing JSONC\n{"custom": true}\n')

    def scanner(self, command, *, env, **kwargs):
        snapshot = Path(command[2])
        self.assertIn("ShellRoot", (snapshot / "shell.qml").read_text())
        self.assertNotIn("original DMS source", (snapshot / "shell.qml").read_text())
        self.assertEqual(env["QT_QPA_PLATFORM"], "offscreen")
        generated = Path(env["XDG_RUNTIME_DIR"]) / "vfs"
        for module in (
            "Common",
            "Widgets",
            "Services",
            "Modules/Plugins",
            "DankCommon/Common",
            "DankCommon/Widgets",
        ):
            directory = generated / "qs" / module
            directory.mkdir(parents=True)
            (directory / "qmldir").write_text(f"module qs.{module.replace('/', '.')}\n")
        (generated / "qs/Common/Theme.qml").symlink_to(snapshot / "Common/Theme.qml")
        (snapshot / ".qmlls.ini").write_text(
            f'[General]\nbuildDir="{generated}"\nimportPaths="/qt/qml"\n'
        )
        return tooling.subprocess.CompletedProcess(command, 0, "", "")

    def run_setup(self, source=None, scanner=None):
        with (
            patch.object(tooling.shutil, "which", return_value="/fake/qs"),
            patch.object(tooling.subprocess, "run", side_effect=scanner or self.scanner),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            tooling.setup(self.root, source or self.source)

    def assert_preserved(self):
        self.assertEqual((self.local / "source/previous").read_text(), "keep me")
        self.assertEqual((self.local / "imports/previous").read_text(), "keep me")
        self.assertEqual((self.root / ".qmlls.ini").read_text(), "previous config")
        self.assertEqual((self.local / "SOURCE.txt").read_text(), "previous source")
        self.assertFalse(list(self.local.glob(".build-*")))

    def test_refresh_is_repeatable_and_imports_outlive_scanner_runtime(self):
        original = (self.source / "shell.qml").read_text()
        self.run_setup()
        self.run_setup()
        theme = self.local / "imports/qs/Common/Theme.qml"
        self.assertFalse(theme.is_symlink())
        self.assertEqual(theme.read_text(), "original DMS source\n")
        self.assertEqual(
            (self.local / "imports/qs/Common/QmlUtils.js").read_text(), "function helper() {}\n"
        )
        self.assertEqual((self.local / "imports/qs/assets/icon.svg").read_text(), "<svg/>\n")
        self.assertFalse((self.local / "imports/qs/.qmlls.ini").exists())
        config = tooling.configparser.ConfigParser()
        config.read(self.root / ".qmlls.ini")
        self.assertEqual(config["General"]["buildDir"].strip('"'), str(self.local / "imports"))
        self.assertEqual((self.source / "shell.qml").read_text(), original)
        self.assertEqual(
            (self.root / ".vscode/settings.json").read_text(),
            '// existing JSONC\n{"custom": true}\n',
        )
        self.assertFalse(list(self.local.glob(".build-*")))

    def test_new_editor_settings_are_valid_json(self):
        (self.root / ".vscode/settings.json").unlink()
        self.run_setup()
        settings = tooling.json.loads((self.root / ".vscode/settings.json").read_text())
        self.assertTrue(settings["qt-qml.qmlls.enabled"])

    def test_read_only_embedded_source_can_be_snapshotted(self):
        directories = [self.source, *[p for p in self.source.rglob("*") if p.is_dir()]]
        try:
            for directory in directories:
                directory.chmod(0o555)
            self.run_setup()
            self.assertTrue((self.local / "imports/qs/Common/qmldir").is_file())
            self.assertEqual(self.source.stat().st_mode & 0o777, 0o555)
        finally:
            for directory in directories:
                directory.chmod(0o700)

    def test_overlapping_sources_are_rejected_before_changing_anything(self):
        for source in (self.local / "source", self.local, self.root, self.root.parent):
            with self.subTest(source=source), self.assertRaisesRegex(ValueError, "outside"):
                self.run_setup(source)
            self.assert_preserved()

    def test_missing_submodule_is_rejected(self):
        (self.source / "DankCommon/Common/Style.qml").unlink()
        with self.assertRaisesRegex(ValueError, "DankCommon"):
            self.run_setup()
        self.assert_preserved()

    def test_scanner_failure_or_missing_metadata_preserves_working_setup(self):
        failures = (
            tooling.subprocess.CompletedProcess([], 1, "", "scanner error"),
            tooling.subprocess.CompletedProcess([], 0, "", ""),
            tooling.subprocess.TimeoutExpired(["qs"], 30),
        )
        for result in failures:

            def fail(*args, result=result, **kwargs):
                if isinstance(result, Exception):
                    raise result
                return result

            with self.subTest(result=result), self.assertRaises(ValueError):
                self.run_setup(scanner=fail)
            self.assert_preserved()

    def test_publish_failure_restores_already_replaced_artifacts(self):
        rename = Path.rename

        def fail_once(path, destination):
            if path.name == "imports" and path.parent.name.startswith(".build-"):
                raise OSError("simulated write failure")
            return rename(path, destination)

        with patch.object(Path, "rename", fail_once), self.assertRaises(OSError):
            self.run_setup()
        self.assert_preserved()

    def test_generated_path_symlink_is_preserved_and_not_followed(self):
        imports = self.local / "imports"
        tooling.shutil.rmtree(imports)
        imports.symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.run_setup()
        self.assertTrue(imports.is_symlink())
        self.assertEqual((self.local / "source/previous").read_text(), "keep me")
        self.assertEqual((self.root / ".qmlls.ini").read_text(), "previous config")
        self.assertEqual((self.source / "shell.qml").read_text(), "original DMS source\n")


if __name__ == "__main__":
    unittest.main()
