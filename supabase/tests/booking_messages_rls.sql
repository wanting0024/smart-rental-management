-- Run only after all migrations in a disposable local PostgreSQL database.
-- A rollback keeps fixtures and messages out of the database.
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
   '2030-10-22 02:00+00', '2030-10-22 04:00+00', 'Accepted', 'MYR',
   'hourly', 50, 120, 100);

set role authenticated;
select set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
select public.send_booking_message(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111', 'Please use the side gate.');

do $$
begin
  if (select count(*) from public.booking_message) <> 1 then
    raise exception 'Owner should read their own booking message';
  end if;
  begin
    insert into public.booking_message
      (booking_id, sender_user_id, client_message_id, body)
    values
      ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
       '33333333-3333-4333-8333-333333333333', 'Direct write');
    raise exception 'Direct client INSERT unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
select public.send_booking_message(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '22222222-2222-4222-8222-222222222222', 'I will be there at 10.');
do $$
begin
  if (select count(*) from public.booking_message) <> 2 then
    raise exception 'Assigned Provider should read both booking messages';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc', true);
do $$
begin
  if (select count(*) from public.booking_message) <> 0 then
    raise exception 'Unrelated account can read private messages';
  end if;
  begin
    perform public.send_booking_message(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '44444444-4444-4444-8444-444444444444', 'Unrelated sender');
    raise exception 'Unrelated account sent a message';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;
-- Establish genuine SQL-side completion prerequisites through the trusted
-- worker fixture before testing read-only chat on a completed booking.
update public.booking set current_status='In Progress'
where booking_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
do $$ declare kind text; id uuid;
begin
  foreach kind in array array['before','after'] loop
    id := gen_random_uuid();
    perform public.begin_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',id,kind,'png',128,repeat('a',64));
    perform local_test.fixture_verify_photo(id);
    assert (public.attach_evidence_upload('dddddddd-dddd-4ddd-8ddd-dddddddddddd',id)->>'attached')::boolean;
  end loop;
end $$;
update public.booking set current_status = 'Completed'
where booking_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

set role authenticated;
select set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
do $$
begin
  if (select count(*) from public.booking_message) <> 2 then
    raise exception 'Completed booking messages should remain readable';
  end if;
  begin
    perform public.send_booking_message(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '55555555-5555-4555-8555-555555555555', 'Too late');
    raise exception 'New message sent after completion';
  exception when check_violation then
    null;
  end;
  -- A response-lost retry of a committed message returns the old ID.
  perform public.send_booking_message(
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '11111111-1111-4111-8111-111111111111', 'Please use the side gate.');
  if (select count(*) from public.booking_message) <> 2 then
    raise exception 'Retry created a duplicate message';
  end if;
  begin
    perform public.send_booking_message(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '11111111-1111-4111-8111-111111111111', 'Changed retry text');
    raise exception 'Changed-content retry was accepted';
  exception when unique_violation then
    null;
  end;
end;
$$;

reset role;
rollback;
