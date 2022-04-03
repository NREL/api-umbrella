local build_active_config = require "api-umbrella.utils.active_config_store.build_active_config"
local compressed_json = require "api-umbrella.utils.compressed_json"
local fetch_latest_published_config = require "api-umbrella.utils.active_config_store.fetch_latest_published_config"
local mlcache = require "resty.mlcache"
local set_envoy_config = require "api-umbrella.utils.active_config_store.set_envoy_config"

local compress_json_encode = compressed_json.compress_json_encode
local decompress_json_decode = compressed_json.decompress_json_decode
local jobs_dict = ngx.shared.jobs

local _M = {}

local function fetch_compressed_active_config(last_fetched_version)
  local published_config, err = fetch_latest_published_config(last_fetched_version)
  if err then
    ngx.log(ngx.ERR, "failed to fetch published config from database: ", err)
  end

  if not published_config and last_fetched_version then
    return nil
  end

  local active_config = build_active_config(published_config)

  -- Compress the config for storage in the l2 shared dict cache.
  --
  -- This allows us to store and cache a lot of repetitive data across many API
  -- backends without necessarily requiring a lot of memory dedicated to the
  -- shared dict. And because a lot of what is cached is duplicate strings (eg,
  -- error template), this won't necessarily require more memory when stored in
  -- the L1 cache, since at that point, once Lua only keeps a single copy of
  -- identical strings.
  local compressed_active_config = compress_json_encode(active_config)

  local _, envoy_err = set_envoy_config(active_config)
  if envoy_err then
    ngx.log(ngx.ERR, "set envoy error: ", envoy_err)
  end

  local set_ok, set_err, set_forcible = jobs_dict:set("active_config_store_last_fetched_version", active_config["db_version"] or 0)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'active_config_store_last_fetched_version' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'active_config_store_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
  end

  return compressed_active_config
end

local function l1_serializer(compressed)
  return decompress_json_decode(compressed)
end

local cache, cache_err = mlcache.new("active_config", "active_config", {
  lru_size = 1000,
  ttl = 0,
  resurrect_ttl = 60 * 60 * 24,
  neg_ttl = 60 * 60 * 24,
  shm_locks = "active_config_locks",
  ipc_shm = "active_config_ipc",
  l1_serializer = l1_serializer,
})
if not cache then
  ngx.log(ngx.ERR, "failed to create active_config mlcache: ", cache_err)
  return nil
end

function _M.get()
  local active_config, err = cache:get("active_config", nil, fetch_compressed_active_config)
  if err then
    ngx.log(ngx.ERR, "active config cache lookup failed: ", err)
    return nil
  end

  return active_config
end

function _M.exists()
  local _, err, value = cache:peek("active_config", true)
  if err then
    ngx.log(ngx.ERR, "active config cache lookup failed: ", err)
    return false
  end

  return value ~= nil
end

function _M.poll_for_update()
  local last_fetched_version, last_fetched_version_err = jobs_dict:get("active_config_store_last_fetched_version")
  if last_fetched_version_err then
    ngx.log(ngx.ERR, "Error fetching last_fetched_version: ", last_fetched_version_err)
    return
  elseif not last_fetched_version then
    -- If the active config hasn't been set yet, then this means the initial
    -- fetching hasn't yet completed, so return and wait for that to complete.
    return
  end

  local compressed_active_config = fetch_compressed_active_config(last_fetched_version)
  if compressed_active_config then
    -- TODO: Check size to fit in memory.
    cache:set("active_config", nil, compressed_active_config)
  end
end

function _M.refresh_local_cache()
  local _, update_err = cache:update()
  if update_err then
    ngx.log(ngx.ERR, "active_config cache update failed: ", update_err)
  end
end

return _M
