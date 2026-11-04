---
name: manual-review-pr
description: Review a pull request together with the user at the design level — a quick local pass (or a Codex pass when the PR is large), the main design findings ranked, then a conversation where the user's own remarks are checked against the code and challenged, alternatives explored and decisions recorded with their justification, ending with the review comment to post (sections chosen with the user, every code mention linked at the head commit) and, when an axis leaves the author several options, a design review page (overview, final target, one sub-tab per solution, product decisions, minor notes) published on assets.delmai.re (in public when the repository is). Never posts anything on the PR unless asked, then posts exactly the validated file with the review state the user chose. Use when the user runs /manual-review-pr <url>, says "je relis la PR …", "fais toi aussi une passe et challenge mes points", "relis cette PR avec moi", "review de conception", "on discute de la PR avant que je commente", or wants a shareable summary of a review discussion, a TL;DR or a full message of their review to post on the PR, with inline comments ("propose-moi un message", "poste-le en request changes", "fait un commentaire inline", "le message d'approve"). Also for the follow-up once the author pushed fixes ("check la dernière version", "relis les corrections, c'est ok ?").
---

# Manual PR review

A review done with the user, not for them: the agent brings facts and a
second opinion, the user decides, and the comment (with the page when
there is one) records the target design and every decision with its
justification. Line-level
nitpicks are not the point; where responsibilities live is.

**Never post on the PR** (comment, review, suggestion, label), not even at
the end, unless the user explicitly asks for it later in the conversation.

This file covers the review itself (steps 1 to 5). Read the others when
their step comes:

- `comment.md`: the review comment and inline comments, their layout,
  and how to post them (step 6);
- `page.md`: the design review page, built only when asked (step 6);
- `follow-up.md`: when the author pushed a new version after the user's
  review, instead of steps 1 to 5.

## 1. Inputs

- **Required**: the PR URL (or number in the current repository).
- **Optional**: the user's first remarks. When given, they are the agenda:
  every one gets a verdict.
- **Earlier work**: when the user already reviewed the PR (notes, a page,
  a folder under `~/share/` or `sandbox/`), never modify it, and do not
  read it before the own pass is done: a second opinion primed by the
  first one is worth half as much.

## 2. Collect

```bash
gh pr view <url> --json title,body,headRefName,headRefOid,baseRefName,files,commits
gh pr diff <url> > "$SCRATCH/pr.diff"
git fetch -q origin
git log --format='--- %s%n%n%b' "origin/<base>..<headRefOid>"
```

- Read files at the head commit with `git show "${SHA}:path"`, without
  checking the branch out. Under zsh, always brace the variable:
  `$SHA:path` is parsed as a zsh modifier and silently mangles the path.
- Read the commit messages: they hold the author's why, and the "why"
  is what the review will challenge.
