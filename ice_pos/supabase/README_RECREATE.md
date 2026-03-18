# Recrear la base de datos desde cero

El archivo **`recreate_database.sql`** es un script consolidado que:

1. **Elimina** todas las tablas del esquema `public` (y el trigger/función de perfiles).
2. **Crea** de nuevo todas las tablas, índices, RLS, políticas, funciones y grants.

**Cuidado:** se pierde **toda la data** de las tablas públicas. `auth.users` no se toca.

## Cómo ejecutarlo

### Opción 1: Supabase Dashboard (recomendado)

1. Abre tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard) → **SQL Editor**.
2. Crea una nueva query y pega el contenido de `recreate_database.sql` (o sube el archivo si el editor lo permite).
3. Ejecuta (Run). Al terminar, PostgREST recargará el esquema automáticamente (`NOTIFY pgrst, 'reload schema'`).

### Opción 2: Línea de comandos con `psql`

Si tienes **psql** y la **cadena de conexión** a la base (incluye contraseña):

1. En Supabase: **Settings → Database**. Copia la **Connection string (URI)** (modo “Session” o “Transaction”).
   - Formato: `postgresql://postgres.[PROJECT_REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres`
2. Define la variable y ejecuta el script:

```powershell
# Windows (PowerShell)
$env:SUPABASE_DB_URL = "postgresql://postgres.xxxx:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
.\scripts\recreate-database.ps1
```

```bash
# Linux/macOS
export SUPABASE_DB_URL="postgresql://postgres.xxxx:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
./scripts/recreate-database.sh
```

Si no tienes `psql` instalado, usa la **Opción 1** (Dashboard).

### Opción 3: Script desde la raíz del repo

Desde la **raíz del repo** (carpeta `icepos`):

```powershell
# PowerShell
.\scripts\recreate-database.ps1
```

El script buscará `SUPABASE_DB_URL` o `DATABASE_URL`. Si no está definida, mostrará instrucciones para ejecutar el SQL en el Dashboard y la ruta al archivo.

## Después de recrear

- Las tablas quedarán vacías. Puedes:
  - Usar la app: **Sincronizar** / **Enviar datos a la nube** para subir datos locales.
  - O insertar datos manualmente desde el SQL Editor.
- Si usas **Auth**, los usuarios en `auth.users` seguirán existiendo; el script vuelve a crear `public.profiles` y rellena perfiles con rol `cajero` para los usuarios existentes.

## Relación con las migraciones

`recreate_database.sql` equivale a aplicar en orden:

- El esquema base (`supabase_schema.sql`) más las columnas/ajustes de las migraciones 001–009 y 011.

Para **desarrollo incremental** sigue usando la carpeta `migrations/`. Este script sirve cuando quieres **empezar de cero** en un proyecto o entorno (por ejemplo, clonar el repo y levantar la DB sin aplicar migración por migración).
