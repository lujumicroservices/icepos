-- Registro de terminales POS y vínculo turno↔dispositivo para cortes y ventas por caja.

create table if not exists public.pos_devices (
  device_id text primary key,
  device_name text not null,
  last_seen_at timestamptz not null default now(),
  app_version text,
  platform text
);
comment on table public.pos_devices is 'Terminales que se registran explícitamente desde la app (botón o al sincronizar turno).';

alter table public.shifts
  add column if not exists device_id text,
  add column if not exists device_name text;
comment on column public.shifts.device_id is 'Dispositivo que abrió el turno (UUID estable de la app).';
comment on column public.shifts.device_name is 'Nombre legible de la caja (ej. Caja 1).';

alter table public.shift_closures
  add column if not exists closure_kind text not null default 'device',
  add column if not exists closed_by_device_id text;
comment on column public.shift_closures.closure_kind is 'device | admin_remote';
comment on column public.shift_closures.closed_by_device_id is 'Dispositivo que ejecutó el cierre (POS o admin desde otro equipo).';

create index if not exists idx_shifts_device_open
  on public.shifts (device_id)
  where end_time is null;

create index if not exists idx_shifts_device_id on public.shifts (device_id);

alter table public.pos_devices enable row level security;

drop policy if exists "anon_all_pos_devices" on public.pos_devices;
create policy "anon_all_pos_devices" on public.pos_devices
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_pos_devices" on public.pos_devices;
create policy "auth_all_pos_devices" on public.pos_devices
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
