local argparse = require "argparse"

local parser = argparse("api-umbrella", "Open source API management")

local _M = {}
function _M.run()
  local run = require "api-umbrella.cli.run"
  run()
end

function _M.start()
  local run = require "api-umbrella.cli.run"
  run({ background = true })
end

function _M.stop()
  local stop = require "api-umbrella.cli.stop"
  local ok, err = stop()
  if not ok then
    print(err)
    os.exit(1)
  end
end

function _M.restart()
  _M.stop()
  _M.start()
end

function _M.reload(args)
  local reload = require "api-umbrella.cli.reload"
  reload(args)
end

function _M.status()
  local status = require "api-umbrella.cli.status"
  local running, pid = status()
  if running then
    print("api-umbrella (pid " .. (pid or "") .. ") is running...")
    os.exit(0)
  else
    print("api-umbrella is stopped")
    os.exit(3)
  end
end

function _M.reopen_logs()
  local reopen_logs = require "api-umbrella.cli.reopen_logs"
  reopen_logs()
end

function _M.processes()
  local processes = require "api-umbrella.cli.processes"
  processes()
end

function _M.db_setup()
  local db_setup = require "api-umbrella.cli.db_setup"
  db_setup()
end

function _M.migrate()
  local migrate = require "api-umbrella.cli.migrate"
  migrate()
end

function _M.wait_for_migrations()
  local wait_for_migrations = require "api-umbrella.cli.wait_for_migrations"
  wait_for_migrations()
end

function _M.health(args)
  local health = require "api-umbrella.cli.health"
  health(args)
end

function _M.version()
  local get_api_umbrella_version = require "api-umbrella.utils.get_api_umbrella_version"
  local version = get_api_umbrella_version()
  print(version)
  os.exit(0)
end

function _M.dump_config(args)
  local dump_config = require "api-umbrella.cli.dump_config"
  dump_config(args)
end

function _M.write_config_files(args)
  local write_config_files = require "api-umbrella.cli.write_config_files"
  write_config_files(args)
end

function _M.cloud_foundry_generate_config()
  local cloud_foundry_generate_config = require "api-umbrella.cli.cloud_foundry_generate_config"
  cloud_foundry_generate_config()
end

function _M.help()
  print(parser:get_help())
end

parser:flag("--version")
  :description("Print the API Umbrella version number.")
  :action(_M.version)

parser:command("run")
  :description("Run the API Umbrella server in the foreground.")
  :action(_M.run)

parser:command("start")
  :description("Start the API Umbrella server in the background.")
  :action(_M.start)

parser:command("stop")
  :description("Stop the API Umbrella server.")
  :action(_M.stop)

parser:command("restart")
  :description("Restart the API Umbrella server.")
  :action(_M.restart)

parser:command("reload")
  :description("Reload the configuration of the API Umbrella server.")
  :action(_M.reload)

parser:command("status")
  :description("Show the status of the API Umbrella server.")
  :action(_M.status)

parser:command("reopen-logs")
  :description("Close and reopen log files in use.")
  :action(_M.reopen_logs)

parser:command("processes")
  :description("List the status of the processes running under API Umbrella.")
  :action(_M.processes)

parser:command("db-setup")
  :description("Run the initial database setup task.")
  :action(_M.db_setup)

parser:command("migrate")
  :description("Run the database migrations task.")
  :action(_M.migrate)

parser:command("wait-for-migrations")
  :description("Wait for the database to be available and fully migrated.")
  :action(_M.wait_for_migrations)

local health_command = parser:command("health")
  :description("Print the health of the API Umbrella services.")
  :action(_M.health)
health_command:option("--wait-for-status")
  :description("Wait for this health status (or better) to become true before returning")
health_command:option("--wait-timeout")
  :description("When --wait-for-status is being used, maximum time (in seconds) to wait before exiting")
  :default("50")
  :convert(tonumber)
  :show_default(true)

parser:command("dump-config")
  :description("Dump the full runtime configuration after parsing and loading files.")
  :action(_M.dump_config)

parser:command("write-config-files")
  :description("Write any config files and parsed templates after parsing config and loading files.")
  :action(_M.write_config_files)

parser:command("cloud-foundry-generate-config")
  :description("For cloud foundry environments: Generate the api-umbrella.yml file from VCAP_SERVICES")
  :action(_M.cloud_foundry_generate_config)

parser:command("version")
  :description("Print the API Umbrella version number.")
  :action(_M.version)

parser:command("help")
  :description("Show this help message and exit.")
  :action(_M.help)

return function()
  parser:parse()
end
