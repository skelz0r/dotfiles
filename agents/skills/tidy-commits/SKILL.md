---
name: tidy-commits
description: Safely reorganize a branch's git history for a pull request by reordering, rewording, squashing/fixup, splitting and dropping commits. Use when the user asks to tidy or clean up commits, rearrange or reorganize commits, rewrite or amend commit messages across a branch, squash or split commits, or prepare a PR's history for review. Runs in two phases (propose a plan, get approval, then execute) and is engineered to be safe — it works on a detached HEAD with a backup branch, verifies a tree invariant before moving the branch, and aborts cleanly on trouble. Never pushes.
---

# Tidy Commits

Reorganize the commits of a branch (typically an open PR) into a clean, logical
history: reorder, reword messages, squash/fixup related commits, split a commit,
or drop one — without losing work.

## Safety model (why this is safe)

- All work happens on a **detached HEAD** rebuilt on top of `base`. The branch
  ref is **never moved** until the very end, so an abort always returns to the
  pristine branch.
- A **backup branch** is created before anything.
- `tidy_apply.py` refuses to start unless **every** commit in `base..HEAD` is
  accounted for (reused or explicitly dropped) — nothing is silently lost.
- `tidy_finalize.py` proves a **tree invariant** (new history == old history
  minus the dropped commits) before moving the branch. On failure it refuses.
- **Nothing is pushed.** After finalize, the user runs
  `git push --force-with-lease` themselves.

## Two-phase workflow

### Phase 1 — Analyze and propose a plan (no mutation)

1. **Find the base** (commits unique to the branch). See
   [references/recipes.md](references/recipes.md#choosing-the-base):
   merge-base with the PR's target branch (or the repo default branch). A later
   base is fine to keep early commits frozen and shrink the rebase.
2. **Read the history**: `git log --reverse --format='%h %s' --name-only base..HEAD`.
   Understand what each commit does and which files it touches.
3. **Assess difficulty.** Reordering commits that touch the same files causes
   conflicts. A few are fine; if the range is deeply entangled, propose a
   conservative plan (reword/squash, keep order) or say it is not worth it. See
   [recipes.md](references/recipes.md#assessing-rebase-difficulty).
4. **Propose the plan** as a human-readable summary: the new ordered list of
   commits, what each is made of (squashed sources), message changes, and any
   drops. **Stop and get explicit approval before any rewrite.**

### Phase 2 — Execute (only after approval)

1. **Write `plan.json`** following the schema in
   [recipes.md](references/recipes.md#planjson-schema).
2. **Build:**
   ```bash
   python3 scripts/tidy_apply.py --plan plan.json
   ```
   Handle the exit codes:
   - **0** — build complete, go to finalize.
   - **2** — cherry-pick conflict. Resolve files, `git add -A`, then
     `python3 scripts/tidy_apply.py --continue`. (Do not run
     `git cherry-pick --continue` yourself.)
   - **3** — split pause. Carve the staged change into commits, leave the tree
     clean, then `--continue`. See
     [recipes.md](references/recipes.md#splitting-a-commit).
3. **Verify & finalize:**
   ```bash
   python3 scripts/tidy_finalize.py
   ```
   - Prints the `range-diff` (old → new) for review.
   - **Pass** → moves the branch onto the tidied history, deletes the backup,
     reminds you to `git push --force-with-lease`.
   - **Exit 4** (can't auto-prove, e.g. a dropped commit is entangled) → inspect
     the diff; if intended, re-run with `--force`; else abort.
   - **Exit 1** (invariant failed, content would change) → do not keep; abort.
4. **Abort at any point** returns to the untouched branch:
   ```bash
   python3 scripts/tidy_apply.py --abort
   ```

## Scripts

- `scripts/tidy_apply.py` — preconditions, backup, accounting check, detached
  rebuild via cherry-pick, conflict/split resume (`--continue`), `--abort`,
  `--status`.
- `scripts/tidy_finalize.py` — tree-invariant verification, `range-diff`, branch
  swap or refusal. Flags: `--keep-backup`, `--force`.

## When NOT to use / limits

- The range contains **merge commits** → `tidy_apply.py` refuses; pick a base
  after the merge or handle manually.
- Deeply entangled history where reordering would conflict everywhere → keep it
  conservative or skip.
- This skill never pushes and never touches branches other than the one checked
  out and its backup.

Full details, manual fallback, and recovery via reflog:
[references/recipes.md](references/recipes.md).
