-- Synthetic disposable local SQL. Never creates hosted notifications.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@notification.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@notification.invalid'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@notification.invalid');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@notification.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@notification.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@notification.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','PRIVATE ORIGIN',50);
insert into public.service_type(service_type_id,name) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1','Notification cleaning');
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','Test','PRIVATE ADDRESS');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 select ('11111111-1111-4111-8111-'||lpad(n::text,12,'0'))::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',now()+interval '1 day',now()+interval '1 day 2 hours'
 from generate_series(1,25) n;
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare a jsonb;b jsonb;v_id uuid;v_time timestamptz;
begin
 a:=public.page_my_notifications();
 assert (a->>'total_count')::int=25 and (a->>'unread_count')::int=25;
 assert (a->>'action_count')::int=25 and jsonb_array_length(a->'items')=20;
 assert a->'next_cursor'<>'null'::jsonb;
 assert a::text not like '%PRIVATE ADDRESS%';
 b:=public.page_my_notifications('all',20,(a->'next_cursor'->>'timestamp')::timestamptz,
   (a->'next_cursor'->>'id')::uuid,(a->>'as_of')::timestamptz);
 assert jsonb_array_length(b->'items')=5;
 assert not exists(select 1 from jsonb_array_elements(a->'items') x join jsonb_array_elements(b->'items') y on x->>'id'=y->>'id');
 v_id:=(a->'items'->0->>'id')::uuid;
 assert public.read_my_notifications(array[v_id])=1;
 assert public.read_my_notifications(array[v_id])=0;
 assert (public.page_my_notifications()->>'unread_count')::int=24;
 begin perform public.read_my_notifications(array['00000000-0000-4000-8000-000000000000'::uuid]);
  raise exception 'Foreign notification accepted';exception when insufficient_privilege then null;end;
 begin perform public.page_my_notifications('bad');raise exception 'Invalid filter allowed';
  exception when invalid_parameter_value then null;end;
 begin perform public.read_my_notifications();raise exception 'Unbounded mark allowed';
  exception when invalid_parameter_value then null;end;
 assert public.read_my_notifications(null,(a->>'as_of')::timestamptz)=24;
 assert jsonb_array_length(public.page_my_notifications('unread')->'items')=0;
 assert (public.page_my_notifications()->>'total_count')::int=25;
 begin perform 1 from app_private.notification_read;raise exception 'Raw receipt table exposed';
  exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin assert (public.page_my_notifications()->>'total_count')::int=0;end $$;
reset role;
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status)
 values('11111111-1111-4111-8111-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Pending','Accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare a jsonb;begin
 a:=public.page_my_notifications();assert (a->>'total_count')::int=1 and (a->>'unread_count')::int=1;
 assert a->'items'->0->>'event_status'='Accepted';
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin assert (public.page_my_notifications()->>'total_count')::int=0;end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.page_my_notifications();raise exception 'Anon read allowed';exception when insufficient_privilege then null;end;
 begin perform public.read_my_notifications(null,now());raise exception 'Anon mark allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
