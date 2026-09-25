-- Coupon metadata remains visible according to the existing RLS policies, but
-- redemption codes are only returned by the checked RPC below.
revoke select on public.coupons from authenticated;
grant select (
  id, title, subtitle, description, valid_until, business_name, address,
  latitude, longitude, place_id, image_url, is_unlimited, is_published,
  published_at, notification_sent_at, created_by, created_at, updated_at,
  gallery_images, category_ids, notification_region, is_premium_only
) on public.coupons to authenticated;

create or replace function public.get_coupon_redemption_code(
  target_coupon_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_coupon public.coupons%rowtype;
  can_manage boolean := false;
begin
  if caller_id is null
      or coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise insufficient_privilege using message = 'registered_account_required';
  end if;

  select * into target_coupon
  from public.coupons c
  where c.id = target_coupon_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'coupon_not_found';
  end if;

  select
    exists (
      select 1 from public.profiles p
      where p.id = caller_id
        and p.is_admin = true
        and p.admin_role in ('full_admin', 'content_admin')
    )
    or exists (
      select 1 from public.place_managers pm
      where pm.user_id = caller_id
        and pm.place_id = target_coupon.place_id
        and pm.status = 'active'
        and 'coupons' = any(pm.permissions)
    )
  into can_manage;

  if can_manage then return target_coupon.code; end if;

  if not target_coupon.is_published
      or target_coupon.valid_until < current_date then
    raise insufficient_privilege using message = 'coupon_not_available';
  end if;

  if target_coupon.is_premium_only
      and not private.has_active_premium_access(caller_id) then
    raise insufficient_privilege using message = 'premium_coupon_required';
  end if;

  return target_coupon.code;
end;
$$;

revoke all on function public.get_coupon_redemption_code(uuid)
from public, anon;
grant execute on function public.get_coupon_redemption_code(uuid)
to authenticated;

comment on function public.get_coupon_redemption_code(uuid) is
  'Returns a coupon code only to its manager/admin or to an eligible registered user. Premium-only codes require active Premium access.';
