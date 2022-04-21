local find_cmd = require "api-umbrella.utils.find_cmd"
local lexer = require "pl.lexer"
local readfile = require("pl.utils").readfile
local realpath = require("posix.stdlib").realpath

local function parse_require_paths(file_path)
  local source = readfile(file_path)
  if not source then
    error("Could not read file " .. file_path)
    return
  end

  local require_paths = {}
  local next_string_is_require_path = false
  for t, v in lexer.lua(source) do
    if t == "iden" and v == "require" then
      next_string_is_require_path = true
    end

    if next_string_is_require_path and t == "string" then
      require_paths[v] = true
      next_string_is_require_path = false
    end
  end

  return require_paths
end

local function parse_require_paths_in_dir(src_dir, preload_file)
  local file_paths, find_err = find_cmd(src_dir, { "-type", "f", "-name", "*.lua" })
  if find_err then
    print(find_err)
    os.exit(1)
  end

  local require_paths = {}
  for _, file_path in ipairs(file_paths) do
    if file_path ~= preload_file then
      local file_require_paths = parse_require_paths(file_path)
      for file_require_path, _ in pairs(file_require_paths) do
        require_paths[file_require_path] = true
      end
    end
  end

  return require_paths
end

local function check(src_dir, preload_file)
  local preload_require_path = string.gsub(preload_file, "^src/", "")
  preload_require_path = string.gsub(preload_require_path, "%.lua$", "")
  preload_require_path = string.gsub(preload_require_path, "/", ".")

  src_dir = realpath(src_dir)
  preload_file = realpath(preload_file)

  local dir_require_paths = parse_require_paths_in_dir(src_dir, preload_file)
  local preload_require_paths = parse_require_paths(preload_file)
  local missing_preload_require_paths = {}
  local extra_preload_require_paths = {}
  for require_path, _ in pairs(dir_require_paths) do
    if not preload_require_paths[require_path] and require_path ~= preload_require_path then
      table.insert(missing_preload_require_paths, require_path)
    end
  end
  for require_path, _ in pairs(preload_require_paths) do
    if not dir_require_paths[require_path] then
      table.insert(extra_preload_require_paths, require_path)
    end
  end

  local ok = true
  if #missing_preload_require_paths > 0 then
    print("Error: Missing expected require statements in " .. preload_file)
    print("Missing requires to add:\n")

    table.sort(missing_preload_require_paths)
    for _, require_path in ipairs(missing_preload_require_paths) do
      print('require "' .. require_path .. '"')
    end
    print("")

    ok = false
  end

  if #extra_preload_require_paths > 0 then
    print("Error: Extra require statements in " .. preload_file)
    print("Extra requires to remove:\n")

    table.sort(extra_preload_require_paths)
    for _, require_path in ipairs(extra_preload_require_paths) do
      print('require "' .. require_path .. '"')
    end
    print("")

    ok = false
  end

  if ok then
    print(preload_file .. ": OK")
  end

  return ok
end

local proxy_ok = check("src/api-umbrella/proxy", "src/api-umbrella/proxy/hooks/init_preload_modules.lua")
local web_app_ok = check("src/api-umbrella/web-app", "src/api-umbrella/web-app/hooks/init_preload_modules.lua")
if not proxy_ok or not web_app_ok then
  os.exit(1)
end
