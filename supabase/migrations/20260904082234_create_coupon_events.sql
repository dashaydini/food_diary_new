create table public.coupon_events (
  id uuid primary key default gen_random_uuid(),
  coupon_id text not null,
  event_type text not null check (event_type in ('coupon_open', 'code_view')),
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index coupon_events_coupon_created_idx
  on public.coupon_events(coupon_id, created_at desc);
create index coupon_events_user_idx
  on public.coupon_events(user_id, created_at desc);

alter table public.coupon_events enable row level security;
revoke all on public.coupon_events from public, anon, authenticated;
grant insert on public.coupon_events to authenticated;
grant select on public.coupon_events to authenticated;
grant all on public.coupon_events to service_role;

create policy "Users can record own coupon activity"
on public.coupon_events for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Admins can view coupon activity"
on public.coupon_events for select to authenticated
using (public.is_admin());
