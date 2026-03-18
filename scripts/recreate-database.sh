#!/usr/bin/env bash
# Recreate Supabase database from scratch (run consolidated SQL).
# Usage: ./scripts/recreate-database.sh
# Requires: SUPABASE_DB_URL or DATABASE_URL with full postgres connection string.
# If not set, prints instructions to run the SQL in Supabase Dashboard.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SQL_FILE="$REPO_ROOT/ice_pos/supabase/recreate_database.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "recreate_database.sql not found at $SQL_FILE" >&2
  exit 1
fi

DB_URL="${SUPABASE_DB_URL:-$DATABASE_URL}"
if [[ -n "$DB_URL" ]] && command -v psql &>/dev/null; then
  echo "Running recreate_database.sql via psql..."
  psql "$DB_URL" -f "$SQL_FILE"
  echo "Done. Database recreated."
else
  echo "To run via command line, set SUPABASE_DB_URL (or DATABASE_URL) and have psql in PATH."
  echo ""
  echo "Example:"
  echo '  export SUPABASE_DB_URL="postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"'
  echo "  ./scripts/recreate-database.sh"
  echo ""
  echo "Otherwise, run the SQL manually in Supabase Dashboard > SQL Editor:"
  echo "  File: $SQL_FILE"
  echo ""
fi
