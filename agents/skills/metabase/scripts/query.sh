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
METABASE_DATABASE_ID="${METABASE_DATABASE_ID:-1}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sql_query>" >&2
  echo "  $0 'SELECT 1'" >&2
  exit 1
fi

SQL="$1"

RESPONSE=$(curl -sw '\n%{http_code}' "$METABASE_URL/api/dataset" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $METABASE_API_KEY" \
  -d "$(jq -n --arg sql "$SQL" --argjson db "$METABASE_DATABASE_ID" \
    '{database: $db, type: "native", native: {query: $sql}}')")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "202" && "$HTTP_CODE" != "200" ]]; then
  echo "Metabase API error (HTTP $HTTP_CODE)" >&2
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY" >&2
  exit 1
fi

echo "$BODY" | jq '.data.rows'
