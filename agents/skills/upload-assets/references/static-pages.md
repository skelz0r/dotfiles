# Static pages published on assets

Shared by the skills that generate a static HTML page from a source file
and a build script, then publish it here (`pr-review-guide`,
`decision-mockups`). Each skill keeps its own content rules, components and
token roles; what follows is the same for all of them.

## Principles

- **Pure HTML and CSS.** No UI framework (DSFR, Bootstrap, Tailwind file),
  no CDN, no web font, no script beyond what the page strictly needs. The
  page opens from disk, survives an upload to any static host and stays
  readable in five years.
- **One source, one build.** The source (markdown or `build.py`) is the
  only file ever edited; generated HTML is overwritten on each build and
  never touched by hand. The build prints its warnings and must end with
  zero.
- **`noindex`.** Every generated page carries
  `<meta name="robots" content="noindex">`; the server also sends
  `X-Robots-Tag`, the meta keeps it true on any other host.
- **The project's look, not its branding.** Colors and components follow
  the project's design system. Official blocks and logos (the "République
  française" block, a partner's logo) are only drawn when the page mimics
  the product itself, never on a working document about it.

## Where the files live

```bash
mkdir -p ~/share/<slug>
cp <skill>/assets/<files> ~/share/<slug>/
ln -s ~/share/<slug> <working-dir>/<gitignored-dir>/<name>
```

Real files in `~/share`, symlink from a gitignored directory of the project
(e.g. `sandbox/<topic>/`), never the other way round: the link must keep
working on another machine.

## Finding the project's identity

Look, in this order, and stop at the first conclusive source:

1. **DSFR (French government)**: `@gouvfr/dsfr` in `package.json`,
   `dsfr-view-components` or `dsfr-form_builder` in a `Gemfile`, `fr-`
   prefixed classes in views, a `.gouv.fr` domain in the config or README.
   Use the skill's DSFR preset.
2. **Tailwind**: `tailwind.config.*` (`theme.extend.colors`) or a CSS file
   with `@theme { --color-* }`.
3. **CSS custom properties**:
   `grep -rhoE -- '--(color-)?(primary|brand|main)[a-z-]*: *#[0-9a-fA-F]{3,8}'`
   over `app/assets`, `app/frontend`, `app/javascript`, `src/styles`,
   `public/`.
4. **SCSS variables**: `$primary`, `$brand-*`, `$color-*`.

Nothing conclusive: ask the user for a primary color, or keep the neutral
defaults of the skill's `style.css`. Then set the tokens at the top of
`style.css` following the skill's own token table, keep the semantic
colors (info, good, warning) unless they clash with the primary so they
read the same across projects, and check the contrast of text on the
primary (WCAG AA, 4.5:1). Marianne and other project fonts are not
embedded: the fallback stack is enough.

## Looking at the result

`file://` URLs are rejected by agent-browser: serve the folder.

```bash
cd ~/share/<slug> && python3 -m http.server 8765
agent-browser set viewport 1440 1000
agent-browser open "http://localhost:8765/?v=1"
agent-browser screenshot --full desktop.png
agent-browser set viewport 400 900
agent-browser screenshot --full mobile.png
```

Every page or tab, at desktop width and at ~400px. Reload with a new query
string (`?v=2`) after each build to dodge the cache.

## Publishing

Through the `upload-assets` skill, into a folder named after the slug
unless the user picks another one:

- **Exclude the sources**: `--except` the source file, `build.py` and any
  notes file, so only what the page needs goes online.
- **Last check before the upload**: no personal data, token, internal URL
  or real identity left in the page.
- Give the URL, then offer the next step of the skill (e.g. link it from
  the PR description).

To iterate, edit the source, rebuild and republish to the same folder.
