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
setopt CORRECT

# Enable extended globbing
setopt EXTENDED_GLOB

# rvm
[[ -s "/usr/local/rvm/scripts/rvm" ]] && source "/usr/local/rvm/scripts/rvm"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# prompt
export RPS1='$(git_prompt_info)$(rvm_prompt_info)'

# for root
# use http://www.nparikh.org/unix/prompt.php#zsh for moar config
if [ "`id -u`" -eq 0 ]; then
  export PS1="%B%{$fg[yellow]%}%T%{$reset_color%}%b " # hour in bold yellow + space
  PS1+="%B%{$fg[red]%}%n%{$reset_color%}%b"           # user in bold red
  PS1+="%B%{$fg[yellow]%}@%{$reset_color%}%b"         # @ in bold yellow
  PS1+="%B%{$fg[green]%}%m%{$reset_color%}%b "        # short hostname in bold green
  PS1+="%B%{$fg[green]%}%~%{$reset_color%}%b"         # pwd in bold green
  PS1+="%B%{$fg[yellow]%}%#%{$reset_color%}%b "       # prompt delimitor in bold yellow + space
else
  export PS1="%B%{$fg[yellow]%}%T%{$reset_color%}%b " # hour in bold yellow + space
  PS1+="%B%{$fg[green]%}%n%{$reset_color%}%b"         # user in bold green
  PS1+="%B%{$fg[yellow]%}@%{$reset_color%}%b"         # @ in bold yellow
  PS1+="%B%{$fg[red]%}%m%{$reset_color%}%b "          # short hostname in bold red
  PS1+="%B%{$fg[green]%}%~%{$reset_color%}%b"         # pwd in bold green
  PS1+="%B%{$fg[yellow]%}%#%{$reset_color%}%b "       # prompt delimitor in bold yellow + space
fi

export PATH="/Applications/OpenOffice.app/Contents/MacOS:$HOME/bin:$HOME/.bin:./bin:$PATH"

# locales customs
if [ -e "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

source '/Users/skelz0r/tmp/google-cloud-sdk/path.zsh.inc'
source '/Users/skelz0r/tmp/google-cloud-sdk/completion.zsh.inc'
