insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('coupon-images', 'coupon-images', true, 10485760,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true;

create policy "Public can view coupon images"
on storage.objects for select to public
using (bucket_id = 'coupon-images');

create policy "Content admins can upload coupon images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'coupon-images' and exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.is_admin = true and p.admin_role in ('full_admin', 'content_admin')
  )
);

create policy "Content admins can update coupon images"
on storage.objects for update to authenticated
using (bucket_id = 'coupon-images' and public.is_admin())
with check (bucket_id = 'coupon-images' and public.is_admin());

create policy "Content admins can delete coupon images"
on storage.objects for delete to authenticated
using (bucket_id = 'coupon-images' and public.is_admin());
