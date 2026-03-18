-- Diagnóstico: ejecuta en SQL Editor (como postgres/admin) para ver políticas y permisos de app_releases.
-- No cambia nada, solo consultas.

-- 1. ¿Existe la tabla y tiene filas?
select 'app_releases existe' as check_name, count(*) as filas from public.app_releases;

-- 2. Políticas RLS en app_releases
select schemaname, tablename, policyname, permissive, roles, cmd, qual
from pg_policies
where tablename = 'app_releases';

-- 3. Permisos de la tabla (anon debe tener SELECT)
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'app_releases'
order by grantee, privilege_type;

-- Si todo lo anterior está bien pero la API sigue devolviendo []:
-- PostgREST puede tener la tabla fuera de su caché. Ejecuta en otra pestaña del SQL Editor:
--   NOTIFY pgrst, 'reload schema';
-- Luego espera unos segundos y prueba de nuevo la app o scripts\test_app_releases_api.ps1
