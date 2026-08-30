begin;

-- Consolidate overlapping permissive policies while preserving the effective
-- owner/admin/public access model. Local guests use the anon role and receive
-- read-only access to public discovery content.

drop policy if exists "Allow public read access" on public.categories;
drop policy if exists "Everyone can read categories" on public.categories;
drop policy if exists "Content admins can manage categories" on public.categories;
create policy "Everyone can read categories" on public.categories
  for select to public using (true);
create policy "Content admins can insert categories" on public.categories
  for insert to authenticated with check (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  );
create policy "Content admins can update categories" on public.categories
  for update to authenticated using (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  ) with check (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  );
create policy "Content admins can delete categories" on public.categories
  for delete to authenticated using (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  );

drop policy if exists "Admins can manage places" on public.places;
drop policy if exists "Users can create places" on public.places;
drop policy if exists "Users can read places" on public.places;
drop policy if exists "Users can update own places" on public.places;
create policy "Everyone can read places" on public.places
  for select to public using (true);
create policy "Owners and admins can create places" on public.places
  for insert to authenticated with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Owners and admins can update places" on public.places
  for update to authenticated using (
    user_id = (select auth.uid()) or public.is_admin()
  ) with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Admins can delete places" on public.places
  for delete to authenticated using (public.is_admin());

drop policy if exists "Users can read own profile" on public.profiles;
alter policy "Users can insert own profile" on public.profiles
  with check (id = (select auth.uid()));
alter policy "Users can update own profile" on public.profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists "Users can manage companions for visits" on public.visit_companions;
create policy "Visit owners can insert companions" on public.visit_companions
  for insert to authenticated with check (
    (select auth.uid()) in (
      select user_id from public.visits where id = visit_companions.visit_id
    )
  );
create policy "Visit owners can update companions" on public.visit_companions
  for update to authenticated using (
    (select auth.uid()) in (
      select user_id from public.visits where id = visit_companions.visit_id
    )
  ) with check (
    (select auth.uid()) in (
      select user_id from public.visits where id = visit_companions.visit_id
    )
  );
create policy "Visit owners can delete companions" on public.visit_companions
  for delete to authenticated using (
    (select auth.uid()) in (
      select user_id from public.visits where id = visit_companions.visit_id
    )
  );

drop policy if exists "Content admins can manage image reports" on public.visit_image_reports;
drop policy if exists "Users can create own image reports" on public.visit_image_reports;
drop policy if exists "Users can read own image reports" on public.visit_image_reports;
create policy "Owners and content admins can read image reports" on public.visit_image_reports
  for select to authenticated using (
    reporter_id = (select auth.uid()) or exists (
      select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin')
    )
  );
create policy "Owners and content admins can create image reports" on public.visit_image_reports
  for insert to authenticated with check (
    reporter_id = (select auth.uid()) or exists (
      select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin')
    )
  );
create policy "Content admins can update image reports" on public.visit_image_reports
  for update to authenticated using (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  ) with check (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  );
create policy "Content admins can delete image reports" on public.visit_image_reports
  for delete to authenticated using (
    exists (select 1 from public.profiles
      where id = (select auth.uid())
        and admin_role in ('full_admin', 'content_admin'))
  );

drop policy if exists "Admins can manage visit images" on public.visit_images;
drop policy if exists "Users can create own visit images" on public.visit_images;
drop policy if exists "Users can read visit images" on public.visit_images;
drop policy if exists "Users can update own visit images" on public.visit_images;
drop policy if exists "Users can delete own visit images" on public.visit_images;
create policy "Everyone can read visit images" on public.visit_images
  for select to public using (true);
create policy "Owners and admins can create visit images" on public.visit_images
  for insert to authenticated with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Owners and admins can update visit images" on public.visit_images
  for update to authenticated using (
    user_id = (select auth.uid()) or public.is_admin()
  ) with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Owners and admins can delete visit images" on public.visit_images
  for delete to authenticated using (
    user_id = (select auth.uid()) or public.is_admin()
  );

