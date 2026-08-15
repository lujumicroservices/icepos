# Migraciones Supabase

Cada migración es un archivo SQL numerado de forma incremental (`NNN_descripcion.sql`). Ejecutar en orden en **Supabase Dashboard > SQL Editor** cuando apliques cambios al esquema en un proyecto ya desplegado.

## Nuevo archivo sin pensar en el número

En la raíz del repo:

```powershell
.\scripts\new-supabase-migration.ps1 nombre_descriptivo
```

Esto calcula el siguiente id como **max(`.migration_seq`, mayor prefijo en esta carpeta) + 1**, crea `NNN_nombre_descriptivo.sql` y actualiza **`.migration_seq`**. Si alguien añade una migración a mano con número mayor, el script sigue enlazando bien.

No hace falta editar `.migration_seq` a mano salvo corrección tras un merge conflict.

| ID  | Archivo                           | Descripción                                      |
|-----|-----------------------------------|--------------------------------------------------|
| 001 | `001_supplies_category.sql`       | Agregar columna `category` a tabla `supplies`.  |
| 002 | `002_sales_device_id_device_name.sql` | Agregar `device_id` y `device_name` a `sales`. |
| 003 | `003_movements.sql` | Crear tabla `movements` (entradas/salidas caja o banco). |
| 004 | `004_profiles_auth.sql` | Tabla `profiles` (rol admin/cajero) + trigger desde auth.users. |
| 005 | `005_rls_anon_master.sql` | Políticas RLS para que anon/authenticated lean y escriban categorías, productos, insumos, etc. (evita "La nube no tiene categorías" cuando sí hay datos). |
| 006 | `006_sales_cancelled_at.sql` | Columna `cancelled_at` en `sales` para borrado lógico (cancelar venta sin borrar la fila). |
| 033 | `033_staff_tasks.sql` | Tareas de personal (`staff_tasks`, `staff_task_responses`: hecho/omitido + comentario). |
| 034 | `034_fcm_device_tokens.sql` | Tokens FCM para push en tablets Android/iOS. |
| 035 | `035_staff_task_templates.sql` | Plantillas de tareas repetitivas (diario o por días de semana) que generan ocurrencias. |

El esquema base (tablas nuevas) está en la raíz del proyecto: `supabase_schema.sql`.
