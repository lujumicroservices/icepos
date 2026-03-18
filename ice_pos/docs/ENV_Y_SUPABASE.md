# Análisis: .env y Supabase en este proyecto

## Cómo se usa el .env

1. **Dónde está:** `ice_pos/.env` (raíz del proyecto Flutter).
2. **Quién lo carga:** `main.dart` → `await dotenv.load(fileName: '.env')` (antes de todo).
3. **Quién lo lee:** Solo `SupabaseService.initialize()`:
   - `dotenv.env['SUPABASE_URL']`
   - `dotenv.env['SUPABASE_ANON_KEY']`
4. **Asset:** En `pubspec.yaml` está `assets: - .env`, así que el archivo se empaqueta en el build. La app usa **el .env que existía en `ice_pos/` cuando hiciste el último `flutter build` o `flutter run`**.

No hay otra URL ni otra clave de Supabase en el código: un solo cliente, un solo proyecto.

## Si “uso el mismo .env” y la tabla tiene datos pero la app no ve filas

Entonces la consulta a `app_releases` está llegando al proyecto correcto pero **Row Level Security (RLS)** está impidiendo que el rol `anon` vea filas.

### Comprobar en orden

1. **Confirmar host**  
   En el log de la app debería salir algo como:
   ```text
   app_update_service: ... Host=fkkccfcbaxlabhwfozcd.supabase.co
   ```  
   Ese host debe ser el mismo que en la URL del proyecto en el Dashboard de Supabase.

2. **Probar la API con el mismo .env**  
   Desde `ice_pos`:
   ```powershell
   .\scripts\test_app_releases_api.ps1
   ```  
   - Si devuelve **filas** → la API y RLS están bien; si la app sigue sin verlas, haz un **nuevo build** (el que tienes instalado puede haber sido compilado con otro .env).
   - Si devuelve **[]** o error → en ese proyecto (el del host del .env) falta o está mal la política RLS para `app_releases`.

3. **Abrir el proyecto correcto en Supabase**  
   Dashboard → elegir el proyecto cuya URL es `https://<Host>/...` (el mismo del log y del .env).

4. **Aplicar RLS para anon**  
   En ese proyecto, en **SQL Editor**, ejecuta el contenido de:
   ```text
   supabase/migrations/008_app_releases_rls.sql
   ```  
   Eso deja que el rol `anon` lea (y escriba) en `app_releases`.

5. **Recompilar la app**  
   Tras cambiar .env o corregir RLS, haz al menos:
   ```bash
   cd ice_pos && flutter clean && flutter pub get && flutter run
   ```  
   o un nuevo `flutter build apk` e instalar ese APK.

## Resumen

| Qué comprobar              | Dónde / Cómo |
|---------------------------|--------------|
| Mismo proyecto            | Log: `Host=...` = URL del proyecto en Dashboard. |
| Misma configuración       | Script `test_app_releases_api.ps1` usa `ice_pos/.env`. |
| RLS para app_releases     | Ejecutar `008_app_releases_rls.sql` en ese proyecto. |
| App usando .env actual     | Rebuild e instalar (el .env se embebe en el build). |
