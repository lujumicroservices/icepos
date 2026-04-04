-- Sucursales / tiendas. Una fila semilla (id=1); app envía store_id en ventas, turnos, movimientos y pos_devices.

create table if not exists public.stores (
  id serial primary key,
  name text not null,
  created_at timestamptz not null default now()
);

comment on table public.stores is 'Sucursales. La app usa el id activo (por defecto 1 hasta selector multi-tienda).';

insert into public.stores (id, name)
select 1, 'Tienda principal'
where not exists (select 1 from public.stores where id = 1);

select setval(
  pg_get_serial_sequence('public.stores', 'id'),
  coalesce((select max(id) from public.stores), 1)
);

alter table public.sales
  add column if not exists store_id int references public.stores(id);
update public.sales set store_id = 1 where store_id is null;
alter table public.sales alter column store_id set default 1;
alter table public.sales alter column store_id set not null;

alter table public.shifts
  add column if not exists store_id int references public.stores(id);
update public.shifts set store_id = 1 where store_id is null;
alter table public.shifts alter column store_id set default 1;
alter table public.shifts alter column store_id set not null;

alter table public.movements
  add column if not exists store_id int references public.stores(id);
update public.movements set store_id = 1 where store_id is null;
alter table public.movements alter column store_id set default 1;
alter table public.movements alter column store_id set not null;

alter table public.pos_devices
  add column if not exists store_id int references public.stores(id);
update public.pos_devices set store_id = 1 where store_id is null;
alter table public.pos_devices alter column store_id set default 1;
alter table public.pos_devices alter column store_id set not null;

alter table public.shift_close_events
  add column if not exists store_id int references public.stores(id);

create index if not exists idx_sales_store_date on public.sales (store_id, date desc);
create index if not exists idx_shifts_store_id on public.shifts (store_id);

alter table public.stores enable row level security;

drop policy if exists "anon_all_stores" on public.stores;
create policy "anon_all_stores" on public.stores
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_stores" on public.stores;
create policy "auth_all_stores" on public.stores
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
