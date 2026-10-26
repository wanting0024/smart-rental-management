-- Disposable local fixtures only; no hosted users or business data.
begin;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','owner@nav.invalid'),
 ('22222222-2222-4222-8222-222222222222','other@nav.invalid');
insert into public.user_account(user_id,email,role) values
 ('11111111-1111-4111-8111-111111111111','owner@nav.invalid','owner'),
 ('22222222-2222-4222-8222-222222222222','other@nav.invalid','owner');
insert into auth.users(id,email) select md5('nav-provider-'||n)::uuid,'p'||n||'@nav.invalid' from generate_series(1,27)n;
insert into public.user_account(user_id,email,role,created_at)
 select md5('nav-provider-'||n)::uuid,'p'||n||'@nav.invalid','provider','2020-01-01'::timestamptz+make_interval(secs=>n) from generate_series(1,27)n;
insert into public.provider_profile(provider_id,display_name,service_area,service_origin_address,hourly_rate,approval_status,bio)
 select md5('nav-provider-'||n)::uuid,case when n=1 then 'Needle name' else 'Provider '||n end,
  'Test area','PRIVATE ORIGIN',40,case when n=27 then 'pending' else 'approved' end,'Public bio' from generate_series(1,27)n;
insert into public.service_type(service_type_id,name,description) values
 ('33333333-3333-4333-8333-333333333333','Nav service','Public scope'),
 ('44444444-4444-4444-8444-444444444444','Needle service','Special scope');
insert into public.provider_capability(provider_id,service_type_id)
 select md5('nav-provider-'||n)::uuid,case when n=1 then '44444444-4444-4444-8444-444444444444'::uuid else '33333333-3333-4333-8333-333333333333'::uuid end from generate_series(1,27)n;
insert into public.property(property_id,owner_id,unit_name,building_name,address,bedrooms,size_sqft) values
 ('55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','Needle unit','Nav Building','OWNER ADDRESS',2,800),
 ('66666666-6666-4666-8666-666666666666','11111111-1111-4111-8111-111111111111','Ordinary unit','Nav Building','OWNER ADDRESS',2,800),
 ('77777777-7777-4777-8777-777777777777','22222222-2222-4222-8222-222222222222','Private other','Private other','OTHER PRIVATE',2,800);
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,created_at,current_status)
 select md5('nav-booking-'||n)::uuid,'11111111-1111-4111-8111-111111111111',md5('nav-provider-1')::uuid,
  case when n=1 then '55555555-5555-4555-8555-555555555555'::uuid else '66666666-6666-4666-8666-666666666666'::uuid end,
  '33333333-3333-4333-8333-333333333333','2030-01-01'::timestamptz+make_interval(days=>n),
  '2030-01-01'::timestamptz+make_interval(days=>n,hours=>2),'2020-01-01'::timestamptz+make_interval(secs=>n),
  case when n=27 then 'Completed'::public.booking_status_enum else 'Pending'::public.booking_status_enum end from generate_series(1,27)n;
insert into public.booking(owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 values('22222222-2222-4222-8222-222222222222',md5('nav-provider-1')::uuid,'77777777-7777-4777-8777-777777777777',
 '33333333-3333-4333-8333-333333333333','2031-01-01','2031-01-01 02:00Z');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$declare p jsonb;q jsonb;c jsonb;begin
 p:=public.page_approved_provider_directory();c:=p->'next_cursor';
 assert jsonb_array_length(p->'items')=20 and (p->>'has_more')::boolean;
 q:=public.page_approved_provider_directory('',20,(c->>'timestamp')::timestamptz,(c->>'id')::uuid);
 assert jsonb_array_length(q->'items')=6 and not (q->>'has_more')::boolean;
 assert not exists(select 1 from jsonb_array_elements(p->'items') a join jsonb_array_elements(q->'items') b on a->>'provider_id'=b->>'provider_id');
 assert p::text not like '%PRIVATE%' and p::text not like '%@nav.invalid%' and p::text not like '%contact_number%';
 assert jsonb_array_length(public.page_approved_provider_directory('Needle service')->'items')=1;
 assert public.page_approved_provider_directory('Needle name')->'items'->0->>'display_name'='Needle name';
 assert jsonb_array_length(public.page_approved_provider_directory('%')->'items')=0;
 p:=public.page_owner_booking_search();c:=p->'next_cursor';
 assert jsonb_array_length(p->'items')=20 and p::text not like '%OTHER PRIVATE%';
 q:=public.page_owner_booking_search('', 'all',20,(c->>'timestamp')::timestamptz,(c->>'id')::uuid);
 assert jsonb_array_length(q->'items')=7;
 assert jsonb_array_length(public.page_owner_booking_search('Needle unit')->'items')=1;
 assert jsonb_array_length(public.page_owner_booking_search('', 'history')->'items')=1;
 assert jsonb_array_length(public.page_owner_booking_search('', 'pending')->'items')=20;
 assert jsonb_array_length(public.page_owner_booking_search('%')->'items')=0;
 p:=public.page_owner_booking_search('', 'all',20,null,null,true);c:=p->'next_cursor';
 q:=public.page_owner_booking_search('', 'all',20,(c->>'timestamp')::timestamptz,(c->>'id')::uuid,true);
 assert jsonb_array_length(q->'items')=7;
 assert not exists(select 1 from jsonb_array_elements(p->'items') a join jsonb_array_elements(q->'items') b on a->>'booking_id'=b->>'booking_id');
 begin perform public.page_owner_booking_search('', 'bad');raise exception 'Bad filter accepted';exception when invalid_parameter_value then null;end;
 begin perform public.page_approved_provider_directory('',51);raise exception 'Bad page limit accepted';exception when invalid_parameter_value then null;end;
 begin perform public.page_owner_booking_search('', 'all',20,now());raise exception 'Half cursor accepted';exception when invalid_parameter_value then null;end;
end;$$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$begin
 assert jsonb_array_length(public.page_owner_booking_search()->'items')=1;
 assert jsonb_array_length(public.page_owner_booking_search('Needle unit')->'items')=0;
end;$$;
select set_config('request.jwt.claim.sub',md5('nav-provider-1')::uuid::text,true);
do $$begin
 begin perform public.page_owner_booking_search();raise exception 'Provider read owner search';exception when insufficient_privilege then null;end;
 begin perform public.page_approved_provider_directory();raise exception 'Provider read owner directory';exception when insufficient_privilege then null;end;
end;$$;
reset role;
set local role anon;
do $$begin
 begin perform public.page_owner_booking_search();raise exception 'Anon search access';exception when insufficient_privilege then null;end;
 begin perform public.page_approved_provider_directory();raise exception 'Anon directory access';exception when insufficient_privilege then null;end;
end;$$;
rollback;
