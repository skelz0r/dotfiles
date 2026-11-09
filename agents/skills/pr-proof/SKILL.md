---
name: pr-proof
description: Prove that a pull request's change works, in the single proof comment of the PR rewritten at each push — read the diff, derive the proofs it requires (screencast when an interaction changed, before/after captures when a rendering changed, a review guide past ~500 hand-written lines, ~20 files or when stacked, a real run for backend changes, a test seen failing without the fix), post nothing when there is no artefact, produce them through verify-<app> / bin/qa, screencast, gh-image and pr-review-guide, then post or replace the comment on a fixed skeleton. Use after every push of one's own pull request (feature, bugfix, refactoring), when start or codex-review hand over to it, when the user says "prouve la PR", "poste la preuve", "mets à jour le commentaire de preuve", "proof comment", or when a proof comment cites an outdated SHA. Not the proof of review: that one is codex-review's.
---

# pr-proof

A reviewer opens the proof comment to know, in 30 seconds, that the change
works and how it was seen working. Two comments, never merged:

- **proof of review** (`codex-review`, `agentic-review publish`): which
  passes read which diff;
- **proof of change** (this skill): the change works at the pushed head.

Left to judgement, agents published the cheapest proof: statics and
"checked by hand" for a badge that opens a modal (#2265), an approval
that updates a counter then removes a block (#2268), a tag panel (#2270);
no review guide on +1414 lines over 59 files stacked on another PR
(#2261); and the list of every spec example as the proof (#2269). The
triggers below are mechanical and cumulative: produce every proof that
applies, not the strongest one.

The opposite failure: on backend, dependency and config PRs the comment
restated what GitHub already shows. "CI green", the spec files of the
diff, "spec X covers gem Y" and a verdict paraphrasing the description
(apistration#664, superdocu#2277, navette#6) prove nothing, while the
real risk sat at the bottom of "Not verified". A proof comment exists
only to carry an artefact the reviewer cannot see elsewhere: media, a
measure, a test seen failing without the fix, a run against something
real, a risk to watch at deploy. No artefact: post no comment
(`publish` refuses one).

## 1. Scope

Commit and push first: the proof is about the pushed head.

```bash
S=~/.claude/skills/pr-proof/scripts/pr-proof.sh
"$S" scope <pr> [--exclude '^sdk/']
```

It prints the head commit link, the hand-written size (locks, schemas,
swagger, fixtures, snapshots and binaries left out; `--exclude` adds a
project's generated paths), whether the PR is stacked, each required
proof with the files that fired it, the CI statuses and the added or
modified test files, all linked at the head commit.

| Signal on the diff | Proof required |
|---|---|
| Front-end script (Stimulus, JS/TS), or an added line in a view or component that wires an action (`data-action`, turbo stream or frame, button, form, select, SwiftUI `Button`, `.sheet`...) | **Screencast** of each journey whose state changes: click, modal, selection, filter, multi-step flow |
| Only E2E tests touched (`check`) | Screencast if the journey they drive changed behaviour, else say why not |
| View, component, template, stylesheet, mail template | **Before / after captures**, same data, same viewport |
| ≥ 500 hand-written added lines, ≥ 20 files, or stacked | **Review guide** (`pr-review-guide`), linked from the comment |
| Backend, job, client, migration, config | **A real run**: the code path executed outside the specs (rails runner or curl on the dev app, the third party's sandbox, read-only aggregates on production for a data change, the job or hook actually triggered) |
| Bugfix | **Fails without the fix**: the reproducing test run on the base or with the fix reverted |
| Always | **CI** at the head commit, mentioned only when a check is red, pending or skipped |

A signal that fires without a user-visible change (a JS refactor, a
markup move) is not skipped silently: one line in "Not verified" says
which proof was left out and why.

## 2. Produce

- **Run the app** with the project's `verify-<app>` skill or `bin/qa`.
  None: propose `create-verify-skill` and raise it in "Needs you".
- **Screencast**: the `screencast` skill (iOS: its `ios.md`), one video
  per journey, under ~30 s, starting from the screen the user starts
  from and ending on the state that changed (counter updated, block
  gone, modal action done). Saved in `~/share/screencasts/`.
- **Before / after**: "before" on the merge-base, "after" on the head,
  same seed, account and viewport; for a mail, its preview. When the base
  cannot run cheaply, say what "before" shows instead. Saved in
  `~/share/screenshots/`, named `<screen>-before.png` / `-after.png`.
- **Review guide**: the `pr-review-guide` skill, published on
  assets.delmai.re; for a stacked PR it covers only this PR's commits.
- **Measures** when the change is about a number (time, count, size):
  the value on the base and on the head, not an adjective.
- **Real run**: the command run and what it returned, in one line.
  Specs that stub every HTTP call are not one (apistration#665): try
  the sandbox, else say it under "Watch at deploy". Good: a dry run
  on production aggregates giving 976 companies, 7.25 GB (#2257); the
  skip path of a CI actually taken on a pushed commit (navette#8).

On a later push, rerun `scope`. A journey or screen whose code did not
change since (`git range-diff`) keeps its hosted media URL in the body,
no new upload; anything else is filmed or captured again.

## 3. Write

Skeleton, in this order, at most 1,000 characters of text outside media
and URLs. `publish` checks the shape: head link first, an artefact
present, no `Tests:` line, no CI line when every check is green, no
media already in the PR description.

```markdown
Proof at [abc1234de](https://github.com/OWNER/REPO/commit/<sha40>): <verdict in one line: what was seen working, where>

Watch at deploy: <concrete risk: migration order, third-party contract, data volume>

<screencast(s), then before / after side by side>

Review guide: <url>

Ran: <command or environment> → <what it returned>
Fails without the fix: [spec/x_spec.rb](<blob url at sha>) (<n> failures on <base sha>)
Measured: <base value> → <head value>

CI: <only the red, pending or skipped checks>

Not verified: <what, and why>
```

- The SHA is the 9-character head SHA linked to its commit: `scope`
  prints it ready to paste.
- The verdict says what was seen, not what the PR does: the
  description already says that.
- "Fails without the fix" only when it was run; the list of test
  files is in the diff, never in the comment.
- No CI line when every check is green: GitHub shows it. A retried
  check that ended green is not told either (apistration#664).
- "Watch at deploy" comes right under the verdict when there is a
  concrete risk; it is what the deployer must read.
- "Not verified" stays, honest and short: an empty one is written
  "Not verified: nothing". It holds the verification gaps of the
  agentic review too: `codex-review` only counts them.
- Media already in the PR description are not repeated (#2279).
- Omit the lines that do not apply (no guide, no measure); keep the
  order.
- Portrait captures side by side as `<img width="240">`, per `gh-image`.

## 4. Publish

```bash
"$S" publish <pr> --body-file proof.md --attach /abs/after.png --attach /abs/journey.mp4 --dry-run
"$S" publish <pr> --body-file proof.md --attach /abs/after.png --attach /abs/journey.mp4
```

Reference each attached file in the body by its absolute path, as
`gh-image` describes. `publish` checks the first line against the head
commit and the length cap, then:

- with new media: posts a new comment through `gh pr comment --attach`
  (the only command that uploads), records the files with
  `gh-media-log`, and deletes the previous proof comment of the current
  user (marked `<!-- pr-proof -->`, or starting with `Proof at`);
- without new media: edits the previous proof comment in place.

Read the comment back (`gh pr view <pr> --comments`): no local path
left, media rendered.

## When no proof is possible

A lock-only bump or a config change with no run to show and no risk to
watch: no comment, say so in the turn's report. Otherwise say it in
the comment's "Not verified" (what and why: no local reproduction of a
third-party error, no device...) and in the turn's "Needs you". Never
replace a required screencast by "checked by hand" (#2268).
