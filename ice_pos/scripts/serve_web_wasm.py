#!/usr/bin/env python3
"""
Sirve la carpeta build/web de Flutter con Content-Type correcto para .wasm.
Necesario porque el servidor de desarrollo de Flutter no envía application/wasm.

Uso:
  1. flutter build web
  2. Desde la raíz del repo: python3 scripts/serve_web_wasm.py
  3. Abre http://localhost:8080 en Chrome
"""
import http.server
import os
import sys

# Carpeta a servir: ice_pos/build/web (script está en ice_pos/scripts/)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
BUILD_WEB = os.path.join(PROJECT_DIR, "build", "web")

if not os.path.isdir(BUILD_WEB):
    print("Primero ejecuta: flutter build web")
    print(f"Esperaba carpeta: {BUILD_WEB}")
    sys.exit(1)

# Si faltan los assets de Drift, el navegador dará "HTTP status code is not ok" al cargar .wasm
WASM_FILE = os.path.join(BUILD_WEB, "sqlite3.wasm")
WORKER_FILE = os.path.join(BUILD_WEB, "drift_worker.dart.js")
for path, name in [(WASM_FILE, "sqlite3.wasm"), (WORKER_FILE, "drift_worker.dart.js")]:
    if not os.path.isfile(path):
        print(f"ERROR: Falta {name} en build/web (y por tanto en web/ antes de construir).")
        print("  Descarga los archivos y colócalos en ice_pos/web/ luego ejecuta de nuevo:")
        print("  flutter build web")
        print("  Ver docs/WEB_SETUP.md o ejecutar scripts/download_web_drift_assets.sh")
        sys.exit(1)


class WasmHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD_WEB, **kwargs)

    def guess_type(self, path):
        # El navegador exige Content-Type: application/wasm para .wasm.
        # Por defecto Python usa application/octet-stream y el navegador rechaza.
        if path.endswith(".wasm") or ".wasm" in path:
            return "application/wasm"
        return super().guess_type(path)


def main():
    port = 8080
    with http.server.HTTPServer(("", port), WasmHTTPRequestHandler) as httpd:
        print(f"Sirviendo {BUILD_WEB} en http://localhost:{port}")
        print("Content-Type: application/wasm aplicado a archivos .wasm")
        print("Ctrl+C para salir.")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
