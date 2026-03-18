#!/usr/bin/env bash
# Prueba la API de app_releases con la misma URL y anon key que la app.
# Si devuelve filas = RLS/API OK; si devuelve [] = ejecuta 008_app_releases_rls.sql en ESE proyecto.
# Uso: desde repo root, ./ice_pos/scripts/test_app_releases_api.sh
# Requiere: curl, y ice_pos/.env con SUPABASE_URL y SUPABASE_ANON_KEY.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "No existe $ENV_FILE. Crea el archivo con SUPABASE_URL y SUPABASE_ANON_KEY."
  exit 1
fi
source "$ENV_FILE"
if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_ANON_KEY}" ]; then
  echo "Faltan SUPABASE_URL o SUPABASE_ANON_KEY en .env"
  exit 1
fi
URL="${SUPABASE_URL}/rest/v1/app_releases?select=version,build_number,download_url&order=build_number.desc&limit=1"
echo "GET $URL"
echo "Host: $(echo "$SUPABASE_URL" | sed -n 's|https://\([^/]*\).*|\1|p')"
RESP=$(curl -s -w "\n%{http_code}" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Accept: application/json" \
  "$URL")
HTTP_CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | sed '$d')
echo "HTTP $HTTP_CODE"
echo "$BODY" | head -c 500
echo ""
if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: la API no devolvió 200. Revisa RLS (008_app_releases_rls.sql) en ese proyecto."
  exit 1
fi
if [ "$BODY" = "[]" ] || [ -z "$BODY" ]; then
  echo "La API devolvió vacío. Ejecuta en Supabase SQL Editor (proyecto con host arriba):"
  echo "  supabase/migrations/008_app_releases_rls.sql"
  exit 1
fi
echo "OK: la API devuelve datos. Si la app sigue sin verlos, revisa que la app use el mismo .env al compilar."
