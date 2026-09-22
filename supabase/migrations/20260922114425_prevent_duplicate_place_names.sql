create schema if not exists private;

create or replace function private.normalized_place_name(value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.lower(
    pg_catalog.regexp_replace(pg_catalog.btrim(value), '\s+', ' ', 'g')
  );
$$;

revoke all on function private.normalized_place_name(text)
from public, anon, authenticated;

create index if not exists places_normalized_name_lookup_idx
on public.places (private.normalized_place_name(name));

create or replace function private.prevent_duplicate_place_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_name text := private.normalized_place_name(new.name);
begin
  if normalized_name is null or normalized_name = '' then
    raise exception using
      errcode = 'P0001',
      message = 'place_name_required';
  end if;

  -- Serialize checks for the same normalized name. This closes the race where
  -- two devices try to create the same place at exactly the same time.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(normalized_name, 0)
  );

  if exists (
    select 1
    from public.places existing
    where private.normalized_place_name(existing.name) = normalized_name
      and existing.id <> new.id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'duplicate_place_name';
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_duplicate_place_name()
from public, anon, authenticated;

drop trigger if exists prevent_duplicate_place_name
on public.places;

create trigger prevent_duplicate_place_name
before insert or update of name
on public.places
for each row
execute function private.prevent_duplicate_place_name();

comment on function private.prevent_duplicate_place_name() is
  'Prevents new duplicate place names across categories while preserving existing rows.';