drop policy if exists "Admins can manage visits" on public.visits;
drop policy if exists "Users can create visits" on public.visits;
drop policy if exists "Users can read visits" on public.visits;
drop policy if exists "Users can update own visits" on public.visits;
drop policy if exists "Users can delete own visits" on public.visits;
create policy "Everyone can read visits" on public.visits
  for select to public using (true);
create policy "Owners and admins can create visits" on public.visits
  for insert to authenticated with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Owners and admins can update visits" on public.visits
  for update to authenticated using (
    user_id = (select auth.uid()) or public.is_admin()
  ) with check (
    user_id = (select auth.uid()) or public.is_admin()
  );
create policy "Owners and admins can delete visits" on public.visits
  for delete to authenticated using (
    user_id = (select auth.uid()) or public.is_admin()
  );

-- Cache auth.uid() once per statement in the remaining policies flagged by
-- auth_rls_initplan. These changes are logically equivalent to the originals.
alter policy "Users can view own point transactions" on public.point_transactions
  using (user_id = (select auth.uid()));
alter policy "Users can read own premium preferences" on public.premium_preferences
  using (user_id = (select auth.uid()) and public.is_current_user_premium());
alter policy "Users can insert own premium preferences" on public.premium_preferences
  with check (user_id = (select auth.uid()) and public.is_current_user_premium());
alter policy "Users can update own premium preferences" on public.premium_preferences
  using (user_id = (select auth.uid()) and public.is_current_user_premium())
  with check (user_id = (select auth.uid()) and public.is_current_user_premium());

alter policy "Users can view their own category order" on public.user_category_order
  using ((select auth.uid()) = user_id);
alter policy "Users can insert their own category order" on public.user_category_order
  with check ((select auth.uid()) = user_id);
alter policy "Users can update their own category order" on public.user_category_order
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete their own category order" on public.user_category_order
  using ((select auth.uid()) = user_id);

alter policy "Users can follow from own account" on public.user_follows
  with check (follower_id = (select auth.uid()) and follower_id <> following_id);
alter policy "Users can unfollow from own account" on public.user_follows
  using (follower_id = (select auth.uid()));

alter policy "Users can view their own place preferences" on public.user_place_preferences
  using ((select auth.uid()) = user_id);
alter policy "Users can insert their own place preferences" on public.user_place_preferences
  with check ((select auth.uid()) = user_id);
alter policy "Users can update their own place preferences" on public.user_place_preferences
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete their own place preferences" on public.user_place_preferences
  using ((select auth.uid()) = user_id);

alter policy "Users can read own point events" on public.user_point_events
  using (user_id = (select auth.uid()));
alter policy "Users can read own referrals" on public.user_referrals
  using (inviter_id = (select auth.uid()) or invitee_id = (select auth.uid()));
alter policy "users_can_read_own_subscription" on public.user_subscriptions
  using ((select auth.uid()) = user_id);

alter policy "Users can create own visit tag links" on public.visit_tag_links
  with check (
    public.is_admin() or exists (
      select 1 from public.visits
      where id = visit_tag_links.visit_id
        and user_id = (select auth.uid())
    )
  );
alter policy "Users can delete own visit tag links" on public.visit_tag_links
  using (
    public.is_admin() or exists (
      select 1 from public.visits
      where id = visit_tag_links.visit_id
        and user_id = (select auth.uid())
    )
  );

alter policy "Admins can insert visit tags" on public.visit_tags
  with check (
    exists (select 1 from public.profiles
      where id = (select auth.uid()) and is_admin = true)
  );
alter policy "Admins can update visit tags" on public.visit_tags
  using (
    exists (select 1 from public.profiles
      where id = (select auth.uid()) and is_admin = true)
  ) with check (
    exists (select 1 from public.profiles
      where id = (select auth.uid()) and is_admin = true)
  );

alter policy "Visit owner can add user tags" on public.visit_user_tags
  with check (
    public.is_admin() or exists (
      select 1 from public.visits
      where id = visit_user_tags.visit_id
        and user_id = (select auth.uid())
    )
  );
alter policy "Visit owner can remove user tags" on public.visit_user_tags
  using (
    public.is_admin() or exists (
      select 1 from public.visits
      where id = visit_user_tags.visit_id
        and user_id = (select auth.uid())
    )
  );

commit;
