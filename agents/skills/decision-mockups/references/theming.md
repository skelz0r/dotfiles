# Theming from the project's visual identity

The mockups never load a UI framework (no DSFR, Bootstrap or Tailwind CSS
file, no CDN): they must open from `file://`, survive an upload to a static
host, and stay readable in five years. The project's identity is carried by
the tokens at the top of `style.css` and by the header of each actor.

## 1. Find the identity

Look, in this order, and stop at the first conclusive source:

1. **DSFR (French government)**: `@gouvfr/dsfr` in `package.json`,
   `dsfr-view-components` or `dsfr-form_builder` in a `Gemfile`, `fr-`
   prefixed classes in views, a `.gouv.fr` domain in the config or README.
   Use the DSFR preset below.
2. **Tailwind**: `tailwind.config.*` (`theme.extend.colors`) or a CSS file
   with `@theme { --color-* }`.
3. **CSS custom properties**: `grep -rhoE -- '--(color-)?(primary|brand|main)[a-z-]*: *#[0-9a-fA-F]{3,8}'`
   over `app/assets`, `app/frontend`, `app/javascript`, `src/styles`,
   `public/`.
4. **SCSS variables**: `$primary`, `$brand-*`, `$color-*`.
5. **Logo and product name**: the main layout (`app/views/layouts/*`,
   `src/components/Header*`) gives the name and the tagline to put in
   `ACTORS`.

Nothing conclusive: ask the user for a primary color, or keep the neutral
defaults already in `style.css`. The actor that is not the project (a
partner service, a third party) gets its own real color if known, else the
`primary`, `dark` or `alt` header style: the only goal is to tell actors
apart.

## 2. Map to tokens

| Token | Role |
|---|---|
| `--primary` | buttons, card title rule, filled headers, footer rule |
| `--primary-hover` | button hover, a bit lighter or more saturated |
| `--primary-dark` | "you are on" strip above a filled header |
| `--primary-light` / `--primary-lighter` | prefilled inputs, table header |
| `--on-primary` | text on `--primary` (white unless the primary is light) |
| `--font` | project font stack, always ending with system fallbacks |

Keep `--good`, `--weak` and `--info` as they are unless they clash with the
primary: annotations must read the same across every project. Check
contrast of `--on-primary` on `--primary` (WCAG AA, 4.5:1).

## Presets

DSFR (Marianne font is not embedded: the fallback stack is enough):

```css
--font: Marianne, "Segoe UI", system-ui, -apple-system, sans-serif;
--primary: #000091;
--primary-hover: #1212ff;
--primary-dark: #000074;
--primary-light: #e3e3fd;
--primary-lighter: #f5f5fe;
--danger: #e1000f;
```

DSFR header block, to set as `LOGO` in `build.py`:

```html
<div class="logo">République<br>Française<em>Liberté · Égalité · Fraternité</em></div>
```

Neutral: the defaults of `style.css`.
