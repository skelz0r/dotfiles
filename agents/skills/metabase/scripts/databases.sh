#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.metabase"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  echo "Create it with:" >&2
  echo "  METABASE_URL=https://metabase.entreprise.api.gouv.fr" >&2
  echo "  METABASE_API_KEY=your_api_key" >&2
  echo "  METABASE_DATABASE_ID=2" >&2
  exit 1
fi

source "$CONFIG_FILE"

: "${METABASE_API_KEY:?METABASE_API_KEY not set in $CONFIG_FILE}"
: "${METABASE_URL:?METABASE_URL not set in $CONFIG_FILE}"

RESPONSE=$(curl -sw '\n%{http_code}' "$METABASE_URL/api/database" -H "x-api-key: $METABASE_API_KEY")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Metabase API error (HTTP $HTTP_CODE)" >&2
  echo "$BODY" >&2
  exit 1
fi

echo "$BODY" | jq '.data[] | {id, name, engine}'
