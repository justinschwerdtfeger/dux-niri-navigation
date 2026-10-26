"""Verify both installation links and conflict preflight in a temporary config tree."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LinkPluginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["python3", str(ROOT / "scripts/package_plugins.py")], check=True)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.config = Path(temporary.name)
        self.parent = self.config / "dms/plugins"

    def link(self, selection="all"):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/link-plugin.sh"), selection],
            env=dict(os.environ, XDG_CONFIG_HOME=str(self.config)),
            capture_output=True,
            text=True,
            check=False,
        )

    def test_both_links_are_correct_and_repeated_setup_is_safe(self):
        self.assertEqual(self.link().returncode, 0)
        self.assertEqual(self.link().returncode, 0)
        self.assertEqual(
            (self.parent / "JustinNavigation").resolve(), ROOT / "dist/justinNavigation"
        )
        self.assertEqual(
            (self.parent / "JustinWorkspaces").resolve(), ROOT / "dist/justinWorkspaces"
        )

    def test_either_plugin_can_be_linked_alone(self):
        self.assertEqual(self.link("workspaces").returncode, 0)
        self.assertFalse((self.parent / "JustinNavigation").exists())
        self.assertEqual(self.link("window-tabs").returncode, 0)

    def test_unknown_selection_does_not_create_links(self):
        self.assertNotEqual(self.link("invalid").returncode, 0)
        self.assertFalse(self.parent.exists())

    def test_legacy_checkout_link_is_preserved(self):
        self.parent.mkdir(parents=True)
        legacy = self.parent / "JustinNavigation"
        legacy.symlink_to(ROOT)
        self.assertNotEqual(self.link().returncode, 0)
        self.assertEqual(legacy.resolve(), ROOT)
        self.assertFalse((self.parent / "JustinWorkspaces").exists())

    def test_conflicting_workspace_path_prevents_partial_installation(self):
        conflict = self.parent / "JustinWorkspaces"
        conflict.mkdir(parents=True)
        (conflict / "keep").write_text("existing plugin")
        self.assertNotEqual(self.link().returncode, 0)
        self.assertFalse((self.parent / "JustinNavigation").exists())
        self.assertEqual((conflict / "keep").read_text(), "existing plugin")

    def test_broken_window_link_is_preserved(self):
        self.parent.mkdir(parents=True)
        conflict = self.parent / "JustinNavigation"
        conflict.symlink_to(self.config / "missing")
        self.assertNotEqual(self.link().returncode, 0)
        self.assertTrue(conflict.is_symlink())
        self.assertFalse((self.parent / "JustinWorkspaces").exists())
