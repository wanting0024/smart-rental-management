-- ISOLATED SHIM ONLY. Metadata INSERT/DELETE below simulate the Storage API;
-- real object bytes must never be removed by SQL on hosted Supabase.
begin;
insert into auth.users(id) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@photo.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@photo.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@photo.invalid','provider');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test','Test',50);
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','1','Test','Test');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Photo test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,current_status) values
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-01-01 01:00Z','2030-01-01 03:00Z','In Progress');
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare b uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  first_id uuid := gen_random_uuid(); next_id uuid := gen_random_uuid(); competing_id uuid := gen_random_uuid();
  first_ticket jsonb; next_ticket jsonb; competing_ticket jsonb; result jsonb; n integer; path text;
begin
  first_ticket := public.begin_evidence_upload(b,first_id,'before','png',128,repeat('a',64));
  assert first_ticket = public.begin_evidence_upload(b,first_id,'before','png',128,repeat('a',64));
  begin
    perform public.begin_evidence_upload(b,first_id,'before','png',128,repeat('b',64));
    raise exception 'Token accepted different content';
  exception when check_violation then null; end;
  begin
    insert into public.booking_evidence(booking_id,before_path) values(b,first_ticket->>'path');
    raise exception 'Direct evidence write permitted';
  exception when insufficient_privilege then null; end;
  result := public.attach_evidence_upload(b,first_id);
  assert result->>'reason' = 'upload_not_confirmed';
  begin
    insert into storage.objects(bucket_id,name) values('cleaning-evidence',b::text || '/unregistered.png');
    raise exception 'Unregistered upload permitted';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name,metadata) values
      ('cleaning-evidence',first_ticket->>'path','{"size":128,"mimetype":"image/png"}');
    raise exception 'Direct registered upload bypassed server validation';
  exception when insufficient_privilege then null; end;
  perform local_test.fixture_verify_photo(first_id);
  result := public.attach_evidence_upload(b,first_id); assert result->>'attached' = 'true';
  -- Two devices both saw the same old photo; the second commit must not win.
  result := public.begin_evidence_upload(b,gen_random_uuid(),'before','png',128,repeat('b',64));
  assert result->>'state'='photo_changed'; -- stale page cannot silently replace it
  next_ticket := public.begin_evidence_upload(b,next_id,'before','png',128,repeat('b',64),first_ticket->>'path');
  competing_ticket := public.begin_evidence_upload(b,competing_id,'before','png',128,repeat('c',64),first_ticket->>'path');
  perform local_test.fixture_verify_photo(next_id);
  perform local_test.fixture_verify_photo(competing_id);
  result := public.attach_evidence_upload(b,next_id); assert result->>'attached' = 'true';
  result := public.attach_evidence_upload(b,competing_id); assert result->>'reason' = 'photo_changed';
  assert (select before_path from public.booking_evidence where booking_id=b) = next_ticket->>'path';
  -- Still no arbitrary DELETE. Only an irreversible tombstone opens deletion.
  delete from storage.objects where bucket_id='cleaning-evidence';
  get diagnostics n = row_count; assert n = 0;
  for path in select object_path from public.claim_evidence_cleanup(b) loop
    assert path <> next_ticket->>'path';
    assert not public.finish_evidence_cleanup(b,path); -- actual API has not deleted it
    delete from storage.objects where bucket_id='cleaning-evidence' and name=path;
    assert public.finish_evidence_cleanup(b,path);
    assert public.finish_evidence_cleanup(b,path); -- replay after a lost response
  end loop;
  assert (select count(*) from storage.objects) = 1;
  result := public.attach_evidence_upload(b,first_id); assert result->>'attached' = 'false';
  result := public.attach_evidence_upload(b,next_id); assert result->>'attached' = 'true';
  perform public.save_evidence_remarks(b,'Keep this remark');
  result := public.begin_evidence_upload(b,gen_random_uuid(),'after','png',128,repeat('a',64));
  assert (select count(*) from public.claim_evidence_cleanup(b)) = 0; -- fresh pending protected
end $$;
reset role;
-- Only simulate elapsed server time in the disposable database.
update public.evidence_upload set created_at=now()-interval '25 hours' where state='pending';
set local role authenticated;
do $$ declare b uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'; n integer;
begin
  select count(*) into n from public.claim_evidence_cleanup(b); assert n=1;
  assert (select count(*) from public.evidence_upload where state='attached')=1;
end $$;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
  assert (select count(*) from public.evidence_upload)=0;
  assert (select count(*) from storage.objects)=1;
  assert (select count(*) from public.booking_evidence)=1;
  begin
    perform public.claim_evidence_cleanup('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
    raise exception 'Owner could request deletion';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
  assert (select count(*) from storage.objects)=0;
  begin
    perform public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',gen_random_uuid(),'before','png',128,repeat('a',64));
    raise exception 'Other Provider could upload';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  assert not has_function_privilege('anon','public.claim_evidence_cleanup_batch()','execute');
  assert not has_function_privilege('authenticated','public.claim_evidence_cleanup_batch()','execute');
end $$;
set local role service_role;
do $$ declare r record; n integer := 0;
begin
  for r in select * from public.list_evidence_cleanup_batch() loop
    n := n+1;
  end loop;
  assert n=1;
  for r in select * from public.claim_evidence_cleanup_batch() loop
    -- This abandoned pending ticket never had an object, so no fake deletion
    -- is necessary. Existing referenced photos must remain untouched.
    assert public.finish_evidence_cleanup_batch(r.booking_id,r.object_path);
    assert public.finish_evidence_cleanup_batch(r.booking_id,r.object_path);
  end loop;
  assert (select count(*) from public.list_evidence_cleanup_batch())=0;
end $$;
reset role;
rollback;
