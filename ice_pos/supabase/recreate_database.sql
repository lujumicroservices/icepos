-- =============================================================================
-- RECREATE DATABASE FROM SCRATCH (Supabase / PostgreSQL)
-- =============================================================================
-- Run this in Supabase Dashboard > SQL Editor to drop all public tables and
-- recreate the full schema. ALL DATA IN PUBLIC TABLES WILL BE LOST.
-- auth.users is NOT touched; only public schema tables and the profiles trigger.
--
-- After running: use the app "Sincronizar" / "Enviar datos a la nube" to push
-- local data, or seed manually.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. DROP: trigger, function, then all public tables (dependents first)
-- -----------------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

drop table if exists public.profiles cascade;
drop table if exists public.shift_closures cascade;
drop table if exists public.cash_movements cascade;
drop table if exists public.movements cascade;
drop table if exists public.sale_items cascade;
drop table if exists public.inventory_logs cascade;
drop table if exists public.recipes cascade;
drop table if exists public.product_modifiers cascade;
drop table if exists public.modifier_options cascade;
drop table if exists public.bundle_items cascade;
drop table if exists public.sales cascade;
drop table if exists public.products cascade;
drop table if exists public.modifier_groups cascade;
drop table if exists public.bundles cascade;
drop table if exists public.supplies cascade;
drop table if exists public.categories cascade;
drop table if exists public.parked_orders cascade;
drop table if exists public.discounts cascade;
drop table if exists public.shifts cascade;
drop table if exists public.shift_close_events cascade;
drop table if exists public.pos_devices cascade;
drop table if exists public.platform_orders cascade;
drop table if exists public.pos_registers cascade;
drop table if exists public.stores cascade;
drop table if exists public.app_releases cascade;

-- -----------------------------------------------------------------------------
-- 2. TABLES
-- -----------------------------------------------------------------------------

-- Categories (root and subcategories)
create table public.categories (
  id serial primary key,
  name text not null,
  parent_id int references public.categories(id),
  color text,
  image_url text
);

-- Supplies (raw materials)
create table public.supplies (
  id serial primary key,
  name text not null,
  current_stock real not null default 0,
  unit text not null,
  cost_per_unit real default 0,
  reorder_point real default 0,
  category text
);
comment on column public.supplies.category is 'Categoría para agrupar insumos (ej. Lácteos, Sabores). Opcional.';

-- Products
create table public.products (
  id serial primary key,
  name text not null,
  price real not null,
  image_url text,
  is_active boolean not null default true,
  category_id int references public.categories(id)
);

-- Recipes (product -> supply)
create table public.recipes (
  id serial primary key,
  product_id int not null references public.products(id) on delete cascade,
  supply_id int not null references public.supplies(id),
  quantity_required real not null
);

-- Stores (sucursales; semilla id=1)
create table public.stores (
  id serial primary key,
  name text not null,
  created_at timestamptz not null default now()
);
comment on table public.stores is 'Sucursales. App envía store_id (por defecto 1).';

insert into public.stores (id, name) values (1, 'Tienda principal');
select setval(
  pg_get_serial_sequence('public.stores', 'id'),
  (select max(id) from public.stores)
);

-- Cash drawers / registers per store (logical caja)
create table public.pos_registers (
  id serial primary key,
  store_id int not null references public.stores(id) on delete cascade,
  label text not null,
  display_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint pos_registers_store_label_unique unique (store_id, label)
);
comment on table public.pos_registers is 'Cajón o estación de caja; enlaza turnos y terminales.';

insert into public.pos_registers (id, store_id, label, display_order) values (1, 1, 'Caja 1', 0);
select setval(
  pg_get_serial_sequence('public.pos_registers', 'id'),
  (select max(id) from public.pos_registers)
);

-- Sales
create table public.sales (
  id serial primary key,
  date timestamptz not null default now(),
  total_amount real not null,
  payment_method text default 'CASH',
  amount_tendered real default 0,
  change_given real default 0,
  device_id text,
  device_name text,
  cancelled_at timestamptz,
  store_id int not null default 1 references public.stores(id)
);
comment on column public.sales.cancelled_at is 'Si no es null, la venta fue cancelada (borrado lógico).';

-- Sale items
create table public.sale_items (
  id serial primary key,
  sale_id int not null references public.sales(id) on delete cascade,
  product_id int not null references public.products(id),
  quantity real not null,
  unit_price real not null
);

-- Inventory logs
create table public.inventory_logs (
  id serial primary key,
  supply_id int not null references public.supplies(id),
  change_amount real not null,
  reason text not null,
  date timestamptz not null default now()
);

