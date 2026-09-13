begin;

create table public.user_legal_consents (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  privacy_policy_version text not null,
  accepted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_legal_consents enable row level security;
revoke all on public.user_legal_consents from public, anon, authenticated;
grant select, insert, update on public.user_legal_consents to authenticated;
grant all on public.user_legal_consents to service_role;

create policy "Users read own legal consent"
on public.user_legal_consents for select to authenticated
using (user_id = (select auth.uid()));

create policy "Users create own legal consent"
on public.user_legal_consents for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Users update own legal consent"
on public.user_legal_consents for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter table public.notification_preferences
  add column enabled boolean not null default true,
  add column coupons boolean not null default true,
  add column tags boolean not null default true,
  add column new_followers boolean not null default true,
  add column new_places_ai boolean not null default true,
  add column system_messages boolean not null default true;

commit;
