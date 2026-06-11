#!/usr/bin/env python3
"""Verify a rebuilt history, then move the branch onto it (or refuse).

Run after `tidy_apply.py` reports the build is complete. This is the only step
that moves the original branch ref, and it does so only once the safety
invariant holds.

Safety invariant
----------------
Re-applying the dropped commits (in their original order) on top of the rebuilt
HEAD must reproduce the backup's tree exactly. In other words, the new history
is the old history minus exactly the dropped changes, regardless of how commits
were reordered, reworded, squashed or split. With no dropped commits this
reduces to `git diff backup..new` being empty.

Usage:
  tidy_finalize.py                 Verify and, if it passes, finalize
  tidy_finalize.py --keep-backup   Finalize but keep the backup branch
  tidy_finalize.py --force         Finalize even if the invariant can't be auto-proved
"""

import argparse
import json
import os
import subprocess
import sys

NUL = "\x00"


def git(*args, check=True):
    res = subprocess.run(["git", *args], text=True, capture_output=True)
    if check and res.returncode != 0:
        die(f"git {' '.join(args)} failed:\n{(res.stdout + res.stderr).strip()}")
    return res


def git_ok(*args):
    return git(*args, check=False).returncode == 0


def show(*args):
    sys.stdout.flush()
    subprocess.run(["git", *args])
    sys.stdout.flush()


def out(*args):
    return git(*args).stdout.strip()


def die(msg, code=1):
    print(f"tidy-finalize: {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg):
    print(f"tidy-finalize: {msg}")


def state_path():
    return os.path.join(out("rev-parse", "--absolute-git-dir"), "tidy-commits-state.json")


def load_state():
    p = state_path()
    if not os.path.exists(p):
        die("no operation in progress; run tidy_apply.py first.")
    with open(p) as f:
        return json.load(f)


def clear_state():
    p = state_path()
    if os.path.exists(p):
        os.remove(p)


def rev_list(rng):
    s = out("rev-list", "--reverse", rng)
    return s.split("\n") if s else []


def trees_equal(a, b):
    return git("diff", "--quiet", a, b, check=False).returncode == 0


def verify(state):
    """Return 'pass', 'fail-tree' or 'fail-conflict'."""
    base, backup, new = state["base"], state["backup"], state["new_head"]
    dropped = set(state["dropped"])

    if not dropped:
        return "pass" if trees_equal(backup, new) else "fail-tree"

    ordered = [s for s in rev_list(f"{base}..{backup}") if s in dropped]
    git("checkout", "--detach", new)
    for sha in ordered:
        if not git_ok("cherry-pick", sha):
            git("cherry-pick", "--abort", check=False)
            git("checkout", "--detach", new)
            return "fail-conflict"
    ok = trees_equal(backup, "HEAD")
    git("checkout", "--detach", new)
    return "pass" if ok else "fail-tree"


def finalize_swap(state, keep_backup, forced):
    branch, new, backup, orig = (
        state["branch"], state["new_head"], state["backup"], state["orig"],
    )
    git("branch", "-f", branch, new)
    git("checkout", branch)
    if keep_backup:
        info(f"backup kept: {backup} ({orig[:10]})")
    else:
        git("branch", "-D", backup, check=False)
        info(f"backup deleted; recover the old tip via reflog if needed: {orig[:10]}")
    clear_state()
    if forced:
        info("FINALIZED WITH --force: the invariant was not auto-proved. Re-check the diff.")
    print()
    info(f"branch '{branch}' now points at the tidied history ({new[:10]}).")
    info("Nothing was pushed. When you are happy: git push --force-with-lease")


def cmd_finalize(force, keep_backup):
    state = load_state()
    if state.get("phase") != "built":
        die(f"build not complete (phase={state.get('phase')}). "
            "Finish tidy_apply.py (--continue) first, or --abort it.")

    git("checkout", "--detach", state["new_head"])

    print("\n===== range-diff (old -> new) =====")
    show("range-diff", state["base"], state["backup"], state["new_head"])
    print("===================================\n")

    result = verify(state)

    if result == "pass":
        info("invariant holds: rebuilt history matches the original minus dropped commits.")
        finalize_swap(state, keep_backup, forced=False)
        return

    if result == "fail-conflict":
        info("could not auto-prove the invariant: re-applying dropped commits conflicts.")
        info("Inspect the range-diff above and `git diff "
             f"{state['backup'][:10]} {state['new_head'][:10]}` by hand.")
        info("If the result is what you intended, re-run with --force.")
        info("Otherwise discard everything with: tidy_apply.py --abort")
        if force:
            finalize_swap(state, keep_backup, forced=True)
        else:
            sys.exit(4)
        return

    info("INVARIANT FAILED: the rebuilt tree differs from the original beyond the "
         "dropped commits. Content would be lost or changed.")
    print("\n----- unexpected differences (backup -> new) -----")
    show("diff", "--stat", state["backup"], state["new_head"])
    print("--------------------------------------------------\n")
    info("Do NOT keep this unless intentional. Discard with: tidy_apply.py --abort")
    if force:
        finalize_swap(state, keep_backup, forced=True)
    else:
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--keep-backup", action="store_true")
    args = ap.parse_args()
    cmd_finalize(args.force, args.keep_backup)


if __name__ == "__main__":
    main()
