-- Fuerza a PostgREST a recargar su caché de esquema.
-- Útil cuando app_releases (u otra tabla) tiene RLS y GRANT correctos pero la API sigue devolviendo [].
-- Ejecuta en SQL Editor y espera unos segundos antes de probar de nuevo.

NOTIFY pgrst, 'reload schema';
