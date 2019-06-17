local db = require("lapis.db")
local file = require "pl.file"
local json_encode = require "api-umbrella.utils.json_encode"
local path = require "pl.path"

return {
  [1498350289] = function()
    db.query("START TRANSACTION")
    db.query("CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public")

    local audit_sql_path = path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/pg-audit-json--1.0.1.sql")
    local audit_sql = file.read(audit_sql_path, true)
    audit_sql = ngx.re.sub(audit_sql, [[^(\\echo Use)]], "-- $1", "m")
    audit_sql = ngx.re.sub(audit_sql, [[^(SELECT pg_catalog.pg_extension_config_dump)]], "-- $1", "m")
    db.query("SET search_path = public")
    db.query(audit_sql)
    db.query("CREATE INDEX ON audit.log(schema_name, table_name)")
    db.query("CREATE INDEX ON audit.log(application_user_name)")
    db.query("CREATE INDEX ON audit.log((row_data->>'id'))")

    db.query("CREATE SCHEMA IF NOT EXISTS api_umbrella")
    db.query("SET search_path = api_umbrella, public")

    db.query([[
      CREATE OR REPLACE FUNCTION current_app_user_id()
      RETURNS uuid AS $$
      BEGIN
        RETURN current_setting('audit.application_user_id')::uuid;
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE OR REPLACE FUNCTION current_app_username()
      RETURNS varchar(255) AS $$
      BEGIN
        RETURN current_setting('audit.application_user_name');
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE OR REPLACE FUNCTION stamp_record()
      RETURNS TRIGGER AS $$
      DECLARE
        associations jsonb;
        association jsonb;
      BEGIN
        -- Only perform stamping ON INSERT/DELETE or if the UPDATE actually
        -- changed any fields.
        --
        -- Detect changes using *<> operator which is compatible with "point"
        -- types that "DISTINCT FROM" is not:
        -- https://www.mail-archive.com/pgsql-general@postgresql.org/msg198866.html
        -- https://www.postgresql.org/docs/10/functions-comparisons.html#COMPOSITE-TYPE-COMPARISON
        IF (COALESCE(current_setting('api_umbrella.disable_stamping', true), 'off') != 'on' AND (TG_OP != 'UPDATE' OR NEW *<> OLD)) THEN
          -- Update the updated_at timestamp on associated tables (which in
          -- turn will trigger this stamp_record() on that table if the
          -- timestamp changes to take care of any userstamping).
          --
          -- This is done so that insert/updates/deletes of nested data cascade
          -- the updated stamping information to any parent records. For
          -- example, when changing rate limits for a API user:
          --
          -- 1. The insert/update/delete on rate_limits will trigger an update
          --    on the parent api_user_settings record.
          -- 2. The update on the api_user_settings record will trigger an
          --    update on the parent api_user record.
          -- 3. The update on the api_user record will trigger its own update
          --    triggers (which in the case of api_users will result in the
          --    "version" being incremented).
          --
          -- This is primarily for the nested relationship data in api_users
          -- and api_backends, since it keeps the top-level record's timestamps
          -- updated whenever any child record is updated. This is useful for
          -- display purposes (so the updated timestamp of the top-level record
          -- accurately takes into account child record modifications). More
          -- importantly, this is necessary for some of our polling mechanisms
          -- which rely on record timestamps or version increments on the
          -- top-level records to detect any changes and invalidate caches (for
          -- example, detecting when api_users are changed to clear the proxy
          -- cache).
          --
          -- Note: We don't try to automatically detect all associations based
          -- on foreign keys, since that can lead to unnecessary updates (eg,
          -- when updating "api_users_roles" it only really makes sense to
          -- cascade the update time to the user, but not the roles table),
          -- which can also lead to deadlocks under higher concurrency (seen
          -- mainly in our test environment).
          IF TG_ARGV[0] IS NOT NULL THEN
            associations = TG_ARGV[0]::jsonb;
            FOR association IN SELECT * FROM jsonb_array_elements(associations)
            LOOP
              EXECUTE format('UPDATE %I SET updated_at = transaction_timestamp() WHERE %I = ($1).%s', association->>'table_name', association->>'primary_key', association->>'foreign_key') USING (CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);
            END LOOP;
          END IF;

          -- Set the created/updated timestamp and userstamp columns on INSERT
          -- or UPDATE.
          CASE TG_OP
          WHEN 'INSERT' THEN
            -- Use COALESCE to allow for overriding these values with custom
            -- settings on create. The app shouldn't ever set these itself,
            -- this is primarily for the test environment, where it's sometimes
            -- useful to be able to create records with older timestamps.
            NEW.created_at := COALESCE(NEW.created_at, transaction_timestamp());
            NEW.created_by_id := COALESCE(NEW.created_by_id, current_app_user_id());
            NEW.created_by_username := COALESCE(NEW.created_by_username, current_app_username());
            NEW.updated_at := COALESCE(NEW.updated_at, NEW.created_at);
            NEW.updated_by_id := COALESCE(NEW.updated_by_id, NEW.created_by_id);
            NEW.updated_by_username := COALESCE(NEW.updated_by_username, NEW.created_by_username);
          WHEN 'UPDATE' THEN
            NEW.updated_at := transaction_timestamp();
            NEW.updated_by_id := current_app_user_id();
            NEW.updated_by_username := current_app_username();
          WHEN 'DELETE' THEN
            -- Do nothing on deletes.
          END CASE;
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        ELSE
          RETURN NEW;
        END IF;
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE OR REPLACE FUNCTION update_timestamp()
      RETURNS TRIGGER AS $$
      BEGIN
        -- Detect changes using *<> operator which is compatible with "point"
        -- types that "DISTINCT FROM" is not:
        -- https://www.mail-archive.com/pgsql-general@postgresql.org/msg198866.html
        -- https://www.postgresql.org/docs/10/functions-comparisons.html#COMPOSITE-TYPE-COMPARISON
        IF NEW *<> OLD THEN
          NEW.updated_at := transaction_timestamp();
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    ]])


    db.query([[
      CREATE OR REPLACE FUNCTION next_api_backend_sort_order()
      RETURNS int AS $$
      BEGIN
        RETURN (SELECT COALESCE(MAX(sort_order), 0) + 10000 FROM api_backends);
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE TABLE admins(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        username varchar(255) NOT NULL,
        email varchar(255),
        name varchar(255),
        notes text,
        superuser boolean NOT NULL DEFAULT FALSE,
        authentication_token_hash varchar(64) NOT NULL,
        authentication_token_encrypted varchar(76) NOT NULL,
        authentication_token_encrypted_iv varchar(12) NOT NULL,
        current_sign_in_provider varchar(100),
        last_sign_in_provider varchar(100),
        password_hash varchar(60),
        reset_password_token_hash varchar(64),
        reset_password_sent_at timestamp with time zone,
        remember_created_at timestamp with time zone,
        sign_in_count integer NOT NULL DEFAULT 0,
        current_sign_in_at timestamp with time zone,
        last_sign_in_at timestamp with time zone,
        current_sign_in_ip inet,
        last_sign_in_ip inet,
        failed_attempts integer NOT NULL DEFAULT 0,
        unlock_token_hash varchar(64),
        locked_at timestamp with time zone,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON admins(username)")
    db.query("CREATE UNIQUE INDEX ON admins(authentication_token_hash)")
    db.query("CREATE UNIQUE INDEX ON admins(reset_password_token_hash)")
    db.query("CREATE UNIQUE INDEX ON admins(unlock_token_hash)")
    db.query("CREATE TRIGGER admins_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admins FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('admins')")

    db.query([[
      CREATE TABLE admin_permissions(
        id varchar(50) PRIMARY KEY,
        name varchar(255) NOT NULL,
        display_order smallint NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE INDEX ON admin_permissions(display_order)")
    db.query("CREATE TRIGGER admin_permissions_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admin_permissions FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('admin_permissions')")

    db.query([[
      CREATE TABLE api_scopes(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        host varchar(255) NOT NULL,
        path_prefix varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_scopes(host, path_prefix)")
    db.query("CREATE TRIGGER api_scopes_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_scopes FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('api_scopes')")

    db.query([[
      CREATE TABLE admin_groups(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON admin_groups(name)")
    db.query("CREATE TRIGGER admin_groups_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admin_groups FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('admin_groups')")

    db.query([[
      CREATE TABLE admin_groups_admin_permissions(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        admin_permission_id varchar(50) REFERENCES admin_permissions ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        PRIMARY KEY(admin_group_id, admin_permission_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_admin_permissions_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admin_groups_admin_permissions FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "admin_groups",
        primary_key = "id",
        foreign_key = "admin_group_id",
      },
    }))
    db.query("SELECT audit.audit_table('admin_groups_admin_permissions')")

    db.query([[
      CREATE TABLE admin_groups_admins(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        admin_id uuid REFERENCES admins ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        PRIMARY KEY(admin_group_id, admin_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_admins_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admin_groups_admins FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "admins",
        primary_key = "id",
        foreign_key = "admin_id",
      },
    }))
    db.query("SELECT audit.audit_table('admin_groups_admins')")

    db.query([[
      CREATE TABLE admin_groups_api_scopes(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        api_scope_id uuid REFERENCES api_scopes ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        PRIMARY KEY(admin_group_id, api_scope_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_api_scopes_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON admin_groups_api_scopes FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "admin_groups",
        primary_key = "id",
        foreign_key = "admin_group_id",
      },
    }))
    db.query("SELECT audit.audit_table('admin_groups_api_scopes')")

    db.query([[
      CREATE TABLE api_roles(
        id varchar(255) PRIMARY KEY,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE TRIGGER api_roles_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_roles FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('api_roles')")

    db.query([[
      CREATE TABLE api_backends(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        sort_order int NOT NULL DEFAULT next_api_backend_sort_order(),
        backend_protocol varchar(5) NOT NULL CHECK(backend_protocol IN('http', 'https')),
        frontend_host varchar(255) NOT NULL,
        backend_host varchar(255),
        balance_algorithm varchar(11) NOT NULL CHECK(balance_algorithm IN('round_robin', 'least_conn', 'ip_hash')),
        keepalive_connections smallint,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE INDEX ON api_backends(sort_order)")
    db.query("CREATE TRIGGER api_backends_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backends FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('api_backends')")

    db.query([[
      CREATE TABLE api_backend_rewrites(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        matcher_type varchar(5) NOT NULL CHECK(matcher_type IN('route', 'regex')),
        http_method varchar(7) NOT NULL CHECK(http_method IN('any', 'GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'TRACE', 'OPTIONS', 'CONNECT', 'PATCH')),
        frontend_matcher varchar(255) NOT NULL,
        backend_replacement varchar(255) NOT NULL,
        sort_order int NOT NULL DEFAULT 0,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_rewrites(api_backend_id, matcher_type, http_method, frontend_matcher)")
    db.query("CREATE UNIQUE INDEX ON api_backend_rewrites(api_backend_id, sort_order)")
    db.query("CREATE TRIGGER api_backend_rewrites_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_rewrites FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backends",
        primary_key = "id",
        foreign_key = "api_backend_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_rewrites')")

    db.query([[
      CREATE TABLE api_backend_servers(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        host varchar(255) NOT NULL,
        port int NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_servers(api_backend_id, host, port)")
    db.query("CREATE TRIGGER api_backend_servers_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_servers FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backends",
        primary_key = "id",
        foreign_key = "api_backend_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_servers')")

    db.query([[
      CREATE TABLE api_backend_sub_url_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        http_method varchar(7) NOT NULL CHECK(http_method IN('any', 'GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'TRACE', 'OPTIONS', 'CONNECT', 'PATCH')),
        regex varchar(255) NOT NULL,
        sort_order int NOT NULL DEFAULT 0,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_sub_url_settings(api_backend_id, http_method, regex)")
    db.query("CREATE UNIQUE INDEX ON api_backend_sub_url_settings(api_backend_id, sort_order)")
    db.query("CREATE TRIGGER api_backend_sub_url_settings_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_sub_url_settings FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backends",
        primary_key = "id",
        foreign_key = "api_backend_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_sub_url_settings')")

    db.query([[
      CREATE TABLE api_backend_url_matches(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        frontend_prefix varchar(255) NOT NULL,
        backend_prefix varchar(255) NOT NULL,
        sort_order int NOT NULL DEFAULT 0,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_url_matches(api_backend_id, frontend_prefix)")
    db.query("CREATE UNIQUE INDEX ON api_backend_url_matches(api_backend_id, sort_order)")
    db.query("CREATE TRIGGER api_backend_url_matches_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_url_matches FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backends",
        primary_key = "id",
        foreign_key = "api_backend_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_url_matches')")

    db.query([[
      CREATE TABLE api_backend_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid REFERENCES api_backends ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        api_backend_sub_url_settings_id uuid REFERENCES api_backend_sub_url_settings ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        append_query_string varchar(255),
        http_basic_auth varchar(255),
        require_https varchar(23) CHECK(require_https IN('required_return_error', 'transition_return_error', 'optional')),
        require_https_transition_start_at timestamp with time zone,
        redirect_https boolean NOT NULL DEFAULT FALSE,
        disable_api_key boolean,
        api_key_verification_level varchar(16) CHECK(api_key_verification_level IN('none', 'transition_email', 'required_email')),
        api_key_verification_transition_start_at timestamp with time zone,
        required_roles_override boolean NOT NULL DEFAULT FALSE,
        pass_api_key_header boolean NOT NULL DEFAULT FALSE,
        pass_api_key_query_param boolean NOT NULL DEFAULT FALSE,
        rate_limit_bucket_name varchar(255),
        rate_limit_mode varchar(9) CHECK(rate_limit_mode IN('unlimited', 'custom')),
        anonymous_rate_limit_behavior varchar(11) CHECK(anonymous_rate_limit_behavior IN('ip_fallback', 'ip_only')),
        authenticated_rate_limit_behavior varchar(12) CHECK(authenticated_rate_limit_behavior IN('all', 'api_key_only')),
        error_templates jsonb,
        error_data jsonb,
        allowed_ips inet ARRAY,
        allowed_referers varchar(500) ARRAY,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        CONSTRAINT parent_id_not_null CHECK((api_backend_id IS NOT NULL AND api_backend_sub_url_settings_id IS NULL) OR (api_backend_id IS NULL AND api_backend_sub_url_settings_id IS NOT NULL))
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_settings(api_backend_id)")
    db.query("CREATE UNIQUE INDEX ON api_backend_settings(api_backend_sub_url_settings_id)")
    db.query("CREATE TRIGGER api_backend_settings_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_settings FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backends",
        primary_key = "id",
        foreign_key = "api_backend_id",
      },
      {
        table_name = "api_backend_sub_url_settings",
        primary_key = "id",
        foreign_key = "api_backend_sub_url_settings_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_settings')")

    db.query([[
      CREATE TABLE api_backend_settings_required_roles(
        api_backend_settings_id uuid NOT NULL REFERENCES api_backend_settings ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        api_role_id varchar(255) NOT NULL REFERENCES api_roles ON DELETE NO ACTION DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        PRIMARY KEY(api_backend_settings_id, api_role_id)
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_settings_required_roles(api_backend_settings_id, api_role_id)")
    db.query("CREATE TRIGGER api_backend_settings_required_roles_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_settings_required_roles FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backend_settings",
        primary_key = "id",
        foreign_key = "api_backend_settings_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_settings_required_roles')")

    db.query([[
      CREATE TABLE api_backend_http_headers(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_settings_id uuid NOT NULL REFERENCES api_backend_settings ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        header_type varchar(17) NOT NULL CHECK(header_type IN('request', 'response_default', 'response_override')),
        sort_order int NOT NULL,
        key varchar(255) NOT NULL,
        value varchar(255),
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_http_headers(api_backend_settings_id, header_type, sort_order)")
    db.query("CREATE TRIGGER api_backend_http_headers_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_backend_http_headers FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backend_settings",
        primary_key = "id",
        foreign_key = "api_backend_settings_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_backend_http_headers')")

    db.query([[
      CREATE TABLE api_users(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        version bigint NOT NULL,
        api_key_hash varchar(64) NOT NULL,
        api_key_encrypted varchar(76) NOT NULL,
        api_key_encrypted_iv varchar(12) NOT NULL,
        api_key_prefix varchar(16) NOT NULL,
        email varchar(255) NOT NULL,
        email_verified boolean NOT NULL DEFAULT FALSE,
        first_name varchar(80),
        last_name varchar(80),
        use_description varchar(2000),
        website varchar(255),
        metadata jsonb,
        registration_ip inet,
        registration_source varchar(255),
        registration_user_agent varchar(1000),
        registration_referer varchar(1000),
        registration_origin varchar(1000),
        throttle_by_ip boolean NOT NULL DEFAULT FALSE,
        disabled_at timestamp with time zone,
        imported boolean NOT NULL DEFAULT FALSE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_users(version)")
    db.query("CREATE UNIQUE INDEX ON api_users(api_key_hash)")
    db.query("CREATE UNIQUE INDEX ON api_users(api_key_prefix)")
    -- Use the full negative and positive bigint range for this sequence.
    --
    -- For the minimum value, we actually use 1 plus the bigint minimum so we
    -- can more easily perform "last_value - 1" math in some of our queries
    -- without exceeding the bigint range.
    db.query("CREATE SEQUENCE api_users_version_seq MINVALUE -9223372036854775807 MAXVALUE 9223372036854775807")
    db.query([[
      CREATE OR REPLACE FUNCTION api_users_increment_version()
      RETURNS TRIGGER AS $$
      BEGIN
        -- Only increment the version on INSERT or if the UPDATE actually
        -- changed any fields.
        --
        -- Detect changes using *<> operator which is compatible with "point"
        -- types that "DISTINCT FROM" is not:
        -- https://www.mail-archive.com/pgsql-general@postgresql.org/msg198866.html
        -- https://www.postgresql.org/docs/10/functions-comparisons.html#COMPOSITE-TYPE-COMPARISON
        IF TG_OP != 'UPDATE' OR NEW *<> OLD THEN
          NEW.version := nextval('api_users_version_seq');
        END IF;

        return NEW;
      END;
      $$ LANGUAGE plpgsql;
    ]])
    db.query("CREATE TRIGGER api_users_increment_version_trigger BEFORE INSERT OR UPDATE ON api_users FOR EACH ROW EXECUTE PROCEDURE api_users_increment_version()")
    db.query("CREATE TRIGGER api_users_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_users FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('api_users')")

    db.query([[
      CREATE TABLE api_users_roles(
        api_user_id uuid NOT NULL REFERENCES api_users ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        api_role_id varchar(255) NOT NULL REFERENCES api_roles ON DELETE NO ACTION DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        PRIMARY KEY(api_user_id, api_role_id)
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_users_roles(api_user_id, api_role_id)")
    db.query("CREATE TRIGGER api_users_roles_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_users_roles FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_users",
        primary_key = "id",
        foreign_key = "api_user_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_users_roles')")

    db.query([[
      CREATE TABLE api_user_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_user_id uuid NOT NULL REFERENCES api_users ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        rate_limit_mode varchar(9) CHECK(rate_limit_mode IN('unlimited', 'custom')),
        allowed_ips inet ARRAY,
        allowed_referers varchar(500) ARRAY,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE TRIGGER api_user_settings_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON api_user_settings FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_users",
        primary_key = "id",
        foreign_key = "api_user_id",
      },
    }))
    db.query("SELECT audit.audit_table('api_user_settings')")

    db.query([[
      CREATE TABLE published_config(
        id bigserial PRIMARY KEY,
        config jsonb NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE TRIGGER published_config_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON published_config FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('published_config')")

    db.query([[
      CREATE TABLE rate_limits(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_settings_id uuid REFERENCES api_backend_settings ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        api_user_settings_id uuid REFERENCES api_user_settings ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE,
        duration bigint NOT NULL,
        accuracy bigint NOT NULL,
        limit_by varchar(7) NOT NULL CHECK(limit_by IN('ip', 'api_key')),
        limit_to bigint NOT NULL,
        distributed boolean NOT NULL DEFAULT FALSE,
        response_headers boolean NOT NULL DEFAULT FALSE,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL,
        CONSTRAINT settings_id_not_null CHECK((api_backend_settings_id IS NOT NULL AND api_user_settings_id IS NULL) OR (api_backend_settings_id IS NULL AND api_user_settings_id IS NOT NULL))
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON rate_limits(api_backend_settings_id, api_user_settings_id, limit_by, duration)")
    db.query("CREATE TRIGGER rate_limits_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON rate_limits FOR EACH ROW EXECUTE PROCEDURE stamp_record(?)", json_encode({
      {
        table_name = "api_backend_settings",
        primary_key = "id",
        foreign_key = "api_backend_settings_id",
      },
      {
        table_name = "api_user_settings",
        primary_key = "id",
        foreign_key = "api_user_settings_id",
      },
    }))
    db.query("SELECT audit.audit_table('rate_limits')")

    db.query([[
      CREATE TABLE website_backends(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        frontend_host varchar(255) NOT NULL,
        backend_protocol varchar(5) NOT NULL CHECK(backend_protocol IN('http', 'https')),
        server_host varchar(255) NOT NULL,
        server_port int NOT NULL,
        created_at timestamp with time zone NOT NULL,
        created_by_id uuid NOT NULL,
        created_by_username varchar(255) NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        updated_by_id uuid NOT NULL,
        updated_by_username varchar(255) NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON website_backends(frontend_host)")
    db.query("CREATE TRIGGER website_backends_stamp_record BEFORE INSERT OR UPDATE OR DELETE ON website_backends FOR EACH ROW EXECUTE PROCEDURE stamp_record()")
    db.query("SELECT audit.audit_table('website_backends')")

    db.query([[
      CREATE TABLE sessions(
        id_hash varchar(64) PRIMARY KEY,
        data_encrypted bytea NOT NULL,
        data_encrypted_iv varchar(12) NOT NULL,
        expires_at timestamp with time zone NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp()
      )
    ]])
    db.query("CREATE INDEX ON sessions(expires_at)")
    db.query("CREATE TRIGGER sessions_stamp_record BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE PROCEDURE update_timestamp()")

    db.query([[
      CREATE TABLE analytics_cities(
        id serial PRIMARY KEY,
        country varchar(2) NOT NULL,
        region varchar(2),
        city varchar(200),
        location point NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp()
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON analytics_cities(country, region, city)")
    db.query("CREATE TRIGGER analytics_cities_stamp_record BEFORE UPDATE ON analytics_cities FOR EACH ROW EXECUTE PROCEDURE update_timestamp()")

    db.query([[
      CREATE TABLE distributed_rate_limit_counters(
        id varchar(500) PRIMARY KEY,
        version bigint NOT NULL,
        value bigint NOT NULL,
        expires_at timestamp with time zone NOT NULL
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON distributed_rate_limit_counters(version)")
    db.query("CREATE INDEX ON distributed_rate_limit_counters(expires_at)")
    -- Use the full negative and positive bigint range for this sequence.
    --
    -- For the minimum value, we actually use 1 plus the bigint minimum so we
    -- can more easily perform "last_value - 1" math in some of our queries
    -- without exceeding the bigint range.
    db.query("CREATE SEQUENCE distributed_rate_limit_counters_version_seq MINVALUE -9223372036854775807 MAXVALUE 9223372036854775807 CYCLE")
    db.query([[
      CREATE OR REPLACE FUNCTION distributed_rate_limit_counters_increment_version()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.version := nextval('distributed_rate_limit_counters_version_seq');
        return NEW;
      END;
      $$ LANGUAGE plpgsql;
    ]])
    db.query("CREATE TRIGGER distributed_rate_limit_counters_increment_version_trigger BEFORE INSERT OR UPDATE ON distributed_rate_limit_counters FOR EACH ROW EXECUTE PROCEDURE distributed_rate_limit_counters_increment_version()")

    db.query([[
      CREATE TABLE cache(
        id varchar(255) PRIMARY KEY,
        data bytea NOT NULL,
        expires_at timestamp with time zone,
        created_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp()
      )
    ]])
    db.query("CREATE INDEX ON cache(expires_at)")
    db.query("CREATE TRIGGER cache_stamp_record BEFORE UPDATE ON cache FOR EACH ROW EXECUTE PROCEDURE update_timestamp()")

    db.query([[
      CREATE VIEW api_users_flattened AS
        SELECT u.id,
          u.version,
          u.api_key_hash,
          u.api_key_encrypted,
          u.api_key_encrypted_iv,
          u.email,
          u.email_verified,
          u.registration_source,
          u.throttle_by_ip,
          extract(epoch from u.disabled_at) AS disabled_at,
          extract(epoch from u.created_at) AS created_at,
          json_build_object(
            'allowed_ips', s.allowed_ips,
            'allowed_referers', s.allowed_referers,
            'rate_limit_mode', s.rate_limit_mode,
            'rate_limits', (
              SELECT json_agg(r2.*)
              FROM (
                SELECT
                  r.duration,
                  r.accuracy,
                  r.limit_by,
                  r.limit_to,
                  r.distributed,
                  r.response_headers
                FROM rate_limits AS r
                WHERE r.api_user_settings_id = s.id
              ) AS r2
            )
          ) AS settings,
          ARRAY(SELECT ar.api_role_id FROM api_users_roles AS ar WHERE ar.api_user_id = u.id) AS roles
        FROM api_users AS u
          LEFT JOIN api_user_settings AS s ON u.id = s.api_user_id
    ]])

    db.query([[
      CREATE TABLE auto_ssl_storage (
        key text PRIMARY KEY,
        value_encrypted bytea NOT NULL,
        value_encrypted_iv varchar(12) NOT NULL,
        expires_at timestamp with time zone,
        created_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp()
      )
    ]])
    db.query("CREATE INDEX ON auto_ssl_storage (expires_at)")
    db.query("CREATE TRIGGER auto_ssl_storage_stamp_record BEFORE UPDATE ON auto_ssl_storage FOR EACH ROW EXECUTE PROCEDURE update_timestamp()")

    db.query([[
      CREATE TABLE audit.legacy_log(
        id bigserial PRIMARY KEY,
        version bigint NOT NULL,
        original_class varchar(255) NOT NULL,
        original_class_id varchar(36) NOT NULL,
        altered_attributes jsonb NOT NULL,
        full_attributes jsonb NOT NULL,
        created_at timestamp with time zone NOT NULL,
        updated_at timestamp with time zone NOT NULL
      )
    ]])

    db.query("COMMIT")
  end,

  [1554823736] = function()
    db.query("ALTER TABLE api_umbrella.api_backends ADD COLUMN organization_name varchar(255)")
    db.query("ALTER TABLE api_umbrella.api_backends ADD COLUMN status_description varchar(255)")
  end,

  [1560722058] = function()
    db.query([[
      CREATE TABLE analytics_cache(
        id varchar(64) PRIMARY KEY,
        id_data jsonb NOT NULL,
        data jsonb NOT NULL,
        expires_at timestamp with time zone,
        created_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp with time zone NOT NULL DEFAULT transaction_timestamp()
      )
    ]])
    db.query("CREATE INDEX ON analytics_cache(expires_at)")
    db.query("CREATE TRIGGER analytics_cache_stamp_record BEFORE UPDATE ON analytics_cache FOR EACH ROW EXECUTE PROCEDURE update_timestamp()")
  end,
}
