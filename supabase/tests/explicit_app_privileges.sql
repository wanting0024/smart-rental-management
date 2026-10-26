-- Disposable local shim only. No hosted identity/isolation claim.
begin;

-- Check effective privileges, not merely grants visible in information_schema.
do $$
declare r record; actor text; permission text;
begin
  for r in select c.oid,c.relname,c.relrowsecurity from pg_class c
    join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p')
  loop
    assert r.relrowsecurity, 'Every application table requires RLS';
    foreach actor in array array['anon','authenticated','service_role'] loop
      foreach permission in array array['TRUNCATE','REFERENCES','TRIGGER'] loop
        assert not has_table_privilege(actor,r.oid,permission),
          format('Unexpected %s %s on %s',actor,permission,r.relname);
      end loop;
      if current_setting('server_version_num')::integer >= 170000 then
        assert not has_table_privilege(actor,r.oid,'MAINTAIN');
      end if;
    end loop;
    assert not has_any_column_privilege('anon',r.oid,'SELECT,INSERT,UPDATE,REFERENCES');
    assert not has_any_column_privilege('service_role',r.oid,'SELECT,INSERT,UPDATE,REFERENCES');
    assert not has_table_privilege('anon',r.oid,'DELETE');
    assert not has_table_privilege('service_role',r.oid,'DELETE');
  end loop;
  assert not has_table_privilege('authenticated','public.booking','INSERT,UPDATE,DELETE');
  assert has_column_privilege('authenticated','public.booking','instructions','UPDATE');
  assert not has_column_privilege('authenticated','public.booking','current_status','UPDATE');
  assert not has_column_privilege('authenticated','public.booking','quoted_amount','UPDATE');
  assert not has_column_privilege('authenticated','public.user_account','role','UPDATE');
  assert not has_column_privilege('authenticated','public.user_account','created_at','INSERT,UPDATE');
  assert not has_column_privilege('authenticated','public.provider_profile','approval_status','INSERT,UPDATE');
  assert not has_column_privilege('authenticated','public.provider_profile','rating_average','INSERT,UPDATE');
  assert has_column_privilege('authenticated','public.provider_profile','hourly_rate','UPDATE');
  foreach actor in array array['anon','authenticated','service_role'] loop
    assert not has_schema_privilege(actor,'public','CREATE');
    assert not has_schema_privilege(actor,'app_private','USAGE');
  end loop;
  for r in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proowner='postgres'::regrole
  loop
    assert has_function_privilege('anon',r.oid,'EXECUTE') = (r.proname='get_app_environment'),
      format('Unexpected anon function access: %s',r.proname);
    if r.proname like 'guard_%' or r.proname like 'lock_%' or
       r.proname in ('pack_cursor_page','require_test_environment','can_upload_evidence_object',
       'record_initial_booking_status','check_confirmed_after_availability_change','validate_provider_weekly_slot') then
      assert not has_function_privilege('authenticated',r.oid,'EXECUTE');
      assert not has_function_privilege('service_role',r.oid,'EXECUTE');
    end if;
    if r.proname in ('claim_evidence_validation','finish_evidence_validation','fail_evidence_validation',
      'list_evidence_cleanup_batch','claim_evidence_cleanup_batch','finish_evidence_cleanup_batch',
      'preview_test_fixture','seed_test_fixture','inspect_test_run') then
      assert has_function_privilege('service_role',r.oid,'EXECUTE');
      assert not has_function_privilege('authenticated',r.oid,'EXECUTE');
    end if;
  end loop;
end $$;

-- Future objects must not regain broad grants, including PUBLIC EXECUTE.
create table public._acl_future_probe(id integer);
create sequence public._acl_future_sequence;
create function public._acl_future_function() returns integer language sql as 'select 1';
do $$ declare actor text;
begin
  foreach actor in array array['anon','authenticated','service_role'] loop
    assert not has_table_privilege(actor,'public._acl_future_probe','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER');
    assert not has_sequence_privilege(actor,'public._acl_future_sequence','SELECT,UPDATE,USAGE');
    assert not has_function_privilege(actor,'public._acl_future_function()','EXECUTE');
  end loop;
end $$;

