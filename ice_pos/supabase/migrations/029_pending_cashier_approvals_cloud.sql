-- Cola de aprobaciones cajero→admin visible en web y en caja (sync + Realtime).

create table if not exists public.pending_cashier_approvals (
  id uuid primary key default gen_random_uuid(),
  store_id int not null references public.stores (id),
  device_id text not null,
  kind text not null,
  payload jsonb not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint pending_cashier_approvals_status_ck
    check (status in ('pending', 'approved', 'rejected')),
  constraint pending_cashier_approvals_kind_ck
    check (kind in ('movement', 'sale_cancel', 'shift_close'))
);

comment on table public.pending_cashier_approvals is
  'Solicitudes del cajero que requieren aprobación; la caja inserta desde Drift y el admin aprueba en el mismo terminal o en web.';

create index if not exists pending_cashier_approvals_store_pending_idx
  on public.pending_cashier_approvals (store_id, created_at desc)
  where status = 'pending';

create index if not exists pending_cashier_approvals_device_idx
  on public.pending_cashier_approvals (device_id);

alter table public.pending_cashier_approvals enable row level security;

drop policy if exists "anon_all_pending_cashier_approvals" on public.pending_cashier_approvals;
create policy "anon_all_pending_cashier_approvals" on public.pending_cashier_approvals
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_pending_cashier_approvals" on public.pending_cashier_approvals;
create policy "auth_all_pending_cashier_approvals" on public.pending_cashier_approvals
  for all to authenticated using (true) with check (true);

alter publication supabase_realtime add table public.pending_cashier_approvals;
