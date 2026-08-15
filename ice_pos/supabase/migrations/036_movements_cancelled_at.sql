-- Borrado lógico de movimientos (admin).

alter table public.movements
  add column if not exists cancelled_at timestamptz;

comment on column public.movements.cancelled_at is
  'Si no es null, el movimiento ya no cuenta en corte de caja.';

create index if not exists idx_movements_active_store_date
  on public.movements (store_id, date desc)
  where cancelled_at is null;
