# The design review page

Read from step 6 of `SKILL.md`, once the user asked for the page.

## Build

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

## Publish

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
