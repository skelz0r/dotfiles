# Review prompt template

Codex gets no conversation history. Everything it needs goes in the prompt. Fill each section, drop
the ones that do not apply, write it to a file, pass it to `scripts/codex-review.sh`.

```
Do a code review of <TARGET>. Start with `<GIT COMMAND>` and read the surrounding files.
Review only — do not modify any file.

<ONE LINE ON WHAT THE APP IS>

Domain context you need:
- <INVARIANT OR STATE MACHINE THE DIFF DEPENDS ON>
- <NON-OBVIOUS COUPLING BETWEEN LAYERS>
- <WHAT PRODUCTION DATA ACTUALLY LOOKS LIKE, IF IT MATTERS>

Focus, in order of importance:

1. <YOUR OWN STRONGEST SUSPICION, STATED AS A HYPOTHESIS TO CONFIRM OR REFUTE>
2. <SECOND RISK>
3. <BLAST RADIUS: WHAT ELSE CONSUMES THE CHANGED METHOD>
4. <PERFORMANCE, IF A HOT PATH IS TOUCHED>
5. Test quality: would the new specs actually fail against the pre-change code, or are any vacuous?

Report concrete defects with file:line and a failing scenario. Skip style nits. If you find nothing
real in a section, say so plainly instead of inventing findings.
```

## Section notes

**Target.** Prefer a commit range over a working tree: `git show <sha>`, or
`git diff <base>...HEAD`. Name the exact command so Codex does not guess the range.

**Domain context.** The highest-leverage part. Codex reads code well and infers business rules
badly. State the invariant the diff is supposed to preserve, in prose. Example: "status X means the
contact claimed the document is not applicable and the consumer must still arbitrate; it is pending
consumer work even though no file was uploaded."

**Focus item 1.** Put a real hypothesis here, not a topic. "Check the SQL" wastes the budget.
"The subquery joins the table directly while the association applies `active` and `enabled` scopes —
confirm or refute that a contact on an archived workflow now surfaces a card that renders nothing"
gets a verified yes/no with a repro. If a hypothesis is already disproven, say so and why, so the
budget goes elsewhere.

**Blast radius.** Name the callers by file, especially anything with outward-facing effects
(webhooks, CRM sync, notifications, public API responses). Codex will not find them reliably on its
own and a silent behaviour change there is the expensive kind.

**Anti-fabrication clause.** Keep the last sentence verbatim. Without it a high-effort run pads the
report with speculative findings to look thorough.

## Sandbox note

The script pins `--sandbox read-only` on purpose. A typical `~/.codex/config.toml` carries
`sandbox_mode = "danger-full-access"` and `approval_policy = "never"`; inherited, that lets a review
rewrite the working tree. Do not drop the flag, and never pass
`--dangerously-bypass-approvals-and-sandbox` for a review.

Codex still runs git and can execute code in memory to build repros — that is what produces verified
findings rather than guesses, and read-only does not prevent it.
