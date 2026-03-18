-- Bucket público para fotos de productos (URL guardada en products.image_url).
-- Aplicar en Supabase: SQL Editor o supabase db push.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "product_images_select_public" on storage.objects;
drop policy if exists "product_images_insert_anon" on storage.objects;
drop policy if exists "product_images_insert_authenticated" on storage.objects;

-- Lectura pública (POS muestra imágenes por URL)
create policy "product_images_select_public"
on storage.objects for select
to public
using (bucket_id = 'product-images');

-- Subida con clave anónima (misma que usa la app para sync)
create policy "product_images_insert_anon"
on storage.objects for insert
to anon
with check (
  bucket_id = 'product-images'
  and name like 'products/%'
);

create policy "product_images_insert_authenticated"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and name like 'products/%'
);
