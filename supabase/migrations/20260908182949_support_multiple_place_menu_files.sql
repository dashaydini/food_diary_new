begin;

alter table public.place_menus
  add column if not exists files jsonb not null default '[]'::jsonb;

alter table public.place_menus
  drop constraint if exists place_menus_files_is_array;
alter table public.place_menus
  add constraint place_menus_files_is_array
  check (jsonb_typeof(files) = 'array');

-- Preserve any menu uploaded before multi-file support was introduced.
update public.place_menus
set files = jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
  'url', file_url,
  'name', file_name,
  'type', file_type,
  'path', case
    when file_url like '%/place-menu-files/%'
      then split_part(file_url, '/place-menu-files/', 2)
    else null
  end
)))
where coalesce(files, '[]'::jsonb) = '[]'::jsonb
  and file_url is not null
  and btrim(file_url) <> '';

-- New objects are stored as <place-id>/<uploader-id>/<file>. This lets a
-- replacement manager remove an old menu file for the same place without
-- receiving access to files belonging to other businesses.
drop policy if exists "Managers upload place menu files" on storage.objects;
create policy "Managers upload place menu files" on storage.objects
for insert to authenticated with check (
  bucket_id = 'place-menu-files'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and (
    (select public.is_admin())
    or exists (
      select 1 from public.place_managers pm
      where pm.place_id::text = (storage.foldername(name))[1]
        and pm.user_id = (select auth.uid())
        and pm.status = 'active'
        and 'menu' = any(pm.permissions)
    )
  )
);

drop policy if exists "Owners manage place menu files" on storage.objects;
create policy "Place managers update place menu files" on storage.objects
for update to authenticated using (
  bucket_id = 'place-menu-files'
  and (
    (select public.is_admin())
    or exists (
      select 1 from public.place_managers pm
      where pm.place_id::text = (storage.foldername(name))[1]
        and pm.user_id = (select auth.uid())
        and pm.status = 'active'
        and 'menu' = any(pm.permissions)
    )
  )
) with check (bucket_id = 'place-menu-files');

drop policy if exists "Owners delete place menu files" on storage.objects;
create policy "Place managers delete place menu files" on storage.objects
for delete to authenticated using (
  bucket_id = 'place-menu-files'
  and (
    (select public.is_admin())
    or exists (
      select 1 from public.place_managers pm
      where pm.place_id::text = (storage.foldername(name))[1]
        and pm.user_id = (select auth.uid())
        and pm.status = 'active'
        and 'menu' = any(pm.permissions)
    )
  )
);

commit;
