export PATH="$HOME/dotfiles/bin:$HOME/.bin:$PATH"

if [ -z "$SSH_AUTH_SOCK" ]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/agent.local.sock"
  ssh-add -l >/dev/null 2>&1
  local_agent_status=$?
  if [ "$local_agent_status" -eq 2 ]; then
    rm -f "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
  fi
  if [ "$local_agent_status" -ne 0 ]; then
    ssh-add -q ~/.ssh/id_hetzner ~/.ssh/id_ed25519 2>/dev/null
  fi
  unset local_agent_status
fi

rubocop_custom_cops="$HOME/dotfiles/config/rubocop/custom.rb"
if [ -r "$rubocop_custom_cops" ] && [[ "$RUBOCOP_OPTS" != *"$rubocop_custom_cops"* ]]; then
  export RUBOCOP_OPTS="${RUBOCOP_OPTS:+$RUBOCOP_OPTS }--require $rubocop_custom_cops"
fi
unset rubocop_custom_cops
