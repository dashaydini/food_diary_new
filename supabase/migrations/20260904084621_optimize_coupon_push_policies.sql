create index coupons_place_id_idx on public.coupons(place_id);
create index coupons_created_by_idx on public.coupons(created_by);

drop policy "Registered users can view published coupons" on public.coupons;
create policy "Registered users can view published coupons"
on public.coupons for select to authenticated
using (
  (is_published and valid_until >= current_date and
   coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false) = false)
  or (select public.is_admin())
);

drop policy "Users manage own push subscriptions" on public.push_subscriptions;
create policy "Users manage own push subscriptions"
on public.push_subscriptions for all to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid()) and
  coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false) = false
);
