---
name: feature-pitch
description: Build a one-page presentation of a feature for a non-technical audience (product owners, bizdev, support, management) from what already exists - the pull request, its review guide, its tickets and screencasts - then publish it behind a password on assets.delmai.re. One scrolling page in plain language - why, what changes for the user, the journey in video, before / after, what goes away, what it prepares, what changes for the team, the roadmap with its tickets, the decisions taken. Use when the user wants to present or demo a feature to people who will not read the code or the review guide, says "fais un support pour les PO", "une page pour présenter la feature aux bizdev", "un support de démo", "une page de découpage pour l'équipe", "explique la feature à des non-techs", "la démo n'a pas pu avoir lieu, fais un support", or asks for the format of a previous feature pitch.
---

# Feature pitch

A product owner or a bizdev opens one page and understands, in five
minutes and without a meeting, what the feature changes for users, why,
what it prepares and what comes next. Built for apistration#716 (a
rewritten account space with self-service tokens and simplified mails)
when the planned demo could not happen; the user liked the format and
asked for it as a skill.

It reuses the artefacts of the pull request and adds none of its own:
`pr-review-guide` explains the code, `pr-proof` and `screencast` prove it
works, `ux-guide` shows each feature in video. The pitch picks from them
what a non-technical reader needs, and links the review guide for the
rest.

Follow `static-page` for files, identity, checks and publishing. Assets
of this skill: `assets/index.html` (the skeleton, sections in order) and
`assets/style.css` (tokens on top, DSFR blue by default).

## Workflow

### 1. Propose the plan before building

Write the plan in the conversation, section by section, with the one-line
content of each, and wait for the user: they know which angle the
audience needs. On #716 the first plan missed the two things the feature
was really for (moving non-technical users to their software editor,
then hardening token security) and stated "no more expiration
reminders" where only three of six went away. Both came out of the plan
review, not out of the code.

Ask in the same round, with a recommendation each:

- what the feature **prepares** (the next projects it unlocks), if
  anything;
- the **order of the roadmap**, and whether a ticket exists for each
  step; a step without one is written "à cadrer", never given an
  invented ticket.

### 2. Collect

- **Media**: only real ones, copied from the review guide or the proof
  (`~/share/<project>-pr-<n>/img`, `~/share/screencasts/`), never
  re-shot unless missing. Pick few: one video, three or four before /
  after pairs, the mail variants that carry the message. Look at each
  one: crop dev overlays (a debug bar, a dev login banner), check that
  only seed data shows.
- **Tickets**: the real URLs, read through the tracker's tools, with the
  ticket's real title. A ticket whose title does not match what the page
  says it does is described by its real scope (on #716, "API-6749" was
  the logs migration that the statistics need, not the statistics). When
  the tracker cannot be reached, build the links from a format found in
  the repository and say in the report they are unchecked.
- **Facts**: every figure (number of mails, delays, limits) comes from
  the code or the review guide at the pinned commit, and is stated as
  "X instead of Y" when it replaces something.

### 3. Write

Copy the skeleton, fill it, delete the sections that do not apply.

- **Plain language.** "Jeton", not JWT; "l'éditeur de logiciel", not the
  model name; no file, class or column names. A partial removal states
  what stays ("3 rappels au lieu de 6", not "plus de rappels").
- **The user's point of view first**: "Ce qui change pour l'usager"
  comes before anything about the team or the system.
- **"Ce que ça prépare"** shows the dependency between the next steps
  (A unlocks B) and the screens or mails that already serve them.
- **"Ce que ça change pour l'équipe"** gives sentences the support and
  bizdev can reuse as they are.
- **Decisions taken**, each with its reason in half a sentence; open
  points only when the audience must act on them.
- **No password** of another page in this one: link the review guide
  and say it is protected.

### 4. Check and publish

```bash
<skill>/scripts/check.sh ~/share/<slug>
```

It fails on a placeholder left from the skeleton, a missing local
image or video, a missing `noindex`, a video not forced to 2×, a local
path or a `#k=` password in the page. Then look at the page in a
browser at desktop width and at 400 px, as `static-page` says.

Publish with `upload-assets`, behind a new password while the feature
is unreleased; the slug is `<project>-<topic>-presentation`. Report the
direct link with `#k=`, the password, and what could not be included or
checked (unreachable tracker, media left out).
