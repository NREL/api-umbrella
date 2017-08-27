local file = require "pl.file"
local path = require "pl.path"
local db = require("lapis.db")

return {
  [1498350289] = function()
    db.query("START TRANSACTION")

    local audit_sql_path = path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/audit.sql")
    local audit_sql = file.read(audit_sql_path, true)
    db.query(audit_sql)
    db.query("CREATE INDEX ON audit.log(schema_name, table_name)")
    db.query("CREATE INDEX ON audit.log(application_name)")
    db.query("CREATE INDEX ON audit.log(application_user)")
    db.query("CREATE INDEX ON audit.log((original->>'id'))")

    db.query([[
      CREATE OR REPLACE FUNCTION current_app_user()
      RETURNS varchar(255) AS $$
      BEGIN
        RETURN current_setting('application.user');
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE OR REPLACE FUNCTION set_updated()
      RETURNS TRIGGER AS $$
      BEGIN
        IF row(NEW.*) IS DISTINCT FROM row(OLD.*) THEN
          NEW.updated_at := (now() AT TIME ZONE 'UTC');
          NEW.updated_by := current_app_user();
          RETURN NEW;
        ELSE
          RETURN OLD;
        END IF;
      END;
      $$ LANGUAGE plpgsql;
    ]])

    db.query([[
      CREATE OR REPLACE FUNCTION next_api_backend_sort_order()
      RETURNS int AS $$
      BEGIN
        RETURN (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM api_backends);
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
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON admins(username)")
    db.query("CREATE UNIQUE INDEX ON admins(authentication_token_hash)")
    db.query("CREATE UNIQUE INDEX ON admins(reset_password_token_hash)")
    db.query("CREATE UNIQUE INDEX ON admins(unlock_token_hash)")
    db.query("CREATE TRIGGER admins_updated_at BEFORE UPDATE ON admins FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admins')")

    db.query([[
      CREATE TABLE admin_permissions(
        id varchar(50) PRIMARY KEY,
        name varchar(255) NOT NULL,
        display_order smallint NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')
      )
    ]])
    db.query("CREATE INDEX ON admin_permissions(display_order)")
    db.query("CREATE TRIGGER admin_permissions_updated_at BEFORE UPDATE ON admin_permissions FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admin_permissions')")

    db.query([[
      CREATE TABLE api_scopes(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        host varchar(255) NOT NULL,
        path_prefix varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_scopes(host, path_prefix)")
    db.query("CREATE TRIGGER api_scopes_updated_at BEFORE UPDATE ON api_scopes FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_scopes')")

    db.query([[
      CREATE TABLE admin_groups(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_updated_at BEFORE UPDATE ON admin_groups FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admin_groups')")

    db.query([[
      CREATE TABLE admin_groups_admin_permissions(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE,
        admin_permission_id varchar(50) REFERENCES admin_permissions ON DELETE CASCADE,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user(),
        PRIMARY KEY(admin_group_id, admin_permission_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_admin_permissions_updated_at BEFORE UPDATE ON admin_groups_admin_permissions FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admin_groups_admin_permissions')")

    db.query([[
      CREATE TABLE admin_groups_admins(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE,
        admin_id uuid REFERENCES admins ON DELETE CASCADE,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user(),
        PRIMARY KEY(admin_group_id, admin_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_admins_updated_at BEFORE UPDATE ON admin_groups_admins FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admin_groups_admins')")

    db.query([[
      CREATE TABLE admin_groups_api_scopes(
        admin_group_id uuid REFERENCES admin_groups ON DELETE CASCADE,
        api_scope_id uuid REFERENCES api_scopes ON DELETE CASCADE,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user(),
        PRIMARY KEY(admin_group_id, api_scope_id)
      )
    ]])
    db.query("CREATE TRIGGER admin_groups_api_scopes_updated_at BEFORE UPDATE ON admin_groups_api_scopes FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('admin_groups_api_scopes')")

    db.query([[
      CREATE TABLE api_backends(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(255) NOT NULL,
        sort_order int NOT NULL DEFAULT next_api_backend_sort_order(),
        backend_protocol varchar(5) NOT NULL CHECK(backend_protocol IN('http', 'https')),
        frontend_host varchar(255) NOT NULL,
        backend_host varchar(255),
        balance_algorithm varchar(11) NOT NULL CHECK(balance_algorithm IN('round_robin', 'least_conn', 'ip_hash')),
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE INDEX ON api_backends(sort_order)")
    db.query("CREATE TRIGGER api_backends_updated_at BEFORE UPDATE ON api_backends FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backends')")

    db.query([[
      CREATE TABLE api_backend_rewrites(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE,
        matcher_type varchar(5) NOT NULL CHECK(matcher_type IN('route', 'regex')),
        http_method varchar(7) NOT NULL CHECK(http_method IN('any', 'GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'TRACE', 'OPTIONS', 'CONNECT', 'PATCH')),
        frontend_matcher varchar(255) NOT NULL,
        backend_replacement varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backend_rewrites_updated_at BEFORE UPDATE ON api_backend_rewrites FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_rewrites')")

    db.query([[
      CREATE TABLE api_backend_servers(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE,
        host varchar(255) NOT NULL,
        port int NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backend_servers_updated_at BEFORE UPDATE ON api_backend_servers FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_servers')")

    db.query([[
      CREATE TABLE api_backend_sub_url_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE,
        http_method varchar(7) NOT NULL CHECK(http_method IN('any', 'GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'TRACE', 'OPTIONS', 'CONNECT', 'PATCH')),
        regex varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backend_sub_url_settings_updated_at BEFORE UPDATE ON api_backend_sub_url_settings FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_sub_url_settings')")

    db.query([[
      CREATE TABLE api_backend_url_matches(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid NOT NULL REFERENCES api_backends ON DELETE CASCADE,
        frontend_prefix varchar(255) NOT NULL,
        backend_prefix varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backend_url_matches_updated_at BEFORE UPDATE ON api_backend_url_matches FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_url_matches')")

    db.query([[
      CREATE TABLE api_backend_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_id uuid REFERENCES api_backends ON DELETE CASCADE,
        api_backend_sub_url_settings_id uuid REFERENCES api_backend_sub_url_settings ON DELETE CASCADE,
        append_query_string varchar(255),
        http_basic_auth varchar(255),
        require_https varchar(23) CHECK(require_https IN('required_return_error', 'transition_return_error', 'optional')),
        require_https_transition_start_at timestamp with time zone,
        disable_api_key boolean NOT NULL DEFAULT FALSE,
        api_key_verification_level varchar(16) CHECK(api_key_verification_level IN('none', 'transition_email', 'required_email')),
        api_key_verification_transition_start_at timestamp with time zone,
        required_roles varchar(100) ARRAY,
        required_roles_override boolean NOT NULL DEFAULT FALSE,
        allowed_ips inet ARRAY,
        allowed_referers varchar(255) ARRAY,
        pass_api_key_header varchar(255),
        pass_api_key_query_param varchar(255),
        rate_limit_mode varchar(9) CHECK(rate_limit_mode IN('unlimited', 'custom')),
        anonymous_rate_limit_behavior varchar(11) CHECK(anonymous_rate_limit_behavior IN('ip_fallback', 'ip_only')),
        authenticated_rate_limit_behavior varchar(12) CHECK(authenticated_rate_limit_behavior IN('all', 'api_key_only')),
        error_templates jsonb,
        error_data jsonb,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user(),
        CONSTRAINT parent_id_not_null CHECK((api_backend_id IS NOT NULL AND api_backend_sub_url_settings_id IS NULL) OR (api_backend_id IS NULL AND api_backend_sub_url_settings_id IS NOT NULL))
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_settings(api_backend_id)")
    db.query("CREATE UNIQUE INDEX ON api_backend_settings(api_backend_sub_url_settings_id)")
    db.query("CREATE TRIGGER api_backend_settings_updated_at BEFORE UPDATE ON api_backend_settings FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_settings')")

    db.query([[
      CREATE TABLE api_backend_http_headers(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_settings_id uuid NOT NULL REFERENCES api_backend_settings ON DELETE CASCADE,
        header_type varchar(17) NOT NULL CHECK(header_type IN('request', 'response_default', 'response_override')),
        sort_order int NOT NULL,
        key varchar(255) NOT NULL,
        value varchar(255),
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_backend_http_headers(api_backend_settings_id, header_type, sort_order)")
    db.query("CREATE TRIGGER api_backend_http_headers_updated_at BEFORE UPDATE ON api_backend_http_headers FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_http_headers')")

    db.query([[
      CREATE TABLE api_users(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_key_hash varchar(64) NOT NULL,
        api_key_encrypted varchar(76) NOT NULL,
        api_key_encrypted_iv varchar(12) NOT NULL,
        api_key_prefix varchar(10) NOT NULL,
        email varchar(255) NOT NULL,
        email_verified boolean NOT NULL DEFAULT FALSE,
        first_name varchar(255),
        last_name varchar(255),
        use_description varchar(2000),
        user_metadata jsonb,
        registration_ip inet,
        registration_source varchar(255),
        registration_user_agent varchar(1000),
        registration_referer varchar(1000),
        registration_origin varchar(1000),
        throttle_by_ip boolean NOT NULL DEFAULT FALSE,
        roles varchar(100) ARRAY,
        disabled_at timestamp with time zone,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE UNIQUE INDEX ON api_users(api_key_hash)")
    db.query("CREATE TRIGGER api_users_updated_at BEFORE UPDATE ON api_users FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_users')")

    db.query([[
      CREATE TABLE api_user_settings(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_user_id uuid NOT NULL REFERENCES api_users ON DELETE CASCADE,
        rate_limit_mode varchar(9) CHECK(rate_limit_mode IN('unlimited', 'custom')),
        allowed_ips inet ARRAY,
        allowed_referers varchar(255) ARRAY,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_user_settings_updated_at BEFORE UPDATE ON api_user_settings FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_user_settings')")

    db.query([[
      CREATE TABLE published_config(
        id bigserial PRIMARY KEY,
        config jsonb NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER published_config_updated_at BEFORE UPDATE ON published_config FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('published_config')")

    db.query([[
      CREATE TABLE rate_limits(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        api_backend_settings_id uuid REFERENCES api_backend_settings ON DELETE CASCADE,
        api_user_settings_id uuid REFERENCES api_user_settings ON DELETE CASCADE,
        duration bigint NOT NULL,
        accuracy bigint NOT NULL,
        limit_by varchar(7) NOT NULL CHECK(limit_by IN('ip', 'api_key')),
        limit_to bigint NOT NULL,
        distributed boolean NOT NULL DEFAULT FALSE,
        response_headers boolean NOT NULL DEFAULT FALSE,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user(),
        CONSTRAINT settings_id_not_null CHECK((api_backend_settings_id IS NOT NULL AND api_user_settings_id IS NULL) OR (api_backend_settings_id IS NULL AND api_user_settings_id IS NOT NULL))
      )
    ]])
    db.query("CREATE TRIGGER rate_limits_updated_at BEFORE UPDATE ON rate_limits FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('rate_limits')")

    db.query([[
      CREATE TABLE website_backends(
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        frontend_host varchar(255) NOT NULL,
        backend_protocol varchar(5) NOT NULL CHECK(backend_protocol IN('http', 'https')),
        server_host varchar(255) NOT NULL,
        server_port int NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER website_backends_updated_at BEFORE UPDATE ON website_backends FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('website_backends')")

    db.query([[
      CREATE TABLE sessions(
        id varchar(40) PRIMARY KEY,
        expires timestamp with time zone,
        encrypted_data TEXT NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE PROCEDURE set_updated()")

    db.query([[
      CREATE VIEW api_users_with_settings AS
        SELECT u.*,
          row_to_json(s.*) AS settings,
          (SELECT json_agg(r.*) FROM rate_limits AS r WHERE r.api_user_settings_id = s.id) AS rate_limits
        FROM api_users AS u
          LEFT JOIN api_user_settings AS s ON u.id = s.api_user_id
    ]])

    db.query("GRANT USAGE ON SCHEMA public TO api_umbrella_app_user")
    db.query("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_umbrella_app_user")
    db.query("GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO api_umbrella_app_user")

    db.query("COMMIT")
  end
}
