-- Synthetic local rollback-only regression. Never changes a hosted approval.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@approval.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@approval.invalid');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@approval.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@approval.invalid','provider');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate,approval_status)
 values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','TEST ONLY',50,'approved');
insert into public.property(property_id,owner_id,unit_name,building_name,address)
 values('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','TEST','TEST');
insert into public.service_type(service_type_id,name)
 values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Approval regression');
insert into public.provider_capability values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
insert into public.provider_weekly_slot(provider_id,weekday,start_time,end_time)
 select 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',n,'08:00','18:00' from generate_series(1,7)n;
-- Request was valid while approved. An administrator later withdraws approval.
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount)
 values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 (((now() at time zone 'Asia/Kuala_Lumpur')::date+14)+time '10:00') at time zone 'Asia/Kuala_Lumpur',
 (((now() at time zone 'Asia/Kuala_Lumpur')::date+14)+time '12:00') at time zone 'Asia/Kuala_Lumpur',
 'hourly',50,120,100);
update public.provider_profile set approval_status='pending';
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare r jsonb;begin
 r:=public.accept_pending_booking('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
 assert r->>'accepted'='false' and r->>'reason'='provider_not_approved',
  'Revoked approval must deny accepting an existing Pending request';
 assert (select current_status from public.booking where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')='Pending';
 assert (select count(*) from public.booking_status_history where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')=1;
end $$;
reset role;
update public.provider_profile set approval_status='rejected';
set local role authenticated;
do $$ declare r jsonb;begin
 r:=public.accept_pending_booking('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
 assert r->>'accepted'='false' and r->>'reason'='provider_not_approved';
end $$;
reset role;
update public.provider_profile set approval_status='approved';
set local role authenticated;
do $$ declare r jsonb;begin
 r:=public.accept_pending_booking('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
 assert r->>'accepted'='true','Approved assigned Provider can still accept';
 assert (select count(*) from public.booking_status_history where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')=2;
 r:=public.accept_pending_booking('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
 assert r->>'accepted'='false' and r->>'reason'='not_pending';
 assert (select count(*) from public.booking_status_history where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')=2;
end $$;
reset role;
-- A stale Pending request cannot be accepted after its requested start. This
-- is an existing acceptance rule, distinct from the undecided early-start rule.
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount)
 values('99999999-9999-4999-8999-999999999999','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',now()-interval '2 days',now()-interval '2 days'+interval '2 hours',
 'hourly',50,120,100);
set local role authenticated;
do $$ declare r jsonb;begin
 r:=public.accept_pending_booking('99999999-9999-4999-8999-999999999999');
 assert r->>'accepted'='false' and r->>'reason'='rental_window';
 assert (select current_status from public.booking where booking_id='99999999-9999-4999-8999-999999999999')='Pending';
 assert (select count(*) from public.booking_status_history where booking_id='99999999-9999-4999-8999-999999999999')=1;
end $$;
reset role;
rollback;
