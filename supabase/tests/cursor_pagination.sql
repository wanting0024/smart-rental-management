-- Disposable PostgreSQL only. Synthetic tie-heavy fixtures, not app users.
begin;
insert into auth.users(id) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id,email,role) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','owner@pages.invalid','owner'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','provider@pages.invalid','provider'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','other@pages.invalid','owner');
insert into public.provider_profile(provider_id,service_area,service_origin_address,hourly_rate) values
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test','Private origin',50);
insert into public.property(property_id,owner_id,unit_name,building_name,address) values
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','1','Test','Owner A address'),
 ('ffffffff-ffff-4fff-8fff-fffffffffff2','cccccccc-cccc-4ccc-8ccc-cccccccccccc','2','Test','Other owner address');
insert into public.service_type(service_type_id,name) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Page test');
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,created_at,current_status)
 select ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'ffffffff-ffff-4fff-8fff-ffffffffffff','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 '2030-10-22 02:00Z','2030-10-22 04:00Z','2030-10-22 02:00:00.123456Z',
 case when i=1 then 'Accepted'::public.booking_status_enum else 'Pending'::public.booking_status_enum end
 from generate_series(1,61) i;
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 values('20000000-0000-4000-8000-000000000001','cccccccc-cccc-4ccc-8ccc-cccccccccccc',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-fffffffffff2',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2030-10-23 02:00Z','2030-10-23 04:00Z');
insert into public.booking_message(message_id,booking_id,sender_user_id,client_message_id,body,created_at)
 select ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'10000000-0000-4000-8000-000000000001',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',gen_random_uuid(),'SYNTHETIC PAGINATION FIXTURE '||i,'2030-10-22 02:00:00.123456Z'
 from generate_series(1,67) i;
insert into public.booking_status_history(status_history_id,booking_id,changed_by_user_id,previous_status,new_status,changed_at)
 select ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'10000000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Pending',case when i=57 then 'Accepted'::public.booking_status_enum else 'Pending'::public.booking_status_enum end,
 '2030-10-22 02:00:00.123456Z' from generate_series(1,57) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
do $$ declare page jsonb; cursor_at timestamptz; cursor_id uuid; ids text[]:='{}'; row jsonb; n integer; kind text;
begin
  foreach kind in array array['bookings','messages','history'] loop
    cursor_at:=null; cursor_id:=null; ids:='{}';
    loop
      page:=case kind when 'bookings' then public.page_my_bookings(20,cursor_at,cursor_id)
        when 'messages' then public.page_booking_messages('10000000-0000-4000-8000-000000000001',20,cursor_at,cursor_id)
        else public.page_booking_history('10000000-0000-4000-8000-000000000001',20,cursor_at,cursor_id) end;
      assert jsonb_array_length(page->'items')<=20;
      for row in select value from jsonb_array_elements(page->'items') loop
        ids:=array_append(ids,row->>case kind when 'bookings' then 'booking_id' when 'messages' then 'message_id' else 'status_history_id' end);
        if kind='bookings' then assert row->>'property_address'='Owner A address'; end if;
      end loop;
      exit when not (page->>'has_more')::boolean;
      assert page->'next_cursor'->>'timestamp' like '%123456%';
      cursor_at:=(page->'next_cursor'->>'timestamp')::timestamptz;
      cursor_id:=(page->'next_cursor'->>'id')::uuid;
    end loop;
    -- The booking INSERT trigger also created one initial history event.
    n:=case kind when 'bookings' then 61 when 'messages' then 67 else 58 end;
    assert cardinality(ids)=n,format('%s: got %s rows, expected %s',kind,cardinality(ids),n);
    assert (select count(distinct id) from unnest(ids) id)=n;
  end loop;
  page:=public.owner_dashboard_summary();
  assert page->>'property_count'='1' and page->>'pending_count'='60' and page->>'active_count'='1';
  assert jsonb_array_length(public.booking_cards_by_ids(array['20000000-0000-4000-8000-000000000001'::uuid]))=0;
  begin perform public.page_my_bookings(51); raise exception 'Oversized page permitted';
    exception when invalid_parameter_value then null; end;
  begin perform public.page_my_bookings(20,now(),null); raise exception 'Partial cursor permitted';
    exception when invalid_parameter_value then null; end;
end $$;
reset role;
-- Insert ahead of an existing cursor. The next older page must not shift.
create temporary table page_snapshot as
  with head as(select public.page_my_bookings(20) as first)
  select first,public.page_my_bookings(20,(first->'next_cursor'->>'timestamp')::timestamptz,
    (first->'next_cursor'->>'id')::uuid) as second from head;
grant select on page_snapshot to authenticated;
insert into public.booking(booking_id,owner_id,provider_id,property_id,service_type_id,
 requested_start_at,requested_end_at,created_at) values
 ('90000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','2031-10-22 02:00Z','2031-10-22 04:00Z','2031-10-22 02:00Z');
set local role authenticated;
do $$ declare snapshot record; result jsonb;
begin
  select * into snapshot from page_snapshot;
  result:=public.page_my_bookings(20,(snapshot.first->'next_cursor'->>'timestamp')::timestamptz,
    (snapshot.first->'next_cursor'->>'id')::uuid);
  assert result=snapshot.second;
  assert public.owner_dashboard_summary()->>'pending_count'='61';
  assert jsonb_array_length(public.page_my_bookings()->'items')=20;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
do $$ begin
  assert jsonb_array_length(public.page_my_bookings()->'items')=1;
  begin perform public.page_booking_messages('10000000-0000-4000-8000-000000000001');
    raise exception 'Outsider read messages'; exception when insufficient_privilege then null; end;
  begin perform public.page_booking_history('10000000-0000-4000-8000-000000000001');
    raise exception 'Outsider read history'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ begin
  assert jsonb_array_length(public.page_my_bookings(50)->'items')=50;
  assert jsonb_array_length(public.page_booking_messages('10000000-0000-4000-8000-000000000001')->'items')=20;
  begin perform public.owner_dashboard_summary(); raise exception 'Provider read Owner summary';
    exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  assert not has_function_privilege('anon','public.page_my_bookings(integer,timestamptz,uuid)','execute');
end $$;
rollback;
