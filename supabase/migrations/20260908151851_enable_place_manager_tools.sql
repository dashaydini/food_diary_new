-- Place managers receive real data access only for their assigned place and
-- only when the matching permission is active.

create policy "Place managers can view managed coupons"
on public.coupons for select to authenticated
using (
  place_id is not null and exists (
    select 1
    from public.place_managers pm
    where pm.place_id = coupons.place_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
);

create policy "Place managers can create managed coupons"
on public.coupons for insert to authenticated
with check (
  created_by = (select auth.uid())
  and place_id is not null
  and exists (
    select 1
    from public.place_managers pm
    where pm.place_id = coupons.place_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
);

create policy "Place managers can update managed coupons"
on public.coupons for update to authenticated
using (
  place_id is not null and exists (
    select 1
    from public.place_managers pm
    where pm.place_id = coupons.place_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
)
with check (
  place_id is not null and exists (
    select 1
    from public.place_managers pm
    where pm.place_id = coupons.place_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
);

create policy "Place managers can delete managed coupons"
on public.coupons for delete to authenticated
using (
  place_id is not null and exists (
    select 1
    from public.place_managers pm
    where pm.place_id = coupons.place_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
);

create policy "Place managers can view managed coupon activity"
on public.coupon_events for select to authenticated
using (
  exists (
    select 1
    from public.coupons c
    join public.place_managers pm on pm.place_id = c.place_id
    where c.id::text = coupon_events.coupon_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'statistics' = any(pm.permissions)
  )
);

create policy "Place managers can edit assigned place details"
on public.places for update to authenticated
using (
  exists (
    select 1
    from public.place_managers pm
    where pm.place_id = places.id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'details' = any(pm.permissions)
  )
)
with check (
  exists (
    select 1
    from public.place_managers pm
    where pm.place_id = places.id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'details' = any(pm.permissions)
  )
);

create policy "Place managers can upload coupon images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'coupon-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.place_managers pm
    where pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and 'coupons' = any(pm.permissions)
  )
);
