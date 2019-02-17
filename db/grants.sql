DO $$
  BEGIN
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_app') THEN
      GRANT USAGE ON SCHEMA public TO api_umbrella_app;
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_umbrella_app;
      GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO api_umbrella_app;
      REVOKE ALL ON auto_ssl_storage FROM api_umbrella_app;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_app TO api_umbrella_owner;
      END IF;
    END IF;

    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_auto_ssl') THEN
      GRANT USAGE ON SCHEMA public TO api_umbrella_auto_ssl;
      GRANT SELECT, INSERT, UPDATE, DELETE ON auto_ssl_storage TO api_umbrella_auto_ssl;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_auto_ssl TO api_umbrella_owner;
      END IF;
    END IF;
  END
$$;
