---
name: manual-review-pr
description: Review a pull request together with the user at the design level — a quick local pass (or a Codex pass when the PR is large), the main design findings ranked, then a conversation where the user's own remarks are checked against the code and challenged, alternatives explored and decisions recorded with their justification, ending with the review comment to post (sections chosen with the user, every code mention linked at the head commit) and, when an axis leaves the author several options, a design review page (overview, final target, one sub-tab per solution, product decisions, minor notes) published on assets.delmai.re (in public when the repository is). Never posts anything on the PR unless asked, then posts exactly the validated file with the review state the user chose. Use when the user runs /manual-review-pr <url>, says "je relis la PR …", "fais toi aussi une passe et challenge mes points", "relis cette PR avec moi", "review de conception", "on discute de la PR avant que je commente", or wants a shareable summary of a review discussion, a TL;DR or a full message of their review to post on the PR ("propose-moi un message", "poste-le en request changes").
---

# Manual PR review

A review done with the user, not for them: the agent brings facts and a
second opinion, the user decides, and the comment (with the page when
there is one) records the target design and every decision with its
justification. Line-level
nitpicks are not the point; where responsibilities live is.

**Never post on the PR** (comment, review, suggestion, label), not even at
the end, unless the user explicitly asks for it later in the conversation.

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
step 8 can go alone, and gets the page link added on top if the page is
built later.

## 6. The page

Built with the assets of the `pr-review-guide` skill (`build.py`,
`style.css`, both in its `assets/`) and the skeleton `assets/GUIDE.md` of
this skill. Read `static-page` first for where files live, theming and
checks. Slug: `<project>-pr-<n>-review`.

```bash
mkdir -p ~/share/<slug>
cp <pr-review-guide>/assets/{build.py,style.css} ~/share/<slug>/
cp <this skill>/assets/GUIDE.md ~/share/<slug>/
ln -s ~/share/<slug> <repo>/sandbox/<slug>
```

Tabs, in this order:

1. **Vue d'ensemble**: a one-sentence verdict, what the PR does today
   (pinned links), the axes table (in the PR / constraint / detail link),
   the proposed refactor order, what is kept as is.
2. **Cible finale**: a callout saying it assembles the recommended
   options and is illustrative, then all the constraints in one list,
   then the whole target at once, to show it holds together: who does
   what (table), a request flow diagram in a `text` block, a sketch of
   each piece, what the next feature of the same kind has to write, and
   what disappears from the PR.
3. **Solutions**: a short intro, then one `<!-- subtab: … -->` per axis:
   today (real excerpt, pinned link), the problem, the decision in a
   callout with the user's justification, the **constraints**, the
   **options** (table: option / for / against, the user's own idea among
   them when they had one) and the recommended one, its sketch, the
   consequences.
4. **Décisions produit**: one callout per decision with the user's
   justification; open questions last.
5. **Notes**: minor findings, for the record.

Rules:

- **Constraints bind, sketches illustrate.** Whoever takes the page next,
  the PR's author or an agent briefed with it, copies a lone code excerpt
  as if it were the spec. So each axis states first what any solution
  must guarantee (who must not know what, which paths must agree, what
  the contract must not gain): that is what the fix will be reviewed
  against. Then two or three options with honest costs, so none reads as
  the only way. A callout at the top of the page says that diverging
  from the sketches is expected as long as the constraints hold. An axis
  with a single sensible fix (a bug) states its constraint and a "Piste",
  without a code sketch.
- **Real excerpts come from the pinned head commit; sketches say they are
  sketches.** A sketch follows the repository's idioms (check them: e.g.
  no endless methods if the codebase has none) and must be coherent from
  one tab to the other.
- **The user's justifications are quoted as decisions**, not turned into
  the agent's arguments.
- **Design level**: no line-by-line review; a detail belongs in Notes.
- **Callout variants go in braces**: `::: {.callout .warning}`;
  `::: callout .warning` renders as plain text.

Build to zero warnings, look at every tab and one sub-tab reached by
`#anchor` at desktop and ~400px, as `static-page` describes.

## 7. Publish

As described in `static-page`, into the `<slug>-<suffix>` folder it
records, with `--except build.py --except GUIDE.md`.

Access follows the repository, without asking:

- **Public repository on GitHub** (`gh repo view --json visibility`):
  publish in public, even for an unreleased feature, since the code is
  already public. Before the upload, check that everything the page says
  is already public: code, commits, PR description and comments, docs of
  the repository. Nothing from the ticket tracker (Linear, Jira), Slack,
  meetings, Sentry, metrics or production data, no internal URL, no real
  personal data (a name or identity from a fixture is fine, one from a
  log is not), no internal plan or other team's position. Rephrase or
  drop what is not; when a decision rests on internal context, keep the
  decision and drop the context.
- **Private repository**: behind a password.

Give the URL. Do not link it from the PR unless asked.

## 8. The review comment

Draft the comment the user will post with their review, with or without
a page: the page link first when there is one (on a private repository,
the direct link and the password, as `static-page` states).

Content:

- Everything the conversation covered, in the decisions' order of
  weight: what to rework in the design, the bugs, then the product
  points, with what is not blocking flagged as such. Minor notes the user
  waved off stay, introduced as such ("Pour mémoire", "on peut s'en
  passer"): the author reads them as optional instead of discovering
  them later.
- What is wrong and why, not how to fix it: no option name or DSL from
  the page, which would anchor the author on one solution. A direction
  the user settled is stated as a direction with its binding constraint
  (e.g. "centralize the source in the organizer; an EAJE attestation
  without a known regime must keep showing *origine non communiquée*"),
  quoting their justification; only unsettled options stay out.
- Every piece of code mentioned links to the PR's head commit with its
  lines, and the comment adds links for context: where the value comes
  from, who else uses it, where the responsibility already lives. Build
  each link with `scripts/pin-link <owner/repo> <sha> <path> <pattern>
  [end-pattern]`, which fails when the pattern is not at that commit,
  instead of counting lines by hand.
- The user's language; nothing that looks generated. Same leak check as
  a public page: the PR comment is as public as the repository.

Layout follows density:

- Short review (one topic, a few points): short prose paragraphs, no
  headings, bold or lists.
- Dense review: one `##` section per family of points, a bold title on
  its own line for each point, then short paragraphs separated by blank
  lines. The families are the user's when they named them (Technique /
  Produit on #639, but Données, Usagers, Sécurité... as fit); when they
  did not and the grouping is not obvious, ask. No tables or checklists.

Write the draft to a file in the scratchpad from the first version, show
it from that file, edit that file on every round, and post that file
with `--body-file` / `body=@`: the user validates exactly what gets
posted. Re-wording while posting, even to tighten it, posts a text the
user never read.

Wait for the user's go. Then, only when asked, post it with the state
they chose, or amend the review they already submitted, keeping its
state:

```bash
gh pr review <n> --request-changes --body-file <file>   # or --approve / --comment
gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[] | select(.user.login == "<user>") | {id, state, body}'
gh api -X PUT repos/<owner>/<repo>/pulls/<n>/reviews/<id> -F body=@<file>
```
