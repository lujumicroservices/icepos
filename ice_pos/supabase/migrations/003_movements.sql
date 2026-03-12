-- 003: Tabla movements (entradas/salidas de caja o banco; no son ventas).
-- type: ENTRADA | SALIDA, account: CAJA | BANCO. amount siempre positivo.
-- shift_id opcional: si account=CAJA, puede asociarse al turno en curso.

create table if not exists public.movements (
  id serial primary key,
  date timestamptz not null default now(),
  type text not null,
  account text not null,
  amount real not null,
  reason text not null,
  shift_id int references public.shifts(id)
);
comment on table public.movements is 'Entradas y salidas de caja o banco que afectan el monto esperado; no son ventas.';

alter table public.movements enable row level security;

drop policy if exists "anon_all_movements" on public.movements;
create policy "anon_all_movements" on public.movements for all to anon using (true) with check (true);
