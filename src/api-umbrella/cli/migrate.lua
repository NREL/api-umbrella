local read_config = require "api-umbrella.cli.read_config"
local config = read_config()

local setenv = require("posix.stdlib").setenv
setenv("API_UMBRELLA_RUNTIME_CONFIG", config["_api_umbrella_config_runtime_file"])

-- Override the default config details that Lapis will use in src/config.lua
-- and src/migrations.lua to connect to the database.
config = require "api-umbrella.proxy.models.file_config"
config["postgresql"]["username"] = config["postgresql"]["migrations"]["username"]
config["postgresql"]["password"] = config["postgresql"]["migrations"]["password"]

local file = require "pl.file"
local migrations = require("lapis.db.migrations")
local path = require "pl.path"
local pg_utils = require "api-umbrella.utils.pg_utils"

return function()
  -- FIXME: Don't drop the database on every migrate... Obviously. Just for
  -- testing/development purposes now.
  if config["app_env"] == "development" then
    -- Connect as superuser to drop/create database.
    pg_utils.db_config["user"] = "api-umbrella"
    pg_utils.db_config["password"] = nil
    pg_utils.db_config["database"] = "postgres"

    pg_utils.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'api_umbrella' AND pid != pg_backend_pid()", nil, { verbose = true, fatal = true })
    pg_utils.query("DROP DATABASE IF EXISTS api_umbrella", nil, { verbose = true, fatal = true })
    pg_utils.query("CREATE DATABASE api_umbrella WITH OWNER = " .. pg_utils.escape_identifier(config["postgresql"]["migrations"]["username"]), nil, { verbose = true, fatal = true })

    pg_utils.db_config["database"] = "api_umbrella"
    pg_utils.query("ALTER SCHEMA public OWNER TO " .. pg_utils.escape_identifier(config["postgresql"]["migrations"]["username"]), nil, { verbose = true, fatal = true })
    pg_utils.query("GRANT ALL ON SCHEMA public TO " .. pg_utils.escape_identifier(pg_utils.db_config["user"]), nil, { verbose = true, fatal = true })
    pg_utils.query("CREATE EXTENSION IF NOT EXISTS pgcrypto", nil, { verbose = true, fatal = true })
  end

  migrations.create_migrations_table()
  migrations.run_migrations(require("migrations"))

  pg_utils.db_config["user"] = config["postgresql"]["migrations"]["username"]
  pg_utils.db_config["password"] = config["postgresql"]["migrations"]["password"]

  local grants_sql_path = path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/grants.sql")
  local grants_sql = file.read(grants_sql_path, true)
  pg_utils.query(grants_sql, nil, { verbose = true, fatal = true })

  -- In development, dump the db/schema.sql file after migrations.
  if config["app_env"] == "development" then
    setenv("PGHOST", config["postgresql"]["host"])
    setenv("PGPORT", config["postgresql"]["port"])
    setenv("PGDATABASE", config["postgresql"]["database"])
    setenv("PGUSER", config["postgresql"]["migrations"]["username"])
    setenv("PGPASSWORD", config["postgresql"]["migrations"]["password"])
    os.execute("pg_dump --schema-only --no-privileges --no-owner --file=" .. path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/schema.sql"))
  end
end
