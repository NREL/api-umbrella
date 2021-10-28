CREATE FUNCTION pg_temp.ensure_schema_owner(schema_name TEXT, role_name TEXT) RETURNS void AS $$
  DECLARE
    r record;
  BEGIN
    FOR r IN EXECUTE format('SELECT n.nspname, c.relname FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON c.relnamespace = n.oid WHERE c.relkind = ''r'' AND n.nspname = %L AND pg_get_userbyid(c.relowner) != %L', schema_name, role_name) LOOP
      EXECUTE format('ALTER TABLE %I.%I OWNER TO %I', r.nspname, r.relname, role_name);
    END LOOP;
    FOR r IN EXECUTE format('SELECT n.nspname, c.relname FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON c.relnamespace = n.oid WHERE c.relkind = ''v'' AND n.nspname = %L AND pg_get_userbyid(c.relowner) != %L', schema_name, role_name) LOOP
      EXECUTE format('ALTER VIEW %I.%I OWNER TO %I', r.nspname, r.relname, role_name);
    END LOOP;
    FOR r IN EXECUTE format('SELECT n.nspname, c.relname FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON c.relnamespace = n.oid WHERE c.relkind = ''m'' AND n.nspname = %L AND pg_get_userbyid(c.relowner) != %L', schema_name, role_name) LOOP
      EXECUTE format('ALTER MATERIALIZED VIEW %I.%I OWNER TO %I', r.nspname, r.relname, role_name);
    END LOOP;
    FOR r IN EXECUTE format('SELECT n.nspname, c.relname FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON c.relnamespace = n.oid WHERE c.relkind = ''i'' AND n.nspname = %L AND pg_get_userbyid(c.relowner) != %L', schema_name, role_name) LOOP
      EXECUTE format('ALTER INDEX %I.%I OWNER TO %I', r.nspname, r.relname, role_name);
    END LOOP;
    FOR r IN EXECUTE format('SELECT n.nspname, c.relname FROM pg_catalog.pg_class AS c JOIN pg_catalog.pg_namespace AS n ON c.relnamespace = n.oid WHERE c.relkind = ''S'' AND n.nspname = %L AND pg_get_userbyid(c.relowner) != %L', schema_name, role_name) LOOP
      EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO %I', r.nspname, r.relname, role_name);
    END LOOP;
  END;
$$ LANGUAGE plpgsql;

DO $$
  BEGIN
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
      ALTER SCHEMA api_umbrella OWNER TO api_umbrella_owner;
      ALTER SCHEMA audit OWNER TO api_umbrella_owner;
      PERFORM pg_temp.ensure_schema_owner('api_umbrella', 'api_umbrella_owner');
      PERFORM pg_temp.ensure_schema_owner('audit', 'api_umbrella_owner');
    END IF;

    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_app') THEN
      GRANT USAGE ON SCHEMA public, api_umbrella TO api_umbrella_app;
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public, api_umbrella TO api_umbrella_app;
      GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public, api_umbrella TO api_umbrella_app;
      REVOKE ALL ON api_umbrella.auto_ssl_storage FROM api_umbrella_app;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_app TO api_umbrella_owner;
      END IF;
    END IF;

    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_auto_ssl') THEN
      GRANT USAGE ON SCHEMA public, api_umbrella TO api_umbrella_auto_ssl;
      GRANT SELECT, INSERT, UPDATE, DELETE ON api_umbrella.auto_ssl_storage TO api_umbrella_auto_ssl;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_auto_ssl TO api_umbrella_owner;
      END IF;
    END IF;
  END
$$;
