-- Run ONLY within BEGIN/ROLLBACK. Uses two existing non-admin identities and
-- temporary experiences; every write, including existing award triggers, rolls back.
do $$
declare
  users uuid[];
  place uuid;
  other_place uuid;
  original uuid := gen_random_uuid();
  personal uuid := gen_random_uuid();
  tag uuid;
  outing uuid;
  affected integer;
  baseline bigint;
begin
  select array_agg(id) into users from (
    select id from public.profiles where role is distinct from 'admin' order by id limit 2
  ) p;
  if cardinality(users) <> 2 then raise exception 'Need two non-admin test identities'; end if;
  select id into place from public.places order by id limit 1;
  select id into other_place from public.places where id <> place order by id limit 1;

  perform set_config('request.jwt.claim.sub', users[1]::text, true);
  set local role authenticated;
  insert into public.visits(id,place_id,user_id,notes,rating)
    values(original,place,users[1],'Shared outing rollback test',5);
  select outing_id into outing from public.visits where id = original;

  perform set_config('request.jwt.claim.sub', users[2]::text, true);
  baseline := public.visit_tag_unread_count();
  begin
    insert into public.visits(place_id,user_id,source_visit_id) values(place,users[2],original);
    raise exception 'FAIL: untagged user joined';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', users[1]::text, true);
  perform public.sync_visit_user_tags(original,array[users[2]]);
  select id into tag from public.visit_user_tags where visit_id=original and user_id=users[2];
  assert tag is not null, 'Tag created';
  begin
    insert into public.visit_tag_receipts(tag_id,user_id) values(tag,users[1]);
    raise exception 'FAIL: author read recipient notification';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', users[2]::text, true);
  assert public.visit_tag_unread_count() = baseline+1, 'Unread increments';
  insert into public.visit_tag_receipts(tag_id,user_id) values(tag,users[2]);
  assert public.visit_tag_unread_count() = baseline, 'Read clears unread';
  begin
    insert into public.visits(place_id,user_id,source_visit_id) values(other_place,users[2],original);
    raise exception 'FAIL: participant changed place';
  exception when insufficient_privilege then null; end;
  insert into public.visits(id,place_id,user_id,source_visit_id,notes,rating)
    values(personal,place,users[2],original,'My independent experience',2);
  assert (select outing_id=outing and rating=2 from public.visits where id=personal), 'Same outing, independent rating';
  assert (select rating=5 from public.visits where id=original), 'Author rating untouched';
  assert (select is_shared_response from public.visits where id=personal), 'Response role set by server';
  begin
    insert into public.visit_user_tags(visit_id,user_id) values(personal,users[1]);
    raise exception 'FAIL: participant invited someone directly';
  exception when insufficient_privilege then null; end;
  begin
    perform public.sync_visit_user_tags(personal,array[users[1]]);
    raise exception 'FAIL: participant invited someone through legacy RPC';
  exception when insufficient_privilege then null; end;
  begin
    perform public.sync_visit_user_tags(personal,array[users[1]],'{}');
    raise exception 'FAIL: participant invited someone through delta RPC';
  exception when insufficient_privilege then null; end;
  begin
    update public.visits set is_shared_response=false where id=personal;
    raise exception 'FAIL: participant removed response role';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.visits(place_id,user_id,source_visit_id) values(place,users[2],original);
    raise exception 'FAIL: duplicate personal experience';
  exception when unique_violation then null; end;
  update public.visits set notes='Unauthorized edit' where id=original;
  get diagnostics affected = row_count;
  assert affected=0, 'Participant cannot edit author';
  delete from public.visits where id=original;
  get diagnostics affected = row_count;
  assert affected=0, 'Participant cannot delete author';
  begin
    update public.visits set user_id=users[1] where id=personal;
    raise exception 'FAIL: ownership reassignment';
  exception when insufficient_privilege then null; end;
  begin
    update public.visits set outing_id=gen_random_uuid() where id=personal;
    raise exception 'FAIL: outing reassignment';
  exception when insufficient_privilege then null; end;
  begin
    perform public.sync_visit_user_tags(original,'{}');
    raise exception 'FAIL: participant edited author tags';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub', users[1]::text, true);
  perform public.sync_visit_user_tags(original,array[users[2]]);
  assert (select id=tag from public.visit_user_tags where visit_id=original and user_id=users[2]), 'Unchanged tag keeps ID';
  assert not exists(select 1 from public.visit_tag_receipts where tag_id=tag), 'Other user cannot read receipt';
  perform set_config('request.jwt.claim.sub', users[2]::text, true);
  assert public.visit_tag_unread_count()=baseline, 'Editing does not notify again';
  delete from public.visit_user_tags where id=tag and user_id=users[2];
  assert not exists(select 1 from public.visit_user_tags where id=tag), 'Recipient removed tag';
  assert exists(select 1 from public.visits where id=personal), 'Removing tag preserves personal experience';
  assert not exists(select 1 from public.visit_tag_receipts where tag_id=tag), 'Receipt cascades';
  perform set_config('request.jwt.claim.sub', users[1]::text, true);
  perform public.sync_visit_user_tags(original,array[users[2]],array[users[2]]);
  assert not exists(select 1 from public.visit_user_tags where visit_id=original and user_id=users[2]), 'Stale author edit cannot restore removed tag';
  perform set_config('request.jwt.claim.sub', users[2]::text, true);
  update public.visits set notes='Edited by owner' where id=personal;
  get diagnostics affected = row_count;
  assert affected=1, 'Owner still edits after untagging';

  perform set_config('request.jwt.claim.sub', users[1]::text, true);
  delete from public.visits where id=original;
  assert (select source_visit_id is null and outing_id=outing from public.visits where id=personal), 'Source deletion preserves participant experience/group';
  perform set_config('request.jwt.claim.sub', users[2]::text, true);
  assert (select is_shared_response from public.visits where id=personal), 'Response role survives original deletion';
  begin
    insert into public.visit_user_tags(visit_id,user_id) values(personal,users[1]);
    raise exception 'FAIL: orphaned response invited someone';
  exception when insufficient_privilege then null; end;
  delete from public.visits where id=personal;
  get diagnostics affected = row_count;
  assert affected=1, 'Owner can delete own experience';
  reset role;
end;
$$;
