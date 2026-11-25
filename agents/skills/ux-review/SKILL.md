---
name: ux-review
description: Review the UX of the screens a pull request touches - walk each screen in the running app for every role concerned, at desktop (1280 px) and phone (390 px) width, write numbered findings U1…Un (severity, effort, fact, concrete recommendation naming the design-system component and the accessibility criterion), have Codex check each factual claim against the code, publish them on a password-protected static page and list the review in the agentic review comment without blocking its status. Launched by codex-review as a parallel sub-agent when `scripts/ux-signal.sh` says `run`; also on demand. Use when the user asks for "une revue UX", "review UX de la PR", "regarde l'ergonomie des écrans", "audit UX des écrans touchés", "UX review", or answers a UX review with a one-line triage ("U1 oui, U8 fix it").
---

# UX review

A code review never opens the app: it misses a tab that loses context, a
phone layout that breaks, an error message a user cannot act on. Built from
datagouv/apistration#724 (editor page with tabs, editor and admin spaces):
23 findings the user triaged in one line each (« U1 oui, U14 on verra, U16
à adapter, U8 fix it »). The numbered format is what makes that triage
possible; keep it.

It is a review, not a proof: `pr-proof` shows the head works, `ux-guide`
shows each feature, `pr-review-guide` explains the code. This one says
what to change for users. It never blocks the `Agentic review` status.

## 1. Decide whether it runs

```bash
~/.claude/skills/ux-review/scripts/ux-signal.sh [<base>]
```

- `run`: a new screen (view, component, or GET route next to interface
  files) or >= 150 interface lines. `codex-review` launches it.
- `offer`: propose it to the user in one line, do not run it.
- `no`: nothing a user sees changed.

On a later push, pass the commit the last review read as `<base>`: only a
new `run` on that range calls for a new review; otherwise the page stays
and the agentic review line keeps its commit.

## 2. Scope the screens and the budget

List from the diff the screens it touches, plus one hop: the screen a user
comes from and the one they land on. Cross them with every role that sees
them (editor and admin on #724) and the two widths. That product is the
number of captures; above 40, list the screens to the user and ask which
to keep.

Reuse the captures `pr-proof`, `ux-guide` or `pr-review-guide` already made
at the head instead of taking them again.

## 3. Walk the app

Launch it with the project's `verify-<app>` skill. Without one, start it
the usual way and drive it with `agent-browser` and the project's dev
login; when it does not start or has no way to log in as each role, stop,
skip the review and raise it in "Needs you" with `create-verify-skill`.

For each screen, role and width: a full-page capture, then crops on the
block a finding discusses, in `~/share/<project>-pr-<n>-ux-review/img/`.
Use the states a user meets (empty, filled, error, long text), not only
the seed's happy path.

## 4. Write the findings

Look at every capture before writing anything about it. A doubt is
settled in the real browser, never from the capture: on #724 a « missing
white frame » was an artefact of the full-page capture and was dropped.

Each finding:

- `U<n>` and a title stating the problem;
- severity: Important (a user fails or gives up, an accessibility
  blocker), Moyen (a user hesitates or works around it), Confort;
- effort: S, M, L;
- Constat: what happens, factual, with the capture;
- Recommandation: the change, naming the design-system component (load
  `dsfr-skill` on a DSFR project) and the RGAA criterion when there is one;
- production figures only when they weigh on the choice, as aggregates
  (`outis` or the project's read-only access), never rows.

The page opens on the five findings to do first, ends on a plan in lots
with their effort and the product decision a lot depends on. Write it in
the user's language.

## 5. Have Codex check the claims

Claims about behaviour (« the input is lost when switching tabs », « the
INSEE check takes a minute ») come from screens, not from code. Two such
claims were wrong on #724 and caught only by rereading the code. Before
publishing, fill `references/verify-prompt.md` with the draft and run it:

```bash
~/.claude/skills/codex-review/scripts/codex-review.sh <prompt-file> medium
```

A claim Codex refutes with a `file:line` is corrected or dropped; an
unclear one is checked in the browser. Codex adds no finding.

## 6. Publish

Build the page with `static-page` in the project's identity, one card per
finding (id, title, severity and effort badges, Constat, Recommandation),
and publish it with `upload-assets` in `<project>-pr-<n>-ux-review-<hex>`,
behind a password while the feature is not released.

Then, in the session that runs `codex-review`, after the last triage of
Codex and before `publish`:

```bash
~/.claude/skills/codex-review/scripts/agentic-review start --reviewer "Claude ux-review" --advisory \
  --scope "UX at <sha>: <N> findings, <x> Important, <url without #k=>"
```

Never put the `#k=` key in that scope: the comment is public to anyone
who reads the repository. `--advisory` lists the review without making
the head look covered by a code review.

## 7. Act on the triage

The user answers in one line. Everything accepted (« oui », « fix it »,
« à adapter » with its adaptation) is fixed in the pull request; « on
verra », « non » stay as they are. Before coding, when the accepted
findings add up to an L or more than three M, propose moving a lot to a
follow-up pull request and let the user decide.

One commit per finding, its subject the change for users. Then a
`codex-review` pass on those commits (`git range-diff`, as for work added
to the branch), `pr-proof` refilms what changed, and the page is
republished with each finding's state (fait, plus tard, écarté).
