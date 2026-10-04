-- A server-enforced promotional Premium code for the first BITE THE WAY
-- beta testers. The limit is protected by a row lock in the redemption RPC,
-- rather than by the Flutter client.

create table if not exists public.premium_promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  max_redemptions integer not null check (max_redemptions > 0),
  redemption_count integer not null default 0
    check (redemption_count >= 0 and redemption_count <= max_redemptions),
  premium_duration interval not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint premium_promo_codes_normalized_code_check
    check (code = upper(trim(code)))
);

create table if not exists public.premium_promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_code_id uuid not null references public.premium_promo_codes(id)
    on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  premium_expires_at timestamptz,
  unique (promo_code_id, user_id),
  -- Beta access is an introductory entitlement, not a stack of codes.
  unique (user_id)
);

create index if not exists premium_promo_redemptions_promo_idx
  on public.premium_promo_redemptions(promo_code_id, redeemed_at);

alter table public.premium_promo_codes enable row level security;
alter table public.premium_promo_redemptions enable row level security;

revoke all on public.premium_promo_codes from public, anon, authenticated;
revoke all on public.premium_promo_redemptions from public, anon, authenticated;
grant all on public.premium_promo_codes to service_role;
grant all on public.premium_promo_redemptions to service_role;

insert into public.premium_promo_codes (
  code, max_redemptions, premium_duration, expires_at, is_active
)
values (
  'BITEBETA',
  30,
  interval '365 days',
  '2026-10-16 20:59:59+00'::timestamptz,
  true
)
on conflict (code) do nothing;

create or replace function public.redeem_premium_promo(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  normalized_code text := upper(trim(coalesce(p_code, '')));
  promo public.premium_promo_codes%rowtype;
  previous_subscription public.user_subscriptions%rowtype;
  granted_until timestamptz;
begin
  if caller_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if normalized_code = '' then
    raise exception using errcode = '22023', message = 'invalid_promo_code';
  end if;

  select * into promo
  from public.premium_promo_codes
  where code = normalized_code
  for update;

  if not found or not promo.is_active
      or promo.starts_at > now()
      or (promo.expires_at is not null and promo.expires_at <= now()) then
    raise exception using errcode = '22023', message = 'invalid_promo_code';
  end if;

  if exists (
    select 1 from public.premium_promo_redemptions where user_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'promo_already_redeemed';
  end if;

  if promo.redemption_count >= promo.max_redemptions then
    raise exception using errcode = 'P0001', message = 'promo_limit_reached';
  end if;

  select * into previous_subscription
  from public.user_subscriptions
  where user_id = caller_id
  for update;

  if found and previous_subscription.expires_at is null
      and previous_subscription.status = 'active'
      and previous_subscription.plan = 'premium' then
    granted_until := null;
  else
    granted_until := greatest(
      coalesce(previous_subscription.expires_at, now()),
      now()
    ) + promo.premium_duration;
  end if;

  insert into public.user_subscriptions as subscription (
    user_id, plan, status, provider, external_subscription_id,
    started_at, expires_at, created_at, updated_at
  ) values (
    caller_id, 'premium', 'active', 'manual', 'promo:' || promo.code,
    now(), granted_until, now(), now()
  )
  on conflict (user_id) do update set
    plan = 'premium',
    status = 'active',
    provider = case
      when subscription.expires_at is null and subscription.status = 'active'
        then subscription.provider
      else 'manual'
    end,
    external_subscription_id = case
      when subscription.expires_at is null and subscription.status = 'active'
        then subscription.external_subscription_id
      else excluded.external_subscription_id
    end,
    started_at = case
      when subscription.expires_at is null and subscription.status = 'active'
        then subscription.started_at
      else now()
    end,
    expires_at = granted_until,
    updated_at = now();

  insert into public.premium_promo_redemptions (
    promo_code_id, user_id, premium_expires_at
  ) values (promo.id, caller_id, granted_until);

  update public.premium_promo_codes
  set redemption_count = redemption_count + 1,
      updated_at = now()
  where id = promo.id;

  update public.profiles
  set is_premium = true
  where id = caller_id;

  return jsonb_build_object(
    'code', promo.code,
    'remaining', promo.max_redemptions - promo.redemption_count - 1,
    'expires_at', granted_until
  );
end;
$$;

revoke all on function public.redeem_premium_promo(text) from public, anon;
grant execute on function public.redeem_premium_promo(text) to authenticated;

comment on function public.redeem_premium_promo(text) is
  'Redeems one introductory Premium offer per account. BITEBETA grants 365 days to the first 30 redemptions.';
