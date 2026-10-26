-- Synthetic local data ONLY. Every row is rolled back.
begin;
insert into auth.users(id) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@earnings.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@earnings.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@earnings.invalid','provider');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test','Private origin',50),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Test','Other private origin',90);
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A','Test','PRIVATE ADDRESS');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Earnings test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,current_status,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount)
 select ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'ffffffff-ffff-4fff-8fff-ffffffffffff','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 '2020-02-01 02:00Z'::timestamptz,case when i=44 then '2020-02-01 10:00Z'::timestamptz else '2020-02-01 04:00Z'::timestamptz end,
 'Completed',case when i=45 then null when i=44 then 'daily' else 'hourly' end,
 case when i=45 then null when i=44 then 280 else 50.005 end,
 case when i=45 then null when i=44 then 480 else 120 end,
 case when i=45 then null when i=44 then 280 else 100.01 end
 from generate_series(1,46) i;
-- An insert initial history is Pending, not proof of completion.
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status,changed_at)
 select ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','In Progress','Completed',
 case i when 41 then '2020-02-29 16:00Z'::timestamptz
 when 42 then '2020-02-29 15:59:59Z'::timestamptz
 when 43 then '2020-01-31 00:00Z'::timestamptz
 else '2020-03-01 00:00:00.123456Z'::timestamptz end from generate_series(1,45) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare r jsonb; cursor_at timestamptz; cursor_id uuid; ids text[]:='{}'; item jsonb;
begin
 r:=public.provider_earnings('thisMonth',null,null,'2020-03-01 12:00Z');
 assert r->>'jobs'='43' and r->>'unpriced_jobs'='1' and r->>'undated_jobs'='1',r::text;
 assert (r->>'gross')::numeric=4380.41;
 assert jsonb_array_length(r->'items')=20 and r->'next_cursor' <> 'null'::jsonb;
 assert not (r::text like '%PRIVATE ADDRESS%');
 assert r->>'start_day'='2020-03-01';
 assert (select sum((value->>'gross')::numeric) from jsonb_array_elements(r->'buckets'))=4380.41;
 loop
  for item in select value from jsonb_array_elements(r->'items') loop
   ids:=array_append(ids,item->>'booking_id');
  end loop;
  exit when r->'next_cursor'='null'::jsonb;
  cursor_at:=(r->'next_cursor'->>'timestamp')::timestamptz;
  cursor_id:=(r->'next_cursor'->>'id')::uuid;
  r:=public.provider_earnings('thisMonth',cursor_at,cursor_id,'2020-03-01 12:00Z');
  assert r->>'jobs'='43' and (r->>'gross')::numeric=4380.41;
 end loop;
 assert cardinality(ids)=43;
 assert (select count(distinct id) from unnest(ids) id)=43;
 r:=public.provider_earnings('last30',null,null,'2020-03-01 12:00Z');
 assert r->>'jobs'='44' and r->>'start_day'='2020-02-01';
 r:=public.provider_earnings('allTime',null,null,'2020-03-01 12:00Z');
 assert r->>'jobs'='45' and (r->>'gross')::numeric=4580.43;
 begin perform public.provider_earnings('bad'); raise exception 'Invalid period allowed';
 exception when invalid_parameter_value then null;end;
 begin perform public.provider_earnings('allTime',now(),null); raise exception 'Partial cursor allowed';
 exception when invalid_parameter_value then null;end;
 begin perform public.provider_earnings('allTime',null,null,now()+interval '1 day'); raise exception 'Future snapshot allowed';
 exception when invalid_parameter_value then null;end;
end $$;
-- Session/role isolation. No caller-supplied provider ID exists.
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin assert public.provider_earnings('allTime')->>'jobs'='0';end $$;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ begin
 begin perform public.provider_earnings(); raise exception 'Owner allowed';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.provider_earnings(); raise exception 'Anon allowed';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
