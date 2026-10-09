# Theming from the project's visual identity

Find the identity as described in the `static-page` skill, then set the
tokens at the top of `style.css`. The components (tabs, tables, callouts,
badges) are drawn by `style.css` itself, after the project's design
system.

## Tokens

| Token | Role |
|---|---|
| `--primary` | links, selected tab text and rule, footer rule |
| `--primary-hover` | callout rule |
| `--primary-light` | unselected tabs |
| `--primary-lighter` | tab hover, links set on code |
| `--font` | project font stack, always ending with system fallbacks |
| `--callout-bg` | neutral callout background |

Keep `--info`, `--good`, `--warning`, `--error` and the code colors as they
are unless they clash with the primary. The contrast to check is
`--primary` on white.

## Presets

DSFR (the official "République française" block is never reproduced, the
guide is a working document, not a State website):

```css
--font: Marianne, "Segoe UI", system-ui, -apple-system, sans-serif;
--primary: #000091;
--primary-hover: #6a6af4;
--primary-light: #e3e3fd;
--primary-lighter: #f5f5fe;
--callout-bg: #eeeeee;
```

Neutral: the defaults of `style.css`.
