-- READ ONLY metadata verification, not a real JWT/Storage/Realtime test.
select n.nspname as schema,c.relname,c.relrowsecurity,pg_get_userbyid(c.relowner) as owner
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','app_private') and c.relkind in ('r','p')
order by n.nspname,c.relname;
select r.rolname as role,c.relname as table_name,
 has_table_privilege(r.oid,c.oid,'SELECT') as table_select,
 has_table_privilege(r.oid,c.oid,'INSERT') as table_insert,
 has_table_privilege(r.oid,c.oid,'UPDATE') as table_update,
 has_table_privilege(r.oid,c.oid,'DELETE') as table_delete,
 has_table_privilege(r.oid,c.oid,'TRUNCATE,REFERENCES,TRIGGER') as unexpected_special_privilege
from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join pg_roles r
where n.nspname='public' and c.relkind in ('r','p') and r.rolname in ('anon','authenticated','service_role')
order by r.rolname,c.relname;
-- Table-level false does not mean all column-level grants are false.
select grantee,table_name,column_name,privilege_type from information_schema.column_privileges
where table_schema='public' and grantee in ('anon','authenticated','service_role')
order by grantee,table_name,column_name,privilege_type;
select p.oid::regprocedure::text as function_signature,
 has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') as server_execute,
 p.prosecdef as security_definer,p.proconfig as fixed_settings
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','app_private') and p.proowner='postgres'::regrole
order by function_signature;
select schemaname,tablename,policyname,cmd,roles,qual,with_check from pg_policies
where schemaname in ('public','app_private') order by schemaname,tablename,policyname;
select schemaname,tablename from pg_publication_tables
where pubname='supabase_realtime' order by schemaname,tablename;
select public.get_app_environment() as environment_marker;
