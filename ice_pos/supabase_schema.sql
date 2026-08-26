-- Supabase: single source of truth for POS data.
-- Run in Supabase Dashboard > SQL Editor. Then seed data (app "Enviar datos a la nube" or "Sincronizar").
-- ID alignment: the app inserts with explicit id (local id = cloud id) and calls sync_sequences() after push.

-- 1. Categories (root and subcategories)
create table if not exists public.categories (
  id serial primary key,
  name text not null,
  parent_id int references public.categories(id),
  color text,
  image_url text
);

-- 2. Supplies (raw materials)
create table if not exists public.supplies (
  id serial primary key,
  name text not null,
  current_stock real not null default 0,
  unit text not null,
  cost_per_unit real default 0,
  reorder_point real default 0,
  category text
);
comment on column public.supplies.category is 'Categoría para agrupar insumos (ej. Lácteos, Sabores). Opcional.';

-- 3. Products
create table if not exists public.products (
  id serial primary key,
  name text not null,
  price real not null,
  employee_price real,
  image_url text,
  is_active boolean not null default true,
  category_id int references public.categories(id)
);

-- 4. Recipes (product -> supply)
create table if not exists public.recipes (
  id serial primary key,
  product_id int not null references public.products(id) on delete cascade,
  supply_id int not null references public.supplies(id),
  quantity_required real not null
);

-- 5. Sales (device_id identifica el dispositivo que registró la venta; device_name es opcional, ej. "Caja 1")
create table if not exists public.sales (
  id serial primary key,
  date timestamptz not null default now(),
  total_amount real not null,
  payment_method text default 'CASH',
  amount_tendered real default 0,
  change_given real default 0,
  device_id text,
  device_name text
);

-- 6. Sale items
create table if not exists public.sale_items (
  id serial primary key,
  sale_id int not null references public.sales(id) on delete cascade,
  product_id int not null references public.products(id),
  quantity real not null,
  unit_price real not null
);

-- 7. Inventory logs
create table if not exists public.inventory_logs (
  id serial primary key,
  supply_id int not null references public.supplies(id),
  change_amount real not null,
  reason text not null,
  date timestamptz not null default now()
);

-- 8. Modifier groups
create table if not exists public.modifier_groups (
  id serial primary key,
  name text not null,
  min_selection int default 0,
  max_selection int not null
);

-- 9. Product -> modifier group
create table if not exists public.product_modifiers (
  id serial primary key,
  product_id int not null references public.products(id) on delete cascade,
  modifier_group_id int not null references public.modifier_groups(id) on delete cascade
);

-- 10. Modifier options (group -> supply)
create table if not exists public.modifier_options (
  id serial primary key,
  modifier_group_id int not null references public.modifier_groups(id) on delete cascade,
  supply_id int not null references public.supplies(id),
  quantity_deducted real not null,
  price_extra real default 0,
  image_url text
);

-- 11. Parked orders
create table if not exists public.parked_orders (
  id serial primary key,
  customer_name text,
  items_json text not null,
  parked_at timestamptz not null default now(),
  total_amount real not null
);

-- 12. Discounts
-- type: 'percentage' | 'employee'
create table if not exists public.discounts (
  id serial primary key,
  code text not null unique,
  type text not null default 'percentage',
  percentage real not null,
  description text,
  is_active boolean not null default true
);

-- 13. Bundles
create table if not exists public.bundles (
  id serial primary key,
  name text not null,
  price real not null,
  is_active boolean not null default true,
  category_id int references public.categories(id)
);

-- 14. Bundle items
create table if not exists public.bundle_items (
  id serial primary key,
  bundle_id int not null references public.bundles(id) on delete cascade,
  product_id int not null references public.products(id),
  quantity real not null default 1
);

-- 15. Shifts
create table if not exists public.shifts (
  id serial primary key,
  start_time timestamptz not null default now(),
  end_time timestamptz,
  starting_fund real default 0
);

-- 16. Cash movements
create table if not exists public.cash_movements (
  id serial primary key,
  shift_id int not null references public.shifts(id),
  amount real not null,
  reason text not null,
  date timestamptz not null default now()
);

-- 17. Shift closures
create table if not exists public.shift_closures (
  id serial primary key,
  shift_id int not null references public.shifts(id),
  closing_time timestamptz not null default now(),
  system_expected_cash real not null,
  declared_cash real not null,
  difference real not null,
  notes text
);

-- 17.5 Movements (entradas/salidas de caja o banco; no son ventas)
-- type: ENTRADA | SALIDA, account: CAJA | BANCO. amount siempre positivo.
-- shift_id opcional: si account=CAJA, puede asociarse al turno en curso.
create table if not exists public.movements (
  id serial primary key,
  date timestamptz not null default now(),
  type text not null,
  account text not null,
  amount real not null,
  reason text not null,
  shift_id int references public.shifts(id)
);
comment on table public.movements is 'Entradas y salidas de caja o banco que afectan el monto esperado; no son ventas.';

-- 18. App releases (para avisar a empleados de nueva versión sin Google Play)
create table if not exists public.app_releases (
  id serial primary key,
  version text not null,
  build_number int not null,
  download_url text,
  message_es text,
  created_at timestamptz not null default now()
);
comment on table public.app_releases is 'Última versión disponible. La app compara build_number con el instalado y muestra enlace de descarga si hay actualización.';

-- Indexes
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_sale_items_sale on public.sale_items(sale_id);
create index if not exists idx_sales_date on public.sales(date desc);
create index if not exists idx_recipes_product on public.recipes(product_id);
create index if not exists idx_product_modifiers_product on public.product_modifiers(product_id);
create index if not exists idx_modifier_options_group on public.modifier_options(modifier_group_id);

-- RLS: allow anon to read/write (POS app). Tighten in production with auth.
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

do $$
declare t text;
begin
  for t in select unnest(array['categories','supplies','products','recipes','sales','sale_items','inventory_logs','modifier_groups','product_modifiers','modifier_options','parked_orders','discounts','bundles','bundle_items','shifts','cash_movements','shift_closures','movements','app_releases'])
  loop
    execute format('drop policy if exists "anon_all_%s" on public.%I', t, t);
    execute format('create policy "anon_all_%s" on public.%I for all to anon using (true) with check (true)', t, t);
  end loop;
end $$;

-- After push (insert with explicit id), call this so next serial id does not conflict.
-- Enables ID alignment: local and cloud use the same ids for categories, supplies, products, etc.
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

-- Migraciones incrementales: ver carpeta supabase/migrations/ (001_..., 002_..., etc.).
