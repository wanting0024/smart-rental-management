-- Staging only. Creates empty test objects inside a transaction and rolls back.
-- Do not run only a selected CREATE statement; run the entire script.
BEGIN;
CREATE TABLE public._security_probe_plain_20261023 (id integer);
CREATE TABLE public._security_probe_ctas_20261023 AS SELECT 1 AS id WITH NO DATA;
SELECT 1 AS id INTO public._security_probe_selectinto_20261023 WHERE false;

SELECT c.relname AS test_table, c.relrowsecurity AS rls_enabled,
       has_table_privilege('anon', c.oid, 'SELECT') AS anon_select,
       has_table_privilege('anon', c.oid, 'INSERT') AS anon_insert,
       has_table_privilege('anon', c.oid, 'UPDATE') AS anon_update,
       has_table_privilege('anon', c.oid, 'DELETE') AS anon_delete,
       has_table_privilege('authenticated', c.oid, 'SELECT') AS authenticated_select,
       has_table_privilege('authenticated', c.oid, 'INSERT') AS authenticated_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') AS authenticated_update,
       has_table_privilege('authenticated', c.oid, 'DELETE') AS authenticated_delete,
       has_table_privilege('anon', c.oid, 'TRUNCATE') AS residual_anon_truncate
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('_security_probe_plain_20261023', '_security_probe_ctas_20261023',
                    '_security_probe_selectinto_20261023')
ORDER BY c.relname;

ROLLBACK;
