-- 001: Agregar columna category a supplies (categoría para agrupar insumos).
-- Ejecutar una vez si la tabla supplies ya existía sin esta columna.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'supplies' and column_name = 'category'
  ) then
    alter table public.supplies add column category text;
    comment on column public.supplies.category is 'Categoría para agrupar insumos (ej. Lácteos, Sabores). Opcional.';
  end if;
end $$;
