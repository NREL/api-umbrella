local db = require("lapis.db")

return {
  [1498350289] = function()
    -- TODO: Integrate https://raw.githubusercontent.com/razorlabs/pg-json-audit-trigger/07fd12b7694c255fcd7286f6bd2035edb382fa3e/audit.sql

    db.query([[
      CREATE OR REPLACE FUNCTION set_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        IF row(NEW.*) IS DISTINCT FROM row(OLD.*) THEN
          NEW.updated_at = (now() at time zone 'UTC');
          RETURN NEW;
        ELSE
          RETURN OLD;
        END IF;
      END;
      $$ language 'plpgsql';
    ]])

    db.query([[
      CREATE TABLE api_scopes(
        id uuid PRIMARY KEY DEFAULT md5(random()::text || clock_timestamp()::text)::uuid,
        name varchar(255) NOT NULL,
        host varchar(255) NOT NULL,
        path_prefix varchar(255) NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
        created_by uuid,
        updated_at timestamp with time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
        updated_by uuid
      )
    ]])

    db.query("SELECT audit.audit_table('api_scopes')")
    db.query("CREATE UNIQUE INDEX ON api_scopes(host, path_prefix)")
    db.query("CREATE TRIGGER api_scopes_updated_at BEFORE UPDATE ON api_scopes FOR EACH ROW EXECUTE PROCEDURE set_updated_at()")
  end
}