-- Real SQL permission attempts as anon (no service_role/postgres bypass).
set local role anon;
do $$ begin
  assert public.get_app_environment()->>'environment'='unassigned';
  begin perform 1 from public.booking; raise exception 'anon read succeeded';
  exception when insufficient_privilege then null; end;
  begin truncate public.booking cascade; raise exception 'anon TRUNCATE succeeded';
  exception when insufficient_privilege then null; end;
  begin perform public.list_approved_provider_directory(); raise exception 'anon RPC succeeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000001','owner@acl.invalid'),
 ('00000000-0000-4000-8000-000000000002','provider@acl.invalid'),
 ('00000000-0000-4000-8000-000000000003','other@acl.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"email":"owner@acl.invalid"}',true);
insert into public.user_account(user_id,email,role,contact_number)
 values(auth.uid(),'owner@acl.invalid','owner','synthetic contact');
update public.user_account set contact_number='changed synthetic contact' where user_id=auth.uid();
do $$ begin
  begin update public.user_account set role='provider'; raise exception 'Role escalation succeeded';
  exception when insufficient_privilege then null; end;
  begin update public.user_account set created_at=now(); raise exception 'Audit timestamp spoof succeeded';
  exception when insufficient_privilege then null; end;
  begin insert into public.user_account(user_id,email,role)
    values('00000000-0000-4000-8000-000000000003','owner@acl.invalid','owner');
    raise exception 'Other identity registration succeeded';
  exception when insufficient_privilege then null; end;
end $$;
insert into public.property(owner_id,unit_name,building_name,address,bedrooms,size_sqft)
 values(auth.uid(),'ACL unit','Synthetic building','Synthetic address',2,800);
select set_config('test.acl_property',(select property_id::text from public.property),true);
update public.property set bedrooms=3 where owner_id=auth.uid();

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"email":"provider@acl.invalid"}',true);
insert into public.user_account(user_id,email,role) values(auth.uid(),'provider@acl.invalid','provider');
insert into public.provider_profile(provider_id,bio,service_area,service_origin_address,hourly_rate,daily_rate)
 values(auth.uid(),'Synthetic bio','Synthetic area','PRIVATE ORIGIN',40,280);
update public.provider_profile set bio='Edited bio' where provider_id=auth.uid();
do $$ begin
  begin update public.provider_profile set approval_status='approved'; raise exception 'Self approval succeeded';
  exception when insufficient_privilege then null; end;
  begin insert into public.provider_capability values(auth.uid(),(select service_type_id from public.service_type limit 1));
    raise exception 'Direct capabilities write succeeded';
  exception when insufficient_privilege then null; end;
  assert (select count(*) from public.property)=0, 'Provider read an unrelated raw property';
end $$;
select set_config('test.acl_service',(select service_type_id::text from public.service_type order by name limit 1),true);
select public.replace_provider_capabilities(array[current_setting('test.acl_service')::uuid]);
insert into public.provider_weekly_slot(provider_id,weekday,start_time,end_time)
 values(auth.uid(),extract(isodow from date '2036-06-09')::integer,'08:00','18:00');
do $$ begin
  begin insert into public.provider_weekly_slot(provider_id,weekday,start_time,end_time)
    values(auth.uid(),extract(isodow from date '2036-06-09')::integer,'19:00','19:10');
    raise exception 'Ten minute availability succeeded';
  exception when check_violation then null; end;
  begin insert into public.provider_weekly_slot(provider_id,weekday,start_time,end_time)
    values(auth.uid(),extract(isodow from date '2036-06-09')::integer,'09:00','12:00');
    raise exception 'Overlapping availability succeeded';
  exception when check_violation then null; end;
end $$;
insert into public.provider_unavailable_date(provider_id,unavailable_on) values(auth.uid(),'2036-06-10');
delete from public.provider_unavailable_date where unavailable_on='2036-06-10';
reset role;
-- Trusted approval fixture, not an App operation.
update public.provider_profile set approval_status='approved'
 where provider_id='00000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ declare result jsonb; retry jsonb; found_count integer;
