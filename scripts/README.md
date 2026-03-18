# Scripts de respaldo

## Recrear la base de datos desde cero (Supabase)

Para **borrar y volver a crear** todas las tablas del esquema `public` en Supabase (pierdes toda la data):

1. **Desde el Dashboard:** Supabase → SQL Editor → pega o sube el contenido de `ice_pos/supabase/recreate_database.sql` y ejecuta.
2. **Desde la terminal** (con `psql` y cadena de conexión):
   ```powershell
   $env:SUPABASE_DB_URL = "postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"
   .\scripts\recreate-database.ps1
   ```
   La cadena la obtienes en Supabase → Settings → Database → Connection string (URI).

Más detalles en `ice_pos/supabase/README_RECREATE.md`.

---

## Publicar release APK desde tu computadora

Si GitHub Actions no está disponible o quieres tener un plan B, puedes generar y subir una nueva versión desde tu Mac (o cualquier máquina con Flutter y `gh`).

### Requisitos

1. **Flutter** en PATH (la misma versión que uses para desarrollar, ej. 3.35).
2. **GitHub CLI (`gh`)** instalado y autenticado:
   ```bash
   brew install gh
   gh auth login
   ```
3. **Supabase** (opcional): para que la app muestre “Nueva versión” a los empleados. Necesitas `SUPABASE_URL` y `SUPABASE_ANON_KEY` en el entorno o en `ice_pos/.env`.

### Uso

Tienes que estar **en la raíz del repo** (la carpeta donde está `ice_pos` y `scripts`):

```bash
cd icepos   # o cd /Users/juanvaldes/dev/icepos
chmod +x scripts/release-apk-local.sh
./scripts/release-apk-local.sh <VERSION> <BUILD_NUMBER> [MENSAJE]
```

Ejemplos:

```bash
# Versión 1.0.3, build 4, mensaje por defecto
./scripts/release-apk-local.sh 1.0.3 4

# Con mensaje personalizado
./scripts/release-apk-local.sh 1.0.3 4 "Corrección de impresión y mejoras en cortes"
```

- **VERSION**: número de versión que verá el usuario (ej. 1.0.3).
- **BUILD_NUMBER**: entero que debe ser mayor que el anterior (Android permite hasta 2 100 000 000).
- **MENSAJE**: texto opcional para la release en GitHub y para `message_es` en Supabase.

### Qué hace el script

1. Compila el APK con `flutter build apk --release` usando la versión y build que pasaste.
2. Crea (o actualiza) la release en GitHub con el tag `v<VERSION>` y sube el APK.
3. Si tienes `SUPABASE_URL` y `SUPABASE_ANON_KEY`, inserta una fila en la tabla `app_releases` para que la app pueda avisar de la nueva versión.

### Variables de entorno para Supabase

Puedes definirlas en la sesión antes de ejecutar:

```bash
export SUPABASE_URL="https://TU_PROYECTO.supabase.co"
export SUPABASE_ANON_KEY="tu_anon_key"
./scripts/release-apk-local.sh 1.0.3 4
```

O añadir las mismas variables a `ice_pos/.env` (el script intenta cargarlas desde ahí si existen).

### Windows (PowerShell)

En la **raíz del repo** (donde están `ice_pos` y `scripts`), abre PowerShell:

```powershell
# Publicar release (versión, build, mensaje opcional)
.\scripts\release-apk-local.ps1 1.0.12 12
.\scripts\release-apk-local.ps1 1.0.12 12 "Corrección de impresión"
```

Si PowerShell no permite ejecutar scripts, una vez por equipo:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

O ejecutar sin cambiar la política:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release-apk-local.ps1 1.0.12 12
```

### Probar API de actualizaciones (app_releases)

Si la app dice "ya tienes la última versión" pero en Supabase la tabla tiene datos:

```powershell
cd ice_pos
.\scripts\test_app_releases_api.ps1
```

Si devuelve `[]`, ejecuta en Supabase (SQL Editor) el contenido de `supabase/migrations/008_app_releases_rls.sql`.

### Si no tienes `gh`

Puedes compilar el APK a mano y subir la release desde la web de GitHub:

```bash
cd ice_pos
flutter pub get
flutter build apk --release --build-name=1.0.3 --build-number=4
```

El APK queda en `ice_pos/build/app/outputs/flutter-apk/app-release.apk`. Luego:

1. En GitHub: Releases → Create a new release.
2. Tag: `v1.0.3` (crear nuevo tag).
3. Sube el archivo `app-release.apk`.
4. Si usas Supabase, inserta una fila en `app_releases` con `version`, `build_number`, `download_url` y `message_es` (por ejemplo desde el SQL Editor del dashboard).
