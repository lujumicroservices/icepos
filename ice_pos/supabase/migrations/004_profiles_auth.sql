-- 004: Perfiles de usuario (rol admin/cajero). Fuente de verdad en nube con Supabase Auth.
-- auth.users contiene la identidad; public.profiles extiende con el rol para la app.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'cajero' check (role in ('admin', 'cajero'))
);
comment on table public.profiles is 'Rol de cada usuario (admin/cajero). Fuente de verdad en nube.';

alter table public.profiles enable row level security;

-- Cada usuario puede leer su propio perfil.
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles
  for select using (auth.uid() = id);

-- Solo el backend (service role) o un admin pueden actualizar roles; el trigger inserta como definer.
-- Para que la app no escriba perfiles, no damos policy de insert/update a anon/authenticated.
-- El trigger que crea el perfil usa security definer.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'role', 'cajero'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Si ya existen usuarios en auth.users sin perfil, rellenar ahora (opcional).
insert into public.profiles (id, role)
select id, 'cajero' from auth.users
on conflict (id) do nothing;
