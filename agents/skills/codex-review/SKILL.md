---
name: codex-review
description: Run an adversarial code review of a diff, commit or branch through the Codex CLI (a different model family), sizing the reasoning effort to the complexity of the change, then triage the findings. Use when the user asks to review something with Codex, wants a second opinion or an external/independent review of code just written, says "review avec codex", "codex review", "fais relire ça", "double-check this diff", or asks to cross-check a change before opening or merging a PR.
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
- **A test-quality item**: would the new specs actually fail against the pre-change code?
- **The anti-fabrication clause**, verbatim: high effort without it pads the report with
  speculation to look thorough.

### 4. Run it

```bash
scripts/codex-review.sh <prompt-file> [effort] [model]
```

Read-only sandbox is pinned in the script. Do not remove it: a typical `~/.codex/config.toml` runs
`danger-full-access` with `approval_policy = "never"`, which inherited would let a review rewrite the
working tree.

Run it in the background — `xhigh` takes minutes. The report is the last block of stdout, printed
twice (streamed, then as the final message).

### 5. Triage, do not auto-apply

Sort every finding into one of three buckets and say which is which:

- **Regression introduced by this diff** → fix now, with a regression test.
- **Pre-existing problem the diff merely exposes** → report it, do not silently widen the scope. If
  the proper fix is architectural, say so and why a patch would be worse.
- **Wrong or not worth it** → say so with the reason. Codex reports real-looking findings that do not
  hold; verify each one against the code before acting.

Check the findings that clear you too, not only the ones that accuse you — a "no regression found" on
a worry you raised in your own summary is worth relaying.

For every fix, verify the new test fails without it:

```bash
git stash push <changed files> -q && <test command>; git stash pop -q
```

Then re-run the project's own checks. A Codex review is not a substitute for the test suite; it did
not run it.
