-- Ensure discounts are in Realtime (catalog sync already pulls them; events keep tablets fresh).
do $$
begin
  alter publication supabase_realtime add table public.discounts;
exception
  when duplicate_object then null;
end $$;
