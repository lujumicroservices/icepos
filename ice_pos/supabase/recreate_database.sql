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
  cancelled_at timestamptz
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
  starting_fund real default 0
);

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
  notes text
);

-- Movements (entradas/salidas caja o banco; no son ventas)
create table public.movements (
  id serial primary key,
  date timestamptz not null default now(),
  type text not null,
  account text not null,
  amount real not null,
  reason text not null,
  shift_id int references public.shifts(id)
);
comment on table public.movements is 'Entradas y salidas de caja o banco que afectan el monto esperado; no son ventas.';

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

-- -----------------------------------------------------------------------------
-- 3. INDEXES
-- -----------------------------------------------------------------------------
create index idx_products_category on public.products(category_id);
create index idx_sale_items_sale on public.sale_items(sale_id);
create index idx_sales_date on public.sales(date desc);
create index idx_recipes_product on public.recipes(product_id);
create index idx_product_modifiers_product on public.product_modifiers(product_id);
create index idx_modifier_options_group on public.modifier_options(modifier_group_id);

-- -----------------------------------------------------------------------------
-- 4. RLS + POLICIES (anon and authenticated for all tables)
-- -----------------------------------------------------------------------------
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
alter table public.app_releases enable row level security;
alter table public.profiles enable row level security;

do $$
declare
  t text;
  tables text[] := array[
    'categories','supplies','products','recipes','sales','sale_items','inventory_logs',
    'modifier_groups','product_modifiers','modifier_options','parked_orders','discounts',
    'bundles','bundle_items','shifts','cash_movements','shift_closures','movements',
    'app_releases'
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
end;
$$;
grant execute on function public.sync_sequences() to anon;
grant execute on function public.sync_sequences() to authenticated;

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
