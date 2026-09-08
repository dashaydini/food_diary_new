create table public.place_menus (
  place_id uuid primary key references public.places(id) on delete cascade,
  content text not null default '',
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.place_opening_hours (
  place_id uuid primary key references public.places(id) on delete cascade,
  content text not null default '',
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.place_gallery_images (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  image_url text not null,
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.place_official_replies (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  visit_id uuid not null unique references public.visits(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 2 and 2000),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index place_gallery_images_place_idx
on public.place_gallery_images(place_id, created_at desc);
create index place_official_replies_place_idx
on public.place_official_replies(place_id, updated_at desc);

alter table public.place_menus enable row level security;
alter table public.place_opening_hours enable row level security;
alter table public.place_gallery_images enable row level security;
alter table public.place_official_replies enable row level security;

grant select, insert, update, delete on public.place_menus to authenticated;
grant select, insert, update, delete on public.place_opening_hours to authenticated;
grant select, insert, update, delete on public.place_gallery_images to authenticated;
grant select, insert, update, delete on public.place_official_replies to authenticated;
grant select on public.place_menus, public.place_opening_hours,
  public.place_gallery_images, public.place_official_replies to anon;

create policy "Everyone can read place menus" on public.place_menus
for select to public using (true);
create policy "Managers maintain place menus" on public.place_menus
for all to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_menus.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'menu' = any(pm.permissions)))
with check (updated_by = (select auth.uid()) and ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_menus.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'menu' = any(pm.permissions))));

create policy "Everyone can read opening hours" on public.place_opening_hours
for select to public using (true);
create policy "Managers maintain opening hours" on public.place_opening_hours
for all to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_opening_hours.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'hours' = any(pm.permissions)))
with check (updated_by = (select auth.uid()) and ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_opening_hours.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'hours' = any(pm.permissions))));

create policy "Everyone can read place gallery" on public.place_gallery_images
for select to public using (true);
create policy "Managers add place gallery images" on public.place_gallery_images
for insert to authenticated with check (uploaded_by = (select auth.uid()) and
  ((select public.is_admin()) or exists (
    select 1 from public.place_managers pm where pm.place_id = place_gallery_images.place_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
    and 'gallery' = any(pm.permissions))));
create policy "Managers remove place gallery images" on public.place_gallery_images
for delete to authenticated using ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_gallery_images.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'gallery' = any(pm.permissions)));

create policy "Everyone can read official replies" on public.place_official_replies
for select to public using (true);
create policy "Managers add official replies" on public.place_official_replies
for insert to authenticated with check (created_by = (select auth.uid()) and
  ((select public.is_admin()) or exists (
    select 1 from public.place_managers pm where pm.place_id = place_official_replies.place_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
    and 'replies' = any(pm.permissions))));
create policy "Managers update official replies" on public.place_official_replies
for update to authenticated using ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_official_replies.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'replies' = any(pm.permissions)))
with check (created_by = (select auth.uid()) and ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_official_replies.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'replies' = any(pm.permissions))));
create policy "Managers delete official replies" on public.place_official_replies
for delete to authenticated using ((select public.is_admin()) or exists (
  select 1 from public.place_managers pm where pm.place_id = place_official_replies.place_id
  and pm.user_id = (select auth.uid()) and pm.status = 'active'
  and 'replies' = any(pm.permissions)));
