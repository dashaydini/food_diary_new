-- The beta offer is available through the Android Alpha build until the first
-- 30 redemptions or 16 October 2026, 23:59 Israel time (UTC+03:00).
update public.premium_promo_codes
set expires_at = '2026-10-16 20:59:59+00'::timestamptz,
    updated_at = now()
where code = 'BITEBETA';

create or replace function public.get_beta_premium_offer_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  promo public.premium_promo_codes%rowtype;
  already_redeemed boolean := false;
  already_premium boolean := false;
  is_admin boolean := false;
  available boolean := false;
begin
  if caller_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  select * into promo
  from public.premium_promo_codes
  where code = 'BITEBETA';

  if not found then
    return jsonb_build_object('available', false);
  end if;

  select exists(
    select 1 from public.premium_promo_redemptions r
    where r.user_id = caller_id
  ) into already_redeemed;

  select exists(
    select 1 from public.user_subscriptions s
    where s.user_id = caller_id
      and s.plan = 'premium'
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) into already_premium;

  select coalesce(p.is_admin, false)
  into is_admin
  from public.profiles p
  where p.id = caller_id;

  available := promo.is_active
    and promo.starts_at <= now()
    and (promo.expires_at is null or promo.expires_at > now())
    and promo.redemption_count < promo.max_redemptions
    and not already_redeemed
    and not already_premium
    and not coalesce(is_admin, false);

  return jsonb_build_object(
    'available', available,
    'remaining', greatest(promo.max_redemptions - promo.redemption_count, 0),
    'expires_at', promo.expires_at
  );
end;
$$;

revoke all on function public.get_beta_premium_offer_status() from public, anon;
grant execute on function public.get_beta_premium_offer_status() to authenticated;
