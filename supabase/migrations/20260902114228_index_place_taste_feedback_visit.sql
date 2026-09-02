create index if not exists user_place_preferences_taste_visit_id_idx
  on public.user_place_preferences (taste_feedback_visit_id)
  where taste_feedback_visit_id is not null;
