-- Disposable PostgreSQL integration check for the authoritative lifecycle.
-- This uses a minimal Supabase shim, not hosted Auth/Storage services.
begin;

insert into auth.users(id) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.user_account(user_id, email, role) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner@test.invalid', 'owner'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'provider@test.invalid', 'provider'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'other@test.invalid', 'owner');
insert into public.property
  (property_id, owner_id, unit_name, building_name, address)
values
  ('ffffffff-ffff-4fff-8fff-ffffffffffff',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'A-1', 'Test Building', 'Test Address');
insert into public.provider_profile
  (provider_id, service_area, service_origin_address, hourly_rate,
   daily_rate, approval_status)
values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'Test Area', 'Private Test Address', 50, 320, 'approved');
insert into public.service_type(service_type_id, name)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'Test cleaning');
insert into public.provider_capability(provider_id, service_type_id)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
insert into public.provider_weekly_slot
  (provider_id, weekday, start_time, end_time)
values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   extract(isodow from timestamp '2030-10-22 10:00')::integer,
   '08:00', '18:00');
insert into public.booking
  (booking_id, owner_id, provider_id, property_id, service_type_id,
   requested_start_at, requested_end_at, current_status, quote_currency,
   quote_basis, quoted_rate, quoted_duration_minutes, quoted_amount)
values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'ffffffff-ffff-4fff-8fff-ffffffffffff',
   'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   '2030-10-22 02:00+00', '2030-10-22 04:00+00', 'Pending', 'MYR',
   'hourly', 50, 120, 100);

-- Pending is not slot-blocking. Another overlapping request may exist.
insert into public.booking
  (booking_id, owner_id, provider_id, property_id, service_type_id,
   requested_start_at, requested_end_at, current_status, quote_currency,
   quote_basis, quoted_rate, quoted_duration_minutes, quoted_amount)
values
  ('99999999-9999-4999-8999-999999999999',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'ffffffff-ffff-4fff-8fff-ffffffffffff',
   'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   '2030-10-22 03:00+00', '2030-10-22 05:00+00', 'Pending', 'MYR',
   'hourly', 50, 120, 100);

set role authenticated;
select set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
do $$
declare v_result jsonb;
begin
  v_result := public.accept_pending_booking(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd');
  if v_result ->> 'accepted' <> 'true' then
    raise exception 'First eligible Pending request was not accepted: %',
      v_result;
  end if;
  v_result := public.accept_pending_booking(
    '99999999-9999-4999-8999-999999999999');
  if v_result ->> 'accepted' <> 'false' then
    raise exception 'Overlapping Pending request was incorrectly accepted';
  end if;
  perform public.transition_booking(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'In Progress', null);
  begin
    perform public.transition_booking(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Completed', null);
    raise exception 'Completion succeeded without evidence';
  exception when check_violation then
    null;
  end;
end;
$$;

-- Simulate Storage's metadata writes, not real uploaded bytes. Register each
-- immutable upload first, attach through the RPC, then save locked remarks.
do $$ declare v_kind text; v_id uuid; v_ticket jsonb; v_attached jsonb;
begin
  foreach v_kind in array array['before','after'] loop
    v_id := gen_random_uuid();
    v_ticket := public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      v_id,v_kind,'png',128,repeat('a',64));
    perform local_test.fixture_verify_photo(v_id);
    v_attached := public.attach_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',v_id);
    assert v_attached->>'attached' = 'true';
  end loop;
  perform public.save_evidence_remarks('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'Kitchen and bathrooms cleaned.');
end $$;
select public.transition_booking(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Completed', null);

do $$ declare v_result jsonb; v_deleted integer;
begin
  v_result := public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    gen_random_uuid(),'before','png',128,repeat('a',64));
  assert v_result->>'state' = 'closed';
  begin
    perform public.save_evidence_remarks('dddddddd-dddd-4ddd-8ddd-dddddddddddd','Changed after completion');
    raise exception 'Completed evidence was modified';
  exception when check_violation then null; end;
  delete from storage.objects where bucket_id='cleaning-evidence';
  get diagnostics v_deleted = row_count; assert v_deleted=0;
end $$;

do $$
begin
  if (select current_status from public.booking
      where booking_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd')
      <> 'Completed' then
    raise exception 'Completed status was not stored';
  end if;
  if (select count(*) from public.booking_status_history
      where booking_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 4 then
    raise exception 'Booking status history is incomplete';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
do $$
begin
  if (select count(*) from public.booking_evidence) <> 1 or
     (select count(*) from storage.objects) <> 2 then
    raise exception 'Owner cannot read completed evidence';
  end if;
end;
$$;

-- Only the Owner may review a Completed booking. A correction updates the
-- same row and refreshes the Provider aggregate, not a second rating.
do $$
declare v_result jsonb;
begin
  if (select count(*) from public.list_booking_contexts()) <> 2 or
     (select count(*) from public.list_booking_contexts()
      where unit_name = 'A-1' and
            property_address = 'Test Address' and
            service_name = 'Test cleaning') <> 2 then
    raise exception 'Owner booking context is missing';
  end if;
  v_result := public.save_booking_review(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 4, 'Good work');
  if v_result ->> 'rating_average' <> '4.00' then
    raise exception 'Provider average was not saved: %', v_result;
  end if;
  v_result := public.save_booking_review(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 5, 'Excellent work');
  if (select count(*) from public.booking_review) <> 1 or
     (v_result ->> 'rating_average')::numeric is distinct from 5 then
    raise exception 'Review update did not refresh the aggregate';
  end if;
  -- Owner must use the whitelisted directory, never private raw profile rows.
  assert (select count(*) from public.provider_profile)=0;
  assert (select rating_average from public.list_approved_provider_directory()
    where provider_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') is not distinct from 5;
  begin
    insert into public.booking_review
      (booking_id, owner_id, provider_id, rating)
    values ('99999999-9999-4999-8999-999999999999',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1);
    raise exception 'Direct review INSERT was incorrectly permitted';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.save_booking_review(
      '99999999-9999-4999-8999-999999999999', 1, null);
    raise exception 'Pending booking was incorrectly reviewed';
  exception when check_violation then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
do $$
begin
  if (select count(*) from public.list_booking_contexts()) <> 2 then
    raise exception 'Assigned Provider cannot see booking context';
  end if;
  if (select count(*) from public.booking_review) <> 1 then
    raise exception 'Assigned Provider cannot read the review';
  end if;
  begin
    perform public.save_booking_review(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, null);
    raise exception 'Provider incorrectly reviewed own work';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc', true);
do $$
begin
  if (select count(*) from public.list_booking_contexts()) <> 0 then
    raise exception 'Outsider can see booking context';
  end if;
  if (select count(*) from public.booking_evidence) <> 0 or
     (select count(*) from storage.objects) <> 0 or
     (select count(*) from public.booking_review) <> 0 then
    raise exception 'Unrelated account can read private evidence';
  end if;
  begin
    perform public.save_booking_review(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, null);
    raise exception 'Unrelated account incorrectly reviewed a booking';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
rollback;
