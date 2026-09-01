begin;

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default 'general'
    check (category in ('general', 'privacy', 'terms', 'technical', 'report')),
  subject text not null check (char_length(btrim(subject)) between 3 and 120),
  message text not null check (char_length(btrim(message)) between 10 and 4000),
  status text not null default 'new'
    check (status in ('new', 'in_progress', 'resolved', 'closed')),
  admin_reply text check (
    admin_reply is null or char_length(btrim(admin_reply)) between 2 and 4000
  ),
  responded_by uuid references auth.users(id) on delete set null,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (admin_reply is null and responded_by is null and responded_at is null)
    or
    (admin_reply is not null and responded_by is not null and responded_at is not null)
  )
);

create index support_requests_user_id_created_at_idx
  on public.support_requests (user_id, created_at desc);

create index support_requests_status_created_at_idx
  on public.support_requests (status, created_at desc);

alter table public.support_requests enable row level security;

create policy "Users and support admins can read support requests"
  on public.support_requests
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid())
        and is_admin = true
        and admin_role in ('full_admin', 'support_admin')
    )
  );

create policy "Users can create own support requests"
  on public.support_requests
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'new'
    and admin_reply is null
    and responded_by is null
    and responded_at is null
  );

create policy "Support admins can update support requests"
  on public.support_requests
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where id = (select auth.uid())
        and is_admin = true
        and admin_role in ('full_admin', 'support_admin')
    )
  )
  with check (
    exists (
      select 1
      from public.profiles
      where id = (select auth.uid())
        and is_admin = true
        and admin_role in ('full_admin', 'support_admin')
    )
    and (responded_by is null or responded_by = (select auth.uid()))
  );

revoke all on table public.support_requests from public, anon, authenticated;
grant select on table public.support_requests to authenticated;
grant insert (user_id, category, subject, message)
  on table public.support_requests to authenticated;
grant update (status, admin_reply, responded_by, responded_at, updated_at)
  on table public.support_requests to authenticated;

commit;
