-- Synthetic local-only fixtures, rolled back. Never copy to hosted accounts.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@chat.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@chat.invalid'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@chat.invalid');
insert into public.user_account(user_id,email,role,contact_number) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@chat.invalid','owner','PRIVATE PHONE'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@chat.invalid','provider','PRIVATE PHONE'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@chat.invalid','owner',null);
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate,display_name) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','PRIVATE ORIGIN',50,'Real provider');
insert into public.service_type(service_type_id,name) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1','Conversation cleaning');
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','Test','PRIVATE ADDRESS'),
 ('ffffffff-ffff-4fff-8fff-fffffffffffe','cccccccc-cccc-4ccc-8ccc-cccccccccccc','Foreign unit','Other','PRIVATE ADDRESS');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,current_status,created_at)
 select ('11111111-1111-4111-8111-'||lpad(n::text,12,'0'))::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',now()+n*interval '1 day',now()+n*interval '1 day'+interval '2 hours',
 (case when n=1 then 'Completed' when n=26 then 'Pending' when n=27 then 'Cancelled' else 'Accepted' end)::public.booking_status_enum,
 now()-interval '2 days' from generate_series(1,27) n;
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,current_status,created_at) values
 ('22222222-2222-4222-8222-222222222222','cccccccc-cccc-4ccc-8ccc-cccccccccccc',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-fffffffffffe',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',now()+interval '50 days',now()+interval '50 days 2 hours','Accepted',now()-interval '2 days');
insert into public.booking_message(booking_id,sender_user_id,client_message_id,body,created_at)
 select booking_id,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),
 'Actual server message',now()-interval '1 hour' from public.booking
 where owner_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and current_status in ('Accepted','Completed')
 and booking_id<>'11111111-1111-4111-8111-000000000025';
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare a jsonb;b jsonb;begin
 a:=public.page_my_conversations();
 assert jsonb_array_length(a->'items')=20 and (a->>'has_more')::boolean;
 assert a->>'recipient_id'='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 assert a::text not like '%PRIVATE%' and a::text not like '%@chat.invalid%';
 assert a::text not like '%Foreign unit%';
 assert a->'items'->0->>'counterpart_name'='Real provider';
 b:=public.page_my_conversations(20,(a->'next_cursor'->>'timestamp')::timestamptz,
   (a->'next_cursor'->>'id')::uuid,(a->>'as_of')::timestamptz);
 assert jsonb_array_length(b->'items')=5 and not (b->>'has_more')::boolean;
 assert not exists(select 1 from jsonb_array_elements(a->'items') x join jsonb_array_elements(b->'items') y on x->>'booking_id'=y->>'booking_id');
 assert exists(select 1 from jsonb_array_elements(b->'items') x where x->>'status'='Completed');
 assert exists(select 1 from jsonb_array_elements(b->'items') x where x->>'last_message'='');
 assert jsonb_array_length(public.page_my_conversations(p_search=>'Foreign unit')->'items')=0;
 assert jsonb_array_length(public.page_my_conversations(p_search=>'%')->'items')=0;
 assert jsonb_array_length(public.page_my_conversations(p_search=>'REAL PROVIDER')->'items')=20;
 begin perform public.page_my_conversations(p_limit=>0);raise exception 'Bad limit accepted';exception when invalid_parameter_value then null;end;
 begin perform public.page_my_conversations(p_before_at=>now());raise exception 'Partial cursor accepted';exception when invalid_parameter_value then null;end;
 begin perform public.page_my_conversations(p_search=>repeat('a',81));raise exception 'Long search accepted';exception when invalid_parameter_value then null;end;
 begin perform public.page_my_conversations(p_before_at=>now(),p_before_id=>gen_random_uuid());raise exception 'Unanchored cursor accepted';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin assert jsonb_array_length(public.page_my_conversations()->'items')=1;end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ begin
 assert jsonb_array_length(public.page_my_conversations(p_search=>'Other')->'items')=1;
 assert public.page_my_conversations()->'items'->0->>'counterpart_name'='Property Owner';
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin perform public.page_my_conversations();raise exception 'No identity accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- An incoming message after page one must not move an older thread out of
-- the anchored next page. A manual/visible refresh starts a new snapshot.
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare a jsonb;b jsonb;begin
 a:=public.page_my_conversations();
 insert into public.booking_message(booking_id,sender_user_id,client_message_id,body,created_at)
 values('11111111-1111-4111-8111-000000000025','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),
 'New message after snapshot',(a->>'as_of')::timestamptz+interval '1 millisecond');
 b:=public.page_my_conversations(20,(a->'next_cursor'->>'timestamp')::timestamptz,
   (a->'next_cursor'->>'id')::uuid,(a->>'as_of')::timestamptz);
 assert jsonb_array_length(b->'items')=5;
 assert exists(select 1 from jsonb_array_elements(b->'items') x where
   x->>'booking_id'='11111111-1111-4111-8111-000000000025' and x->>'last_message'='');
 assert b::text not like '%New message after snapshot%';
end $$;
set local role anon;
do $$ begin
 begin perform public.page_my_conversations();raise exception 'Anon allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
