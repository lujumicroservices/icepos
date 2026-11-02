-- Permitir que el ESP32 (y otros clientes con anon/publishable key)
-- inserten lecturas en temperature_readings.

alter table if exists public.temperature_readings enable row level security;

drop policy if exists "anon_insert_temperature_readings" on public.temperature_readings;
create policy "anon_insert_temperature_readings"
  on public.temperature_readings
  for insert
  to anon
  with check (true);

drop policy if exists "auth_insert_temperature_readings" on public.temperature_readings;
create policy "auth_insert_temperature_readings"
  on public.temperature_readings
  for insert
  to authenticated
  with check (true);

grant insert on public.temperature_readings to anon, authenticated;
