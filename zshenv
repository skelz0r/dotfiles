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
