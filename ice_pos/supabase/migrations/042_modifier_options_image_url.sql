-- Optional public image URL for modifier options (e.g. ice cream flavors).

alter table public.modifier_options
add column if not exists image_url text;
