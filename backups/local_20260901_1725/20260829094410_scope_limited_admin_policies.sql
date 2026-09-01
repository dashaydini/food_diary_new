
drop policy if exists "Admins can manage categories" on public.categories;
create policy "Content admins can manage categories"
on public.categories
for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and admin_role in ('full_admin', 'content_admin')
  )
)
with check (
  exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and admin_role in ('full_admin', 'content_admin')
  )
);

drop policy if exists "Admins can manage image reports" on public.visit_image_reports;
create policy "Content admins can manage image reports"
on public.visit_image_reports
for all
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and admin_role in ('full_admin', 'content_admin')
  )
)
with check (
  exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and admin_role in ('full_admin', 'content_admin')
  )
);
;
