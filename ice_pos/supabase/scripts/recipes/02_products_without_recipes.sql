-- Productos activos que no tienen ninguna fila en recipes
-- Útil para cruzar con el CSV (filas ERR_NO_PRODUCT / SKIP_EMPTY / ERR_NO_SUPPLY)

select p.id, p.name, p.category_id, p.is_active
from public.products p
where p.is_active = true
  and not exists (
    select 1 from public.recipes r where r.product_id = p.id
  )
order by p.name;
