-- One independently owned experience per user per shared outing.
-- Version aligned with the approved Supabase migration history.
-- Deleting the source experience must not delete another participant's work.
alter table public.visits
  add column outing_id uuid not null default gen_random_uuid(),
  add column source_visit_id uuid references public.visits(id) on delete set null;
create unique index visits_outing_user_unique on public.visits(outing_id, user_id);
create index visits_source_visit_idx on public.visits(source_visit_id);

create schema if not exists private;
create function private.enforce_shared_visit()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare source public.visits;
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id
       or new.place_id is distinct from old.place_id
       or new.outing_id is distinct from old.outing_id then
      raise exception 'Experience ownership, place and outing cannot be reassigned' using errcode = '42501';
    end if;
    if new.source_visit_id is distinct from old.source_visit_id
       and not (new.source_visit_id is null and pg_trigger_depth() > 1) then
      raise exception 'Experience source cannot be reassigned' using errcode = '42501';
    end if;
    return new;
  end if;
  if new.source_visit_id is null then
    -- Never trust a client-supplied outing identifier.
    new.outing_id := gen_random_uuid();
  else
    if auth.uid() is null or new.user_id <> auth.uid() then
      raise exception 'Authentication required' using errcode = '42501';
    end if;
    select * into source from public.visits where id = new.source_visit_id;
    if not found or source.place_id <> new.place_id or not exists (
      select 1 from public.visit_user_tags
      where visit_id = source.id and user_id = auth.uid()
    ) then
      raise exception 'An active tag at this place is required' using errcode = '42501';
    end if;
    new.outing_id := source.outing_id;
    new.visit_date := source.visit_date;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_shared_visit() from public, anon, authenticated;
create trigger enforce_shared_visit before insert or update on public.visits
for each row execute function private.enforce_shared_visit();

-- Ordinary users never gain edit rights to an author's experience through a tag.
-- Existing administrator moderation policies are retained.
alter policy "Owners and admins can update visits" on public.visits
  using (user_id = (select auth.uid()) or public.is_admin())
  with check (user_id = (select auth.uid()) or public.is_admin());
create policy "Tagged users can remove their own tag" on public.visit_user_tags
  for delete to authenticated using (user_id = (select auth.uid()));
create index if not exists visit_user_tags_recipient_created_idx
  on public.visit_user_tags(user_id, created_at desc, id);

-- Read state is recipient-owned. Notifications derive from existing tags, so
-- historical tags work too and deleting a tag removes its notification.
create table public.visit_tag_receipts (
  tag_id uuid primary key references public.visit_user_tags(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now()
);
create index visit_tag_receipts_user_idx on public.visit_tag_receipts(user_id);
alter table public.visit_tag_receipts enable row level security;
revoke all on public.visit_tag_receipts from anon, authenticated;
grant select, insert on public.visit_tag_receipts to authenticated;
grant all on public.visit_tag_receipts to service_role;
create policy "Recipients can read receipts" on public.visit_tag_receipts
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Recipients can mark own tags read" on public.visit_tag_receipts
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.visit_user_tags t
      where t.id = tag_id and t.user_id = (select auth.uid())
    )
  );

-- Preserve unchanged tag IDs/read states; updating a rating must not re-notify.
create function public.sync_visit_user_tags(p_visit_id uuid, p_user_ids uuid[])
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.visits where id = p_visit_id and user_id = auth.uid()
  ) then
    raise exception 'Only the experience author can change participants' using errcode = '42501';
  end if;
  if cardinality(p_user_ids) > 100 then
    raise exception 'Too many participants';
  end if;
  delete from public.visit_user_tags
  where visit_id = p_visit_id and not (user_id = any(coalesce(p_user_ids, '{}'::uuid[])));
  insert into public.visit_user_tags(visit_id, user_id)
  select p_visit_id, p.id from public.profiles p
  where p.id = any(coalesce(p_user_ids, '{}'::uuid[])) and p.id <> auth.uid()
    and not exists (select 1 from public.visit_user_tags t where t.visit_id = p_visit_id and t.user_id = p.id)
  on conflict (visit_id, user_id) do nothing;
end;
$$;
revoke all on function public.sync_visit_user_tags(uuid, uuid[]) from public, anon;
grant execute on function public.sync_visit_user_tags(uuid, uuid[]) to authenticated;

create function public.visit_tag_unread_count()
returns bigint language sql stable security invoker set search_path = '' as $$
  select count(*) from public.visit_user_tags t
  join public.visits v on v.id = t.visit_id
  where t.user_id = (select auth.uid()) and v.user_id <> (select auth.uid())
    and not exists (select 1 from public.visit_tag_receipts r where r.tag_id = t.id);
$$;
revoke all on function public.visit_tag_unread_count() from public, anon;
grant execute on function public.visit_tag_unread_count() to authenticated;
