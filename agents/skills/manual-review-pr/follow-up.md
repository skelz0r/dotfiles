# Follow-up review

Read from `SKILL.md` when the author pushed a new version after a review
of the user, or answered it, and the user asks to "check la dernière
version", "relis les corrections", "c'est ok ?".

## Collect the new state

```bash
gh pr view <n> --json headRefOid,commits,comments,reviews
gh pr checks <n>
```

- Fetch the head with `gh` or over HTTPS when `git fetch` fails (no SSH
  key for that remote): `git fetch https://github.com/<owner>/<repo>.git
  pull/<n>/head`.
- Diff from the parent of the PR's first commit, not from
  `origin/<base>`: a stale local base adds every commit merged on it
  since to the diff (32 files on #639, 183 against the stale base).
- Read the author's replies since the user's last review, in comments
  and review threads: they say what they changed, what they pushed back
  on, and what they did not understand. A misunderstood point is
  rephrased, not repeated.

## Verdict per point

Take the points of the previous review one by one and give each a
verdict at the new head: fixed (with the `file:line` that shows it),
partly, not addressed, or pushed back on (with the author's argument,
then the agent's opinion on it). A fix gets the same grid as the first
pass, in a smaller scope: a fix can move the smell instead of removing
it (on #639 the source left the controller for the organizer, but as an
override to `nil` that needed a comment to be understood).

Then read the commits added on the way, which no earlier point covers
(on #639, a footer running off the page). Run Codex only on what
changed, when it touches a costly area; never the whole branch again.

## Close

Report: points fixed, what is left, its weight, CI state. Then the
outputs of `comment.md`: usually a short body and inline nits, posted
with the state the user chooses (`APPROVE`, an approval with a
condition, or `REQUEST_CHANGES` again).
