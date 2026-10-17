---
name: rebase
description: Rebase a pull request branch onto the default branch, push it, then watch its CI and keep going until it is green — resolving mechanical conflicts alone, asking on product or business ones, fixing real failures of the branch after a codex-review pass, and reporting failures that come from elsewhere (default branch, clock, CDN, infrastructure) instead of patching them in the PR. Use when the user runs /rebase, says "rebase push", "rebase et pousse", "remets la PR à jour", "rebase sur develop/main", or "ça passe pas les tests" right after a rebase.
---

# Rebase

Brings a PR branch up to date and drives it to a green CI. Argument: a PR
number or branch; without one, the current branch. Normally nothing needs
the user: they want to hear only about decisions.

## 1. Rebase

```bash
git fetch -q origin
DEFAULT="$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')"
OLD="$(git rev-parse HEAD)"; BASE_OLD="$(git merge-base HEAD "origin/$DEFAULT")"
git rebase "origin/$DEFAULT"
```

On conflict, read both sides and the commits that brought them
(`git log origin/$DEFAULT -- <file>`):

- mechanical (both sides add to the same place, renames, lockfiles,
  generated files to regenerate): resolve and continue;
- the two sides encode different product or business rules (a status,
  a wording, a threshold, who sees what): stop and ask, showing both
  versions and what each commit wanted.

Then check nothing was dropped or altered beyond the conflict:

```bash
git range-diff "$BASE_OLD..$OLD" "origin/$DEFAULT..HEAD"
```

Every commit must be `=` or `!` only where a conflict was resolved. Run
the project's tests for the files touched by the branch before pushing.

## 2. Push

- PR authored by the user (`gh pr view --json author` matches
  `gh api user --jq .login`): `git push --force-with-lease`.
- Someone else's PR: ask before force pushing.

## 3. Watch the CI

```bash
gh pr checks <pr> --watch --fail-fast
```

Green: report and stop. Red: open the failed job log
(`gh run view <run> --log-failed`, or `--job <id> --log` when
`--log-failed` is truncated) and classify before touching anything.

## 4. Classify a failure

Ask, in order:

1. Does the failing job cover code the branch touches?
   (`git diff --stat origin/$DEFAULT...HEAD -- <app dir>`) If not, the
   cause is very likely outside the branch.
2. Did the same job pass on the default branch at the same base commit?
   (`gh run list --branch $DEFAULT --workflow "<name>"` with `headSha`)
   Do other open PRs fail the same way since a given time?
3. Reproduce locally, on the branch then on `origin/$DEFAULT`. A CI log
   cut short with no test summary still hides real failures: the local
   run shows them.

Then:

- **Flaky** (passes on rerun, no local repro): `gh run rerun <id>
  --failed` once. Twice red is not flaky.
- **Broken outside the branch** (fails on the default branch too):
  do not patch it in the PR. Find the cause, tell the user, and propose
  a dedicated fix through `/start`. Known shapes:
  - unpinned CDN asset (`lib@latest`) that just got a major release:
    compare the release time with the first red run;
  - test with a frozen date (Timecop, `travel_to`, fixed `Time.zone.local`)
    that turns into a time bomb when the real clock passes it, typically
    an assertion or a cache TTL read outside the freeze: the first red
    run lands right after that date;
  - infrastructure (runner, service image `latest`, external service).
- **Real failure of the branch**: fix it, run the `codex-review` skill on
  the fix, then ask the user whether to fold it as a fixup into the commit
  that introduced the defect or to reorganise with `tidy-commits` (both
  rewrite the history), and push again.

## 5. Loop

Back to step 3 after every push or rerun, until the CI is green or every
remaining failure is outside the branch and reported. The `codex-review`
passes on the fixes count against its cap of three passes per branch:
once reached, stop looping and ask the user to rethink the approach
rather than pushing a fourth fix. When an outside fix
lands on the default branch, rebase again (step 1).

## Report

Commits rebased, conflicts resolved and how, decisions asked, CI state,
and each failure with its class and cause.
