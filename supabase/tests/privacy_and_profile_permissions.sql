-- Run inside BEGIN/ROLLBACK only. No persistent test accounts or experiences.
do $$
declare
  user_a uuid := gen_random_uuid();
  user_b uuid := gen_random_uuid();
  place uuid;
  visit_a uuid;
  visit_b uuid;
  col text;
begin
  insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_anonymous)
  values (user_a,user_a::text||'@example.invalid','{"provider":"email"}','{}',false),
         (user_b,user_b::text||'@example.invalid','{"provider":"email"}','{}',false);
  select id into place from public.places limit 1;
  assert place is not null, 'Existing place needed for rollback fixture';
  insert into public.visits(user_id,place_id,journal_note,with_whom,favorite_memory)
  values(user_a,place,'PRIVATE A','COMPANION A',true) returning id into visit_a;
  insert into public.visits(user_id,place_id,journal_note,with_whom,favorite_memory)
  values(user_b,place,'PRIVATE B','COMPANION B',false) returning id into visit_b;

  perform set_config('request.jwt.claim.sub',user_a::text,true);
  set local role authenticated;
  foreach col in array array['role','is_admin','admin_role','is_premium','points','level','referral_code','referred_by','email'] loop
    assert not has_column_privilege('authenticated','public.profiles',col,'INSERT'), 'Protected INSERT: '||col;
    assert not has_column_privilege('authenticated','public.profiles',col,'UPDATE'), 'Protected UPDATE: '||col;
    begin
      execute format('update public.profiles set %I=%I where id=$1',col,col) using user_a;
      raise exception 'FAIL: protected column update accepted: %',col;
    exception when insufficient_privilege then null; end;
  end loop;
  begin
    insert into public.profiles(id,role) values(user_a,'admin')
      on conflict(id) do update set role=excluded.role;
    raise exception 'FAIL: admin upsert accepted';
  exception when insufficient_privilege then null; end;
  insert into public.profiles(id,display_name) values(user_a,'Safe name')
    on conflict(id) do update set id=excluded.id,display_name=excluded.display_name;
  update public.profiles set avatar_url='https://example.invalid/avatar' where id=user_a;
  assert (select display_name='Safe name' and role='user' from public.profiles where id=user_a);
  assert not public.is_admin(), 'User remains non-admin';
  begin
    perform email from public.profiles where id=user_b;
    raise exception 'FAIL: another user email readable';
  exception when insufficient_privilege then null; end;
  begin
    perform journal_note from public.visits where id=visit_b;
    raise exception 'FAIL: private journal directly readable';
  exception when insufficient_privilege then null; end;
  assert (select count(*)=1 from public.get_my_visit_private_details(null)), 'Only caller private row';
  assert (select journal_note='PRIVATE A' and with_whom='COMPANION A' and favorite_memory from public.get_my_visit_private_details(visit_a));
  assert not exists(select 1 from public.get_my_visit_private_details(visit_b)), 'No IDOR on private RPC';
  update public.visits set favorite_memory=false where id=visit_a;
  assert (select not favorite_memory from public.get_my_visit_private_details(visit_a)), 'Owner memory update works';
  update public.visits set journal_note='ATTACK' where id=visit_b;
  reset role;
  assert (select journal_note='PRIVATE B' from public.visits where id=visit_b), 'Cross-user private update blocked';

  perform set_config('request.jwt.claim.sub','',true);
  set local role anon;
  perform id,notes,rating from public.visits limit 1;
  foreach col in array array['journal_note','with_whom','favorite_memory'] loop
    begin
      execute format('select %I from public.visits limit 1',col);
      raise exception 'FAIL: anonymous private read: %',col;
    exception when insufficient_privilege then null; end;
  end loop;
  begin
    perform * from public.get_my_visit_private_details(visit_a);
    raise exception 'FAIL: anonymous private RPC access';
  exception when insufficient_privilege then null; end;
  reset role;
  assert has_table_privilege('service_role','public.profiles','UPDATE'), 'Trusted admin service unchanged';
  assert has_column_privilege('service_role','public.profiles','email','SELECT'), 'Trusted admin email read unchanged';
end $$;
