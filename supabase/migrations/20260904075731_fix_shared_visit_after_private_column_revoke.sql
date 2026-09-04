-- Participant responses began failing after private visit columns were revoked
-- from authenticated clients. The invoker trigger previously selected the whole
-- source row, which implicitly required access to those private columns.
-- Read only the two public values needed to validate and group the response.
create or replace function private.enforce_shared_visit()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  source_place_id uuid;
  source_outing_id uuid;
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

    select v.place_id, v.outing_id
      into source_place_id, source_outing_id
    from public.visits v
    where v.id = new.source_visit_id;

    if not found or source_place_id <> new.place_id or not exists (
      select 1 from public.visit_user_tags
      where visit_id = new.source_visit_id and user_id = auth.uid()
    ) then
      raise exception 'An active tag at this place is required' using errcode = '42501';
    end if;
    new.outing_id := source_outing_id;
    new.visit_date := (
      select v.visit_date from public.visits v where v.id = new.source_visit_id
    );
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_shared_visit() from public, anon, authenticated;
