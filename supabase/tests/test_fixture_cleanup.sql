-- Local synthetic cleanup safety. This never deletes hosted test/user data.
begin;
update public.app_deployment_environment set environment='staging',project_ref='aaaaaaaaaaaaaaaaaaaa';
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','owner.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid'),
 ('22222222-2222-4222-8222-222222222222','provider.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid'),
 ('33333333-3333-4333-8333-333333333333','unrelated@example.invalid');
select public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 (now() at time zone 'Asia/Kuala_Lumpur')::date+7);
do $$ declare p jsonb;r text;begin
 p:=public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
 assert (p->>'eligible')::boolean and length(p->>'fingerprint')=32;
 assert p->'counts'->>'accounts'='2' and p->'counts'->>'properties'='2';
 foreach r in array array['anon','authenticated'] loop
  assert not has_function_privilege(r,'public.preview_test_fixture_cleanup(text,uuid)','EXECUTE');
  assert not has_function_privilege(r,'public.cleanup_test_fixture(text,uuid,text)','EXECUTE');
 end loop;
 begin perform public.cleanup_test_fixture('bbbbbbbbbbbbbbbbbbbb','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',p->>'fingerprint');
  raise exception 'Wrong project cleanup allowed';exception when insufficient_privilege then null;end;
 begin perform public.cleanup_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null);
  raise exception 'Missing confirmation allowed';exception when serialization_failure then null;end;
 update public.booking set instructions='[TEST] Changed since preview';
 begin perform public.cleanup_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',p->>'fingerprint');
  raise exception 'Stale preview deleted data';exception when serialization_failure then null;end;
 assert (select count(*) from public.booking)=1;
end $$;
-- Accepted, even subsequently cancelled, cannot be automatically erased.
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status)
 select booking_id,provider_id,'Pending','Accepted' from public.booking;
do $$ declare p jsonb;begin
 p:=public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
 assert not (p->>'eligible')::boolean and p->>'fingerprint' is null;
 begin perform public.cleanup_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',repeat('a',32));
  raise exception 'Worked-on history erased';exception when insufficient_privilege then null;end;
end $$;
delete from public.booking_status_history where new_status='Accepted';
insert into public.booking_message(booking_id,sender_user_id,client_message_id,body)
 select booking_id,owner_id,gen_random_uuid(),'[TEST] A message requiring review' from public.booking;
do $$ begin assert not (public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'eligible')::boolean;end $$;
delete from public.booking_message;
-- Files are NEVER deleted by this tool, even if otherwise empty/pending.
insert into storage.objects(bucket_id,name) select 'cleaning-evidence',booking_id::text||'/untracked.jpg' from public.booking;
do $$ begin assert not (public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'eligible')::boolean;end $$;
delete from storage.objects;
-- Cross-account dependencies are blockers, not a cascade-delete plan.
insert into public.user_account(user_id,email,role) values('33333333-3333-4333-8333-333333333333','unrelated@example.invalid','owner');
insert into public.property(owner_id,unit_name,building_name,address) values('33333333-3333-4333-8333-333333333333','Other','Other','Other');
insert into public.booking(owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at)
 select '33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222',property_id,
  (select service_type_id from public.service_type where name='Standard cleaning'),now()+interval '10 days',now()+interval '10 days 2 hours'
 from public.property where owner_id='33333333-3333-4333-8333-333333333333';
do $$ begin assert not (public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'eligible')::boolean;end $$;
delete from public.booking where owner_id='33333333-3333-4333-8333-333333333333';
-- Now the same exact eligible run can be removed and reseeded, retaining Auth.
set local role service_role;
do $$ declare p jsonb;r jsonb;begin
 p:=public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
 r:=public.cleanup_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',p->>'fingerprint');
 assert (r->>'cleaned')::boolean and (r->>'auth_users_retained')::int=2;
end $$;
reset role;
do $$ begin
 assert (select count(*) from auth.users)=3;
 assert (select count(*) from public.user_account)=1;
 assert (select count(*) from public.property)=1;
 assert (select count(*) from public.test_data_run)=0;
 assert (select count(*) from public.provider_profile)=0;
 assert (select count(*) from public.service_type)=5;
end $$;
set local role service_role;
select public.seed_test_fixture('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 (now() at time zone 'Asia/Kuala_Lumpur')::date+7);
reset role;
do $$ begin
 assert (select count(*) from public.test_data_run)=1;
 assert (select count(*) from public.booking)=1;
 assert (select count(*) from public.provider_weekly_slot)=7;
end $$;
update public.app_deployment_environment set environment='production';
set local role service_role;
do $$ begin
 begin perform public.preview_test_fixture_cleanup('aaaaaaaaaaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  raise exception 'Production cleanup allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
