-- Borra TODOS los datos de la nube (Supabase). Ejecutar en Dashboard > SQL Editor.
-- Para base NUEVA: ejecuta solo supabase_schema.sql (este script no aplica).
-- Después de truncar: en el dispositivo con el menú cargado, usa "Enviar datos a la nube" para subir de nuevo.

-- Orden por dependencias FK (hijos antes que padres). RESTART IDENTITY resetea los serials.
truncate table public.sale_items           restart identity cascade;
truncate table public.inventory_logs       restart identity cascade;
truncate table public.modifier_options     restart identity cascade;
truncate table public.product_modifiers    restart identity cascade;
truncate table public.recipes              restart identity cascade;
truncate table public.bundle_items         restart identity cascade;
truncate table public.sales                restart identity cascade;
truncate table public.modifier_groups      restart identity cascade;
truncate table public.bundles              restart identity cascade;
truncate table public.products             restart identity cascade;
truncate table public.supplies             restart identity cascade;
truncate table public.categories           restart identity cascade;
truncate table public.parked_orders        restart identity cascade;
truncate table public.discounts            restart identity cascade;
truncate table public.cash_movements       restart identity cascade;
truncate table public.shift_closures       restart identity cascade;
truncate table public.shifts               restart identity cascade;
truncate table public.app_releases         restart identity cascade;
