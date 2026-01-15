#!/usr/bin/env bash

detect_host() {
  local local_host="${1:-lch405}"
  local remote_host="${2:-rch405}"

  if ssh -o ConnectTimeout=1 -o BatchMode=yes "$local_host" true 2>/dev/null; then
    echo "$local_host"
  else
    echo "$remote_host"
  fi
}
