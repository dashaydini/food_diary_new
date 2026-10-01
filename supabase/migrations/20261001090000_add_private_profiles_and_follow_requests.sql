begin;

-- A private profile keeps its identity visible, but its experiences and
-- followers are only visible after the profile owner approves the request.
alter table public.profiles
  add column if not exists is_private boolean not null default false;

alter table public.user_follows
  add column if not exists status text not null default 'accepted';

alter table public.user_follows
  drop constraint if exists user_follows_status_check;

alter table public.user_follows
  add constraint user_follows_status_check
  check (status in ('pending', 'accepted'));

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from public, anon, authenticated;
grant select, insert, delete on public.user_blocks to authenticated;

create policy "Users manage own blocks"
on public.user_blocks for all to authenticated
using (blocker_id = (select auth.uid()))
with check (blocker_id = (select auth.uid()));

create index if not exists user_follows_following_status_idx
  on public.user_follows(following_id, status, created_at desc);

-- Existing rows predate the request flow and remain accepted.
update public.user_follows set status = 'accepted' where status is null;

-- Only the owner may alter privacy; the function also enforces the Premium
-- entitlement on the server, instead of relying on the Flutter interface.
revoke update on public.profiles from anon, authenticated;
grant update (id, display_name, avatar_url, registration_completed, is_private)
  on public.profiles to authenticated;
grant select (is_private) on public.profiles to anon, authenticated;

create or replace function public.set_my_profile_private(p_is_private boolean)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  entitled boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_is_private then
    select coalesce(p.is_admin, false) or exists (
      select 1 from public.user_subscriptions s
      where s.user_id = auth.uid()
        and s.plan = 'premium'
        and s.status = 'active'
        and (s.expires_at is null or s.expires_at > now())
    ) into entitled
    from public.profiles p where p.id = auth.uid();

    if not coalesce(entitled, false) then
      raise exception 'Premium required' using errcode = '42501';
    end if;
  end if;

  update public.profiles set is_private = p_is_private where id = auth.uid();
  if not p_is_private then
    update public.user_follows
      set status = 'accepted'
      where following_id = auth.uid() and status = 'pending';
  end if;
  return p_is_private;
end;
$$;

revoke all on function public.set_my_profile_private(boolean) from public, anon;
grant execute on function public.set_my_profile_private(boolean) to authenticated;

-- Requesting a follow is a single server-side operation, so a client cannot
-- bypass private profiles or follow someone who blocked it.
create or replace function public.request_follow(p_following_id uuid)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  target_private boolean;
  requested_status text;
begin
  if auth.uid() is null or auth.uid() = p_following_id then
    raise exception 'Invalid follow request' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_following_id and b.blocked_id = auth.uid())
       or (b.blocker_id = auth.uid() and b.blocked_id = p_following_id)
  ) then
    raise exception 'Follow unavailable' using errcode = '42501';
  end if;

  select is_private into target_private from public.profiles where id = p_following_id;
  if not found then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;

  requested_status := case when target_private then 'pending' else 'accepted' end;
  insert into public.user_follows(follower_id, following_id, status)
  values (auth.uid(), p_following_id, requested_status)
  on conflict (follower_id, following_id) do update
    set status = excluded.status,
        notify_on_new_experience = case
          when excluded.status = 'pending' then false
          else public.user_follows.notify_on_new_experience
        end;

  return requested_status;
end;
$$;

create or replace function public.respond_to_follow_request(
  p_follower_id uuid,
  p_accept boolean
)
returns text
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_accept then
    update public.user_follows
      set status = 'accepted'
      where follower_id = p_follower_id
        and following_id = auth.uid()
        and status = 'pending';
    if not found then raise exception 'Request not found' using errcode = 'P0002'; end if;
    return 'accepted';
  end if;

  delete from public.user_follows
    where follower_id = p_follower_id
      and following_id = auth.uid()
      and status = 'pending';
  if not found then raise exception 'Request not found' using errcode = 'P0002'; end if;
  return 'rejected';
end;
$$;

create or replace function public.remove_follower(p_follower_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and coalesce(p.is_admin, false)
  ) and not exists (
    select 1 from public.user_subscriptions s
    where s.user_id = auth.uid() and s.plan = 'premium' and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    raise exception 'Premium required' using errcode = '42501';
  end if;
  delete from public.user_follows
    where follower_id = p_follower_id and following_id = auth.uid();
end;
$$;

create or replace function public.block_user(p_blocked_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or auth.uid() = p_blocked_id then
    raise exception 'Invalid block request' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and coalesce(p.is_admin, false)
  ) and not exists (
    select 1 from public.user_subscriptions s
    where s.user_id = auth.uid() and s.plan = 'premium' and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    raise exception 'Premium required' using errcode = '42501';
  end if;
  insert into public.user_blocks(blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict do nothing;
  delete from public.user_follows
    where (follower_id = auth.uid() and following_id = p_blocked_id)
       or (follower_id = p_blocked_id and following_id = auth.uid());
end;
$$;

revoke all on function public.request_follow(uuid) from public, anon;
revoke all on function public.respond_to_follow_request(uuid, boolean) from public, anon;
revoke all on function public.remove_follower(uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.request_follow(uuid),
  public.respond_to_follow_request(uuid, boolean),
  public.remove_follower(uuid), public.block_user(uuid) to authenticated;

-- Legacy clients may still attempt a direct insert. They may follow public
-- profiles, but can never bypass the approval flow of a private profile.
alter policy "Users can follow from own account" on public.user_follows
  with check (
    follower_id = (select auth.uid())
    and follower_id <> following_id
    and status = 'accepted'
    and exists (
      select 1 from public.profiles p
      where p.id = following_id and p.is_private = false
    )
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = following_id and b.blocked_id = (select auth.uid()))
         or (b.blocker_id = (select auth.uid()) and b.blocked_id = following_id)
    )
  );

-- Pending requests never count as followers and private profiles do not expose
-- their experiences or photos to people who have not been approved.
drop policy if exists "Everyone can read visits" on public.visits;
create policy "Users read visible visits"
on public.visits for select to public
using (
  user_id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.id = visits.user_id and p.is_private = false
  )
  or exists (
    select 1 from public.user_follows f
    where f.follower_id = (select auth.uid())
      and f.following_id = visits.user_id
      and f.status = 'accepted'
  )
);

drop policy if exists "Everyone can read visit images" on public.visit_images;
create policy "Users read visible visit images"
on public.visit_images for select to public
using (
  exists (
    select 1 from public.visits v
    where v.id = visit_images.visit_id
  )
);

notify pgrst, 'reload schema';
commit;
