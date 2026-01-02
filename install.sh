#!/usr/bin/env bash
#
# install.sh - Install dotfiles and dependencies
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Install dotfiles and setup development environment.

Options:
  -n, --dry-run    Show what would be done without making changes
  -h, --help       Show this help message

The installer will:
  1. Create symlinks for dotfiles
  2. Install Ruby version and ruby-lsp
  3. Install tmux and vim plugins
  4. Setup config files
EOF
  exit 0
}

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
dry() { $DRY_RUN && echo -e "${YELLOW}[DRY]${NC} Would: $*" && return 0 || return 1; }

backup_file() {
  local file="$1"
  if [[ -e "$file" && ! -L "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_path="$BACKUP_DIR/$(basename "$file")"
    if dry "backup $file to $backup_path"; then
      return
    fi
    cp -r "$file" "$backup_path"
    log "Backed up $file"
  fi
}

safe_symlink() {
  local source="$1"
  local target="$2"

  # Already correct symlink
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  # Backup existing file
  backup_file "$target"

  if dry "symlink $source -> $target"; then
    return
  fi

  rm -rf "$target"
  ln -s "$source" "$target"
  success "Linked $target"
}

safe_clone() {
  local repo="$1"
  local dest="$2"

  if [[ -d "$dest" ]]; then
    log "Already exists: $dest"
    return 0
  fi

  if dry "clone $repo to $dest"; then
    return
  fi

  git clone "$repo" "$dest"
  success "Cloned $repo"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

$DRY_RUN && warn "DRY RUN MODE - No changes will be made"

cd "$(dirname "$0")"
DOTFILES_DIR="$(pwd)"

log "Installing dotfiles from $DOTFILES_DIR"

# Step 1: Symlinks
log "Creating symlinks..."
./symlink.sh

# Step 2: Ruby
if command -v rbenv &> /dev/null; then
  if [[ -f ruby-version ]]; then
    RUBY_VERSION=$(cat ruby-version)
    if rbenv versions | grep -q "$RUBY_VERSION"; then
      log "Ruby $RUBY_VERSION already installed"
    else
      if ! dry "install Ruby $RUBY_VERSION"; then
        rbenv install "$RUBY_VERSION"
      fi
    fi
    if ! dry "set global Ruby to $RUBY_VERSION"; then
      rbenv global "$RUBY_VERSION"
    fi
  fi

  if ! gem list -i ruby-lsp &> /dev/null; then
    if ! dry "install ruby-lsp gem"; then
      gem install ruby-lsp
    fi
  else
    log "ruby-lsp already installed"
  fi
else
  warn "rbenv not found, skipping Ruby setup"
fi

# Step 3: Tmux plugins
safe_clone "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

# Step 4: Vim plugins
safe_clone "https://github.com/gmarik/vundle.git" "$HOME/.vim/bundle/vundle"

if ! dry "install vim plugins"; then
  nvim -u ~/.vimrc.bundles +BundleInstall +qa 2>/dev/null || true
fi

# Step 5: Neovim config
mkdir -p "$HOME/.config/nvim"
safe_symlink "$DOTFILES_DIR/config/coc-settings.json" "$HOME/.config/nvim/coc-settings.json"

# Step 6: Claude config
mkdir -p "$HOME/.claude"
if ! dry "copy Claude settings"; then
  cp -n claude/settings.json "$HOME/.claude/settings.json" 2>/dev/null || log "Claude settings exists"
  cp claude/statusline-command.sh "$HOME/.claude/statusline-command.sh"
fi

echo ""
success "Installation complete!"
[[ -d "$BACKUP_DIR" ]] && log "Backups saved to: $BACKUP_DIR"
