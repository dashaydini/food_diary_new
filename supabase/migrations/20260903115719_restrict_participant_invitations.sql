-- Persist the response role even if its original experience is deleted.
-- Filename aligned with the approved remote migration history.
alter table public.visits
  add column is_shared_response boolean not null default false;
update public.visits set is_shared_response = true where source_visit_id is not null;

create function private.enforce_shared_response_role()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.is_shared_response := new.source_visit_id is not null;
    if new.source_visit_id is not null and exists (
      select 1 from public.visits where id = new.source_visit_id and is_shared_response
    ) then
      raise exception 'Only an original experience can invite participants' using errcode = '42501';
    end if;
  elsif new.is_shared_response is distinct from old.is_shared_response then
    raise exception 'Experience participation role cannot be changed' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_shared_response_role() from public, anon, authenticated;
create trigger enforce_shared_response_role before insert or update on public.visits
for each row execute function private.enforce_shared_response_role();

-- Applies to direct REST writes and both participant-sync RPC overloads.
create policy "Only original experiences can invite participants"
on public.visit_user_tags as restrictive for insert to authenticated
with check (exists (
  select 1 from public.visits v where v.id = visit_id and not v.is_shared_response
));
create policy "Only original experiences can receive moved tags"
on public.visit_user_tags as restrictive for update to authenticated
using (exists (
  select 1 from public.visits v where v.id = visit_id and not v.is_shared_response
))
with check (exists (
  select 1 from public.visits v where v.id = visit_id and not v.is_shared_response
));
