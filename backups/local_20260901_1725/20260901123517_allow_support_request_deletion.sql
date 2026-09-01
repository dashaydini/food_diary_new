begin;

drop policy if exists "Users and support admins can delete support requests"
  on public.support_requests;

create policy "Users and support admins can delete support requests"
  on public.support_requests
  for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid())
        and is_admin = true
        and admin_role in ('full_admin', 'support_admin')
    )
  );

grant delete on table public.support_requests to authenticated;

commit;
