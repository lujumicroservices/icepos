-- Configurable temperature alert thresholds (per freezer) + notify dedupe.

create table if not exists public.temperature_alert_settings (
  freezer_key text primary key,
  min_c double precision not null,
  max_c double precision not null,
  stale_minutes int not null default 15 check (stale_minutes > 0),
  enabled boolean not null default true,
  notify_cooldown_minutes int not null default 15 check (notify_cooldown_minutes > 0),
  updated_at timestamptz not null default now(),
  constraint temperature_alert_settings_min_lt_max check (min_c < max_c)
);

comment on table public.temperature_alert_settings is
  'Umbrales de alerta de temperatura por congelador; editables desde la app admin.';

insert into public.temperature_alert_settings (freezer_key, min_c, max_c, stale_minutes, enabled, notify_cooldown_minutes)
values
  ('freezer1', -5, 8, 15, true, 15),
  ('freezer2', -25, -10, 15, true, 15)
on conflict (freezer_key) do nothing;

create table if not exists public.temperature_alert_events (
  sensor_id text not null,
  kind text not null,
  last_notified_at timestamptz not null default now(),
  last_value_c double precision,
  primary key (sensor_id, kind)
);

comment on table public.temperature_alert_events is
  'Anti-spam de push de temperatura (última notificación por sensor/kind).';

alter table public.temperature_alert_settings enable row level security;
alter table public.temperature_alert_events enable row level security;

drop policy if exists "anon_select_temperature_alert_settings" on public.temperature_alert_settings;
create policy "anon_select_temperature_alert_settings"
  on public.temperature_alert_settings for select to anon using (true);

drop policy if exists "auth_select_temperature_alert_settings" on public.temperature_alert_settings;
create policy "auth_select_temperature_alert_settings"
  on public.temperature_alert_settings for select to authenticated using (true);

-- Writes: anon/authenticated allowed for POS admin tablets (same pattern as other master tables).
drop policy if exists "anon_write_temperature_alert_settings" on public.temperature_alert_settings;
create policy "anon_write_temperature_alert_settings"
  on public.temperature_alert_settings for all to anon using (true) with check (true);

drop policy if exists "auth_write_temperature_alert_settings" on public.temperature_alert_settings;
create policy "auth_write_temperature_alert_settings"
  on public.temperature_alert_settings for all to authenticated using (true) with check (true);

-- Events: only service_role (edge) writes; app may select for UI.
drop policy if exists "anon_select_temperature_alert_events" on public.temperature_alert_events;
create policy "anon_select_temperature_alert_events"
  on public.temperature_alert_events for select to anon using (true);

drop policy if exists "auth_select_temperature_alert_events" on public.temperature_alert_events;
create policy "auth_select_temperature_alert_events"
  on public.temperature_alert_events for select to authenticated using (true);

grant select, insert, update, delete on public.temperature_alert_settings to anon, authenticated;
grant select on public.temperature_alert_events to anon, authenticated;
-- service_role bypasses RLS; grant for clarity on edge upsert/delete.
grant select, insert, update, delete on public.temperature_alert_events to service_role;

-- Schedule (applied on Luju POS): pg_cron job `evaluate-temperature-alerts-5min`
--   schedule: */5 * * * *  → POST /functions/v1/evaluate-temperature-alerts via pg_net.

-- Optional role on FCM tokens for admin-only temp alerts.
alter table if exists public.fcm_device_tokens
  add column if not exists role text;

create index if not exists fcm_device_tokens_store_admin_active_idx
  on public.fcm_device_tokens (store_id)
  where is_active = true and role = 'admin';
