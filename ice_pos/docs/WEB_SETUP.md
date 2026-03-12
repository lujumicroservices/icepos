# Configuración de la app en web (Opción A – Drift)

Para que la base de datos local funcione en el navegador, Drift usa SQLite compilado a WebAssembly. Hay que añadir dos archivos en la carpeta `web/` del proyecto.

**Si ves "Incorrect response MIME type. Expected 'application/wasm'"**: estás usando un servidor que no envía el tipo correcto. **No uses** `flutter run -d chrome` ni abras `index.html` con doble clic (file://). Debes usar **build + el script Python** (paso 4).

**Si ves "HTTP status code is not ok"**: faltan `sqlite3.wasm` y/o `drift_worker.dart.js` en `web/`. Descárgalos (paso 2), colócalos en `ice_pos/web/`, ejecuta de nuevo `flutter build web` y luego el servidor.

## Archivos necesarios

| Archivo | Origen | Descripción |
|--------|--------|-------------|
| `sqlite3.wasm` | [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases) | Módulo WebAssembly de SQLite. Usa una versión **2.x** (la 3.x no es compatible con Drift 2.x). |
| `drift_worker.dart.js` | [drift releases](https://github.com/simolus3/drift/releases) | Worker que ejecuta la base de datos en un hilo en segundo plano. Descarga la versión que coincida con tu `drift` en `pubspec.lock`. |

## Pasos

1. Revisa las versiones en `pubspec.lock`:
   - `drift`: p. ej. 2.31.0
   - `sqlite3` (transitiva): p. ej. 2.9.x

2. Descarga desde los releases:
   - En [drift releases](https://github.com/simolus3/drift/releases), para tu versión de drift (ej. 2.31.0), descarga `drift_worker.dart.js` (o el asset que corresponda al worker para web).
   - En [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases), para una versión 2.x (ej. 2.9.4), descarga `sqlite3.wasm`.

3. Coloca los archivos en `ice_pos/web/` **antes** de ejecutar `flutter build web`:
   ```
   ice_pos/web/
   ├── index.html
   ├── manifest.json
   ├── sqlite3.wasm          ← obligatorio
   └── drift_worker.dart.js  ← obligatorio
   ```
   Si faltan, en el navegador verás **"HTTP status code is not ok"** al cargar la app: la petición al .wasm devuelve 404. Añade los archivos en `web/`, vuelve a ejecutar `flutter build web` y luego `python3 scripts/serve_web_wasm.py`.

4. **Ejecutar en web** (obligatorio: usar el script Python, no `flutter run` ni abrir el HTML a mano):

   ```bash
   cd ice_pos
   flutter build web
   python3 scripts/serve_web_wasm.py
   ```
   Abre en Chrome: **http://localhost:8080**

   - **No uses** `flutter run -d chrome`: el servidor de Flutter no envía `Content-Type: application/wasm` y verás "Incorrect response MIME type".
   - **No abras** `build/web/index.html` con doble clic (file://): tampoco tendrá el MIME correcto.
   - El script `serve_web_wasm.py` sirve `build/web` con `Content-Type: application/wasm` para los `.wasm`.

   Para producción (Firebase, nginx, etc.), configura el host para que sirva `.wasm` con `Content-Type: application/wasm`.

## Comportamiento en web

- **Pestañas**: Solo administrativas (Inventario, Historial de ventas). No se muestra el POS.
- **Menú (drawer)**: Se ocultan "Cerrar turno" e "Impresora". El resto (categorías, productos, insumos, bundles, Movimientos, Reportes, nube, actualizaciones) sigue disponible.
- **Base de datos**: La misma SQLite local vía Drift (en el navegador usa wasm). Sync con Supabase funciona igual.
