# Global Instructions

Be extremely concise. Sacrifice grammar for concision.

## Communication

- Respond in the same language as the user
- No emojis unless asked
- No unnecessary praise or filler
- Direct answers, skip preambles

## Code Style

- Atomic commits with clear messages
- Use `git mv` to preserve history
- All files end with newline
- No trailing whitespace
- No comments - use meaningful names instead

## Shell/Bash

- Shebang: `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Quote variables: `"$var"`
- Use `[[ ]]` over `[ ]`
- Support `--help` and `--dry-run`

## Ruby/Rails

- Follow RuboCop rules
- Use `frozen_string_literal`
- Interactors for business logic
- TDD: write tests first
- Run `rubocop` before finishing

## Testing

- Run only relevant tests, not full suite
- Ensure tests pass before moving on
- Use factories, not fixtures

## Git

- Imperative mood in commits
- One logical change per commit
- Never force push to main/master
