---
name: ux-guide
description: Build the UX guide of a pull request that changes an interface - one short screencast per user-visible feature, each next to what it shows and what to check in review, on a static page in the project's colours, published behind a password next to the review guide and embedded in it. Use when the user asks for "un guide UX", "un screencast global des features", "un screencast par feature avec le détail", "une vidéo par fonctionnalité", "un guide de revue style UX", "montre toutes les features de l'écran en vidéo", or when pr-review-guide needs a UX tab for a PR that changes several journeys of an interface.
---

# UX guide

A reviewer, a product owner or a designer opens one page and sees every
feature of a new interface working, one video each, with what the video
shows and what deserves a look in review. Built for superdocu/app#2354 (a
rebuilt dashboard: 9 videos of 16 to 33 s); the user called the format
"cool" and asked for it as a skill.

It complements, never replaces, the two other artefacts of a PR:
`pr-proof` films the journeys whose state changes to prove the head
works; `pr-review-guide` explains the code. The UX guide explains the
product, feature by feature, and is embedded in the review guide when
there is one.

Output:

```
~/share/<slug>/          <slug> = <project>-pr-<n>-ux
  UX.md        the only file edited: front matter, one ## per feature
  build.py     renders index.html, exit 1 on a missing or unused video
  style.css    tokens of the project's identity
  scenarios/   lib.sh + one <slug>.sh per feature, data.rb (or equivalent)
  videos/      <slug>.mp4 and its poster <slug>.jpg
  sheets/      contact sheets, never published
  index.html   generated
```

Assets in this skill's base directory: `assets/UX.md` (skeleton),
`assets/build.py` (format in its docstring), `assets/style.css`,
`scripts/lib.sh` (recording helpers sourced by each scenario),
`scripts/check-videos.sh` (decodes each video, writes contact sheets and
posters). Read `static-page` for where files live, the identity and the
publication, and `screencast` for the recorder and `demo.js`.

## Workflow

### 1. List the features

From the diff, not from memory: the views, components and front-end
controllers it adds or changes, the PR description, the locale keys.
One feature is one thing a user can see or do (a banner, tabs, a panel,
keyboard navigation, a batch action, an entry point from another page,
mobile), 6 to 10 in all. Name each one as the user sees it. Note for
each the ids its scenario will target.

### 2. Run the app with data that shows everything

Through the project's `verify-<app>` skill, on the PR's worktree, from a
fresh seed. Open the screen and check every feature has something to
show: on #2354, two of three tabs were empty with the seeds. Fill them
with a data script (`scenarios/data.rb` through `rails runner`) touching
as few records as possible, giving them plausible names, and say what
was adjusted in the page's last section: a reviewer must not take the
demo for production behaviour.

### 3. Write one scenario per feature

`scenarios/<nn>-<slug>.sh`, sourcing `scripts/lib.sh` (copy it next to
them, set its variables at the top of a local wrapper). Each one starts
on the screen the user starts from, before `rec_start`, and ends on the
visible effect, in 15 to 35 s. Pacing and cursor follow `screencast`.

- **Order**: scenarios that change nothing first; those that validate,
  send or delete last, each from a state you can recreate
  (`data.rb` after a reseed).
- **Hide dev overlays with a style, not by removing them**: they come
  back after each request (`lib.sh` injects `HIDE`). Never hide flash
  messages: they are the user's feedback.
- **Close a modal by the button the user clicks** (`d.button('Annuler')`):
  Escape did not close the app's modal on #2354 and the rest of that take
  was filmed behind it.
- **Scroll inside a panel with `panel_scroll`**: `d.scroll` moves the
  window, not a side panel.
- **Mobile**: the recorder scales frames to 720 px high, and an odd width
  breaks the encoder (390×844 gave 333 px wide, no video). Use 390×780 or
  360×720.

Dry run every scenario with `RECORD=0` and grep `✗`; then record.

### 4. Check every video

```bash
<skill>/scripts/check-videos.sh ~/share/<slug> 01-banner:7 02-tabs:23
```

Then look at every contact sheet in `sheets/`. A scenario can pass with
no `✗` and still film nothing useful: on #2354 the tabs video showed the
reminder modal for its last 15 s. Retake what the sheet shows wrong. Give
each video a poster at a representative second (the open panel, the
selection bar), not its first frame: nine posters of the same landing
page made the page look like nine copies of one video.

### 5. Write the page

```bash
cp <skill>/assets/{UX.md,build.py,style.css} ~/share/<slug>/
```

Set the tokens of `style.css` as `static-page` says. In `UX.md`, per
feature: the one-line pitch, then what the video shows in the order it
happens, with the real figures seen (17 → 16, 96 → 95), then
`### À regarder` for what a reviewer should check: a product choice kept,
a difference with the previous behaviour, an open point. Close with what
was not filmed and the data used. `python3 build.py` must end with
0 warning; look at the page at desktop width and at 400 px.

### 6. Publish and link

As `static-page` describes, with `--except UX.md --except build.py
--except scenarios --except sheets`, behind a password: the feature is not
released.

- **A review guide exists**: publish into its folder, as the folder
  `<review-folder>/ux`: the review folder's password covers it. Link the
  directory from the review guide's (`ln -s ~/share/<slug>
  ~/share/<review-slug>/ux`) and add its UX tab, as `pr-review-guide`
  step 5b describes; the review guide is published with `--except ux`.
- **None**: its own `<slug>-<suffix>` folder, with the password of any
  other page of the same PR so the reader types one.

Then link it, with the direct link and the password on a private
repository: one line in the PR description, and a link on the work's
navette item (`--link "video|Guide UX|<url>"`, three links at most,
the pull request first).

## Iterate

Edit `UX.md`, rebuild, republish to the same folder. When the branch
changes a filmed feature, retake its scenario only; the others keep
their videos.
