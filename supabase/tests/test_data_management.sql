-- Only for disposable PostgreSQL. All fixtures roll back; no hosted calls.
begin;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','owner.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid'),
 ('22222222-2222-4222-8222-222222222222','provider.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid'),
 ('33333333-3333-4333-8333-333333333333','ordinary-account@example.invalid');
do $$ declare r text;
begin
  foreach r in array array['anon','authenticated'] loop
    assert not has_function_privilege(r,'public.seed_test_fixture(text,uuid,uuid,uuid,date)','EXECUTE');
    assert not has_function_privilege(r,'public.preview_test_fixture(text,uuid,uuid,uuid,date)','EXECUTE');
    assert not has_function_privilege(r,'public.inspect_test_run(text,uuid)','EXECUTE');
    assert not has_table_privilege(r,'public.test_data_run','SELECT');
    assert not has_table_privilege(r,'public.test_data_run','INSERT');
  end loop;
  assert not has_table_privilege('service_role','public.test_data_run','INSERT');
end $$;
set local role service_role;
do $$ begin
  assert public.get_app_environment()->>'environment'='unassigned';
  begin
    perform public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Unassigned environment seeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.app_deployment_environment set environment='production',project_ref='aaaaaaaaaaaaaaaaaaaa';
set local role service_role;
do $$ begin
  begin
    perform public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Production environment seeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.app_deployment_environment set environment='staging';
set local role service_role;
do $$ declare v jsonb;
begin
  begin
    perform public.preview_test_fixture('bbbbbbbbbbbbbbbbbbbb','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Mismatched project accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.preview_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Ordinary account adopted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.preview_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date-1);
    raise exception 'Past fixture accepted';
  exception when invalid_parameter_value then null; end;
  v:=public.preview_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
  assert v->>'already_seeded'='false';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.test_data_run)=0;
  assert (select count(*) from public.user_account)=0;
end $$;
-- Existing business data must not be silently relabelled as test data.
insert into public.user_account(user_id,email,role) values
 ('11111111-1111-4111-8111-111111111111','pre-existing@example.invalid','owner');
set local role service_role;
do $$ begin
  begin
    perform public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Existing business account adopted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
delete from public.user_account where user_id='11111111-1111-4111-8111-111111111111';
-- Force failure after run/account/profile/property inserts. PostgreSQL must
-- roll back the WHOLE fixture, not leave a half-created batch to clean up.
create function pg_temp.fail_fixture_booking() returns trigger language plpgsql as $$
begin raise exception 'Synthetic injected failure' using errcode='23514'; end;
$$;
create trigger fail_fixture_booking before insert on public.booking
  for each row execute function pg_temp.fail_fixture_booking();
set local role service_role;
do $$ begin
  begin
    perform public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
    raise exception 'Injected failure was not raised';
  exception when check_violation then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.test_data_run)=0;
  assert (select count(*) from public.user_account)=0;
  assert (select count(*) from public.property)=0;
  assert (select count(*) from public.provider_profile)=0;
  assert (select count(*) from public.provider_weekly_slot)=0;
end $$;
drop trigger fail_fixture_booking on public.booking;
set local role service_role;
do $$ declare v jsonb;
begin
  v:=public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
  assert v->>'created'='true';
  v:=public.inspect_test_run('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert v->'counts'->>'accounts'='2';
  assert v->'counts'->>'properties'='2';
  assert v->'counts'->>'weekly_slots'='7';
  assert v->'counts'->>'bookings'='1';
  assert v->'counts'->>'status_history'='1';
  assert v->'counts'->>'evidence'='0';
  assert v->>'mixed_account_bookings'='0';
  assert v->>'deletion_supported'='false';
  assert v->>'requires_manual_review'='true';
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.service_type)=5;
  assert (select current_status='Pending' and quoted_amount=80 and
    extract(hour from requested_start_at at time zone 'Asia/Kuala_Lumpur')=10
    from public.booking);
  assert (select count(*) from public.booking_evidence)=0;
end $$;
-- A retry must preserve manual activity, not reset statuses, slots or labels.
update public.booking set instructions='[TEST] Manually edited';
set local role service_role;
do $$ declare v jsonb;
begin
  v:=public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+7);
  assert v->>'already_seeded'='true';
  begin
    perform public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',current_date+8);
    raise exception 'Retry changed run parameters';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from public.booking)=1;
  assert (select instructions='[TEST] Manually edited' from public.booking);
  assert (select count(*) from public.provider_weekly_slot)=7;
end $$;
-- Later activity involving another account must be visible and flagged,
-- never treated as a safe cascade-delete set.
insert into public.user_account(user_id,email,role) values
 ('33333333-3333-4333-8333-333333333333','ordinary-account@example.invalid','owner');
insert into public.property(owner_id,unit_name,building_name,address) values
 ('33333333-3333-4333-8333-333333333333','Another unit','Other','Not part of run');
insert into public.booking(owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 select '33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222',
   property_id,(select service_type_id from public.service_type where name='Standard cleaning'),
   now()+interval '8 days',now()+interval '8 days 2 hours'
 from public.property where owner_id='33333333-3333-4333-8333-333333333333';
insert into public.booking_message(booking_id,sender_user_id,client_message_id,body)
 select booking_id,owner_id,gen_random_uuid(),'[TEST] Later message' from public.booking;
update public.test_data_run set review_after=now()-interval '1 minute';
set local role service_role;
do $$ declare v jsonb;
begin
  v:=public.inspect_test_run('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert v->'counts'->>'bookings'='2';
  assert v->'counts'->>'messages'='2';
  assert v->>'mixed_account_bookings'='1';
  assert v->>'review_due'='true';
  begin
    perform public.inspect_test_run('aaaaaaaaaaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    raise exception 'Unknown run inspected';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;
-- Inventory samples are bounded, but totals must include more than one page.
insert into public.booking(owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 select b.owner_id,b.provider_id,b.property_id,b.service_type_id,b.requested_start_at,b.requested_end_at
 from public.booking b cross join generate_series(1,25) where b.owner_id='11111111-1111-4111-8111-111111111111';
set local role service_role;
do $$ declare v jsonb;
begin
  v:=public.inspect_test_run('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert v->'counts'->>'bookings'='27';
  assert jsonb_array_length(v->'booking_id_sample')=20;
end $$;
reset role;
set local role authenticated;
do $$ begin
  begin
    perform public.inspect_test_run('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    raise exception 'App user inspected private admin inventory';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
