-- Habilitar Realtime para tablas que deben sincronizarse entre dispositivos.
-- Si alguna tabla ya está en la publicación, ejecutar solo las líneas que falten o ignorar el error.
alter publication supabase_realtime add table public.categories;
alter publication supabase_realtime add table public.supplies;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.recipes;
alter publication supabase_realtime add table public.modifier_groups;
alter publication supabase_realtime add table public.product_modifiers;
alter publication supabase_realtime add table public.modifier_options;
alter publication supabase_realtime add table public.bundles;
alter publication supabase_realtime add table public.bundle_items;
