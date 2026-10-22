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
  3. Install vim plugins and compile coc.nvim
  4. Setup neovim config
  5. Setup config files (SSH, Claude, Codex, GPG)
  6. Install Claude managed-settings to system location
  7. Optionally install Syncthing for folder sync
EOF
  exit 0
}

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
dry() { $DRY_RUN && echo -e "${YELLOW}[DRY]${NC} Would: $*" && return 0 || return 1; }

ensure_dir() {
  local dir="$1"
  local mode="${2:-}"

  if [[ ! -d "$dir" ]]; then
    if dry "create directory $dir"; then
      return
    fi
    mkdir -p "$dir"
  fi
  if [[ -n "$mode" ]] && ! dry "chmod $mode $dir"; then
    chmod "$mode" "$dir"
  fi
}

backup_file() {
  local file="$1"
  if [[ -e "$file" && ! -L "$file" ]]; then
    local backup_path
    backup_path="$BACKUP_DIR/$(basename "$file")"
    if dry "backup $file to $backup_path"; then
      return
    fi
    mkdir -p "$BACKUP_DIR"
    cp -R "$file" "$backup_path"
    log "Backed up $file"
  fi
}

refuse_inside_dotfiles() {
  local target="$1"
  local parent

  [[ -e "$target" ]] || return 0
  parent="$(cd -P "$(dirname "$target")" && pwd)"
  if [[ "$parent" == "$DOTFILES_DIR" || "$parent" == "$DOTFILES_DIR"/* ]]; then
    error "Refusing to replace $target: it resolves inside the dotfiles repository ($parent)"
    exit 1
  fi
}

safe_symlink() {
  local source="$1"
  local target="$2"

  # Already correct symlink, or the same file reached through a linked parent
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]] || [[ "$target" -ef "$source" ]]; then
    return 0
  fi

  refuse_inside_dotfiles "$target"

  # Backup existing file
  backup_file "$target"

  if dry "symlink $source -> $target"; then
    return
  fi

  rm -rf "$target"
  ln -s "$source" "$target"
  success "Linked $target"
}

copy_file() {
  local source="$1"
  local target="$2"

  if [[ "$target" -ef "$source" ]]; then
    return 0
  fi

  if dry "copy $source to $target"; then
    return
  fi

  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"
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
if $DRY_RUN; then
  ./symlink.sh --dry-run
else
  ./symlink.sh
fi

# Step 2: Ruby
if command -v rbenv &> /dev/null; then
  if [[ -f ruby-version ]]; then
    RUBY_VERSION=$(cat ruby-version)
    if rbenv prefix "$RUBY_VERSION" &> /dev/null; then
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

# Step 3: Vim plugins
safe_clone "https://github.com/gmarik/vundle.git" "$HOME/.vim/bundle/vundle"

if ! dry "install vim plugins"; then
  nvim -u ~/.vimrc.bundles +BundleInstall +qa 2>/dev/null || true
fi

# Step 4: Neovim config
ensure_dir "$HOME/.config/nvim"
safe_symlink "$DOTFILES_DIR/config/coc-settings.json" "$HOME/.config/nvim/coc-settings.json"

# Herdr config
ensure_dir "$HOME/.config/herdr"
safe_symlink "$DOTFILES_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"

# Create init.vim to source vimrc
NVIM_INIT="$HOME/.config/nvim/init.vim"
if [[ ! -f "$NVIM_INIT" ]]; then
  if ! dry "create $NVIM_INIT"; then
    cat > "$NVIM_INIT" << 'EOF'
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOF
    success "Created nvim init.vim"
  fi
fi

# Compile coc.nvim
if [[ -d "$HOME/.vim/bundle/coc.nvim" ]]; then
  if ! dry "compile coc.nvim"; then
    cd "$HOME/.vim/bundle/coc.nvim"
    if command -v npm &> /dev/null; then
      npm ci &> /dev/null || warn "Failed to compile coc.nvim"
      success "Compiled coc.nvim"
    else
      warn "npm not found, skipping coc.nvim compilation"
    fi
    cd "$DOTFILES_DIR"
  fi
fi

# Step 5: SSH config
ensure_dir "$HOME/.ssh" 700
ensure_dir "$HOME/.ssh/sockets" 700
if [[ ! -f "$HOME/.ssh/config" ]]; then
  safe_symlink "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config"
else
  log "SSH config exists, skipping (manual merge may be needed)"
fi

# Step 6: Claude config
log "Installing Claude config files..."
while IFS= read -r file; do
  copy_file "$DOTFILES_DIR/$file" "$HOME/.${file}"
done < <(git ls-files claude/commands/)

safe_symlink "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
safe_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
safe_symlink "$DOTFILES_DIR/claude/managed-settings.json" "$HOME/.claude/managed-settings.json"

# Install managed-settings.json to system location
if ! dry "install managed-settings.json to /Library/Application Support/ClaudeCode/"; then
  sudo mkdir -p "/Library/Application Support/ClaudeCode"
  sudo ln -sf "$DOTFILES_DIR/claude/managed-settings.json" "/Library/Application Support/ClaudeCode/managed-settings.json"
fi

success "Claude config installed"

# Step 6b: Codex config
log "Installing Codex config files..."
ensure_dir "$HOME/.codex"
safe_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"
success "Codex config installed"

# Step 6c: Agents skills
log "Installing agents skills..."
ensure_dir "$HOME/.agents/skills"
for skill_dir in "$DOTFILES_DIR"/agents/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  safe_symlink "$skill_dir" "$HOME/.agents/skills/$skill_name"
done
safe_symlink "$HOME/.agents/skills" "$HOME/.claude/skills"
safe_symlink "$DOTFILES_DIR/agents/skill-lock.json" "$HOME/.agents/.skill-lock.json"
success "Agents skills installed"

# Step 6d: Third-party skills locked in agents/skill-lock.json, installed
# only when missing: updates stay a reviewed `npx skills update`
if command -v npx &> /dev/null && command -v jq &> /dev/null; then
  while IFS=$'\t' read -r skill_name source_url; do
    [[ -e "$HOME/.agents/skills/$skill_name" ]] && continue
    if dry "install skill $skill_name from $source_url"; then
      continue
    fi
    log "Installing skill $skill_name..."
    npx -y skills add "$source_url" --skill "$skill_name" --global --agent claude-code -y > /dev/null \
      || warn "Failed to install skill $skill_name"
  done < <(jq -r '.skills | to_entries[] | [.key, .value.sourceUrl] | @tsv' "$DOTFILES_DIR/agents/skill-lock.json")
else
  warn "npx or jq missing, third-party skills not installed"
fi

# Step 7: GPG config
ensure_dir "$HOME/.gnupg" 700
safe_symlink "$DOTFILES_DIR/gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
if ! dry "restart gpg-agent"; then
  gpgconf --kill gpg-agent 2>/dev/null || true
fi

# Step 8: Syncthing (optional)
if ! $DRY_RUN && ! command -v syncthing &> /dev/null; then
  echo ""
  read -p "Install Syncthing for folder sync? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Installing Syncthing..."
    brew install syncthing
    brew services start syncthing
    success "Syncthing installed. Run 'sync-setup' to configure."
  fi
fi

echo ""
success "Installation complete!"
if [[ -d "$BACKUP_DIR" ]]; then
  log "Backups saved to: $BACKUP_DIR"
fi
