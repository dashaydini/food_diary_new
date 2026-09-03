-- Column permissions are independent of row policies. Remove both table and
-- Timestamp matches the applied hosted migration.
-- residual column grants; explicitly list public fields (future fields stay private).
revoke select on public.profiles, public.visits from public, anon, authenticated;
do $$
declare tab text; cols text;
begin
  foreach tab in array array['profiles','visits'] loop
    select string_agg(quote_ident(attname), ', ') into cols
    from pg_attribute where attrelid=format('public.%I',tab)::regclass
      and attnum>0 and not attisdropped;
    execute format('revoke select (%s) on public.%I from public, anon, authenticated',cols,tab);
  end loop;
end $$;
grant select (id, display_name, role, created_at, avatar_url, points, level,
  referral_code, referred_by, is_admin, is_premium, admin_role, registration_completed)
  on public.profiles to anon, authenticated;
grant select (id, place_id, user_id, visit_date, notes, rating, created_at, updated_at,
  food, drink, food_price, drink_price, image_url, food_rating, drink_rating,
  atmosphere_rating, service_rating, cleanliness_rating, variety_rating, value_rating,
  total_price, price_level, outing_id, source_visit_id, is_shared_response)
  on public.visits to anon, authenticated;

-- Keep private values in place: no delete, copy, duplicate source or data loss.
-- A narrowly scoped privileged read is necessary because public and private fields
-- share legacy rows. The private function never accepts a caller-selected owner.
create schema if not exists app_private;
revoke all on schema app_private from public, anon;
grant usage on schema app_private to authenticated;
create function app_private.read_my_visit_private_details(p_visit_id uuid default null)
returns table(id uuid, journal_note text, with_whom text, favorite_memory boolean)
language sql stable security definer set search_path = '' as $$
  select v.id, v.journal_note, v.with_whom, v.favorite_memory
  from public.visits v
  where auth.uid() is not null and v.user_id=auth.uid()
    and (p_visit_id is null or v.id=p_visit_id);
$$;
revoke all on function app_private.read_my_visit_private_details(uuid) from public, anon, authenticated;
grant execute on function app_private.read_my_visit_private_details(uuid) to authenticated;
create function public.get_my_visit_private_details(p_visit_id uuid default null)
returns table(id uuid, journal_note text, with_whom text, favorite_memory boolean)
language sql stable security invoker set search_path = '' as $$
  select * from app_private.read_my_visit_private_details(p_visit_id);
$$;
revoke all on function public.get_my_visit_private_details(uuid) from public, anon;
grant execute on function public.get_my_visit_private_details(uuid) to authenticated;

-- Avoid selecting email implicitly through a whole-row read.
create or replace function public.complete_google_registration(
  p_display_name text, p_referral_code text default null
)
returns void language plpgsql security invoker set search_path = '' as $$
declare current_profile record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select registration_completed,referred_by into current_profile from public.profiles
    where id = auth.uid() for update;
  if not found then
    raise exception 'Profile not found' using errcode = '42501';
  end if;
  if current_profile.registration_completed then return; end if;
  if p_display_name is null or length(trim(p_display_name)) not between 2 and 60 then
    raise exception 'Invalid display name' using errcode = '22001';
  end if;
  if nullif(trim(p_referral_code),'') is not null and current_profile.referred_by is null then
    if not public.apply_referral_code(trim(p_referral_code)) then
      raise exception 'Invalid referral code' using errcode = '22023';
    end if;
  end if;
  update public.profiles
    set display_name=trim(p_display_name), registration_completed=true
    where id=auth.uid();
end;
$$;
notify pgrst, 'reload schema';
