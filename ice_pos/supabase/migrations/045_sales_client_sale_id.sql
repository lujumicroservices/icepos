-- Idempotent sale sync: client-generated key so ESP/outbox replay cannot duplicate rows.

alter table public.sales
  add column if not exists client_sale_id text;

comment on column public.sales.client_sale_id is
  'Stable id from POS device (e.g. deviceId:localSaleId). Unique when present.';

create unique index if not exists sales_client_sale_id_uidx
  on public.sales (client_sale_id)
  where client_sale_id is not null;
