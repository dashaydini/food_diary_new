
alter table public.profiles
  add column if not exists admin_role text;

alter table public.profiles
  drop constraint if exists profiles_admin_role_check;

alter table public.profiles
  add constraint profiles_admin_role_check
  check (
    admin_role is null
    or admin_role in ('full_admin', 'content_admin', 'support_admin')
  );

update public.profiles
set admin_role = 'full_admin'
where is_admin = true
  and admin_role is null;
;
