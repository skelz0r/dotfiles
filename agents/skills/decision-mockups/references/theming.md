# Theming from the project's visual identity

Find the identity as described in the `upload-assets` skill's
`references/static-pages.md`, then set the tokens at the top of
`style.css` and the header of each actor.

The main layout (`app/views/layouts/*`, `src/components/Header*`) also
gives the product name and tagline to put in `ACTORS`. The actor that is
not the project (a partner service, a third party) gets its own real color
if known, else the `primary`, `dark` or `alt` header style: the only goal is
to tell actors apart.

## Tokens

| Token | Role |
|---|---|
| `--primary` | buttons, card title rule, filled headers, footer rule |
| `--primary-hover` | button hover, a bit lighter or more saturated |
| `--primary-dark` | "you are on" strip above a filled header |
| `--primary-light` / `--primary-lighter` | prefilled inputs, table header |
| `--on-primary` | text on `--primary` (white unless the primary is light) |
| `--font` | project font stack, always ending with system fallbacks |

Keep `--good`, `--weak` and `--info` as they are unless they clash with the
primary: annotations must read the same across every project. The contrast
to check is `--on-primary` on `--primary`.

## Presets

DSFR:

```css
--font: Marianne, "Segoe UI", system-ui, -apple-system, sans-serif;
--primary: #000091;
--primary-hover: #1212ff;
--primary-dark: #000074;
--primary-light: #e3e3fd;
--primary-lighter: #f5f5fe;
--danger: #e1000f;
```

DSFR header block, to set as `LOGO` in `build.py` (the mockups mimic the
product, its header is part of it):

```html
<div class="logo">République<br>Française<em>Liberté · Égalité · Fraternité</em></div>
```

Neutral: the defaults of `style.css`.
