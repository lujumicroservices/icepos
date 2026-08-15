-- POS strip "más vendidos": aggregate sale_items from Supabase (not local SQLite).

create or replace function public.pos_top_selling_product_ids(
  p_days integer,
  p_limit integer,
  p_store_id integer default null
)
returns table (
  product_id bigint,
  qty_sum double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    si.product_id::bigint,
    sum(si.quantity)::double precision as qty_sum
  from public.sale_items si
  inner join public.sales s on s.id = si.sale_id
  where s.cancelled_at is null
    and s.date >= (timezone('utc', now()) - make_interval(days => greatest(coalesce(p_days, 30), 1)))
    and (p_store_id is null or s.store_id = p_store_id)
  group by si.product_id
  order by qty_sum desc
  limit greatest(coalesce(p_limit, 12), 1);
$$;

comment on function public.pos_top_selling_product_ids(integer, integer, integer) is
  'POS: product_id ordered by sum(quantity) on non-cancelled sales in the last p_days (UTC). Optional p_store_id filters sales.store_id.';

revoke all on function public.pos_top_selling_product_ids(integer, integer, integer) from public;
grant execute on function public.pos_top_selling_product_ids(integer, integer, integer) to anon, authenticated;
