-- Si ves: ERROR 23505 duplicate key ... supplies_pkey Key (id)=(N) already exists
-- ejecuta SOLO esto (ajusta la secuencia al último id usado). Luego vuelve a correr el INSERT.

select setval(
  pg_get_serial_sequence('public.supplies', 'id'),
  coalesce((select max(id) from public.supplies), 0),
  true
) as next_id_will_be_this_plus_one;
