# Migraciones Supabase

Cada migración es un archivo SQL numerado de forma incremental. Ejecutar en orden en **Supabase Dashboard > SQL Editor** cuando apliques cambios al esquema en un proyecto ya desplegado.

| ID  | Archivo                           | Descripción                                      |
|-----|-----------------------------------|--------------------------------------------------|
| 001 | `001_supplies_category.sql`       | Agregar columna `category` a tabla `supplies`.  |
| 002 | `002_sales_device_id_device_name.sql` | Agregar `device_id` y `device_name` a `sales`. |
| 003 | `003_movements.sql` | Crear tabla `movements` (entradas/salidas caja o banco). |
| 004 | `004_profiles_auth.sql` | Tabla `profiles` (rol admin/cajero) + trigger desde auth.users. |
| 005 | `005_rls_anon_master.sql` | Políticas RLS para que anon/authenticated lean y escriban categorías, productos, insumos, etc. (evita "La nube no tiene categorías" cuando sí hay datos). |
| 006 | `006_sales_cancelled_at.sql` | Columna `cancelled_at` en `sales` para borrado lógico (cancelar venta sin borrar la fila). |

El esquema base (tablas nuevas) está en la raíz del proyecto: `supabase_schema.sql`.
