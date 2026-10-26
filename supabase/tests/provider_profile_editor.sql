-- Disposable local database, synthetic identities, no hosted profile writes.
begin;
insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@profile.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@profile.invalid'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@profile.invalid');
insert into public.user_account(user_id,email,role,contact_number) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@profile.invalid','owner',null),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@profile.invalid','provider',null),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@profile.invalid','provider',null);
insert into public.provider_profile(provider_id,bio,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Old','Area','PRIVATE ORIGIN',50),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Other','Other area','OTHER PRIVATE ORIGIN',80);
insert into public.service_type(service_type_id,name) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1','Profile standard'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2','Profile deep');
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','Test','Private property');
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare r jsonb; v_input jsonb; v_revision bigint;
begin
 r:=public.my_provider_profile();
 assert r->>'provider_id'=auth.uid()::text and r->>'approval_status'='pending';
 assert r->>'email'='provider@profile.invalid' and r->>'show_phone_to_owners'='false';
 assert r->>'completed_jobs'='0' and r->>'rating_average' is null;
 v_input:=jsonb_build_object('display_name','Provider Name','bio','Saved bio',
   'service_area','New area','service_origin_address','NEW PRIVATE ORIGIN','hourly_rate',55.25,'daily_rate',300.50,
   'avatar_color_index',2,'show_phone_to_owners',true,'contact_number','+60 12-345 6789',
   'service_type_ids',jsonb_build_array('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'));
 r:=public.save_my_provider_profile(v_input,(r->>'revision')::bigint,null);
 assert r->>'display_name'='Provider Name' and r->>'contact_number'='+60 12-345 6789';
 assert (r->>'hourly_rate')::numeric=55.25 and (r->>'daily_rate')::numeric=300.50;
 assert r->>'approval_status'='pending' and r->>'rating_average' is null and r->>'completed_jobs'='0';
 assert (r->>'revision')::bigint>1;
 assert (select count(*) from public.provider_capability where provider_id=auth.uid())=1;
 v_revision:=(r->>'revision')::bigint;
 begin perform public.save_my_provider_profile(v_input,1,null);raise exception 'Stale draft allowed';
 exception when serialization_failure then null;end;
 begin perform public.save_my_provider_profile(v_input||'{"approval_status":"approved"}',v_revision,r->>'contact_number');
   raise exception 'Approval injection allowed';exception when invalid_parameter_value then null;end;
 begin perform public.save_my_provider_profile(v_input||'{"email":"hijack@profile.invalid"}',v_revision,r->>'contact_number');
   raise exception 'Unverified email change allowed';exception when invalid_parameter_value then null;end;
 begin perform public.save_my_provider_profile(v_input||'{"service_type_ids":["dddddddd-dddd-4ddd-8ddd-dddddddddddd"],"bio":"BAD PARTIAL CHANGE"}',v_revision,r->>'contact_number');
   raise exception 'Unknown service allowed';exception when check_violation then null;end;
 assert public.my_provider_profile()->>'bio'='Saved bio';
 assert (public.my_provider_profile()->>'revision')::bigint=v_revision;
 begin perform public.save_my_provider_profile(v_input||'{"hourly_rate":"NaN"}',v_revision,r->>'contact_number');
   raise exception 'Non-numeric rate allowed';exception when invalid_parameter_value then null;end;
 begin update public.provider_profile set approval_status='approved' where provider_id=auth.uid();
   raise exception 'Direct approval allowed';exception when insufficient_privilege then null;end;
 begin update public.provider_profile set profile_revision=999 where provider_id=auth.uid();
   raise exception 'Direct revision allowed';exception when insufficient_privilege then null;end;
 -- Daily-only providers keep a real nullable hourly rate, not a demo fallback.
 r:=public.save_my_provider_profile(v_input||'{"hourly_rate":null}',v_revision,r->>'contact_number');
 assert r->>'hourly_rate' is null and (r->>'daily_rate')::numeric=300.50;
end $$;
reset role;
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
  requested_start_at,requested_end_at,current_status,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount)
 values('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',now()+interval '1 day',now()+interval '1 day 2 hours',
 'Accepted','hourly',50,120,100);
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
 assert public.booking_provider_contact('11111111-1111-4111-8111-111111111111')='+60 12-345 6789';
 begin perform public.my_provider_profile();raise exception 'Owner read private profile';
 exception when insufficient_privilege then null;end;
 begin perform public.save_my_provider_profile('{}',1,null);raise exception 'Owner wrote profile';
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
 assert public.my_provider_profile()->>'provider_id'=auth.uid()::text;
 assert public.my_provider_profile()->>'service_origin_address'='OTHER PRIVATE ORIGIN';
 assert public.booking_provider_contact('11111111-1111-4111-8111-111111111111') is null;
end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare r jsonb; v_input jsonb; old_revision bigint;
begin
 r:=public.my_provider_profile();old_revision:=(r->>'revision')::bigint;
 v_input:=jsonb_build_object('display_name',r->>'display_name','bio','Must roll back',
   'service_area',r->>'service_area','service_origin_address',r->>'service_origin_address',
   'hourly_rate',50,'daily_rate',null,'avatar_color_index',0,'show_phone_to_owners',false,
   'contact_number','+60 12-000 0000','service_type_ids',jsonb_build_array('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'));
 begin perform public.save_my_provider_profile(v_input,old_revision,r->>'contact_number');
   raise exception 'Confirmed service removed';exception when check_violation then null;end;
 assert public.my_provider_profile()->>'bio'='Saved bio';
 assert public.my_provider_profile()->>'contact_number'='+60 12-345 6789';
 assert (public.my_provider_profile()->>'revision')::bigint=old_revision;
 v_input:=v_input||jsonb_build_object('service_type_ids',jsonb_build_array('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'));
 r:=public.save_my_provider_profile(v_input,old_revision,r->>'contact_number');
 assert r->>'show_phone_to_owners'='false';
 -- Existing capability setup invalidates another editor's old revision.
 old_revision:=(r->>'revision')::bigint;
 perform public.replace_provider_capabilities(array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'::uuid,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'::uuid]);
 assert (public.my_provider_profile()->>'revision')::bigint>old_revision;
 begin perform public.save_my_provider_profile(v_input,old_revision,r->>'contact_number');
   raise exception 'Old services overwrite allowed';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin assert public.booking_provider_contact('11111111-1111-4111-8111-111111111111') is null;end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.my_provider_profile();raise exception 'Anonymous private read';
 exception when insufficient_privilege then null;end;
 begin perform public.save_my_provider_profile('{}',1,null);raise exception 'Anonymous write';
 exception when insufficient_privilege then null;end;
 begin perform public.booking_provider_contact('11111111-1111-4111-8111-111111111111');raise exception 'Anonymous phone read';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
