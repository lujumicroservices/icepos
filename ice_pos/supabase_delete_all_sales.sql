-- Borra TODAS las ventas (y sus ítems) en Supabase.
-- Útil para iniciar el piloto con catálogo y turnos intactos.
-- Ejecutar en Supabase Dashboard > SQL Editor.

-- Primero los ítems (hijos), luego las ventas (padres)
truncate table public.sale_items restart identity cascade;
truncate table public.sales restart identity cascade;

-- Opcional: reiniciar el contador de IDs para que la próxima venta sea id = 1
select setval(pg_get_serial_sequence('public.sales', 'id'), 1);
select setval(pg_get_serial_sequence('public.sale_items', 'id'), 1);
