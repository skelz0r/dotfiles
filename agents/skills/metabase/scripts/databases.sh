#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

RESPONSE=$(curl -sw '\n%{http_code}' "$METABASE_URL/api/database" -H "x-api-key: $METABASE_API_KEY")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Metabase API error (HTTP $HTTP_CODE)" >&2
  echo "$BODY" >&2
  exit 1
fi

echo "$BODY" | jq '.data[] | {id, name, engine}'
