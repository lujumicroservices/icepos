-- Lectura (y opcionalmente inserción) de temperature_readings para la app con anon key.
-- Ajusta las políticas según tu modelo: si solo un backend inserta con service_role,
-- aquí basta con SELECT para anon/authenticated.

alter table if exists public.temperature_readings enable row level security;

drop policy if exists "anon_select_temperature_readings" on public.temperature_readings;
create policy "anon_select_temperature_readings"
  on public.temperature_readings
  for select
  to anon
  using (true);

drop policy if exists "auth_select_temperature_readings" on public.temperature_readings;
create policy "auth_select_temperature_readings"
  on public.temperature_readings
  for select
  to authenticated
  using (true);

-- Descomenta si quieres que dispositivos con anon key inserten lecturas desde la app:
-- drop policy if exists "anon_insert_temperature_readings" on public.temperature_readings;
-- create policy "anon_insert_temperature_readings"
--   on public.temperature_readings
--   for insert
--   to anon
--   with check (true);
