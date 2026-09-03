-- Existing users are grandfathered in. Only newly created Google accounts
-- Filename aligned with the approved Supabase migration history.
-- need the one-time completion screen; email registration is unchanged.
alter table public.profiles
  add column registration_completed boolean not null default true;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.is_anonymous then return new; end if;
  insert into public.profiles(id,display_name,email,role,registration_completed)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),
    new.email,
    'user',
    coalesce(new.raw_app_meta_data->>'provider','email') <> 'google'
  );
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

create function public.complete_google_registration(
  p_display_name text, p_referral_code text default null
)
returns void language plpgsql security invoker set search_path = '' as $$
declare current_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  -- Serialize double taps / concurrent tabs, including referral awards.
  select * into current_profile from public.profiles
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
revoke all on function public.complete_google_registration(text,text) from public, anon;
grant execute on function public.complete_google_registration(text,text) to authenticated;
