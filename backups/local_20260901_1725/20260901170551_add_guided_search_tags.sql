insert into public.visit_tags (name, icon, sort_order, category)
values
  ('מקום יפה', 'photo_camera', 10, 'אווירה'),
  ('טבע ונוף', 'landscape', 20, 'אווירה'),
  ('פינה נסתרת', 'explore', 30, 'אווירה'),
  ('סוד מקומי', 'local_secret', 40, 'אווירה')
on conflict (name) do update
set icon = excluded.icon,
    sort_order = excluded.sort_order,
    category = excluded.category;
