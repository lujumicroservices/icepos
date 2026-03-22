-- Verificación rápida: recetas en Supabase y FK
-- Ejecutar en: Supabase → SQL Editor

-- 1) Totales
select
  (select count(*) from public.recipes) as recipes_count,
  (select count(*) from public.products) as products_count,
  (select count(*) from public.supplies) as supplies_count;

-- 2) Recetas que no apuntan a un producto o insumo válido (debería ser 0)
select r.*
from public.recipes r
left join public.products p on p.id = r.product_id
left join public.supplies s on s.id = r.supply_id
where p.id is null or s.id is null;

-- 3) Top productos por número de líneas de receta
select r.product_id, p.name as product_name, count(*) as recipe_lines
from public.recipes r
join public.products p on p.id = r.product_id
group by r.product_id, p.name
order by recipe_lines desc
limit 30;
