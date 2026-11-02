-- App (anon/authenticated) may read sensor_readings written by Azure service_role.

alter table if exists public.sensor_readings enable row level security;

drop policy if exists "anon_select_sensor_readings" on public.sensor_readings;
create policy "anon_select_sensor_readings"
  on public.sensor_readings
  for select
  to anon
  using (true);

drop policy if exists "auth_select_sensor_readings" on public.sensor_readings;
create policy "auth_select_sensor_readings"
  on public.sensor_readings
  for select
  to authenticated
  using (true);

grant select on public.sensor_readings to anon, authenticated;
