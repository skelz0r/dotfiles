---
name: ui-variants
description: Draw 3 to 5 variants of one screen or one element of an app on a single static HTML page, halfway between mockup and real design, using the project's real compiled CSS, fonts and icons and the classes of its real views, without running the app's server; the current screen comes first as reference, each variant with a one-line pitch and pros / cons. Use when the user says "fais des variantes".
---

# UI variants

One page that puts several variants of the same screen side by side,
rendered with the app's own compiled CSS, so the user can feel each one
without a server, a branch or a designer. Not a wireframe (decision-mockups
draws walkthroughs with tokens to settle a decision), not a PR guide.

Reference example: `~/share/superdocu-contacts-trash-cta/` (where to put
the contacts trash button, five variants, Rails + Tailwind).

Read the `static-page` skill first: where the files live, how to look at
the page and publish it. This skill overrides two of its principles, on
purpose, because the page mimics the product: "Pure HTML and CSS" (the
project's compiled CSS framework file is embedded) and "no web font" (the
project's fonts are embedded). Both are copied next to the page, never
loaded from a CDN or from the app.

## Output

```
~/share/<slug>/
  build.py      the only file ever edited, from assets/build.py
  app.css       copied from the project by the build, URLs rewritten
  fonts/        copied from the project by the build
  index.html    generated
```

## Workflow

### 1. Frame

From the conversation: the screen or element, the problem in two
sentences, what is fictitious in the drawings (a counter not built yet,
fake rows). 3 to 5 variants unless the user gave a number, plus
**Actuel** first as reference (only cons, when it has any), left out only
when the screen does not exist yet. The page language is the product's.

### 2. Find the real assets

| Need | Where to look |
|---|---|
| Compiled CSS | committed build: `app/assets/builds/*.css`, `public/assets/*.css`, `dist/` |
| No committed build | run the project's CSS build alone, no server (`bin/rails tailwindcss:build`, `npm run build:css`, `vite build`); else `curl` the stylesheet of staging, then production; else stop and ask, never fall back to tokens |
| Fonts | `@font-face` in the compiled CSS gives the URLs; files in `public/fonts`, `app/assets/fonts`, `node_modules/<font>/files` |
| Icons | the SVGs the views render: `app/assets/svg/icons/<set>/`, `app/assets/images/icons/`, an icon gem (`bundle exec gem contents <gem>`), `node_modules/heroicons` or `lucide-static` |
| DSFR | `@gouvfr/dsfr/dist` (in `node_modules` or vendored): `dsfr.min.css`, `fonts/` (Marianne), `icons/` referenced by the CSS, plus the project's own CSS; markup from the `dsfr-skill` |

Fill the constants at the top of `build.py`: `PROJECT`, `CSS_SOURCES`,
`URL_REWRITES` (absolute URLs of the CSS made relative, e.g.
`url(/fonts/` to `url(fonts/`), `ASSET_DIRS`, `ICON_PATH`.

### 3. Copy the real markup

Read the views and components that render the screen and copy their
classes into small Python functions (`header()`, `table()`, `screen()`…)
drawing a reduced screen: the zone around the element and enough context
to judge it (3 fake rows, not 25). Change only what the variant changes.

The compiled CSS is purged: only classes the app already uses exist
(`btn light` may exist and `btn ghost` not). Take statuses and modifiers
from the code (`to_validate`, not a guessed `pending_validation`). What
the app lacks goes into `PAGE_STYLE`.

### 4. Build

```bash
cp <skill>/assets/build.py ~/share/<slug>/
python3 ~/share/<slug>/build.py
```

The build fails while a class of the page exists neither in the compiled
CSS nor in `PAGE_STYLE`. A failure means a typo or a class the app does
not have: fix the markup. `UNSTYLED` is only for classes copied from the
real markup that no CSS styles (JS hooks), after checking them with grep
in the views.

The template is assembled by marker replacement: keep it that way, a `%`
or `{}` in CSS breaks `%` and `format` templates. The app's reset
restyles bare `h1`, `h2`, `p`: prefix the page's own selectors with
`.page`.

### 5. Look

`static-page`'s "Looking at the result", at 1440 and 400 px, on a free
port (another session may hold a fixed one and serve another page: check
`document.title`). At both widths
`document.documentElement.scrollWidth` equals `innerWidth`, and
`document.fonts.check('16px "<Font>"')` is true.

### 6. Publish and answer

Publish with `static-page`, behind a password while the feature is
unreleased. The page stays neutral: give the recommendation, and why, in
the answer only.
