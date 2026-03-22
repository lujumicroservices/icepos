# Recetas: importación local, CSV y Supabase

## Flujo recomendado

1. **Alta de productos e insumos**  
   Los nombres en `assets/data/recetas_formato.json` deben coincidir **exactamente** con `products.name` y `supplies.name` en la base local (y en la nube si usas sync).

2. **Importar en la app (genera CSV + actualiza SQLite)**  
   - Menú lateral (admin) → **Importar recetas (recetas_formato.json)**.  
   - Se escribe un CSV de reporte en la carpeta de documentos de la app (Windows/Android/iOS/desktop) y **además** se copia el mismo contenido al **portapapeles**.  
   - En web solo queda el portapapeles (no hay ruta de archivo).

3. **Opcional: subir a Supabase**  
   Si la nube está configurada, el diálogo pregunta si deseas subir cada producto tocado. Eso usa `syncProductToCloudFull` (recetas + datos del producto). Requiere red.

4. **Insumos vacíos en Supabase**  
   Si `supplies` está vacío o faltan nombres que exige `recetas_formato.json`, ejecuta **`04_insert_supplies_from_recetas_json.sql`**: inserta los **55 insumos únicos** que aparecen como `insumo` en ese JSON (idempotente por `name`). Revisa y ajusta `unit`, `category` y `current_stock` antes o después según tu negocio.

5. **Auditoría en Supabase**  
   En el SQL Editor de Supabase, ejecuta los scripts en orden:

   | Orden | Archivo | Uso |
   |-------|---------|-----|
   | 1 | `01_verify_recipes.sql` | Conteos y comprobación de FK |
   | 2 | `02_products_without_recipes.sql` | Productos activos sin ninguna receta |
   | 3 | `03_optional_clear_all_recipes.sql` | **PELIGROSO**: borra todas las recetas en la nube (solo si vas a reimportar desde cero vía app) |
   | — | `04_insert_supplies_from_recetas_json.sql` | Insertar insumos del JSON de recetas (si no existen por nombre) |
   | — | `00_fix_supplies_id_sequence.sql` | Solo si falla el INSERT con **duplicate key supplies_pkey**: alinea el serial |

## Qué **no** hace el importador del JSON

- No crea filas en `modifier_groups` / `modifier_options` a partir del bloque `modificadores` del JSON (solo deja filas `INFO_MODIFIER` en el CSV).  
- Sigue usando tus JSON de modificadores existentes o la pantalla de administración.

## Migraciones

No hace falta una migración nueva si tu proyecto ya tiene la tabla `public.recipes` (ver `supabase/recreate_database.sql`). Si recreaste la BD desde cero con ese script, los scripts de esta carpeta son solo de **consulta/limpieza**.

## Dependencias en la app

- `path_provider` (CSV en disco donde el SO lo permita).  
- Asset ya incluido vía `assets/data/` en `pubspec.yaml`.
