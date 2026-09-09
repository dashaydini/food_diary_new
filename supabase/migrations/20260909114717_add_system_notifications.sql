begin;

create table public.system_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 80),
  body text not null check (char_length(btrim(body)) between 5 and 240),
  target_url text not null default '/',
  created_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'sending'
    check (status in ('sending', 'sent', 'failed')),
  recipient_count integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.system_notifications enable row level security;
revoke all on public.system_notifications from public, anon, authenticated;
grant select on public.system_notifications to authenticated;
grant all on public.system_notifications to service_role;

create policy "Full admins read system notifications"
on public.system_notifications for select to authenticated
using (exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid())
    and p.is_admin = true
    and p.admin_role = 'full_admin'
));

create index system_notifications_created_idx
on public.system_notifications(created_at desc);

commit;
