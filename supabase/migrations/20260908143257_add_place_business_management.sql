create table public.place_managers (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  permissions text[] not null default '{}',
  status text not null default 'active' check (status in ('active', 'suspended')),
  assigned_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (place_id, user_id)
);

alter table public.place_managers enable row level security;

create policy "Managers read own place access" on public.place_managers
for select to authenticated using (
  user_id = (select auth.uid()) or exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
    and p.admin_role = 'full_admin'));

create policy "Full admins assign place managers" on public.place_managers
for insert to authenticated with check (exists (
  select 1 from public.profiles p where p.id = (select auth.uid())
  and p.admin_role = 'full_admin'));
create policy "Full admins update place managers" on public.place_managers
for update to authenticated using (exists (
  select 1 from public.profiles p where p.id = (select auth.uid())
  and p.admin_role = 'full_admin')) with check (exists (
  select 1 from public.profiles p where p.id = (select auth.uid())
  and p.admin_role = 'full_admin'));
create policy "Full admins remove place managers" on public.place_managers
for delete to authenticated using (exists (
  select 1 from public.profiles p where p.id = (select auth.uid())
  and p.admin_role = 'full_admin'));

grant select, insert, update, delete on public.place_managers to authenticated;

create index place_managers_user_status_idx
on public.place_managers(user_id, status);
create index place_managers_place_idx on public.place_managers(place_id);
