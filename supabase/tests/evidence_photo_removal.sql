-- Disposable shim only: SQL DELETE below models the Storage API, never hosted
-- object deletion. All business removals use the normal authenticated RPC.
begin;
insert into auth.users(id) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@removal.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@removal.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@removal.invalid','provider');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','Private origin',50);
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','1','Building','Address');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Cleaning');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,current_status) values
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-01-01 01:00Z','2030-01-01 03:00Z','In Progress');
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare
 b uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
 first_id uuid := gen_random_uuid(); after_id uuid := gen_random_uuid(); next_id uuid := gen_random_uuid();
 first_photo jsonb; after_photo jsonb; next_photo jsonb; r jsonb; path text;
begin
 first_photo := public.begin_evidence_upload(b,first_id,'before','png',128,repeat('a',64));
 after_photo := public.begin_evidence_upload(b,after_id,'after','png',128,repeat('b',64));
 perform local_test.fixture_verify_photo(first_id); perform local_test.fixture_verify_photo(after_id);
 perform public.attach_evidence_upload(b,first_id); perform public.attach_evidence_upload(b,after_id);
 perform public.save_evidence_remarks(b,'Keep these remarks');
 r := public.remove_evidence_photo(b,'before',first_photo->>'path');
 assert r->>'removed' = 'true';
 assert (select before_path is null and after_path = after_photo->>'path' and completion_remarks='Keep these remarks'
   from public.booking_evidence where booking_id=b);
 assert (select state='retired' from public.evidence_upload where upload_id=first_id);
 assert not public.can_read_evidence_object(first_photo->>'path');
 assert public.can_read_evidence_object(after_photo->>'path');
 assert public.remove_evidence_photo(b,'before',first_photo->>'path')->>'removed' = 'true';
 begin
   perform public.transition_booking(b,'Completed');
   raise exception 'Completion succeeded without both photos';
 exception when check_violation then null; end;
 -- Only the removed object is eligible for API cleanup. The other stays live.
 for path in select object_path from public.claim_evidence_cleanup(b) loop
   assert path=first_photo->>'path';
   assert not public.finish_evidence_cleanup(b,path);
   delete from storage.objects where bucket_id='cleaning-evidence' and name=path;
   assert public.finish_evidence_cleanup(b,path);
 end loop;
 assert (select count(*) from storage.objects)=1;
 assert public.remove_evidence_photo(b,'before',first_photo->>'path')->>'removed'='true';
 assert public.attach_evidence_upload(b,first_id)->>'attached'='false';
 next_photo := public.begin_evidence_upload(b,next_id,'before','png',128,repeat('c',64));
 perform local_test.fixture_verify_photo(next_id); perform public.attach_evidence_upload(b,next_id);
 -- Retrying an old removal must never detach a replacement from another device.
 assert public.remove_evidence_photo(b,'before',first_photo->>'path')->>'reason'='photo_changed';
 assert (select before_path=next_photo->>'path' from public.booking_evidence where booking_id=b);
 perform public.transition_booking(b,'Completed');
 assert public.remove_evidence_photo(b,'after',after_photo->>'path')->>'reason'='booking_closed';
 assert (select after_path=after_photo->>'path' from public.booking_evidence where booking_id=b);
end $$;

select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
 begin
  perform public.remove_evidence_photo('dddddddd-dddd-4ddd-8ddd-dddddddddddd','before','dddddddd-dddd-4ddd-8ddd-dddddddddddd/before.jpg');
  raise exception 'Owner deleted provider evidence';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
 begin
  perform public.remove_evidence_photo('dddddddd-dddd-4ddd-8ddd-dddddddddddd','after','dddddddd-dddd-4ddd-8ddd-dddddddddddd/after.jpg');
  raise exception 'Unrelated provider deleted evidence';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 assert not has_function_privilege('anon','public.remove_evidence_photo(uuid,text,text)','execute');
 assert not has_table_privilege('authenticated','public.booking_evidence','UPDATE');
end $$;
rollback;
