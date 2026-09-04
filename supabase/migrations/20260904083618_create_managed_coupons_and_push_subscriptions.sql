create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  description text not null default '',
  code text not null unique,
  valid_until date not null,
  business_name text not null,
  address text not null default '',
  latitude double precision,
  longitude double precision,
  place_id uuid references public.places(id) on delete set null,
  image_url text not null default '',
  is_unlimited boolean not null default true,
  is_published boolean not null default false,
  published_at timestamptz,
  notification_sent_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index coupons_published_valid_idx
  on public.coupons(is_published, valid_until desc);

alter table public.coupons enable row level security;
revoke all on public.coupons from public, anon, authenticated;
grant select on public.coupons to authenticated;
grant insert, update, delete on public.coupons to authenticated;
grant all on public.coupons to service_role;

create policy "Registered users can view published coupons"
on public.coupons for select to authenticated
using (
  (is_published and valid_until >= current_date and
   coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  or public.is_admin()
);

create policy "Content admins can create coupons"
on public.coupons for insert to authenticated
with check (
  exists (select 1 from public.profiles p where p.id = (select auth.uid())
    and p.is_admin = true and p.admin_role in ('full_admin', 'content_admin'))
  and created_by = (select auth.uid())
);

create policy "Content admins can update coupons"
on public.coupons for update to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid())
  and p.is_admin = true and p.admin_role in ('full_admin', 'content_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid())
  and p.is_admin = true and p.admin_role in ('full_admin', 'content_admin')));

create policy "Content admins can delete coupons"
on public.coupons for delete to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid())
  and p.is_admin = true and p.admin_role in ('full_admin', 'content_admin')));

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  subscription jsonb not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index push_subscriptions_user_idx on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from public, anon, authenticated;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant all on public.push_subscriptions to service_role;

create policy "Users manage own push subscriptions"
on public.push_subscriptions for all to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid()) and
  coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

insert into public.coupons (
  title, subtitle, description, code, valid_until, business_name, address,
  latitude, longitude, place_id, image_url, is_unlimited, is_published,
  published_at
) values (
  'קפה לבחירה במתנה',
  'בקניית מארז לראש השנה',
  'על כל קניית מארז לחג, קפה לבחירה במתנה.',
  'BTW-CAFE-1109', '2026-09-11', 'פטפוט במוזיאון',
  'העצמאות 60, העיר העתיקה, באר שבע', 31.2410286761093,
  34.7888643763947, 'ca43cd9b-a450-47fd-8a7d-b51d0dd174b4',
  'assets/coupons/rosh_hashanah_gift_basket.jpeg', true, true, now()
)
on conflict (code) do nothing;
