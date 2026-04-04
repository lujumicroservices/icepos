-- Cross-device diagnostics for cierre de caja: pull movements, local commit, cloud sync.
-- Written by POS devices when Supabase is enabled; readable from web admin.

create table if not exists public.shift_close_events (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  event text not null,
  device_id text not null,
  device_name text not null,
  shift_id int,
  context jsonb
);

comment on table public.shift_close_events is
  'Auditoría de cierre de caja por dispositivo (pull movimientos, commit local, sync nube).';

create index if not exists idx_shift_close_events_created_at
  on public.shift_close_events (created_at desc);

alter table public.shift_close_events enable row level security;

drop policy if exists "anon_all_shift_close_events" on public.shift_close_events;
create policy "anon_all_shift_close_events" on public.shift_close_events
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_shift_close_events" on public.shift_close_events;
create policy "auth_all_shift_close_events" on public.shift_close_events
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
