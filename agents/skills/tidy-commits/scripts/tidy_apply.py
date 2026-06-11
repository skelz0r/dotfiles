#!/usr/bin/env python3
"""Rebuild a branch's history from a plan, safely, on a detached HEAD.

The original branch ref is never moved by this script: all work happens on a
detached HEAD built on top of `base`. `tidy_finalize.py` moves the branch ref
only after the safety invariant passes.

Usage:
  tidy_apply.py --plan plan.json     Start a new rebuild
  tidy_apply.py --continue           Resume after resolving a conflict / split
  tidy_apply.py --abort              Discard work, return to the original branch
  tidy_apply.py --status             Show current operation state

Plan schema (plan.json):
{
  "base":   "<sha-or-ref>",          # rebuild starts on top of this commit (exclusive)
  "commits": [                        # resulting commits, in final order
    {
      "message": "subject\n\nbody",   # exact message for the rebuilt commit
      "from":    ["<sha>", ...],       # source commits to cherry-pick & combine, in order
      "split":   false,                # optional: pause for manual hunk-splitting
      "allow_empty": false             # optional: permit an empty resulting commit
    }
  ],
  "dropped": ["<sha>", ...]            # commits intentionally omitted (for accounting + verify)
}

Accounting rule: every commit in base..HEAD must appear in some `from` array or
in `dropped`. A sha may appear in several `from` arrays only to express a split.
"""

import argparse
import json
import os
import subprocess
import sys
import time

SEP = "\x1f"


def git(*args, check=True, capture=True):
    res = subprocess.run(
        ["git", *args],
        text=True,
        capture_output=capture,
    )
    if check and res.returncode != 0:
        out = (res.stdout or "") + (res.stderr or "")
        die(f"git {' '.join(args)} failed:\n{out.strip()}")
    return res


def git_ok(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).returncode == 0


def out(*args):
    return git(*args).stdout.strip()


