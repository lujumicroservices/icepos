-- Borrado lógico de ventas: al cancelar se marca cancelled_at en lugar de borrar la fila.
alter table public.sales
  add column if not exists cancelled_at timestamptz;

comment on column public.sales.cancelled_at is 'Si no es null, la venta fue cancelada (borrado lógico). No se eliminan sale_items.';
