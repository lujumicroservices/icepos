-- 007: Agregar columna category_id a bundles (para agrupar bundles por categoría).
-- Ejecutar una vez si la tabla bundles ya existía sin esta columna.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'bundles' and column_name = 'category_id'
  ) then
    alter table public.bundles add column category_id int references public.categories(id);
    comment on column public.bundles.category_id is 'Categoría del bundle (opcional).';
  end if;
end $$;
