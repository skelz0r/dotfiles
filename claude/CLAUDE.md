# Global Instructions

Be extremely concise. Sacrifice grammar for concision.

## Communication

- Be brutally honest: if you think I'm wrong tell me
- Respond in the same language as the user
- No emojis unless asked
- No unnecessary praise or filler
- Direct answers, skip preambles

## Tickets / issues comments

- Comments on Linear/GitHub issues follow the same style as commits and PR
  descriptions: short prose paragraphs, conclusions first, only the key
  facts (ids, volumes, link to the PR)
- No headings, tables, bold or checklists: must not look AI-generated

## Code Style

- All files end with newline
- No trailing whitespace
- No comments - use meaningful names for variables/methods and commits messages instead

## Git

- Write commit messages in the repository's own language: read `git log`
  before writing to know whether it is French or English
- Atomic commits with clear messages, prefer the why than the what
- Standard Git commit message formatting: imperative subject limited to
  50 characters, blank line before the body, body wrapped at 72 characters
- Commit bodies should be explicit and detailed enough to understand the
  change without context, but stay short when the change is simple: go
  into detail only when the why is complicated or not visible in the code
- Never mention my name in commits: describe the change, not who asked for it
- Never commit files you didn't write nor edit: there is other agent's work
- Use `git mv` to preserve history
- When rebasing, double check of you did not drop anything
- When code is unclear/illogical, read its commit messages to understand
    context (title first, then description if needed)

## Pull Requests

- Single-commit PR: reuse the commit message as the description, verbatim
- Otherwise, PR description = compact summary of the commits, not a
  re-explanation of each
- Bullet points only when the branch holds distinct logical groups of commits
  (e.g. an unrelated doc commit alongside the feature); otherwise prose

## Ruby

- Ban `is_a?` and `respond_to?` — prefer duck typing (e.g. `[*values] == values` instead of `values.is_a?(Array)`)

## Testing

- Run only relevant tests, not full suite
- Ensure tests pass before moving on
- Use TDD where possible

## Secrets

- Never read files under any `secrets/` directory (any depth), regardless of
  extension or how the read is performed (Read tool, `cat`, `grep`, `xxd`,
  piping, shell expansion, `find -exec`, etc.). Treat their contents as
  unknown.
- Never run `git-crypt unlock`, `git-crypt export-key`, or any command that
  would reveal the git-crypt key.
- Writing new files under `secrets/` is allowed (scaffolding with
  placeholders), but never read them back.

## herdr / tmux

- "Tab" means herdr tab or tmux window, not pane; herdr when
  `HERDR_ENV=1`, else tmux when `$TMUX` is set
- Rename the one Claude runs in, never the one the client displays:
  `herdr tab rename "$HERDR_TAB_ID" <name>` or
  `tmux rename-window -t "$TMUX_PANE" <name>`
- Every new development topic goes through `/start`: dedicated worktree,
  tab and fresh session; never work in the main checkout nor in the
  current session

## Screenshots / screencasts

* When referencing, located within ~/share/screenshots/
  or ~/share/screencasts/
* To attach images to a GitHub issue or PR, upload them with the
  `upload-assets` skill into the `gh` folder, named
  `<project>-{issue,pr}-<id>-<name>.png` (e.g.
  `superdocu-pr-1990-portal.png`), then embed the resulting URLs
