create schema if not exists private;

create or replace function private.has_active_premium_access(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1
      from public.profiles p
      where p.id = target_user_id
        and coalesce(p.is_admin, false)
    )
    or exists (
      select 1
      from public.user_subscriptions s
      where s.user_id = target_user_id
        and s.plan = 'premium'
        and s.status = 'active'
        and (s.expires_at is null or s.expires_at > now())
    );
$$;

revoke all on function private.has_active_premium_access(uuid)
from public, anon, authenticated;

create or replace function private.enforce_free_journal_collection_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  existing_count integer;
begin
  if caller_id is null then return new; end if;
  if new.user_id <> caller_id then
    raise insufficient_privilege using message = 'journal_collection_owner_mismatch';
  end if;
  if private.has_active_premium_access(caller_id) then return new; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('journal-collections:' || caller_id::text, 0)
  );
  select count(*) into existing_count
  from public.journal_collections c
  where c.user_id = caller_id;

  if existing_count >= 5 then
    raise exception using errcode = 'P0001', message = 'free_collections_limit';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_free_journal_collection_limit()
from public, anon, authenticated;

drop trigger if exists enforce_free_journal_collection_limit
on public.journal_collections;
create trigger enforce_free_journal_collection_limit
before insert on public.journal_collections
for each row execute function private.enforce_free_journal_collection_limit();

create or replace function private.enforce_free_collection_visit_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  collection_owner uuid;
  existing_count integer;
begin
  if caller_id is null then return new; end if;

  select c.user_id into collection_owner
  from public.journal_collections c
  where c.id = new.collection_id;

  if collection_owner is null or collection_owner <> caller_id then
    raise insufficient_privilege using message = 'journal_collection_owner_mismatch';
  end if;
  if private.has_active_premium_access(caller_id) then return new; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('journal-items:' || new.collection_id::text, 0)
  );
  select count(*) into existing_count
  from public.journal_collection_visits jcv
  where jcv.collection_id = new.collection_id
    and jcv.visit_id <> new.visit_id;

  if existing_count >= 3 then
    raise exception using errcode = 'P0001', message = 'free_collection_items_limit';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_free_collection_visit_limit()
from public, anon, authenticated;

drop trigger if exists enforce_free_collection_visit_limit
on public.journal_collection_visits;
create trigger enforce_free_collection_visit_limit
before insert on public.journal_collection_visits
for each row execute function private.enforce_free_collection_visit_limit();

create or replace function private.enforce_visit_image_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  visit_owner uuid;
  existing_count integer;
  allowed_count integer;
begin
  if caller_id is null then return new; end if;

  select v.user_id into visit_owner
  from public.visits v
  where v.id = new.visit_id;

  if visit_owner is null or visit_owner <> caller_id or new.user_id <> caller_id then
    raise insufficient_privilege using message = 'visit_image_owner_mismatch';
  end if;

  allowed_count := case
    when private.has_active_premium_access(caller_id) then 10
    else 3
  end;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('visit-images:' || new.visit_id::text, 0)
  );
  select count(*) into existing_count
  from public.visit_images vi
  where vi.visit_id = new.visit_id;

  if existing_count >= allowed_count then
    raise exception using errcode = 'P0001', message = 'visit_images_limit';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_visit_image_limit()
from public, anon, authenticated;

drop trigger if exists enforce_visit_image_limit on public.visit_images;
create trigger enforce_visit_image_limit
before insert on public.visit_images
for each row execute function private.enforce_visit_image_limit();

create or replace function private.enforce_premium_category_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null then return new; end if;
  if new.user_id <> caller_id then
    raise insufficient_privilege using message = 'category_order_owner_mismatch';
  end if;
  if not private.has_active_premium_access(caller_id) then
    raise exception using errcode = 'P0001', message = 'premium_category_order_required';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_premium_category_order()
from public, anon, authenticated;

drop trigger if exists enforce_premium_category_order
on public.user_category_order;
create trigger enforce_premium_category_order
before insert or update on public.user_category_order
for each row execute function private.enforce_premium_category_order();

comment on function private.enforce_free_journal_collection_limit() is
  'Free accounts may create up to five journal collections. Existing content is never removed.';
comment on function private.enforce_free_collection_visit_limit() is
  'Free accounts may add up to three experiences to each collection.';
comment on function private.enforce_visit_image_limit() is
  'Limits images per experience to three for free accounts and ten for Premium accounts.';
comment on function private.enforce_premium_category_order() is
  'Category order customization is available to Premium accounts and administrators.';
