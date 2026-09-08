begin;

drop policy if exists "Everyone can read visible visits" on public.visits;
drop policy if exists "Admins can read hidden visits" on public.visits;
drop policy if exists "Guests can read visible visits" on public.visits;
drop policy if exists "Registered users read allowed visits" on public.visits;
create policy "Guests can read visible visits" on public.visits
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visits" on public.visits
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

drop policy if exists "Everyone can read visible visit images" on public.visit_images;
drop policy if exists "Admins can read hidden visit images" on public.visit_images;
drop policy if exists "Guests can read visible visit images" on public.visit_images;
drop policy if exists "Registered users read allowed visit images" on public.visit_images;
create policy "Guests can read visible visit images" on public.visit_images
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visit images" on public.visit_images
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

create index if not exists visit_reports_handled_by_idx
  on public.visit_reports(handled_by);
create index if not exists place_gallery_images_uploaded_by_idx
  on public.place_gallery_images(uploaded_by);
create index if not exists place_menus_updated_by_idx
  on public.place_menus(updated_by);
create index if not exists place_opening_hours_updated_by_idx
  on public.place_opening_hours(updated_by);
create index if not exists place_official_replies_created_by_idx
  on public.place_official_replies(created_by);

commit;
