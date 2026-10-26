-- READ ONLY metadata. No fixture writes, user records, tokens or secrets.
with relations as (
 select c.oid,n.nspname,c.relname,c.relrowsecurity,c.relowner from pg_catalog.pg_class c
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','app_private') and c.relkind in ('r','p')
), routines as (
 select p.oid,p.proname,p.prosecdef,p.proconfig,p.proowner,n.nspname from pg_catalog.pg_proc p
 join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','app_private') and p.prokind='f'
 and not exists(select 1 from pg_catalog.pg_depend d where d.classid='pg_catalog.pg_proc'::regclass
   and d.objid=p.oid and d.deptype='e')
)
select 'relations' as category,coalesce(jsonb_agg(jsonb_build_object(
 'schema',nspname,'table',relname,'owner',pg_catalog.pg_get_userbyid(relowner),'rls',relrowsecurity)
 order by nspname,relname),'[]'::jsonb) as result from relations
union all select 'table_privileges',coalesce(jsonb_agg(jsonb_build_object(
 'role',r.rolname,'schema',c.nspname,'table',c.relname,
 'select',has_table_privilege(r.oid,c.oid,'SELECT'),
 'insert',has_table_privilege(r.oid,c.oid,'INSERT'),
 'update',has_table_privilege(r.oid,c.oid,'UPDATE'),
 'delete',has_table_privilege(r.oid,c.oid,'DELETE'),
 'any_insert_column',has_any_column_privilege(r.oid,c.oid,'INSERT'),
 'any_update_column',has_any_column_privilege(r.oid,c.oid,'UPDATE'),
 'truncate',has_table_privilege(r.oid,c.oid,'TRUNCATE'),
 'special_privileges',has_table_privilege(r.oid,c.oid,'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN'))
 order by r.rolname,c.nspname,c.relname),'[]'::jsonb)
from relations c cross join pg_catalog.pg_roles r where r.rolname in ('anon','authenticated','service_role')
union all select 'column_grants',coalesce(jsonb_agg(jsonb_build_object(
 'role',grantee,'table',table_name,'column',column_name,'privilege',privilege_type)
 order by grantee,table_name,column_name,privilege_type),'[]'::jsonb)
from information_schema.column_privileges where table_schema='public'
 and grantee in ('anon','authenticated','service_role') and privilege_type<>'SELECT'
union all select 'functions',coalesce(jsonb_agg(jsonb_build_object(
 'signature',p.oid::regprocedure::text,'name',p.proname,'schema',p.nspname,
 'owner',pg_catalog.pg_get_userbyid(p.proowner),'definer',p.prosecdef,'settings',p.proconfig,
 'anon',has_function_privilege('anon',p.oid,'EXECUTE'),
 'authenticated',has_function_privilege('authenticated',p.oid,'EXECUTE'),
 'service_role',has_function_privilege('service_role',p.oid,'EXECUTE'))
 order by p.nspname,p.proname,p.oid),'[]'::jsonb) from routines p
union all select 'policies',coalesce(jsonb_agg(jsonb_build_object(
 'schema',schemaname,'table',tablename,'policy',policyname,'command',cmd,'roles',roles,
 'using',qual,'check',with_check) order by schemaname,tablename,policyname),'[]'::jsonb)
from pg_catalog.pg_policies where schemaname in ('public','app_private','storage')
union all select 'postgres_default_acls',coalesce(jsonb_agg(jsonb_build_object(
 'schema',coalesce(n.nspname,'GLOBAL'),'object_type',d.defaclobjtype,'acl',d.defaclacl::text)
 order by n.nspname,d.defaclobjtype),'[]'::jsonb)
from pg_catalog.pg_default_acl d left join pg_catalog.pg_namespace n on n.oid=d.defaclnamespace
where d.defaclrole='postgres'::regrole and (d.defaclnamespace=0 or n.nspname in ('public','app_private'))
union all select 'schema_roles',coalesce(jsonb_agg(jsonb_build_object('role',rolname,
 'superuser',rolsuper,'bypassrls',rolbypassrls,'create_public',has_schema_privilege(oid,'public','CREATE'),
 'private_usage',has_schema_privilege(oid,'app_private','USAGE')) order by rolname),'[]'::jsonb)
from pg_catalog.pg_roles where rolname in ('anon','authenticated','service_role')
union all select 'realtime',coalesce(jsonb_agg(jsonb_build_object('schema',schemaname,'table',tablename)
 order by schemaname,tablename),'[]'::jsonb) from pg_catalog.pg_publication_tables where pubname='supabase_realtime'
union all select 'evidence_bucket',coalesce(jsonb_agg(jsonb_build_object('id',id,'public',public,
 'size_limit',file_size_limit,'mime_types',allowed_mime_types)),'[]'::jsonb)
from storage.buckets where id='cleaning-evidence'
union all select 'environment_marker',public.get_app_environment()
union all select 'history',jsonb_agg(jsonb_build_object('version',version,'name',name) order by version)
from supabase_migrations.schema_migrations;
