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

ENV_METABASE_URL="${METABASE_URL-}"
ENV_METABASE_API_KEY="${METABASE_API_KEY-}"
ENV_METABASE_DATABASE_ID="${METABASE_DATABASE_ID-}"

source "$CONFIG_FILE"

METABASE_URL="${ENV_METABASE_URL:-${METABASE_URL-}}"
METABASE_API_KEY="${ENV_METABASE_API_KEY:-${METABASE_API_KEY-}}"
METABASE_DATABASE_ID="${ENV_METABASE_DATABASE_ID:-${METABASE_DATABASE_ID:-1}}"

: "${METABASE_API_KEY:?METABASE_API_KEY not set in environment nor in $CONFIG_FILE}"
: "${METABASE_URL:?METABASE_URL not set in environment nor in $CONFIG_FILE}"
