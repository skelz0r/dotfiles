---
name: codex-review
description: Run an adversarial code review of a diff, commit or branch through the Codex CLI (a different model family), sizing the reasoning effort to the complexity of the change, then triage the findings and publish a proof of review (status and comment) on one's own pull request. Use when the user asks to review something with Codex, wants a second opinion or an external/independent review of code just written, says "review avec codex", "codex review", "fais relire ça", "double-check this diff", or asks to cross-check a change before opening or merging a PR, or to show reviewers which agentic reviews a PR went through ("publie la review sur la PR", "agentic review status"), or to request a human reviewer on one's pull request ("ouvre une PR et request une review à X"), which waits for the review loops.
---

# Codex review

Codex reads code well and infers business rules badly. The value comes from a different model family
attacking the diff with an explicit hypothesis, not from generic "review this". Everything hinges on
the prompt and on sizing the effort correctly.

## Workflow

### 1. Scope the target

Identify the exact diff and the git command that shows it. Prefer a committed range over a dirty
working tree:

```bash
git log --oneline <base>..HEAD      # confirm what is in scope
git diff --stat <base>...HEAD
```

`codex review` has a purpose-built harness but **refuses a custom prompt together with a target**:
`--commit <SHA>` and `--base <BRANCH>` both conflict with `[PROMPT]`. Domain context matters more
than that harness, so drive `codex exec` instead and name the range inside the prompt.

### 2. Rate the complexity, pick the effort

Score the diff on the axes below. Each one that applies pushes the effort up a rung.

| Signal | Why it raises the bar |
|---|---|
| Hand-written SQL, aggregates, correlated subqueries, `to_sql` interpolation | Silent wrong-row bugs, no type checker |
| An invariant spread across several layers that must agree | Each layer looks fine alone |
| Concurrency, ordering, retries, idempotency | Failure modes are not reachable by reading |
| Auth, permissions, money, PII | Cost of a miss is not proportional to diff size |
| Migrations, backfills, anything irreversible | No cheap rollback |
| Outward-facing contracts: public API, webhooks, CRM, emails | Breakage lands on third parties |
| Caches, denormalised counters, derived state | Invalidation bugs survive tests |
| A changed method with many callers | Blast radius outruns the diff |

And what pulls it down: a single file, local semantics, a rename, a config bump, a pure function
already covered by tests.

| Effort | When |
|---|---|
| `low` | Mechanical, local, obviously correct on inspection. Usually not worth a Codex call at all. |
| `medium` | Ordinary feature work, one or two files, no signal from the table above. |
| `high` | One or two signals, or a diff large enough that a human reviewer would skim. |
| `xhigh` | Three or more signals, or any of: irreversible, security-relevant, invariant spread across layers. |

State the score and the chosen rung to the user in one line before running — it is a judgement they
may want to override.

Model: inherit whatever `~/.codex/config.toml` sets. Only name a model when the user asks for one, or
to downshift to a faster one on a trivial diff. `xhigh` is verified working in this setup; an
unrecognised effort value is not rejected loudly, so stay on the ladder above.

### 3. Write the prompt

Read `references/prompt-template.md` and fill it in. Non-negotiable parts:

- **Domain context in prose.** The invariant the diff must preserve, the state machine, what
  production data really looks like. This is the highest-leverage section.
- **Focus item 1 is a hypothesis, not a topic.** Put the thing that worries you most, phrased so
  Codex must confirm or refute it with a repro. Include the doubts you cannot resolve yourself —
  especially a divergence you introduced knowingly.
- **Blast radius**, naming the callers by file, above all outward-facing ones.
- **What the change claims to do**: the pull request description and the linked issue, pasted, for
  the alignment item (undocumented behaviour, drive-bys).
- **Error detection**: whether a breakage in production would be seen before users report it.
- **A test-quality item**: would the new specs actually fail against the pre-change code?
- **The anti-fabrication clause**, verbatim: high effort without it pads the report with
  speculation to look thorough.

### 4. Run it

