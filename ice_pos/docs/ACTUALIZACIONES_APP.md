# Actualizaciones de la app (sin Google Play)

La app comprueba si hay una versión nueva consultando la tabla `app_releases` en Supabase. Si el `build_number` en la nube es mayor al instalado, se muestra un aviso con opción de descargar el APK.

---

## Opción A: Pipeline con GitHub Actions (recomendado)

Con el workflow incluido (`.github/workflows/release-apk.yml`) puedes publicar una versión en unos minutos sin construir ni subir nada a mano. El APK se publica en **GitHub Releases** y la tabla `app_releases` de Supabase se actualiza sola.

### Requisitos

- Repo en GitHub (público o privado; en privado los minutos de Actions son limitados en el plan gratis).
- En el repo: **Settings → Secrets and variables → Actions** → añadir:
  - `SUPABASE_URL`: `https://<tu-proyecto>.supabase.co`
  - `SUPABASE_ANON_KEY`: la anon key del proyecto (Supabase Dashboard → Settings → API).

### Uso del workflow

**1. Lanzar a mano (recomendado la primera vez)**  
- En GitHub: **Actions** → workflow **"Release APK"** → **Run workflow**.  
- Completa:
  - **Version**: ej. `1.0.1`
  - **Build number**: entero mayor que el actual (ej. `2`)
  - **Release notes**: opcional, ej. "Mejoras y correcciones"
- **Run workflow**. Cuando termine:
  - El APK estará en **Releases** con la etiqueta `v1.0.1`.
  - La URL de descarga será:  
    `https://github.com/<tu-usuario>/<tu-repo>/releases/download/v1.0.1/app-release.apk`
  - En Supabase se habrá insertado una fila en `app_releases` con esa URL.

**2. Lanzar con un tag**  
- Crea y sube un tag, por ejemplo:  
  `git tag v1.0.1 && git push origin v1.0.1`  
- El workflow se ejecutará, tomará la versión del tag (`1.0.1`) y usará el **run number** del workflow como `build_number`.  
- Si no configuraste los secrets de Supabase, el release se crea igual; solo no se actualizará `app_releases` (puedes actualizarla después a mano).

### Notas

- Repo **público**: la descarga del APK desde Releases no requiere login.
- Repo **privado**: la URL del asset de Releases no es pública; en ese caso conviene seguir usando Supabase Storage para el APK y poner esa URL en `download_url` (o subir el APK a Storage en otro paso del workflow).

---

## Opción B: Manual (Supabase Storage + SQL)

### 1. Tabla en Supabase

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

### 2. Subir el APK a Supabase Storage

1. En el Dashboard de Supabase: **Storage** → crea un bucket (ej. `releases`) y márcalo **público** si quieres que el enlace sea directo.
2. Sube el archivo APK (ej. `ice_pos_1.0.1.apk`).
3. Copia la URL pública del archivo. Con bucket público suele ser:
   `https://<PROYECTO>.supabase.co/storage/v1/object/public/releases/ice_pos_1.0.1.apk`

### 3. Publicar la nueva versión

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

---

## En la app

- **Comprobar actualización:** Menú (drawer) → “Comprobar actualización”.
- Si hay versión nueva: se muestra un diálogo con el mensaje y un botón **Descargar** que abre el `download_url` en el navegador (o la app que gestione la descarga). El usuario instala el APK manualmente (hay que permitir “Orígenes desconocidos” en Android si lo pide).

## Versión y build (referencia)

- En `pubspec.yaml`: `version: 1.0.0+1` → versión `1.0.0`, build `1`.
- Para cada release nuevo, sube **build_number** (y si quieres version): por ejemplo `1.0.1+2` y en Supabase `build_number = 2`.

Si no pones `download_url` en `app_releases`, el diálogo seguirá mostrando “Actualización disponible” y el mensaje, pero no habrá botón “Descargar” (útil si repartes el APK por otro medio).
