#!/usr/bin/env bash
# Backup: generar APK y publicar release desde tu computadora (sin depender de GitHub Actions).
#
# Requisitos:
#   - Flutter instalado y en PATH
#   - GitHub CLI (gh) instalado y autenticado: brew install gh && gh auth login
#   - Opcional: SUPABASE_URL y SUPABASE_ANON_KEY en el entorno o en ice_pos/.env
#
# Uso:
#   ./scripts/release-apk-local.sh 1.0.3 4
#   ./scripts/release-apk-local.sh 1.0.3 4 "Corrección de impresión"
#
# Argumentos:
#   $1 = version (ej. 1.0.3)
#   $2 = build number (entero, ej. 4). Android permite hasta 2100000000.
#   $3 = mensaje opcional para la release (default: "Nueva versión disponible.")

set -e

VERSION="${1:?Falta versión (ej. 1.0.3)}"
BUILD="${2:?Falta build number (ej. 4)}"
MESSAGE_ES="${3:-Nueva versión disponible.}"

# Límite Android para versionCode
MAX_BUILD=2100000000
if [ "$BUILD" -gt "$MAX_BUILD" ]; then
  echo "Build number se limita a $MAX_BUILD (límite Android)."
  BUILD=$MAX_BUILD
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICE_POS="$REPO_ROOT/ice_pos"
APK_PATH="$ICE_POS/build/app/outputs/flutter-apk/app-release.apk"

cd "$REPO_ROOT"

echo "==> Versión: $VERSION, Build: $BUILD"
echo "==> Compilando APK..."
cd "$ICE_POS"
flutter pub get
flutter build apk --release --build-name="$VERSION" --build-number="$BUILD"
cd "$REPO_ROOT"

if [ ! -f "$APK_PATH" ]; then
  echo "Error: no se generó $APK_PATH"
  exit 1
fi

echo "==> Creando release en GitHub..."
# gh release create crea el tag si no existe y sube el APK
gh release create "v$VERSION" "$APK_PATH" \
  --title "Release $VERSION" \
  --notes "$MESSAGE_ES" \
  --latest

echo "==> Actualizando Supabase app_releases (si hay credenciales)..."

# Cargar .env de ice_pos si existe (formato KEY=value)
if [ -f "$ICE_POS/.env" ]; then
  set -a
  source "$ICE_POS/.env" 2>/dev/null || true
  set +a
fi

if [ -n "${SUPABASE_URL}" ] && [ -n "${SUPABASE_ANON_KEY}" ]; then
  REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  if [ -z "$REPO_SLUG" ]; then
    echo "No se pudo obtener repo (gh repo view). Pasa SUPABASE_* y usa DOWNLOAD_URL manual si hace falta."
  else
    DOWNLOAD_URL="https://github.com/${REPO_SLUG}/releases/download/v${VERSION}/app-release.apk"
    MESSAGE_JSON=$(printf '%s' "$MESSAGE_ES" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    curl -s -X POST "${SUPABASE_URL}/rest/v1/app_releases" \
      -H "apikey: ${SUPABASE_ANON_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=minimal" \
      -d "{\"version\":\"$VERSION\",\"build_number\":$BUILD,\"download_url\":\"$DOWNLOAD_URL\",\"message_es\":$MESSAGE_JSON}"
    echo "Supabase app_releases actualizado."
  fi
else
  echo "SUPABASE_URL o SUPABASE_ANON_KEY no configurados. Omitiendo Supabase."
  echo "  Para activar: export SUPABASE_URL=... SUPABASE_ANON_KEY=... o añádelos a ice_pos/.env"
fi

echo ""
echo "Listo. Release v$VERSION publicada."
echo "  APK: $APK_PATH"
echo "  URL: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "OWNER/REPO")/releases/tag/v$VERSION"
