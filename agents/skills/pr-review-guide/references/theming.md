# Theming from the project's visual identity

The guide never loads a UI framework (no DSFR, Bootstrap or Tailwind file,
no CDN, no web font): it must open from `file://`, survive an upload to a
static host and stay readable in five years. The project's identity is
carried by the tokens at the top of `style.css`; the components (tabs,
tables, callouts, badges) are drawn by `style.css` itself, after the
project's design system.

## 1. Find the identity

Look, in this order, and stop at the first conclusive source:

1. **DSFR (French government)**: `@gouvfr/dsfr` in `package.json`,
   `dsfr-view-components` or `dsfr-form_builder` in a `Gemfile`, `fr-`
   prefixed classes in views, a `.gouv.fr` domain. Use the DSFR preset.
2. **Tailwind**: `tailwind.config.*` (`theme.extend.colors`) or a CSS file
   with `@theme { --color-* }`.
3. **CSS custom properties**:
   `grep -rhoE -- '--(color-)?(primary|brand|main)[a-z-]*: *#[0-9a-fA-F]{3,8}'`
   over `app/assets`, `app/frontend`, `app/javascript`, `src/styles`, `public/`.
4. **SCSS variables**: `$primary`, `$brand-*`, `$color-*`.

Nothing conclusive: ask for a primary color, or keep the neutral defaults.

## 2. Map to tokens

| Token | Role |
|---|---|
| `--primary` | links, selected tab text and rule, footer rule |
| `--primary-hover` | callout rule |
| `--primary-light` | unselected tabs |
| `--primary-lighter` | tab hover, links set on code |
| `--font` | project font stack, always ending with system fallbacks |
| `--callout-bg` | neutral callout background |

Keep `--info`, `--good`, `--warning`, `--error` and the code colors as they
are unless they clash with the primary: badges and callouts must read the
same across projects. Check the contrast of `--primary` on white (WCAG AA,
4.5:1).

## Presets

DSFR (Marianne is not embedded: the fallback stack is enough; the official
"République française" block is never reproduced, the guide is a working
document, not a State website):

```css
--font: Marianne, "Segoe UI", system-ui, -apple-system, sans-serif;
--primary: #000091;
--primary-hover: #6a6af4;
--primary-light: #e3e3fd;
--primary-lighter: #f5f5fe;
--callout-bg: #eeeeee;
```

Neutral: the defaults of `style.css`.
