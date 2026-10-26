-- Local disposable fixtures only. Roll back all user data and account edits.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@uat.invalid','{"requested_display_name":"  Wan Ting  "}'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@uat.invalid','{"requested_display_name":"Provider Name"}'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@uat.invalid','{}'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bad@uat.invalid','{"requested_display_name":"x"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
select set_config('request.jwt.claims','{"email":"owner@uat.invalid"}',true);
insert into public.user_account(user_id,email,role) values(auth.uid(),'owner@uat.invalid','owner');
do $$begin
 assert (select display_name='Wan Ting' from public.user_account where user_id=auth.uid());
 assert not has_column_privilege('authenticated','public.user_account','display_name','INSERT');
end;$$;
reset role;
do $$begin assert not has_function_privilege('authenticated','app_private.seed_registration_display_name()','EXECUTE');end;$$;
insert into public.user_account(user_id,email,role) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@uat.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@uat.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate)
 values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Area','PRIVATE ORIGIN',40);
do $$begin
 assert (select display_name='Provider Name' from public.provider_profile where provider_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
 begin
  insert into public.user_account(user_id,email,role) values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bad@uat.invalid','owner');
  raise exception 'Invalid registration name accepted';
 exception when invalid_parameter_value then null;end;
end;$$;
insert into public.property(owner_id,unit_name,building_name,address,bedrooms,size_sqft)
 select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Unit '||n,'Building '||(n%3),'PRIVATE ADDRESS',2,800 from generate_series(1,25) n;
insert into public.property(owner_id,unit_name,building_name,address,bedrooms,size_sqft)
 values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Other unit','Other building','PRIVATE OTHER',5,9000);
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$declare s jsonb;p jsonb;begin
 s:=public.my_owner_portfolio_summary();p:=public.page_my_properties();
 assert jsonb_array_length(p->'items')=20;
 assert (s->>'property_count')::int=25 and (s->>'building_count')::int=3 and (s->>'size_sqft')::int=20000;
 assert (s->>'total')::int=0 and (s->>'open')::int=0 and (s->>'done')::int=0;
 assert s::text not like '%PRIVATE%';
 perform public.save_my_owner_profile('{"display_name":"Updated name","contact_number":null}',1);
 assert (select display_name='Updated name' from public.user_account where user_id=auth.uid());
end;$$;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$begin assert (public.my_owner_portfolio_summary()->>'property_count')::int=1;end;$$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$begin
 begin perform public.my_owner_portfolio_summary();raise exception 'Provider read owner summary';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
set local role anon;
do $$begin
 begin perform public.my_owner_portfolio_summary();raise exception 'Anonymous summary read';
 exception when insufficient_privilege then null;end;
end;$$;
rollback;
