begin;

alter table public.place_menus
  add column if not exists file_url text,
  add column if not exists file_name text,
  add column if not exists file_type text
    check (file_type is null or file_type in ('image', 'pdf'));

alter table public.place_opening_hours
  add column if not exists schedule jsonb not null default '[]'::jsonb;

alter table public.visits
  add column if not exists moderation_status text not null default 'visible'
    check (moderation_status in ('visible', 'hidden'));

alter table public.visit_images
  add column if not exists moderation_status text not null default 'visible'
    check (moderation_status in ('visible', 'hidden'));

create table if not exists public.visit_reports (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 2 and 1000),
  status text not null default 'new' check (status in ('new', 'handled')),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references public.profiles(id)
);

create unique index if not exists visit_reports_one_open_per_reporter_idx
  on public.visit_reports(visit_id, reporter_id) where status = 'new';
create index if not exists visit_reports_status_created_idx
  on public.visit_reports(status, created_at desc);
create index if not exists visit_reports_reporter_idx
  on public.visit_reports(reporter_id);

alter table public.visit_reports enable row level security;
grant select, insert, update, delete on public.visit_reports to authenticated;

create policy "Reporters and admins read visit reports" on public.visit_reports
for select to authenticated using (
  reporter_id = (select auth.uid()) or (select public.is_admin())
);
create policy "Authenticated users report visits" on public.visit_reports
for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "Admins update visit reports" on public.visit_reports
for update to authenticated using ((select public.is_admin()))
with check ((select public.is_admin()));
create policy "Admins delete visit reports" on public.visit_reports
for delete to authenticated using ((select public.is_admin()));

drop policy if exists "Everyone can read visits" on public.visits;
create policy "Guests can read visible visits" on public.visits
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visits" on public.visits
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

drop policy if exists "Everyone can read visit images" on public.visit_images;
create policy "Guests can read visible visit images" on public.visit_images
for select to anon using (moderation_status = 'visible');
create policy "Registered users read allowed visit images" on public.visit_images
for select to authenticated using (
  moderation_status = 'visible' or (select public.is_admin())
);

drop policy if exists "Managers delete official replies" on public.place_official_replies;
create policy "Authors and admins delete official replies"
on public.place_official_replies for delete to authenticated using (
  (select public.is_admin()) or (
    created_by = (select auth.uid()) and exists (
      select 1 from public.place_managers pm
      where pm.place_id = place_official_replies.place_id
        and pm.user_id = (select auth.uid())
        and pm.status = 'active'
        and 'replies' = any(pm.permissions)
    )
  )
);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.sync_visit_moderation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_id uuid;
begin
  target_id := coalesce(new.visit_id, old.visit_id);
  update public.visits set moderation_status = case when exists (
    select 1 from public.visit_reports
    where visit_id = target_id and status = 'new'
  ) then 'hidden' else 'visible' end where id = target_id;
  return coalesce(new, old);
end;
$$;

create or replace function private.sync_visit_image_moderation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_id uuid;
begin
  target_id := coalesce(new.image_id, old.image_id);
  update public.visit_images set moderation_status = case when exists (
    select 1 from public.visit_image_reports
    where image_id = target_id and status = 'new'
  ) then 'hidden' else 'visible' end where id = target_id;
  return coalesce(new, old);
end;
$$;

revoke execute on function private.sync_visit_moderation() from public, anon, authenticated;
revoke execute on function private.sync_visit_image_moderation() from public, anon, authenticated;

create trigger sync_visit_moderation_after_report
after insert or update or delete on public.visit_reports
for each row execute function private.sync_visit_moderation();

create trigger sync_visit_image_moderation_after_report
after insert or update or delete on public.visit_image_reports
for each row execute function private.sync_visit_image_moderation();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('place-menu-files', 'place-menu-files', true, 10485760,
  array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Public reads place menu files" on storage.objects
for select to public using (bucket_id = 'place-menu-files');
create policy "Managers upload place menu files" on storage.objects
for insert to authenticated with check (
  bucket_id = 'place-menu-files'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and ((select public.is_admin()) or exists (
    select 1 from public.place_managers pm
    where pm.user_id = (select auth.uid()) and pm.status = 'active'
      and 'menu' = any(pm.permissions)
  ))
);
create policy "Owners manage place menu files" on storage.objects
for update to authenticated using (
  bucket_id = 'place-menu-files'
  and (owner_id = (select auth.uid()::text) or (select public.is_admin()))
) with check (bucket_id = 'place-menu-files');
create policy "Owners delete place menu files" on storage.objects
for delete to authenticated using (
  bucket_id = 'place-menu-files'
  and (owner_id = (select auth.uid()::text) or (select public.is_admin()))
);

commit;
