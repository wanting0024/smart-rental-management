-- Synthetic SQL/role-shim checks only; no real image or hosted service.
begin;
insert into auth.users(id) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@verified.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@verified.invalid','provider');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate)
 values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test','Test',50);
insert into public.property(property_id,owner_id,unit_name,building_name,address)
 values('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','1','Test','Test');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Validation test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,current_status)
 values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-01-01 01:00Z','2030-01-01 03:00Z','In Progress');
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
select public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 '11111111-1111-4111-8111-111111111111','before','png',100,repeat('a',64));
do $$ begin
  assert not has_function_privilege('authenticated','public.claim_evidence_validation(uuid,uuid,uuid)','execute');
  assert not has_function_privilege('anon','public.finish_evidence_validation(uuid,uuid,text,text,integer,integer,integer,text)','execute');
  begin
    perform * from app_private.evidence_validation;
    raise exception 'Client read private attestation';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Even convincing Storage metadata is NOT sufficient to attach or read.
insert into storage.objects(bucket_id,name,metadata) values('cleaning-evidence',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd/before_11111111-1111-4111-8111-111111111111.png',
 '{"size":128,"mimetype":"image/png"}');
set local role authenticated;
do $$ begin
  assert (public.attach_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '11111111-1111-4111-8111-111111111111')->>'attached')='false';
  assert (select count(*) from storage.objects)=0;
end $$;
reset role;
set local role service_role;
do $$ declare t jsonb; id uuid := '11111111-1111-4111-8111-111111111111';
 b uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'; p uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
begin
  begin
    perform public.claim_evidence_validation(b,id,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    raise exception 'Wrong actor claimed validation';
  exception when insufficient_privilege then null; end;
  t:=public.claim_evidence_validation(b,id,p);
  assert t->>'state'='processing';
  assert public.claim_evidence_validation(b,id,p)->>'state'='busy';
  assert not public.finish_evidence_validation(id,null,repeat('a',64),repeat('e',64),128,2,2,'image/png');
  assert not public.finish_evidence_validation(id,(t->>'token')::uuid,repeat('b',64),repeat('e',64),128,2,2,'image/png');
  assert public.finish_evidence_validation(id,(t->>'token')::uuid,repeat('a',64),repeat('e',64),128,2,2,'image/png');
  assert public.claim_evidence_validation(b,id,p)->>'state'='verified';
end $$;
reset role;
set local role authenticated;
do $$ begin
  assert (select count(*) from public.booking_evidence)=0; -- verification != attachment
  assert (public.attach_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '11111111-1111-4111-8111-111111111111')->>'attached')='true';
  -- Canonical size differs from input (128 vs 100); only verified size wins.
  assert (select count(*) from storage.objects)=1;
end $$;
reset role;
-- Legacy paths are retained, but do not silently gain verification.
do $$ declare b uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
 p uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 id uuid := '22222222-2222-4222-8222-222222222222'; old_token uuid; t jsonb;
begin
  perform public.begin_evidence_upload(b,id,'after','png',128,repeat('a',64));
  t:=public.claim_evidence_validation(b,id,p); old_token:=(t->>'token')::uuid;
  update app_private.evidence_validation set lease_until=clock_timestamp()-interval '1 minute' where upload_id=id;
  t:=public.claim_evidence_validation(b,id,p); assert t->>'state'='processing';
  assert not public.finish_evidence_validation(id,old_token,repeat('a',64),repeat('e',64),128,2,2,'image/png');
  perform public.fail_evidence_validation(id,(t->>'token')::uuid,false);
  t:=public.claim_evidence_validation(b,id,p); assert t->>'state'='processing';
  perform public.fail_evidence_validation(id,(t->>'token')::uuid,false);
  assert public.claim_evidence_validation(b,id,p)->>'state'='attempts_exhausted';
  assert (select attempts from app_private.evidence_validation where upload_id=id)=3;
  id:='33333333-3333-4333-8333-333333333333';
  perform public.begin_evidence_upload(b,id,'after','png',128,repeat('a',64));
  t:=public.claim_evidence_validation(b,id,p);
  perform public.fail_evidence_validation(id,(t->>'token')::uuid,true);
  assert public.claim_evidence_validation(b,id,p)->>'state'='photo_rejected';
  assert public.begin_evidence_upload(b,id,'after','png',128,repeat('a',64))->>'state'='photo_rejected';
  id:='44444444-4444-4444-8444-444444444444';
  perform public.begin_evidence_upload(b,id,'after','png',128,repeat('a',64));
  update public.evidence_upload set created_at=clock_timestamp()-interval '23 hours 51 minutes' where upload_id=id;
  assert public.claim_evidence_validation(b,id,p)->>'state'='expired_or_closed';
end $$;
update public.booking_evidence set after_path='dddddddd-dddd-4ddd-8ddd-dddddddddddd/legacy.png',completion_remarks='Synthetic';
insert into storage.objects(bucket_id,name,metadata) values('cleaning-evidence',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd/legacy.png','{"size":128,"mimetype":"image/png"}');
do $$ begin
  begin
    update public.booking set current_status='Completed' where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    raise exception 'Unverified legacy evidence completed booking';
  exception when check_violation then null; end;
  assert (select current_status from public.booking)='In Progress';
end $$;
rollback;
