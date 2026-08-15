-- Split / multi-method payments stored as JSON on the sale header.
alter table public.sales
  add column if not exists payments_json jsonb;

comment on column public.sales.payments_json is
  'Optional split payments: [{method, amount, amount_tendered?, change_given?}]. payment_method=SPLIT when set.';
