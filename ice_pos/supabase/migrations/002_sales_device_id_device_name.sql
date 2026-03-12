-- 002: Agregar device_id y device_name a sales (identificador del dispositivo que registró la venta).
-- Ejecutar una vez si la tabla sales ya existía sin estas columnas.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'sales' and column_name = 'device_id'
  ) then
    alter table public.sales add column device_id text;
    comment on column public.sales.device_id is 'ID estable del dispositivo que registró la venta.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'sales' and column_name = 'device_name'
  ) then
    alter table public.sales add column device_name text;
    comment on column public.sales.device_name is 'Nombre legible del dispositivo (ej. Caja 1, Tablet piso 2). Opcional.';
  end if;
end $$;
