-- Fix serial sequences that fell behind max(id) (manual imports / sync with explicit ids).
-- Symptoms: insert hangs in UI or fails with supplies_pkey / products_pkey duplicate key.

select setval(
  pg_get_serial_sequence('public.supplies', 'id'),
  coalesce((select max(id) from public.supplies), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.products', 'id'),
  coalesce((select max(id) from public.products), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.categories', 'id'),
  coalesce((select max(id) from public.categories), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.bundles', 'id'),
  coalesce((select max(id) from public.bundles), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.bundle_items', 'id'),
  coalesce((select max(id) from public.bundle_items), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.recipes', 'id'),
  coalesce((select max(id) from public.recipes), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.modifier_groups', 'id'),
  coalesce((select max(id) from public.modifier_groups), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.modifier_options', 'id'),
  coalesce((select max(id) from public.modifier_options), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.product_modifiers', 'id'),
  coalesce((select max(id) from public.product_modifiers), 1),
  true
);

select setval(
  pg_get_serial_sequence('public.discounts', 'id'),
  coalesce((select max(id) from public.discounts), 1),
  true
);
