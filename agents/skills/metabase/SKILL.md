---
name: metabase
description: Run SQL queries against a Metabase instance via its API. Use when the user asks to query Metabase, extract data from Metabase, list Metabase databases, or run SQL against a Metabase-connected database. Triggers on "metabase", "query metabase", "metabase SQL", "metabase databases".
---

# Metabase

Run SQL queries against Metabase via its REST API using an API key.

## Setup

On first use, check for a `.metabase` config file at the git repo root. If missing, ask the user to create it:

```bash
cat > .metabase <<'EOF'
METABASE_URL=https://metabase.example.com
METABASE_API_KEY=your_api_key_here
METABASE_DATABASE_ID=1
EOF
```

Then ensure `.metabase` is in `.gitignore`. Add it if missing.

## Scripts

All scripts source `.metabase` from the repo root (`$(git rev-parse --show-toplevel)/.metabase`).

### List databases

```bash
scripts/databases.sh
```

Returns `{id, name, engine}` for each database. Use this to help the user pick the right `METABASE_DATABASE_ID`.

### Run a SQL query

```bash
scripts/query.sh 'SELECT count(*) FROM users'
```

Returns `jq`-formatted `.data.rows` array. Override the database per-query:

```bash
METABASE_DATABASE_ID=3 scripts/query.sh 'SELECT 1'
```

## Auth

Uses `x-api-key` header (Metabase API keys), not session tokens.

## Error handling

Scripts check HTTP status and print the error body on failure. Common errors:
- **401**: invalid or expired API key
- **400**: bad SQL syntax (Metabase returns the DB error)
