-- Disposable local PostgreSQL only; never run fixtures against a live project.
begin;
do $$ begin
  assert public.get_app_environment() =
    '{"environment":"unassigned","project_ref":null}'::jsonb;
  assert not has_table_privilege('anon', 'public.app_deployment_environment', 'SELECT');
  assert not has_table_privilege('authenticated', 'public.app_deployment_environment', 'UPDATE');
end $$;
set local role anon;
do $$ begin
  assert public.get_app_environment()->>'environment' = 'unassigned';
  begin
    update public.app_deployment_environment set environment = 'staging';
    raise exception 'Anonymous caller changed deployment identity';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
update public.app_deployment_environment set environment = 'production',
  project_ref = 'aaaaaaaaaaaaaaaaaaaa', configured_at = now() where singleton;
set local role authenticated;
do $$ begin
  assert public.get_app_environment() =
    '{"environment":"production","project_ref":"aaaaaaaaaaaaaaaaaaaa"}'::jsonb;
  begin
    update public.app_deployment_environment set environment = 'staging';
    raise exception 'App user changed deployment identity';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  begin
    update public.app_deployment_environment set project_ref = null;
    raise exception 'Assigned environment accepted a missing Project ID';
  exception when check_violation then null;
  end;
end $$;
rollback;
