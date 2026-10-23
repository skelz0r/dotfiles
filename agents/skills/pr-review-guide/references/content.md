# Collecting the facts and filling each tab

Everything in the guide is taken from the repository or produced by running
the code. Nothing is estimated or typed from memory.

## The pinned commit

The guide describes one commit: the head of the pushed branch.

```bash
git fetch && git rev-parse HEAD @{u}      # both must match, else push or rebase first
gh pr view <n> --json title,url,commits,additions,deletions,changedFiles
```

Put the full hash in `sha`. When the branch moves, bump `sha`, rebuild, and
reread the tabs that describe what changed: `build.py` catches a file that
no longer exists or an anchor past the end of a file, not a line that moved
inside a file.

## What can be skimmed

Split the diff between generated, mechanical and hand-written code, with
numbers:

```bash
git diff --numstat <base>...HEAD | awk '{
  g = $3 ~ /^path\/to\/generated\// ? "generated" : $3 ~ /_spec\.rb$|\.test\./ ? "tests" : "code";
  n[g]++; a[g] += $1; d[g] += $2 } END { for (g in n) printf "%-10s %4d files +%d -%d\n", g, n[g], a[g], d[g] }'
```

Generated files are the ones a script writes (a header such as "do not
edit", a CI job regenerating and diffing them). Say which check guarantees
they match the code: that is what lets the reader skip them.

Mechanical changes are the same one-line edit repeated across many files
(a declaration per controller, a renamed constant): show one, count the rest.

## Overview tab

- One sentence in a callout: what changes, for whom, what keeps it true.
- What ships, by surface the user touches (route, screen, command, SDK).
- What can be skimmed, with the numbers above.
- Behaviour changes users will notice, as a Before / After / Why table.
- Any decision resting on an assumption, in a `warning` callout titled
  as such: what is assumed, why it is believed, who adapts if it is wrong.

Charts, each only when the PR gives the numbers, all in markdown (syntax in
the docstring of `build.py`):

- **Lines added per zone** (`::: {.chart .stack}`), always: the zones of
  "what can be skimmed", from `git diff --numstat`.
- **Before / after flow** (`::: flows`), when the PR changes a behaviour:
  the paths through the old code and where they end (nothing, twice),
  next to the single path of the new one. Above "what ships", under the
  problem it answers.
- **A value per case, base branch against the PR** (`::: {.chart .bars
  target=…}`), when specs measure something on both: run the PR's new
  specs on the base code (`git checkout <commit of the specs>`, which
  holds the specs and not the fix), read the `got:` of each failure, then
  run them on the branch. Group the cases by what was wrong; the target is
  the expected value.
- **Data a migration touches** (`::: {.chart .stack}`), when it rewrites
  production rows: the count of the migration's `WHERE` turned into a
  `SELECT`, measured read-only on production and dated, against the
  total.

## End-to-end tab

Pick one real case that crosses most layers of the change, and follow it
from the code that declares it to what the end user sees. Each step is a
heading saying what the reader is looking at, and a sentence saying how it
differs from the previous step ("what the endpoint can return" is not "what
a caller receives when it happens").

Artefacts, all real:

- **Code**: excerpts copied from the pinned commit, each with its `gh:` link
  on the relevant lines.
- **Payloads**: produced by running the code, never written by hand:
  a serializer called from a console or runner, a request to a local
  server, a fixture replayed. Freeze the clock or the fixture when the
  payload depends on it. Truncate explicitly with `…`. No personal data, no
  token, no internal URL that should not leak.
  When the project has an isolated end-to-end harness (`bin/qa` with a
  throwaway database and fake external APIs), copy it to the scratchpad,
  keep its helpers, replace its main block by the guide's case, and
  save each payload to a file. Between steps, wait for a `go-<step>` file:
  meanwhile the server is up for the browser screenshots of that state.
  Run the copy from the project directory, so its Ruby or Node version
  file applies. Check it dropped its database afterwards.
- **Generated documentation** (OpenAPI, JSON schema, config): the exact
  excerpt of the generated file.
- **Screens**: screenshots of the real application (see below). When the
  case goes through an interface, each step that produces or reads a screen
  shows it right after its request or response, as a small `::: gallery`
  of captioned `::: shot` blocks (the same component as the Design tab):
  the form that sent the payload, the screen built from the response, the
  state after the action. Prefix each caption and alt text with the
  screen's ID from the Design tab (`![E4 · Codes de secours](img/04-backup-codes.png)`).
  When the screenshots come from the UI tests'
  data rather than the run that produced the payloads, say so once at the
  top of the tab.

## Architecture tab

The hand-written code, in reading order: the model, then how it is
assembled, generated, published. One subsection per building block: its
file linked on the method that matters, its role in one sentence, the
contract it relies on. Refactors done on the way get their own short list.

## Safety nets tab

The tests or checks that keep the change true, as a table "Check / Fails
when". Then the failure messages a developer will actually see, copied from
a real run (introduce the mistake temporarily, run the check, revert) or
from the message string in the source. Then the known limits: what no check
catches, and why.

## Commits & tests tab

One row per commit: its subject linked with `commit:`, what to look at.
Then the exact commands to test, from the right directory, with the port or
URL of the local environment.

## Screenshots

Start from the end-to-end tests the PR touches when the project can
capture them (`bin/qa` with `QA_SCREENSHOTS=1`, see the project's
`verify-<app>` skill, or `create-verify-skill` to set one up): each test
already puts the screen in the state the guide needs, the captures are
reproducible, and driving a browser by hand costs far more. Drive the
app by hand only for a state no test reaches, as below.

```bash
cd <app> && bin/rails s -d                 # or the project's own command
python3 -m http.server 8765               # for static pages: file:// is rejected
agent-browser set viewport 1440 1000
agent-browser open "<url>"
agent-browser eval "JSON.stringify(document.querySelector('#section').getBoundingClientRect())"
agent-browser screenshot --full full.png
python3 -c "from PIL import Image; Image.open('full.png').crop((x, y, x2, y2)).save('img/section.png')"
```

- Crop to the block the text talks about, keep a little context above it.
- Remove development overlays (profiler badges, debug toolbars) by cropping
  or disabling them.
- Restart the application after changing data it memoizes, and reload with
  a query string (`?v=2`) to dodge the browser cache.
- Look at every crop before using it: a screenshot often reveals a bug in
  the change itself (an empty interpolation, a wrong label), fix it first.

## Counting

Every number in the guide comes from a command run on the pinned commit
(`grep -c`, a script over the generated files, `git diff --stat`). When a
number is quoted in several places, check they agree.
