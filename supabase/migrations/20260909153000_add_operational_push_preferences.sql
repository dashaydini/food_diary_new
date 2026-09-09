begin;

create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  manager_new_experience boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from public, anon, authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant all on public.notification_preferences to service_role;

create policy "Users read own notification preferences"
on public.notification_preferences for select to authenticated
using (user_id = (select auth.uid()));

create policy "Users create own notification preferences"
on public.notification_preferences for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Users update own notification preferences"
on public.notification_preferences for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create table public.notification_dispatches (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  resource_id uuid not null,
  recipient_count integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (event_type, resource_id)
);

alter table public.notification_dispatches enable row level security;
revoke all on public.notification_dispatches from public, anon, authenticated;
grant all on public.notification_dispatches to service_role;

create index notification_dispatches_created_idx
on public.notification_dispatches(created_at desc);

commit;
