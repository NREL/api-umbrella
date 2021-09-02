local read_config = require "api-umbrella.cli.read_config"
local config = read_config({ write = true })

local setenv = require("posix.stdlib").setenv
setenv("API_UMBRELLA_RUNTIME_CONFIG", config["_api_umbrella_config_runtime_file"])

-- Override the default config details that Lapis will use in src/config.lua
-- and src/migrations.lua to connect to the database.
config = require "api-umbrella.proxy.models.file_config"
config["postgresql"]["username"] = config["postgresql"]["migrations"]["username"]
config["postgresql"]["password"] = config["postgresql"]["migrations"]["password"]

local db = require("lapis.db")
local file = require "pl.file"
local migrations = require("lapis.db.migrations")
local shell_blocking_run = require("shell-games").run
local path = require "pl.path"
local pg_utils = require "api-umbrella.utils.pg_utils"

return function()
  db.query("SET search_path = api_umbrella, public")
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
    local schema_path = path.join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/schema.sql")
    local _, err = shell_blocking_run({
      "pg_dump",
      "--schema-only",
      "--no-privileges",
      "--no-owner",
      "--file", schema_path,
    })
    if err then
      print(err)
      os.exit(1)
    end

    _, err = shell_blocking_run({
      "sed",
      "-e",
      [['s/^\(COMMENT ON EXTENSION\)/-- \1/g']],
      "-i",
      schema_path,
    })
    if err then
      print(err)
      os.exit(1)
    end
  end
end