begin
  assert (select count(*) from public.provider_profile)=0, 'Owner read private provider profile';
  assert (select count(*) from public.provider_weekly_slot)=0, 'Owner read private provider schedule';
  assert (select count(*) from public.provider_capability)=0, 'Owner read private capabilities';
  select count(*) into found_count from public.find_eligible_providers(current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 10:00+08','2036-06-09 12:00+08');
  assert found_count=1, 'Privacy or grants broke eligible-provider search';
  assert not exists(select 1 from public.list_approved_provider_directory() d
    where to_jsonb(d) ? 'service_origin_address'), 'Directory exposed private origin';
  result:=public.create_pending_booking(gen_random_uuid(),
    '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 10:00+08','2036-06-09 12:00+08',1,'hourly','test');
  assert result->>'reason'='price_changed', 'Server accepted a tampered displayed price';
  result:=public.create_pending_booking(gen_random_uuid(),
    '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 07:00+08','2036-06-09 09:00+08',80,'hourly','test');
  assert result->>'reason'='rental_window', 'Server accepted an out-of-window interval';
  result:=public.create_pending_booking('00000000-0000-4000-8000-000000000010',
    '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 10:00+08','2036-06-09 12:00+08',80,'hourly','test');
  assert result->>'created'='true' and (result->>'quoted_amount')::numeric=80;
  perform set_config('test.acl_booking',result->>'booking_id',true);
  retry:=public.create_pending_booking('00000000-0000-4000-8000-000000000010',
    '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 10:00+08','2036-06-09 12:00+08',80,'hourly','test');
  assert retry->>'booking_id'=result->>'booking_id' and retry->>'reused'='true';
  begin
    perform public.create_pending_booking('00000000-0000-4000-8000-000000000010',
      '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
      current_setting('test.acl_service')::uuid,'2036-06-09 10:00+08','2036-06-09 12:00+08',80,'hourly','changed content');
    raise exception 'Retry token accepted changed content';
  exception when check_violation then null; end;
  retry:=public.create_pending_booking(gen_random_uuid(),
    '00000000-0000-4000-8000-000000000002',current_setting('test.acl_property')::uuid,
    current_setting('test.acl_service')::uuid,'2036-06-09 08:00+08','2036-06-09 16:00+08',280,'daily','daily test');
  assert retry->>'created'='true' and (retry->>'quoted_amount')::numeric=280,
    'Daily price or nonblocking Pending rule changed';
  begin update public.booking set quoted_amount=1; raise exception 'Quote spoof succeeded';
  exception when insufficient_privilege then null; end;
  begin update public.booking set current_status='Accepted'; raise exception 'Direct transition succeeded';
  exception when insufficient_privilege then null; end;
  begin insert into public.booking(owner_id) values(auth.uid()); raise exception 'Direct booking INSERT succeeded';
  exception when insufficient_privilege then null; end;
  begin truncate public.booking cascade; raise exception 'Authenticated TRUNCATE succeeded';
  exception when insufficient_privilege then null; end;
  begin perform public.claim_evidence_validation(gen_random_uuid(),gen_random_uuid(),auth.uid());
    raise exception 'Client called worker endpoint';
  exception when insufficient_privilege then null; end;
end $$;
update public.booking set instructions='Edited pending note' where booking_id=current_setting('test.acl_booking')::uuid;

-- Unrelated account has no booking rows or participant RPC access.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
do $$ begin
  assert (select count(*) from public.booking)=0;
  assert (select count(*) from public.booking_status_history)=0;
  begin perform public.page_booking_messages(current_setting('test.acl_booking')::uuid);
    raise exception 'Unrelated account read messages';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ declare result jsonb;
begin
  result:=public.accept_pending_booking(current_setting('test.acl_booking')::uuid);
  assert result->>'accepted'='true', 'Allowed acceptance failed after ACL closure';
  begin delete from public.provider_weekly_slot; raise exception 'Confirmed schedule invalidated';
  exception when check_violation then null; end;
  begin perform public.replace_provider_capabilities(array[]::uuid[]); raise exception 'Required capability removed';
  exception when check_violation then null; end;
  begin update public.booking set instructions='Provider forged Owner note';
    -- RLS silently filters unauthorized UPDATE; zero affected rows is correct.
    assert not found;
  end;
end $$;
reset role;
do $$ begin
  assert (select instructions from public.booking where booking_id=current_setting('test.acl_booking')::uuid)
    is not distinct from 'Edited pending note';
end $$;
rollback;
