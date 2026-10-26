"""Exercise Make's container startup in ordinary checkouts and linked worktrees."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class DevcontainerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.repo = self.base / "checkout with spaces"
        self.git("init", "--quiet", "--initial-branch=main", str(self.repo))
        shutil.copyfile(ROOT / "Makefile", self.repo / "Makefile")
        self.git("-C", str(self.repo), "add", "Makefile")
        self.git(
            "-C",
            str(self.repo),
            "-c",
            "user.name=Test",
            "-c",
            "user.email=test@example.org",
            "commit",
            "--quiet",
            "-m",
            "fixture",
        )
        self.cli = self.base / "cli"
        self.cli.write_text(
            "#!/usr/bin/env python3\nimport json, os, pathlib, sys\n"
            "pathlib.Path(os.environ['DEVCONTAINER_LOG']).write_text(json.dumps(sys.argv[1:]))\n"
        )
        self.cli.chmod(0o755)
        self.log = self.base / "invocation.json"

    def git(self, *args):
        subprocess.run(["git", *args], check=True, capture_output=True, text=True)

    def start(self, directory):
        return subprocess.run(
            ["make", "dev-up", f"DEVCONTAINER={self.cli}", "CONTAINER_ENGINE=docker"],
            cwd=directory,
            env=dict(os.environ, DEVCONTAINER_LOG=str(self.log)),
            capture_output=True,
            text=True,
            check=False,
        )

    def test_ordinary_checkout_needs_no_extra_mount(self):
        result = self.start(self.repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.log.read_text()),
            ["up", "--docker-path", "docker", "--workspace-folder", str(self.repo)],
        )

    def test_worktree_mounts_common_git_directory_as_one_argument(self):
        worktree = self.base / "linked worktree"
        self.git("-C", str(self.repo), "worktree", "add", "--quiet", "--detach", str(worktree))
        result = self.start(worktree)
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads(self.log.read_text())
        common = self.repo / ".git"
        self.assertEqual(arguments[-2:], ["--mount", f"type=bind,source={common},target={common}"])
        self.assertEqual(arguments[arguments.index("--workspace-folder") + 1], str(worktree))

    def test_unrepresentable_git_mount_fails_before_starting_container(self):
        renamed = self.base / "checkout,comma"
        self.repo.rename(renamed)
        worktree = self.base / "linked"
        self.git("-C", str(renamed), "worktree", "add", "--quiet", "--detach", str(worktree))
        result = self.start(worktree)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("comma", result.stderr)
        self.assertFalse(self.log.exists())
