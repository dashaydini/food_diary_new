-- Only execute inside BEGIN/ROLLBACK; no persistent accounts or emails.
do $$
declare
  google_id uuid := gen_random_uuid();
  email_id uuid := gen_random_uuid();
  referrer uuid;
  referral text;
  original_count bigint;
  referrer_points integer;
  affected integer;
begin
  select id,referral_code,coalesce(points,0) into referrer,referral,referrer_points
  from public.profiles where referral_code is not null order by id limit 1;
  assert referrer is not null, 'Existing referrer required';
  select count(*) into original_count from public.profiles where not registration_completed;
  insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_anonymous)
    values(google_id,google_id::text||'@example.invalid','{"provider":"google"}',
      '{"full_name":"Google test","role":"admin","registration_completed":true}',false),
    (email_id,email_id::text||'@example.invalid','{"provider":"email"}','{}',false);
  assert (select not registration_completed and role='user' from public.profiles where id=google_id), 'New Google user requires completion; user metadata cannot grant privileges';
  assert (select registration_completed from public.profiles where id=email_id), 'Email registration unchanged';
  assert (select count(*) from public.profiles where not registration_completed)=original_count+1, 'Existing profiles unchanged';

  perform set_config('request.jwt.claim.sub',google_id::text,true);
  set local role authenticated;
  begin
    perform public.complete_google_registration('','');
    raise exception 'FAIL: empty display name accepted';
  exception when sqlstate '22001' then null; end;
  begin
    perform public.complete_google_registration('Valid name','invalid-'||google_id::text);
    raise exception 'FAIL: invalid invitation accepted';
  exception when sqlstate '22023' then null; end;
  assert (select not registration_completed and referred_by is null from public.profiles where id=google_id), 'Invalid invitation leaves registration pending';
  perform public.complete_google_registration('Chosen name',referral);
  assert (select registration_completed and display_name='Chosen name' and referred_by=referrer from public.profiles where id=google_id), 'Completion preserves account and applies invitation';
  assert (select points=25 from public.profiles where id=google_id), 'Invitee receives points once';
  perform public.complete_google_registration('Changed name',referral);
  assert (select points=25 and display_name='Chosen name' from public.profiles where id=google_id), 'Completion retry is idempotent';
  update public.profiles set registration_completed=false where id=referrer;
  get diagnostics affected=row_count;
  assert affected=0, 'Cannot change another user registration';
  reset role;
  assert (select points=referrer_points+25 from public.profiles where id=referrer), 'Referrer receives points once';
end;
$$;
