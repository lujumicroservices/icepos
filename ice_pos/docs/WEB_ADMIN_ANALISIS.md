# Análisis: ejecutar la app en web (solo funciones administrativas)

## Objetivo
Correr la aplicación en web **solo con funciones administrativas** (sin POS, sin impresora, sin escáner).

---

## Estado actual

| Aspecto | Estado |
|--------|--------|
| **Plataforma web** | Ya existe carpeta `web/` (index.html, manifest.json). Flutter web está habilitado. |
| **Datos** | Admin usa `PosRepository` → Drift (SQLite local). Reportes pueden usar ya `CloudReportsService` (Supabase). |
| **Supabase** | Configurado: sync, reportes desde nube, push/sync desde drawer. |

---

## Dependencias que afectan a web

| Dependencia | Uso | Soporte web | Acción |
|-------------|-----|-------------|--------|
| **drift** + **drift_flutter** + **sqlite3_flutter_libs** | Base de datos local (todo el repositorio) | SQLite en web requiere **sqlite3 wasm** (Drift lo soporta con setup adicional). `sqlite3_flutter_libs` es solo nativo. | Opción A: usar Drift en web con wasm. Opción B: en web no usar DB local, solo Supabase. |
| **blue_thermal_printer** | Impresión de tickets | No soporta web | Ocultar/omitir en web (no hace falta para admin). |
| **mobile_scanner** | Escáner QR | Limitado o no en web | Ocultar en web. |
| **permission_handler** | Permisos Bluetooth/etc. | Limitado en web | Solo se usa con impresora/escáner → omitir en web. |
| **shared_preferences** | Preferencias (idioma, etc.) | Sí (localStorage) | Sin cambios. |
| **supabase_flutter** | API y auth | Sí | Sin cambios. |

---

## Enfoques posibles

### Opción A – Drift también en web (recomendada para “mínimo cambio”)

**Idea:** La misma app corre en web; la base de datos local en web usa SQLite vía WebAssembly (Drift tiene soporte oficial).

**Pasos resumidos:**
1. **Habilitar Drift en web**
   - Añadir soporte web a `drift_flutter` / usar `sqlite3` wasm según [documentación de Drift para web](https://drift.simonbinder.eu/Platforms/web) (assets en `web/`, worker si aplica).
   - En `app_database.dart` la apertura de la DB ya usa `driftDatabase()`; suele bastar con configurar la parte web (wasm) y no tocar el resto del código de Drift.
2. **Condicionar código solo-móvil**
   - En `main.dart`: si `kIsWeb`, no llamar a `receiptPrinterProvider.loadBondedDevices()`.
   - En `HomeScreen` (o donde se arme el menú): si `kIsWeb`, mostrar solo pestañas/rutas administrativas (Inventario, Historial de ventas, Reportes, etc.) y ocultar POS, Configuración de impresora, Escáner.
   - Opcional: en web no mostrar ítems del drawer que dependan de impresora/escáner.
3. **Comprobaciones**
   - `flutter run -d chrome` y probar: login/rol admin, categorías, productos, insumos, bundles, reportes, historial de ventas, movimientos, cierre de turno (si aplica en web).

**Ventajas:** Un solo código; admin en web funciona igual que en escritorio (con DB local y sync con Supabase).  
**Desventajas:** Hay que configurar sqlite3 wasm y asegurar que el bundle web incluya los assets necesarios.  
**Esfuerzo estimado:** Bajo–medio (1–2 días si ya conoces el stack).

---

### Opción B – Web solo con Supabase (sin SQLite en web)

**Idea:** En web no se usa Drift; toda la lógica administrativa en web lee/escribe solo en Supabase.

**Pasos resumidos:**
1. **Detectar web**  
   Usar `kIsWeb` (o un flag “solo nube”) en un único sitio (p. ej. provider de “plataforma” o de “repositorio”).
2. **Abstraer fuente de datos**
   - Definir interfaces (o contratos) para lo que hoy usa `PosRepository`: categorías, productos, insumos, recetas, bundles, reportes, historial de ventas, movimientos, cierres.
   - Implementación actual: `PosRepository` con Drift (local).
   - Nueva implementación: p. ej. `SupabaseAdminRepository` que haga `client.from('categories').select()`, `upsert`, etc., para cada entidad.
3. **Inyección por plataforma**
   - En web: usar solo `SupabaseAdminRepository` (y no crear `AppDatabase` en web, o crear un stub que no se use).
   - En móvil/desktop: seguir usando `PosRepository` con Drift.
4. **Pantallas admin**
   - Las pantallas (productos, categorías, insumos, bundles, reportes, historial, movimientos) dependerían del contrato (interface), no de `PosRepository` directamente. En web recibirían el repo de Supabase.
5. **Reportes**
   - Ya tienes `CloudReportsService`; en web los reportes pueden usar solo eso (o el nuevo repo Supabase) para no tocar Drift.

**Ventajas:** En web no dependes de SQLite/wasm; solo Supabase y lógica de red.  
**Desventajas:** Refactor mayor (interfaces + segunda implementación del “repositorio admin”); duplicar o mapear bien la lógica de negocio (validaciones, reglas de sync, etc.).  
**Esfuerzo estimado:** Medio–alto (varios días).

---

## Recomendación

- **Si quieres algo rápido y estable:** **Opción A** (Drift en web con wasm + ocultar POS/impresora/escáner en web). Es menos trabajo y mantiene una sola fuente de verdad (Drift + sync a Supabase) en todas las plataformas.
- **Si quieres que web no dependa de SQLite y solo hable con Supabase:** **Opción B**, asumiendo un refactor de capa de datos y tiempo para implementar y probar el repo “solo Supabase” para todas las pantallas admin.

---

## Resumen de esfuerzo (solo admin en web)

| Enfoque | Complejidad | Tiempo estimado | Riesgo |
|--------|-------------|-----------------|--------|
| **A – Drift en web + ocultar POS/impresora/escáner** | Baja–media | 1–2 días | Bajo |
| **B – Web solo Supabase (sin Drift en web)** | Media–alta | 4–8 días | Medio (refactor y doble implementación) |

Conclusión: **sí es razonablemente sencillo** sacar una versión web solo administrativa; la vía más sencilla es la **Opción A** (mantener Drift en web y limitar la UI a funciones admin).

---

## Implementación Opción A (realizada)

- **Drift en web**: `app_database.dart` usa `DriftWebOptions` cuando `kIsWeb` (sqlite3.wasm + drift_worker.dart.js).
- **main.dart**: En web no se llama a `loadBondedDevices()` (impresora).
- **HomeScreen**: En web las pestañas son solo Inventario e Historial de ventas; en el drawer se ocultan "Cerrar turno" e "Impresora".
- **Assets web**: Hay que añadir `sqlite3.wasm` y `drift_worker.dart.js` en `web/`. Ver **[WEB_SETUP.md](WEB_SETUP.md)** y el script `scripts/download_web_drift_assets.sh`.
