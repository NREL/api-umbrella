local file = require "pl.file"
local path = require "pl.path"
local db = require("lapis.db")

return {
  [1498350289] = function()
    db.query("START TRANSACTION")

    local audit_sql_path = path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/audit.sql")
    local audit_sql = file.read(audit_sql_path, true)
    db.query(audit_sql)

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
      CREATE TABLE admins(
        id uuid PRIMARY KEY,
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
        id uuid PRIMARY KEY,
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
        id uuid PRIMARY KEY,
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
        admin_group_id uuid REFERENCES admin_groups(id),
        admin_permission_id varchar(50) REFERENCES admin_permissions(id),
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
        admin_group_id uuid REFERENCES admin_groups(id),
        admin_id uuid REFERENCES admins(id),
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
        admin_group_id uuid REFERENCES admin_groups(id),
        api_scope_id uuid REFERENCES api_scopes(id),
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
        id uuid PRIMARY KEY,
        name varchar(255) NOT NULL,
        sort_order int NOT NULL,
        backend_protocol varchar(5) NOT NULL CHECK(backend_protocol IN('http', 'https')),
        frontend_host varchar(255) NOT NULL,
        backend_host varchar(255) NOT NULL,
        balance_algorithm varchar(11) NOT NULL CHECK(balance_algorithm IN('round_robin', 'least_conn', 'ip_hash')),
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backends_updated_at BEFORE UPDATE ON api_backends FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backends')")

    db.query([[
      CREATE TABLE api_backend_rewrites(
        id uuid PRIMARY KEY,
        api_backend_id uuid NOT NULL REFERENCES api_backends,
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
        id uuid PRIMARY KEY,
        api_backend_id uuid NOT NULL REFERENCES api_backends,
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
      CREATE TABLE api_backend_url_matches(
        id uuid PRIMARY KEY,
        api_backend_id uuid NOT NULL REFERENCES api_backends,
        frontend_prefix varchar(255) NOT NULL,
        backend_prefix varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        created_by varchar(255) NOT NULL DEFAULT current_app_user(),
        updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
        updated_by varchar(255) NOT NULL DEFAULT current_app_user()
      )
    ]])
    db.query("CREATE TRIGGER api_backend_url_matches_updated_at BEFORE UPDATE ON api_backend_url_matches FOR EACH ROW EXECUTE PROCEDURE set_updated()")
    db.query("SELECT audit.audit_table('api_backend_servers')")

    db.query([[
      CREATE TABLE api_users(
        id uuid PRIMARY KEY,
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
        settings jsonb,
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
      CREATE TABLE published_config(
        id serial PRIMARY KEY,
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
      CREATE TABLE website_backends(
        id uuid PRIMARY KEY,
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

    db.query("GRANT USAGE ON SCHEMA public TO api_umbrella_app_user")
    db.query("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_umbrella_app_user")
    db.query("GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO api_umbrella_app_user")

    db.query("COMMIT")
  end
}
