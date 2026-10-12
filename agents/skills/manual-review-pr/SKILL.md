---
name: manual-review-pr
description: Review a pull request together with the user at the design level — a quick local pass (or a Codex pass when the PR is large), the main design findings ranked, then a conversation where the user's own remarks are checked against the code and challenged, alternatives explored and decisions recorded with their justification, ending with a design review page (overview, final target, one sub-tab per solution, product decisions, minor notes) published on assets.delmai.re. Never posts anything on the PR. Use when the user runs /manual-review-pr <url>, says "je relis la PR …", "fais toi aussi une passe et challenge mes points", "relis cette PR avec moi", "review de conception", "on discute de la PR avant que je commente", or wants a shareable summary of a review discussion.
---

# Manual PR review

A review done with the user, not for them: the agent brings facts and a
second opinion, the user decides, and the page at the end records the
target design and every decision with its justification. Line-level
nitpicks are not the point; where responsibilities live is.

**Never post on the PR** (comment, review, suggestion, label), not even at
the end, unless the user explicitly asks for it later in the conversation.

## 1. Inputs

- **Required**: the PR URL (or number in the current repository).
- **Optional**: the user's first remarks. When given, they are the agenda:
  every one gets a verdict.

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
  lines and touches no costly area (money, access, personal data,
  outbound actions).
- **Add a Codex pass** above that, or on a costly area: launch the
  `codex-review` skill on the range in the background and do the local
  pass meanwhile; triage its findings into the same list.

The threshold is a starting point: adjust it when a review shows it was
wrong, and record the change here.

## 4. The local pass, design first

Read the hand-written code and, more importantly, what it plugs into:
base classes, callers, every other user of the classes it changes (one
class shared by two entry points changes where a responsibility can
live). Look for:

- **Misplaced responsibility**: a rule living in the orchestrator when the
  object it is about could declare it (e.g. a hard-coded list of errors
  instead of the error saying what it is).
- **Ad-hoc lists without a business rule**: ask what justifies "this case
  yes, that one no". If nothing does, the list is a smell.
- **Duplicated paths**: test, mock or sandbox paths that re-implement the
  decision of the real path.
- **State leaking through shared context**: values set then reset to
  hide them, copies made defensively.
- **Hooks working around the framework** (e.g. an `around` because a
  chain stops on failure): the sign the code sits in the wrong layer.
- **Tests and public docs encoding the rule** rather than a need: they
  will flip if the rule changes.
- **Product or legal implications**: what the feature lets a user prove,
  forge or skip.

Check every claim against the code before saying it. A user remark can
rest on a wrong fact (e.g. "it matches on the error code" when it matches
on titles): say so, then answer the real concern behind it.

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
  - **axes**: in the PR / target / why / consequences;
  - **decisions**: the decision and the user's justification, in their
    words;
  - **open questions**;
  - **minor notes**, kept even when the user waves them off ("for the
    record").

Offer the page when the axes have converged; build it when asked.

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
   (pinned links), the axes table (in the PR / target / detail link), the
   proposed refactor order, what is kept as is.
2. **Cible finale**: the whole target at once, to show it is clean: who
   does what (table), a request flow diagram in a `text` block, a sketch
   of each piece, what the next feature of the same kind has to write,
   and what disappears from the PR.
3. **Solutions**: a short intro, then one `<!-- subtab: … -->` per axis:
   today (real excerpt, pinned link), the problem, the decision in a
   callout with the user's justification, the target sketch, the
   consequences.
4. **Décisions produit**: one callout per decision with the user's
   justification; open questions last.
5. **Notes**: minor findings, for the record.

Rules:

- **Real excerpts come from the pinned head commit; sketches say they are
  sketches.** A sketch follows the repository's idioms (check them: e.g.
  no endless methods if the codebase has none) and must be coherent from
  one tab to the other.
- **The user's justifications are quoted as decisions**, not turned into
  the agent's arguments.
- **Design level**: no line-by-line review; a detail belongs in Notes.

Build to zero warnings, look at every tab and one sub-tab reached by
`#anchor` at desktop and ~400px, as `static-page` describes.

## 7. Publish

Through `upload-assets`. Ask public or password, unless already said:
public is fine when the repository is public on GitHub, a password when
the feature or the discussion is internal. Give the URL. Do not link it
from the PR unless asked.
