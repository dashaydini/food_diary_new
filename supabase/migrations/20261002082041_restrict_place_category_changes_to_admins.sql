-- A place may be edited by its creator or an assigned business manager, but
-- moving it between public categories is a moderation action reserved for an
-- administrator. RLS alone cannot compare OLD and NEW column values here.
create or replace function private.prevent_non_admin_category_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.category_id is distinct from old.category_id
     and not coalesce(public.is_admin(), false) then
    raise exception 'Only an administrator can change a place category'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_non_admin_category_change()
  from public, anon, authenticated;

drop trigger if exists prevent_non_admin_category_change on public.places;
create trigger prevent_non_admin_category_change
before update of category_id on public.places
for each row
execute function private.prevent_non_admin_category_change();
