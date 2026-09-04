alter table public.coupons
  add column gallery_images text[] not null default '{}';

update public.coupons
set gallery_images = array[image_url]
where image_url <> '' and cardinality(gallery_images) = 0;
