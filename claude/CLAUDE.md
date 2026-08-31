# Global Instructions

Be extremely concise. Sacrifice grammar for concision.

## Communication

- Be brutally honest: if you think I'm wrong tell me
- Respond in the same language as the user
- No emojis unless asked
- No unnecessary praise or filler
- Direct answers, skip preambles

## Code Style

- Atomic commits with clear messages, prefer the why than the what
- Follow standard Git commit message formatting: imperative subject limited to
  50 characters, blank line before the body, body wrapped at 72 characters
- Use `git mv` to preserve history
- All files end with newline
- No trailing whitespace
- No comments - use meaningful names for variables/methods and commits messages instead
- Never commit files you didn't write nor edit: there is other agent's work
- Commit bodies should be explicit and detailed enough to understand the
  change without context. Don't hesitate to make them longer.
- When rebasing, double check of you did not drop anything
- When code is unclear/illogical, read its commit messages to understand
    context (title first, then description if needed)
- Never mention my name in commits: describe the change, not who asked for it

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

## Screenshots / screencasts

* When referencing, located within ~/share/screenshots/
  or ~/share/screencasts/
