"""Behaviour tests of the tidy-commits scripts on a real temporary git repository.

The scripts rewrite history, so every case checks the one property that
matters: the original branch never moves unless the rebuilt history is
proven equivalent, and the initial state can always be recovered.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = REPO_ROOT / "agents" / "skills" / "tidy-commits" / "scripts"
APPLY = SCRIPTS / "tidy_apply.py"
FINALIZE = SCRIPTS / "tidy_finalize.py"


class TidyCommitsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name) / "repo"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Tester")
        self.git("config", "user.email", "tester@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.write("base.txt", "base\n")
        self.commit("Base commit")
        self.base = self.rev("HEAD")
        self.git("checkout", "-q", "-b", "feature")
        self.write("a.txt", "one\n")
        self.c1 = self.commit("Add a")
        self.write("b.txt", "b\n")
        self.c2 = self.commit("Add b")
        self.write("a.txt", "two\n")
        self.c3 = self.commit("Set a to two")
        self.orig = self.rev("feature")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args, check=True):
        return subprocess.run(
            ["git", *args], cwd=self.repo, text=True, capture_output=True, check=check,
        )

    def out(self, *args):
        return self.git(*args).stdout.strip()

    def rev(self, ref):
        return self.out("rev-parse", ref)

    def write(self, name, content):
        (self.repo / name).write_text(content)

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.rev("HEAD")

    def run_script(self, script, *args):
        return subprocess.run(
            [sys.executable, str(script), *args],
            cwd=self.repo, text=True, capture_output=True,
        )

    def apply(self, *args):
        return self.run_script(APPLY, *args)

    def finalize(self, *args):
        return self.run_script(FINALIZE, *args)

    def write_plan(self, commits, dropped=()):
        plan = self.repo.parent / "plan.json"
        plan.write_text(json.dumps({
            "base": self.base,
            "commits": commits,
            "dropped": list(dropped),
        }))
        return str(plan)

    def state_file(self):
        return Path(self.out("rev-parse", "--absolute-git-dir")) / "tidy-commits-state.json"

    def backup_branches(self):
        refs = self.out("for-each-ref", "--format=%(refname:short)", "refs/heads/tidy-backup/")
        return refs.splitlines() if refs else []

    def subjects(self, ref="HEAD"):
        return self.out("log", "--reverse", "--format=%s", f"{self.base}..{ref}").splitlines()

    def tree(self, ref):
        return self.out("rev-parse", f"{ref}^{{tree}}")

    def assert_initial_state(self):
        self.assertEqual(self.rev("feature"), self.orig)
        self.assertEqual(self.out("symbolic-ref", "--short", "HEAD"), "feature")
        self.assertEqual(self.out("status", "--porcelain"), "")
        self.assertFalse(self.state_file().exists())
        self.assertEqual(self.backup_branches(), [])

    def test_a_plan_omitting_a_commit_of_the_range_is_refused(self):
        plan = self.write_plan([
            {"message": "Add a", "from": [self.c1]},
            {"message": "Add b", "from": [self.c2]},
        ])

        result = self.apply("--plan", plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("neither reused nor dropped", result.stderr)
        self.assertIn("Set a to two", result.stderr)
        self.assert_initial_state()

    def test_a_valid_plan_moves_the_branch_only_after_the_invariant_holds(self):
        plan = self.write_plan([
            {"message": "Add b first", "from": [self.c2]},
            {"message": "Add a, set to two\n\nSquashed.", "from": [self.c1, self.c3]},
        ])

        result = self.apply("--plan", plan)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rev("feature"), self.orig)
        self.assertEqual(self.git("symbolic-ref", "-q", "HEAD", check=False).returncode, 1)
        self.assertEqual(len(self.backup_branches()), 1)

        result = self.finalize()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.out("symbolic-ref", "--short", "HEAD"), "feature")
        self.assertEqual(self.subjects("feature"), ["Add b first", "Add a, set to two"])
        self.assertEqual(self.tree("feature"), self.tree(self.orig))
        self.assertEqual(self.out("log", "-1", "--format=%an <%ae>", "feature"), "Tester <tester@example.com>")
        self.assertEqual(self.backup_branches(), [])
        self.assertFalse(self.state_file().exists())
        self.assertIn(self.orig, self.out("log", "-g", "--format=%H", "feature"))

    def test_the_branch_stays_put_when_the_rebuilt_tree_differs(self):
        plan = self.write_plan([
            {"message": "Add a", "from": [self.c1]},
            {"message": "Add b and set a", "from": [self.c2, self.c3], "split": True},
        ])

        result = self.apply("--plan", plan)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("SPLIT requested", result.stdout)

        self.write("a.txt", "corrupted\n")
        self.commit("Bad manual split")
        result = self.apply("--continue")
        self.assertEqual(result.returncode, 0, result.stderr)

        result = self.finalize()
        self.assertEqual(result.returncode, 1)
        self.assertIn("INVARIANT FAILED", result.stdout)
        self.assertEqual(self.rev("feature"), self.orig)
        self.assertEqual(len(self.backup_branches()), 1)
        self.assertTrue(self.state_file().exists())

        result = self.apply("--abort")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_initial_state()

    def test_abort_after_a_conflict_restores_the_initial_state(self):
        plan = self.write_plan([
            {"message": "Set a to two", "from": [self.c3]},
            {"message": "Add a", "from": [self.c1]},
            {"message": "Add b", "from": [self.c2]},
        ])

        result = self.apply("--plan", plan)
        self.assertEqual(result.returncode, 2)
        self.assertIn("CONFLICT", result.stdout)
        self.assertNotEqual(self.out("ls-files", "--unmerged"), "")

        result = self.apply("--abort")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_initial_state()
        self.assertEqual((self.repo / "a.txt").read_text(), "two\n")

    def test_a_resolved_conflict_continues_to_the_planned_history(self):
        plan = self.write_plan([
            {"message": "Set a to two", "from": [self.c3]},
            {"message": "Add b", "from": [self.c2]},
        ], dropped=[self.c1])

        result = self.apply("--plan", plan)
        self.assertEqual(result.returncode, 2)
        self.assertIn("CONFLICT", result.stdout)

        self.write("a.txt", "two\n")
        self.git("add", "-A")
        result = self.apply("--continue")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("built 2 commit(s)", result.stdout)
        self.assertEqual(self.subjects(), ["Set a to two", "Add b"])
        self.assertEqual((self.repo / "a.txt").read_text(), "two\n")
        self.assertTrue((self.repo / "b.txt").exists())
        self.assertEqual(self.rev("feature"), self.orig)

        status = json.loads(self.apply("--status").stdout)
        self.assertEqual(status["phase"], "built")
        self.assertEqual(status["dropped"], 1)

        result = self.finalize()
        self.assertEqual(result.returncode, 4)
        self.assertIn("could not auto-prove the invariant", result.stdout)
        self.assertEqual(self.rev("feature"), self.orig)

        result = self.finalize("--force", "--keep-backup")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.subjects("feature"), ["Set a to two", "Add b"])
        self.assertEqual(len(self.backup_branches()), 1)
        self.assertEqual(self.rev(self.backup_branches()[0]), self.orig)
        self.assertFalse(self.state_file().exists())


if __name__ == "__main__":
    unittest.main()
