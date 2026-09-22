create schema if not exists private;

create index if not exists user_place_preferences_favorites_count_idx
  on public.user_place_preferences (user_id)
  where is_favorite = true;

create index if not exists user_place_preferences_wishlist_count_idx
  on public.user_place_preferences (user_id)
  where is_wishlist = true;

create or replace function private.enforce_saved_places_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  has_unlimited_access boolean := false;
  saved_count integer;
begin
  -- Service-role maintenance is allowed. Every app request must only mutate
  -- the signed-in user's own row, in addition to the table's RLS policies.
  if caller_id is null then
    return new;
  end if;

  if new.user_id <> caller_id then
    raise insufficient_privilege using message = 'saved_places_owner_mismatch';
  end if;

  select
    coalesce(p.is_admin, false)
    or exists (
      select 1
      from public.user_subscriptions s
      where s.user_id = caller_id
        and s.plan = 'premium'
        and s.status = 'active'
        and (s.expires_at is null or s.expires_at > now())
    )
  into has_unlimited_access
  from public.profiles p
  where p.id = caller_id;

  if coalesce(has_unlimited_access, false) then
    return new;
  end if;

  -- Serialize limit checks for the same account so two simultaneous saves
  -- cannot both observe the same count and exceed the free allowance.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(caller_id::text, 0)
  );

  if new.is_favorite = true
      and (tg_op = 'INSERT' or old.is_favorite is distinct from true) then
    select count(*)
    into saved_count
    from public.user_place_preferences pref
    where pref.user_id = caller_id
      and pref.is_favorite = true
      and pref.place_id <> new.place_id;

    if saved_count >= 5 then
      raise exception using
        errcode = 'P0001',
        message = 'free_favorites_limit';
    end if;
  end if;

  if new.is_wishlist = true
      and (tg_op = 'INSERT' or old.is_wishlist is distinct from true) then
    select count(*)
    into saved_count
    from public.user_place_preferences pref
    where pref.user_id = caller_id
      and pref.is_wishlist = true
      and pref.place_id <> new.place_id;

    if saved_count >= 5 then
      raise exception using
        errcode = 'P0001',
        message = 'free_wishlist_limit';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_saved_places_limit()
from public, anon, authenticated;

drop trigger if exists enforce_saved_places_limit
on public.user_place_preferences;

create trigger enforce_saved_places_limit
before insert or update of is_favorite, is_wishlist
on public.user_place_preferences
for each row
execute function private.enforce_saved_places_limit();

comment on function private.enforce_saved_places_limit() is
  'Limits free accounts to five favorites and five wishlist places. Premium and admin accounts are unlimited.';
