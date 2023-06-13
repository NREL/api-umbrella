local config = require("api-umbrella.utils.load_config")()

return function(ngx_ctx)
  local https_url = {
    config["override_public_https_proto"] or "https",
    "://",
    ngx_ctx.host_normalized,
  }
  if config["override_public_https_port"] then
    if config["override_public_https_port"] ~= 443 then
      table.insert(https_url, ":")
      table.insert(https_url, config["override_public_https_port"])
    end
  elseif config["https_port"] and config["https_port"] ~= 443 then
    table.insert(https_url, ":")
    table.insert(https_url, config["https_port"])
  end
  table.insert(https_url, ngx_ctx.original_request_uri)

  return table.concat(https_url, "")
end
