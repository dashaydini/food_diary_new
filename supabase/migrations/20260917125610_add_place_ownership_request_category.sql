begin;

alter table public.support_requests
  drop constraint if exists support_requests_category_check;

alter table public.support_requests
  add constraint support_requests_category_check
  check (category in (
    'general', 'privacy', 'terms', 'technical', 'report', 'place_ownership'
  ));

alter table public.support_requests
  add column if not exists place_id uuid references public.places(id) on delete set null;

create index if not exists support_requests_place_id_idx
  on public.support_requests(place_id)
  where place_id is not null;

grant insert (place_id) on public.support_requests to authenticated;

-- Community gallery photos are visit images. Verify that the uploader owns
-- the experience that will display them (app admins retain moderation access).
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'visit_images'
      and policyname = 'Visit authors attach their own images'
  ) then
    create policy "Visit authors attach their own images"
      on public.visit_images as restrictive for insert to authenticated
      with check (
        (select public.is_admin()) or exists (
          select 1 from public.visits v
          where v.id = visit_id and v.user_id = (select auth.uid())
        )
      );
  end if;
end $$;

commit;
