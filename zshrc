eval "$(/opt/homebrew/bin/brew shellenv)"

export LANG=en_US.UTF-8

# Colors
autoload -U colors && colors
export CLICOLOR=1

# Fast git branch (cached per directory change)
_git_branch_cache=""
_git_branch_pwd=""

git_prompt_info() {
  [[ "$PWD" != "$_git_branch_pwd" ]] && {
    _git_branch_pwd="$PWD"
    _git_branch_cache=$(git symbolic-ref --short HEAD 2>/dev/null)
  }
  [[ -n "$_git_branch_cache" ]] && echo "[%{$fg_bold[green]%}$_git_branch_cache%{$reset_color%}]"
}

# Prompt
setopt prompt_subst

if [ "$(id -u)" -eq 0 ]; then
  PS1="%B%{$fg[yellow]%}%T%{$reset_color%}%b "
  PS1+="%B%{$fg[red]%}%n%{$reset_color%}%b"
  PS1+="%B%{$fg[yellow]%}@%{$reset_color%}%b"
  PS1+="%B%{$fg[green]%}%m%{$reset_color%}%b "
  PS1+="%B%{$fg[green]%}%~%{$reset_color%}%b"
  PS1+="%B%{$fg[yellow]%}%#%{$reset_color%}%b "
else
  PS1="%B%{$fg[yellow]%}%T%{$reset_color%}%b "
  PS1+="%B%{$fg[green]%}%n%{$reset_color%}%b"
  PS1+="%B%{$fg[yellow]%}@%{$reset_color%}%b"
  PS1+="%B%{$fg[red]%}%m%{$reset_color%}%b "
  PS1+="%B%{$fg[green]%}%~%{$reset_color%}%b"
  PS1+="%B%{$fg[yellow]%}%#%{$reset_color%}%b "
fi

RPS1='$(git_prompt_info)'

# History
setopt histignoredups
setopt SHARE_HISTORY
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Options
setopt CORRECT
setopt EXTENDED_GLOB

# Editor
export VISUAL=vim
export EDITOR=$VISUAL

# Key bindings
bindkey "^R" history-incremental-search-backward

# Completion (cached for speed)
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Load custom completions
fpath=(~/.zsh/completion $fpath)

# Aliases
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Functions (lazy-load, etc.)
for f in ~/.zsh/functions/*; do
  source "$f"
done

# Local config
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# iTerm2 integration (lazy)
[[ -f "${HOME}/.iterm2_shell_integration.zsh" ]] && source "${HOME}/.iterm2_shell_integration.zsh"

# Environment
export NVM_DIR="$HOME/.nvm"
export PYENV_ROOT="$HOME/.pyenv"
export BUN_INSTALL="$HOME/.bun"

# PATH (consolidated)
typeset -U path  # Unique entries only
path=(
  $HOME/bin
  $HOME/.bin
  $HOME/.local/bin
  ./bin
  $PYENV_ROOT/bin
  $BUN_INSTALL/bin
  $HOME/.yarn/bin
  /opt/homebrew/opt/libpq/bin
  $HOME/.lmstudio/bin
  $HOME/.opencode/bin
  $path
)

# Bun completions (lazy)
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
