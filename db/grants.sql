DO $$
  BEGIN
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_app_user') THEN
      GRANT USAGE ON SCHEMA public TO api_umbrella_app_user;
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_umbrella_app_user;
      GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO api_umbrella_app_user;
      REVOKE ALL ON auto_ssl_storage FROM api_umbrella_app_user;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_app_user TO api_umbrella_owner;
      END IF;
    END IF;

    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_auto_ssl_user') THEN
      GRANT USAGE ON SCHEMA public TO api_umbrella_auto_ssl_user;
      GRANT SELECT, INSERT, UPDATE, DELETE ON auto_ssl_storage TO api_umbrella_auto_ssl_user;

      IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'api_umbrella_owner') THEN
        GRANT api_umbrella_auto_ssl_user TO api_umbrella_owner;
      END IF;
    END IF;
  END
$$;
