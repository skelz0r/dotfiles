# The review comment

Read from step 6 of `SKILL.md`.

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

Prefer an inline comment when a point is about a precise spot of the
code (a nit, a misleading name, a comment to drop): it lands where the
author edits, and keeps the review body for what spans several files.
Draft each inline comment in its own file too, and say on which lines
of the head it anchors.

The state is the user's: `REQUEST_CHANGES`, `APPROVE`, `COMMENT`, or an
approval with a condition stated in the body (e.g. "technique OK, une
confirmation métier avant de merger"), which unblocks the PR on the code
while leaving the merge to that confirmation.

Wait for the user's go, check `gh pr checks <n>` and that the head did
not move since the drafts, then post with `scripts/post-review`, which
pins the review to the PR head and attaches the inline comments (`gh pr
review` cannot):

```bash
scripts/post-review --dry-run <owner/repo> <n> APPROVE <body-file> "<path>:<start>-<end>=<comment-file>"
scripts/post-review <owner/repo> <n> APPROVE <body-file> "<path>:<start>-<end>=<comment-file>"
```

To amend a review already submitted, keeping its state:

```bash
gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[] | select(.user.login == "<user>") | {id, state, body}'
gh api -X PUT repos/<owner>/<repo>/pulls/<n>/reviews/<id> -F body=@<file>
```
