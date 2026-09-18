begin;

alter table public.user_follows
  add column if not exists notify_on_new_experience boolean not null default false;

create index if not exists user_follows_experience_notifications_idx
  on public.user_follows(following_id, follower_id)
  where notify_on_new_experience = true;

revoke update on public.user_follows from anon, authenticated;
grant update (notify_on_new_experience) on public.user_follows
  to authenticated;

create policy "Users update own follow notifications"
on public.user_follows for update to authenticated
using (
  follower_id = (select auth.uid()) and
  coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false
)
with check (
  follower_id = (select auth.uid()) and
  coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false
);

commit;
