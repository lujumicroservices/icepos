# Usuarios y permisos en la nube (Supabase)

Cuando Supabase está configurado (`.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY`), la **fuente de verdad** de usuarios y roles es la nube.

## Cómo funciona

- **Identidad**: Supabase Auth (correo + contraseña).
- **Rol**: tabla `public.profiles` (admin o cajero). Se rellena con un trigger al crear cada usuario en Auth.

## Migración 004

Ejecuta en **Supabase Dashboard > SQL Editor** la migración `supabase/migrations/004_profiles_auth.sql` para:

1. Crear la tabla `profiles` (id, role).
2. Activar RLS y policy para que cada usuario lea su propio perfil.
3. Trigger que inserta un perfil con rol `cajero` por defecto al dar de alta un usuario en Auth.

## Crear usuarios

1. **Supabase Dashboard > Authentication > Users > Add user** (o Invite).
2. Indica **Email** y **Password**. El trigger creará una fila en `profiles` con rol `cajero`.
3. Para dar rol **admin**: en **Table Editor > profiles**, edita la fila de ese usuario y pon `role = 'admin'`.

Si creas usuarios por API con `signUp`, puedes pasar el rol en metadata:

```dart
await supabase.auth.signUp(
  email: 'admin@tudominio.com',
  password: '...',
  data: {'role': 'admin'},
);
```

El trigger usa `raw_user_meta_data ->> 'role'` y, si no existe, usa `'cajero'`.

## Login en la app

- Con **nube activa**: el primer campo es "Usuario o correo". Si es la **primera vez** y escribes **admin** / **admin**, la app intenta crear automáticamente el usuario `admin@pos.local` en Supabase (con rol admin). Para que eso funcione, en Supabase debe estar activado el registro: **Authentication > Providers > Email > Enable email signups**.
- Si **admin** / **admin** no funciona: crea el usuario a mano en **Authentication > Users > Add user** (email: `admin@pos.local`, contraseña: `admin`). El trigger creará la fila en `profiles`; en **Table Editor > profiles** pon `role = 'admin'` para ese usuario.
- Sin nube: se usan usuarios locales (tabla `app_users` en Drift), con usuarios por defecto admin/admin y cajero/cajero.
