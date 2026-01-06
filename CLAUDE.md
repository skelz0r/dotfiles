# Development Guidelines

## Commands

- Install dotfiles: `./install.sh`
- Preview install: `./install.sh --dry-run`
- Health check: `dotfiles-health`
- Compare with local: `dotfiles-diff`
- Sync to new machine: `migration --local user@host`

## Code Style

- Shebang: `#!/usr/bin/env bash` for all shell scripts
- Use `set -euo pipefail` in scripts
- All scripts must have `--help` / `-h` option
- Use functions for reusable logic
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` instead of `[ ]` for tests
- Use `$(command)` instead of backticks
- Prefer `$HOME` over `~` in scripts
- All files must end with a newline
- No trailing whitespace

## Shell Scripts Guidelines

- Add colors for user-facing output (use RED/GREEN/YELLOW/BLUE)
- Support `--dry-run` for destructive operations
- Validate inputs before processing
- Cross-platform: support both macOS and Linux when possible
- Use `command -v` to check for command existence

## Zsh Configuration

- Keep startup fast: lazy-load heavy tools (nvm, pyenv, rbenv)
- Cache prompt info per directory change, not per prompt
- Use `typeset -U path` to avoid PATH duplicates
- Local customizations go in `*.local` files

## Vim Configuration

- Plugins managed via Vundle
- LSP via coc.nvim
- Local customizations in `~/.vimrc.local`

## Git

- Use `git mv` when moving files to preserve history
- Atomic commits: one logical change per commit
- Commit message format: imperative mood, concise summary

## Testing Changes

Before committing:
1. Open new terminal to test zsh config
2. Run `dotfiles-health` to verify dependencies
3. Run `dotfiles-diff` to review changes
