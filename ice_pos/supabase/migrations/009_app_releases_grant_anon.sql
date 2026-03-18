-- El rol anon necesita GRANT explícito para poder leer la tabla (RLS solo filtra; no concede permiso).
-- Si 008 ya aplicó la política pero la API sigue devolviendo [], ejecuta esta migración.

grant usage on schema public to anon;
grant select on public.app_releases to anon;
