-- Unifica en la nube todas las operaciones con un solo terminal POS (UUID + nombre).
-- Ejecutar en Supabase SQL Editor o como migración cuando quieras normalizar datos históricos.
-- ATENCIÓN: borra filas en pos_devices que no sean la caja canónica (solo queda un registro).

do $$
declare
  canonical_id text := '0cfe96ba-43cf-42d1-ab69-d15568eff51d';
  canonical_name text := 'Caja eff51d';
begin
  update public.sales
  set
    device_id = canonical_id,
    device_name = canonical_name;

  update public.shifts
  set
    device_id = canonical_id,
    device_name = canonical_name;

  update public.shift_closures
  set closed_by_device_id = canonical_id;

  update public.shift_close_events
  set
    device_id = canonical_id,
    device_name = canonical_name;

  insert into public.pos_devices (
    device_id,
    device_name,
    last_seen_at,
    store_id
  )
  values (
    canonical_id,
    canonical_name,
    now(),
    1
  )
  on conflict (device_id) do update set
    device_name = excluded.device_name,
    last_seen_at = now();

  delete from public.pos_devices
  where device_id is distinct from canonical_id;
end $$;

notify pgrst, 'reload schema';