-- Modifier groups
create table public.modifier_groups (
  id serial primary key,
  name text not null,
  min_selection int default 0,
  max_selection int not null
);

-- Product -> modifier group
create table public.product_modifiers (
  id serial primary key,
  product_id int not null references public.products(id) on delete cascade,
  modifier_group_id int not null references public.modifier_groups(id) on delete cascade
);

-- Modifier options
create table public.modifier_options (
  id serial primary key,
  modifier_group_id int not null references public.modifier_groups(id) on delete cascade,
  supply_id int not null references public.supplies(id),
  quantity_deducted real not null,
  price_extra real default 0
);

-- Parked orders
create table public.parked_orders (
  id serial primary key,
  customer_name text,
  items_json text not null,
  parked_at timestamptz not null default now(),
  total_amount real not null
);

-- Discounts
create table public.discounts (
  id serial primary key,
  code text not null unique,
  percentage real not null,
  description text,
  is_active boolean not null default true
);

-- Bundles
create table public.bundles (
  id serial primary key,
  name text not null,
  price real not null,
  is_active boolean not null default true,
  category_id int references public.categories(id)
);

-- Bundle items
create table public.bundle_items (
  id serial primary key,
  bundle_id int not null references public.bundles(id) on delete cascade,
  product_id int not null references public.products(id),
  quantity real not null default 1
);

-- Shifts
create table public.shifts (
  id serial primary key,
  start_time timestamptz not null default now(),
  end_time timestamptz,
  starting_fund real default 0,
  device_id text,
  device_name text,
  store_id int not null default 1 references public.stores(id),
  register_id int references public.pos_registers(id) on delete set null
);
comment on column public.shifts.device_id is 'Dispositivo que abrió el turno (UUID estable de la app).';
comment on column public.shifts.device_name is 'Nombre legible de la caja.';
comment on column public.shifts.register_id is 'Cajón lógico; corte y ventas por turno aunque cambie el terminal.';

alter table public.sales
  add column shift_id int not null references public.shifts(id) on delete restrict;
comment on column public.sales.shift_id is 'Turno en nube (shifts.id); obligatorio en cada venta.';

-- Cash movements
create table public.cash_movements (
  id serial primary key,
  shift_id int not null references public.shifts(id),
  amount real not null,
  reason text not null,
  date timestamptz not null default now()
);

-- Shift closures
create table public.shift_closures (
  id serial primary key,
  shift_id int not null references public.shifts(id),
  closing_time timestamptz not null default now(),
  system_expected_cash real not null,
  declared_cash real not null,
  difference real not null,
  notes text,
  closure_kind text not null default 'device',
  closed_by_device_id text
);
comment on column public.shift_closures.closure_kind is 'device | admin_remote';
comment on column public.shift_closures.closed_by_device_id is 'Dispositivo que ejecutó el cierre.';

-- Movements (entradas/salidas caja o banco; no son ventas)
create table public.movements (
  id serial primary key,
  date timestamptz not null default now(),
  type text not null,
  account text not null,
  amount real not null,
  reason text not null,
  shift_id int references public.shifts(id),
  store_id int not null default 1 references public.stores(id)
);
comment on table public.movements is 'Entradas y salidas de caja o banco que afectan el monto esperado; no son ventas.';

-- Shift close diagnostics (multi-device observability)
create table public.shift_close_events (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  event text not null,
  device_id text not null,
  device_name text not null,
  shift_id int,
  context jsonb,
  store_id int references public.stores(id)
);
comment on table public.shift_close_events is 'Auditoría de cierre de caja por dispositivo (pull movimientos, commit local, sync nube).';
create index idx_shift_close_events_created_at on public.shift_close_events (created_at desc);

-- Terminales POS registrados desde la app
create table public.pos_devices (
  device_id text primary key,
  device_name text not null,
  last_seen_at timestamptz not null default now(),
  app_version text,
  platform text,
  store_id int not null default 1 references public.stores(id),
  register_id int references public.pos_registers(id) on delete set null,
  remote_update_requested_at timestamptz,
  remote_update_message text
);
comment on table public.pos_devices is 'Registro explícito de cajas/dispositivos (botón en la app).';
comment on column public.pos_devices.remote_update_requested_at is 'Admin: señal para que la caja compruebe actualización (pull).';
comment on column public.pos_devices.remote_update_message is 'Mensaje opcional en el aviso en la caja.';

