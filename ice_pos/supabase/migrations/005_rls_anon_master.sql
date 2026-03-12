-- Permite que la app (clave anon o usuario autenticado) lea y escriba
-- categorías, productos, insumos, etc. Sin estas políticas, RLS devuelve
-- vacío y verás "La nube no tiene categorías".

do $$
declare
  t text;
  tables text[] := array[
    'categories', 'supplies', 'products', 'recipes',
    'modifier_groups', 'product_modifiers', 'modifier_options',
    'bundles', 'bundle_items',
    'sales', 'sale_items', 'inventory_logs',
    'shifts', 'shift_closures', 'cash_movements', 'movements'
  ];
begin
  foreach t in array tables
  loop
    execute format('alter table if exists public.%I enable row level security', t);
    execute format('drop policy if exists "anon_all_%s" on public.%I', t, t);
    execute format(
      'create policy "anon_all_%s" on public.%I for all to anon using (true) with check (true)',
      t, t
    );
    execute format('drop policy if exists "auth_all_%s" on public.%I', t, t);
    execute format(
      'create policy "auth_all_%s" on public.%I for all to authenticated using (true) with check (true)',
      t, t
    );
  end loop;
end $$;
