begin;

drop policy if exists "Everyone can read visible visits" on public.visits;
drop policy if exists "Guests can read visible visits" on public.visits;
drop policy if exists "Registered users read allowed visits" on public.visits;
create policy "Guests can read visible visits" on public.visits
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visits" on public.visits
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

drop policy if exists "Everyone can read visible visit images" on public.visit_images;
drop policy if exists "Guests can read visible visit images" on public.visit_images;
drop policy if exists "Registered users read allowed visit images" on public.visit_images;
create policy "Guests can read visible visit images" on public.visit_images
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visit images" on public.visit_images
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

update public.visits v set moderation_status = 'hidden'
where exists (
  select 1 from public.visit_reports r
  where r.visit_id = v.id and r.status = 'new'
);
update public.visit_images i set moderation_status = 'hidden'
where exists (
  select 1 from public.visit_image_reports r
  where r.image_id = i.id and r.status = 'new'
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visit_reports'
  ) then
    alter publication supabase_realtime add table public.visit_reports;
  end if;
end $$;

commit;
