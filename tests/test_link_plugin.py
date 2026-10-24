"""Verify both installation links and conflict preflight in a temporary config tree."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LinkPluginTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.config = Path(temporary.name)
        self.parent = self.config / "DankMaterialShell/plugins"

    def link(self):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/link-plugin.sh")],
            env=dict(os.environ, XDG_CONFIG_HOME=str(self.config)),
            capture_output=True,
            text=True,
            check=False,
        )

    def test_both_links_are_correct_and_repeated_setup_is_safe(self):
        self.assertEqual(self.link().returncode, 0)
        self.assertEqual(self.link().returncode, 0)
        self.assertEqual((self.parent / "JustinNavigation").resolve(), ROOT)
        self.assertEqual((self.parent / "JustinWorkspaces").resolve(), ROOT / "workspace-plugin")

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
