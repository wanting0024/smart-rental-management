-- Rollback-only local permissions/read-boundary regression, not hosted UAT.
begin;
insert into auth.users(id) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@read.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@read.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@read.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate,approval_status)
 values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','TEST','PRIVATE',40,'approved');
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','TEST','PRIVATE');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Read test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,current_status)
 select ('11111111-1111-4111-8111-'||lpad(n::text,12,'0'))::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 '2035-10-12 02:00Z'::timestamptz+n*interval '1 day','2035-10-12 04:00Z'::timestamptz+n*interval '1 day','Accepted'
 from generate_series(1,2)n;
insert into public.booking_message(message_id,booking_id,sender_user_id,client_message_id,body,created_at) values
 ('22222222-2222-4222-8222-000000000001','11111111-1111-4111-8111-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),'Incoming old','2020-01-01Z'),
 ('22222222-2222-4222-8222-000000000002','11111111-1111-4111-8111-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),'Incoming visible','2020-01-02Z'),
 ('22222222-2222-4222-8222-000000000003','11111111-1111-4111-8111-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'Own message','2020-01-03Z'),
 ('22222222-2222-4222-8222-000000000004','11111111-1111-4111-8111-000000000002','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),'Other thread','2020-01-04Z');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare a jsonb;begin
 assert (public.my_message_unread()->>'messages')::int=3;
 assert (public.my_message_unread()->>'threads')::int=2;
 a:=public.page_my_conversations();assert (a->>'unread_total')::int=3;
 assert exists(select 1 from jsonb_array_elements(a->'items')x where (x->>'unread_count')::int=2);
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array[]::uuid[]);
  raise exception 'Empty IDs accepted';exception when invalid_parameter_value then null;end;
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000003']::uuid[]);
  raise exception 'Own message accepted';exception when insufficient_privilege then null;end;
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000002','22222222-2222-4222-8222-000000000004']::uuid[]);
  raise exception 'Mixed thread accepted';exception when insufficient_privilege then null;end;
 assert (public.my_message_unread()->>'messages')::int=3,'Failed batch must be atomic';
 perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000002']::uuid[]);
 perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000002']::uuid[]);
 assert (public.my_message_unread()->>'messages')::int=2,'Idempotent exact-ID read leaves unseen older message unread';
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array_fill('22222222-2222-4222-8222-000000000002'::uuid,array[51]));
  raise exception 'Unbounded batch accepted';exception when invalid_parameter_value then null;end;
end $$;
-- Separate statement: fresh snapshot includes confirmed read. No whole-thread reset.
do $$ begin
 assert (public.page_my_conversations()->>'unread_total')::int=2;
 assert jsonb_array_length(public.page_my_unread_conversations()->'items')=2;
 perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000001']::uuid[]);
end $$;
do $$ begin assert jsonb_array_length(public.page_my_unread_conversations()->'items')=1;end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ begin
 assert (public.my_message_unread()->>'messages')::int=1,'Peer read receipt must not clear my incoming message';
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
 assert (public.my_message_unread()->>'messages')::int=0;
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000001']::uuid[]);
  raise exception 'Outsider accepted';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.message_read_receipt;raise exception 'Private table exposed';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- A new message arriving after read remains unread, even with same created_at.
insert into public.booking_message(message_id,booking_id,sender_user_id,client_message_id,body,created_at)
 values('22222222-2222-4222-8222-000000000005','11111111-1111-4111-8111-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),'New arrival','2020-01-02Z');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin assert (public.my_message_unread()->>'messages')::int=2;end $$;
set local role anon;
do $$ begin
 begin perform public.my_message_unread();raise exception 'Anon count exposed';exception when insufficient_privilege then null;end;
 begin perform public.read_booking_messages('11111111-1111-4111-8111-000000000001',array['22222222-2222-4222-8222-000000000001']::uuid[]);
  raise exception 'Anon write accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