- Read the agent instructions of the repository and of each app the diff
  touches (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING`): they often state
  where a responsibility lives, and a review that cites them settles a
  debate the code alone leaves open. On #639 the app's `CLAUDE.md` said
  the organizer knows nothing of the attestation, which decided where
  the source of the document goes; it was read only at the third round.
- Split the diff into hand-written code and the rest (lockfiles,
  generated API docs, vendored or synced code, fixtures, mock payloads,
  changelogs) from `gh pr view --json files`.

## 3. Size the pass

- **Local pass only** when the hand-written diff stays under about 600
  lines and touches no costly area.
- **Costly areas**: money, access and authorization, personal data,
  outbound actions (mails, webhooks, calls to third parties), documents
  with evidentiary or legal value (attestations, proofs, signatures,
  invoices), irreversible data changes, public contracts consumed by
  others (API, SDK, file formats).
- **Add a Codex pass** above the threshold, on a costly area, or when the
  local pass cannot be independent (the user's conclusions are already
  in the conversation): launch the `codex-review` skill on the range in
  the background and do the local pass meanwhile; triage its findings
  into the same list. Launch it at the start, unasked: on PR #639 of
  apistration (a student status attestation, so a costly area) the first
  answer went out without it and offered it as an option, and the user
  had to ask for the pass that then found the bug reproduced in code.

The threshold is a starting point: adjust it when a review shows it was
wrong, and record the change here.

## 4. The local pass, design first

Read the hand-written code and, more importantly, what it plugs into:
base classes, callers, every other user of the classes it changes (one
class shared by two entry points changes where a responsibility can
live), the framework's extension points, and how the same problem is
solved elsewhere in the repository. Follow what grep does not show: the
JSON a response returns, a column another job or app reads, a feature
flag, the source of a gem at its pinned version.

Walk the whole grid below. Report only what the code shows: an empty
category is a fine outcome, a finding stretched to fill it is not.

**Responsibilities**

- **Misplaced rule**: a decision taken by a caller, orchestrator or
  controller about an object that could state it itself (e.g. a checkout
  service with a `case` on payment types to know which are refundable,
  instead of each payment type saying so).
- **Re-derived knowledge**: a layer reconstructs from an output (a
  message, a label, a serialized payload, a raw header) what another
  layer knew as a typed fact. Matching on human-readable strings breaks
  silently on a wording change.
- **Ad-hoc lists**: ask what justifies "this case yes, that one no". If
  no business rule does, the list is a smell; if one does, it belongs
  in the code or the docs, not only in a commit message.
- **Reaching through objects**: reading another object's internals or
  transport details instead of asking it.
- **Stretched inheritance**: a subclass overriding a base method to
  disable it, a base designed for another case, constants borrowed from
  a sibling class. Often composition, or a narrower base, fits better.
- **Comments explaining a rule**: usually a smell, so challenge each one
  the diff adds. It often compensates code that does not say the rule:
  the same rule applied by two different guards, an override to `nil`
  that needs a sentence to be understood. Check whether the why is
  already carried by test descriptions and the commit message: then the
  comment is a third copy nothing checks, and a name or a single guard
  named after the rule replaces it.
- **Wrong level of abstraction**: generic machinery with a single user,
  or a second copy-pasted variant. Ask what the next feature of the same
  kind would have to write.

**Control flow**

- **Working around the framework**: callbacks wrapping a chain, rescue
  and re-raise, private methods called with `send`, patches, because the
  natural extension point does not fit. The sign the code sits in the
  wrong layer.
- **Exceptions as control flow**, and broad rescues that turn a bug into
  a log line.
- **Partial writes**: an object or context mutated step by step, so a
  failure midway needs cleanup code; compute first, write once.

**State and data**

- **Shared mutable context**: values set then reset to hide them,
  defensive copies, reads that depend on the order of steps.
- **Default set before the fact**: a default copied into a shared context
  before the fact it depends on is known (a `before` hook, while the
  value arrives with the response) forces the special case to write
  `nil` to escape it. Resolve the value when the fact is known (an
  `after` hook, a lazy reader) instead.
- **Inputs mutated in place** (normalization, defaults), so the original
  value is lost to whoever needs it later.
- **Time**: several "now" in one operation, time zones, expiry and
  validity windows.
- **Concurrency and idempotence**: retries, double submissions, jobs run
  twice, a check and a write that can race.
- **Cache**: whether the new behaviour bypasses, poisons or leaks through
  a cache, and on which key.

**Paths and environments**

- **Duplicated paths**: test, mock, sandbox or feature-flag paths that
  re-implement the decision of the real path, and can drift from it.
- **Environment branches** in production code.

**Contracts and evolution**

- **Public contract**: response shape, error format, SDKs, generated
  docs, versioning and backward compatibility for existing clients.
- **Data changes**: migration reversibility, backfill, deploy order.
- **Tests and public docs encoding the rule** rather than a need: they
  will flip if the rule changes. Tests mocking internal collaborators
  instead of the system boundary.
- **Commit messages out of sync with the code**: a later commit changed
  what an earlier message claims.

**Failure and operations**

- **What fails how**: what the user sees, what is logged, what alerts,
  what fails silently.
- **Cost**: extra calls to third parties, quotas, N+1 queries, payload
  size.

**Product, security, legal**

- **What the feature lets a user prove, forge, skip or learn**: a
  document that can be obtained with chosen inputs, a response that
  reveals whether a record exists, a check that can be bypassed.
- **Personal data**: minimization, who sees what, retention.
- **Authorization**: who can trigger the new behaviour, under which
  scope.

Check every claim against the code before saying it. A user remark can
rest on a wrong fact (e.g. "it runs once per request" when it runs once
per item): say so, then answer the real concern behind it.

A design that looks risky is usually safe, or not, because of a single
fact (e.g. "the job only reads rows the request already committed").
Find it instead of listing maybes, and say how far it is proven:
cited (`file:line`, or the library's source at the pinned version),
walked (the failing scenario followed step by step does not reach),
ran (a small script calling the real code fails loud if it is false),
reproduced (in the running app). On a costly area, take it to ran
before the verdict, and keep the script: it is the cheapest check to
hand the author. A fact left unproven is said so.

## 5. Converse

- First message: the user's points one by one (agree / disagree, the
  fact, the alternative), then the agent's own findings, ranked, short,
  in the user's language. No code dump; links and file:line references.
- Then one topic per round, at the user's pace. When asked to explore,
  give two or three approaches with honest costs and recommend one.
  Expand the chosen one with a sketch in the repository's own idioms.
- Brutally honest: if the user's direction has a cost or a hole, say it
  once, clearly, then follow their decision.
- Keep a ledger in the scratchpad as the conversation goes, it is the
  page's source:
  - **axes**: in the PR / constraints / options with their costs /
    recommended one / consequences;
  - **decisions**: the decision and the user's justification, in their
    words;
  - **open questions**;
  - **minor notes**, kept even when the user waves them off ("for the
    record").

The page is optional. Offer it when the axes have converged and at least
one of them leaves the author several viable options, or when the fix
will be handed to someone (the author, an agent) who needs constraints
and options rather than a verdict; build it when asked. When every point
is a bug, a question or a direction the user settled, the comment of
step 6 can go alone, and gets the page link added on top if the page is
built later.

## 6. Outputs

- The review comment: `comment.md`, always.
- The design review page: `page.md`, when the user asked for it.
