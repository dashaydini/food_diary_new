alter table public.coupons
  add column if not exists is_premium_only boolean not null default false;

comment on column public.coupons.is_premium_only is
  'When true, the coupon code may only be redeemed by an active Premium user or administrator.';
