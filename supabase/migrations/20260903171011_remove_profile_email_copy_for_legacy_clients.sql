-- The canonical email is auth.users.email. Remove the duplicate from the
-- Timestamp matches the applied hosted migration.
-- client-readable profile row so legacy clients may request it without either
-- exposing an address or failing the whole public-experience query.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.is_anonymous then return new; end if;
  insert into public.profiles(id,display_name,role,registration_completed)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),
    'user',
    coalesce(new.raw_app_meta_data->>'provider','email') <> 'google'
  );
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

update public.profiles set email=null where email is not null;
comment on column public.profiles.email is
  'Deprecated compatibility field. Canonical email lives in auth.users; this column must remain null.';
grant select (email) on public.profiles to anon, authenticated;
notify pgrst, 'reload schema';
