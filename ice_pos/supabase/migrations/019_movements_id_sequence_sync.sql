-- Fix duplicate key on movements_pkey when inserting from web after mobile sync.
-- Mobile upserts rows with explicit `id` (local SQLite ids); that does not advance
-- the serial sequence, so the next plain INSERT can reuse an existing id (23505).

select setval(
  pg_get_serial_sequence('public.movements', 'id')::regclass,
  coalesce((select max(id) from public.movements), 0),
  true
);

create or replace function public.movements_before_insert_sync_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  seq regclass;
  m bigint;
begin
  perform pg_advisory_xact_lock(87392001);

  seq := pg_get_serial_sequence('public.movements', 'id')::regclass;
  if seq is null then
    return new;
  end if;

  m := (select coalesce(max(id), 0) from public.movements);

  if exists (select 1 from public.movements where id = new.id) then
    new.id := m + 1;
    perform setval(seq, new.id, true);
  else
    perform setval(seq, greatest(m, new.id), true);
  end if;

  return new;
end;
$$;

drop trigger if exists movements_before_insert_sync_id on public.movements;
create trigger movements_before_insert_sync_id
before insert on public.movements
for each row
execute procedure public.movements_before_insert_sync_id();

notify pgrst, 'reload schema';
