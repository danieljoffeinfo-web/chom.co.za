#!/usr/bin/env bash
# Regenerates packages/api/src/database.types.ts from the database schema.
#
# Usage: pnpm db:types
# Defaults to the local Supabase started with `pnpm db:start`. Set DB_URL to use
# another database. CI runs this and fails if the committed file is out of date.
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres?sslmode=disable}"
OUT="packages/api/src/database.types.ts"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
  echo '// Generated from the database schema by `pnpm db:types`. Do not edit by hand.'
  supabase gen types typescript --remote "$DB_URL" --schema public
} > "$TMP"

mv "$TMP" "$OUT"
prettier --write "$OUT" > /dev/null
echo "Wrote $OUT"