```bash
~/.claude/skills/codex-review/scripts/codex-review.sh <prompt-file> [effort] [model]
```

Read-only sandbox is pinned in the script. Do not remove it: a typical `~/.codex/config.toml` runs
`danger-full-access` with `approval_policy = "never"`, which inherited would let a review rewrite the
working tree.

Call the scripts by their absolute path from the reviewed project, never after a `cd` into the
skill: both refuse to run inside the repository that holds them.

Run it in the background — `xhigh` takes minutes. The report is the last block of stdout, printed
twice (streamed, then as the final message).

Write the prompt file with the file-writing tool first, pasting in the output of
`agentic-review known` for a later pass, and launch only the scripts in the background command,
with `</dev/null`. Never build the prompt in a heredoc inside that background command: one such
pass sat 80 minutes on an empty prompt file, `cat` waiting on a heredoc that never reached it, with
no Codex process started. The script refuses an empty prompt file. Within a minute of launching,
check that a `codex exec` process runs (`pgrep -fl 'codex exec'`); if none, the launch is stuck
before Codex, stop it and relaunch.

### 5. Triage, do not auto-apply

Sort every finding into one of three buckets and say which is which:

- **Regression introduced by this diff** → fix now, with a regression test.
- **Pre-existing problem the diff merely exposes** → report it, do not silently widen the scope. If
  the proper fix is architectural, say so and why a patch would be worse.
