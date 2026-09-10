create table if not exists public.ad_test_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.ad_test_users enable row level security;

revoke all on table public.ad_test_users from anon, authenticated;
grant select on table public.ad_test_users to authenticated;
grant all on table public.ad_test_users to service_role;

create policy "Users can read their own ad test status"
on public.ad_test_users
for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
);

insert into public.ad_test_users (user_id, enabled)
select id, true
from auth.users
where lower(email) = lower('carneholic@gmail.com')
on conflict (user_id) do update
set enabled = excluded.enabled;
