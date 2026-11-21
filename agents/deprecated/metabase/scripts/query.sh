#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

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
