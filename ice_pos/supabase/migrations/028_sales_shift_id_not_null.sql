-- Every sale must reference an open/closed shift (shifts.id). Backfill nulls, then NOT NULL + FK restrict.

alter table public.sales drop constraint if exists sales_shift_id_fkey;

-- Prefer shift whose time window contains the sale (latest matching shift per sale).
update public.sales s
set shift_id = pick.shift_id
from (
  select distinct on (s_inner.id)
    s_inner.id as sale_id,
    sh.id as shift_id
  from public.sales s_inner
  join public.shifts sh
    on sh.start_time <= s_inner.date
   and (sh.end_time is null or sh.end_time >= s_inner.date)
  where s_inner.shift_id is null
  order by s_inner.id, sh.id desc
) as pick(sale_id, shift_id)
where s.id = pick.sale_id;

-- Fallback: any existing shift
update public.sales
set shift_id = (select min(id) from public.shifts)
where shift_id is null
  and exists (select 1 from public.shifts);

-- Legacy row with no shifts at all: single synthetic closed shift
insert into public.shifts (store_id, start_time, end_time, starting_fund)
select 1, timestamptz '1970-01-01', timestamptz '1970-01-02', 0
where exists (select 1 from public.sales where shift_id is null)
  and not exists (select 1 from public.shifts);

update public.sales
set shift_id = (select min(id) from public.shifts)
where shift_id is null;

alter table public.sales alter column shift_id set not null;

alter table public.sales
  add constraint sales_shift_id_fkey
  foreign key (shift_id) references public.shifts (id) on delete restrict;

drop index if exists idx_sales_shift_id;
create index idx_sales_shift_id on public.sales (shift_id);

comment on column public.sales.shift_id is 'Turno en nube (shifts.id); obligatorio en cada venta.';