def die(msg, code=1):
    print(f"tidy-apply: {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg):
    print(f"tidy-apply: {msg}")


def state_path():
    gitdir = out("rev-parse", "--absolute-git-dir")
    return os.path.join(gitdir, "tidy-commits-state.json")


def load_state():
    p = state_path()
    if not os.path.exists(p):
        die("no operation in progress (no state file). Start with --plan PLAN.")
    with open(p) as f:
        return json.load(f)


def save_state(state):
    with open(state_path(), "w") as f:
        json.dump(state, f, indent=2)


def clear_state():
    p = state_path()
    if os.path.exists(p):
        os.remove(p)


def full_sha(ref):
    res = git("rev-parse", "--verify", f"{ref}^{{commit}}", check=False)
    if res.returncode != 0:
        die(f"cannot resolve commit: {ref}")
    return res.stdout.strip()


def rev_list(rng):
    s = out("rev-list", "--reverse", rng)
    return s.split("\n") if s else []


def current_branch():
    res = git("symbolic-ref", "--quiet", "--short", "HEAD", check=False)
    return res.stdout.strip() if res.returncode == 0 else None


def working_tree_dirty():
    return bool(out("status", "--porcelain", "--untracked-files=no"))


def author_of(sha):
    s = out("show", "-s", "--format=%an%x1f%ae%x1f%aI", sha)
    name, email, date = s.split(SEP)
    return name, email, date


def write_message(state, text):
    msg = os.path.join(out("rev-parse", "--absolute-git-dir"), "tidy-commits-msg.txt")
    with open(msg, "w") as f:
        f.write(text)
        if not text.endswith("\n"):
            f.write("\n")
    return msg


def staged_anything():
    return git("diff", "--cached", "--quiet", check=False).returncode != 0


def has_unmerged():
    return bool(out("ls-files", "--unmerged"))


# --------------------------------------------------------------------------- #
# start
# --------------------------------------------------------------------------- #
def cmd_start(plan_path):
    git("rev-parse", "--git-dir")
    if os.path.exists(state_path()):
        die("an operation is already in progress. Use --continue, --abort or --status.")

    branch = current_branch()
    if not branch:
        die("HEAD is detached; check out the branch you want to tidy first.")
    if working_tree_dirty():
        die("working tree has uncommitted changes (tracked). Commit or stash first.")

    with open(plan_path) as f:
        plan = json.load(f)

    base = full_sha(plan["base"])
    orig = full_sha("HEAD")

    if not git_ok("merge-base", "--is-ancestor", base, orig):
        die("`base` is not an ancestor of HEAD.")

    commit_set = rev_list(f"{base}..{orig}")
    if not commit_set:
        die("no commits between base and HEAD; nothing to do.")

    merges = out("rev-list", "--merges", f"{base}..{orig}")
    if merges:
        die("range contains merge commits; pick a base after them or flatten first.")

    commit_set_full = set(commit_set)
    dropped = [full_sha(s) for s in plan.get("dropped", [])]
    groups = plan["commits"]

    used = []
    for i, g in enumerate(groups):
        if not g.get("from"):
            die(f"commit #{i} has an empty `from`.")
        g["from"] = [full_sha(s) for s in g["from"]]
        used.extend(g["from"])

    foreign = [s for s in used + dropped if s not in commit_set_full]
    if foreign:
        die("plan references commits outside base..HEAD:\n  " + "\n  ".join(foreign))

    accounted = set(used) | set(dropped)
    missing = [s for s in commit_set if s not in accounted]
    if missing:
        lines = [f"{s[:10]}  {out('show', '-s', '--format=%s', s)}" for s in missing]
        die("these commits are neither reused nor dropped (would be lost):\n  "
            + "\n  ".join(lines))

    overlap = set(used) & set(dropped)
    if overlap:
        die("commits are both reused and dropped:\n  " + "\n  ".join(overlap))

    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = f"tidy-backup/{branch.replace('/', '-')}-{stamp}"
    git("branch", backup, orig)

    state = {
        "plan_path": os.path.abspath(plan_path),
        "base": base,
        "branch": branch,
        "orig": orig,
        "backup": backup,
        "dropped": dropped,
        "groups": groups,
        "next_index": 0,
        "phase": "build",
    }

    info(f"backup branch: {backup}")
    info(f"rebuilding {len(commit_set)} commit(s) into {len(groups)} commit(s)"
         + (f", dropping {len(dropped)}" if dropped else ""))
    git("checkout", "--detach", base, capture=True)
    save_state(state)
    build(state)


# --------------------------------------------------------------------------- #
# build loop
# --------------------------------------------------------------------------- #
def commit_group(state, group):
    name, email, date = author_of(group["from"][0])
    if not staged_anything():
        if group.get("allow_empty"):
            extra = ["--allow-empty"]
        else:
            die("resulting commit has no changes; adjust the plan "
                "(or set allow_empty: true).")
    else:
        extra = []
    msg = write_message(state, group["message"])
    git("commit", "--no-verify", "-F", msg,
        f"--author={name} <{email}>", f"--date={date}", *extra)


def build(state):
    groups = state["groups"]
    i = state["next_index"]

    while i < len(groups):
        group = groups[i]

        if state.get("phase") == "split-wait":
            state["phase"] = "build"
            if working_tree_dirty() or staged_anything():
                die("working tree not clean after split; commit the split pieces "
                    "before --continue.")
            i += 1
            state["next_index"] = i
            save_state(state)
            continue

        start_src = state.pop("next_src", 0)
        for j in range(start_src, len(group["from"])):
            src = group["from"][j]
            res = git("cherry-pick", "-n", src, check=False)
            if res.returncode != 0:
                state["next_index"] = i
                state["next_src"] = j
                state["phase"] = "conflict"
                save_state(state)
                print((res.stdout or "") + (res.stderr or ""), file=sys.stderr)
                info(f"CONFLICT cherry-picking {src[:10]} for commit #{i}.")
                info("Resolve the files, `git add -A`, then run: tidy_apply.py --continue")
                sys.exit(2)

        if group.get("split"):
            state["next_index"] = i
            state["phase"] = "split-wait"
            save_state(state)
            info(f"SPLIT requested for commit #{i}: changes are staged on detached HEAD.")
            info("Create the split commits manually (e.g. `git reset -q HEAD` then "
                 "`git add -p` + `git commit`), leave the tree clean,")
            info("then run: tidy_apply.py --continue")
            sys.exit(3)

        commit_group(state, group)
        i += 1
        state["next_index"] = i
        state["phase"] = "build"
        save_state(state)

    finish_build(state)


def finish_build(state):
    state["phase"] = "built"
    state["new_head"] = full_sha("HEAD")
    save_state(state)
    info(f"built {len(state['groups'])} commit(s) on detached HEAD {state['new_head'][:10]}.")
    info("Now verify and finalize with: tidy_finalize.py")


# --------------------------------------------------------------------------- #
# continue / abort / status
# --------------------------------------------------------------------------- #
def cmd_continue():
    state = load_state()
    phase = state.get("phase")
    if phase == "conflict":
        if has_unmerged():
            die("unresolved conflicts remain. Resolve them and `git add -A` first.")
        git("cherry-pick", "--quit", check=False)
        state["next_src"] = state.get("next_src", 0) + 1
        state["phase"] = "build"
        save_state(state)
        build(state)
    elif phase == "split-wait":
        build(state)
    elif phase == "built":
        info("build already complete; run tidy_finalize.py.")
    else:
        die(f"nothing to continue (phase={phase}).")


def cmd_abort():
    state = load_state()
    git("cherry-pick", "--quit", check=False)
    git("checkout", "-f", state["branch"], capture=True)
    if git_ok("rev-parse", "--verify", state["backup"]):
        git("branch", "-D", state["backup"], check=False)
    clear_state()
    info(f"aborted. Branch '{state['branch']}' is unchanged (was never moved).")


def cmd_status():
    state = load_state()
    print(json.dumps({
        "branch": state["branch"],
        "base": state["base"][:10],
        "backup": state["backup"],
        "phase": state.get("phase"),
        "next_index": state.get("next_index"),
        "groups": len(state["groups"]),
        "dropped": len(state["dropped"]),
        "new_head": state.get("new_head", "")[:10],
    }, indent=2))


def main():
    ap = argparse.ArgumentParser(add_help=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--plan", metavar="PLAN")
    g.add_argument("--continue", dest="cont", action="store_true")
    g.add_argument("--abort", action="store_true")
    g.add_argument("--status", action="store_true")
    args = ap.parse_args()

    if args.plan:
        cmd_start(args.plan)
    elif args.cont:
        cmd_continue()
    elif args.abort:
        cmd_abort()
    elif args.status:
        cmd_status()


if __name__ == "__main__":
    main()
