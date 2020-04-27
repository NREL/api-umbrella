local append_array = require("api-umbrella.proxy.utils").append_array
local file_read = require("pl.file").read
local json_decode = require("cjson").decode
local path = require "pl.path"
local shell_blocking_capture_combined = require("shell-games").capture_combined

local match = ngx.re.match
local path_exists = path.exists
local path_join = path.join

local _M = {}

function _M.pull(config)
  local db_path = path_join(config["db_dir"], "disposable-email-domains")
  if not path_exists(db_path) then
    local _, git_err = shell_blocking_capture_combined({ "git", "clone", "https://github.com/ivolo/disposable-email-domains.git", db_path })
    if git_err then
      return false, git_err
    end

    return "changed"
  else
    local result, git_err = shell_blocking_capture_combined({ "git", "pull", "origin", "master" }, { chdir = db_path })
    if git_err then
      return false, git_err
    else
      local matches, match_err = match(result["output"], "Already.up.to.date", "ijo")
      if match_err then
        return false, "regex error: " .. match_err
      end

      if matches then
        return "changed"
      end

      return true
    end
  end
end

function _M.get_domains(config)
  local db_path = path_join(config["db_dir"], "disposable-email-domains")
  local domains = json_decode(file_read(path_join(db_path, "index.json")))
  append_array(domains, json_decode(file_read(path_join(db_path, "wildcard.json"))))

  return domains
end

return _M
