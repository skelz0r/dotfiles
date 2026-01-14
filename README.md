# skelz0r dotfiles

Personal dotfiles for macOS/Linux with zsh, vim, git, tmux, and pry.
Optimized for Rails development with lazy-loaded version managers.

## Quick Start

```sh
git clone https://github.com/skelz0r/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run  # Preview changes
./install.sh            # Install
```

## Requirements

- **zsh** as login shell: `chsh -s $(which zsh)`
- **Homebrew** (macOS) or equivalent package manager

## Installation

```sh
./install.sh [OPTIONS]

Options:
  -n, --dry-run    Preview changes without applying
  -h, --help       Show help
```

The installer:
1. Creates symlinks for dotfiles in `$HOME`
2. Installs Ruby via rbenv + ruby-lsp
3. Clones tmux/vim plugin managers
4. Sets up SSH and Claude configs

**Backups**: Existing files are saved to `~/.dotfiles_backup/YYYYMMDD_HHMMSS/`

## What's Included

### Shell (zsh)
- Git branch in prompt
- **Lazy loading** for nvm/rbenv/pyenv (faster startup)
- Common aliases: `g`, `b`, `v`, `mcd`, `tat`

### Vim/Neovim
- [vim-rails](https://github.com/tpope/vim-rails) - Rails navigation
- [coc.nvim](https://github.com/neoclide/coc.nvim) - LSP support
- [copilot.vim](https://github.com/github/copilot.vim) - GitHub Copilot
- 40+ plugins via [Vundle](https://github.com/gmarik/vundle)

### Tmux
- Prefix: `Ctrl+a`
- [TPM](https://github.com/tmux-plugins/tpm) for plugins
- Battery indicator in status bar

### Git
- Useful aliases (`lg`, `tree`, `pod`, `pf`)
- GPG signing ready

### SSH
- Secure defaults (ed25519, strong ciphers)
- Connection multiplexing
- Pre-configured for GitHub/GitLab

## Customization

Add your customizations **above** the line `DO NOT EDIT BELOW THIS LINE`.

Example `~/.gitconfig`:
```gitconfig
[user]
  name = Your Name
  email = you@example.com

# DO NOT EDIT BELOW THIS LINE
[color]
  diff = auto
```

Local overrides (not synced):
- `~/.zshrc.local` - Shell customizations
- `~/.vimrc.local` - Vim customizations
- `~/.aliases` - Custom aliases

## Utility Scripts

| Script | Description |
|--------|-------------|
| `migration` | Sync folders between machines (rsync) |
| `dotfiles-health` | Check dependencies and configuration |
| `dotfiles-diff` | Compare local vs repo dotfiles |
| `kill_port <port>` | Kill process on port |
| `tat` | Attach to tmux session (named after directory) |
| `wt <name>` | Create git worktree with branch |
| `encrypt_folder <dir>` | GPG encrypt a folder |
| `flushdns` | Flush DNS cache (macOS/Linux) |
| `battery` | Show battery level for tmux |
| `stunnel [port]` | SSH tunnel to Mac Studio (default: 3000) |
| `stunnel-ss [port]` | Screen Sharing tunnel (default: 5900) |

### Migration Script

Sync dotfiles and documents to a new machine:

```sh
# Push to remote
migration --local user@newmac.local

# Pull from remote
migration --pull user@oldmac.local

# Preview only
migration --dry-run --local user@newmac.local
```

Configure folders in `~/.migration.conf`:
```sh
FOLDERS=(
  "$HOME/Documents"
  "$HOME/Projects"
  "$HOME/.ssh"
)
```

### Health Check

```sh
dotfiles-health        # Full check
dotfiles-health -q     # Errors/warnings only
```

Checks: git, zsh, nvim, tmux, rbenv, pyenv, nvm, symlinks, SSH, GPG

## Directory Structure

```
dotfiles/
├── bin/                 # Utility scripts
├── zsh/
│   ├── completion/      # Shell completions
│   └── functions/       # Shell functions (lazy-load, etc.)
├── vim/
│   ├── bundle/          # Vundle plugins (git-ignored)
│   └── colors/          # Color schemes
├── config/              # App configs (coc-settings.json)
├── claude/              # Claude Code commands
├── zshrc, vimrc, ...    # Dotfiles
├── ssh_config           # SSH configuration
├── install.sh           # Installer
└── symlink.sh           # Symlink creator
```

## Version Managers

Lazy-loaded for fast shell startup:

| Manager | Commands |
|---------|----------|
| **rbenv** | `ruby`, `gem`, `bundle`, `rails`, `rake`, `rspec` |
| **nvm** | `node`, `npm`, `npx`, `yarn`, `pnpm` |
| **pyenv** | `python`, `pip` |

First invocation loads the manager, subsequent calls are direct.

## Updating

```sh
cd ~/dotfiles
git pull
./install.sh
```

Check for drift:
```sh
dotfiles-diff -a        # Check all files
dotfiles-diff -v zshrc  # Show diff for specific file
```

## Credits

Inspired by [thoughtbot's dotfiles](https://github.com/thoughtbot/dotfiles)

## License

Free software under [LICENSE](LICENSE).