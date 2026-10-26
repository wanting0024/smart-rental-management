-- Disposable synthetic local-only data. Not an approval of hosted workflows.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@workspace.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@workspace.invalid'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@workspace.invalid');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@workspace.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@workspace.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@workspace.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate,display_name) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','PRIVATE ORIGIN',50,'Actual provider');
insert into public.property(property_id,owner_id,unit_name,building_name,address,bedrooms,size_sqft)
 select ('11111111-1111-4111-8111-'||lpad(n::text,12,'0'))::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'Unit '||n,'Building','PRIVATE ADDRESS',2,800 from generate_series(1,25) n;
insert into public.service_type(service_type_id,name) values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Workspace cleaning');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,
 current_status,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount,created_at)
 select ('22222222-2222-4222-8222-'||lpad(n::text,12,'0'))::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','11111111-1111-4111-8111-000000000001','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 '2020-02-01 02:00Z','2020-02-01 04:00Z','Completed',
 case when n=25 then null else 'hourly' end,case when n=25 then null else 50.005 end,
 case when n=25 then null else 120 end,case when n=25 then null else 100.01 end,'2020-01-01 00:00Z'
 from generate_series(1,26) n;
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status,changed_at)
 select booking_id,provider_id,'In Progress','Completed','2020-03-01 00:00:00.123456Z' from public.booking
 where booking_id<>'22222222-2222-4222-8222-000000000026';
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status,changed_at)
 select booking_id,provider_id,'Pending','Accepted','2020-01-01 00:12Z' from public.booking;
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare a jsonb;b jsonb;p jsonb;begin
 a:=public.my_owner_profile();assert (a->>'property_count')::int=25 and (a->>'revision')::int=1;
 assert a->>'email'='owner@workspace.invalid';
 b:=public.save_my_owner_profile('{"display_name":"Actual owner","contact_number":"+60123456789"}',1);
 assert b->>'display_name'='Actual owner' and (b->>'revision')::int=2;
 begin perform public.save_my_owner_profile('{"display_name":"Old draft","contact_number":null}',1);
  raise exception 'Stale overwrite allowed';exception when serialization_failure then null;end;
 begin perform public.save_my_owner_profile('{"display_name":"Owner","contact_number":null,"role":"provider"}',2);
  raise exception 'Role forgery allowed';exception when invalid_parameter_value then null;end;
 a:=public.page_my_properties();assert (a->>'total_count')::int=25 and jsonb_array_length(a->'items')=20;
 assert (public.my_owner_portfolio_summary()->>'property_count')::int=25;
 assert (public.my_owner_portfolio_summary()->>'done')::int=26;
 assert (public.my_owner_portfolio_summary()->>'total')::int=26;
 b:=public.page_my_properties((a->'next_cursor'->>'timestamp')::timestamptz,(a->'next_cursor'->>'id')::uuid);
 assert jsonb_array_length(b->'items')=5;
 assert not exists(select 1 from jsonb_array_elements(a->'items') x join jsonb_array_elements(b->'items') y on x->>'property_id'=y->>'property_id');
 p:=public.my_property('11111111-1111-4111-8111-000000000001');assert (p->>'total')::int=26;
 b:=public.save_my_property('11111111-1111-4111-8111-000000000001',1,
  '{"unit_name":"Edited","building_name":"Building","address":"Changed address","bedrooms":3,"size_sqft":900,"cleaning_window_start":"08:00","cleaning_window_end":"18:00"}');
 assert b->>'unit_name'='Edited' and (b->>'property_revision')::int=2;
 begin perform public.save_my_property('11111111-1111-4111-8111-000000000001',1,
  '{"unit_name":"Old","building_name":"Building","address":"Changed address","bedrooms":3,"size_sqft":900,"cleaning_window_start":"08:00","cleaning_window_end":"18:00"}');
  raise exception 'Stale property overwrite allowed';exception when serialization_failure then null;end;
 a:=public.page_my_property_bookings('11111111-1111-4111-8111-000000000001');
 assert jsonb_array_length(a->'items')=20 and (a->>'has_more')::boolean;
 a:=public.owner_spending('thisMonth',null,null,'2020-03-01 12:00Z');
 assert (a->>'jobs')::int=25 and (a->>'unpriced')::int=1 and (a->>'undated')::int=1;
 assert (a->>'gross')::numeric=2400.24 and (a->>'this_month')::numeric=2400.24;
 assert a::text not like '%PRIVATE%' and jsonb_array_length(a->'items')=20;
 b:=public.owner_spending('thisMonth',(a->'next_cursor'->>'timestamp')::timestamptz,
  (a->'next_cursor'->>'id')::uuid,(a->>'as_of')::timestamptz);
 assert jsonb_array_length(b->'items')=5 and b->>'as_of'=a->>'as_of';
 assert jsonb_array_length(public.owner_spending('last30',null,null,'2020-04-30 12:00Z')->'items')=0;
 begin perform public.my_provider_statistics();raise exception 'Owner read Provider statistics';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
 assert public.page_my_properties()->>'total_count'='0';assert public.owner_spending()->>'jobs'='0';
 begin perform public.my_property('11111111-1111-4111-8111-000000000001');raise exception 'Foreign property visible';exception when insufficient_privilege then null;end;
 begin perform public.page_my_property_bookings('11111111-1111-4111-8111-000000000001');raise exception 'Foreign property bookings visible';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare a jsonb;begin
 a:=public.my_provider_statistics();assert (a->>'total')::int=26 and (a->>'accepted')::int=26;
 assert (a->>'decisions')::int=26 and (a->>'accepted_decisions')::int=26;
 assert (a->>'response_minutes')::numeric=12 and (a->>'repeat_jobs')::int=25;
 assert (a->>'undated_completions')::int=1 and jsonb_array_length(a->'weeks')=8;
 assert a::text not like '%PRIVATE%';
 begin perform public.my_owner_profile();raise exception 'Provider read Owner profile';exception when insufficient_privilege then null;end;
 begin perform public.owner_spending();raise exception 'Provider read Owner spending';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.my_owner_profile();raise exception 'Anon profile';exception when insufficient_privilege then null;end;
 begin perform public.page_my_properties();raise exception 'Anon properties';exception when insufficient_privilege then null;end;
 begin perform public.owner_spending();raise exception 'Anon spending';exception when insufficient_privilege then null;end;
 begin perform public.my_provider_statistics();raise exception 'Anon stats';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
