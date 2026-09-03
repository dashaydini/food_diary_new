-- Allow guest relation queries to request public identity fields. Existing
-- Timestamp matches the applied hosted migration.
-- profiles RLS still controls which rows a guest may actually see.
grant select (id, display_name, role, created_at, avatar_url, points, level,
  referral_code, referred_by, is_admin, is_premium, admin_role, registration_completed)
  on public.profiles to anon;
