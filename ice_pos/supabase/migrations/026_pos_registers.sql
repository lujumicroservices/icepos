-- Cajones / estaciones de caja por tienda. Vincula turnos y terminales al mismo cajón lógico.

create table if not exists public.pos_registers (
  id serial primary key,
  store_id int not null references public.stores(id) on delete cascade,
  label text not null,
  display_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint pos_registers_store_label_unique unique (store_id, label)
);

comment on table public.pos_registers is 'Cajón o estación de caja en una tienda (ej. Caja 1). Turnos y dispositivos se enlazan aquí para corte y recuperación tras reinstalar.';
create index if not exists idx_pos_registers_store on public.pos_registers (store_id) where active = true;

insert into public.pos_registers (id, store_id, label, display_order)
select 1, 1, 'Caja 1', 0
where exists (select 1 from public.stores where id = 1)
  and not exists (select 1 from public.pos_registers where id = 1);

select setval(
  pg_get_serial_sequence('public.pos_registers', 'id'),
  coalesce((select max(id) from public.pos_registers), 1)
);

alter table public.pos_devices
  add column if not exists register_id int references public.pos_registers(id) on delete set null;
comment on column public.pos_devices.register_id is 'Cajón al que está asignado este terminal (opcional).';

alter table public.shifts
  add column if not exists register_id int references public.pos_registers(id) on delete set null;
comment on column public.shifts.register_id is 'Cajón en el que corre el turno; ventas con shift_id quedan bajo el mismo corte.';

alter table public.sales
  add column if not exists shift_id int references public.shifts(id) on delete set null;
comment on column public.sales.shift_id is 'Turno en nube (shifts.id); suma en corte por turno aunque cambie device_id.';

update public.shifts s
set register_id = 1
where s.register_id is null
  and s.store_id = 1
  and exists (select 1 from public.pos_registers r where r.id = 1 and r.store_id = 1);

update public.pos_devices d
set register_id = 1
where d.register_id is null
  and d.store_id = 1
  and exists (select 1 from public.pos_registers r where r.id = 1 and r.store_id = 1);

create index if not exists idx_shifts_register_open
  on public.shifts (store_id, register_id)
  where end_time is null;

create index if not exists idx_sales_shift_id
  on public.sales (shift_id)
  where shift_id is not null;

alter table public.pos_registers enable row level security;

drop policy if exists "anon_all_pos_registers" on public.pos_registers;
create policy "anon_all_pos_registers"
  on public.pos_registers
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_pos_registers" on public.pos_registers;
create policy "auth_all_pos_registers"
  on public.pos_registers
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