- **Wrong or not worth it** → say so with the reason. Codex reports real-looking findings that do not
  hold; verify each one against the code before acting. A dismissal that reads right is worth nothing
  on its own: most alarming findings are cleared by a single fact (e.g. "this callback only runs
  after commit, so a rollback never purges"). Name that fact and prove it as far as is cheap:
  `cited` (a real `file:line`, or the gem's source at the pinned version), `walked` (the failing
  scenario followed step by step does not reach), `ran` (a small script calling the real code fails
  loud if the fact is false), `reproduced` (in the running app). `agentic-review` refuses a `wrong`
  without that level, and below `ran` on a security, P0 or P1 finding.

When a finding names a class of defect, fix every instance of the class in the diff in the same
round, not only the line Codex pointed at: otherwise the next pass finds the next instance.

Check the findings that clear you too, not only the ones that accuse you — a "no regression found" on
a worry you raised in your own summary is worth relaying.

For every fix, verify the new test fails without it:

```bash
git stash push <changed files> -q && <test command>; git stash pop -q
```

Then re-run the project's own checks. A Codex review is not a substitute for the test suite; it did
not run it.

### 6. Converge: cap the passes

An agent fixing and an agent reviewing can keep each other busy forever: each pass digs up a few
more defects in code that was already there at the first pass. Anthropic saw a pull request go
through more than fifty overnight rounds this way, 59% of the repeated findings on code present
since the first pass; capping the rounds and re-reviewing only the new diff took the pull requests
needing five rounds or more from 8.9% to 1.5%.

- The first pass reads the whole branch. Every later pass reads only the fixes
  (`git range-diff <base> <head reviewed> HEAD`), never the whole branch again.
- Every later prompt lists what is already triaged, from `scripts/agentic-review known`, and asks
  Codex not to report it again (see the template).
- Three passes on a branch is the cap. A third pass still finding regressions means the approach is
  wrong, not unfinished: stop, tell the user what keeps breaking and question the design instead of
  launching a fourth pass. Old defects the passes surface are `pre-existing`, not a reason for
  another round.
- Work the user adds to the branch afterwards (a new feature in the same pull request) opens its own
  series of at most three passes, the first reading only that work
  (`git range-diff <base> <head reviewed> HEAD`), not the whole branch again.

### 7. Commit each fix where it belongs

One commit per finding, never one "address review" commit for all of them. Make it a fixup of the
commit that introduced the defect, found with `git log -L` or `git blame` on the lines you changed:

```bash
git add <files of this finding>
git commit --fixup=<sha that introduced the defect>
```

When the fix carries a reason worth keeping (the failing scenario Codex found, a trade-off, why
the obvious patch was wrong), use `--squash` instead and write that reason in the body:

```bash
git commit --squash=<sha> -m "<subject>" -m "<why: the scenario and the choice made>"
```

At autosquash, a fixup's message is discarded while a squash's message is offered merged with the
target's: edit the combined message so the reason ends up as a paragraph of the origin commit, and
the history keeps why the code is shaped that way without keeping the detour.

The branch history then folds itself back into clean commits with
`git rebase -i --autosquash <base>` (or the `tidy-commits` skill), each fix landing in the commit
that wrote the bug, so the reviewer reads the right code once instead of a defect and its patch. A
single commit mixing fixes for code written in several commits cannot be redistributed without
splitting it by hand, file by file and hunk by hunk.

When a finding spans several origin commits, split the fix along them. When it does not belong to
any branch commit (a pre-existing problem you chose to fix anyway), give it its own commit with a
message that explains the defect. A test hardened because Codex showed it was vacuous is a fixup of
the commit that added the test.

### 8. Publish the proof of review on the pull request

A human reviewer cannot tell which passes the branch went through, on what, and whether they still
cover the code. `scripts/agentic-review` records them and publishes, on one's own pull request, a
commit status `Agentic review` on the head commit and a single comment, edited at each pass, with
the passes, the fixed findings and the ones left with their reason.

This is the proof of review: it says what read the code, not that the change works. Once it is
published, run the `pr-proof` skill, which posts the proof of change (screencast, before/after,
review guide, CI and tests at the head) in its own comment. Never put either in the other.

Record as you go, never reconstruct afterwards:

```bash
~/.claude/skills/codex-review/scripts/agentic-review start --reviewer Codex --effort xhigh --scope "whole branch, focus on <hypothesis>"
~/.claude/skills/codex-review/scripts/agentic-review finding --kind bug --severity P1 --title "<defect, one line>" --open
~/.claude/skills/codex-review/scripts/agentic-review finding --id f1 --fixed "<the fix>" --commit <fixup sha>
~/.claude/skills/codex-review/scripts/agentic-review finding --id f2 --left "<why it stays>" --verdict pre-existing
```

- `start` right before running Codex: it snapshots the diff the pass reads (per-file patch-ids of
  `git diff <merge-base>..HEAD`), so commit first.
- One `finding` per triaged finding, when it is triaged. Kinds: security, bug, product, perf,
  design, test, docs, nit. Keep Codex's severity (`--severity P1`) when it gave one. `--commit` is
  followed through autosquash by its subject.
- A finding left unfixed carries its verdict: `wrong` (false alarm), `intentional`, `pre-existing`
  or `deferred` (own ticket). A `wrong` also takes `--proof` and its reason states the fact that
  clears it with the evidence (the `file:line`, the script's output). Be honest with `wrong`: the
  verdicts, read back across pull requests
  from the state in their comments, measure how much of Codex's output is noise at each effort, and
  are the only evidence to move the effort ladder above or the size threshold of
  `manual-review-pr`.
- Other passes use the same commands: `--reviewer "Claude code-review" --effort max` for
  `/code-review`, and `decision --axis --problem --decision --why [--commit]` for a design pass,
  where "kept" is a valid decision and the why quotes the author when they settled it.

The comment opens on a merge risk for the human reviewer, then the gaps of each category, and
nothing for a category without one. After the last triage, record the gaps in one call, which
replaces the previous ones (no option: assessed, no gap):

```bash
~/.claude/skills/codex-review/scripts/agentic-review risk \
  --alignment "<behaviour changed or assumed that neither the description nor the issue states>" \
  --impact "<blast radius beyond the diff, sensitive area touched>" \
  --verification "<behaviour or edge case nothing proves: no test, no capture>" \
  --rollback-cost "<a one-way door: data dropped or rewritten, a message sent, a contract published>" \
  --error-detection "<a breakage nobody would see before users: error swallowed, no log, Sentry nor alert>"
```

Every option is repeatable. A gap is a fact a reviewer can check, one line, never a grade; leave a
category out when it has none, error detection included when the diff has no runtime flow.
Verification is what the `pr-proof` comment will not prove: the comment only counts those gaps,
their text lives once, under "Not verified" in the proof comment. Rollback cost is only a real
one-way door. A gap already carried by a finding left unfixed is not recorded again: on
datagouv/apistration#664 an error-detection gap restated the INVALID index finding of the table.

Measure before recording a gap: what can be checked from here (a table size through an aggregate
query, the deploy order in the repository's deploy config) is checked, and a gap names only what
could not be. On the same pull request, "production table size not measured" made the risk medium
when one `pg_total_relation_size` would have settled it.
The level is computed, never chosen: `high` when a security, P0 or P1 finding ships unfixed (open,
`intentional` or `deferred`) or rollback cost has a gap; `medium` when any other finding ships unfixed
(nits, `wrong` and `pre-existing` aside) or any category has a gap; `low` otherwise. Warp's skill
weights five grades into a score: a number averaging a one-way door with four good grades reads
reassuring for the one change that cannot be undone. The merge risk informs the reviewer, it does
not change the status.

Freshness lives in the status, never in the comment's wording: the status is `success` when a pass
read exactly the diff of the pushed head (a rebase without conflict keeps it), `pending` with a
description starting with `Stale:` otherwise (a pass is due, nothing known is wrong). `failure` is
kept for real blockers, whatever the coverage: a finding not triaged, or a security, P0 or P1 the
pull request ships on purpose (`intentional`). A fixed one, a `pre-existing` one (already on the
default branch), a `deferred` one (it has its own ticket) or a `product` choice stays for `gate` and
the human reviewer, not for the status. On superdocu/app every red status had been a
stale one after a CHANGELOG or a contract entry. Fixes made after a pass make it stale by design:
once autosquashed, run a short confirmation pass on them before publishing:

```bash
git range-diff <base> <head reviewed> HEAD     # the fixes, as Codex must read them
~/.claude/skills/codex-review/scripts/agentic-review start --reviewer Codex --effort medium --scope "confirmation: fixes of Codex 1"
~/.claude/skills/codex-review/scripts/agentic-review check                   # exit 1 and the unreviewed files when stale
```

Publish only at the end of the triage, after pushing:

```bash
~/.claude/skills/codex-review/scripts/agentic-review publish --dry-run
~/.claude/skills/codex-review/scripts/agentic-review publish [--note "<what changed since the last pass, when stale>"] [--request-reviewer <login>]
```

A human reviewer is requested here, through `--request-reviewer`, never when the pull request is
opened: GitHub notifies them at once, and the passes that follow rewrite what they would read. "Open
a PR and request a review from X" means `gh pr create` without `--reviewer`, the review loops, then
`publish --request-reviewer X`. On PR 645 the reviewer was requested at `gh pr create`, then two
passes found nine defects and rewrote the commit.

It refuses a pull request opened by someone else or a local HEAD that differs from the pushed one.
Before the pull request exists, the state stays in the git dir of the worktree and `publish` says
so; run it again once the pull request is open. Leaving a pull request stale is fine when the last
changes are trivial: the comment's "Not reviewed" row tells the reviewer what was not read. Going
from `success` or `pending` to `failure` posts a one-line notice, since editing a comment notifies
nobody; going stale posts none.
Never put secrets or production data in titles and reasons: the comment is visible to anyone who
can read the repository.

When the project lets an agent merge without a human, `gate` is the check that decides:

```bash
~/.claude/skills/codex-review/scripts/agentic-review gate --require "<CI status the project needs>"
```

It exits 0 only when every finding is fixed or cleared as `wrong`, `pre-existing` or `deferred`;
none is security, P0, P1, `product` or `intentional` (a human arbitrates those, fixed or not); no
rollback cost gap was recorded with `risk` (a one-way door); only
the first pass raised findings, so the confirmation pass on the fixes found nothing; the status is
published and covers the head; and every check of the pull request is green. Otherwise it lists
what waits for a human. A stale status blocks it even after a one-line fix: run the short
confirmation pass instead of leaving it stale.
