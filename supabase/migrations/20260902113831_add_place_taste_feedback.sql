alter table public.user_place_preferences
  add column if not exists taste_feedback smallint,
  add column if not exists taste_feedback_source text,
  add column if not exists taste_feedback_visit_id uuid
    references public.visits(id) on delete set null,
  add column if not exists taste_feedback_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_place_preferences_taste_feedback_check'
      and conrelid = 'public.user_place_preferences'::regclass
  ) then
    alter table public.user_place_preferences
      add constraint user_place_preferences_taste_feedback_check
      check (taste_feedback is null or taste_feedback in (-1, 1));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_place_preferences_taste_source_check'
      and conrelid = 'public.user_place_preferences'::regclass
  ) then
    alter table public.user_place_preferences
      add constraint user_place_preferences_taste_source_check
      check (
        (taste_feedback is null and taste_feedback_source is null)
        or
        (
          taste_feedback is not null
          and taste_feedback_source in ('experience', 'visited_marker')
        )
      );
  end if;
end
$$;

create index if not exists user_place_preferences_taste_feedback_idx
  on public.user_place_preferences (user_id, taste_feedback)
  where taste_feedback is not null;

grant select, insert, update, delete
  on table public.user_place_preferences
  to authenticated;

comment on column public.user_place_preferences.taste_feedback is
  'Explicit user taste signal: 1 liked, -1 disliked.';

comment on column public.user_place_preferences.taste_feedback_source is
  'Signal source. experience is active; visited_marker is reserved for a future visited flow.';
