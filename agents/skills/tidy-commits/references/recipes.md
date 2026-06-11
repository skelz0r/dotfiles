# tidy-commits — recipes & reference

Table of contents
- [plan.json schema](#planjson-schema)
- [Choosing the base](#choosing-the-base)
- [Assessing rebase difficulty](#assessing-rebase-difficulty)
- [Resolving a conflict](#resolving-a-conflict)
- [Splitting a commit](#splitting-a-commit)
- [Dropping commits](#dropping-commits)
- [Aborting & recovery](#aborting--recovery)
- [Manual fallback (no scripts)](#manual-fallback-no-scripts)
- [Edge cases](#edge-cases)

## plan.json schema

```json
{
  "base": "<sha-or-ref>",
  "commits": [
    {
      "message": "subject line\n\nOptional body explaining the why.",
      "from": ["<sha>", "<sha>"],
      "split": false,
      "allow_empty": false
    }
  ],
  "dropped": ["<sha>"]
}
```

- `base` — the rebuild starts on top of this commit (exclusive). Everything in
  `base..HEAD` is replaced by `commits`.
- `commits` — the resulting commits, in final order (top of the list becomes the
  oldest commit on top of base).
  - `from` — source commits cherry-picked in this order and combined into one
    commit (this is how you squash/fixup: list several SHAs). The new commit's
    author is taken from the first SHA.
  - `message` — exact message for the rebuilt commit (subject + body).
  - `split` (optional) — pause after staging so you can hand-carve the staged
    changes into several commits. See [Splitting a commit](#splitting-a-commit).
  - `allow_empty` (optional) — allow a commit with no net change.
- `dropped` (optional) — commits to omit. Listed explicitly so the accounting
  check passes and so finalize can prove the tree invariant.

Accounting rule enforced by `tidy_apply.py`: **every** commit in `base..HEAD`
must appear in some `from` or in `dropped`. A SHA may appear in several `from`
arrays only when expressing a split. This guarantees nothing is silently lost.

## Choosing the base

The base is normally the merge-base with the PR's target branch, so you only
touch commits unique to the branch:

```bash
# target branch of the PR, if there is one
target=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null)
# fallback to the repo default branch
[ -z "$target" ] && target=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's#origin/##')
[ -z "$target" ] && target=main
base=$(git merge-base HEAD "origin/$target")
git log --oneline --stat "$base..HEAD"
```

You can pick a *later* base than the merge-base to keep the early commits frozen
and only reorganize recent ones — smaller, safer rebases.

## Assessing rebase difficulty

Before proposing a plan, gauge conflict risk. Reordering commits that touch the
same files is what produces conflicts.

```bash
# files touched per commit in the range
git log --reverse --format='%h %s' --name-only "$base..HEAD"
```

- Independent commits (disjoint file sets) reorder cleanly — no conflicts.
- Commits whose hunks overlap will likely conflict when reordered. A few are
  fine; resolve them. If the whole range is deeply entangled, prefer a
  conservative plan (reword + squash only, keep order) or tell the user it is
  not worth it.

## Resolving a conflict

`tidy_apply.py` stops with exit code 2 on a cherry-pick conflict, leaving the
conflict staged on the detached HEAD.

```bash
git status                       # see conflicted files
# edit files to resolve, then:
git add -A
python3 scripts/tidy_apply.py --continue
```

Do not run `git cherry-pick --continue` yourself — the script clears the
cherry-pick state and proceeds.

## Splitting a commit

Set `"split": true` on a commit entry whose `from` is the source to split.
`tidy_apply.py` cherry-picks it with `-n` (changes staged, not committed) and
stops with exit code 3. Then carve the staged changes into commits yourself:

```bash
git reset -q HEAD                # unstage, keep working-tree changes
git add -p                       # stage the first slice (or: git add <paths>)
git commit -m "first piece"
git add -A
git commit -m "second piece"
git status                       # MUST be clean before continuing
python3 scripts/tidy_apply.py --continue
```

The `message` of a `split` entry is ignored — you author each piece's message.
The tree invariant still protects you: the union of the split pieces must equal
the original change.

## Dropping commits

List the SHA under `dropped` and leave it out of every `from`. Finalize proves
the drop is exactly intended by re-applying the dropped commits on top of the
new HEAD and checking the tree matches the backup. If a dropped commit is
entangled with kept changes, that re-application may conflict; finalize then
asks you to confirm the diff by hand and re-run with `--force`.

## Aborting & recovery

```bash
python3 scripts/tidy_apply.py --abort     # return to the original branch, untouched
```

The original branch ref is never moved before finalize, so aborting is always
safe. Even after a successful finalize, the old tip is recoverable:

```bash
git reflog | grep <branch>                # find the old tip SHA
# or, if you finalized with --keep-backup, the tidy-backup/* branch still exists
git branch -f <branch> <old-sha>          # restore if needed
```

## Manual fallback (no scripts)

The scripts just make this reliable. The underlying method, by hand:

```bash
git branch backup-x                        # safety net
git checkout --detach <base>
git cherry-pick -n <sha1> <sha2>           # combine = squash
git commit -F msg.txt                      # reworded message
git cherry-pick <sha3>                     # keep as-is
# ... in the desired final order ...
git diff backup-x HEAD                      # MUST be empty (no drops) before swapping
git branch -f <branch> HEAD
git checkout <branch>
git branch -D backup-x
```

`git rebase -i` is the usual tool but its interactive editor is not drivable in
this environment, which is why the cherry-pick rebuild is preferred here.

## Edge cases

- **Merge commits** in `base..HEAD`: `tidy_apply.py` refuses to start. Choose a
  base after the merge, or handle it manually.
- **GPG signing**: rebuilt commits are signed only if `commit.gpgsign=true` is
  set in git config (same as a normal rebase).
- **Hooks**: rebuilt commits are created with `--no-verify` to avoid pre-commit
  / commit-msg hooks firing once per rebuilt commit. Run your checks after
  finalize instead.
- **Author vs committer dates**: the author identity and date are preserved from
  the first source commit of each group; the committer date becomes "now", as
  with any rebase.
- **Already pushed branch**: tidying rewrites history, so the remote update is a
  force-push. This skill never pushes; do it yourself with
  `git push --force-with-lease` after reviewing.
