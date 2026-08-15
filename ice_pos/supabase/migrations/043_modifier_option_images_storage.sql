-- Public bucket for modifier-option / flavor photos (URL in modifier_options.image_url).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'modifier-option-images',
  'modifier-option-images',
  true,
  5242880,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "modifier_option_images_select_public" on storage.objects;
drop policy if exists "modifier_option_images_insert_anon" on storage.objects;
drop policy if exists "modifier_option_images_insert_authenticated" on storage.objects;

create policy "modifier_option_images_select_public"
on storage.objects for select
to public
using (bucket_id = 'modifier-option-images');

create policy "modifier_option_images_insert_anon"
on storage.objects for insert
to anon
with check (
  bucket_id = 'modifier-option-images'
  and name like 'modifier-options/%'
);

create policy "modifier_option_images_insert_authenticated"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'modifier-option-images'
  and name like 'modifier-options/%'
);
