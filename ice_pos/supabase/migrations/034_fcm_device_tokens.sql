-- FCM tokens for Android/iOS native push (staff tasks, approvals, etc.).

create table if not exists public.fcm_device_tokens (
  token text primary key,
  store_id int not null references public.stores (id),
  device_id text,
  user_id text,
  platform text not null default 'android',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.fcm_device_tokens is
  'Token FCM por dispositivo; la edge function envía notificaciones a la tienda.';

create index if not exists fcm_device_tokens_store_active_idx
  on public.fcm_device_tokens (store_id)
  where is_active = true;

alter table public.fcm_device_tokens enable row level security;

drop policy if exists "anon_all_fcm_device_tokens" on public.fcm_device_tokens;
create policy "anon_all_fcm_device_tokens" on public.fcm_device_tokens
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_fcm_device_tokens" on public.fcm_device_tokens;
create policy "auth_all_fcm_device_tokens" on public.fcm_device_tokens
  for all to authenticated using (true) with check (true);
