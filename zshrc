# adds the current branch name in green
git_prompt_info() {
  ref=$(git symbolic-ref HEAD 2> /dev/null)
  if [[ -n $ref ]]; then
    echo "[%{$fg_bold[green]%}${ref#refs/heads/}%{$reset_color%}]"
  fi
}

# makes color constants available
autoload -U colors
colors

# enable colored output from ls, etc
export CLICOLOR=1

# expand functions in the prompt
setopt prompt_subst

# load our own completion functions
fpath=(~/.zsh/completion $fpath)

# aliases
if [ -e "$HOME/.aliases" ]; then
  source "$HOME/.aliases"
fi

# completion
autoload -U compinit
compinit

for function in ~/.zsh/functions/*; do
  source $function
done

# expand functions in the prompt
setopt prompt_subst

# use vim as the visual editor
export VISUAL=vim
export EDITOR=$VISUAL

# use incremental search
bindkey "^R" history-incremental-search-backward

# ignore duplicate history entries
setopt histignoredups

# keep TONS of history
export HISTSIZE=4096

# Try to correct command line spelling
setopt CORRECT CORRECT_ALL

# Enable extended globbing
setopt EXTENDED_GLOB

# prompt
export RPS1='$(git_prompt_info)'
# for root
if [ "`id -u`" -eq 0 ]; then
  export PS1="%{[33;33;1m%}%T%{[0m%} %{[33;31;1m%}%n%{[0m[33;33;1m%}@%{[33;32;1m%}%m %{[33;32;1m%}%~%{[0m[33;33;1m%}%#%{[0m%} "
else
  export PS1="%{[33;33;1m%}%T%{[0m%} %{[33;32;1m%}%n%{[0m[33;33;1m%}@%{[33;31;1m%}%m %{[33;32;1m%}%~%{[0m[33;33;1m%}%#%{[0m%} "
fi

export PATH="$HOME/bin:$HOME/.bin:./bin:$PATH"

# rvm
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" && rvm use --default &> /dev/null
