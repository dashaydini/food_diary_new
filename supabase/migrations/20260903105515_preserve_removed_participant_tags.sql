-- Apply participant changes relative to the editor's original snapshot.
-- Version aligned with the approved Supabase migration history.
-- A stale editor must not recreate a tag removed by its recipient.
create function public.sync_visit_user_tags(
  p_visit_id uuid, p_user_ids uuid[], p_previous_user_ids uuid[]
)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.visits where id = p_visit_id and user_id = auth.uid()
  ) then
    raise exception 'Only the experience author can change participants' using errcode = '42501';
  end if;
  if cardinality(p_user_ids) > 100 or cardinality(p_previous_user_ids) > 100 then
    raise exception 'Too many participants';
  end if;
  delete from public.visit_user_tags
  where visit_id = p_visit_id
    and user_id = any(coalesce(p_previous_user_ids, '{}'::uuid[]))
    and not (user_id = any(coalesce(p_user_ids, '{}'::uuid[])));
  insert into public.visit_user_tags(visit_id, user_id)
  select p_visit_id, p.id from public.profiles p
  where p.id = any(coalesce(p_user_ids, '{}'::uuid[]))
    and not (p.id = any(coalesce(p_previous_user_ids, '{}'::uuid[])))
    and p.id <> auth.uid()
  on conflict (visit_id, user_id) do nothing;
end;
$$;
revoke all on function public.sync_visit_user_tags(uuid, uuid[], uuid[]) from public, anon;
grant execute on function public.sync_visit_user_tags(uuid, uuid[], uuid[]) to authenticated;
