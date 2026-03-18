-- Adds image URL to categories (optional).
-- App stores a public URL (Supabase Storage or external host).

alter table public.categories
add column if not exists image_url text;

