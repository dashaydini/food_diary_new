-- Clients may edit their public identity, never their authority or rewards.
-- Timestamp matches the applied hosted migration.
revoke insert, update on public.profiles from public, anon, authenticated;
do $$
declare cols text;
begin
  select string_agg(quote_ident(attname), ', ') into cols
  from pg_attribute where attrelid='public.profiles'::regclass
    and attnum>0 and not attisdropped;
  execute format('revoke insert (%s), update (%s) on public.profiles from public, anon, authenticated', cols, cols);
end $$;
grant insert (id, display_name, avatar_url) on public.profiles to authenticated;
-- id is included for PostgREST upsert; existing RLS requires id = auth.uid().
grant update (id, display_name, avatar_url, registration_completed)
  on public.profiles to authenticated;
