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
- **Generated documentation** (OpenAPI, JSON schema, config): the exact
  excerpt of the generated file.
- **Screens**: screenshots of the real application (see below).

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
