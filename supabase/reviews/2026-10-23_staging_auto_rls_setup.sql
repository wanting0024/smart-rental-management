-- One-time bootstrap, NOT a numbered business migration.
-- Dashboard target MUST be smart-rental-staging / gqtetdavmrautoojaqrk.
-- SQL cannot verify the Dashboard project reference; confirm it in the URL.
-- This intentionally fails rather than overwriting an existing helper/trigger.
BEGIN;

DO $guard$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Run as the Staging Dashboard postgres administrator';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
  ) THEN
    RAISE EXCEPTION 'Expected a fresh Staging project with no public tables';
  END IF;
END;
$guard$;

CREATE SCHEMA app_security_bootstrap AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA app_security_bootstrap FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION app_security_bootstrap.enable_public_table_rls()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT * FROM pg_catalog.pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table', 'partitioned table')
      AND schema_name = 'public'
  LOOP
    EXECUTE pg_catalog.format(
      'ALTER TABLE %s ENABLE ROW LEVEL SECURITY', cmd.object_identity
    );
  END LOOP;
END;
$function$;

-- Revoke PUBLIC's implicit EXECUTE in the same transaction as creation.
-- App roles cannot invoke this SECURITY DEFINER helper.
REVOKE ALL ON FUNCTION app_security_bootstrap.enable_public_table_rls()
FROM PUBLIC, anon, authenticated, service_role;

CREATE EVENT TRIGGER app_enable_public_table_rls
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
EXECUTE FUNCTION app_security_bootstrap.enable_public_table_rls();

COMMENT ON EVENT TRIGGER app_enable_public_table_rls IS
'Enable RLS on future public tables. Does not grant API access or create policies.';

COMMIT;

SELECT e.evtname, e.evtenabled, n.nspname AS helper_schema,
       p.prosecdef AS security_definer, p.proconfig AS fixed_settings,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_catalog.pg_event_trigger e
JOIN pg_catalog.pg_proc p ON p.oid = e.evtfoid
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE e.evtname = 'app_enable_public_table_rls';
