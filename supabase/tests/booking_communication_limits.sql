-- Synthetic fixtures only, in the network-isolated disposable database.
begin;
insert into auth.users(id) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@limits.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@limits.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@limits.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate,approval_status)
 values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test','Synthetic private origin',50,'approved');
insert into public.property(property_id,owner_id,unit_name,building_name,address)
 values('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','1','Test','Synthetic test address');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Limit test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,current_status)
 values('dddddddd-dddd-4ddd-8ddd-ddddddddddd1','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-10-22 02:00Z','2030-10-22 04:00Z','In Progress'),
 ('dddddddd-dddd-4ddd-8ddd-ddddddddddd2','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-10-23 02:00Z','2030-10-23 04:00Z','In Progress');

-- END SYNTHETIC FIXTURE SETUP
create function pg_temp.expect_limit(p_action text, p_booking uuid, p_id uuid)
returns integer language plpgsql as $$
declare v_detail text; v_wait integer;
begin
  if p_action='message' then perform public.send_booking_message(p_booking,p_id,'SYNTHETIC LIMIT TEST');
  else perform public.begin_evidence_upload(p_booking,p_id,'before','png',128,repeat('a',64)); end if;
  raise exception 'Expected an authoritative rate rejection';
exception when sqlstate 'PT429' then
  assert sqlerrm = case when p_action='message' then 'CHAT_RATE_LIMITED' else 'EVIDENCE_RATE_LIMITED' end;
  get stacked diagnostics v_detail=PG_EXCEPTION_DETAIL;
  assert v_detail ~ '^retry_after_seconds=[0-9]+$';
  v_wait:=split_part(v_detail,'=',2)::integer;
  assert v_wait between 1 and 86400;
  return v_wait;
end $$;
grant execute on function pg_temp.expect_limit(text,uuid,uuid) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare i integer; r jsonb;
begin
  for i in 1..8 loop
    r:=public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
      ('11111111-1111-4111-8111-'||lpad(i::text,12,'0'))::uuid,'SYNTHETIC LIMIT TEST');
    assert (r->>'reused')::boolean=false;
  end loop;
  assert pg_temp.expect_limit('message','dddddddd-dddd-4ddd-8ddd-ddddddddddd1',gen_random_uuid()) between 1 and 10;
  -- Switching bookings cannot bypass the actor-level budget.
  assert pg_temp.expect_limit('message','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 10;
  assert (select count(*) from public.booking_message)=8;
  r:=public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1','11111111-1111-4111-8111-000000000001','SYNTHETIC LIMIT TEST');
  assert (r->>'reused')::boolean=true; -- lost-response retry is free
  begin
    perform public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1','11111111-1111-4111-8111-000000000001','CHANGED PAYLOAD');
    raise exception 'Changed retry content was accepted';
  exception when unique_violation then null; end;
  begin
    perform app_private.check_activity_budget(auth.uid(),'message');
    raise exception 'Client could call internal helper';
  exception when insufficient_privilege then null; end;
  begin
    update app_private.activity_limit set max_events=1000;
    raise exception 'Client could raise its own quota';
  exception when insufficient_privilege then null; end;
end $$;
-- A different actor still has its own budget.
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
select public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',gen_random_uuid(),'SYNTHETIC PROVIDER MESSAGE');
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
  begin
    perform public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',gen_random_uuid(),'UNRELATED ACTOR');
    raise exception 'Unrelated user sent a message';
  exception when insufficient_privilege then null; end;
end $$;

reset role;
delete from public.booking_message;
-- Seed only older-window activity, without waiting a real minute/hour.
insert into public.booking_message(booking_id,sender_user_id,client_message_id,body,created_at)
 select 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),
 'SYNTHETIC MINUTE WINDOW',clock_timestamp()-interval '20 seconds' from generate_series(1,40);
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin assert pg_temp.expect_limit('message','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 60; end $$;
reset role;
delete from public.booking_message;
insert into public.booking_message(booking_id,sender_user_id,client_message_id,body,created_at)
 select 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),
 'SYNTHETIC HOUR WINDOW',clock_timestamp()-interval '10 minutes' from generate_series(1,300);
set local role authenticated;
do $$ begin assert pg_temp.expect_limit('message','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 3600; end $$;
reset role;
update public.booking_message set created_at=clock_timestamp()-interval '2 hours';
set local role authenticated;
select public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid(),'OLD ACTIVITY HAS EXPIRED');

select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare i integer; r jsonb;
begin
  for i in 1..6 loop
    r:=public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
      ('22222222-2222-4222-8222-'||lpad(i::text,12,'0'))::uuid,'before','png',128,repeat('a',64));
    assert r->>'state'='pending';
  end loop;
  assert pg_temp.expect_limit('evidence','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 60;
  assert (select count(*) from public.evidence_upload)=6;
  r:=public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
    '22222222-2222-4222-8222-000000000001','before','png',128,repeat('a',64));
  assert r->>'state'='pending'; -- identical retry is free
  begin
    perform public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
      '22222222-2222-4222-8222-000000000001','before','png',129,repeat('b',64));
    raise exception 'Changed photo retry content was accepted';
  exception when check_violation then null; end;
end $$;
reset role;
delete from public.evidence_upload;
insert into public.evidence_upload(upload_id,booking_id,provider_id,kind,object_path,byte_size,sha256,created_at)
 select gen_random_uuid(),'dddddddd-dddd-4ddd-8ddd-ddddddddddd1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'before','synthetic-hour-fixture-'||i,128,repeat('a',64),clock_timestamp()-interval '10 minutes' from generate_series(1,30) i;
set local role authenticated;
do $$ begin assert pg_temp.expect_limit('evidence','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 3600; end $$;
reset role;
delete from public.evidence_upload;
insert into public.evidence_upload(upload_id,booking_id,provider_id,kind,object_path,byte_size,sha256,created_at)
 select gen_random_uuid(),'dddddddd-dddd-4ddd-8ddd-ddddddddddd1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'before','synthetic-day-fixture-'||i,128,repeat('a',64),clock_timestamp()-interval '2 hours' from generate_series(1,100) i;
set local role authenticated;
do $$ begin assert pg_temp.expect_limit('evidence','dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid()) between 1 and 86400; end $$;
reset role;
update public.evidence_upload set created_at=clock_timestamp()-interval '25 hours';
set local role authenticated;
select public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid(),'before','png',128,repeat('a',64));
reset role;

-- Policy corruption fails closed, rather than silently disabling enforcement.
savepoint missing_policy;
delete from app_private.activity_limit where action='message';
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
  begin
    perform public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd2',gen_random_uuid(),'MUST NOT SAVE');
    raise exception 'Missing policy disabled protection';
  exception when object_not_in_prerequisite_state then assert sqlerrm='ABUSE_POLICY_UNAVAILABLE'; end;
end $$;
reset role;
rollback to savepoint missing_policy;
rollback;

-- The API explicitly rejects a stale-snapshot isolation mode.
begin isolation level repeatable read;
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
  begin
    perform public.send_booking_message('dddddddd-dddd-4ddd-8ddd-ddddddddddd1',gen_random_uuid(),'UNSUPPORTED ISOLATION');
    raise exception 'Unsupported isolation was accepted';
  exception when invalid_transaction_state then assert sqlerrm='ABUSE_REQUIRES_READ_COMMITTED'; end;
end $$;
rollback;
