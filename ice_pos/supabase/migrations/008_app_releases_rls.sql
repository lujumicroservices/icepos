-- Permite que la app (anon) lea app_releases para "Comprobar actualización".
-- RLS + política permiten qué filas ver; GRANT da permiso de SELECT a anon.

alter table if exists public.app_releases enable row level security;

drop policy if exists "anon_all_app_releases" on public.app_releases;
create policy "anon_all_app_releases"
  on public.app_releases
  for all
  to anon
  using (true)
  with check (true);

-- Sin este GRANT, anon no puede leer aunque la política exista.
grant usage on schema public to anon;
grant select on public.app_releases to anon;
