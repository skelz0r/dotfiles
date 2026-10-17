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

## Checks

Rules below are enforced by a check: a refusal means fix the cause,
never bypass it (`--no-verify`). Prose stays only for what the check
cannot see.

| Rule | Enforced by | Still prose |
|---|---|---|
| Final newline, no trailing whitespace | git `pre-commit` in `~/dotfiles/git-hooks`, on staged changes | - |
| Commit subject <= 50, blank line, body <= 72 | git `commit-msg` in `~/dotfiles/git-hooks` | imperative mood, repository's language |
| No read under `secrets/`, no `git-crypt unlock`/`export-key` | Claude Code PreToolUse hook `~/dotfiles/claude/hooks/block-secrets.sh` (not Codex) | Secrets section: scripts, recursive greps, globs |
| No `is_a?` / `respond_to?` | RuboCop cop `config/rubocop/duck_typing.rb` of dotfiles, only where copied | Ruby section |

## Code Style

- No comments - use meaningful names for variables/methods and commits messages instead

## Git

- Write commit messages in the repository's own language: read `git log`
  before writing to know whether it is French or English
- Atomic commits with clear messages, prefer the why than the what
- Imperative subject
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

- Internal tooling (skills, commands, CLAUDE.md, agent config, personal
  dotfiles scripts), never code shipped to clients: once verified it
  works, rebase on the default branch and push directly, without PR nor
  review
- PR description written for the human reviewer first: a TL;DR on top,
  readable in 90 seconds, at most ~1,500 characters
- Single-commit PR: the commit message is the TL;DR, verbatim
- Otherwise, the TL;DR is a compact summary of the commits, not a
  re-explanation of each
- Bullet points only when the branch holds distinct logical groups of commits
  (e.g. an unrelated doc commit alongside the feature); otherwise prose
- Context an agent picking up the PR would need and that does not fit the
  TL;DR (business constraints, edge cases, rejected alternatives) goes
  below in a collapsed `<details><summary>Context</summary>` block: never
  drop a constraint to fit the cap

## Ruby

- Ban `is_a?` and `respond_to?` — prefer duck typing (e.g. `[*values] == values` instead of `values.is_a?(Array)`)

## Testing

- Run only relevant tests, not full suite
- Ensure tests pass before moving on
- Do not write tests by default: a test written from your own reading
  of the intent is no more trustworthy than the code it checks
- Write a test only when it encodes intent from outside the code:
  - a reproduced bug, from the report, before the fix
  - an end-to-end user flow
  - a public contract (API, CLI, file format) consumed by others
  - cases I gave in the ticket, the plan or the conversation
- When a bug would be costly or irreversible (money, access, data
  loss or exposure, outbound actions) or would go unnoticed (background
  jobs, concurrency, time and expiry, limits, state transitions),
  cover it and make the chosen cases reviewable:
  - test descriptions are business statements, readable as a spec
  - the commit body lists covered cases and those deliberately left
    untested, with why
  - the final summary flags them as needing my validation
- Test behaviour through the public boundary (use case, endpoint,
  CLI command, public API of a module), never internal steps: a test
  must survive refactoring the internals
- Mock only what crosses the system boundary (network, third-party
  services, clock), never internal collaborators
- When an existing test breaks without any intended behaviour change,
  tell me whether the test or the code is wrong, never silently adapt
  the test
- Do not repair a breaking test that only mirrors the implementation:
  propose deleting it

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

## Shared HTML pages

- Any HTML page meant for someone else (PR overview, report, demo,
  presentation) is built with the `static-page` skill and published
  with `upload-assets` on assets.delmai.re, never as a claude.ai
  Artifact: the URL is what gets shared
- Unreleased feature: publish behind a password

## Screenshots / screencasts

* When referencing, located within ~/share/screenshots/
  or ~/share/screencasts/
* To attach images or videos to a GitHub issue, PR or comment, use
  the `gh-image` skill (native `gh --attach`), not `upload-assets`
