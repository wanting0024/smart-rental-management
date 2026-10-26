-- READ ONLY. Check the Dashboard URL separately: gqtetdavmrautoojaqrk.
-- An SQL connection cannot independently prove the Supabase project reference.
select current_user as migration_role, current_setting('server_version') as postgres_version;
select n.nspname,c.relname,c.relkind,pg_get_userbyid(c.relowner) as owner,c.relrowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','app_private') and c.relkind in ('r','p','v','m','S','f')
order by n.nspname,c.relname;
-- Fresh-Staging bundle requires zero non-extension public business relations
-- and no app_private schema. An existing original schema must NOT use it.
select evtname,evtenabled from pg_event_trigger where evtname='app_enable_public_table_rls';
select pg_get_userbyid(d.defaclrole) as creator,coalesce(n.nspname,'GLOBAL') as scope,
       d.defaclobjtype,d.defaclacl::text
from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace
where d.defaclrole in ('postgres'::regrole,'supabase_admin'::regrole)
order by creator,scope,d.defaclobjtype;
