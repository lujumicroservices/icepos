# Actualizaciones de la app (sin Google Play)

La app comprueba si hay una versión nueva consultando la tabla `app_releases` en Supabase. Si el `build_number` en la nube es mayor al instalado, se muestra un aviso con opción de descargar el APK.

## 1. Tabla en Supabase

En el SQL Editor de Supabase ejecuta (si no la tienes ya en tu schema):

```sql
create table if not exists public.app_releases (
  id serial primary key,
  version text not null,
  build_number int not null,
  download_url text,
  message_es text,
  created_at timestamptz not null default now()
);
-- RLS (si usas el mismo patrón que el resto de tablas)
alter table public.app_releases enable row level security;
drop policy if exists "anon_all_app_releases" on public.app_releases;
create policy "anon_all_app_releases" on public.app_releases for all to anon using (true) with check (true);
```

## 2. Subir el APK a Supabase Storage

1. En el Dashboard de Supabase: **Storage** → crea un bucket (ej. `releases`) y márcalo **público** si quieres que el enlace sea directo.
2. Sube el archivo APK (ej. `ice_pos_1.0.1.apk`).
3. Copia la URL pública del archivo. Con bucket público suele ser:
   `https://<PROYECTO>.supabase.co/storage/v1/object/public/releases/ice_pos_1.0.1.apk`

## 3. Publicar la nueva versión

Cada vez que quieras que los empleados vean “hay actualización”:

1. **Genera el APK** con versión y build mayores:
   ```bash
   flutter build apk --build-name=1.0.1 --build-number=2
   ```
   El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Renómbralo si quieres (ej. `ice_pos_1.0.1.apk`).

2. **Súbelo** al bucket de Supabase (Storage) y copia la URL pública.

3. **Inserta o actualiza** la fila en `app_releases`. La app solo mira la fila con **mayor** `build_number`, así que puedes:
   - Insertar una fila nueva cada vez:
   ```sql
   insert into public.app_releases (version, build_number, download_url, message_es)
   values ('1.0.1', 2, 'https://<PROYECTO>.supabase.co/storage/v1/object/public/releases/ice_pos_1.0.1.apk', 'Mejoras y correcciones.');
   ```
   - O mantener una sola fila “última versión” y actualizarla:
   ```sql
   update public.app_releases set version = '1.0.1', build_number = 2, download_url = 'https://...', message_es = 'Mejoras y correcciones.' where id = 1;
   ```

## 4. En la app

- **Comprobar actualización:** Menú (drawer) → “Comprobar actualización”.
- Si hay versión nueva: se muestra un diálogo con el mensaje y un botón **Descargar** que abre el `download_url` en el navegador (o la app que gestione la descarga). El usuario instala el APK manualmente (hay que permitir “Orígenes desconocidos” en Android si lo pide).

## Versión y build

- En `pubspec.yaml`: `version: 1.0.0+1` → versión `1.0.0`, build `1`.
- Para cada release nuevo, sube **build_number** (y si quieres version): por ejemplo `1.0.1+2` y en Supabase `build_number = 2`.

Si no pones `download_url` en `app_releases`, el diálogo seguirá mostrando “Actualización disponible” y el mensaje, pero no habrá botón “Descargar” (útil si repartes el APK por otro medio).
