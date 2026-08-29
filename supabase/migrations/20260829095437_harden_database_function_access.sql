-- Keep name resolution deterministic for application functions that previously
-- inherited the caller's mutable search_path.
alter function public.get_nearby_places(double precision, double precision, double precision)
  set search_path = public, extensions;

alter function public.fn_generate_referral_code()
  set search_path = public, extensions;

alter function public.sync_place_location()
  set search_path = public, extensions;

-- SECURITY DEFINER functions bypass row-level security. PostgreSQL grants
-- EXECUTE to PUBLIC by default, so explicitly close every application-owned
-- privileged function before granting only the RPCs used by the Flutter app.
revoke execute on function public.apply_referral_code(text) from public, anon, authenticated;
revoke execute on function public.award_points(uuid, text, uuid, text) from public, anon, authenticated;
revoke execute on function public.award_user_points(uuid, integer, text, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.check_email_exists(text) from public, anon, authenticated;
revoke execute on function public.generate_referral_code() from public, anon, authenticated;
revoke execute on function public.get_premium_recommendations(integer) from public, anon, authenticated;
revoke execute on function public.get_referral_count(uuid) from public, anon, authenticated;
revoke execute on function public.get_user_level(integer) from public, anon, authenticated;
revoke execute on function public.handle_new_profile_referral_code() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_place_points() from public, anon, authenticated;
revoke execute on function public.handle_referral_first_visit() from public, anon, authenticated;
revoke execute on function public.handle_visit_full_rating() from public, anon, authenticated;
revoke execute on function public.handle_visit_photo() from public, anon, authenticated;
revoke execute on function public.handle_visit_points() from public, anon, authenticated;
revoke execute on function public.handle_visit_tags() from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon, authenticated;
revoke execute on function public.is_current_user_premium() from public, anon, authenticated;
revoke execute on function public.is_user_premium(uuid) from public, anon, authenticated;
revoke execute on function public.reward_visit_points() from public, anon, authenticated;
revoke execute on function public.update_user_level(uuid) from public, anon, authenticated;

-- Registration checks happen before sign-in. All other exposed RPCs require an
-- authenticated session; trigger helpers and point-awarding internals stay private.
grant execute on function public.check_email_exists(text) to anon, authenticated;
grant execute on function public.apply_referral_code(text) to authenticated;
grant execute on function public.get_premium_recommendations(integer) to authenticated;
grant execute on function public.get_referral_count(uuid) to authenticated;
grant execute on function public.get_user_level(integer) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_current_user_premium() to authenticated;
grant execute on function public.is_user_premium(uuid) to authenticated;

-- Remove a redundant unique index (the UNIQUE constraint already owns an
-- identical index), and cover foreign keys used by joins and cascading checks.
drop index if exists public.visit_user_tags_visit_user_unique;

create index if not exists places_user_id_idx
  on public.places (user_id);
create index if not exists point_transactions_action_key_idx
  on public.point_transactions (action_key);
create index if not exists profiles_referred_by_idx
  on public.profiles (referred_by);
create index if not exists user_category_order_category_id_idx
  on public.user_category_order (category_id);
create index if not exists visit_companions_user_id_idx
  on public.visit_companions (user_id);
create index if not exists visit_image_reports_reporter_id_idx
  on public.visit_image_reports (reporter_id);
create index if not exists visit_tag_links_tag_id_idx
  on public.visit_tag_links (tag_id);
create index if not exists visits_place_id_idx
  on public.visits (place_id);
