begin;

insert into public.visit_tags (name, icon, sort_order, category)
values ('שווה נסיעה', 'directions_car', 50, 'אווירה')
on conflict (name) do update
set icon = excluded.icon,
    sort_order = excluded.sort_order,
    category = excluded.category;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_requests'
  ) then
    alter publication supabase_realtime add table public.support_requests;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visit_image_reports'
  ) then
    alter publication supabase_realtime add table public.visit_image_reports;
  end if;
end
$$;

commit;
