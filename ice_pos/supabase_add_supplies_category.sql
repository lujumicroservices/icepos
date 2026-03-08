-- Ejecuta esto en Supabase > SQL Editor si obtienes: column "category" of relation "public.supplies" does not exist
-- Añade la columna category a la tabla supplies (una sola vez).

alter table public.supplies add column if not exists category text;
comment on column public.supplies.category is 'Categoría para agrupar insumos (ej. Lácteos, Sabores). Opcional.';
