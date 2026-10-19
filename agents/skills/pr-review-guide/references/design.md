# The Design tab

When the pull request changes an interface, the guide gets a "Design" tab,
right after the overview, written for the designer who will redraw the
screens. The reviewer reads the rest of the guide; the designer may read
only this tab, so it must stand on its own.

It carries content, not a new look: the page keeps the project's design
system set in `style.css`. A one-off page made for the designer (an
overview with its own palette and fonts) is a source of content to port
into this tab, never a style to copy.

## Structure

Above the sub-tabs, read first:

- **A callout** "Fonctionnel, design à reprendre" (or its equivalent in the
  guide's language): what the feature lets users do in two sentences, that
  the screens are the working version drawn without a mockup, and the
  expected deliverable named as the designer knows it (the file, the page
  and the section of their design tool, next to which existing section).
- **The flow** in `::: steps`, one step per moment of the user's journey,
  each a bold verb then one sentence.

Then five sub-tabs:

| Sub-tab | Holds |
| --- | --- |
| Écrans | Every screen of the PR, including those already shown in the end-to-end tab, each with a stable ID (E1, E2…) explained in one line at the top of the sub-tab. One `##` per moment of the flow, a sentence on what happens there, then a table `\| ID \| Écran \| Capture \|` whose ID cell is `[E4]{#e4}`, so `#e4` links straight to it. Every state worth drawing gets its own row: empty, error, not found, disabled, full. A closing line says what screenshots cannot show (animations, haptics, a state that only exists mid-gesture). |
| À redessiner | `::: cards`, one `::: card` per weak spot ranked by priority: the location as `[E4 · zone]{.where}`, the screen named by its ID, the element in bold, what is missing and what it should achieve. Then what the platform imposes (native components that can be tinted but not replaced without cost) and the constraints to keep, each with the reason found in the code or in a failure met while building. |
| Règles | The business rules the design must respect, as the code enforces them: limits, optional fields, who can do what, what disappears when. |
| États et textes | A table of every building block with where it appears and the states to cover, then every text the user sees, copied from the code, grouped by block. |
| Tokens | The project's typography and colours with their values, each table linking the design-system file at the pinned commit. |

## Collecting

- **Screenshots of the real app**: reuse those the UI tests already attach
  (export them from each worker's result bundle, the attachments are spread
  across workers), and add a temporary UI test for the missing states (not
  found, empty list, first item selected, empty form). Delete the test and
  restore the project file afterwards, and check the worktree is clean.
- **Look at each screenshot** before using it: it shows what the designer
  will be judged against, and often a defect worth a card in "À redessiner"
  (a system default colour, a cramped layout, a broken line).
- **Texts**: grep the views for user-visible strings (button labels,
  alerts, empty states, counters with their plural forms, web locales),
  never type them from memory.
- **Tokens**: read them from the design-system files (typography, colour
  assets, CSS custom properties), with the role each one plays in the
  screens shown.

## Rendering

- `build.py` does not turn an image into a figure: write the title as a
  bold paragraph right under the image, `style.css` styles it as the
  caption title.
- Keep galleries to real screenshots resized to about 900 px on their long
  side; crop web pages to the block discussed, a sticky bar can be its own
  shot.
- Check the tab at desktop width and around 400 px: galleries wrap to one
  or two columns.
