-- Pedidos de delivery (Uber Eats, etc.). Las filas las inserta la integración (Edge Function / webhook).
-- La app solo lee para mostrar el listado por día.

create table if not exists public.platform_orders (
  id bigserial primary key,
  store_id int not null default 1 references public.stores (id),
  platform text not null,
  external_order_id text not null,
  status text not null default 'UNKNOWN',
  ordered_at timestamptz not null,
  total_amount real not null default 0,
  currency text,
  display_summary text,
  raw_json jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_orders_platform_external_unique unique (platform, external_order_id)
);

create index if not exists idx_platform_orders_store_ordered
  on public.platform_orders (store_id, ordered_at desc);

comment on table public.platform_orders is 'Pedidos externos por plataforma. Filtrar por día local en la app; ordered_at en UTC.';

alter table public.platform_orders enable row level security;

drop policy if exists "anon_all_platform_orders" on public.platform_orders;
create policy "anon_all_platform_orders" on public.platform_orders
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_platform_orders" on public.platform_orders;
create policy "auth_all_platform_orders" on public.platform_orders
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
