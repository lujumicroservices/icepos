#!/usr/bin/env bash
# Descarga sqlite3.wasm y drift_worker.dart.js para soporte web de Drift.
# Ejecutar desde la raíz del repo: ./scripts/download_web_drift_assets.sh
# Requiere: curl o wget. Los archivos se guardan en ice_pos/web/.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$PROJECT_DIR/web"

# Versiones compatibles con pubspec.lock (drift 2.31, sqlite3 2.x)
DRIFT_VERSION="${DRIFT_VERSION:-2.31.0}"
SQLITE3_VERSION="${SQLITE3_VERSION:-2.9.4}"

DRIFT_RELEASE="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}"
SQLITE3_RELEASE="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}"

mkdir -p "$WEB_DIR"

download() {
  local url="$1"
  local out="$2"
  if command -v curl &>/dev/null; then
    curl -sSL -o "$out" "$url"
  elif command -v wget &>/dev/null; then
    wget -q -O "$out" "$url"
  else
    echo "Necesitas curl o wget para descargar."
    exit 1
  fi
}

# Drift worker asset is named drift_worker.js in GitHub releases.
echo "Descargando drift_worker.dart.js (drift v$DRIFT_VERSION)..."
if download "${DRIFT_RELEASE}/drift_worker.js" "$WEB_DIR/drift_worker.dart.js"; then
  echo "  -> $WEB_DIR/drift_worker.dart.js"
else
  echo "  Fallo. Descárgalo manualmente de $DRIFT_RELEASE y colócalo en web/"
fi

# sqlite3.wasm
echo "Descargando sqlite3.wasm (sqlite3 v$SQLITE3_VERSION)..."
if download "${SQLITE3_RELEASE}/sqlite3.wasm" "$WEB_DIR/sqlite3.wasm"; then
  echo "  -> $WEB_DIR/sqlite3.wasm"
else
  echo "  Fallo. Descárgalo manualmente de $SQLITE3_RELEASE y colócalo en web/"
fi

echo "Listo. Luego: flutter build web && python3 scripts/serve_web_wasm.py"
