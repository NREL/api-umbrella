local config = require("api-umbrella.utils.load_config")()

local etlua_render = require("etlua").render
local path_join = require "api-umbrella.utils.path_join"
local pg_utils = require "api-umbrella.utils.pg_utils"
local readfile = require("pl.utils").readfile
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

return function()
  local database = pg_utils.db_config["database"]

  pg_utils.db_config["database"] = "postgres"
  pg_utils.db_config["user"] = os.getenv("DB_USERNAME")
  pg_utils.db_config["password"] = os.getenv("DB_PASSWORD")

  local result = pg_utils.query("SELECT 1 FROM pg_catalog.pg_database WHERE datname = :database", { database = database }, { verbose = true, fatal = true })
  if not result[1] then
    pg_utils.query("CREATE DATABASE :database", { database = pg_utils.identifier(database) }, { verbose = true, fatal = true })
  end

  pg_utils.db_config["database"] = database

  local setup_sql_path = path_join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/setup.sql.etlua")
  local setup_sql = readfile(setup_sql_path, true)
  local render_ok, render_err
  render_ok, setup_sql, render_err = xpcall(etlua_render, xpcall_error_handler, setup_sql, { config = config })
  if not render_ok or render_err then
    ngx.log(ngx.ERR, "template compile error in " .. setup_sql_path ..": " .. (render_err or setup_sql))
    os.exit(1)
  end
  pg_utils.query(setup_sql, nil, { verbose = true, fatal = true })

  local schema_sql_path = path_join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/schema.sql")
  local schema_sql = readfile(schema_sql_path, true)
  pg_utils.query(schema_sql, nil, { verbose = true, fatal = true })

  local grants_sql_path = path_join(os.getenv("API_UMBRELLA_SRC_ROOT"), "db/grants.sql")
  local grants_sql = readfile(grants_sql_path, true)
  pg_utils.query(grants_sql, nil, { verbose = true, fatal = true })
end