create index idx_shifts_device_open on public.shifts (device_id) where end_time is null;
create index idx_shifts_device_id on public.shifts (device_id);
create index idx_shifts_store_id on public.shifts (store_id);
create index idx_shifts_register_open on public.shifts (store_id, register_id) where end_time is null;
create index idx_sales_shift_id on public.sales (shift_id);
create index idx_pos_registers_store on public.pos_registers (store_id) where active = true;

-- App releases (actualizaciones de la app)
create table public.app_releases (
  id serial primary key,
  version text not null,
  build_number int not null,
  download_url text,
  message_es text,
  created_at timestamptz not null default now()
);
comment on table public.app_releases is 'Última versión disponible. La app compara build_number con el instalado.';

-- Profiles (roles admin/cajero; fuente de verdad en nube)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'cajero' check (role in ('admin', 'cajero'))
);
comment on table public.profiles is 'Rol de cada usuario (admin/cajero). Fuente de verdad en nube.';

-- Delivery platform orders (Uber Eats, etc.); populated by integration, read by app.
create table public.platform_orders (
  id bigserial primary key,
  store_id int not null default 1 references public.stores(id),
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
comment on table public.platform_orders is 'Pedidos externos; ordered_at en UTC; app filtra por día local.';

-- Cajero → admin: cola sincronizada con la app y aprobable desde web.
create table public.pending_cashier_approvals (
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
create index idx_pending_cashier_approvals_store_pending
  on public.pending_cashier_approvals (store_id, created_at desc)
  where status = 'pending';

-- -----------------------------------------------------------------------------
-- 3. INDEXES
-- -----------------------------------------------------------------------------
create index idx_products_category on public.products(category_id);
create index idx_sale_items_sale on public.sale_items(sale_id);
create index idx_sales_date on public.sales(date desc);
create index idx_sales_store_date on public.sales(store_id, date desc);
create index idx_platform_orders_store_ordered on public.platform_orders(store_id, ordered_at desc);
create index idx_recipes_product on public.recipes(product_id);
create index idx_product_modifiers_product on public.product_modifiers(product_id);
create index idx_modifier_options_group on public.modifier_options(modifier_group_id);

-- -----------------------------------------------------------------------------
-- 4. RLS + POLICIES (anon and authenticated for all tables)
-- -----------------------------------------------------------------------------
alter table public.stores enable row level security;
alter table public.categories enable row level security;
alter table public.supplies enable row level security;
alter table public.products enable row level security;
alter table public.recipes enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.inventory_logs enable row level security;
alter table public.modifier_groups enable row level security;
alter table public.product_modifiers enable row level security;
alter table public.modifier_options enable row level security;
alter table public.parked_orders enable row level security;
alter table public.discounts enable row level security;
alter table public.bundles enable row level security;
alter table public.bundle_items enable row level security;
alter table public.shifts enable row level security;
alter table public.cash_movements enable row level security;
alter table public.shift_closures enable row level security;
alter table public.movements enable row level security;
alter table public.shift_close_events enable row level security;
alter table public.pos_devices enable row level security;
alter table public.pos_registers enable row level security;
alter table public.app_releases enable row level security;
alter table public.profiles enable row level security;
alter table public.platform_orders enable row level security;
alter table public.pending_cashier_approvals enable row level security;

do $$
declare
  t text;
  tables text[] := array[
    'stores','categories','supplies','products','recipes','sales','sale_items','inventory_logs',
    'modifier_groups','product_modifiers','modifier_options','parked_orders','discounts',
    'bundles','bundle_items','shifts','cash_movements','shift_closures','movements',
    'shift_close_events','pos_devices','pos_registers','app_releases','platform_orders',
    'pending_cashier_approvals'
  ];
begin
  foreach t in array tables loop
    execute format('drop policy if exists "anon_all_%s" on public.%I', t, t);
    execute format('create policy "anon_all_%s" on public.%I for all to anon using (true) with check (true)', t, t);
    execute format('drop policy if exists "auth_all_%s" on public.%I', t, t);
    execute format('create policy "auth_all_%s" on public.%I for all to authenticated using (true) with check (true)', t, t);
  end loop;
end $$;

-- Profiles: each user can read own profile only
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles
  for select using (auth.uid() = id);

-- app_releases: anon must be able to read (check for updates)
drop policy if exists "anon_all_app_releases" on public.app_releases;
create policy "anon_all_app_releases" on public.app_releases for all to anon using (true) with check (true);

-- -----------------------------------------------------------------------------
-- 5. GRANTS (anon can read app_releases; schema usage)
-- -----------------------------------------------------------------------------
grant usage on schema public to anon;
grant select on public.app_releases to anon;

-- -----------------------------------------------------------------------------
-- 6. FUNCTIONS
-- -----------------------------------------------------------------------------
create or replace function public.sync_sequences()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform setval(pg_get_serial_sequence('stores', 'id'), coalesce((select max(id) from stores), 1));
  perform setval(
    pg_get_serial_sequence('pos_registers', 'id'),
    coalesce((select max(id) from pos_registers), 1)
  );
  perform setval(pg_get_serial_sequence('categories', 'id'), coalesce((select max(id) from categories), 1));
  perform setval(pg_get_serial_sequence('supplies', 'id'), coalesce((select max(id) from supplies), 1));
  perform setval(pg_get_serial_sequence('products', 'id'), coalesce((select max(id) from products), 1));
  perform setval(pg_get_serial_sequence('recipes', 'id'), coalesce((select max(id) from recipes), 1));
  perform setval(pg_get_serial_sequence('sales', 'id'), coalesce((select max(id) from sales), 1));
  perform setval(pg_get_serial_sequence('sale_items', 'id'), coalesce((select max(id) from sale_items), 1));
  perform setval(pg_get_serial_sequence('inventory_logs', 'id'), coalesce((select max(id) from inventory_logs), 1));
  perform setval(pg_get_serial_sequence('modifier_groups', 'id'), coalesce((select max(id) from modifier_groups), 1));
  perform setval(pg_get_serial_sequence('product_modifiers', 'id'), coalesce((select max(id) from product_modifiers), 1));
  perform setval(pg_get_serial_sequence('modifier_options', 'id'), coalesce((select max(id) from modifier_options), 1));
  perform setval(pg_get_serial_sequence('parked_orders', 'id'), coalesce((select max(id) from parked_orders), 1));
  perform setval(pg_get_serial_sequence('discounts', 'id'), coalesce((select max(id) from discounts), 1));
  perform setval(pg_get_serial_sequence('bundles', 'id'), coalesce((select max(id) from bundles), 1));
  perform setval(pg_get_serial_sequence('bundle_items', 'id'), coalesce((select max(id) from bundle_items), 1));
  perform setval(pg_get_serial_sequence('shifts', 'id'), coalesce((select max(id) from shifts), 1));
  perform setval(pg_get_serial_sequence('cash_movements', 'id'), coalesce((select max(id) from cash_movements), 1));
  perform setval(pg_get_serial_sequence('shift_closures', 'id'), coalesce((select max(id) from shift_closures), 1));
  perform setval(pg_get_serial_sequence('movements', 'id'), coalesce((select max(id) from movements), 1));
  perform setval(
    pg_get_serial_sequence('platform_orders', 'id'),
    coalesce((select max(id) from platform_orders), 1)
  );
end;
$$;
grant execute on function public.sync_sequences() to anon;
grant execute on function public.sync_sequences() to authenticated;

-- Movements: mobile upsert sends explicit ids (SQLite) without advancing serial; web INSERT must not reuse ids.
create or replace function public.movements_before_insert_sync_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  seq regclass;
  m bigint;
begin
  perform pg_advisory_xact_lock(87392001);

  seq := pg_get_serial_sequence('public.movements', 'id')::regclass;
  if seq is null then
    return new;
  end if;

  m := (select coalesce(max(id), 0) from public.movements);

  if exists (select 1 from public.movements where id = new.id) then
    new.id := m + 1;
    perform setval(seq, new.id, true);
  else
    perform setval(seq, greatest(m, new.id), true);
  end if;

  return new;
end;
$$;

drop trigger if exists movements_before_insert_sync_id on public.movements;
create trigger movements_before_insert_sync_id
before insert on public.movements
for each row
execute procedure public.movements_before_insert_sync_id();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'role', 'cajero'));
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Backfill existing auth users (no-op if none)
insert into public.profiles (id, role)
select id, 'cajero' from auth.users
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- 7. POSTGREST: reload schema cache (optional, for Supabase)
-- -----------------------------------------------------------------------------
notify pgrst, 'reload schema';

-- -----------------------------------------------------------------------------
-- 8. REALTIME: habilitar tablas para sincronización entre dispositivos
-- -----------------------------------------------------------------------------
alter publication supabase_realtime add table public.categories;
alter publication supabase_realtime add table public.supplies;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.recipes;
alter publication supabase_realtime add table public.modifier_groups;
alter publication supabase_realtime add table public.product_modifiers;
alter publication supabase_realtime add table public.modifier_options;
alter publication supabase_realtime add table public.bundles;
alter publication supabase_realtime add table public.bundle_items;
alter publication supabase_realtime add table public.platform_orders;
alter publication supabase_realtime add table public.pending_cashier_approvals;
