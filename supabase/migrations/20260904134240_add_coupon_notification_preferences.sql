alter table public.coupons
  add column category_ids text[] not null default '{}',
  add column notification_region text;

create table public.coupon_notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  category_ids text[] not null default '{}',
  regions text[] not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.coupon_notification_preferences enable row level security;

create policy "Users read own coupon notification preferences"
on public.coupon_notification_preferences for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users create own coupon notification preferences"
on public.coupon_notification_preferences for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users update own coupon notification preferences"
on public.coupon_notification_preferences for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, insert, update on public.coupon_notification_preferences to authenticated;
