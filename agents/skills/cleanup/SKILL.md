---
name: cleanup
description: Clean up after a worktree's pull request is merged — check the PR state, then tear the worktree down with the project's own removal script (servers, worktree, local branch, databases) and close the tmux tab named after it. Use when the user runs /cleanup, asks to "nettoie le worktree", "check la PR et nettoie", "la PR est mergée, cleanup", or after confirming a worktree PR was merged.
---

# Cleanup

Tears down a git worktree once its pull request has landed. Argument: the
worktree name (ticket like `API-7345` or slug like `cnav-nir`), a branch
or a PR number. Without argument, use the worktree of the current session.

Every project isolates its worktrees differently (ports, Postgres, Redis,
env files), so the teardown itself is delegated to the project's removal
script. This skill only adds the safety checks around it and the tmux
cleanup.

## Steps

1. Find the primary checkout and the project's conventions:

   ```bash
   PRIMARY_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
   ```

   Read the worktree section of `$PRIMARY_ROOT/CLAUDE.md` (or
   `AGENTS.md`, or the `CLAUDE.md` it points to) to learn where worktrees
   live and which script removes them. Failing that, look for it:
   `ls "$PRIMARY_ROOT"/bin | grep -iE 'worktree.*(remove|rm)|(remove|rm).*worktree'`.
   Known examples: `bin/remove_worktree.sh <name>`,
   `bin/worktree-remove <name>`.

2. Resolve the PR: `gh pr view <number|branch> --json state,mergedAt,headRefName,headRefOid,baseRefName`.
   Map it to its worktree with `git worktree list --porcelain`: the entry
   whose `branch refs/heads/<headRefName>`. This covers both the project
   worktrees directory and Claude Code ones (`.claude/worktrees/`).

3. Stop unless the PR is `MERGED`. Report its state (open, closed without
   merge, checks pending) and do nothing else: an unmerged worktree holds
   work that would be lost.

4. Check nothing unpublished remains in the worktree:
   - `git -C <path> status --short` must be empty;
   - `git -C <path> rev-parse HEAD` must equal `headRefOid`.
   Otherwise stop and show what would be lost.

5. From the primary checkout (never from inside the worktree being
   removed), run the removal script with the name it expects (usually the
   worktree directory name). It typically stops the servers, removes the
   worktree, deletes the local branch and drops the worktree's databases.

   If the script keeps the local branch because it looks unmerged (squash
   or merge commit on GitHub, local base branch behind), step 4 already
   proved the branch is published and merged: delete it with
   `git -C "$PRIMARY_ROOT" branch -D <branch>`.

   Without a removal script, follow the manual teardown documented in the
   project's `CLAUDE.md` (servers, simulators, worktree, branch,
   databases). With no such procedure either, fall back to
   `git -C "$PRIMARY_ROOT" worktree remove <path>` then
   `git branch -D <branch>`, and tell the user that servers and databases
   specific to the worktree may be left behind.

6. Look for leftover Postgres databases of the project: those of the
   removed worktree, and those of older worktrees removed by hand.

   ```bash
   psql -d postgres -XAtc "select datname from pg_database where not datistemplate order by 1"
   ```

   Derive the project's naming scheme from `config/database.yml` and the
   worktree setup script (prefix, `DATABASE_SUFFIX`, `-` turned into
   `_`, parallel test suffixes like `_2`…`_16` or `_0`…`_31`). Map every
   suffix to a worktree still listed by `git worktree list` (read each
   worktree's `.env.local` or equivalent for its suffix): the removed
   worktree's databases and those whose suffix matches no worktree are
   orphans. Beware that a branch may use an older naming scheme (read the
   `database.yml` of the worktree itself), and that the primary checkout
   also owns parallel test databases.

   Show the orphans with the worktree they belonged to, drop them with
   `dropdb`, one per line (`while read -r db`: zsh does not word-split
   `for db in $list`). Never drop `*_production` nor backup databases,
   and ask before dropping anything that does not follow the scheme.

7. Always close the tmux tab of the worktree if it exists, whichever way
   step 5 went:

   ```bash
   tmux list-windows -a -F '#{window_id} #{window_name}'
   tmux display-message -p -t "$TMUX_PANE" '#{window_id}'
   ```

   The tab to close is the one named after the worktree (or the feature
   slug it was renamed to), and the window Claude runs in when this
   session worked on that worktree, even if its name differs. If it is
   the window Claude runs in, report the outcome to the user first, then
   kill it as the very last action, since it ends the session. Never kill
   another session's window whose name does not match.

## Report

One line per step: PR state, worktree removed, branch deleted, databases
dropped, orphan databases dropped, tab closed (or why each one was skipped).
